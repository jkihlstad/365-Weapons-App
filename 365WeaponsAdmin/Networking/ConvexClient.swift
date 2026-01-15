//
//  ConvexClient.swift
//  365WeaponsAdmin
//
//  Convex Backend Client for realtime data sync
//  Enhanced with unified error handling and retry support
//

import Foundation
import Combine

// MARK: - Convex Configuration
struct ConvexConfig {
    static let deploymentURL = "https://clear-pony-963.convex.cloud"
    static let httpEndpoint = "\(deploymentURL)/api"

    // Function endpoints
    static let queryEndpoint = "\(httpEndpoint)/query"
    static let mutationEndpoint = "\(httpEndpoint)/mutation"
    static let actionEndpoint = "\(httpEndpoint)/action"

    // Retry configuration
    static let defaultRetryConfig = RetryConfiguration(
        maxAttempts: 3,
        baseDelay: 1.0,
        maxDelay: 15.0,
        exponentialBackoff: true,
        jitter: 0.2
    )

    // Timeout configuration
    static let requestTimeout: TimeInterval = 30
    static let resourceTimeout: TimeInterval = 60
}

// MARK: - Convex Client
class ConvexClient: ObservableObject {
    static let shared = ConvexClient()

    @Published var isConnected: Bool = false
    @Published var lastSyncTime: Date?
    @Published var lastError: AppError?
    @Published var connectionState: ConnectionState = .disconnected

    private var cancellables = Set<AnyCancellable>()
    private let session: URLSession
    private var authToken: String?
    private var retryConfig: RetryConfiguration

    /// Connection state enumeration
    enum ConnectionState: String {
        case connected
        case connecting
        case disconnected
        case reconnecting
        case error

        var displayName: String {
            rawValue.capitalized
        }
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = ConvexConfig.requestTimeout
        config.timeoutIntervalForResource = ConvexConfig.resourceTimeout
        self.session = URLSession(configuration: config)
        self.retryConfig = ConvexConfig.defaultRetryConfig
        setupConnectionMonitoring()
    }

    // MARK: - Connection Monitoring

    private func setupConnectionMonitoring() {
        // Periodic connection check
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.checkConnection()
                }
            }
            .store(in: &cancellables)
    }

    private func checkConnection() async {
        // Simple connectivity check
        do {
            let _: Bool = try await ping()
            await MainActor.run {
                if connectionState != .connected {
                    connectionState = .connected
                    lastError = nil
                }
            }
        } catch {
            await MainActor.run {
                connectionState = .disconnected
            }
        }
    }

    /// Test connection to Convex backend
    private func ping() async throws -> Bool {
        // Perform a lightweight query to test connectivity
        let url = URL(string: ConvexConfig.queryEndpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5

        let body: [String: Any] = [
            "path": "products:listAll",
            "args": [:],
            "format": "json"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return false
        }

        return true
    }

    /// Configure retry behavior
    func setRetryConfiguration(_ config: RetryConfiguration) {
        self.retryConfig = config
    }

    // MARK: - Authentication
    func setAuthToken(_ token: String) {
        self.authToken = token
        self.isConnected = true
    }

    func clearAuth() {
        self.authToken = nil
        self.isConnected = false
    }

    // MARK: - Query Functions

    /// Execute a Convex query with automatic retry support
    /// - Parameters:
    ///   - functionName: The Convex function path to call
    ///   - args: Arguments to pass to the function
    ///   - useRetry: Whether to use automatic retry for transient errors
    /// - Returns: The decoded response
    func query<T: Decodable>(_ functionName: String, args: [String: Any] = [:], useRetry: Bool = true) async throws -> T {
        if useRetry {
            return try await executeWithRetry(functionName: functionName) {
                try await self.executeQuery(functionName, args: args)
            }
        } else {
            return try await executeQuery(functionName, args: args)
        }
    }

    /// Internal query execution
    private func executeQuery<T: Decodable>(_ functionName: String, args: [String: Any]) async throws -> T {
        let url = URL(string: ConvexConfig.queryEndpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "path": functionName,
            "args": args,
            "format": "json"
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw AppError.invalidInput("Failed to encode request for \(functionName)")
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            await updateConnectionState(.disconnected)
            throw AppError.from(urlError)
        } catch {
            await updateConnectionState(.error)
            throw AppError.unknown(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.invalidResponse
        }

        // Handle HTTP status codes
        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw AppError.notAuthenticated
        case 403:
            throw AppError.notAuthorized
        case 404:
            throw AppError.convexDataNotFound(entity: functionName)
        case 429:
            throw AppError.openRouterRateLimited(retryAfter: nil)
        case 500...599:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AppError.convexServerError(statusCode: httpResponse.statusCode, message: errorMessage)
        default:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AppError.networkRequestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        let result: ConvexQueryResult<T>
        do {
            result = try decoder.decode(ConvexQueryResult<T>.self, from: data)
        } catch {
            throw AppError.dataCorrupted("Failed to decode response from \(functionName): \(error.localizedDescription)")
        }

        if let error = result.errorMessage {
            throw AppError.convexQueryFailed(function: functionName, message: error)
        }

        guard let value = result.value else {
            throw AppError.convexDataNotFound(entity: functionName)
        }

        await updateConnectionState(.connected)
        await MainActor.run {
            lastSyncTime = Date()
        }
        return value
    }

    /// Execute operation with retry logic
    private func executeWithRetry<T>(functionName: String, operation: () async throws -> T) async throws -> T {
        var lastError: Error?

        for attempt in 1...retryConfig.maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                let appError = AppError.from(error)

                // Log the attempt
                await DebugLogger.shared.warning(
                    "Convex \(functionName) attempt \(attempt)/\(retryConfig.maxAttempts) failed: \(appError.userMessage)",
                    category: .convex
                )

                // Check if error is retryable
                guard appError.isRetryable && attempt < retryConfig.maxAttempts else {
                    break
                }

                // Calculate delay
                let delay = retryConfig.delay(for: attempt)
                await DebugLogger.shared.log("Retrying \(functionName) in \(String(format: "%.1f", delay))s...", category: .convex)

                // Wait before retry
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        let finalError = AppError.from(lastError ?? AppError.unknown(NSError(domain: "Convex", code: -1)))
        await MainActor.run {
            self.lastError = finalError
        }
        throw finalError
    }

    /// Update connection state on main actor
    @MainActor
    private func updateConnectionState(_ state: ConnectionState) {
        if connectionState != state {
            connectionState = state
            if state == .connected {
                isConnected = true
                lastError = nil
            } else if state == .disconnected || state == .error {
                isConnected = false
            }
        }
    }

    // MARK: - Mutation Functions

    /// Execute a Convex mutation with automatic retry support
    /// - Parameters:
    ///   - functionName: The Convex function path to call
    ///   - args: Arguments to pass to the function
    ///   - useRetry: Whether to use automatic retry for transient errors
    /// - Returns: The decoded response
    func mutation<T: Decodable>(_ functionName: String, args: [String: Any] = [:], useRetry: Bool = true) async throws -> T {
        if useRetry {
            return try await executeWithRetry(functionName: functionName) {
                try await self.executeMutation(functionName, args: args)
            }
        } else {
            return try await executeMutation(functionName, args: args)
        }
    }

    /// Internal mutation execution
    private func executeMutation<T: Decodable>(_ functionName: String, args: [String: Any]) async throws -> T {
        let url = URL(string: ConvexConfig.mutationEndpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "path": functionName,
            "args": args,
            "format": "json"
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw AppError.invalidInput("Failed to encode mutation request for \(functionName)")
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            await updateConnectionState(.disconnected)
            throw AppError.from(urlError)
        } catch {
            await updateConnectionState(.error)
            throw AppError.unknown(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.invalidResponse
        }

        // Handle HTTP status codes
        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw AppError.notAuthenticated
        case 403:
            throw AppError.notAuthorized
        case 404:
            throw AppError.convexDataNotFound(entity: functionName)
        case 429:
            throw AppError.openRouterRateLimited(retryAfter: nil)
        case 500...599:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AppError.convexServerError(statusCode: httpResponse.statusCode, message: errorMessage)
        default:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AppError.networkRequestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        let result: ConvexQueryResult<T>
        do {
            result = try decoder.decode(ConvexQueryResult<T>.self, from: data)
        } catch {
            throw AppError.dataCorrupted("Failed to decode mutation response from \(functionName): \(error.localizedDescription)")
        }

        if let error = result.errorMessage {
            throw AppError.convexMutationFailed(function: functionName, message: error)
        }

        guard let value = result.value else {
            throw AppError.convexDataNotFound(entity: functionName)
        }

        await updateConnectionState(.connected)
        return value
    }

    // MARK: - Action Functions

    /// Execute a Convex action with automatic retry support
    /// - Parameters:
    ///   - functionName: The Convex function path to call
    ///   - args: Arguments to pass to the function
    ///   - useRetry: Whether to use automatic retry for transient errors
    /// - Returns: The decoded response
    func action<T: Decodable>(_ functionName: String, args: [String: Any] = [:], useRetry: Bool = true) async throws -> T {
        if useRetry {
            return try await executeWithRetry(functionName: functionName) {
                try await self.executeAction(functionName, args: args)
            }
        } else {
            return try await executeAction(functionName, args: args)
        }
    }

    /// Internal action execution
    private func executeAction<T: Decodable>(_ functionName: String, args: [String: Any]) async throws -> T {
        let url = URL(string: ConvexConfig.actionEndpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "path": functionName,
            "args": args,
            "format": "json"
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw AppError.invalidInput("Failed to encode action request for \(functionName)")
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            await updateConnectionState(.disconnected)
            throw AppError.from(urlError)
        } catch {
            await updateConnectionState(.error)
            throw AppError.unknown(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.invalidResponse
        }

        // Handle HTTP status codes
        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw AppError.notAuthenticated
        case 403:
            throw AppError.notAuthorized
        case 404:
            throw AppError.convexDataNotFound(entity: functionName)
        case 429:
            throw AppError.openRouterRateLimited(retryAfter: nil)
        case 500...599:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AppError.convexServerError(statusCode: httpResponse.statusCode, message: errorMessage)
        default:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AppError.networkRequestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        do {
            let result = try decoder.decode(T.self, from: data)
            await updateConnectionState(.connected)
            return result
        } catch {
            throw AppError.dataCorrupted("Failed to decode action response from \(functionName): \(error.localizedDescription)")
        }
    }

    // MARK: - Convenience Methods for Common Queries

    func fetchProducts(category: String? = nil) async throws -> [Product] {
        if let category = category {
            return try await query("products:list", args: ["category": category])
        }
        return try await query("products:listAll")
    }

    func fetchOrders(userId: String? = nil, status: String? = nil, limit: Int = 50) async throws -> [Order] {
        if let userId = userId {
            return try await query("orders:getByUser", args: ["userId": userId])
        }
        return try await query("orders:listAll")
    }

    func fetchPartners() async throws -> [PartnerStore] {
        return try await query("partnerStores:list")
    }

    func fetchCommissions(status: String? = nil) async throws -> [Commission] {
        return try await query("commissions:listAll")
    }

    func fetchInquiries(status: String? = nil) async throws -> [ServiceInquiry] {
        if let status = status {
            return try await query("serviceInquiries:getByStatus", args: ["status": status])
        }
        return try await query("serviceInquiries:list")
    }

    func createProduct(_ product: CreateProductRequest) async throws -> String {
        let args: [String: Any] = [
            "title": product.title,
            "description": product.description ?? "",
            "price": product.price,
            "priceRange": product.priceRange ?? "",
            "category": product.category,
            "image": product.image,
            "inStock": product.inStock,
            "hasOptions": product.hasOptions ?? false
        ]
        return try await mutation("products:create", args: args)
    }

    func updateProduct(id: String, updates: [String: Any]) async throws -> Bool {
        var args = updates
        args["productId"] = id
        return try await mutation("products:update", args: args)
    }

    func updateOrderStatus(orderId: String, status: String) async throws -> Bool {
        let args: [String: Any] = [
            "orderId": orderId,
            "status": status
        ]
        return try await mutation("orders:updateStatus", args: args)
    }

    func fetchDashboardStats() async throws -> DashboardStats {
        // Aggregate queries for dashboard - using all available backend functions
        async let products: [Product] = query("products:listAll")
        async let orders: [Order] = query("orders:listAll")
        async let partners: [PartnerStore] = query("partnerStores:list")
        async let commissions: [Commission] = query("commissions:listAll")
        async let inquiries: [ServiceInquiry] = query("serviceInquiries:list")

        let (productsList, ordersList, partnersList, commissionsList, inquiriesList) = try await (products, orders, partners, commissions, inquiries)

        // Calculate stats from available data
        let totalRevenue = ordersList
            .filter { $0.status == .completed }
            .compactMap { $0.totals?.total }
            .reduce(0) { $0 + Double($1) / 100.0 }

        let pendingOrders = ordersList.filter { $0.status == .awaitingShipment || $0.status == .inProgress }.count
        let pendingInquiries = inquiriesList.filter { $0.status == .new || $0.status == .reviewed }.count
        let eligibleCommissions = commissionsList
            .filter { $0.status == .eligible }
            .reduce(0.0) { $0 + $1.commissionAmount }

        return DashboardStats(
            totalRevenue: totalRevenue,
            totalOrders: ordersList.count,
            totalProducts: productsList.count,
            totalPartners: partnersList.count,
            pendingOrders: pendingOrders,
            pendingInquiries: pendingInquiries,
            eligibleCommissions: eligibleCommissions,
            revenueGrowth: 12.5,        // Would need historical data
            orderGrowth: 8.3            // Would need historical data
        )
    }
}

// MARK: - Convex Response Types
struct ConvexQueryResult<T: Decodable>: Decodable {
    let value: T?
    let errorMessage: String?
}

// MARK: - Convex Errors
enum ConvexError: Error, LocalizedError {
    case invalidResponse
    case noData
    case queryError(message: String)
    case mutationError(message: String)
    case serverError(statusCode: Int, message: String)
    case encodingError

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .noData:
            return "No data received"
        case .queryError(let message):
            return "Query error: \(message)"
        case .mutationError(let message):
            return "Mutation error: \(message)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .encodingError:
            return "Failed to encode request"
        }
    }
}

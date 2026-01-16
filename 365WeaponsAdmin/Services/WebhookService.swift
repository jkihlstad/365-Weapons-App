//
//  WebhookService.swift
//  365WeaponsAdmin
//
//  Service for managing webhooks - CRUD operations, testing, and delivery history
//

import Foundation
import Combine
import CryptoKit

// MARK: - Webhook Service Configuration
struct WebhookServiceConfig {
    static let apiBaseURL = "https://365-weapons-ios-app-production.up.railway.app/webhooks"
    static let testTimeout: TimeInterval = 30
    static let maxDeliveryHistoryItems = 100
}

// MARK: - Webhook Service
class WebhookService: ObservableObject {
    static let shared = WebhookService()

    // MARK: - Published Properties
    @Published var webhooks: [WebhookConfiguration] = []
    @Published var deliveryHistory: [String: [WebhookDelivery]] = [:] // webhookId -> deliveries
    @Published var isLoading: Bool = false
    @Published var error: WebhookServiceError?

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let session: URLSession
    private let convex = ConvexClient.shared
    private var authToken: String?

    // Local storage key for offline support
    private let webhooksStorageKey = "stored_webhooks"
    private let deliveriesStorageKey = "stored_deliveries"

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        // Load cached webhooks on init
        loadCachedWebhooks()
    }

    // MARK: - Configuration
    func configure(authToken: String) {
        self.authToken = authToken
    }

    // MARK: - CRUD Operations

    /// Fetch all webhooks from the backend
    func getWebhooks() async throws -> [WebhookConfiguration] {
        isLoading = true
        defer { isLoading = false }

        do {
            // Try to fetch from Convex backend
            let webhooks: [WebhookConfiguration] = try await convex.query("webhooks:list")

            await MainActor.run {
                self.webhooks = webhooks
                self.cacheWebhooks(webhooks)
                self.error = nil
            }

            return webhooks
        } catch {
            // Fall back to cached webhooks if available
            await MainActor.run {
                self.error = .fetchFailed(error.localizedDescription)
            }

            // Return cached webhooks if available
            if !webhooks.isEmpty {
                return webhooks
            }

            throw WebhookServiceError.fetchFailed(error.localizedDescription)
        }
    }

    /// Create a new webhook
    func createWebhook(_ webhook: WebhookConfiguration) async throws -> WebhookConfiguration {
        // Validate URL before creating
        if let validationError = webhook.url.webhookURLValidationError {
            throw WebhookServiceError.invalidURL(validationError)
        }

        // Validate name
        guard !webhook.name.trimmed.isEmpty else {
            throw WebhookServiceError.validationError("Webhook name is required")
        }

        // Validate events
        guard !webhook.events.isEmpty else {
            throw WebhookServiceError.validationError("At least one event must be selected")
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let args: [String: Any] = [
                "name": webhook.name,
                "url": webhook.url,
                "events": webhook.events.map { $0.rawValue },
                "isActive": webhook.isActive,
                "secret": webhook.secret,
                "retryEnabled": webhook.retryEnabled,
                "maxRetries": webhook.maxRetries,
                "headers": webhook.headers ?? [:]
            ]

            let createdId: String = try await convex.mutation("webhooks:create", args: args)

            // Create the new webhook with the returned ID
            var newWebhook = webhook
            let createdWebhook = WebhookConfiguration(
                id: createdId,
                name: newWebhook.name,
                url: newWebhook.url,
                events: newWebhook.events,
                isActive: newWebhook.isActive,
                secret: newWebhook.secret,
                createdAt: Date(),
                retryEnabled: newWebhook.retryEnabled,
                maxRetries: newWebhook.maxRetries
            )

            await MainActor.run {
                self.webhooks.append(createdWebhook)
                self.cacheWebhooks(self.webhooks)
                self.error = nil
            }

            // Log admin action
            await ActionTrackingService.shared.logAdminAction("Created webhook: \(webhook.name)")

            return createdWebhook
        } catch let error as WebhookServiceError {
            await MainActor.run {
                self.error = error
            }
            throw error
        } catch {
            let serviceError = WebhookServiceError.createFailed(error.localizedDescription)
            await MainActor.run {
                self.error = serviceError
            }
            throw serviceError
        }
    }

    /// Update an existing webhook
    func updateWebhook(_ webhook: WebhookConfiguration) async throws -> WebhookConfiguration {
        // Validate URL
        if let validationError = webhook.url.webhookURLValidationError {
            throw WebhookServiceError.invalidURL(validationError)
        }

        // Validate name
        guard !webhook.name.trimmed.isEmpty else {
            throw WebhookServiceError.validationError("Webhook name is required")
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let args: [String: Any] = [
                "webhookId": webhook.id,
                "name": webhook.name,
                "url": webhook.url,
                "events": webhook.events.map { $0.rawValue },
                "isActive": webhook.isActive,
                "retryEnabled": webhook.retryEnabled,
                "maxRetries": webhook.maxRetries,
                "headers": webhook.headers ?? [:]
            ]

            let _: Bool = try await convex.mutation("webhooks:update", args: args)

            var updatedWebhook = webhook
            updatedWebhook.updatedAt = Date()

            await MainActor.run {
                if let index = self.webhooks.firstIndex(where: { $0.id == webhook.id }) {
                    self.webhooks[index] = updatedWebhook
                    self.cacheWebhooks(self.webhooks)
                }
                self.error = nil
            }

            await ActionTrackingService.shared.logAdminAction("Updated webhook: \(webhook.name)")

            return updatedWebhook
        } catch {
            let serviceError = WebhookServiceError.updateFailed(error.localizedDescription)
            await MainActor.run {
                self.error = serviceError
            }
            throw serviceError
        }
    }

    /// Delete a webhook
    func deleteWebhook(_ webhookId: String) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let args: [String: Any] = ["webhookId": webhookId]
            let _: Bool = try await convex.mutation("webhooks:delete", args: args)

            await MainActor.run {
                let webhookName = self.webhooks.first(where: { $0.id == webhookId })?.name ?? "Unknown"
                self.webhooks.removeAll { $0.id == webhookId }
                self.deliveryHistory.removeValue(forKey: webhookId)
                self.cacheWebhooks(self.webhooks)
                self.error = nil

                Task {
                    await ActionTrackingService.shared.logAdminAction("Deleted webhook: \(webhookName)")
                }
            }
        } catch {
            let serviceError = WebhookServiceError.deleteFailed(error.localizedDescription)
            await MainActor.run {
                self.error = serviceError
            }
            throw serviceError
        }
    }

    /// Toggle webhook active status
    func toggleWebhook(_ webhookId: String, isActive: Bool) async throws {
        guard var webhook = webhooks.first(where: { $0.id == webhookId }) else {
            throw WebhookServiceError.notFound
        }

        webhook.isActive = isActive
        let _ = try await updateWebhook(webhook)
    }

    // MARK: - Testing

    /// Test a webhook by sending a test payload
    func testWebhook(_ webhook: WebhookConfiguration) async throws -> WebhookTestResult {
        // Validate URL first
        if let validationError = webhook.url.webhookURLValidationError {
            throw WebhookServiceError.invalidURL(validationError)
        }

        guard let url = URL(string: webhook.url) else {
            throw WebhookServiceError.invalidURL("Invalid URL format")
        }

        let startTime = Date()

        // Create test payload
        let testData: [String: AnyCodable] = [
            "test": AnyCodable(true),
            "message": AnyCodable("This is a test webhook from 365Weapons Admin"),
            "timestamp": AnyCodable(ISO8601DateFormatter().string(from: Date())),
            "webhook_name": AnyCodable(webhook.name)
        ]

        let payload = WebhookPayload(
            event: .orderCreated, // Use a common event for testing
            data: testData,
            webhookId: webhook.id,
            secret: webhook.secret
        )

        // Prepare request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("365Weapons-Webhook/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue(webhook.id, forHTTPHeaderField: "X-Webhook-ID")
        request.setValue("test", forHTTPHeaderField: "X-Webhook-Event")

        // Add signature header
        if let signature = payload.signature {
            request.setValue(signature, forHTTPHeaderField: "X-Webhook-Signature")
        }

        // Add timestamp header
        request.setValue(String(Int(payload.timestamp.timeIntervalSince1970)), forHTTPHeaderField: "X-Webhook-Timestamp")

        // Add custom headers if configured
        if let headers = webhook.headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        // Encode payload
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(payload)

        request.timeoutInterval = WebhookServiceConfig.testTimeout

        do {
            let (data, response) = try await session.data(for: request)
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw WebhookServiceError.testFailed("Invalid response")
            }

            let responseString = String(data: data, encoding: .utf8)
            let success = httpResponse.statusCode >= 200 && httpResponse.statusCode < 300

            let result = WebhookTestResult(
                webhookId: webhook.id,
                success: success,
                statusCode: httpResponse.statusCode,
                response: responseString,
                duration: duration,
                errorMessage: success ? nil : "HTTP \(httpResponse.statusCode)",
                timestamp: Date()
            )

            // Record the test delivery in history
            let delivery = WebhookDelivery(
                webhookId: webhook.id,
                event: .orderCreated,
                payload: String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "",
                response: responseString,
                statusCode: httpResponse.statusCode,
                success: success,
                errorMessage: success ? nil : "Test: HTTP \(httpResponse.statusCode)"
            )

            await MainActor.run {
                self.addDeliveryToHistory(delivery)
            }

            await ActionTrackingService.shared.logAdminAction("Tested webhook: \(webhook.name) - \(success ? "Success" : "Failed")")

            return result
        } catch let error as URLError {
            let errorMessage: String
            switch error.code {
            case .timedOut:
                errorMessage = "Request timed out after \(Int(WebhookServiceConfig.testTimeout))s"
            case .cannotConnectToHost:
                errorMessage = "Could not connect to host"
            case .notConnectedToInternet:
                errorMessage = "No internet connection"
            case .secureConnectionFailed:
                errorMessage = "SSL/TLS connection failed"
            default:
                errorMessage = error.localizedDescription
            }

            return WebhookTestResult(
                webhookId: webhook.id,
                success: false,
                statusCode: nil,
                response: nil,
                duration: nil,
                errorMessage: errorMessage,
                timestamp: Date()
            )
        } catch {
            return WebhookTestResult(
                webhookId: webhook.id,
                success: false,
                statusCode: nil,
                response: nil,
                duration: nil,
                errorMessage: error.localizedDescription,
                timestamp: Date()
            )
        }
    }

    // MARK: - Delivery History

    /// Get delivery history for a specific webhook
    func getDeliveryHistory(for webhookId: String, limit: Int = 50) async throws -> [WebhookDelivery] {
        do {
            let args: [String: Any] = [
                "webhookId": webhookId,
                "limit": limit
            ]

            let deliveries: [WebhookDelivery] = try await convex.query("webhooks:getDeliveries", args: args)

            await MainActor.run {
                self.deliveryHistory[webhookId] = deliveries
            }

            return deliveries
        } catch {
            // Return cached deliveries if available
            if let cached = deliveryHistory[webhookId] {
                return cached
            }

            throw WebhookServiceError.fetchFailed("Failed to fetch delivery history")
        }
    }

    /// Add a delivery to local history
    private func addDeliveryToHistory(_ delivery: WebhookDelivery) {
        var history = deliveryHistory[delivery.webhookId] ?? []
        history.insert(delivery, at: 0)

        // Keep only the most recent deliveries
        if history.count > WebhookServiceConfig.maxDeliveryHistoryItems {
            history = Array(history.prefix(WebhookServiceConfig.maxDeliveryHistoryItems))
        }

        deliveryHistory[delivery.webhookId] = history
    }

    /// Clear delivery history for a webhook
    func clearDeliveryHistory(for webhookId: String) async throws {
        do {
            let args: [String: Any] = ["webhookId": webhookId]
            let _: Bool = try await convex.mutation("webhooks:clearDeliveries", args: args)

            await MainActor.run {
                self.deliveryHistory[webhookId] = []
            }
        } catch {
            throw WebhookServiceError.deleteFailed("Failed to clear delivery history")
        }
    }

    // MARK: - Secret Key Management

    /// Regenerate secret for a webhook
    func regenerateSecret(for webhookId: String) async throws -> String {
        guard var webhook = webhooks.first(where: { $0.id == webhookId }) else {
            throw WebhookServiceError.notFound
        }

        let newSecret = WebhookConfiguration.generateSecret()

        do {
            let args: [String: Any] = [
                "webhookId": webhookId,
                "secret": newSecret
            ]

            let _: Bool = try await convex.mutation("webhooks:updateSecret", args: args)

            await MainActor.run {
                if let index = self.webhooks.firstIndex(where: { $0.id == webhookId }) {
                    self.webhooks[index].secret = newSecret
                    self.webhooks[index].updatedAt = Date()
                    self.cacheWebhooks(self.webhooks)
                }
            }

            await ActionTrackingService.shared.logAdminAction("Regenerated secret for webhook: \(webhook.name)")

            return newSecret
        } catch {
            throw WebhookServiceError.updateFailed("Failed to regenerate secret")
        }
    }

    // MARK: - Validation

    /// Validate a webhook URL by sending a HEAD request
    func validateURL(_ urlString: String) async -> (isValid: Bool, errorMessage: String?) {
        // First check format
        if let formatError = urlString.webhookURLValidationError {
            return (false, formatError)
        }

        guard let url = URL(string: urlString) else {
            return (false, "Invalid URL format")
        }

        // Try to reach the URL
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10

        do {
            let (_, response) = try await session.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                // Accept any response as valid - the endpoint exists
                return (true, nil)
            } else {
                return (false, "Invalid response from server")
            }
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                return (false, "Connection timed out")
            case .cannotFindHost:
                return (false, "Host not found")
            case .cannotConnectToHost:
                return (false, "Cannot connect to host")
            case .secureConnectionFailed:
                return (false, "SSL/TLS error")
            default:
                return (false, error.localizedDescription)
            }
        } catch {
            // Some servers don't support HEAD, so we might still accept POST
            return (true, nil)
        }
    }

    // MARK: - Statistics

    /// Get webhook statistics
    func getStatistics(for webhookId: String) async throws -> WebhookStatistics {
        let deliveries = try await getDeliveryHistory(for: webhookId, limit: 100)

        let totalDeliveries = deliveries.count
        let successfulDeliveries = deliveries.filter { $0.success }.count
        let failedDeliveries = totalDeliveries - successfulDeliveries
        let successRate = totalDeliveries > 0 ? Double(successfulDeliveries) / Double(totalDeliveries) * 100 : 0

        let averageDuration = deliveries.compactMap { $0.duration }.reduce(0, +) / Double(max(1, deliveries.count))

        let lastDelivery = deliveries.first
        let lastSuccessfulDelivery = deliveries.first(where: { $0.success })

        return WebhookStatistics(
            webhookId: webhookId,
            totalDeliveries: totalDeliveries,
            successfulDeliveries: successfulDeliveries,
            failedDeliveries: failedDeliveries,
            successRate: successRate,
            averageDuration: averageDuration,
            lastDelivery: lastDelivery,
            lastSuccessfulDelivery: lastSuccessfulDelivery
        )
    }

    // MARK: - Caching

    private func loadCachedWebhooks() {
        if let data = UserDefaults.standard.data(forKey: webhooksStorageKey),
           let cached = try? JSONDecoder().decode([WebhookConfiguration].self, from: data) {
            self.webhooks = cached
        }
    }

    private func cacheWebhooks(_ webhooks: [WebhookConfiguration]) {
        if let data = try? JSONEncoder().encode(webhooks) {
            UserDefaults.standard.set(data, forKey: webhooksStorageKey)
        }
    }

    // MARK: - Refresh
    func refresh() async {
        do {
            let _ = try await getWebhooks()
        } catch {
            print("Failed to refresh webhooks: \(error)")
        }
    }
}

// MARK: - Webhook Statistics
struct WebhookStatistics {
    let webhookId: String
    let totalDeliveries: Int
    let successfulDeliveries: Int
    let failedDeliveries: Int
    let successRate: Double
    let averageDuration: TimeInterval
    let lastDelivery: WebhookDelivery?
    let lastSuccessfulDelivery: WebhookDelivery?

    var successRateFormatted: String {
        String(format: "%.1f%%", successRate)
    }

    var averageDurationFormatted: String {
        String(format: "%.0fms", averageDuration * 1000)
    }
}

// MARK: - Webhook Service Errors
enum WebhookServiceError: Error, LocalizedError {
    case invalidURL(String)
    case validationError(String)
    case fetchFailed(String)
    case createFailed(String)
    case updateFailed(String)
    case deleteFailed(String)
    case testFailed(String)
    case notFound
    case unauthorized
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let message):
            return "Invalid URL: \(message)"
        case .validationError(let message):
            return "Validation error: \(message)"
        case .fetchFailed(let message):
            return "Failed to fetch: \(message)"
        case .createFailed(let message):
            return "Failed to create: \(message)"
        case .updateFailed(let message):
            return "Failed to update: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete: \(message)"
        case .testFailed(let message):
            return "Test failed: \(message)"
        case .notFound:
            return "Webhook not found"
        case .unauthorized:
            return "Unauthorized access"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

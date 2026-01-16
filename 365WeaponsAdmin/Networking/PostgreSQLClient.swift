//
//  PostgreSQLClient.swift
//  365WeaponsAdmin
//
//  PostgreSQL Client for analytics and action tracking
//

import Foundation
import Combine

// MARK: - PostgreSQL Configuration
struct PostgreSQLConfig {
    // These would typically come from secure configuration
    static var host: String = "localhost"
    static var port: Int = 5432
    static var database: String = "weapons365_analytics"
    static var user: String = "admin"
    static var password: String = ""

    // API endpoint for PostgreSQL proxy (since direct connections aren't possible from iOS)
    static var proxyEndpoint: String = "https://365-weapons-ios-app-production.up.railway.app/db"
}

// MARK: - PostgreSQL Client
class PostgreSQLClient: ObservableObject {
    static let shared = PostgreSQLClient()

    @Published var isConnected: Bool = false
    @Published var lastQueryTime: Date?
    @Published var error: PostgreSQLError?

    private let session: URLSession
    private var authToken: String?

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Configuration
    func configure(proxyEndpoint: String, authToken: String) {
        PostgreSQLConfig.proxyEndpoint = proxyEndpoint
        self.authToken = authToken
        self.isConnected = true
    }

    // MARK: - Query Execution
    func query<T: Decodable>(_ sql: String, params: [Any] = []) async throws -> [T] {
        guard let authToken = authToken else {
            throw PostgreSQLError.notConnected
        }

        var request = URLRequest(url: URL(string: "\(PostgreSQLConfig.proxyEndpoint)/query")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let body = QueryRequest(sql: sql, params: params.map { "\($0)" })
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PostgreSQLError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PostgreSQLError.queryError(message: errorMessage)
        }

        lastQueryTime = Date()

        let queryResponse = try JSONDecoder().decode(QueryResponse<T>.self, from: data)
        return queryResponse.rows
    }

    func execute(_ sql: String, params: [Any] = []) async throws -> Int {
        guard let authToken = authToken else {
            throw PostgreSQLError.notConnected
        }

        var request = URLRequest(url: URL(string: "\(PostgreSQLConfig.proxyEndpoint)/execute")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let body = QueryRequest(sql: sql, params: params.map { "\($0)" })
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PostgreSQLError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PostgreSQLError.executionError(message: errorMessage)
        }

        let executeResponse = try JSONDecoder().decode(ExecuteResponse.self, from: data)
        return executeResponse.rowsAffected
    }

    // MARK: - Website Action Tracking

    /// Log a website action
    func logAction(action: WebsiteAction) async throws {
        let sql = """
            INSERT INTO website_actions (id, action_type, description, user_id, user_email, metadata, timestamp)
            VALUES ($1, $2, $3, $4, $5, $6, $7)
        """

        let metadataJSON = try? JSONEncoder().encode(action.metadata)
        let metadataString = metadataJSON.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        _ = try await execute(sql, params: [
            action.id,
            action.actionType.rawValue,
            action.description,
            action.userId ?? "",
            action.userEmail ?? "",
            metadataString,
            action.timestamp.timeIntervalSince1970
        ])
    }

    /// Get recent website actions
    func getRecentActions(limit: Int = 100) async throws -> [WebsiteAction] {
        let sql = """
            SELECT id, action_type, description, user_id, user_email, metadata, timestamp
            FROM website_actions
            ORDER BY timestamp DESC
            LIMIT $1
        """

        return try await query(sql, params: [limit])
    }

    /// Get actions by type
    func getActionsByType(_ type: ActionType, limit: Int = 50) async throws -> [WebsiteAction] {
        let sql = """
            SELECT id, action_type, description, user_id, user_email, metadata, timestamp
            FROM website_actions
            WHERE action_type = $1
            ORDER BY timestamp DESC
            LIMIT $2
        """

        return try await query(sql, params: [type.rawValue, limit])
    }

    /// Get action statistics for a time period
    func getActionStats(from startDate: Date, to endDate: Date) async throws -> [ActionStat] {
        let sql = """
            SELECT action_type, COUNT(*) as count
            FROM website_actions
            WHERE timestamp >= $1 AND timestamp <= $2
            GROUP BY action_type
            ORDER BY count DESC
        """

        return try await query(sql, params: [
            startDate.timeIntervalSince1970,
            endDate.timeIntervalSince1970
        ])
    }

    // MARK: - Analytics Queries

    /// Get revenue by date range
    func getRevenueByDateRange(from startDate: Date, to endDate: Date) async throws -> [RevenueDataPoint] {
        let sql = """
            SELECT DATE(timestamp) as date, SUM(amount) as revenue, COUNT(*) as orders
            FROM transactions
            WHERE timestamp >= $1 AND timestamp <= $2 AND status = 'completed'
            GROUP BY DATE(timestamp)
            ORDER BY date ASC
        """

        return try await query(sql, params: [
            startDate.timeIntervalSince1970,
            endDate.timeIntervalSince1970
        ])
    }

    /// Get top products by sales
    func getTopProducts(limit: Int = 10) async throws -> [ProductSalesData] {
        let sql = """
            SELECT product_id, product_title, SUM(quantity) as total_quantity, SUM(amount) as total_revenue
            FROM order_items
            GROUP BY product_id, product_title
            ORDER BY total_revenue DESC
            LIMIT $1
        """

        return try await query(sql, params: [limit])
    }

    /// Get customer analytics
    func getCustomerAnalytics() async throws -> CustomerAnalytics {
        let totalCustomersSQL = "SELECT COUNT(DISTINCT user_id) as count FROM orders"
        let returningCustomersSQL = """
            SELECT COUNT(*) as count FROM (
                SELECT user_id FROM orders GROUP BY user_id HAVING COUNT(*) > 1
            ) as returning
        """
        let avgOrderValueSQL = "SELECT AVG(total) as avg FROM orders WHERE status = 'completed'"

        async let totalResult: [CountResult] = query(totalCustomersSQL)
        async let returningResult: [CountResult] = query(returningCustomersSQL)
        async let avgResult: [AvgResult] = query(avgOrderValueSQL)

        let (total, returning, avg) = try await (totalResult, returningResult, avgResult)

        return CustomerAnalytics(
            totalCustomers: total.first?.count ?? 0,
            returningCustomers: returning.first?.count ?? 0,
            averageOrderValue: avg.first?.avg ?? 0
        )
    }

    // MARK: - Schema Setup (for reference)
    func setupSchema() async throws {
        let createActionsTable = """
            CREATE TABLE IF NOT EXISTS website_actions (
                id VARCHAR(255) PRIMARY KEY,
                action_type VARCHAR(50) NOT NULL,
                description TEXT,
                user_id VARCHAR(255),
                user_email VARCHAR(255),
                metadata JSONB,
                timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );

            CREATE INDEX IF NOT EXISTS idx_actions_type ON website_actions(action_type);
            CREATE INDEX IF NOT EXISTS idx_actions_timestamp ON website_actions(timestamp);
            CREATE INDEX IF NOT EXISTS idx_actions_user ON website_actions(user_id);
        """

        let createTransactionsTable = """
            CREATE TABLE IF NOT EXISTS transactions (
                id VARCHAR(255) PRIMARY KEY,
                order_id VARCHAR(255) NOT NULL,
                amount DECIMAL(10, 2) NOT NULL,
                status VARCHAR(50) NOT NULL,
                payment_method VARCHAR(50),
                timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
            );

            CREATE INDEX IF NOT EXISTS idx_transactions_status ON transactions(status);
            CREATE INDEX IF NOT EXISTS idx_transactions_timestamp ON transactions(timestamp);
        """

        let createOrderItemsTable = """
            CREATE TABLE IF NOT EXISTS order_items (
                id SERIAL PRIMARY KEY,
                order_id VARCHAR(255) NOT NULL,
                product_id VARCHAR(255) NOT NULL,
                product_title VARCHAR(500),
                quantity INTEGER NOT NULL,
                unit_price DECIMAL(10, 2) NOT NULL,
                amount DECIMAL(10, 2) NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_order_items_product ON order_items(product_id);
        """

        _ = try await execute(createActionsTable)
        _ = try await execute(createTransactionsTable)
        _ = try await execute(createOrderItemsTable)
    }
}

// MARK: - Request/Response Types
struct QueryRequest: Encodable {
    let sql: String
    let params: [String]
}

struct QueryResponse<T: Decodable>: Decodable {
    let rows: [T]
    let rowCount: Int
}

struct ExecuteResponse: Decodable {
    let rowsAffected: Int
}

struct ActionStat: Decodable {
    let actionType: String
    let count: Int

    enum CodingKeys: String, CodingKey {
        case actionType = "action_type"
        case count
    }
}

struct ProductSalesData: Decodable, Identifiable {
    var id: String { productId }
    let productId: String
    let productTitle: String
    let totalQuantity: Int
    let totalRevenue: Double

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case productTitle = "product_title"
        case totalQuantity = "total_quantity"
        case totalRevenue = "total_revenue"
    }
}

struct CustomerAnalytics: Codable {
    let totalCustomers: Int
    let returningCustomers: Int
    let averageOrderValue: Double

    var retentionRate: Double {
        guard totalCustomers > 0 else { return 0 }
        return Double(returningCustomers) / Double(totalCustomers) * 100
    }
}

struct CountResult: Decodable {
    let count: Int
}

struct AvgResult: Decodable {
    let avg: Double
}

// MARK: - Error Types
enum PostgreSQLError: Error, LocalizedError {
    case notConnected
    case invalidResponse
    case queryError(message: String)
    case executionError(message: String)
    case connectionError(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to PostgreSQL"
        case .invalidResponse:
            return "Invalid response from database"
        case .queryError(let message):
            return "Query error: \(message)"
        case .executionError(let message):
            return "Execution error: \(message)"
        case .connectionError(let message):
            return "Connection error: \(message)"
        }
    }
}

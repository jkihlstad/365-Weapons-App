//
//  WebhookModels.swift
//  365WeaponsAdmin
//
//  Data models for webhook configuration and delivery tracking
//

import Foundation

// MARK: - Webhook Event Types
enum WebhookEvent: String, Codable, CaseIterable, Identifiable {
    case orderCreated = "order.created"
    case orderUpdated = "order.updated"
    case orderCompleted = "order.completed"
    case orderCancelled = "order.cancelled"
    case productCreated = "product.created"
    case productUpdated = "product.updated"
    case productDeleted = "product.deleted"
    case lowStock = "inventory.low_stock"
    case newInquiry = "inquiry.created"
    case inquiryUpdated = "inquiry.updated"
    case partnerCreated = "partner.created"
    case partnerUpdated = "partner.updated"
    case commissionEligible = "commission.eligible"
    case commissionPaid = "commission.paid"
    case paymentReceived = "payment.received"
    case paymentFailed = "payment.failed"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .orderCreated: return "Order Created"
        case .orderUpdated: return "Order Updated"
        case .orderCompleted: return "Order Completed"
        case .orderCancelled: return "Order Cancelled"
        case .productCreated: return "Product Created"
        case .productUpdated: return "Product Updated"
        case .productDeleted: return "Product Deleted"
        case .lowStock: return "Low Stock Alert"
        case .newInquiry: return "New Inquiry"
        case .inquiryUpdated: return "Inquiry Updated"
        case .partnerCreated: return "Partner Created"
        case .partnerUpdated: return "Partner Updated"
        case .commissionEligible: return "Commission Eligible"
        case .commissionPaid: return "Commission Paid"
        case .paymentReceived: return "Payment Received"
        case .paymentFailed: return "Payment Failed"
        }
    }

    var description: String {
        switch self {
        case .orderCreated: return "Triggered when a new order is placed"
        case .orderUpdated: return "Triggered when an order status changes"
        case .orderCompleted: return "Triggered when an order is marked complete"
        case .orderCancelled: return "Triggered when an order is cancelled"
        case .productCreated: return "Triggered when a new product is added"
        case .productUpdated: return "Triggered when a product is modified"
        case .productDeleted: return "Triggered when a product is removed"
        case .lowStock: return "Triggered when inventory falls below threshold"
        case .newInquiry: return "Triggered when a customer submits an inquiry"
        case .inquiryUpdated: return "Triggered when an inquiry status changes"
        case .partnerCreated: return "Triggered when a new partner signs up"
        case .partnerUpdated: return "Triggered when partner info is updated"
        case .commissionEligible: return "Triggered when a commission becomes eligible"
        case .commissionPaid: return "Triggered when a commission is paid out"
        case .paymentReceived: return "Triggered when payment is successfully processed"
        case .paymentFailed: return "Triggered when a payment attempt fails"
        }
    }

    var icon: String {
        switch self {
        case .orderCreated, .orderUpdated, .orderCompleted, .orderCancelled:
            return "list.clipboard"
        case .productCreated, .productUpdated, .productDeleted:
            return "cube.box"
        case .lowStock:
            return "exclamationmark.triangle"
        case .newInquiry, .inquiryUpdated:
            return "questionmark.circle"
        case .partnerCreated, .partnerUpdated:
            return "person.2"
        case .commissionEligible, .commissionPaid:
            return "dollarsign.circle"
        case .paymentReceived:
            return "checkmark.circle"
        case .paymentFailed:
            return "xmark.circle"
        }
    }

    var category: WebhookEventCategory {
        switch self {
        case .orderCreated, .orderUpdated, .orderCompleted, .orderCancelled:
            return .orders
        case .productCreated, .productUpdated, .productDeleted, .lowStock:
            return .products
        case .newInquiry, .inquiryUpdated:
            return .inquiries
        case .partnerCreated, .partnerUpdated:
            return .partners
        case .commissionEligible, .commissionPaid:
            return .commissions
        case .paymentReceived, .paymentFailed:
            return .payments
        }
    }
}

// MARK: - Webhook Event Categories
enum WebhookEventCategory: String, CaseIterable, Identifiable {
    case orders = "Orders"
    case products = "Products"
    case inquiries = "Inquiries"
    case partners = "Partners"
    case commissions = "Commissions"
    case payments = "Payments"

    var id: String { rawValue }

    var events: [WebhookEvent] {
        WebhookEvent.allCases.filter { $0.category == self }
    }

    var icon: String {
        switch self {
        case .orders: return "list.clipboard"
        case .products: return "cube.box"
        case .inquiries: return "questionmark.circle"
        case .partners: return "person.2"
        case .commissions: return "dollarsign.circle"
        case .payments: return "creditcard"
        }
    }
}

// MARK: - Webhook Configuration
struct WebhookConfiguration: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var url: String
    var events: [WebhookEvent]
    var isActive: Bool
    var secret: String
    let createdAt: Date
    var updatedAt: Date?
    var lastTriggeredAt: Date?
    var failureCount: Int
    var headers: [String: String]?
    var retryEnabled: Bool
    var maxRetries: Int

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, url, events, isActive, secret, createdAt, updatedAt
        case lastTriggeredAt, failureCount, headers, retryEnabled, maxRetries
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        url: String,
        events: [WebhookEvent],
        isActive: Bool = true,
        secret: String = "",
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        lastTriggeredAt: Date? = nil,
        failureCount: Int = 0,
        headers: [String: String]? = nil,
        retryEnabled: Bool = true,
        maxRetries: Int = 3
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.events = events
        self.isActive = isActive
        self.secret = secret.isEmpty ? WebhookConfiguration.generateSecret() : secret
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastTriggeredAt = lastTriggeredAt
        self.failureCount = failureCount
        self.headers = headers
        self.retryEnabled = retryEnabled
        self.maxRetries = maxRetries
    }

    static func == (lhs: WebhookConfiguration, rhs: WebhookConfiguration) -> Bool {
        lhs.id == rhs.id
    }

    // Generate a secure random secret for webhook signatures
    static func generateSecret(length: Int = 32) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var secret = "whsec_"
        for _ in 0..<length {
            let randomIndex = Int.random(in: 0..<characters.count)
            let index = characters.index(characters.startIndex, offsetBy: randomIndex)
            secret.append(characters[index])
        }
        return secret
    }

    // Masked secret for display (shows only last 4 characters)
    var maskedSecret: String {
        guard secret.count > 10 else { return String(repeating: "*", count: 8) }
        let lastFour = String(secret.suffix(4))
        return "whsec_" + String(repeating: "*", count: 24) + lastFour
    }

    // Check if webhook has recent failures
    var hasRecentFailures: Bool {
        failureCount > 0
    }

    // Status indicator
    var status: WebhookStatus {
        if !isActive {
            return .disabled
        } else if failureCount >= maxRetries {
            return .failing
        } else if failureCount > 0 {
            return .warning
        } else {
            return .healthy
        }
    }
}

// MARK: - Webhook Status
enum WebhookStatus: String {
    case healthy = "Healthy"
    case warning = "Warning"
    case failing = "Failing"
    case disabled = "Disabled"

    var color: String {
        switch self {
        case .healthy: return "green"
        case .warning: return "orange"
        case .failing: return "red"
        case .disabled: return "gray"
        }
    }

    var icon: String {
        switch self {
        case .healthy: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .failing: return "xmark.circle.fill"
        case .disabled: return "pause.circle.fill"
        }
    }
}

// MARK: - Webhook Delivery
struct WebhookDelivery: Codable, Identifiable {
    let id: String
    let webhookId: String
    let event: WebhookEvent
    let payload: String
    let requestHeaders: [String: String]?
    let response: String?
    let responseHeaders: [String: String]?
    let statusCode: Int?
    let timestamp: Date
    let duration: TimeInterval?
    let success: Bool
    let retryCount: Int
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case webhookId, event, payload, requestHeaders, response, responseHeaders
        case statusCode, timestamp, duration, success, retryCount, errorMessage
    }

    init(
        id: String = UUID().uuidString,
        webhookId: String,
        event: WebhookEvent,
        payload: String,
        requestHeaders: [String: String]? = nil,
        response: String? = nil,
        responseHeaders: [String: String]? = nil,
        statusCode: Int? = nil,
        timestamp: Date = Date(),
        duration: TimeInterval? = nil,
        success: Bool,
        retryCount: Int = 0,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.webhookId = webhookId
        self.event = event
        self.payload = payload
        self.requestHeaders = requestHeaders
        self.response = response
        self.responseHeaders = responseHeaders
        self.statusCode = statusCode
        self.timestamp = timestamp
        self.duration = duration
        self.success = success
        self.retryCount = retryCount
        self.errorMessage = errorMessage
    }

    // Formatted status code display
    var statusCodeDisplay: String {
        guard let code = statusCode else { return "N/A" }
        return "\(code)"
    }

    // Duration formatted as milliseconds
    var durationFormatted: String {
        guard let duration = duration else { return "N/A" }
        return String(format: "%.0fms", duration * 1000)
    }

    // Truncated payload for preview
    var payloadPreview: String {
        let maxLength = 100
        if payload.count <= maxLength {
            return payload
        }
        return String(payload.prefix(maxLength)) + "..."
    }

    // Truncated response for preview
    var responsePreview: String? {
        guard let response = response else { return nil }
        let maxLength = 100
        if response.count <= maxLength {
            return response
        }
        return String(response.prefix(maxLength)) + "..."
    }
}

// MARK: - Webhook Test Result
struct WebhookTestResult: Codable {
    let webhookId: String
    let success: Bool
    let statusCode: Int?
    let response: String?
    let duration: TimeInterval?
    let errorMessage: String?
    let timestamp: Date

    var isSuccessStatusCode: Bool {
        guard let code = statusCode else { return false }
        return code >= 200 && code < 300
    }
}

// MARK: - Webhook Payload
struct WebhookPayload: Codable {
    let id: String
    let event: String
    let timestamp: Date
    let data: [String: AnyCodable]
    let webhookId: String
    let signature: String?

    init(event: WebhookEvent, data: [String: AnyCodable], webhookId: String, secret: String? = nil) {
        self.id = UUID().uuidString
        self.event = event.rawValue
        self.timestamp = Date()
        self.data = data
        self.webhookId = webhookId

        // Generate signature if secret provided
        if let secret = secret {
            self.signature = WebhookPayload.generateSignature(
                timestamp: self.timestamp,
                payload: self.id,
                secret: secret
            )
        } else {
            self.signature = nil
        }
    }

    // Generate HMAC signature for webhook verification
    static func generateSignature(timestamp: Date, payload: String, secret: String) -> String {
        let timestampString = String(Int(timestamp.timeIntervalSince1970))
        let signaturePayload = "\(timestampString).\(payload)"

        // In production, use CryptoKit for proper HMAC-SHA256
        // For now, return a placeholder format
        let hash = signaturePayload.data(using: .utf8)?.base64EncodedString() ?? ""
        return "sha256=\(hash)"
    }
}

// Note: AnyCodable is defined in LangGraphService.swift

// MARK: - URL Validation Extension
extension String {
    var isValidWebhookURL: Bool {
        guard let url = URL(string: self) else { return false }

        // Must have a valid scheme (http or https)
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return false
        }

        // Must have a host
        guard url.host != nil, !url.host!.isEmpty else {
            return false
        }

        // Should not be localhost in production (but allow for testing)
        // In a real app, you might want to restrict this

        return true
    }

    var webhookURLValidationError: String? {
        if self.isEmpty {
            return "URL is required"
        }

        guard let url = URL(string: self) else {
            return "Invalid URL format"
        }

        guard let scheme = url.scheme?.lowercased() else {
            return "URL must start with http:// or https://"
        }

        if scheme != "http" && scheme != "https" {
            return "URL must use HTTP or HTTPS protocol"
        }

        guard url.host != nil, !url.host!.isEmpty else {
            return "URL must include a valid host"
        }

        return nil
    }
}

// MARK: - Date Extension for Webhook
extension Date {
    var timeAgo: String {
        let interval = Date().timeIntervalSince(self)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: self)
        }
    }
}

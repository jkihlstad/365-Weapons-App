//
//  SyncModels.swift
//  365WeaponsAdmin
//
//  Models for offline sync and caching functionality
//

import Foundation

// MARK: - Pending Action
/// Represents an action that needs to be synced when the device comes back online
struct PendingAction: Codable, Identifiable, Equatable {
    let id: UUID
    let type: PendingActionType
    let payload: Data
    let timestamp: Date
    var retryCount: Int
    let maxRetries: Int

    init(
        id: UUID = UUID(),
        type: PendingActionType,
        payload: Data,
        timestamp: Date = Date(),
        retryCount: Int = 0,
        maxRetries: Int = 3
    ) {
        self.id = id
        self.type = type
        self.payload = payload
        self.timestamp = timestamp
        self.retryCount = retryCount
        self.maxRetries = maxRetries
    }

    var canRetry: Bool {
        retryCount < maxRetries
    }

    mutating func incrementRetry() {
        retryCount += 1
    }

    static func == (lhs: PendingAction, rhs: PendingAction) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Pending Action Type
enum PendingActionType: String, Codable, CaseIterable {
    // Order actions
    case updateOrderStatus = "UPDATE_ORDER_STATUS"
    case createOrder = "CREATE_ORDER"

    // Product actions
    case createProduct = "CREATE_PRODUCT"
    case updateProduct = "UPDATE_PRODUCT"
    case deleteProduct = "DELETE_PRODUCT"

    // Inquiry actions
    case updateInquiry = "UPDATE_INQUIRY"
    case respondToInquiry = "RESPOND_TO_INQUIRY"

    // Partner actions
    case updatePartner = "UPDATE_PARTNER"

    // Commission actions
    case approveCommission = "APPROVE_COMMISSION"
    case payCommission = "PAY_COMMISSION"

    var displayName: String {
        switch self {
        case .updateOrderStatus: return "Update Order Status"
        case .createOrder: return "Create Order"
        case .createProduct: return "Create Product"
        case .updateProduct: return "Update Product"
        case .deleteProduct: return "Delete Product"
        case .updateInquiry: return "Update Inquiry"
        case .respondToInquiry: return "Respond to Inquiry"
        case .updatePartner: return "Update Partner"
        case .approveCommission: return "Approve Commission"
        case .payCommission: return "Pay Commission"
        }
    }

    var icon: String {
        switch self {
        case .updateOrderStatus, .createOrder: return "list.clipboard"
        case .createProduct, .updateProduct, .deleteProduct: return "cube.box"
        case .updateInquiry, .respondToInquiry: return "questionmark.circle"
        case .updatePartner: return "building.2"
        case .approveCommission, .payCommission: return "dollarsign.circle"
        }
    }
}

// MARK: - Sync Status
/// Represents the synchronization status of data
enum SyncStatus: String, Codable, CaseIterable {
    case synced = "SYNCED"
    case pending = "PENDING"
    case failed = "FAILED"
    case syncing = "SYNCING"

    var displayName: String {
        switch self {
        case .synced: return "Synced"
        case .pending: return "Pending"
        case .failed: return "Failed"
        case .syncing: return "Syncing"
        }
    }

    var icon: String {
        switch self {
        case .synced: return "checkmark.circle.fill"
        case .pending: return "clock.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .syncing: return "arrow.triangle.2.circlepath"
        }
    }

    var color: String {
        switch self {
        case .synced: return "green"
        case .pending: return "orange"
        case .failed: return "red"
        case .syncing: return "blue"
        }
    }
}

// MARK: - Cache Metadata
/// Metadata about cached data items
struct CacheMetadata: Codable, Identifiable, Equatable {
    let id: UUID
    let key: String
    let size: Int
    let createdAt: Date
    let expiresAt: Date?
    let dataType: CachedDataType

    init(
        id: UUID = UUID(),
        key: String,
        size: Int,
        createdAt: Date = Date(),
        expiresAt: Date?,
        dataType: CachedDataType
    ) {
        self.id = id
        self.key = key
        self.size = size
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.dataType = dataType
    }

    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }

    var timeUntilExpiration: TimeInterval? {
        guard let expiresAt = expiresAt else { return nil }
        return expiresAt.timeIntervalSinceNow
    }

    static func == (lhs: CacheMetadata, rhs: CacheMetadata) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Cached Data Type
enum CachedDataType: String, Codable, CaseIterable {
    case dashboard = "DASHBOARD"
    case orders = "ORDERS"
    case products = "PRODUCTS"
    case partners = "PARTNERS"
    case commissions = "COMMISSIONS"
    case inquiries = "INQUIRIES"
    case userProfile = "USER_PROFILE"
    case analytics = "ANALYTICS"
    case other = "OTHER"

    var displayName: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .orders: return "Orders"
        case .products: return "Products"
        case .partners: return "Partners"
        case .commissions: return "Commissions"
        case .inquiries: return "Inquiries"
        case .userProfile: return "User Profile"
        case .analytics: return "Analytics"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "chart.bar.xaxis"
        case .orders: return "list.clipboard"
        case .products: return "cube.box"
        case .partners: return "building.2"
        case .commissions: return "dollarsign.circle"
        case .inquiries: return "questionmark.circle"
        case .userProfile: return "person.circle"
        case .analytics: return "chart.line.uptrend.xyaxis"
        case .other: return "folder"
        }
    }

    /// Default cache expiration time in seconds
    var defaultExpiration: TimeInterval {
        switch self {
        case .dashboard: return 60            // 1 minute
        case .orders: return 120              // 2 minutes
        case .products: return 300            // 5 minutes
        case .partners: return 600            // 10 minutes
        case .commissions: return 300         // 5 minutes
        case .inquiries: return 120           // 2 minutes
        case .userProfile: return 1800        // 30 minutes
        case .analytics: return 300           // 5 minutes
        case .other: return 300               // 5 minutes
        }
    }
}

// MARK: - Sync Event
/// Represents a sync event for logging and debugging
struct SyncEvent: Codable, Identifiable {
    let id: UUID
    let type: SyncEventType
    let timestamp: Date
    let details: String?
    let success: Bool
    let errorMessage: String?

    init(
        id: UUID = UUID(),
        type: SyncEventType,
        timestamp: Date = Date(),
        details: String? = nil,
        success: Bool = true,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.details = details
        self.success = success
        self.errorMessage = errorMessage
    }
}

enum SyncEventType: String, Codable {
    case syncStarted = "SYNC_STARTED"
    case syncCompleted = "SYNC_COMPLETED"
    case syncFailed = "SYNC_FAILED"
    case actionQueued = "ACTION_QUEUED"
    case actionExecuted = "ACTION_EXECUTED"
    case actionFailed = "ACTION_FAILED"
    case cacheHit = "CACHE_HIT"
    case cacheMiss = "CACHE_MISS"
    case cacheExpired = "CACHE_EXPIRED"
    case cacheCleared = "CACHE_CLEARED"
    case networkOnline = "NETWORK_ONLINE"
    case networkOffline = "NETWORK_OFFLINE"
}

// MARK: - Cached Wrapper
/// Generic wrapper for cached data with metadata
struct CachedData<T: Codable>: Codable {
    let data: T
    let cachedAt: Date
    let expiresAt: Date?
    let syncStatus: SyncStatus

    init(
        data: T,
        cachedAt: Date = Date(),
        expiresAt: Date? = nil,
        syncStatus: SyncStatus = .synced
    ) {
        self.data = data
        self.cachedAt = cachedAt
        self.expiresAt = expiresAt
        self.syncStatus = syncStatus
    }

    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }

    var age: TimeInterval {
        Date().timeIntervalSince(cachedAt)
    }

    var formattedAge: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: cachedAt, relativeTo: Date())
    }
}

// MARK: - Offline Action Payloads

/// Payload for updating order status
struct UpdateOrderStatusPayload: Codable {
    let orderId: String
    let newStatus: String
    let previousStatus: String?
    let note: String?
}

/// Payload for creating a product
struct CreateProductPayload: Codable {
    let title: String
    let description: String?
    let price: Double
    let priceRange: String?
    let category: String
    let image: String
    let inStock: Bool
    let hasOptions: Bool?
}

/// Payload for updating a product
struct UpdateProductPayload: Codable {
    let productId: String
    let updates: [String: String] // Simplified for Codable compliance
}

/// Payload for inquiry actions
struct UpdateInquiryPayload: Codable {
    let inquiryId: String
    let status: String?
    let quotedAmount: Double?
    let adminNotes: String?
}

//
//  DataModels.swift
//  365WeaponsAdmin
//
//  Data models mirroring Convex backend schema
//

import Foundation

// MARK: - Admin User
struct AdminUser: Codable, Identifiable {
    let id: String
    let email: String
    let name: String?
    let avatarUrl: String?

    var displayName: String {
        name ?? email.components(separatedBy: "@").first ?? "Admin"
    }
}

// MARK: - Product
struct Product: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var description: String?
    var price: Double
    var priceRange: String?
    var category: String
    var image: String
    var stripeProductId: String?
    var stripePriceId: String?
    var inStock: Bool
    var hasOptions: Bool?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title, description, price, priceRange, category, image
        case stripeProductId, stripePriceId, inStock, hasOptions, createdAt
    }

    var formattedPrice: String {
        if let range = priceRange, !range.isEmpty {
            return range
        }
        return String(format: "$%.2f", price)
    }
}

// MARK: - Order
struct Order: Codable, Identifiable {
    let id: String
    let orderNumber: String
    let placedBy: OrderPlacedBy
    let partnerStoreId: String?
    let partnerCodeUsed: String?
    let serviceType: ServiceType?
    let status: OrderStatus
    let totals: OrderTotals?
    let userEmail: String?
    let endCustomerInfo: CustomerInfo?
    let billingAddress: Address?
    let returnShippingAddressSnapshot: Address?
    let createdAt: Date
    let paidAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case orderNumber, placedBy, partnerStoreId, partnerCodeUsed
        case serviceType, status, totals, userEmail, endCustomerInfo
        case billingAddress, returnShippingAddressSnapshot, createdAt, paidAt
    }

    var formattedTotal: String {
        guard let total = totals?.total else { return "$0.00" }
        return String(format: "$%.2f", Double(total) / 100.0)
    }

    var customerEmail: String {
        endCustomerInfo?.email ?? userEmail ?? "Unknown"
    }
}

enum OrderPlacedBy: String, Codable {
    case customer = "CUSTOMER"
    case partner = "PARTNER"
}

enum ServiceType: String, Codable, CaseIterable {
    case porting = "PORTING"
    case opticCut = "OPTIC_CUT"
    case slideEngraving = "SLIDE_ENGRAVING"
    case other = "OTHER"

    var displayName: String {
        switch self {
        case .porting: return "Porting"
        case .opticCut: return "Optic Cut"
        case .slideEngraving: return "Slide Engraving"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .porting: return "wrench.and.screwdriver"
        case .opticCut: return "scope"
        case .slideEngraving: return "pencil.and.scribble"
        case .other: return "cube"
        }
    }
}

enum OrderStatus: String, Codable, CaseIterable {
    case awaitingPayment = "AWAITING_PAYMENT"
    case awaitingShipment = "AWAITING_SHIPMENT"
    case inProgress = "IN_PROGRESS"
    case completed = "COMPLETED"
    case cancelled = "CANCELLED"

    var displayName: String {
        switch self {
        case .awaitingPayment: return "Awaiting Payment"
        case .awaitingShipment: return "Awaiting Shipment"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }

    var color: String {
        switch self {
        case .awaitingPayment: return "orange"
        case .awaitingShipment: return "blue"
        case .inProgress: return "purple"
        case .completed: return "green"
        case .cancelled: return "red"
        }
    }
}

struct OrderTotals: Codable {
    let subtotal: Int
    let discountAmount: Int?
    let tax: Int?
    let shipping: Int?
    let total: Int
}

struct CustomerInfo: Codable {
    let name: String?
    let phone: String?
    let email: String?
}

struct Address: Codable {
    let street: String?
    let city: String?
    let state: String?
    let zip: String?
    let country: String?

    var formatted: String {
        [street, city, state, zip, country]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

// MARK: - Partner Store
struct PartnerStore: Codable, Identifiable {
    let id: String
    let storeName: String
    let storeCode: String
    let active: Bool
    let storeContactName: String
    let storePhone: String
    let storeEmail: String
    let storeReturnAddress: Address?
    let commissionType: CommissionType
    let commissionValue: Double
    let payoutMethod: String
    let paypalEmail: String
    let payoutHoldDays: Int
    let onboardingComplete: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case storeName, storeCode, active, storeContactName, storePhone, storeEmail
        case storeReturnAddress, commissionType, commissionValue, payoutMethod
        case paypalEmail, payoutHoldDays, onboardingComplete, createdAt
    }

    var formattedCommission: String {
        switch commissionType {
        case .percentage:
            return "\(Int(commissionValue * 100))%"
        case .flat, .perService:
            return String(format: "$%.2f", commissionValue)
        }
    }
}

enum CommissionType: String, Codable {
    case percentage
    case flat
    case perService
}

// MARK: - Commission
struct Commission: Codable, Identifiable {
    let id: String
    let partnerStoreId: String
    let orderId: String
    let orderNumber: String
    let placedBy: String
    let serviceType: String?
    let commissionBaseAmount: Double
    let commissionAmount: Double
    let status: CommissionStatus
    let eligibleAt: Date?
    let createdAt: Date
    let paidAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case partnerStoreId, orderId, orderNumber, placedBy, serviceType
        case commissionBaseAmount, commissionAmount, status
        case eligibleAt, createdAt, paidAt
    }

    var formattedAmount: String {
        String(format: "$%.2f", commissionAmount)
    }
}

enum CommissionStatus: String, Codable, CaseIterable {
    case pending = "PENDING"
    case eligible = "ELIGIBLE"
    case approved = "APPROVED"
    case paid = "PAID"
    case voided = "VOIDED"

    var displayName: String {
        rawValue.capitalized
    }

    var color: String {
        switch self {
        case .pending: return "orange"
        case .eligible: return "blue"
        case .approved: return "purple"
        case .paid: return "green"
        case .voided: return "red"
        }
    }
}

// MARK: - Service Inquiry
struct ServiceInquiry: Codable, Identifiable {
    let id: String
    let customerName: String
    let customerEmail: String
    let customerPhone: String?
    let serviceType: String
    let productSlug: String
    let productTitle: String
    let message: String?
    let status: InquiryStatus
    let quotedAmount: Double?
    let adminNotes: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case customerName, customerEmail, customerPhone
        case serviceType, productSlug, productTitle, message
        case status, quotedAmount, adminNotes, createdAt, updatedAt
    }

    var formattedQuote: String? {
        guard let amount = quotedAmount else { return nil }
        return String(format: "$%.2f", amount)
    }
}

enum InquiryStatus: String, Codable, CaseIterable {
    case new = "NEW"
    case reviewed = "REVIEWED"
    case quoted = "QUOTED"
    case invoiceSent = "INVOICE_SENT"
    case paid = "PAID"
    case inProgress = "IN_PROGRESS"
    case completed = "COMPLETED"
    case cancelled = "CANCELLED"

    var displayName: String {
        switch self {
        case .new: return "New"
        case .reviewed: return "Reviewed"
        case .quoted: return "Quoted"
        case .invoiceSent: return "Invoice Sent"
        case .paid: return "Paid"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
}

// MARK: - Discount Code
struct DiscountCode: Codable, Identifiable {
    let id: String
    let code: String
    let partnerStoreId: String?
    let discountType: DiscountType
    let discountValue: Double
    let usageCount: Int
    let maxUsage: Int?
    let active: Bool
    let expiresAt: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case code, partnerStoreId, discountType, discountValue
        case usageCount, maxUsage, active, expiresAt, createdAt
    }

    var formattedDiscount: String {
        switch discountType {
        case .percentage:
            return "\(Int(discountValue * 100))% off"
        case .fixed:
            return String(format: "$%.2f off", discountValue)
        }
    }
}

enum DiscountType: String, Codable {
    case percentage
    case fixed
}

// MARK: - Dashboard Analytics
struct DashboardStats: Codable {
    let totalRevenue: Double
    let totalOrders: Int
    let totalProducts: Int
    let totalPartners: Int
    let pendingOrders: Int
    let pendingInquiries: Int
    let eligibleCommissions: Double
    let revenueGrowth: Double
    let orderGrowth: Double
}

struct RevenueDataPoint: Identifiable, Codable {
    var id: UUID = UUID()
    let date: Date
    let revenue: Double
    let orders: Int

    enum CodingKeys: String, CodingKey {
        case date, revenue, orders
    }

    init(date: Date, revenue: Double, orders: Int) {
        self.id = UUID()
        self.date = date
        self.revenue = revenue
        self.orders = orders
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.date = try container.decode(Date.self, forKey: .date)
        self.revenue = try container.decode(Double.self, forKey: .revenue)
        self.orders = try container.decode(Int.self, forKey: .orders)
    }
}

struct CategorySales: Identifiable {
    let id = UUID()
    let category: String
    let sales: Double
    let percentage: Double
}

struct ServiceBreakdown: Identifiable {
    let id = UUID()
    let serviceType: ServiceType
    let count: Int
    let revenue: Double
}

// MARK: - Website Action Tracking
struct WebsiteAction: Codable, Identifiable {
    let id: String
    let actionType: ActionType
    let description: String
    let userId: String?
    let userEmail: String?
    let metadata: [String: String]?
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case actionType, description, userId, userEmail, metadata, timestamp
    }
}

enum ActionType: String, Codable, CaseIterable {
    case pageView = "PAGE_VIEW"
    case productView = "PRODUCT_VIEW"
    case addToCart = "ADD_TO_CART"
    case checkout = "CHECKOUT"
    case purchase = "PURCHASE"
    case inquiry = "INQUIRY"
    case partnerSignup = "PARTNER_SIGNUP"
    case login = "LOGIN"
    case other = "OTHER"

    var icon: String {
        switch self {
        case .pageView: return "eye"
        case .productView: return "cube"
        case .addToCart: return "cart.badge.plus"
        case .checkout: return "creditcard"
        case .purchase: return "checkmark.circle"
        case .inquiry: return "questionmark.circle"
        case .partnerSignup: return "person.badge.plus"
        case .login: return "person.crop.circle"
        case .other: return "ellipsis.circle"
        }
    }

    var displayName: String {
        switch self {
        case .pageView: return "Page View"
        case .productView: return "Product View"
        case .addToCart: return "Add to Cart"
        case .checkout: return "Checkout"
        case .purchase: return "Purchase"
        case .inquiry: return "Inquiry"
        case .partnerSignup: return "Partner Signup"
        case .login: return "Login"
        case .other: return "Other"
        }
    }
}

// MARK: - AI Chat
struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: ChatRole
    let content: String
    let timestamp: Date
    var isLoading: Bool

    init(id: UUID = UUID(), role: ChatRole, content: String, timestamp: Date = Date(), isLoading: Bool = false) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isLoading = isLoading
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

enum ChatRole: String, Codable {
    case user
    case assistant
    case system
}

// MARK: - API Response Types
struct ConvexResponse<T: Codable>: Codable {
    let data: T?
    let error: String?
}

struct CreateProductRequest: Codable {
    let title: String
    let description: String?
    let price: Double
    let priceRange: String?
    let category: String
    let image: String
    let inStock: Bool
    let hasOptions: Bool?
}

struct UpdateOrderStatusRequest: Codable {
    let orderId: String
    let status: String
}

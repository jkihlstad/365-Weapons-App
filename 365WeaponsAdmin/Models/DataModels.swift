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

// MARK: - Order Item (for legacy orders)
struct OrderItem: Codable {
    let productId: String
    let title: String
    let price: Double
    let quantity: Int
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

    // Legacy fields for product orders
    let userId: String?
    let items: [OrderItem]?
    let total: Double?

    // Additional optional fields that Convex may return
    let customerPhone: String?
    let returnShippingAddressType: String?
    let selectedOptions: AnyCodable?
    let stripeCustomerId: String?
    let stripePaymentIntentId: String?
    let stripeSessionId: String?
    let notes: String?
    let trackingNumber: String?
    let completedAt: Date?
    let cancelledAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case orderNumber, placedBy, partnerStoreId, partnerCodeUsed
        case serviceType, status, totals, userEmail, endCustomerInfo
        case billingAddress, returnShippingAddressSnapshot, createdAt, paidAt
        case userId, items, total
        case customerPhone, returnShippingAddressType, selectedOptions
        case stripeCustomerId, stripePaymentIntentId, stripeSessionId
        case notes, trackingNumber, completedAt, cancelledAt
    }

    // Custom decoder to handle missing/extra fields gracefully
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        orderNumber = try container.decode(String.self, forKey: .orderNumber)
        placedBy = try container.decode(OrderPlacedBy.self, forKey: .placedBy)
        partnerStoreId = try container.decodeIfPresent(String.self, forKey: .partnerStoreId)
        partnerCodeUsed = try container.decodeIfPresent(String.self, forKey: .partnerCodeUsed)
        serviceType = try container.decodeIfPresent(ServiceType.self, forKey: .serviceType)

        // Decode status with fallback for unknown values
        if let statusValue = try? container.decode(OrderStatus.self, forKey: .status) {
            status = statusValue
        } else {
            let statusString = try container.decode(String.self, forKey: .status)
            status = OrderStatus(rawValue: statusString) ?? .pending
        }

        totals = try container.decodeIfPresent(OrderTotals.self, forKey: .totals)
        userEmail = try container.decodeIfPresent(String.self, forKey: .userEmail)
        endCustomerInfo = try container.decodeIfPresent(CustomerInfo.self, forKey: .endCustomerInfo)
        billingAddress = try container.decodeIfPresent(Address.self, forKey: .billingAddress)
        returnShippingAddressSnapshot = try container.decodeIfPresent(Address.self, forKey: .returnShippingAddressSnapshot)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        paidAt = try container.decodeIfPresent(Date.self, forKey: .paidAt)

        // Legacy fields
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        items = try container.decodeIfPresent([OrderItem].self, forKey: .items)
        total = try container.decodeIfPresent(Double.self, forKey: .total)

        // Additional optional fields
        customerPhone = try container.decodeIfPresent(String.self, forKey: .customerPhone)
        returnShippingAddressType = try container.decodeIfPresent(String.self, forKey: .returnShippingAddressType)
        selectedOptions = try container.decodeIfPresent(AnyCodable.self, forKey: .selectedOptions)
        stripeCustomerId = try container.decodeIfPresent(String.self, forKey: .stripeCustomerId)
        stripePaymentIntentId = try container.decodeIfPresent(String.self, forKey: .stripePaymentIntentId)
        stripeSessionId = try container.decodeIfPresent(String.self, forKey: .stripeSessionId)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        trackingNumber = try container.decodeIfPresent(String.self, forKey: .trackingNumber)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        cancelledAt = try container.decodeIfPresent(Date.self, forKey: .cancelledAt)
    }

    // Manual initializer for mock data
    init(
        id: String,
        orderNumber: String,
        placedBy: OrderPlacedBy,
        partnerStoreId: String? = nil,
        partnerCodeUsed: String? = nil,
        serviceType: ServiceType? = nil,
        status: OrderStatus,
        totals: OrderTotals? = nil,
        userEmail: String? = nil,
        endCustomerInfo: CustomerInfo? = nil,
        billingAddress: Address? = nil,
        returnShippingAddressSnapshot: Address? = nil,
        createdAt: Date,
        paidAt: Date? = nil,
        userId: String? = nil,
        items: [OrderItem]? = nil,
        total: Double? = nil,
        customerPhone: String? = nil,
        returnShippingAddressType: String? = nil,
        selectedOptions: AnyCodable? = nil,
        stripeCustomerId: String? = nil,
        stripePaymentIntentId: String? = nil,
        stripeSessionId: String? = nil,
        notes: String? = nil,
        trackingNumber: String? = nil,
        completedAt: Date? = nil,
        cancelledAt: Date? = nil
    ) {
        self.id = id
        self.orderNumber = orderNumber
        self.placedBy = placedBy
        self.partnerStoreId = partnerStoreId
        self.partnerCodeUsed = partnerCodeUsed
        self.serviceType = serviceType
        self.status = status
        self.totals = totals
        self.userEmail = userEmail
        self.endCustomerInfo = endCustomerInfo
        self.billingAddress = billingAddress
        self.returnShippingAddressSnapshot = returnShippingAddressSnapshot
        self.createdAt = createdAt
        self.paidAt = paidAt
        self.userId = userId
        self.items = items
        self.total = total
        self.customerPhone = customerPhone
        self.returnShippingAddressType = returnShippingAddressType
        self.selectedOptions = selectedOptions
        self.stripeCustomerId = stripeCustomerId
        self.stripePaymentIntentId = stripePaymentIntentId
        self.stripeSessionId = stripeSessionId
        self.notes = notes
        self.trackingNumber = trackingNumber
        self.completedAt = completedAt
        self.cancelledAt = cancelledAt
    }

    // Custom encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(orderNumber, forKey: .orderNumber)
        try container.encode(placedBy, forKey: .placedBy)
        try container.encodeIfPresent(partnerStoreId, forKey: .partnerStoreId)
        try container.encodeIfPresent(partnerCodeUsed, forKey: .partnerCodeUsed)
        try container.encodeIfPresent(serviceType, forKey: .serviceType)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(totals, forKey: .totals)
        try container.encodeIfPresent(userEmail, forKey: .userEmail)
        try container.encodeIfPresent(endCustomerInfo, forKey: .endCustomerInfo)
        try container.encodeIfPresent(billingAddress, forKey: .billingAddress)
        try container.encodeIfPresent(returnShippingAddressSnapshot, forKey: .returnShippingAddressSnapshot)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(paidAt, forKey: .paidAt)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encodeIfPresent(items, forKey: .items)
        try container.encodeIfPresent(total, forKey: .total)
        try container.encodeIfPresent(customerPhone, forKey: .customerPhone)
        try container.encodeIfPresent(returnShippingAddressType, forKey: .returnShippingAddressType)
        try container.encodeIfPresent(selectedOptions, forKey: .selectedOptions)
        try container.encodeIfPresent(stripeCustomerId, forKey: .stripeCustomerId)
        try container.encodeIfPresent(stripePaymentIntentId, forKey: .stripePaymentIntentId)
        try container.encodeIfPresent(stripeSessionId, forKey: .stripeSessionId)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(trackingNumber, forKey: .trackingNumber)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encodeIfPresent(cancelledAt, forKey: .cancelledAt)
    }

    var formattedTotal: String {
        guard let total = totals?.total else { return "$0.00" }
        return String(format: "$%.2f", total)
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
    case slidePolishing = "SLIDE_POLISHING"
    case otherService = "OTHER_SERVICE"
    case other = "OTHER"

    var displayName: String {
        switch self {
        case .porting: return "Porting"
        case .opticCut: return "Optic Cut"
        case .slideEngraving: return "Slide Engraving"
        case .slidePolishing: return "Slide Polishing"
        case .otherService: return "Other Service"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .porting: return "wrench.and.screwdriver"
        case .opticCut: return "scope"
        case .slideEngraving: return "pencil.and.scribble"
        case .slidePolishing: return "sparkles"
        case .otherService: return "wrench"
        case .other: return "cube"
        }
    }
}

enum OrderStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case awaitingPayment = "AWAITING_PAYMENT"
    case awaitingShipment = "AWAITING_SHIPMENT"
    case inProgress = "IN_PROGRESS"
    case completed = "COMPLETED"
    case cancelled = "CANCELLED"

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .awaitingPayment: return "Awaiting Payment"
        case .awaitingShipment: return "Awaiting Shipment"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }

    var color: String {
        switch self {
        case .pending: return "yellow"
        case .awaitingPayment: return "orange"
        case .awaitingShipment: return "blue"
        case .inProgress: return "purple"
        case .completed: return "green"
        case .cancelled: return "red"
        }
    }
}

struct OrderTotals: Codable {
    let subtotal: Double
    let discountAmount: Double?
    let tax: Double?
    let shipping: Double?
    let total: Double
}

struct CustomerInfo: Codable {
    let name: String?
    let phone: String?
    let email: String?
}

struct Address: Codable {
    // Fields for billingAddress format
    let addressLine1: String?
    let addressLine2: String?
    let fullName: String?
    let email: String?
    let phone: String?
    let zipCode: String?

    // Fields for returnShippingAddressSnapshot format
    let street: String?
    let name: String?
    let zip: String?

    // Common fields
    let city: String?
    let state: String?
    let country: String?

    // Computed property to get the street address regardless of format
    var streetAddress: String? {
        addressLine1 ?? street
    }

    // Computed property to get the zip code regardless of format
    var postalCode: String? {
        zipCode ?? zip
    }

    // Computed property to get the contact name regardless of format
    var contactName: String? {
        fullName ?? name
    }

    var formatted: String {
        [streetAddress, city, state, postalCode, country]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    // Custom initializer with defaults
    init(
        addressLine1: String? = nil,
        addressLine2: String? = nil,
        fullName: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        zipCode: String? = nil,
        street: String? = nil,
        name: String? = nil,
        zip: String? = nil,
        city: String? = nil,
        state: String? = nil,
        country: String? = nil
    ) {
        self.addressLine1 = addressLine1
        self.addressLine2 = addressLine2
        self.fullName = fullName
        self.email = email
        self.phone = phone
        self.zipCode = zipCode
        self.street = street
        self.name = name
        self.zip = zip
        self.city = city
        self.state = state
        self.country = country
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
    // Stripe integration
    let stripeCouponId: String?
    // Product restriction
    let productId: String?
    let isCustomProduct: Bool?
    // Commission settings
    let commissionEnabled: Bool?
    let commissionType: DiscountType?
    let commissionValue: Double?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case code, partnerStoreId, discountType, discountValue
        case usageCount, maxUsage, active, expiresAt, createdAt
        case stripeCouponId, productId, isCustomProduct
        case commissionEnabled, commissionType, commissionValue
    }

    var formattedDiscount: String {
        switch discountType {
        case .percentage:
            return "\(Int(discountValue * 100))% off"
        case .fixed:
            return String(format: "$%.2f off", discountValue)
        }
    }

    var formattedCommission: String? {
        guard let enabled = commissionEnabled, enabled,
              let type = commissionType,
              let value = commissionValue else { return nil }
        switch type {
        case .percentage:
            return "\(Int(value))% commission"
        case .fixed:
            return String(format: "$%.2f commission", value)
        }
    }

    /// Calculate discount amount for a given order total
    func discountAmount(for orderTotal: Double) -> Double {
        switch discountType {
        case .percentage:
            return orderTotal * discountValue
        case .fixed:
            return min(discountValue, orderTotal)
        }
    }

    /// Calculate commission amount for a given order total
    func commissionAmount(for orderTotal: Double) -> Double {
        guard let enabled = commissionEnabled, enabled,
              let type = commissionType,
              let value = commissionValue else { return 0 }
        let afterDiscount = orderTotal - discountAmount(for: orderTotal)
        switch type {
        case .percentage:
            return afterDiscount * (value / 100)
        case .fixed:
            return value
        }
    }
}

enum DiscountType: String, Codable, CaseIterable {
    case percentage
    case fixed

    var displayName: String {
        switch self {
        case .percentage: return "Percentage"
        case .fixed: return "Fixed Amount"
        }
    }
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


//
//  VendorModels.swift
//  365WeaponsAdmin
//
//  Extended data models for vendor management
//

import Foundation

// MARK: - Vendor Filter
enum VendorFilterStatus: String, CaseIterable, Identifiable {
    case all = "all"
    case active = "active"
    case inactive = "inactive"
    case pending = "pending"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "All Vendors"
        case .active: return "Active"
        case .inactive: return "Inactive"
        case .pending: return "Pending"
        }
    }
}

struct VendorFilter {
    var searchQuery: String = ""
    var status: VendorFilterStatus = .all
    var hasOrders: Bool?
    var minCommission: Double?

    var isActive: Bool {
        !searchQuery.isEmpty ||
        status != .all ||
        hasOrders != nil ||
        minCommission != nil
    }
}

// MARK: - Vendor Details
struct VendorDetails {
    let store: PartnerStore
    let users: [PartnerUser]
    let stats: VendorStats
    let recentOrders: [Order]
    let commissions: [Commission]
    let discountCodes: [DiscountCode]
}

// MARK: - Partner User
struct PartnerUser: Identifiable, Codable {
    let id: String
    let userId: String
    let partnerStoreId: String
    let role: PartnerUserRole
    let email: String?
    let name: String?
    let createdAt: Date
    let lastLoginAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId, partnerStoreId, role, email, name, createdAt, lastLoginAt
    }
}

enum PartnerUserRole: String, Codable, CaseIterable {
    case owner = "OWNER"
    case admin = "ADMIN"
    case staff = "STAFF"

    var displayName: String {
        rawValue.capitalized
    }

    var permissions: [String] {
        switch self {
        case .owner:
            return ["all"]
        case .admin:
            return ["orders", "commissions", "discounts", "settings"]
        case .staff:
            return ["orders", "view_commissions"]
        }
    }
}

// MARK: - Vendor Stats
struct VendorStats: Codable {
    let totalOrders: Int
    let totalRevenue: Double
    let commissionTotal: Double
    let commissionPaid: Double
    let commissionPending: Double
    let activeDiscountCodes: Int
    let averageOrderValue: Double
    let ordersByStatus: [String: Int]

    var commissionEarned: Double {
        commissionTotal
    }

    var formattedRevenue: String {
        String(format: "$%.2f", totalRevenue)
    }

    var formattedCommissionTotal: String {
        String(format: "$%.2f", commissionTotal)
    }

    var formattedCommissionPending: String {
        String(format: "$%.2f", commissionPending)
    }
}

// MARK: - Create Vendor Request
struct CreateVendorRequest: Codable {
    let storeName: String
    let storeCode: String
    let storeContactName: String
    let storePhone: String
    let storeEmail: String
    let commissionType: String
    let commissionValue: Double
    let payoutMethod: String
    let paypalEmail: String?
    let payoutHoldDays: Int
}

// MARK: - Update Vendor Request
struct UpdateVendorRequest: Codable {
    let storeName: String?
    let storeContactName: String?
    let storePhone: String?
    let storeEmail: String?
    let commissionType: String?
    let commissionValue: Double?
    let payoutMethod: String?
    let paypalEmail: String?
    let payoutHoldDays: Int?
    let active: Bool?
}

// MARK: - Payout Request
struct PayoutRequest: Codable {
    let partnerStoreId: String
    let commissionIds: [String]
    let amount: Double
    let payoutMethod: String
    let notes: String?
}

// MARK: - Payout Batch
struct PayoutBatch: Identifiable, Codable {
    let id: String
    let partnerStoreId: String
    let commissionIds: [String]
    let totalAmount: Double
    let status: PayoutStatus
    let payoutMethod: String
    let transactionId: String?
    let notes: String?
    let createdAt: Date
    let processedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case partnerStoreId, commissionIds, totalAmount, status
        case payoutMethod, transactionId, notes, createdAt, processedAt
    }

    var formattedAmount: String {
        String(format: "$%.2f", totalAmount)
    }
}

enum PayoutStatus: String, Codable, CaseIterable {
    case pending = "PENDING"
    case processing = "PROCESSING"
    case completed = "COMPLETED"
    case failed = "FAILED"

    var displayName: String {
        rawValue.capitalized
    }

    var color: String {
        switch self {
        case .pending: return "orange"
        case .processing: return "blue"
        case .completed: return "green"
        case .failed: return "red"
        }
    }
}

// MARK: - Vendor Invite
struct VendorInvite: Identifiable, Codable {
    let id: String
    let partnerStoreId: String
    let email: String
    let role: PartnerUserRole
    let invitedBy: String
    let status: InviteStatus
    let createdAt: Date
    let expiresAt: Date
    let acceptedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case partnerStoreId, email, role, invitedBy, status
        case createdAt, expiresAt, acceptedAt
    }
}

enum InviteStatus: String, Codable {
    case pending = "PENDING"
    case accepted = "ACCEPTED"
    case expired = "EXPIRED"
    case cancelled = "CANCELLED"

    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Vendor Activity
struct VendorActivity: Identifiable {
    let id: String
    let type: VendorActivityType
    let description: String
    let date: Date
    let metadata: [String: String]?
}

enum VendorActivityType: String, Codable {
    case orderPlaced = "ORDER_PLACED"
    case commissionEarned = "COMMISSION_EARNED"
    case payoutReceived = "PAYOUT_RECEIVED"
    case settingsUpdated = "SETTINGS_UPDATED"
    case userAdded = "USER_ADDED"
    case discountCreated = "DISCOUNT_CREATED"

    var icon: String {
        switch self {
        case .orderPlaced: return "cart.fill"
        case .commissionEarned: return "dollarsign.circle.fill"
        case .payoutReceived: return "banknote.fill"
        case .settingsUpdated: return "gear"
        case .userAdded: return "person.badge.plus"
        case .discountCreated: return "tag.fill"
        }
    }
}

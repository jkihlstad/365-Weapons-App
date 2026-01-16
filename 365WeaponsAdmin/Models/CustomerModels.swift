//
//  CustomerModels.swift
//  365WeaponsAdmin
//
//  Data models for unified customer management
//

import Foundation

// MARK: - Customer Source
enum CustomerSource: String, Codable, CaseIterable, Identifiable {
    case order = "order"
    case inquiry = "inquiry"
    case newsletter = "newsletter"
    case contact = "contact"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .order: return "Order"
        case .inquiry: return "Inquiry"
        case .newsletter: return "Newsletter"
        case .contact: return "Contact Form"
        }
    }

    var icon: String {
        switch self {
        case .order: return "cart"
        case .inquiry: return "questionmark.circle"
        case .newsletter: return "envelope"
        case .contact: return "message"
        }
    }

    var color: String {
        switch self {
        case .order: return "green"
        case .inquiry: return "blue"
        case .newsletter: return "purple"
        case .contact: return "orange"
        }
    }
}

// MARK: - Unified Customer
struct Customer: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let email: String
    let phone: String?
    let source: CustomerSource
    let orderCount: Int
    let totalSpent: Double
    let lastActivity: Date
    let addresses: [Address]?
    let createdAt: Date

    // For hashing
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Customer, rhs: Customer) -> Bool {
        lhs.id == rhs.id
    }

    var formattedTotalSpent: String {
        String(format: "$%.2f", totalSpent)
    }

    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Customer Filter
struct CustomerFilter {
    var searchQuery: String = ""
    var sources: Set<CustomerSource> = Set(CustomerSource.allCases)
    var hasOrders: Bool?
    var minSpent: Double?
    var maxSpent: Double?

    var isActive: Bool {
        !searchQuery.isEmpty ||
        sources.count != CustomerSource.allCases.count ||
        hasOrders != nil ||
        minSpent != nil ||
        maxSpent != nil
    }
}

// MARK: - Customer Stats
struct CustomerStats: Codable {
    let totalCustomers: Int
    let bySource: [String: Int]
    let totalRevenue: Double
    let averageOrderValue: Double
    let repeatCustomerRate: Double
}

// MARK: - Newsletter Subscriber
struct NewsletterSubscriber: Identifiable, Codable {
    let id: String
    let firstName: String?
    let lastName: String?
    let email: String
    let phone: String?
    let subscribedAt: Date
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case firstName, lastName, email, phone, subscribedAt, isActive
    }

    var fullName: String {
        [firstName, lastName].compactMap { $0 }.joined(separator: " ")
    }
}

// MARK: - Contact Submission
struct ContactSubmission: Identifiable, Codable {
    let id: String
    let name: String
    let email: String
    let phone: String?
    let subject: String?
    let message: String
    let status: ContactStatus
    let createdAt: Date
    let respondedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, email, phone, subject, message, status, createdAt, respondedAt
    }
}

enum ContactStatus: String, Codable, CaseIterable {
    case new = "NEW"
    case read = "READ"
    case responded = "RESPONDED"
    case archived = "ARCHIVED"

    var displayName: String {
        switch self {
        case .new: return "New"
        case .read: return "Read"
        case .responded: return "Responded"
        case .archived: return "Archived"
        }
    }
}

// MARK: - Customer Activity
struct CustomerActivity: Identifiable {
    let id: String
    let type: CustomerActivityType
    let description: String
    let date: Date
    let metadata: [String: String]?
}

enum CustomerActivityType: String, Codable {
    case order = "ORDER"
    case inquiry = "INQUIRY"
    case contact = "CONTACT"
    case newsletter = "NEWSLETTER"

    var icon: String {
        switch self {
        case .order: return "cart.fill"
        case .inquiry: return "questionmark.circle.fill"
        case .contact: return "message.fill"
        case .newsletter: return "envelope.fill"
        }
    }
}

// MARK: - Customer Export
struct CustomerExportData: Codable {
    let customers: [Customer]
    let exportedAt: Date
    let filters: String?
    let totalCount: Int
}

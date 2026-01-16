//
//  CodesViewModel.swift
//  365WeaponsAdmin
//
//  ViewModel for managing discount codes
//

import Foundation
import Combine

// MARK: - Product Restriction Option

enum ProductRestriction: Hashable {
    case allProducts
    case custom // For invoice-only use
    case specific(productId: String, productName: String)

    var displayName: String {
        switch self {
        case .allProducts: return "All Products"
        case .custom: return "Custom (Invoice Only)"
        case .specific(_, let name): return name
        }
    }
}

// MARK: - Enriched Discount Code (with partner/product names)

struct EnrichedDiscountCode: Identifiable, Codable {
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
    let stripeCouponId: String?
    let productId: String?
    let isCustomProduct: Bool?
    let commissionEnabled: Bool?
    let commissionType: DiscountType?
    let commissionValue: Double?
    // Enriched fields
    let partnerName: String?
    let productName: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case code, partnerStoreId, discountType, discountValue
        case usageCount, maxUsage, active, expiresAt, createdAt
        case stripeCouponId, productId, isCustomProduct
        case commissionEnabled, commissionType, commissionValue
        case partnerName, productName
    }

    var formattedDiscount: String {
        switch discountType {
        case .percentage:
            return "\(Int(discountValue))% off"
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
            return orderTotal * (discountValue / 100)
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

    var productRestriction: ProductRestriction {
        if let isCustom = isCustomProduct, isCustom {
            return .custom
        } else if let prodId = productId, let prodName = productName {
            return .specific(productId: prodId, productName: prodName)
        }
        return .allProducts
    }
}

// MARK: - Create Code Request

struct CreateDiscountCodeRequest: Encodable {
    let code: String
    let partnerStoreId: String
    let discountType: String
    let discountValue: Double
    let maxUsage: Int?
    let expiresAt: Int?
    let productId: String?
    let isCustomProduct: Bool?
    let commissionEnabled: Bool
    let commissionType: String?
    let commissionValue: Double?
}

// MARK: - Codes ViewModel

@MainActor
class CodesViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var codes: [EnrichedDiscountCode] = []
    @Published var filteredCodes: [EnrichedDiscountCode] = []
    @Published var isLoading = false
    @Published var error: Error?

    // Filter state
    @Published var searchText = ""
    @Published var showActiveOnly = false
    @Published var selectedPartnerFilter: String? = nil

    // Stats
    @Published var totalCodes = 0
    @Published var activeCodes = 0
    @Published var totalUsage = 0

    // Data for dropdowns
    @Published var partners: [PartnerStore] = []
    @Published var products: [Product] = []

    // MARK: - Dependencies
    private let convex = ConvexClient.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init() {
        setupFilters()
    }

    private func setupFilters() {
        Publishers.CombineLatest3(
            $searchText.debounce(for: .milliseconds(300), scheduler: DispatchQueue.main),
            $showActiveOnly,
            $selectedPartnerFilter
        )
        .sink { [weak self] searchText, activeOnly, partnerFilter in
            self?.applyFilters(searchText: searchText, activeOnly: activeOnly, partnerFilter: partnerFilter)
        }
        .store(in: &cancellables)
    }

    // MARK: - Data Loading

    func loadData() async {
        isLoading = true
        error = nil

        do {
            // Load codes, partners, and products in parallel
            async let codesTask = convex.fetchAllDiscountCodesEnriched()
            async let partnersTask = convex.fetchPartners()
            async let productsTask = convex.fetchProducts()

            let (fetchedCodes, fetchedPartners, fetchedProducts) = try await (
                codesTask,
                partnersTask,
                productsTask
            )

            codes = fetchedCodes
            partners = fetchedPartners
            products = fetchedProducts

            // Calculate stats
            totalCodes = codes.count
            activeCodes = codes.filter { $0.active }.count
            totalUsage = codes.reduce(0) { $0 + $1.usageCount }

            // Apply filters
            applyFilters(searchText: searchText, activeOnly: showActiveOnly, partnerFilter: selectedPartnerFilter)

        } catch {
            self.error = error
        }

        isLoading = false
    }

    func refresh() {
        Task {
            await loadData()
        }
    }

    // MARK: - Filtering

    private func applyFilters(searchText: String, activeOnly: Bool, partnerFilter: String?) {
        var result = codes

        // Filter by active status
        if activeOnly {
            result = result.filter { $0.active }
        }

        // Filter by partner
        if let partnerId = partnerFilter {
            result = result.filter { $0.partnerStoreId == partnerId }
        }

        // Filter by search text
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.code.lowercased().contains(query) ||
                ($0.partnerName?.lowercased().contains(query) ?? false) ||
                ($0.productName?.lowercased().contains(query) ?? false)
            }
        }

        filteredCodes = result
    }

    // MARK: - CRUD Operations

    func createCode(
        code: String,
        partnerStoreId: String,
        discountType: DiscountType,
        discountValue: Double,
        maxUsage: Int?,
        expiresAt: Date?,
        productRestriction: ProductRestriction,
        commissionEnabled: Bool,
        commissionType: DiscountType?,
        commissionValue: Double?
    ) async throws {
        var productId: String? = nil
        var isCustomProduct: Bool? = nil

        switch productRestriction {
        case .allProducts:
            break
        case .custom:
            isCustomProduct = true
        case .specific(let prodId, _):
            productId = prodId
        }

        try await convex.createDiscountCode(
            code: code,
            partnerStoreId: partnerStoreId,
            discountType: discountType.rawValue,
            discountValue: discountValue,
            maxUsage: maxUsage,
            expiresAt: expiresAt.map { Int($0.timeIntervalSince1970 * 1000) },
            productId: productId,
            isCustomProduct: isCustomProduct,
            commissionEnabled: commissionEnabled,
            commissionType: commissionEnabled ? commissionType?.rawValue : nil,
            commissionValue: commissionEnabled ? commissionValue : nil
        )

        // Refresh the list
        await loadData()
    }

    func toggleCodeActive(_ code: EnrichedDiscountCode) async throws {
        try await convex.updateDiscountCode(
            codeId: code.id,
            active: !code.active
        )
        await loadData()
    }

    func deleteCode(_ code: EnrichedDiscountCode) async throws {
        try await convex.deleteDiscountCode(codeId: code.id)
        await loadData()
    }

    // MARK: - Helpers

    func partnerName(for id: String?) -> String {
        guard let id = id else { return "Unknown" }
        return partners.first { $0.id == id }?.storeName ?? "Unknown"
    }
}

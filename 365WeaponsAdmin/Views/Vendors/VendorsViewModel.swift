//
//  VendorsViewModel.swift
//  365WeaponsAdmin
//
//  ViewModel for vendors/partners management
//

import Foundation
import Combine

@MainActor
class VendorsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var vendors: [PartnerStore] = []
    @Published var filteredVendors: [PartnerStore] = []
    @Published var selectedVendor: PartnerStore?
    @Published var vendorDetails: VendorDetails?
    @Published var isLoading = false
    @Published var isLoadingDetails = false
    @Published var searchText = ""
    @Published var selectedFilter: VendorFilterStatus = .all
    @Published var error: AppError?

    // MARK: - Dependencies
    private let convex = ConvexClient.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties
    var hasError: Bool {
        error != nil
    }

    var activeCount: Int {
        vendors.filter { $0.active }.count
    }

    var inactiveCount: Int {
        vendors.filter { !$0.active }.count
    }

    var pendingCount: Int {
        vendors.filter { !$0.onboardingComplete }.count
    }

    // MARK: - Initialization
    init() {
        setupBindings()
    }

    private func setupBindings() {
        Publishers.CombineLatest($searchText, $selectedFilter)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] searchText, filter in
                self?.applyFilters(searchText: searchText, filter: filter)
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Loading
    func loadVendors() async {
        isLoading = true
        error = nil

        do {
            vendors = try await convex.fetchPartners()
            applyFilters(searchText: searchText, filter: selectedFilter)
        } catch {
            self.error = AppError.from(error)
        }

        isLoading = false
    }

    func loadVendorDetails(vendorId: String) async {
        isLoadingDetails = true
        vendorDetails = nil

        do {
            guard let vendor = vendors.first(where: { $0.id == vendorId }) else {
                isLoadingDetails = false
                return
            }
            let commissions = try await convex.fetchPartnerCommissions(partnerId: vendorId)
            let allOrders = try await convex.fetchOrders(limit: 500)
            let vendorOrders = allOrders.filter { $0.partnerStoreId == vendorId }
            let discountCodes = try? await convex.fetchDiscountCodes(partnerStoreId: vendorId)

            // Calculate stats
            let totalOrders = vendorOrders.count
            let totalRevenue = vendorOrders.compactMap { $0.totals?.total }.reduce(0, +)
            let commissionTotal = commissions.reduce(0) { $0 + $1.commissionAmount }
            let commissionPaid = commissions.filter { $0.status == .paid }.reduce(0) { $0 + $1.commissionAmount }
            let commissionPending = commissions.filter { $0.status == .pending || $0.status == .eligible }.reduce(0) { $0 + $1.commissionAmount }

            var ordersByStatus: [String: Int] = [:]
            for order in vendorOrders {
                ordersByStatus[order.status.rawValue, default: 0] += 1
            }

            let stats = VendorStats(
                totalOrders: totalOrders,
                totalRevenue: totalRevenue,
                commissionTotal: commissionTotal,
                commissionPaid: commissionPaid,
                commissionPending: commissionPending,
                activeDiscountCodes: discountCodes?.filter { $0.active }.count ?? 0,
                averageOrderValue: totalOrders > 0 ? totalRevenue / Double(totalOrders) : 0,
                ordersByStatus: ordersByStatus
            )

            vendorDetails = VendorDetails(
                store: vendor,
                users: [],
                stats: stats,
                recentOrders: Array(vendorOrders.prefix(10)),
                commissions: commissions,
                discountCodes: discountCodes ?? []
            )
        } catch {
            self.error = AppError.from(error)
        }

        isLoadingDetails = false
    }

    // MARK: - Filtering
    private func applyFilters(searchText: String, filter: VendorFilterStatus) {
        var result = vendors

        // Apply search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.storeName.lowercased().contains(query) ||
                $0.storeCode.lowercased().contains(query) ||
                $0.storeEmail.lowercased().contains(query)
            }
        }

        // Apply status filter
        switch filter {
        case .all:
            break
        case .active:
            result = result.filter { $0.active }
        case .inactive:
            result = result.filter { !$0.active }
        case .pending:
            result = result.filter { !$0.onboardingComplete }
        }

        filteredVendors = result
    }

    func filterByStatus(_ status: VendorFilterStatus) {
        selectedFilter = status
    }

    // MARK: - Actions
    func selectVendor(_ vendor: PartnerStore) {
        selectedVendor = vendor
    }

    func refresh() {
        Task {
            await loadVendors()
        }
    }

    func clearError() {
        error = nil
    }

    func retry() {
        refresh()
    }
}

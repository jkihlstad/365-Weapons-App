//
//  OrdersViewModel.swift
//  365WeaponsAdmin
//
//  ViewModel for Orders data management following MVVM pattern with offline support
//

import Foundation
import Combine

// MARK: - Orders ViewModel
@MainActor
class OrdersViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var orders: [Order] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var error: OrdersError?
    @Published var searchText: String = ""
    @Published var selectedStatus: OrderStatus?
    @Published var selectedOrder: Order?

    // MARK: - Multi-Select Properties
    @Published var isSelectionMode: Bool = false
    @Published var selectedOrderIds: Set<String> = []
    @Published var isBulkOperationInProgress: Bool = false
    @Published var bulkOperationResult: BulkOperationResult?

    // MARK: - Pagination
    @Published var currentPage: Int = 0
    @Published var hasMorePages: Bool = true
    @Published var totalOrdersCount: Int = 0

    // MARK: - Offline Support
    @Published var isOffline: Bool = false
    @Published var isUsingCachedData: Bool = false
    @Published var lastCacheUpdate: Date?
    @Published var pendingUpdates: Int = 0

    // MARK: - Computed Properties
    var filteredOrders: [Order] {
        var result = orders

        // Filter by status
        if let status = selectedStatus {
            result = result.filter { $0.status == status }
        }

        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter {
                $0.orderNumber.localizedCaseInsensitiveContains(searchText) ||
                $0.customerEmail.localizedCaseInsensitiveContains(searchText) ||
                ($0.endCustomerInfo?.name?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return result
    }

    var orderCountByStatus: [OrderStatus: Int] {
        Dictionary(grouping: orders, by: { $0.status })
            .mapValues { $0.count }
    }

    var pendingOrdersCount: Int {
        orders.filter { $0.status == .awaitingPayment || $0.status == .awaitingShipment }.count
    }

    var inProgressOrdersCount: Int {
        orders.filter { $0.status == .inProgress }.count
    }

    var completedOrdersCount: Int {
        orders.filter { $0.status == .completed }.count
    }

    var hasError: Bool {
        error != nil
    }

    var errorMessage: String {
        error?.localizedDescription ?? ""
    }

    // MARK: - Multi-Select Computed Properties
    var selectedOrdersCount: Int {
        selectedOrderIds.count
    }

    var hasSelection: Bool {
        !selectedOrderIds.isEmpty
    }

    var allFilteredSelected: Bool {
        let filteredIds = Set(filteredOrders.map { $0.id })
        return !filteredIds.isEmpty && filteredIds.isSubset(of: selectedOrderIds)
    }

    var selectedOrders: [Order] {
        orders.filter { selectedOrderIds.contains($0.id) }
    }

    // MARK: - Dependencies
    private let convex = ConvexClient.shared
    private let offlineManager = OfflineManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    private let pageSize: Int = 50

    // MARK: - Initialization
    init() {
        setupSearchDebounce()
        setupOfflineObserver()
    }

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: - Offline Observer Setup
    private func setupOfflineObserver() {
        offlineManager.$isOnline
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isOnline in
                self?.isOffline = !isOnline
                if isOnline {
                    // Refresh data when coming back online
                    self?.refresh()
                }
            }
            .store(in: &cancellables)

        offlineManager.$pendingActions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] actions in
                self?.pendingUpdates = actions.filter { $0.type == .updateOrderStatus }.count
            }
            .store(in: &cancellables)
    }

    // MARK: - Search Debounce
    private func setupSearchDebounce() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self = self else { return }
                if !query.isEmpty {
                    Task {
                        await self.searchOrders(query: query)
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Loading

    /// Load orders from the backend
    func loadOrders() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil
        currentPage = 0

        // Check if we're offline
        if offlineManager.shouldUseCachedData() {
            await loadCachedOrders()
            isLoading = false
            return
        }

        do {
            let fetchedOrders = try await convex.fetchOrders(limit: pageSize)
            orders = fetchedOrders
            totalOrdersCount = fetchedOrders.count
            hasMorePages = fetchedOrders.count >= pageSize
            currentPage = 1

            // Cache the orders for offline use
            await cacheOrders()

            self.isUsingCachedData = false
            self.lastCacheUpdate = Date()

        } catch let fetchError {
            // Ignore cancelled request errors (e.g., when view refreshes)
            let nsError = fetchError as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                print("Request cancelled (normal during view refresh)")
            } else {
                self.error = OrdersError.loadFailed(fetchError.localizedDescription)
                print("Orders load error: \(fetchError)")

                // Fall back to cached data
                await loadCachedOrders()
            }
        }

        isLoading = false
    }

    /// Load more orders for pagination
    func loadMoreOrders() async {
        guard !isLoadingMore && hasMorePages else { return }

        isLoadingMore = true

        do {
            // Note: The current Convex client doesn't support offset pagination
            // In a real implementation, you would pass cursor/offset to the API
            let offset = currentPage * pageSize
            let fetchedOrders = try await convex.fetchOrders(limit: pageSize)

            // For now, simulate pagination by checking if we got fewer results
            if fetchedOrders.count < pageSize {
                hasMorePages = false
            }

            // Append unique orders only
            let existingIds = Set(orders.map { $0.id })
            let newOrders = fetchedOrders.filter { !existingIds.contains($0.id) }
            orders.append(contentsOf: newOrders)
            currentPage += 1

        } catch let fetchError {
            // Ignore cancelled request errors
            let nsError = fetchError as NSError
            if nsError.domain != NSURLErrorDomain || nsError.code != NSURLErrorCancelled {
                self.error = OrdersError.loadFailed(fetchError.localizedDescription)
            }
        }

        isLoadingMore = false
    }

    /// Refresh orders
    func refreshOrders() async {
        currentPage = 0
        hasMorePages = true
        await loadOrders()
    }

    /// Convenience method for pull-to-refresh and button actions
    func refresh() {
        Task {
            await refreshOrders()
        }
    }

    // MARK: - Cache Operations

    private func cacheOrders() async {
        let cache = CacheService.shared

        do {
            try await cache.cache(
                orders,
                forKey: CacheKeys.allOrders,
                expiration: CachedDataType.orders.defaultExpiration,
                dataType: .orders
            )
        } catch {
            print("Failed to cache orders: \(error)")
        }
    }

    private func loadCachedOrders() async {
        let cache = CacheService.shared

        do {
            if let cachedOrders: [Order] = try await cache.retrieve(forKey: CacheKeys.allOrders) {
                self.orders = cachedOrders
                self.totalOrdersCount = cachedOrders.count
                self.isUsingCachedData = true

                let metadata = await cache.getAllMetadata()
                if let ordersMeta = metadata.first(where: { $0.key == CacheKeys.allOrders }) {
                    self.lastCacheUpdate = ordersMeta.createdAt
                }
            }
        } catch {
            print("Failed to load cached orders: \(error)")
        }
    }

    // MARK: - Search

    /// Search orders by query
    func searchOrders(query: String) async {
        guard !query.isEmpty else {
            await loadOrders()
            return
        }

        // For now, search is done client-side via filteredOrders computed property
        // In a production app, you might want server-side search for large datasets
        // This method exists for future server-side search implementation
    }

    // MARK: - Filtering

    /// Filter orders by status
    func filterByStatus(_ status: OrderStatus?) {
        selectedStatus = status
    }

    /// Clear all filters
    func clearFilters() {
        selectedStatus = nil
        searchText = ""
    }

    // MARK: - Order Operations

    /// Update order status
    func updateOrderStatus(orderId: String, status: OrderStatus) async {
        // If offline, queue the action
        if !offlineManager.isOnline {
            await queueStatusUpdate(orderId: orderId, status: status)
            return
        }

        do {
            let success = try await convex.updateOrderStatus(orderId: orderId, status: status.rawValue)

            if success {
                // Update local state immediately for better UX
                if let index = orders.firstIndex(where: { $0.id == orderId }) {
                    // Since Order is a struct, we need to create a new one
                    // This is a temporary local update until we refresh
                    await refreshOrders()
                }
            } else {
                self.error = OrdersError.updateFailed("Failed to update order status")
            }
        } catch let updateError {
            // If the request fails, queue it for later
            await queueStatusUpdate(orderId: orderId, status: status)
            self.error = OrdersError.updateFailed(updateError.localizedDescription)
            print("Order status update error: \(updateError)")
        }
    }

    /// Update order status (convenience method with Order object)
    func updateOrderStatus(_ order: Order, to status: OrderStatus) async {
        await updateOrderStatus(orderId: order.id, status: status)
    }

    /// Queue a status update for offline sync
    private func queueStatusUpdate(orderId: String, status: OrderStatus) async {
        // Find current status for the order
        let currentStatus = orders.first { $0.id == orderId }?.status.rawValue

        let payload = UpdateOrderStatusPayload(
            orderId: orderId,
            newStatus: status.rawValue,
            previousStatus: currentStatus,
            note: nil
        )

        do {
            try await offlineManager.queueAction(type: .updateOrderStatus, payload: payload)
            self.error = OrdersError.networkError("Update queued for when online")
        } catch {
            print("Failed to queue status update: \(error)")
            self.error = OrdersError.updateFailed("Failed to queue update: \(error.localizedDescription)")
        }
    }

    // MARK: - Selection

    /// Select an order for detail view
    func selectOrder(_ order: Order) {
        selectedOrder = order
    }

    /// Deselect order
    func deselectOrder() {
        selectedOrder = nil
    }

    // MARK: - Error Handling

    /// Clear current error
    func clearError() {
        error = nil
    }

    /// Retry last failed operation
    func retry() {
        Task {
            await loadOrders()
        }
    }

    // MARK: - Auto Refresh

    /// Start auto-refresh timer
    func startAutoRefresh(interval: TimeInterval = 60) {
        stopAutoRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                // Only auto-refresh when online
                if self?.offlineManager.isOnline == true {
                    await self?.loadOrders()
                }
            }
        }
    }

    /// Stop auto-refresh timer
    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Offline Status

    func getOfflineStatus() -> OfflineStatusSummary {
        offlineManager.getStatusSummary()
    }

    func getCacheAge() -> String? {
        guard let lastUpdate = lastCacheUpdate else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastUpdate, relativeTo: Date())
    }

    // MARK: - Statistics

    /// Get order statistics
    func getStatistics() -> OrderStatistics {
        let totalRevenue = orders
            .filter { $0.status == .completed }
            .compactMap { $0.totals?.total }
            .reduce(0, +)

        let averageOrderValue = orders.isEmpty ? 0.0 :
            orders.compactMap { $0.totals?.total }
                .reduce(0, +) / Double(orders.count)

        let partnerOrders = orders.filter { $0.placedBy == .partner }.count
        let directOrders = orders.filter { $0.placedBy == .customer }.count

        return OrderStatistics(
            totalOrders: orders.count,
            pendingOrders: pendingOrdersCount,
            inProgressOrders: inProgressOrdersCount,
            completedOrders: completedOrdersCount,
            totalRevenue: totalRevenue,
            averageOrderValue: averageOrderValue,
            partnerOrders: partnerOrders,
            directOrders: directOrders
        )
    }

    /// Get orders grouped by date
    func getOrdersByDate() -> [Date: [Order]] {
        let calendar = Calendar.current
        return Dictionary(grouping: orders) { order in
            calendar.startOfDay(for: order.createdAt)
        }
    }

    /// Get recent orders (last 7 days)
    func getRecentOrders(days: Int = 7) -> [Order] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return orders.filter { $0.createdAt >= cutoffDate }
    }

    // MARK: - Multi-Select Operations

    /// Toggle selection mode
    func toggleSelectionMode() {
        isSelectionMode.toggle()
        if !isSelectionMode {
            clearSelection()
        }
    }

    /// Toggle selection for a specific order
    func toggleSelection(orderId: String) {
        if selectedOrderIds.contains(orderId) {
            selectedOrderIds.remove(orderId)
        } else {
            selectedOrderIds.insert(orderId)
        }
    }

    /// Check if an order is selected
    func isSelected(orderId: String) -> Bool {
        selectedOrderIds.contains(orderId)
    }

    /// Select all filtered orders
    func selectAll() {
        selectedOrderIds = Set(filteredOrders.map { $0.id })
    }

    /// Clear all selections
    func clearSelection() {
        selectedOrderIds.removeAll()
    }

    /// Bulk update status for selected orders
    func bulkUpdateStatus(to status: OrderStatus) async {
        guard !selectedOrderIds.isEmpty else { return }

        isBulkOperationInProgress = true
        var successCount = 0
        var failedIds: [String] = []

        for orderId in selectedOrderIds {
            do {
                let success = try await convex.updateOrderStatus(orderId: orderId, status: status.rawValue)
                if success {
                    successCount += 1
                } else {
                    failedIds.append(orderId)
                }
            } catch {
                failedIds.append(orderId)
                print("Bulk update failed for order \(orderId): \(error)")
            }
        }

        bulkOperationResult = BulkOperationResult(
            successCount: successCount,
            failedCount: failedIds.count,
            failedIds: failedIds,
            message: "Updated \(successCount) of \(selectedOrderIds.count) orders to \(status.displayName)"
        )

        // Refresh orders after bulk operation
        await refreshOrders()
        clearSelection()
        isSelectionMode = false
        isBulkOperationInProgress = false
    }

    /// Bulk delete selected orders (placeholder - needs Convex mutation)
    func bulkDelete() async {
        guard !selectedOrderIds.isEmpty else { return }

        isBulkOperationInProgress = true

        // Note: This would need a Convex mutation for bulk deletion
        bulkOperationResult = BulkOperationResult(
            successCount: 0,
            failedCount: selectedOrderIds.count,
            failedIds: Array(selectedOrderIds),
            message: "Bulk deletion not yet implemented on the server"
        )

        isBulkOperationInProgress = false
    }

    /// Export selected orders to CSV format
    func exportSelectedToCSV() -> String {
        let ordersToExport = selectedOrderIds.isEmpty ? filteredOrders : selectedOrders

        var csv = "Order Number,Date,Customer Email,Status,Service Type,Total,Placed By,Partner Code\n"

        for order in ordersToExport {
            let row = [
                order.orderNumber,
                order.createdAt.formatted(date: .numeric, time: .omitted),
                order.customerEmail,
                order.status.displayName,
                order.serviceType?.displayName ?? "N/A",
                order.formattedTotal,
                order.placedBy == .partner ? "Partner" : "Customer",
                order.partnerCodeUsed ?? ""
            ].map { "\"\($0)\"" }.joined(separator: ",")

            csv += row + "\n"
        }

        return csv
    }

    /// Clear bulk operation result
    func clearBulkResult() {
        bulkOperationResult = nil
    }
}

// MARK: - Order Statistics
struct OrderStatistics {
    let totalOrders: Int
    let pendingOrders: Int
    let inProgressOrders: Int
    let completedOrders: Int
    let totalRevenue: Double
    let averageOrderValue: Double
    let partnerOrders: Int
    let directOrders: Int

    var formattedTotalRevenue: String {
        String(format: "$%.2f", totalRevenue)
    }

    var formattedAverageOrderValue: String {
        String(format: "$%.2f", averageOrderValue)
    }

    var partnerOrderPercentage: Double {
        guard totalOrders > 0 else { return 0 }
        return Double(partnerOrders) / Double(totalOrders) * 100
    }
}

// MARK: - Bulk Operation Result
struct BulkOperationResult: Identifiable {
    let id = UUID()
    let successCount: Int
    let failedCount: Int
    let failedIds: [String]
    let message: String

    var isSuccess: Bool {
        failedCount == 0
    }
}

// MARK: - Orders Errors
enum OrdersError: Error, LocalizedError {
    case loadFailed(String)
    case updateFailed(String)
    case orderNotFound(String)
    case invalidStatus(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .loadFailed(let message):
            return "Failed to load orders: \(message)"
        case .updateFailed(let message):
            return "Failed to update order: \(message)"
        case .orderNotFound(let id):
            return "Order not found: \(id)"
        case .invalidStatus(let status):
            return "Invalid order status: \(status)"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }

    var userFriendlyMessage: String {
        switch self {
        case .loadFailed:
            return "Unable to load orders. Please check your connection and try again."
        case .updateFailed:
            return "Unable to update order. Please try again."
        case .orderNotFound:
            return "This order could not be found. It may have been deleted."
        case .invalidStatus:
            return "Invalid status selected. Please choose a valid status."
        case .networkError:
            return "Connection error. Please check your internet connection."
        }
    }

    var isRetryable: Bool {
        switch self {
        case .loadFailed, .networkError:
            return true
        case .updateFailed, .orderNotFound, .invalidStatus:
            return false
        }
    }
}

//
//  DashboardViewModel.swift
//  365WeaponsAdmin
//
//  ViewModel for Dashboard data management with offline support
//

import Foundation
import Combine

@MainActor
class DashboardViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var stats: DashboardStats?
    @Published var recentOrders: [Order] = []
    @Published var revenueData: [RevenueDataPoint] = []
    @Published var serviceBreakdown: [ServiceBreakdown] = []
    @Published var topPartners: [PartnerPerformance] = []
    @Published var recentActions: [WebsiteAction] = []
    @Published var isLoading: Bool = false
    @Published var error: Error?

    // MARK: - Data Availability Flags
    @Published var partnersAvailable: Bool = true
    @Published var commissionsAvailable: Bool = true
    @Published var inquiriesAvailable: Bool = true

    // MARK: - Offline Support
    @Published var isOffline: Bool = false
    @Published var isUsingCachedData: Bool = false
    @Published var lastCacheUpdate: Date?

    // MARK: - Dependencies
    private let convex = ConvexClient.shared
    private let postgres = PostgreSQLClient.shared
    private let dashboardAgent = DashboardAgent()
    private let offlineManager = OfflineManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?

    // MARK: - Initialization
    init() {
        setupOfflineObserver()
        // Don't start auto-refresh automatically - let view control it
    }

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: - Lifecycle Management

    /// Call when dashboard view appears
    func onAppear() {
        startAutoRefresh()
        ConvexClient.shared.startConnectionMonitoring()
    }

    /// Call when dashboard view disappears
    func onDisappear() {
        stopAutoRefresh()
        ConvexClient.shared.stopConnectionMonitoring()
    }

    private func startAutoRefresh() {
        guard refreshTimer == nil else { return }
        setupAutoRefresh()
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
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
    }

    // MARK: - Data Loading

    func loadData() async {
        isLoading = true
        error = nil

        // Check if we're offline
        if offlineManager.shouldUseCachedData() {
            await loadCachedData()
            isLoading = false
            return
        }

        do {
            // Load core data (stats and orders) - these are required
            async let statsTask = convex.fetchDashboardStats()
            async let ordersTask = convex.fetchOrders(limit: 20)

            // Load partner data - now available from backend
            async let partnersTask = dashboardAgent.getPartnerPerformance()

            let (fetchedStats, fetchedOrders, fetchedPartners) = try await (statsTask, ordersTask, partnersTask)

            // Update published properties
            self.stats = fetchedStats
            self.recentOrders = fetchedOrders
            self.topPartners = fetchedPartners

            // All data sources are now available
            self.partnersAvailable = true
            self.commissionsAvailable = true
            self.inquiriesAvailable = true

            // Generate sample revenue data (would come from PostgreSQL in production)
            self.revenueData = generateSampleRevenueData()

            // Generate service breakdown
            self.serviceBreakdown = calculateServiceBreakdown(from: fetchedOrders)

            // Load recent actions
            if postgres.isConnected {
                self.recentActions = (try? await postgres.getRecentActions(limit: 10)) ?? []
            } else {
                self.recentActions = generateSampleActions()
            }

            // Cache the data for offline use
            await cacheData()

            self.isUsingCachedData = false
            self.lastCacheUpdate = Date()

        } catch {
            // Ignore cancelled request errors (e.g., when view refreshes)
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                print("Request cancelled (normal during view refresh)")
            } else {
                self.error = error
                print("Dashboard load error: \(error)")

                // Fall back to cached data on error
                await loadCachedData()
            }
        }

        isLoading = false
    }

    func refresh() {
        Task {
            await loadData()
        }
    }

    // MARK: - Cache Operations

    private func cacheData() async {
        let cache = CacheService.shared

        do {
            // Cache dashboard stats
            if let stats = stats {
                try await cache.cache(
                    stats,
                    forKey: CacheKeys.dashboardStats,
                    expiration: CachedDataType.dashboard.defaultExpiration,
                    dataType: .dashboard
                )
            }

            // Cache recent orders
            if !recentOrders.isEmpty {
                try await cache.cache(
                    recentOrders,
                    forKey: CacheKeys.recentOrders,
                    expiration: CachedDataType.orders.defaultExpiration,
                    dataType: .orders
                )
            }

            // Cache revenue data
            if !revenueData.isEmpty {
                try await cache.cache(
                    revenueData,
                    forKey: CacheKeys.revenueData,
                    expiration: CachedDataType.analytics.defaultExpiration,
                    dataType: .analytics
                )
            }
        } catch {
            print("Failed to cache dashboard data: \(error)")
        }
    }

    private func loadCachedData() async {
        let cache = CacheService.shared

        do {
            // Load cached stats
            if let cachedStats: DashboardStats = try await cache.retrieve(forKey: CacheKeys.dashboardStats) {
                self.stats = cachedStats
            }

            // Load cached orders
            if let cachedOrders: [Order] = try await cache.retrieve(forKey: CacheKeys.recentOrders) {
                self.recentOrders = cachedOrders
                self.serviceBreakdown = calculateServiceBreakdown(from: cachedOrders)
            }

            // Load cached revenue data
            if let cachedRevenue: [RevenueDataPoint] = try await cache.retrieve(forKey: CacheKeys.revenueData) {
                self.revenueData = cachedRevenue
            }

            // Mark as using cached data
            self.isUsingCachedData = true

            // Get cache metadata for last update time
            let metadata = await cache.getAllMetadata()
            if let dashboardMeta = metadata.first(where: { $0.key == CacheKeys.dashboardStats }) {
                self.lastCacheUpdate = dashboardMeta.createdAt
            }

        } catch {
            print("Failed to load cached dashboard data: \(error)")
        }
    }

    // MARK: - Auto Refresh
    private func setupAutoRefresh() {
        // Refresh every 2 minutes (reduced from 30 seconds to save battery/bandwidth)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            Task { @MainActor in
                // Only auto-refresh when online and not already loading
                guard let self = self,
                      self.offlineManager.isOnline,
                      !self.isLoading else { return }
                await self.loadData()
            }
        }
    }

    // MARK: - Data Calculations

    private func calculateServiceBreakdown(from orders: [Order]) -> [ServiceBreakdown] {
        var breakdown: [ServiceType: (count: Int, revenue: Double)] = [:]

        for order in orders {
            guard let serviceType = order.serviceType,
                  let total = order.totals?.total else { continue }

            let current = breakdown[serviceType] ?? (0, 0)
            breakdown[serviceType] = (current.count + 1, current.revenue + total)
        }

        return breakdown.map { ServiceBreakdown(serviceType: $0.key, count: $0.value.count, revenue: $0.value.revenue) }
    }

    // MARK: - Sample Data Generation

    private func generateSampleRevenueData() -> [RevenueDataPoint] {
        let calendar = Calendar.current
        var data: [RevenueDataPoint] = []

        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            let revenue = Double.random(in: 1000...5000)
            let orders = Int.random(in: 5...20)
            data.append(RevenueDataPoint(date: date, revenue: revenue, orders: orders))
        }

        return data.reversed()
    }

    private func generateSampleActions() -> [WebsiteAction] {
        let types: [(ActionType, String)] = [
            (.purchase, "New order placed - #ORD12345"),
            (.productView, "Product viewed - Porting Service"),
            (.inquiry, "New service inquiry received"),
            (.partnerSignup, "New vendor registration"),
            (.addToCart, "Item added to cart"),
            (.login, "Admin login from iOS app")
        ]

        return types.enumerated().map { index, item in
            WebsiteAction(
                id: UUID().uuidString,
                actionType: item.0,
                description: item.1,
                userId: nil,
                userEmail: nil,
                metadata: nil,
                timestamp: Date().addingTimeInterval(-Double(index * 600))
            )
        }
    }

    // MARK: - AI Insights

    func getAIInsights() async throws -> String {
        guard let stats = stats else {
            throw DashboardError.noData
        }

        let output = try await OrchestrationAgent.shared.getDashboardInsights()
        return output.response
    }

    func getDailyBriefing() async throws -> String {
        let chatAgent = ChatAgent()
        return try await chatAgent.getDailyBriefing()
    }

    // MARK: - Specific Metrics

    func getRevenueGrowth() -> Double {
        return stats?.revenueGrowth ?? 0
    }

    func getOrderGrowth() -> Double {
        return stats?.orderGrowth ?? 0
    }

    func getPendingItemsCount() -> Int {
        let pendingOrders = stats?.pendingOrders ?? 0
        // Only include inquiries if that data is available
        let pendingInquiries = inquiriesAvailable ? (stats?.pendingInquiries ?? 0) : 0
        return pendingOrders + pendingInquiries
    }

    func getCompletionRate() -> Double {
        guard !recentOrders.isEmpty else { return 0 }
        let completed = recentOrders.filter { $0.status == .completed }.count
        return Double(completed) / Double(recentOrders.count) * 100
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
}

// MARK: - Dashboard Errors
enum DashboardError: Error, LocalizedError {
    case noData
    case loadFailed(String)

    var errorDescription: String? {
        switch self {
        case .noData:
            return "No dashboard data available"
        case .loadFailed(let message):
            return "Load failed: \(message)"
        }
    }
}

//
//  AnalyticsView.swift
//  365WeaponsAdmin
//
//  Advanced analytics and reporting view
//

import SwiftUI
import Charts

struct AnalyticsView: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @StateObject private var viewModel = AnalyticsViewModel()
    @State private var selectedTimeRange: TimeRange = .month
    @State private var selectedMetric: MetricType = .revenue

    enum TimeRange: String, CaseIterable {
        case week = "7 Days"
        case month = "30 Days"
        case quarter = "90 Days"
        case year = "1 Year"
    }

    enum MetricType: String, CaseIterable {
        case revenue = "Revenue"
        case orders = "Orders"
        case customers = "Customers"
        case products = "Products"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Time range selector
                    timeRangeSelector

                    // Key metrics
                    keyMetricsSection

                    // Main chart
                    mainChartSection

                    // Comparison charts
                    HStack(spacing: 16) {
                        serviceComparisonCard
                        partnerComparisonCard
                    }

                    // Detailed breakdowns
                    ordersByStatusCard

                    // Customer insights
                    customerInsightsCard

                    // Live activity
                    liveActivityCard
                }
                .padding()
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Analytics")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: viewModel.exportReport) {
                            Label("Export Report", systemImage: "square.and.arrow.up")
                        }
                        Button(action: viewModel.refresh) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .refreshable {
                await viewModel.loadData()
            }
        }
        .task {
            await viewModel.loadData()
        }
    }

    // MARK: - Time Range Selector
    private var timeRangeSelector: some View {
        Picker("Time Range", selection: $selectedTimeRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedTimeRange) { _, newValue in
            Task {
                await viewModel.loadData(timeRange: newValue)
            }
        }
    }

    // MARK: - Key Metrics Section
    private var keyMetricsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            MetricCard(
                title: "Revenue",
                value: viewModel.totalRevenue.currencyFormatted,
                icon: "dollarsign.circle.fill",
                color: .green,
                trend: viewModel.revenueGrowth,
                isSelected: selectedMetric == .revenue,
                action: { selectedMetric = .revenue }
            )

            MetricCard(
                title: "Orders",
                value: "\(viewModel.totalOrders)",
                icon: "list.clipboard.fill",
                color: .blue,
                trend: viewModel.orderGrowth,
                isSelected: selectedMetric == .orders,
                action: { selectedMetric = .orders }
            )

            MetricCard(
                title: "Customers",
                value: "\(viewModel.totalCustomers)",
                icon: "person.2.fill",
                color: .purple,
                trend: viewModel.customerGrowth,
                isSelected: selectedMetric == .customers,
                action: { selectedMetric = .customers }
            )

            MetricCard(
                title: "Avg Order",
                value: viewModel.averageOrderValue.currencyFormatted,
                icon: "cart.fill",
                color: Color.appAccent,
                isSelected: selectedMetric == .products,
                action: { selectedMetric = .products }
            )
        }
    }

    // MARK: - Main Chart Section
    private var mainChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("\(selectedMetric.rawValue) Over Time")
                    .font(.headline)
                Spacer()
                Text(getTotalForMetric())
                    .font(.title2.weight(.bold))
                    .foregroundColor(colorForMetric(selectedMetric))
            }

            if !viewModel.timeSeriesData.isEmpty {
                Chart(viewModel.timeSeriesData) { point in
                    switch selectedMetric {
                    case .revenue:
                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Revenue", point.revenue)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green.opacity(0.3), .green.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Revenue", point.revenue)
                        )
                        .foregroundStyle(Color.appSuccess)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                    case .orders:
                        BarMark(
                            x: .value("Date", point.date),
                            y: .value("Orders", point.orders)
                        )
                        .foregroundStyle(Color.appAccent)
                        .cornerRadius(4)

                    default:
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Value", point.revenue)
                        )
                        .foregroundStyle(Color.appAccent)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let val = value.as(Double.self) {
                                Text(selectedMetric == .revenue ? val.shortCurrencyFormatted : "\(Int(val))")
                                    .foregroundColor(Color.appTextSecondary)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date.shortFormatted)
                                    .foregroundColor(Color.appTextSecondary)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 250)
            } else {
                ContentUnavailableView("No Data", systemImage: "chart.line.uptrend.xyaxis")
                    .frame(height: 250)
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(16)
    }

    private func getTotalForMetric() -> String {
        switch selectedMetric {
        case .revenue: return viewModel.totalRevenue.currencyFormatted
        case .orders: return "\(viewModel.totalOrders)"
        case .customers: return "\(viewModel.totalCustomers)"
        case .products: return viewModel.averageOrderValue.currencyFormatted
        }
    }

    private func colorForMetric(_ metric: MetricType) -> Color {
        switch metric {
        case .revenue: return .green
        case .orders: return .blue
        case .customers: return .purple
        case .products: return Color.appAccent
        }
    }

    // MARK: - Service Comparison Card
    private var serviceComparisonCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("By Service")
                .font(.headline)

            if !viewModel.serviceBreakdown.isEmpty {
                Chart(viewModel.serviceBreakdown) { item in
                    SectorMark(
                        angle: .value("Revenue", item.revenue),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Service", item.serviceType.displayName))
                    .cornerRadius(4)
                }
                .chartLegend(position: .bottom, alignment: .center)
                .frame(height: 180)
            } else {
                Text("No data available")
                    .foregroundColor(Color.appTextSecondary)
                    .frame(height: 180)
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(16)
    }

    // MARK: - Partner Comparison Card
    private var partnerComparisonCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Top Partners")
                    .font(.headline)
                Spacer()
                Text("Coming Soon")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.appAccent.opacity(0.2))
                    .foregroundColor(Color.appAccent)
                    .cornerRadius(8)
            }

            // Partner data not available yet - show placeholder
            VStack(spacing: 12) {
                Image(systemName: "person.2.circle")
                    .font(.system(size: 40))
                    .foregroundColor(Color.appTextSecondary.opacity(0.5))
                Text("Partner analytics will be\navailable in a future update")
                    .font(.caption)
                    .foregroundColor(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 180)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(16)
    }

    // MARK: - Orders By Status Card
    private var ordersByStatusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Orders by Status")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(OrderStatus.allCases, id: \.self) { status in
                    let count = viewModel.ordersByStatus[status] ?? 0
                    StatusMetricCard(
                        status: status,
                        count: count,
                        total: viewModel.totalOrders
                    )
                }
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(16)
    }

    // MARK: - Customer Insights Card
    private var customerInsightsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Customer Insights")
                .font(.headline)

            HStack(spacing: 16) {
                InsightCard(
                    title: "New Customers",
                    value: "\(viewModel.newCustomers)",
                    subtitle: "This period",
                    icon: "person.badge.plus",
                    color: .green
                )

                InsightCard(
                    title: "Returning",
                    value: "\(viewModel.returningCustomers)",
                    subtitle: "\(String(format: "%.1f", viewModel.retentionRate))% rate",
                    icon: "arrow.uturn.left.circle",
                    color: .blue
                )

                InsightCard(
                    title: "Avg Lifetime",
                    value: viewModel.avgCustomerLifetimeValue.currencyFormatted,
                    subtitle: "Per customer",
                    icon: "dollarsign.circle",
                    color: Color.appAccent
                )
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(16)
    }

    // MARK: - Live Activity Card
    private var liveActivityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Live Activity")
                    .font(.headline)

                Circle()
                    .fill(Color.appSuccess)
                    .frame(width: 8, height: 8)
                    .modifier(PulseAnimation())

                Spacer()

                Text("\(viewModel.activeVisitors) active now")
                    .font(.caption)
                    .foregroundColor(Color.appTextSecondary)
            }

            if !viewModel.recentActions.isEmpty {
                ForEach(viewModel.recentActions.prefix(5)) { action in
                    HStack(spacing: 12) {
                        Image(systemName: action.actionType.icon)
                            .foregroundColor(Color.appAccent)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(action.actionType.displayName)
                                .font(.subheadline)
                            Text(action.description)
                                .font(.caption)
                                .foregroundColor(Color.appTextSecondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text(action.timestamp.timeAgo)
                            .font(.caption2)
                            .foregroundColor(Color.appTextSecondary)
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Text("No recent activity")
                    .font(.caption)
                    .foregroundColor(Color.appTextSecondary)
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(16)
    }
}

// MARK: - Metric Card
struct MetricCard: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    let title: String
    let value: String
    let icon: String
    let color: Color
    var trend: Double? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)

                    Spacer()

                    if let trend = trend {
                        HStack(spacing: 2) {
                            Image(systemName: trend >= 0 ? "arrow.up" : "arrow.down")
                                .font(.caption2)
                            Text("\(String(format: "%.0f", abs(trend)))%")
                                .font(.caption2)
                        }
                        .foregroundColor(trend >= 0 ? Color.appSuccess : Color.appDanger)
                    }
                }

                Text(value)
                    .font(.headline)
                    .foregroundColor(Color.appTextPrimary)

                Text(title)
                    .font(.caption2)
                    .foregroundColor(Color.appTextSecondary)
            }
            .padding(12)
            .background(isSelected ? color.opacity(0.2) : Color.appSurface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Status Metric Card
struct StatusMetricCard: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    let status: OrderStatus
    let count: Int
    let total: Int

    var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total) * 100
    }

    var color: Color {
        switch status {
        case .pending: return .yellow
        case .awaitingPayment: return Color.appAccent
        case .awaitingShipment: return .blue
        case .inProgress: return .purple
        case .completed: return .green
        case .cancelled: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(status.displayName)
                    .font(.caption)
                    .foregroundColor(Color.appTextSecondary)
            }

            Text("\(count)")
                .font(.title2.weight(.bold))

            ProgressView(value: percentage, total: 100)
                .tint(color)
        }
        .padding(12)
        .background(Color.appSurface)
        .cornerRadius(12)
    }
}

// MARK: - Insight Card
struct InsightCard: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)

            Text(value)
                .font(.headline)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(Color.appTextSecondary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(Color.appTextSecondary.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.appSurface)
        .cornerRadius(12)
    }
}

// MARK: - Analytics ViewModel
@MainActor
class AnalyticsViewModel: ObservableObject {
    @Published var totalRevenue: Double = 0
    @Published var totalOrders: Int = 0
    @Published var totalCustomers: Int = 0
    @Published var averageOrderValue: Double = 0
    @Published var revenueGrowth: Double = 0
    @Published var orderGrowth: Double = 0
    @Published var customerGrowth: Double = 0

    @Published var timeSeriesData: [RevenueDataPoint] = []
    @Published var serviceBreakdown: [ServiceBreakdown] = []
    @Published var topPartners: [PartnerPerformance] = []
    @Published var ordersByStatus: [OrderStatus: Int] = [:]
    @Published var recentActions: [WebsiteAction] = []

    @Published var newCustomers: Int = 0
    @Published var returningCustomers: Int = 0
    @Published var retentionRate: Double = 0
    @Published var avgCustomerLifetimeValue: Double = 0
    @Published var activeVisitors: Int = 0

    @Published var isLoading = false

    private let convex = ConvexClient.shared
    private let postgres = PostgreSQLClient.shared
    private let dashboardAgent = DashboardAgent()

    func loadData(timeRange: AnalyticsView.TimeRange = .month) async {
        isLoading = true

        do {
            // Load dashboard stats
            let stats = try await convex.fetchDashboardStats()
            totalRevenue = stats.totalRevenue
            totalOrders = stats.totalOrders
            revenueGrowth = stats.revenueGrowth
            orderGrowth = stats.orderGrowth

            // Load orders for breakdown
            let orders = try await convex.fetchOrders(limit: 500)

            // Calculate orders by status
            var statusCounts: [OrderStatus: Int] = [:]
            for order in orders {
                statusCounts[order.status, default: 0] += 1
            }
            ordersByStatus = statusCounts

            // Calculate average order value
            let completedOrders = orders.filter { $0.status == .completed }
            if !completedOrders.isEmpty {
                let total = completedOrders.compactMap { $0.totals?.total }.reduce(0, +)
                averageOrderValue = total / Double(completedOrders.count)
            }

            // Service breakdown
            var breakdown: [ServiceType: Double] = [:]
            for order in completedOrders {
                if let serviceType = order.serviceType,
                   let total = order.totals?.total {
                    breakdown[serviceType, default: 0] += total
                }
            }
            serviceBreakdown = breakdown.map { ServiceBreakdown(serviceType: $0.key, count: 0, revenue: $0.value) }

            // Generate time series data
            timeSeriesData = generateTimeSeriesData(from: orders, timeRange: timeRange)

            // Partner performance data is not available yet
            // Will be enabled when partnerStores:list backend function is implemented
            topPartners = []

            // Customer metrics (simulated for now)
            totalCustomers = Set(orders.map { $0.customerEmail }).count
            newCustomers = Int(Double(totalCustomers) * 0.3)
            returningCustomers = totalCustomers - newCustomers
            retentionRate = totalCustomers > 0 ? Double(returningCustomers) / Double(totalCustomers) * 100 : 0
            avgCustomerLifetimeValue = totalCustomers > 0 ? totalRevenue / Double(totalCustomers) : 0
            customerGrowth = 5.2

            // Active visitors (simulated)
            activeVisitors = Int.random(in: 5...25)

            // Recent actions
            if postgres.isConnected {
                recentActions = (try? await postgres.getRecentActions(limit: 10)) ?? []
            } else {
                recentActions = generateSampleActions()
            }

        } catch {
            print("Analytics load error: \(error)")
        }

        isLoading = false
    }

    func refresh() {
        Task {
            await loadData()
        }
    }

    func exportReport() {
        // Would generate and share a report
        print("Exporting analytics report...")
    }

    private func generateTimeSeriesData(from orders: [Order], timeRange: AnalyticsView.TimeRange) -> [RevenueDataPoint] {
        let days: Int
        switch timeRange {
        case .week: days = 7
        case .month: days = 30
        case .quarter: days = 90
        case .year: days = 365
        }

        let calendar = Calendar.current
        var dataPoints: [RevenueDataPoint] = []

        for i in 0..<min(days, 14) { // Limit points for readability
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

            let dayOrders = orders.filter { $0.createdAt >= dayStart && $0.createdAt < dayEnd }
            let dayRevenue = dayOrders.compactMap { $0.totals?.total }.reduce(0, +)

            dataPoints.append(RevenueDataPoint(date: date, revenue: dayRevenue, orders: dayOrders.count))
        }

        return dataPoints.reversed()
    }

    private func generateSampleActions() -> [WebsiteAction] {
        let types: [(ActionType, String)] = [
            (.purchase, "New order #ORD12345"),
            (.productView, "Viewed Porting Service"),
            (.inquiry, "New service inquiry"),
            (.addToCart, "Added item to cart"),
            (.login, "Admin logged in")
        ]

        return types.enumerated().map { index, item in
            WebsiteAction(
                id: UUID().uuidString,
                actionType: item.0,
                description: item.1,
                userId: nil,
                userEmail: nil,
                metadata: nil,
                timestamp: Date().addingTimeInterval(-Double(index * 300))
            )
        }
    }
}

// MARK: - Preview
#Preview {
    AnalyticsView()
}

//
//  DashboardView.swift
//  365WeaponsAdmin
//
//  Beautiful dashboard with interactive widgets and charts
//  Enhanced with comprehensive error handling and recovery
//
//  This view demonstrates usage of:
//  - Error handling system: ErrorAlertView, ErrorBanner, InlineErrorView
//  - ErrorRecoveryService: Global error management with retry logic
//  - Reusable components: SectionHeader, StatusBadge, EmptyStateView, LoadingOverlay
//

import SwiftUI
import Charts

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @StateObject private var errorService = ErrorRecoveryService.shared
    @EnvironmentObject var orchestrator: OrchestrationAgent

    @State private var showAIInsights = false
    @State private var selectedTimeRange: TimeRange = .week
    @State private var currentError: AppError?
    @State private var showErrorBanner = false

    enum TimeRange: String, CaseIterable {
        case day = "24h"
        case week = "7d"
        case month = "30d"
        case quarter = "90d"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        // Error banner at top of content (for non-critical errors)
                        if let error = currentError, showErrorBanner {
                            InlineErrorView(
                                error: error,
                                onRetry: {
                                    Task {
                                        await retryLoadData()
                                    }
                                },
                                onDismiss: {
                                    withAnimation {
                                        showErrorBanner = false
                                        currentError = nil
                                    }
                                }
                            )
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Connection status indicator
                        if !ConvexClient.shared.isConnected {
                            connectionStatusView
                        }

                        // Header with greeting
                        headerSection

                        // Quick stats cards
                        statsGrid

                        // Revenue chart
                        revenueChartCard

                        // Activity sections
                        HStack(spacing: 16) {
                            recentOrdersCard
                            pendingItemsCard
                        }

                        // Service breakdown
                        serviceBreakdownCard

                        // Partner performance
                        partnerPerformanceCard

                        // Live activity feed
                        activityFeedCard
                    }
                    .padding()
                }
                .background(Color.black.ignoresSafeArea())

                // Loading overlay using new component
                if viewModel.isLoading {
                    LoadingOverlay(
                        message: "Loading dashboard...",
                        style: .fullscreen
                    )
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAIInsights = true }) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("AI Insights")
                        }
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(8)
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        // Refresh button
                        Button(action: {
                            Task {
                                await retryLoadData()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.gray)
                        }

                        // Connection status indicator
                        connectionIndicator
                    }
                }
            }
            .refreshable {
                await loadDataWithErrorHandling()
            }
            .sheet(isPresented: $showAIInsights) {
                AIInsightsSheet(viewModel: viewModel)
            }
            // Error alert modifier for critical errors
            .errorAlert($currentError, onRetry: {
                Task {
                    await retryLoadData()
                }
            })
            // Listen for error recovery refresh notifications
            .onReceive(NotificationCenter.default.publisher(for: .errorRecoveryRefresh)) { _ in
                Task {
                    await loadDataWithErrorHandling()
                }
            }
        }
        .task {
            await loadDataWithErrorHandling()
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }

    // MARK: - Error Handling Methods

    /// Load data with comprehensive error handling
    private func loadDataWithErrorHandling() async {
        do {
            try await errorService.withRetry(
                config: .default,
                context: "Dashboard data load"
            ) {
                await viewModel.loadData()

                // Check if there was an error in the view model
                if let error = viewModel.error {
                    throw error
                }
            }

            // Clear any previous errors on success
            await MainActor.run {
                withAnimation {
                    currentError = nil
                    showErrorBanner = false
                }
            }
        } catch {
            // Ignore cancelled request errors (e.g., when view refreshes)
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                print("Request cancelled (normal during view refresh)")
                return
            }

            let appError = AppError.from(error)

            await MainActor.run {
                // Show banner for non-critical errors, alert for critical
                if appError.severity == .critical {
                    currentError = appError
                } else {
                    currentError = appError
                    withAnimation {
                        showErrorBanner = true
                    }
                }

                // Log the error
                errorService.handleError(appError, context: "DashboardView.loadData", showAlert: false)
            }
        }
    }

    /// Retry loading data after an error
    private func retryLoadData() async {
        withAnimation {
            showErrorBanner = false
        }

        await loadDataWithErrorHandling()
    }

    // MARK: - Connection Status Views

    /// Connection indicator in toolbar
    @ViewBuilder
    private var connectionIndicator: some View {
        let client = ConvexClient.shared

        HStack(spacing: 4) {
            Circle()
                .fill(connectionColor(for: client.connectionState))
                .frame(width: 8, height: 8)

            if client.connectionState == .reconnecting {
                ProgressView()
                    .scaleEffect(0.5)
            }
        }
        .help(connectionStatusText(for: client.connectionState))
    }

    /// Connection status view for disconnected state
    @ViewBuilder
    private var connectionStatusView: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 18))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Connection Lost")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)

                Text("Some features may be unavailable")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                Task {
                    await attemptReconnection()
                }
            }) {
                Text("Retry")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(6)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    private func connectionColor(for state: ConvexClient.ConnectionState) -> Color {
        switch state {
        case .connected: return .green
        case .connecting, .reconnecting: return .orange
        case .disconnected, .error: return .red
        }
    }

    private func connectionStatusText(for state: ConvexClient.ConnectionState) -> String {
        switch state {
        case .connected: return "Connected to server"
        case .connecting: return "Connecting..."
        case .disconnected: return "Disconnected"
        case .reconnecting: return "Reconnecting..."
        case .error: return "Connection error"
        }
    }

    private func attemptReconnection() async {
        let recovered = await errorService.attemptRecovery(for: .convexConnectionLost)
        if recovered {
            await loadDataWithErrorHandling()
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.title2.weight(.medium))
                    .foregroundColor(.gray)

                if let growth = viewModel.stats?.revenueGrowth {
                    HStack(spacing: 4) {
                        Image(systemName: growth >= 0 ? "arrow.up.right" : "arrow.down.right")
                        Text("\(String(format: "%.1f", abs(growth)))% \(growth >= 0 ? "growth" : "decline")")
                    }
                    .font(.subheadline)
                    .foregroundColor(growth >= 0 ? .green : .red)
                }
            }

            Spacer()

            // Time range picker
            Picker("Time Range", selection: $selectedTimeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    // MARK: - Stats Grid
    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                title: "Total Revenue",
                value: viewModel.stats?.totalRevenue.currencyFormatted ?? "$0.00",
                icon: "dollarsign.circle.fill",
                color: .green,
                trend: viewModel.stats?.revenueGrowth
            )

            StatCard(
                title: "Total Orders",
                value: "\(viewModel.stats?.totalOrders ?? 0)",
                icon: "list.clipboard.fill",
                color: .blue,
                trend: viewModel.stats?.orderGrowth
            )

            StatCard(
                title: "Products",
                value: "\(viewModel.stats?.totalProducts ?? 0)",
                icon: "cube.box.fill",
                color: .purple,
                subtitle: "Active items"
            )

            StatCard(
                title: "Partners",
                value: viewModel.partnersAvailable ? "\(viewModel.stats?.totalPartners ?? 0)" : "Coming Soon",
                icon: "person.2.fill",
                color: .orange,
                subtitle: viewModel.partnersAvailable ? "Registered vendors" : nil,
                isComingSoon: !viewModel.partnersAvailable
            )
        }
    }

    // MARK: - Revenue Chart Card
    private var revenueChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Revenue Overview")
                    .font(.headline)
                Spacer()
                Text(viewModel.stats?.totalRevenue.currencyFormatted ?? "$0.00")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.green)
            }

            if !viewModel.revenueData.isEmpty {
                Chart(viewModel.revenueData) { dataPoint in
                    AreaMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Revenue", dataPoint.revenue)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green.opacity(0.3), .green.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Revenue", dataPoint.revenue)
                    )
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    PointMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Revenue", dataPoint.revenue)
                    )
                    .foregroundStyle(.green)
                    .symbolSize(30)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let revenue = value.as(Double.self) {
                                Text(revenue.shortCurrencyFormatted)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date.shortFormatted)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .frame(height: 200)
            } else {
                ContentUnavailableView("No Data", systemImage: "chart.line.uptrend.xyaxis")
                    .frame(height: 200)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    // MARK: - Recent Orders Card
    /// Uses SectionHeader component for consistent header styling
    private var recentOrdersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Using SectionHeader component from Components library
            SectionHeader(title: "Recent Orders") {
                NavigationLink(destination: OrdersView()) {
                    HStack(spacing: 4) {
                        Text("See All")
                            .font(.caption)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundColor(.orange)
                }
            }

            if viewModel.recentOrders.isEmpty {
                // Using EmptyStateView component for empty state
                EmptyStateView(
                    icon: "list.clipboard",
                    title: "No Orders",
                    subtitle: "Recent orders will appear here",
                    style: .compact
                )
            } else {
                ForEach(viewModel.recentOrders.prefix(4)) { order in
                    OrderRowCompact(order: order)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    // MARK: - Pending Items Card
    private var pendingItemsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Needs Attention")
                .font(.headline)

            VStack(spacing: 8) {
                PendingItemRow(
                    title: "Pending Orders",
                    count: viewModel.stats?.pendingOrders ?? 0,
                    icon: "clock.fill",
                    color: .orange
                )

                PendingItemRow(
                    title: "New Inquiries",
                    count: viewModel.inquiriesAvailable ? (viewModel.stats?.pendingInquiries ?? 0) : 0,
                    icon: "questionmark.circle.fill",
                    color: .blue,
                    isComingSoon: !viewModel.inquiriesAvailable
                )

                PendingItemRow(
                    title: "Eligible Payouts",
                    count: viewModel.commissionsAvailable ? Int(viewModel.stats?.eligibleCommissions ?? 0) : 0,
                    icon: "dollarsign.circle.fill",
                    color: .green,
                    isCurrency: viewModel.commissionsAvailable,
                    isComingSoon: !viewModel.commissionsAvailable
                )
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    // MARK: - Service Breakdown Card
    private var serviceBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Service Breakdown")
                .font(.headline)

            if !viewModel.serviceBreakdown.isEmpty {
                Chart(viewModel.serviceBreakdown) { item in
                    SectorMark(
                        angle: .value("Revenue", item.revenue),
                        innerRadius: .ratio(0.6),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Service", item.serviceType.displayName))
                    .cornerRadius(4)
                }
                .chartLegend(position: .trailing, alignment: .center)
                .frame(height: 200)
            } else {
                HStack(spacing: 16) {
                    ForEach(ServiceType.allCases, id: \.self) { type in
                        ServiceTypeCard(serviceType: type, count: 0)
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    // MARK: - Partner Performance Card
    private var partnerPerformanceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Top Partners")
                    .font(.headline)
                Spacer()
                if viewModel.partnersAvailable {
                    Text("By Revenue")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    Text("Coming Soon")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(4)
                }
            }

            if !viewModel.partnersAvailable {
                VStack(spacing: 8) {
                    Image(systemName: "person.2.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("Partner analytics will be available soon")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
            } else if viewModel.topPartners.isEmpty {
                Text("No partner data available")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(viewModel.topPartners.prefix(5)) { partner in
                    PartnerRow(partner: partner)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    // MARK: - Activity Feed Card
    /// Uses LiveSectionHeader component for live indicator styling
    private var activityFeedCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Using LiveSectionHeader component from Components library
            LiveSectionHeader(
                title: "Live Activity",
                isLive: true
            )

            if viewModel.recentActions.isEmpty {
                // Using EmptyStateView component for empty state
                EmptyStateView(
                    icon: "bolt.slash",
                    title: "No Activity",
                    subtitle: "Recent activity will appear here",
                    style: .compact
                )
            } else {
                ForEach(viewModel.recentActions.prefix(5)) { action in
                    ActivityRow(action: action)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

// MARK: - Supporting Views
// Note: StatCard is imported from Components/StatCard.swift

struct OrderRowCompact: View {
    let order: Order

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("#\(order.orderNumber)")
                    .font(.caption.weight(.medium))
                Text(order.customerEmail)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(order.formattedTotal)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.green)

                // Using StatusBadge component from Components library
                StatusBadge(orderStatus: order.status, size: .small)
            }
        }
        .padding(.vertical, 4)
    }
}

// StatusBadge is now imported from Components/StatusBadge.swift
// The following legacy struct is kept for backward compatibility with OrderRowCompact
// TODO: Migrate all usages to the new StatusBadge(orderStatus:) initializer
struct OrderStatusBadge: View {
    let status: OrderStatus

    var body: some View {
        // Delegate to the new StatusBadge component
        StatusBadge(orderStatus: status, size: .small)
    }
}

struct PendingItemRow: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    var isCurrency: Bool = false
    var isComingSoon: Bool = false

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isComingSoon ? .gray : color)

            Text(title)
                .font(.caption)
                .foregroundColor(isComingSoon ? .gray : .white)

            Spacer()

            if isComingSoon {
                Text("Coming Soon")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(4)
            } else {
                Text(isCurrency ? Double(count).currencyFormatted : "\(count)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(count > 0 ? color : .gray)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ServiceTypeCard: View {
    let serviceType: ServiceType
    let count: Int

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: serviceType.icon)
                .font(.title2)
                .foregroundColor(.orange)

            Text(serviceType.displayName)
                .font(.caption2)
                .foregroundColor(.gray)

            Text("\(count)")
                .font(.caption.weight(.bold))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}

struct PartnerRow: View {
    let partner: PartnerPerformance

    var body: some View {
        HStack {
            Circle()
                .fill(partner.isActive ? Color.green : Color.gray)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(partner.partnerName)
                    .font(.caption.weight(.medium))
                Text(partner.storeCode)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(partner.totalRevenue.currencyFormatted)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.green)
                Text("\(partner.orderCount) orders")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ActivityRow: View {
    let action: WebsiteAction

    var body: some View {
        HStack {
            Image(systemName: action.actionType.icon)
                .foregroundColor(.orange)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(action.description)
                    .font(.caption)
                    .lineLimit(1)
                Text(action.timestamp.timeAgo)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Pulse Animation
struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .opacity(isPulsing ? 0.6 : 1.0)
            .animation(
                Animation.easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - AI Insights Sheet
struct AIInsightsSheet: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var insights: String = ""
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isLoading {
                        ProgressView("Analyzing your dashboard...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 100)
                    } else {
                        Text(insights)
                            .font(.body)
                            .foregroundColor(.white)
                    }
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("AI Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            await loadInsights()
        }
    }

    private func loadInsights() async {
        do {
            let output = try await OrchestrationAgent.shared.getDashboardInsights()
            insights = output.response
        } catch {
            insights = "Failed to generate insights: \(error.localizedDescription)"
        }
        isLoading = false
    }
}

// MARK: - Extensions
extension Double {
    var currencyFormatted: String {
        String(format: "$%.2f", self)
    }

    var shortCurrencyFormatted: String {
        if self >= 1000000 {
            return String(format: "$%.1fM", self / 1000000)
        } else if self >= 1000 {
            return String(format: "$%.1fK", self / 1000)
        }
        return currencyFormatted
    }
}

extension Date {
    var shortFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: self)
    }

    // Note: timeAgo is defined in WebhookModels.swift
}

// MARK: - Preview
#Preview {
    DashboardView()
        .environmentObject(OrchestrationAgent.shared)
}

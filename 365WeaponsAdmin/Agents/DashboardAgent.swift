//
//  DashboardAgent.swift
//  365WeaponsAdmin
//
//  Dashboard Agent for analytics, statistics, and business insights
//

import Foundation
import Combine

// MARK: - Dashboard Agent
class DashboardAgent: Agent, ObservableObject {
    let name = "dashboard"
    let description = "Handles analytics, statistics, revenue data, order summaries, and business insights"

    @Published var isProcessing: Bool = false
    @Published var cachedStats: DashboardStats?
    @Published var lastRefresh: Date?

    private let openRouter = OpenRouterClient.shared
    private let convex = ConvexClient.shared
    private let postgres = PostgreSQLClient.shared

    // MARK: - Agent Protocol

    func canHandle(input: AgentInput) -> Bool {
        let keywords = [
            "revenue", "sales", "orders", "analytics", "statistics", "stats",
            "dashboard", "metrics", "performance", "growth", "trend", "chart",
            "graph", "report", "insight", "commission", "partner", "vendor"
        ]

        let message = input.message.lowercased()
        return keywords.contains { message.contains($0) }
    }

    func process(input: AgentInput) async throws -> AgentOutput {
        isProcessing = true
        defer { isProcessing = false }

        // Gather dashboard data
        let dashboardData = try await gatherDashboardData()

        // Determine the specific task
        let taskAnalysis = try await analyzeTask(input: input, data: dashboardData)

        // Generate response based on task
        let response = try await generateResponse(input: input, data: dashboardData, task: taskAnalysis)

        return AgentOutput(
            response: response.text,
            agentName: name,
            toolsUsed: response.toolsUsed,
            data: dashboardData.asDictionary,
            suggestedActions: response.suggestedActions,
            confidence: response.confidence
        )
    }

    // MARK: - Data Gathering

    struct DashboardData {
        let stats: DashboardStats
        let recentOrders: [Order]
        let topProducts: [ProductSalesData]?
        let partnerStats: [PartnerStore]?  // Optional - partners data may not be available
        let revenueTimeline: [RevenueDataPoint]?
        let pendingInquiries: [ServiceInquiry]?  // Optional - inquiries data may not be available

        var asDictionary: [String: Any] {
            [
                "totalRevenue": stats.totalRevenue,
                "totalOrders": stats.totalOrders,
                "totalProducts": stats.totalProducts,
                "totalPartners": stats.totalPartners,
                "pendingOrders": stats.pendingOrders,
                "pendingInquiries": stats.pendingInquiries,
                "eligibleCommissions": stats.eligibleCommissions,
                "revenueGrowth": stats.revenueGrowth,
                "orderGrowth": stats.orderGrowth,
                "partnersAvailable": partnerStats != nil,
                "inquiriesAvailable": pendingInquiries != nil
            ]
        }
    }

    private func gatherDashboardData() async throws -> DashboardData {
        // Fetch core data (stats and orders) - these are required
        async let statsTask = convex.fetchDashboardStats()
        async let ordersTask = convex.fetchOrders(limit: 20)

        // Fetch optional data - partners and inquiries may not be available
        // These are wrapped in try? to handle gracefully when endpoints don't exist
        let partners: [PartnerStore]? = try? await convex.fetchPartners()
        let inquiries: [ServiceInquiry]? = try? await convex.fetchInquiries(status: "NEW")

        // Optional: fetch from PostgreSQL for historical data
        let topProducts: [ProductSalesData]? = try? await postgres.getTopProducts(limit: 5)

        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let revenueTimeline: [RevenueDataPoint]? = try? await postgres.getRevenueByDateRange(
            from: thirtyDaysAgo,
            to: Date()
        )

        let (stats, orders) = try await (statsTask, ordersTask)

        cachedStats = stats
        lastRefresh = Date()

        return DashboardData(
            stats: stats,
            recentOrders: orders,
            topProducts: topProducts,
            partnerStats: partners,  // Will be nil if partners endpoint not available
            revenueTimeline: revenueTimeline,
            pendingInquiries: inquiries  // Will be nil if inquiries endpoint not available
        )
    }

    // MARK: - Task Analysis

    enum DashboardTask {
        case overview
        case revenueAnalysis
        case orderAnalysis
        case partnerAnalysis
        case productPerformance
        case trendAnalysis
        case alertsAndIssues
        case custom(String)
    }

    private func analyzeTask(input: AgentInput, data: DashboardData) async throws -> DashboardTask {
        let message = input.message.lowercased()

        if message.contains("overview") || message.contains("summary") || message.contains("how") && message.contains("doing") {
            return .overview
        } else if message.contains("revenue") || message.contains("sales") || message.contains("money") {
            return .revenueAnalysis
        } else if message.contains("order") {
            return .orderAnalysis
        } else if message.contains("partner") || message.contains("vendor") || message.contains("commission") {
            return .partnerAnalysis
        } else if message.contains("product") && (message.contains("best") || message.contains("top") || message.contains("perform")) {
            return .productPerformance
        } else if message.contains("trend") || message.contains("growth") || message.contains("change") {
            return .trendAnalysis
        } else if message.contains("alert") || message.contains("issue") || message.contains("problem") || message.contains("attention") {
            return .alertsAndIssues
        }

        return .custom(input.message)
    }

    // MARK: - Response Generation

    struct DashboardResponse {
        let text: String
        let toolsUsed: [String]
        let suggestedActions: [SuggestedAction]
        let confidence: Double
    }

    private func generateResponse(input: AgentInput, data: DashboardData, task: DashboardTask) async throws -> DashboardResponse {
        var contextPrompt = buildContextPrompt(data: data, task: task)
        var suggestedActions: [SuggestedAction] = []
        var toolsUsed: [String] = ["convex_query"]

        switch task {
        case .overview:
            suggestedActions = [
                SuggestedAction(title: "View Orders", action: "navigate_orders", icon: "list.clipboard"),
                SuggestedAction(title: "Check Inventory", action: "navigate_products", icon: "cube.box"),
                SuggestedAction(title: "Review Inquiries", action: "navigate_inquiries", icon: "questionmark.circle")
            ]

        case .revenueAnalysis:
            toolsUsed.append("revenue_calculation")
            suggestedActions = [
                SuggestedAction(title: "Export Report", action: "export_revenue", icon: "square.and.arrow.up"),
                SuggestedAction(title: "View Trends", action: "view_trends", icon: "chart.line.uptrend.xyaxis")
            ]

        case .orderAnalysis:
            suggestedActions = [
                SuggestedAction(title: "Pending Orders", action: "filter_pending", icon: "clock"),
                SuggestedAction(title: "Update Status", action: "batch_update", icon: "checkmark.circle")
            ]

        case .partnerAnalysis:
            toolsUsed.append("commission_calculation")
            suggestedActions = [
                SuggestedAction(title: "Process Payouts", action: "process_payouts", icon: "dollarsign.circle"),
                SuggestedAction(title: "View Partners", action: "navigate_partners", icon: "person.2")
            ]

        case .alertsAndIssues:
            suggestedActions = [
                SuggestedAction(title: "View All Alerts", action: "view_alerts", icon: "exclamationmark.triangle"),
                SuggestedAction(title: "Resolve Issues", action: "resolve_issues", icon: "checkmark.seal")
            ]

        default:
            break
        }

        let systemPrompt = """
        You are the Dashboard Agent for 365Weapons admin. Provide clear, data-driven insights.

        \(contextPrompt)

        Guidelines:
        - Be concise but informative
        - Highlight key metrics and changes
        - Point out any concerns or opportunities
        - Use numbers and percentages when relevant
        - Format currency as $X,XXX.XX
        """

        let response = try await openRouter.chat(
            messages: [ChatCompletionMessage(role: "user", content: input.message)],
            temperature: 0.5,
            systemPrompt: systemPrompt
        )

        return DashboardResponse(
            text: response,
            toolsUsed: toolsUsed,
            suggestedActions: suggestedActions,
            confidence: 0.9
        )
    }

    private func buildContextPrompt(data: DashboardData, task: DashboardTask) -> String {
        var context = """
        ## Current Dashboard Data

        ### Key Metrics
        - Total Revenue: $\(String(format: "%.2f", data.stats.totalRevenue))
        - Total Orders: \(data.stats.totalOrders)
        - Total Products: \(data.stats.totalProducts)
        - Total Partners: \(data.stats.totalPartners)
        - Revenue Growth: \(String(format: "%.1f", data.stats.revenueGrowth))%
        - Order Growth: \(String(format: "%.1f", data.stats.orderGrowth))%

        ### Pending Items
        - Pending Orders: \(data.stats.pendingOrders)
        - Pending Inquiries: \(data.stats.pendingInquiries)
        - Eligible Commissions: $\(String(format: "%.2f", data.stats.eligibleCommissions))

        """

        // Add task-specific context
        switch task {
        case .orderAnalysis, .overview:
            context += """

            ### Recent Orders
            \(data.recentOrders.prefix(10).map { "- #\($0.orderNumber): \($0.status.displayName) - \($0.formattedTotal) (\($0.customerEmail))" }.joined(separator: "\n"))
            """

        case .productPerformance:
            if let topProducts = data.topProducts {
                context += """

                ### Top Products by Revenue
                \(topProducts.map { "- \($0.productTitle): $\(String(format: "%.2f", $0.totalRevenue)) (\($0.totalQuantity) sold)" }.joined(separator: "\n"))
                """
            }

        case .partnerAnalysis:
            if let partnerStats = data.partnerStats, !partnerStats.isEmpty {
                context += """

                ### Partner Overview
                - Active Partners: \(partnerStats.filter { $0.active }.count)
                - Total Partners: \(partnerStats.count)

                \(partnerStats.prefix(5).map { "- \($0.storeName) (\($0.storeCode)): \($0.formattedCommission) commission" }.joined(separator: "\n"))
                """
            } else {
                context += """

                ### Partner Overview
                Partner data is not yet available. This feature is coming soon.
                """
            }

        case .alertsAndIssues:
            var alerts: [String] = []

            if data.stats.pendingOrders > 10 {
                alerts.append("- High number of pending orders: \(data.stats.pendingOrders)")
            }
            // Only check inquiries if data is available
            if data.pendingInquiries != nil && data.stats.pendingInquiries > 5 {
                alerts.append("- Unreviewed inquiries: \(data.stats.pendingInquiries)")
            }
            // Only check commissions if partner data is available
            if data.partnerStats != nil && data.stats.eligibleCommissions > 1000 {
                alerts.append("- Commissions ready for payout: $\(String(format: "%.2f", data.stats.eligibleCommissions))")
            }
            if data.stats.revenueGrowth < 0 {
                alerts.append("- Revenue decline: \(String(format: "%.1f", data.stats.revenueGrowth))%")
            }

            context += """

            ### Current Alerts
            \(alerts.isEmpty ? "No critical alerts" : alerts.joined(separator: "\n"))
            """

        default:
            break
        }

        return context
    }

    // MARK: - Specific Analytics Functions

    /// Get revenue breakdown
    func getRevenueBreakdown() async throws -> RevenueBreakdown {
        let stats = try await convex.fetchDashboardStats()
        let orders = try await convex.fetchOrders(limit: 100)

        let completedOrders = orders.filter { $0.status == .completed }
        let totalRevenue = completedOrders.compactMap { $0.totals?.total }.reduce(0, +)

        // Group by service type
        var byService: [ServiceType: Double] = [:]
        for order in completedOrders {
            if let serviceType = order.serviceType,
               let total = order.totals?.total {
                byService[serviceType, default: 0] += Double(total) / 100.0
            }
        }

        // Calculate averages
        let averageOrderValue = completedOrders.isEmpty ? 0 : Double(totalRevenue) / Double(completedOrders.count) / 100.0

        return RevenueBreakdown(
            total: stats.totalRevenue,
            byService: byService,
            averageOrderValue: averageOrderValue,
            orderCount: completedOrders.count,
            growth: stats.revenueGrowth
        )
    }

    /// Get order statistics
    func getOrderStatistics() async throws -> DashboardOrderStatistics {
        let orders = try await convex.fetchOrders(limit: 500)

        var byStatus: [OrderStatus: Int] = [:]
        var byServiceType: [ServiceType: Int] = [:]
        var byPlacedBy: [OrderPlacedBy: Int] = [:]

        for order in orders {
            byStatus[order.status, default: 0] += 1
            if let serviceType = order.serviceType {
                byServiceType[serviceType, default: 0] += 1
            }
            byPlacedBy[order.placedBy, default: 0] += 1
        }

        let today = Calendar.current.startOfDay(for: Date())
        let ordersToday = orders.filter { Calendar.current.isDate($0.createdAt, inSameDayAs: today) }.count

        let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: today) ?? today
        let ordersThisWeek = orders.filter { $0.createdAt >= weekStart }.count

        return DashboardOrderStatistics(
            total: orders.count,
            byStatus: byStatus,
            byServiceType: byServiceType,
            byPlacedBy: byPlacedBy,
            todayCount: ordersToday,
            weekCount: ordersThisWeek
        )
    }

    /// Get partner performance
    /// Returns empty array if partner/commission data is not available
    func getPartnerPerformance() async throws -> [PartnerPerformance] {
        // Attempt to fetch partners - return empty if not available
        guard let partners = try? await convex.fetchPartners(), !partners.isEmpty else {
            return []
        }

        // Attempt to fetch commissions - continue with empty if not available
        let commissions: [Commission] = (try? await convex.fetchCommissions()) ?? []
        let orders = try await convex.fetchOrders(limit: 1000)

        var performances: [PartnerPerformance] = []

        for partner in partners {
            let partnerOrders = orders.filter { $0.partnerStoreId == partner.id }
            let partnerCommissions = commissions.filter { $0.partnerStoreId == partner.id }

            let totalRevenue = partnerOrders.compactMap { $0.totals?.total }.reduce(0) { $0 + Double($1) / 100.0 }
            let totalCommissions = partnerCommissions.reduce(0) { $0 + $1.commissionAmount }
            let pendingCommissions = partnerCommissions.filter { $0.status == .pending || $0.status == .eligible }.reduce(0) { $0 + $1.commissionAmount }

            performances.append(PartnerPerformance(
                partnerId: partner.id,
                partnerName: partner.storeName,
                storeCode: partner.storeCode,
                orderCount: partnerOrders.count,
                totalRevenue: totalRevenue,
                totalCommissions: totalCommissions,
                pendingCommissions: pendingCommissions,
                isActive: partner.active
            ))
        }

        return performances.sorted { $0.totalRevenue > $1.totalRevenue }
    }
}

// MARK: - Analytics Data Types

struct RevenueBreakdown {
    let total: Double
    let byService: [ServiceType: Double]
    let averageOrderValue: Double
    let orderCount: Int
    let growth: Double
}

struct DashboardOrderStatistics {
    let total: Int
    let byStatus: [OrderStatus: Int]
    let byServiceType: [ServiceType: Int]
    let byPlacedBy: [OrderPlacedBy: Int]
    let todayCount: Int
    let weekCount: Int
}

struct PartnerPerformance: Identifiable {
    let id = UUID()
    let partnerId: String
    let partnerName: String
    let storeCode: String
    let orderCount: Int
    let totalRevenue: Double
    let totalCommissions: Double
    let pendingCommissions: Double
    let isActive: Bool
}

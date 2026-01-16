//
//  OrderAgent.swift
//  365WeaponsAdmin
//
//  Agent for order management with bulk operations support
//

import Foundation
import Combine

// MARK: - Order Action Types
enum OrderAction {
    case listOrders(filter: OrderFilter?)
    case getOrderDetails(orderId: String)
    case updateStatus(orderId: String, status: OrderStatus)
    case bulkUpdateStatus(orderIds: [String], status: OrderStatus)
    case bulkAssignPartner(orderIds: [String], partnerId: String)
    case bulkDelete(orderIds: [String])
    case exportOrders(orderIds: [String]?, format: ExportFormat)
    case searchOrders(query: String)
    case custom(query: String)
}

enum ExportFormat: String {
    case csv = "csv"
    case pdf = "pdf"
}

// MARK: - Order Filter
struct OrderFilter {
    var searchQuery: String = ""
    var statuses: Set<OrderStatus> = Set(OrderStatus.allCases)
    var serviceTypes: Set<ServiceType> = Set(ServiceType.allCases)
    var placedBy: OrderPlacedBy?
    var partnerId: String?
    var dateFrom: Date?
    var dateTo: Date?

    var isActive: Bool {
        !searchQuery.isEmpty ||
        statuses.count != OrderStatus.allCases.count ||
        serviceTypes.count != ServiceType.allCases.count ||
        placedBy != nil ||
        partnerId != nil ||
        dateFrom != nil ||
        dateTo != nil
    }
}

// MARK: - Order Agent
class OrderAgent: Agent, ObservableObject {
    let name = "order"
    let description = "Manages orders including viewing, status updates, bulk operations, and exports"

    @Published var isProcessing: Bool = false
    @Published var cachedOrders: [Order] = []
    @Published var lastRefresh: Date?
    @Published var selectedOrderIds: Set<String> = []

    private let openRouter = OpenRouterClient.shared
    private let convex = ConvexClient.shared

    private var logger: DebugLogger {
        DebugLogger.shared
    }

    // MARK: - Agent Protocol

    func canHandle(input: AgentInput) -> Bool {
        let keywords = [
            "order", "orders", "shipment", "shipping", "tracking",
            "status", "pending", "completed", "cancelled", "bulk"
        ]

        let message = input.message.lowercased()
        return keywords.contains { message.contains($0) }
    }

    func process(input: AgentInput) async throws -> AgentOutput {
        await MainActor.run {
            logger.log("OrderAgent.process() called with: '\(input.message.prefix(50))...'", category: .agent)
            isProcessing = true
        }
        defer {
            Task { @MainActor in
                self.isProcessing = false
            }
        }

        // Determine the action
        let action = await determineAction(input: input)

        // Execute the action and gather data
        let orderData = try await executeAction(action)

        // Generate response
        let response = try await generateResponse(input: input, data: orderData, action: action)

        return AgentOutput(
            response: response.text,
            agentName: name,
            toolsUsed: response.toolsUsed,
            data: orderData.asDictionary,
            suggestedActions: response.suggestedActions,
            confidence: response.confidence
        )
    }

    // MARK: - Action Determination

    private func determineAction(input: AgentInput) async -> OrderAction {
        let message = input.message.lowercased()

        if message.contains("list") || message.contains("all order") || message.contains("show order") {
            return .listOrders(filter: nil)
        } else if message.contains("pending") {
            return .listOrders(filter: OrderFilter(statuses: [.pending, .awaitingPayment]))
        } else if message.contains("in progress") {
            return .listOrders(filter: OrderFilter(statuses: [.inProgress]))
        } else if message.contains("completed") {
            return .listOrders(filter: OrderFilter(statuses: [.completed]))
        } else if message.contains("search") || message.contains("find order") {
            return .searchOrders(query: input.message)
        } else if message.contains("detail") || message.contains("order #") {
            return .custom(query: input.message)
        } else if message.contains("update status") || message.contains("change status") {
            return .custom(query: input.message)
        } else if message.contains("bulk") {
            return .custom(query: input.message)
        } else if message.contains("export") || message.contains("download") {
            return .exportOrders(orderIds: nil, format: .csv)
        }

        return .custom(query: input.message)
    }

    // MARK: - Action Execution

    struct OrderData {
        let orders: [Order]
        let selectedOrder: Order?
        let orderStats: OrderStats?
        let bulkResult: BulkOperationResult?

        var asDictionary: [String: Any] {
            var dict: [String: Any] = [
                "orderCount": orders.count,
                "pendingCount": orders.filter { $0.status == .pending }.count,
                "inProgressCount": orders.filter { $0.status == .inProgress }.count,
                "completedCount": orders.filter { $0.status == .completed }.count
            ]

            if let selected = selectedOrder {
                dict["selectedOrder"] = selected.orderNumber
            }

            if let stats = orderStats {
                dict["totalRevenue"] = stats.totalRevenue
                dict["averageOrderValue"] = stats.averageOrderValue
            }

            if let result = bulkResult {
                dict["bulkSuccess"] = result.successCount
                dict["bulkFailed"] = result.failedCount
            }

            return dict
        }
    }

    struct OrderStats {
        let totalOrders: Int
        let totalRevenue: Double
        let averageOrderValue: Double
        let byStatus: [OrderStatus: Int]
        let byServiceType: [ServiceType: Int]
        let todayCount: Int
        let weekCount: Int
    }

    private func executeAction(_ action: OrderAction) async throws -> OrderData {
        let orders = try await convex.fetchOrders(limit: 500)
        await MainActor.run {
            self.cachedOrders = orders
            self.lastRefresh = Date()
        }

        switch action {
        case .listOrders(let filter):
            var filteredOrders = orders
            if let filter = filter {
                filteredOrders = applyFilter(orders: orders, filter: filter)
            }
            let stats = calculateOrderStats(orders: filteredOrders)
            return OrderData(orders: filteredOrders, selectedOrder: nil, orderStats: stats, bulkResult: nil)

        case .getOrderDetails(let orderId):
            let order = orders.first { $0.id == orderId }
            return OrderData(orders: orders, selectedOrder: order, orderStats: nil, bulkResult: nil)

        case .searchOrders(let query):
            let searchTerms = query.lowercased()
            let filteredOrders = orders.filter {
                $0.orderNumber.lowercased().contains(searchTerms) ||
                $0.customerEmail.lowercased().contains(searchTerms) ||
                ($0.endCustomerInfo?.name?.lowercased().contains(searchTerms) ?? false)
            }
            return OrderData(orders: filteredOrders, selectedOrder: nil, orderStats: nil, bulkResult: nil)

        case .updateStatus(let orderId, let status):
            try await convex.updateOrderStatus(orderId: orderId, status: status.rawValue)
            let updatedOrders = try await convex.fetchOrders(limit: 500)
            let order = updatedOrders.first { $0.id == orderId }
            return OrderData(orders: updatedOrders, selectedOrder: order, orderStats: nil, bulkResult: BulkOperationResult(successCount: 1, failedCount: 0, failedIds: [], message: "Order status updated to \(status.displayName)"))

        case .bulkUpdateStatus(let orderIds, let status):
            let result = try await performBulkStatusUpdate(orderIds: orderIds, status: status)
            let updatedOrders = try await convex.fetchOrders(limit: 500)
            return OrderData(orders: updatedOrders, selectedOrder: nil, orderStats: nil, bulkResult: result)

        case .bulkAssignPartner(let orderIds, let partnerId):
            let result = try await performBulkPartnerAssign(orderIds: orderIds, partnerId: partnerId)
            let updatedOrders = try await convex.fetchOrders(limit: 500)
            return OrderData(orders: updatedOrders, selectedOrder: nil, orderStats: nil, bulkResult: result)

        case .bulkDelete(let orderIds):
            let result = try await performBulkDelete(orderIds: orderIds)
            let updatedOrders = try await convex.fetchOrders(limit: 500)
            return OrderData(orders: updatedOrders, selectedOrder: nil, orderStats: nil, bulkResult: result)

        case .exportOrders(let orderIds, _):
            let ordersToExport = orderIds != nil ? orders.filter { orderIds!.contains($0.id) } : orders
            return OrderData(orders: ordersToExport, selectedOrder: nil, orderStats: nil, bulkResult: nil)

        case .custom:
            let stats = calculateOrderStats(orders: orders)
            return OrderData(orders: orders, selectedOrder: nil, orderStats: stats, bulkResult: nil)
        }
    }

    private func applyFilter(orders: [Order], filter: OrderFilter) -> [Order] {
        var result = orders

        if !filter.searchQuery.isEmpty {
            let query = filter.searchQuery.lowercased()
            result = result.filter {
                $0.orderNumber.lowercased().contains(query) ||
                $0.customerEmail.lowercased().contains(query) ||
                ($0.endCustomerInfo?.name?.lowercased().contains(query) ?? false)
            }
        }

        if filter.statuses.count < OrderStatus.allCases.count {
            result = result.filter { filter.statuses.contains($0.status) }
        }

        if filter.serviceTypes.count < ServiceType.allCases.count {
            result = result.filter {
                guard let serviceType = $0.serviceType else { return false }
                return filter.serviceTypes.contains(serviceType)
            }
        }

        if let placedBy = filter.placedBy {
            result = result.filter { $0.placedBy == placedBy }
        }

        if let partnerId = filter.partnerId {
            result = result.filter { $0.partnerStoreId == partnerId }
        }

        if let dateFrom = filter.dateFrom {
            result = result.filter { $0.createdAt >= dateFrom }
        }

        if let dateTo = filter.dateTo {
            result = result.filter { $0.createdAt <= dateTo }
        }

        return result
    }

    private func calculateOrderStats(orders: [Order]) -> OrderStats {
        let totalRevenue = orders.compactMap { $0.totals?.total }.reduce(0, +)
        let avgOrderValue = orders.isEmpty ? 0 : totalRevenue / Double(orders.count)

        var byStatus: [OrderStatus: Int] = [:]
        var byServiceType: [ServiceType: Int] = [:]

        for order in orders {
            byStatus[order.status, default: 0] += 1
            if let serviceType = order.serviceType {
                byServiceType[serviceType, default: 0] += 1
            }
        }

        let today = Calendar.current.startOfDay(for: Date())
        let todayCount = orders.filter { Calendar.current.isDate($0.createdAt, inSameDayAs: today) }.count

        let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: today) ?? today
        let weekCount = orders.filter { $0.createdAt >= weekStart }.count

        return OrderStats(
            totalOrders: orders.count,
            totalRevenue: totalRevenue,
            averageOrderValue: avgOrderValue,
            byStatus: byStatus,
            byServiceType: byServiceType,
            todayCount: todayCount,
            weekCount: weekCount
        )
    }

    // MARK: - Bulk Operations

    private func performBulkStatusUpdate(orderIds: [String], status: OrderStatus) async throws -> BulkOperationResult {
        var successCount = 0
        var failedIds: [String] = []

        for orderId in orderIds {
            do {
                try await convex.updateOrderStatus(orderId: orderId, status: status.rawValue)
                successCount += 1
            } catch {
                failedIds.append(orderId)
                await MainActor.run {
                    logger.error("Failed to update order \(orderId): \(error)", category: .agent)
                }
            }
        }

        return BulkOperationResult(
            successCount: successCount,
            failedCount: failedIds.count,
            failedIds: failedIds,
            message: "Updated \(successCount) of \(orderIds.count) orders to \(status.displayName)"
        )
    }

    private func performBulkPartnerAssign(orderIds: [String], partnerId: String) async throws -> BulkOperationResult {
        // This would need a Convex mutation for bulk partner assignment
        // For now, return a placeholder
        return BulkOperationResult(
            successCount: 0,
            failedCount: orderIds.count,
            failedIds: orderIds,
            message: "Bulk partner assignment not yet implemented"
        )
    }

    private func performBulkDelete(orderIds: [String]) async throws -> BulkOperationResult {
        // This would need a Convex mutation for bulk deletion
        // For now, return a placeholder
        return BulkOperationResult(
            successCount: 0,
            failedCount: orderIds.count,
            failedIds: orderIds,
            message: "Bulk deletion not yet implemented"
        )
    }

    // MARK: - Response Generation

    struct OrderResponse {
        let text: String
        let toolsUsed: [String]
        let suggestedActions: [SuggestedAction]
        let confidence: Double
    }

    private func generateResponse(input: AgentInput, data: OrderData, action: OrderAction) async throws -> OrderResponse {
        var contextPrompt = buildContextPrompt(data: data, action: action)
        var suggestedActions: [SuggestedAction] = []
        var toolsUsed: [String] = ["convex_query"]

        switch action {
        case .listOrders:
            suggestedActions = [
                SuggestedAction(title: "Filter Pending", action: "filter_pending", icon: "clock"),
                SuggestedAction(title: "Filter In Progress", action: "filter_in_progress", icon: "arrow.triangle.2.circlepath"),
                SuggestedAction(title: "Export Orders", action: "export_orders", icon: "square.and.arrow.up")
            ]

        case .getOrderDetails:
            suggestedActions = [
                SuggestedAction(title: "Update Status", action: "update_status", icon: "arrow.triangle.2.circlepath"),
                SuggestedAction(title: "View Customer", action: "view_customer", icon: "person.crop.circle"),
                SuggestedAction(title: "Print Label", action: "print_label", icon: "printer")
            ]

        case .bulkUpdateStatus, .bulkAssignPartner, .bulkDelete:
            toolsUsed.append("bulk_operation")
            suggestedActions = [
                SuggestedAction(title: "View Results", action: "view_results", icon: "checkmark.circle"),
                SuggestedAction(title: "Undo", action: "undo_bulk", icon: "arrow.uturn.backward")
            ]

        case .exportOrders:
            toolsUsed.append("export_generation")
            suggestedActions = [
                SuggestedAction(title: "Download CSV", action: "download_csv", icon: "arrow.down.doc"),
                SuggestedAction(title: "Download PDF", action: "download_pdf", icon: "doc.richtext")
            ]

        default:
            suggestedActions = [
                SuggestedAction(title: "View All Orders", action: "list_orders", icon: "list.clipboard"),
                SuggestedAction(title: "Pending Orders", action: "pending_orders", icon: "clock")
            ]
        }

        let systemPrompt = """
        You are the Order Agent for 365Weapons admin. You help manage orders and bulk operations.

        \(contextPrompt)

        Guidelines:
        - Be concise and informative
        - Highlight orders needing attention
        - Mention order statuses and counts
        - Format currency as $X,XXX.XX
        - For bulk operations, report success/failure counts
        """

        let response = try await openRouter.chat(
            messages: [ChatCompletionMessage(role: "user", content: input.message)],
            temperature: 0.5,
            systemPrompt: systemPrompt
        )

        return OrderResponse(
            text: response,
            toolsUsed: toolsUsed,
            suggestedActions: suggestedActions,
            confidence: 0.9
        )
    }

    private func buildContextPrompt(data: OrderData, action: OrderAction) -> String {
        var context = """
        ## Order Data

        ### Overview
        - Total Orders: \(data.orders.count)
        - Pending: \(data.orders.filter { $0.status == .pending }.count)
        - Awaiting Shipment: \(data.orders.filter { $0.status == .awaitingShipment }.count)
        - In Progress: \(data.orders.filter { $0.status == .inProgress }.count)
        - Completed: \(data.orders.filter { $0.status == .completed }.count)

        """

        if let stats = data.orderStats {
            context += """

            ### Statistics
            - Total Revenue: $\(String(format: "%.2f", stats.totalRevenue))
            - Average Order Value: $\(String(format: "%.2f", stats.averageOrderValue))
            - Orders Today: \(stats.todayCount)
            - Orders This Week: \(stats.weekCount)

            """
        }

        if let selectedOrder = data.selectedOrder {
            context += """

            ### Selected Order: #\(selectedOrder.orderNumber)
            - Status: \(selectedOrder.status.displayName)
            - Service: \(selectedOrder.serviceType?.displayName ?? "N/A")
            - Customer: \(selectedOrder.customerEmail)
            - Total: \(selectedOrder.formattedTotal)
            - Created: \(selectedOrder.createdAt.formatted())
            - Partner: \(selectedOrder.partnerStoreId ?? "Direct")

            """
        }

        if let bulkResult = data.bulkResult {
            context += """

            ### Bulk Operation Result
            - \(bulkResult.message)
            - Success: \(bulkResult.successCount)
            - Failed: \(bulkResult.failedCount)

            """
        }

        // List recent orders
        if data.selectedOrder == nil {
            context += """

            ### Recent Orders
            \(data.orders.prefix(10).map { "- #\($0.orderNumber): \($0.status.displayName) - \($0.formattedTotal) (\($0.customerEmail.prefix(20))...)" }.joined(separator: "\n"))

            """
        }

        return context
    }

    // MARK: - Public Helper Methods

    func getOrder(byId id: String) async throws -> Order? {
        let orders = try await convex.fetchOrders(limit: 500)
        return orders.first { $0.id == id }
    }

    func getOrder(byNumber number: String) async throws -> Order? {
        let orders = try await convex.fetchOrders(limit: 500)
        return orders.first { $0.orderNumber == number }
    }

    func getPendingOrders() async throws -> [Order] {
        let orders = try await convex.fetchOrders(limit: 500)
        return orders.filter { $0.status == .pending || $0.status == .awaitingPayment || $0.status == .awaitingShipment }
    }

    func getOrdersByPartner(partnerId: String) async throws -> [Order] {
        let orders = try await convex.fetchOrders(limit: 500)
        return orders.filter { $0.partnerStoreId == partnerId }
    }

    // MARK: - Selection Management

    @MainActor
    func toggleSelection(orderId: String) {
        if selectedOrderIds.contains(orderId) {
            selectedOrderIds.remove(orderId)
        } else {
            selectedOrderIds.insert(orderId)
        }
    }

    @MainActor
    func selectAll(orderIds: [String]) {
        selectedOrderIds = Set(orderIds)
    }

    @MainActor
    func clearSelection() {
        selectedOrderIds.removeAll()
    }

    var hasSelection: Bool {
        !selectedOrderIds.isEmpty
    }

    var selectionCount: Int {
        selectedOrderIds.count
    }
}

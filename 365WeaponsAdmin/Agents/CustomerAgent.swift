//
//  CustomerAgent.swift
//  365WeaponsAdmin
//
//  Agent for unified customer management across all data sources
//

import Foundation
import Combine

// MARK: - Customer Action Types
enum CustomerAction {
    case listCustomers(filter: CustomerFilter?)
    case searchCustomers(query: String)
    case getCustomerDetails(email: String)
    case getCustomerOrders(email: String)
    case getCustomerStats
    case exportCustomers(filter: CustomerFilter?)
    case custom(query: String)
}

// MARK: - Customer Agent
class CustomerAgent: Agent, ObservableObject {
    let name = "customer"
    let description = "Manages customers from all sources: orders, inquiries, newsletter subscribers, and contact submissions"

    @Published var isProcessing: Bool = false
    @Published var cachedCustomers: [Customer] = []
    @Published var lastRefresh: Date?

    private let openRouter = OpenRouterClient.shared
    private let convex = ConvexClient.shared

    private var logger: DebugLogger {
        DebugLogger.shared
    }

    // MARK: - Agent Protocol

    func canHandle(input: AgentInput) -> Bool {
        let keywords = [
            "customer", "contact", "subscriber", "newsletter", "buyer",
            "client", "user", "email list", "mailing list"
        ]

        let message = input.message.lowercased()
        return keywords.contains { message.contains($0) }
    }

    func process(input: AgentInput) async throws -> AgentOutput {
        await MainActor.run {
            logger.log("CustomerAgent.process() called with: '\(input.message.prefix(50))...'", category: .agent)
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
        let customerData = try await executeAction(action)

        // Generate response
        let response = try await generateResponse(input: input, data: customerData, action: action)

        return AgentOutput(
            response: response.text,
            agentName: name,
            toolsUsed: response.toolsUsed,
            data: customerData.asDictionary,
            suggestedActions: response.suggestedActions,
            confidence: response.confidence
        )
    }

    // MARK: - Action Determination

    private func determineAction(input: AgentInput) async -> CustomerAction {
        let message = input.message.lowercased()

        if message.contains("list") || message.contains("all customer") || message.contains("show customer") {
            return .listCustomers(filter: nil)
        } else if message.contains("search") || message.contains("find") {
            // Extract search query
            return .searchCustomers(query: input.message)
        } else if message.contains("detail") || message.contains("info about") {
            return .custom(query: input.message)
        } else if message.contains("order") && message.contains("history") {
            return .custom(query: input.message)
        } else if message.contains("stats") || message.contains("statistics") || message.contains("analytics") {
            return .getCustomerStats
        } else if message.contains("export") || message.contains("download") {
            return .exportCustomers(filter: nil)
        } else if message.contains("newsletter") || message.contains("subscriber") {
            return .listCustomers(filter: CustomerFilter(sources: [.newsletter]))
        } else if message.contains("contact") && message.contains("form") {
            return .listCustomers(filter: CustomerFilter(sources: [.contact]))
        }

        return .custom(query: input.message)
    }

    // MARK: - Action Execution

    struct CustomerData {
        let customers: [Customer]
        let selectedCustomer: Customer?
        let customerOrders: [Order]?
        let customerInquiries: [ServiceInquiry]?
        let stats: CustomerStats?

        var asDictionary: [String: Any] {
            var dict: [String: Any] = [
                "totalCustomers": customers.count,
                "bySource": Dictionary(grouping: customers, by: { $0.source.rawValue }).mapValues { $0.count }
            ]

            if let selected = selectedCustomer {
                dict["selectedCustomer"] = selected.name
                dict["selectedEmail"] = selected.email
            }

            if let stats = stats {
                dict["totalRevenue"] = stats.totalRevenue
                dict["averageOrderValue"] = stats.averageOrderValue
            }

            return dict
        }
    }

    private func executeAction(_ action: CustomerAction) async throws -> CustomerData {
        // Aggregate customers from all sources
        let customers = try await aggregateCustomers()
        await MainActor.run {
            self.cachedCustomers = customers
            self.lastRefresh = Date()
        }

        switch action {
        case .listCustomers(let filter):
            var filteredCustomers = customers
            if let filter = filter {
                filteredCustomers = applyFilter(customers: customers, filter: filter)
            }
            let stats = calculateCustomerStats(customers: filteredCustomers)
            return CustomerData(customers: filteredCustomers, selectedCustomer: nil, customerOrders: nil, customerInquiries: nil, stats: stats)

        case .searchCustomers(let query):
            let searchTerms = query.lowercased()
            let filteredCustomers = customers.filter {
                $0.name.lowercased().contains(searchTerms) ||
                $0.email.lowercased().contains(searchTerms) ||
                ($0.phone?.contains(searchTerms) ?? false)
            }
            return CustomerData(customers: filteredCustomers, selectedCustomer: nil, customerOrders: nil, customerInquiries: nil, stats: nil)

        case .getCustomerDetails(let email):
            let customer = customers.first { $0.email.lowercased() == email.lowercased() }
            let orders = try await convex.fetchOrders(limit: 500)
            let customerOrders = orders.filter { $0.customerEmail.lowercased() == email.lowercased() }
            let inquiries = try? await convex.fetchInquiries()
            let customerInquiries = inquiries?.filter { $0.customerEmail.lowercased() == email.lowercased() }

            return CustomerData(customers: customers, selectedCustomer: customer, customerOrders: customerOrders, customerInquiries: customerInquiries, stats: nil)

        case .getCustomerOrders(let email):
            let customer = customers.first { $0.email.lowercased() == email.lowercased() }
            let orders = try await convex.fetchOrders(limit: 500)
            let customerOrders = orders.filter { $0.customerEmail.lowercased() == email.lowercased() }

            return CustomerData(customers: customers, selectedCustomer: customer, customerOrders: customerOrders, customerInquiries: nil, stats: nil)

        case .getCustomerStats:
            let stats = calculateCustomerStats(customers: customers)
            return CustomerData(customers: customers, selectedCustomer: nil, customerOrders: nil, customerInquiries: nil, stats: stats)

        case .exportCustomers(let filter):
            var filteredCustomers = customers
            if let filter = filter {
                filteredCustomers = applyFilter(customers: customers, filter: filter)
            }
            return CustomerData(customers: filteredCustomers, selectedCustomer: nil, customerOrders: nil, customerInquiries: nil, stats: nil)

        case .custom:
            let stats = calculateCustomerStats(customers: customers)
            return CustomerData(customers: customers, selectedCustomer: nil, customerOrders: nil, customerInquiries: nil, stats: stats)
        }
    }

    // MARK: - Customer Aggregation

    private func aggregateCustomers() async throws -> [Customer] {
        var customerMap: [String: Customer] = [:]

        // 1. Get customers from orders
        let orders = try await convex.fetchOrders(limit: 1000)
        for order in orders {
            let email = order.customerEmail.lowercased()
            if email.isEmpty || email == "unknown" { continue }

            let name = order.endCustomerInfo?.name ?? order.billingAddress?.contactName ?? email.components(separatedBy: "@").first ?? "Unknown"
            let phone = order.endCustomerInfo?.phone ?? order.billingAddress?.phone

            if let existing = customerMap[email] {
                // Update existing customer with order data
                let updatedCustomer = Customer(
                    id: existing.id,
                    name: existing.name.isEmpty ? name : existing.name,
                    email: email,
                    phone: existing.phone ?? phone,
                    source: existing.source,
                    orderCount: existing.orderCount + 1,
                    totalSpent: existing.totalSpent + (order.totals?.total ?? 0),
                    lastActivity: max(existing.lastActivity, order.createdAt),
                    addresses: existing.addresses,
                    createdAt: min(existing.createdAt, order.createdAt)
                )
                customerMap[email] = updatedCustomer
            } else {
                let customer = Customer(
                    id: "order_\(email)",
                    name: name,
                    email: email,
                    phone: phone,
                    source: .order,
                    orderCount: 1,
                    totalSpent: order.totals?.total ?? 0,
                    lastActivity: order.createdAt,
                    addresses: [order.billingAddress, order.returnShippingAddressSnapshot].compactMap { $0 },
                    createdAt: order.createdAt
                )
                customerMap[email] = customer
            }
        }

        // 2. Get customers from inquiries
        if let inquiries = try? await convex.fetchInquiries() {
            for inquiry in inquiries {
                let email = inquiry.customerEmail.lowercased()
                if email.isEmpty { continue }

                if customerMap[email] == nil {
                    let customer = Customer(
                        id: "inquiry_\(email)",
                        name: inquiry.customerName,
                        email: email,
                        phone: inquiry.customerPhone,
                        source: .inquiry,
                        orderCount: 0,
                        totalSpent: 0,
                        lastActivity: inquiry.createdAt,
                        addresses: nil,
                        createdAt: inquiry.createdAt
                    )
                    customerMap[email] = customer
                }
            }
        }

        // 3. Get newsletter subscribers
        if let subscribers = try? await convex.fetchNewsletterSubscribers() {
            for subscriber in subscribers {
                let email = subscriber.email.lowercased()
                if email.isEmpty { continue }

                if customerMap[email] == nil {
                    let customer = Customer(
                        id: "newsletter_\(email)",
                        name: subscriber.fullName.isEmpty ? email.components(separatedBy: "@").first ?? "Subscriber" : subscriber.fullName,
                        email: email,
                        phone: subscriber.phone,
                        source: .newsletter,
                        orderCount: 0,
                        totalSpent: 0,
                        lastActivity: subscriber.subscribedAt,
                        addresses: nil,
                        createdAt: subscriber.subscribedAt
                    )
                    customerMap[email] = customer
                }
            }
        }

        // 4. Get contact form submissions
        if let contacts = try? await convex.fetchContactSubmissions() {
            for contact in contacts {
                let email = contact.email.lowercased()
                if email.isEmpty { continue }

                if customerMap[email] == nil {
                    let customer = Customer(
                        id: "contact_\(email)",
                        name: contact.name,
                        email: email,
                        phone: contact.phone,
                        source: .contact,
                        orderCount: 0,
                        totalSpent: 0,
                        lastActivity: contact.createdAt,
                        addresses: nil,
                        createdAt: contact.createdAt
                    )
                    customerMap[email] = customer
                }
            }
        }

        return Array(customerMap.values).sorted { $0.lastActivity > $1.lastActivity }
    }

    private func applyFilter(customers: [Customer], filter: CustomerFilter) -> [Customer] {
        var result = customers

        if !filter.searchQuery.isEmpty {
            let query = filter.searchQuery.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                $0.email.lowercased().contains(query) ||
                ($0.phone?.contains(query) ?? false)
            }
        }

        if filter.sources.count < CustomerSource.allCases.count {
            result = result.filter { filter.sources.contains($0.source) }
        }

        if let hasOrders = filter.hasOrders {
            result = result.filter { ($0.orderCount > 0) == hasOrders }
        }

        if let minSpent = filter.minSpent {
            result = result.filter { $0.totalSpent >= minSpent }
        }

        if let maxSpent = filter.maxSpent {
            result = result.filter { $0.totalSpent <= maxSpent }
        }

        return result
    }

    private func calculateCustomerStats(customers: [Customer]) -> CustomerStats {
        var bySource: [String: Int] = [:]
        for source in CustomerSource.allCases {
            bySource[source.rawValue] = customers.filter { $0.source == source }.count
        }

        let customersWithOrders = customers.filter { $0.orderCount > 0 }
        let totalRevenue = customersWithOrders.reduce(0) { $0 + $1.totalSpent }
        let avgOrderValue = customersWithOrders.isEmpty ? 0 : totalRevenue / Double(customersWithOrders.map { $0.orderCount }.reduce(0, +))

        let repeatCustomers = customersWithOrders.filter { $0.orderCount > 1 }
        let repeatRate = customersWithOrders.isEmpty ? 0 : Double(repeatCustomers.count) / Double(customersWithOrders.count)

        return CustomerStats(
            totalCustomers: customers.count,
            bySource: bySource,
            totalRevenue: totalRevenue,
            averageOrderValue: avgOrderValue,
            repeatCustomerRate: repeatRate
        )
    }

    // MARK: - Response Generation

    struct CustomerResponse {
        let text: String
        let toolsUsed: [String]
        let suggestedActions: [SuggestedAction]
        let confidence: Double
    }

    private func generateResponse(input: AgentInput, data: CustomerData, action: CustomerAction) async throws -> CustomerResponse {
        var contextPrompt = buildContextPrompt(data: data, action: action)
        var suggestedActions: [SuggestedAction] = []
        var toolsUsed: [String] = ["convex_query", "customer_aggregation"]

        switch action {
        case .listCustomers:
            suggestedActions = [
                SuggestedAction(title: "Filter by Source", action: "filter_source", icon: "line.3.horizontal.decrease.circle"),
                SuggestedAction(title: "Export List", action: "export_customers", icon: "square.and.arrow.up"),
                SuggestedAction(title: "View Stats", action: "customer_stats", icon: "chart.bar")
            ]

        case .searchCustomers:
            suggestedActions = [
                SuggestedAction(title: "View Details", action: "customer_details", icon: "person.crop.circle"),
                SuggestedAction(title: "View Orders", action: "customer_orders", icon: "list.clipboard")
            ]

        case .getCustomerDetails, .getCustomerOrders:
            toolsUsed.append("order_lookup")
            suggestedActions = [
                SuggestedAction(title: "Send Email", action: "send_email", icon: "envelope"),
                SuggestedAction(title: "View Orders", action: "view_orders", icon: "list.clipboard"),
                SuggestedAction(title: "Add Note", action: "add_note", icon: "note.text")
            ]

        case .getCustomerStats:
            toolsUsed.append("stats_calculation")
            suggestedActions = [
                SuggestedAction(title: "Export Report", action: "export_report", icon: "square.and.arrow.up"),
                SuggestedAction(title: "View All", action: "list_customers", icon: "person.3")
            ]

        default:
            suggestedActions = [
                SuggestedAction(title: "View All Customers", action: "list_customers", icon: "person.3"),
                SuggestedAction(title: "View Stats", action: "customer_stats", icon: "chart.bar")
            ]
        }

        let systemPrompt = """
        You are the Customer Agent for 365Weapons admin. You help manage customer relationships across all channels.

        \(contextPrompt)

        Guidelines:
        - Be concise and informative
        - Highlight valuable customers (high spend, repeat orders)
        - Mention customer sources when relevant
        - Format currency as $X,XXX.XX
        - Protect customer privacy (don't share full emails unless necessary)
        """

        let response = try await openRouter.chat(
            messages: [ChatCompletionMessage(role: "user", content: input.message)],
            temperature: 0.5,
            systemPrompt: systemPrompt
        )

        return CustomerResponse(
            text: response,
            toolsUsed: toolsUsed,
            suggestedActions: suggestedActions,
            confidence: 0.9
        )
    }

    private func buildContextPrompt(data: CustomerData, action: CustomerAction) -> String {
        var context = """
        ## Customer Data

        ### Overview
        - Total Customers: \(data.customers.count)

        """

        if let stats = data.stats {
            context += """
            ### Statistics
            - Total Revenue: $\(String(format: "%.2f", stats.totalRevenue))
            - Average Order Value: $\(String(format: "%.2f", stats.averageOrderValue))
            - Repeat Customer Rate: \(String(format: "%.1f", stats.repeatCustomerRate * 100))%

            ### By Source
            \(stats.bySource.map { "- \($0.key.capitalized): \($0.value)" }.joined(separator: "\n"))

            """
        }

        if let selectedCustomer = data.selectedCustomer {
            context += """

            ### Selected Customer: \(selectedCustomer.name)
            - Email: \(selectedCustomer.email)
            - Phone: \(selectedCustomer.phone ?? "Not provided")
            - Source: \(selectedCustomer.source.displayName)
            - Total Orders: \(selectedCustomer.orderCount)
            - Total Spent: \(selectedCustomer.formattedTotalSpent)
            - Last Activity: \(selectedCustomer.lastActivity.formatted())
            - Customer Since: \(selectedCustomer.createdAt.formatted())

            """
        }

        if let orders = data.customerOrders, !orders.isEmpty {
            context += """

            ### Order History
            \(orders.prefix(10).map { "- #\($0.orderNumber): \($0.status.displayName) - \($0.formattedTotal) (\($0.createdAt.formatted()))" }.joined(separator: "\n"))

            """
        }

        if let inquiries = data.customerInquiries, !inquiries.isEmpty {
            context += """

            ### Inquiries
            \(inquiries.prefix(5).map { "- \($0.productTitle): \($0.status.displayName)" }.joined(separator: "\n"))

            """
        }

        // List top customers
        if data.selectedCustomer == nil && data.customers.count <= 20 {
            let topCustomers = data.customers.sorted { $0.totalSpent > $1.totalSpent }.prefix(10)
            context += """

            ### Top Customers
            \(topCustomers.map { "- \($0.name) (\($0.email.prefix(20))...): \($0.orderCount) orders, \($0.formattedTotalSpent)" }.joined(separator: "\n"))

            """
        }

        return context
    }

    // MARK: - Public Helper Methods

    func searchCustomers(query: String) async throws -> [Customer] {
        let customers = try await aggregateCustomers()
        let searchTerms = query.lowercased()
        return customers.filter {
            $0.name.lowercased().contains(searchTerms) ||
            $0.email.lowercased().contains(searchTerms) ||
            ($0.phone?.contains(searchTerms) ?? false)
        }
    }

    func getCustomer(byEmail email: String) async throws -> Customer? {
        let customers = try await aggregateCustomers()
        return customers.first { $0.email.lowercased() == email.lowercased() }
    }

    func getCustomersBySource(source: CustomerSource) async throws -> [Customer] {
        let customers = try await aggregateCustomers()
        return customers.filter { $0.source == source }
    }
}

//
//  VendorAgent.swift
//  365WeaponsAdmin
//
//  Agent for vendor/partner management operations
//

import Foundation
import Combine

// MARK: - Vendor Action Types
enum VendorAction {
    case listVendors(filter: VendorFilter?)
    case getVendorDetails(vendorId: String)
    case updateVendor(vendorId: String, updates: UpdateVendorRequest)
    case getVendorStats(vendorId: String)
    case createVendor(data: CreateVendorRequest)
    case toggleActive(vendorId: String)
    case getCommissions(vendorId: String)
    case getOrders(vendorId: String)
    case custom(query: String)
}

// MARK: - Vendor Agent
class VendorAgent: Agent, ObservableObject {
    let name = "vendor"
    let description = "Manages vendors/partners including their details, commissions, orders, and settings"

    @Published var isProcessing: Bool = false
    @Published var cachedVendors: [PartnerStore] = []
    @Published var lastRefresh: Date?

    private let openRouter = OpenRouterClient.shared
    private let convex = ConvexClient.shared

    private var logger: DebugLogger {
        DebugLogger.shared
    }

    // MARK: - Agent Protocol

    func canHandle(input: AgentInput) -> Bool {
        let keywords = [
            "vendor", "partner", "store", "commission", "payout",
            "ffl", "dealer", "reseller", "affiliate"
        ]

        let message = input.message.lowercased()
        return keywords.contains { message.contains($0) }
    }

    func process(input: AgentInput) async throws -> AgentOutput {
        await MainActor.run {
            logger.log("VendorAgent.process() called with: '\(input.message.prefix(50))...'", category: .agent)
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
        let vendorData = try await executeAction(action)

        // Generate response
        let response = try await generateResponse(input: input, data: vendorData, action: action)

        return AgentOutput(
            response: response.text,
            agentName: name,
            toolsUsed: response.toolsUsed,
            data: vendorData.asDictionary,
            suggestedActions: response.suggestedActions,
            confidence: response.confidence
        )
    }

    // MARK: - Action Determination

    private func determineAction(input: AgentInput) async -> VendorAction {
        let message = input.message.lowercased()

        if message.contains("list") || message.contains("all vendor") || message.contains("show vendor") {
            return .listVendors(filter: nil)
        } else if message.contains("detail") || message.contains("info about") {
            // Try to extract vendor ID or name
            return .custom(query: input.message)
        } else if message.contains("commission") {
            return .custom(query: input.message)
        } else if message.contains("create") || message.contains("add vendor") || message.contains("new vendor") {
            return .custom(query: input.message)
        } else if message.contains("update") || message.contains("edit") || message.contains("change") {
            return .custom(query: input.message)
        } else if message.contains("active") || message.contains("inactive") || message.contains("disable") || message.contains("enable") {
            return .custom(query: input.message)
        } else if message.contains("order") {
            return .custom(query: input.message)
        }

        return .custom(query: input.message)
    }

    // MARK: - Action Execution

    struct VendorData {
        let vendors: [PartnerStore]
        let selectedVendor: PartnerStore?
        let vendorStats: VendorStats?
        let commissions: [Commission]?
        let orders: [Order]?
        let discountCodes: [DiscountCode]?

        var asDictionary: [String: Any] {
            var dict: [String: Any] = [
                "vendorCount": vendors.count,
                "activeVendors": vendors.filter { $0.active }.count
            ]

            if let selected = selectedVendor {
                dict["selectedVendor"] = selected.storeName
            }

            if let stats = vendorStats {
                dict["totalOrders"] = stats.totalOrders
                dict["totalRevenue"] = stats.totalRevenue
                dict["commissionTotal"] = stats.commissionTotal
            }

            return dict
        }
    }

    private func executeAction(_ action: VendorAction) async throws -> VendorData {
        // Fetch all vendors
        let vendors = try await convex.fetchPartners()
        await MainActor.run {
            self.cachedVendors = vendors
            self.lastRefresh = Date()
        }

        switch action {
        case .listVendors(let filter):
            var filteredVendors = vendors
            if let filter = filter {
                if !filter.searchQuery.isEmpty {
                    filteredVendors = vendors.filter {
                        $0.storeName.lowercased().contains(filter.searchQuery.lowercased()) ||
                        $0.storeCode.lowercased().contains(filter.searchQuery.lowercased())
                    }
                }
                switch filter.status {
                case .active:
                    filteredVendors = filteredVendors.filter { $0.active }
                case .inactive:
                    filteredVendors = filteredVendors.filter { !$0.active }
                case .pending:
                    filteredVendors = filteredVendors.filter { !$0.onboardingComplete }
                case .all:
                    break
                }
            }
            return VendorData(vendors: filteredVendors, selectedVendor: nil, vendorStats: nil, commissions: nil, orders: nil, discountCodes: nil)

        case .getVendorDetails(let vendorId):
            let vendor = vendors.first { $0.id == vendorId }
            let commissions = try? await convex.fetchPartnerCommissions(partnerId: vendorId)
            let orders = try await convex.fetchOrders(limit: 100)
            let vendorOrders = orders.filter { $0.partnerStoreId == vendorId }
            let discountCodes = try? await convex.fetchDiscountCodes(partnerStoreId: vendorId)

            let stats = calculateVendorStats(vendor: vendor, orders: vendorOrders, commissions: commissions ?? [])

            return VendorData(vendors: vendors, selectedVendor: vendor, vendorStats: stats, commissions: commissions, orders: vendorOrders, discountCodes: discountCodes)

        case .getVendorStats(let vendorId):
            let vendor = vendors.first { $0.id == vendorId }
            let commissions = try? await convex.fetchPartnerCommissions(partnerId: vendorId)
            let orders = try await convex.fetchOrders(limit: 500)
            let vendorOrders = orders.filter { $0.partnerStoreId == vendorId }

            let stats = calculateVendorStats(vendor: vendor, orders: vendorOrders, commissions: commissions ?? [])

            return VendorData(vendors: vendors, selectedVendor: vendor, vendorStats: stats, commissions: commissions, orders: nil, discountCodes: nil)

        case .getCommissions(let vendorId):
            let vendor = vendors.first { $0.id == vendorId }
            let commissions = try await convex.fetchPartnerCommissions(partnerId: vendorId)

            return VendorData(vendors: vendors, selectedVendor: vendor, vendorStats: nil, commissions: commissions, orders: nil, discountCodes: nil)

        case .getOrders(let vendorId):
            let vendor = vendors.first { $0.id == vendorId }
            let orders = try await convex.fetchOrders(limit: 500)
            let vendorOrders = orders.filter { $0.partnerStoreId == vendorId }

            return VendorData(vendors: vendors, selectedVendor: vendor, vendorStats: nil, commissions: nil, orders: vendorOrders, discountCodes: nil)

        default:
            // For custom queries, fetch general data
            let commissions = try? await convex.fetchCommissions()
            return VendorData(vendors: vendors, selectedVendor: nil, vendorStats: nil, commissions: commissions, orders: nil, discountCodes: nil)
        }
    }

    private func calculateVendorStats(vendor: PartnerStore?, orders: [Order], commissions: [Commission]) -> VendorStats {
        let totalOrders = orders.count
        let totalRevenue = orders.compactMap { $0.totals?.total }.reduce(0, +)
        let commissionTotal = commissions.reduce(0) { $0 + $1.commissionAmount }
        let commissionPaid = commissions.filter { $0.status == .paid }.reduce(0) { $0 + $1.commissionAmount }
        let commissionPending = commissions.filter { $0.status == .pending || $0.status == .eligible }.reduce(0) { $0 + $1.commissionAmount }

        var ordersByStatus: [String: Int] = [:]
        for order in orders {
            ordersByStatus[order.status.rawValue, default: 0] += 1
        }

        let averageOrderValue = totalOrders > 0 ? totalRevenue / Double(totalOrders) : 0

        return VendorStats(
            totalOrders: totalOrders,
            totalRevenue: totalRevenue,
            commissionTotal: commissionTotal,
            commissionPaid: commissionPaid,
            commissionPending: commissionPending,
            activeDiscountCodes: 0,
            averageOrderValue: averageOrderValue,
            ordersByStatus: ordersByStatus
        )
    }

    // MARK: - Response Generation

    struct VendorResponse {
        let text: String
        let toolsUsed: [String]
        let suggestedActions: [SuggestedAction]
        let confidence: Double
    }

    private func generateResponse(input: AgentInput, data: VendorData, action: VendorAction) async throws -> VendorResponse {
        var contextPrompt = buildContextPrompt(data: data, action: action)
        var suggestedActions: [SuggestedAction] = []
        var toolsUsed: [String] = ["convex_query"]

        switch action {
        case .listVendors:
            suggestedActions = [
                SuggestedAction(title: "View Active", action: "filter_active", icon: "checkmark.circle"),
                SuggestedAction(title: "View Inactive", action: "filter_inactive", icon: "xmark.circle"),
                SuggestedAction(title: "Add Vendor", action: "create_vendor", icon: "plus.circle")
            ]

        case .getVendorDetails, .getVendorStats:
            toolsUsed.append("stats_calculation")
            suggestedActions = [
                SuggestedAction(title: "View Orders", action: "vendor_orders", icon: "list.clipboard"),
                SuggestedAction(title: "View Commissions", action: "vendor_commissions", icon: "dollarsign.circle"),
                SuggestedAction(title: "Edit Vendor", action: "edit_vendor", icon: "pencil")
            ]

        case .getCommissions:
            toolsUsed.append("commission_calculation")
            suggestedActions = [
                SuggestedAction(title: "Process Payout", action: "process_payout", icon: "banknote"),
                SuggestedAction(title: "Export Report", action: "export_commissions", icon: "square.and.arrow.up")
            ]

        default:
            suggestedActions = [
                SuggestedAction(title: "View All Vendors", action: "list_vendors", icon: "person.2"),
                SuggestedAction(title: "View Commissions", action: "view_commissions", icon: "dollarsign.circle")
            ]
        }

        let systemPrompt = """
        You are the Vendor Agent for 365Weapons admin. You help manage vendor/partner relationships.

        \(contextPrompt)

        Guidelines:
        - Be concise and informative
        - Highlight key vendor metrics
        - Point out commission payouts due
        - Format currency as $X,XXX.XX
        - Mention any vendors needing attention
        """

        let response = try await openRouter.chat(
            messages: [ChatCompletionMessage(role: "user", content: input.message)],
            temperature: 0.5,
            systemPrompt: systemPrompt
        )

        return VendorResponse(
            text: response,
            toolsUsed: toolsUsed,
            suggestedActions: suggestedActions,
            confidence: 0.9
        )
    }

    private func buildContextPrompt(data: VendorData, action: VendorAction) -> String {
        var context = """
        ## Vendor Data

        ### Overview
        - Total Vendors: \(data.vendors.count)
        - Active Vendors: \(data.vendors.filter { $0.active }.count)
        - Inactive Vendors: \(data.vendors.filter { !$0.active }.count)
        - Pending Onboarding: \(data.vendors.filter { !$0.onboardingComplete }.count)

        """

        if let selectedVendor = data.selectedVendor {
            context += """

            ### Selected Vendor: \(selectedVendor.storeName)
            - Store Code: \(selectedVendor.storeCode)
            - Contact: \(selectedVendor.storeContactName)
            - Email: \(selectedVendor.storeEmail)
            - Phone: \(selectedVendor.storePhone)
            - Status: \(selectedVendor.active ? "Active" : "Inactive")
            - Commission: \(selectedVendor.formattedCommission)
            - Payout Method: \(selectedVendor.payoutMethod)
            - PayPal: \(selectedVendor.paypalEmail)

            """
        }

        if let stats = data.vendorStats {
            context += """

            ### Vendor Statistics
            - Total Orders: \(stats.totalOrders)
            - Total Revenue: $\(String(format: "%.2f", stats.totalRevenue))
            - Commission Earned: $\(String(format: "%.2f", stats.commissionTotal))
            - Commission Paid: $\(String(format: "%.2f", stats.commissionPaid))
            - Commission Pending: $\(String(format: "%.2f", stats.commissionPending))
            - Average Order Value: $\(String(format: "%.2f", stats.averageOrderValue))

            """
        }

        if let commissions = data.commissions, !commissions.isEmpty {
            context += """

            ### Recent Commissions
            \(commissions.prefix(10).map { "- Order #\($0.orderNumber): \($0.formattedAmount) (\($0.status.displayName))" }.joined(separator: "\n"))

            """
        }

        if let orders = data.orders, !orders.isEmpty {
            context += """

            ### Recent Orders
            \(orders.prefix(10).map { "- #\($0.orderNumber): \($0.status.displayName) - \($0.formattedTotal)" }.joined(separator: "\n"))

            """
        }

        // List top vendors
        if data.selectedVendor == nil {
            context += """

            ### Vendor List
            \(data.vendors.prefix(10).map { "- \($0.storeName) (\($0.storeCode)): \($0.active ? "Active" : "Inactive") - \($0.formattedCommission)" }.joined(separator: "\n"))

            """
        }

        return context
    }

    // MARK: - Public Helper Methods

    func getVendor(byId id: String) async throws -> PartnerStore? {
        let vendors = try await convex.fetchPartners()
        return vendors.first { $0.id == id }
    }

    func getVendor(byCode code: String) async throws -> PartnerStore? {
        let vendors = try await convex.fetchPartners()
        return vendors.first { $0.storeCode.lowercased() == code.lowercased() }
    }

    func getVendorCommissions(vendorId: String) async throws -> [Commission] {
        return try await convex.fetchPartnerCommissions(partnerId: vendorId)
    }

    func getVendorOrders(vendorId: String, limit: Int = 100) async throws -> [Order] {
        let allOrders = try await convex.fetchOrders(limit: limit)
        return allOrders.filter { $0.partnerStoreId == vendorId }
    }
}

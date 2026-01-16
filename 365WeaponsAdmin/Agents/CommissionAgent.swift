//
//  CommissionAgent.swift
//  365WeaponsAdmin
//
//  Agent for commission management and payouts
//

import Foundation
import Combine

// MARK: - Commission Action Types
enum CommissionAction {
    case listCommissions(filter: CommissionFilter?)
    case getCommissionDetails(commissionId: String)
    case getPartnerCommissions(partnerId: String)
    case createPayoutBatch(partnerId: String, commissionIds: [String])
    case processPayouts
    case voidCommission(commissionId: String)
    case getPayoutHistory(partnerId: String?)
    case custom(query: String)
}

// MARK: - Commission Filter
struct CommissionFilter {
    var searchQuery: String = ""
    var statuses: Set<CommissionStatus> = Set(CommissionStatus.allCases)
    var partnerId: String?
    var dateFrom: Date?
    var dateTo: Date?
    var minAmount: Double?

    var isActive: Bool {
        !searchQuery.isEmpty ||
        statuses.count != CommissionStatus.allCases.count ||
        partnerId != nil ||
        dateFrom != nil ||
        dateTo != nil ||
        minAmount != nil
    }
}

// MARK: - Commission Agent
class CommissionAgent: Agent, ObservableObject {
    let name = "commission"
    let description = "Manages partner commissions, payouts, and commission reports"

    @Published var isProcessing: Bool = false
    @Published var cachedCommissions: [Commission] = []
    @Published var lastRefresh: Date?

    private let openRouter = OpenRouterClient.shared
    private let convex = ConvexClient.shared

    private var logger: DebugLogger {
        DebugLogger.shared
    }

    // MARK: - Agent Protocol

    func canHandle(input: AgentInput) -> Bool {
        let keywords = [
            "commission", "payout", "payment", "earn", "owed",
            "partner payment", "eligible", "approved"
        ]

        let message = input.message.lowercased()
        return keywords.contains { message.contains($0) }
    }

    func process(input: AgentInput) async throws -> AgentOutput {
        await MainActor.run {
            logger.log("CommissionAgent.process() called with: '\(input.message.prefix(50))...'", category: .agent)
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
        let commissionData = try await executeAction(action)

        // Generate response
        let response = try await generateResponse(input: input, data: commissionData, action: action)

        return AgentOutput(
            response: response.text,
            agentName: name,
            toolsUsed: response.toolsUsed,
            data: commissionData.asDictionary,
            suggestedActions: response.suggestedActions,
            confidence: response.confidence
        )
    }

    // MARK: - Action Determination

    private func determineAction(input: AgentInput) async -> CommissionAction {
        let message = input.message.lowercased()

        if message.contains("list") || message.contains("all commission") || message.contains("show commission") {
            return .listCommissions(filter: nil)
        } else if message.contains("pending") || message.contains("owed") {
            return .listCommissions(filter: CommissionFilter(statuses: [.pending]))
        } else if message.contains("eligible") || message.contains("ready for payout") {
            return .listCommissions(filter: CommissionFilter(statuses: [.eligible]))
        } else if message.contains("paid") {
            return .listCommissions(filter: CommissionFilter(statuses: [.paid]))
        } else if message.contains("payout") && message.contains("process") {
            return .processPayouts
        } else if message.contains("payout history") {
            return .getPayoutHistory(partnerId: nil)
        } else if message.contains("void") {
            return .custom(query: input.message)
        } else if message.contains("partner") {
            return .custom(query: input.message)
        }

        return .custom(query: input.message)
    }

    // MARK: - Action Execution

    struct CommissionData {
        let commissions: [Commission]
        let selectedCommission: Commission?
        let partners: [PartnerStore]?
        let stats: CommissionStats?

        var asDictionary: [String: Any] {
            var dict: [String: Any] = [
                "totalCommissions": commissions.count,
                "pendingCount": commissions.filter { $0.status == .pending }.count,
                "eligibleCount": commissions.filter { $0.status == .eligible }.count,
                "paidCount": commissions.filter { $0.status == .paid }.count
            ]

            if let stats = stats {
                dict["totalAmount"] = stats.totalAmount
                dict["pendingAmount"] = stats.pendingAmount
                dict["eligibleAmount"] = stats.eligibleAmount
            }

            return dict
        }
    }

    struct CommissionStats {
        let totalAmount: Double
        let pendingAmount: Double
        let eligibleAmount: Double
        let approvedAmount: Double
        let paidAmount: Double
        let voidedAmount: Double
        let byPartner: [String: Double]
        let avgCommissionAmount: Double
        let commissionsThisMonth: Int
    }

    private func executeAction(_ action: CommissionAction) async throws -> CommissionData {
        let commissions = try await convex.fetchCommissions()
        let partners = try? await convex.fetchPartners()

        await MainActor.run {
            self.cachedCommissions = commissions
            self.lastRefresh = Date()
        }

        switch action {
        case .listCommissions(let filter):
            var filteredCommissions = commissions
            if let filter = filter {
                filteredCommissions = applyFilter(commissions: commissions, filter: filter)
            }
            let stats = calculateCommissionStats(commissions: commissions, partners: partners ?? [])
            return CommissionData(commissions: filteredCommissions, selectedCommission: nil, partners: partners, stats: stats)

        case .getCommissionDetails(let commissionId):
            let commission = commissions.first { $0.id == commissionId }
            return CommissionData(commissions: commissions, selectedCommission: commission, partners: partners, stats: nil)

        case .getPartnerCommissions(let partnerId):
            let partnerCommissions = commissions.filter { $0.partnerStoreId == partnerId }
            let stats = calculateCommissionStats(commissions: partnerCommissions, partners: partners ?? [])
            return CommissionData(commissions: partnerCommissions, selectedCommission: nil, partners: partners, stats: stats)

        case .processPayouts:
            let eligibleCommissions = commissions.filter { $0.status == .eligible }
            let stats = calculateCommissionStats(commissions: eligibleCommissions, partners: partners ?? [])
            return CommissionData(commissions: eligibleCommissions, selectedCommission: nil, partners: partners, stats: stats)

        case .getPayoutHistory(let partnerId):
            let paidCommissions = commissions.filter { $0.status == .paid }
            let filteredCommissions = partnerId != nil ? paidCommissions.filter { $0.partnerStoreId == partnerId } : paidCommissions
            return CommissionData(commissions: filteredCommissions, selectedCommission: nil, partners: partners, stats: nil)

        case .voidCommission(let commissionId):
            // Would need Convex mutation to void
            let commission = commissions.first { $0.id == commissionId }
            return CommissionData(commissions: commissions, selectedCommission: commission, partners: partners, stats: nil)

        default:
            let stats = calculateCommissionStats(commissions: commissions, partners: partners ?? [])
            return CommissionData(commissions: commissions, selectedCommission: nil, partners: partners, stats: stats)
        }
    }

    private func applyFilter(commissions: [Commission], filter: CommissionFilter) -> [Commission] {
        var result = commissions

        if !filter.searchQuery.isEmpty {
            let query = filter.searchQuery.lowercased()
            result = result.filter {
                $0.orderNumber.lowercased().contains(query)
            }
        }

        if filter.statuses.count < CommissionStatus.allCases.count {
            result = result.filter { filter.statuses.contains($0.status) }
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

        if let minAmount = filter.minAmount {
            result = result.filter { $0.commissionAmount >= minAmount }
        }

        return result
    }

    private func calculateCommissionStats(commissions: [Commission], partners: [PartnerStore]) -> CommissionStats {
        let totalAmount = commissions.reduce(0) { $0 + $1.commissionAmount }
        let pendingAmount = commissions.filter { $0.status == .pending }.reduce(0) { $0 + $1.commissionAmount }
        let eligibleAmount = commissions.filter { $0.status == .eligible }.reduce(0) { $0 + $1.commissionAmount }
        let approvedAmount = commissions.filter { $0.status == .approved }.reduce(0) { $0 + $1.commissionAmount }
        let paidAmount = commissions.filter { $0.status == .paid }.reduce(0) { $0 + $1.commissionAmount }
        let voidedAmount = commissions.filter { $0.status == .voided }.reduce(0) { $0 + $1.commissionAmount }

        var byPartner: [String: Double] = [:]
        for commission in commissions {
            let partnerName = partners.first { $0.id == commission.partnerStoreId }?.storeName ?? commission.partnerStoreId
            byPartner[partnerName, default: 0] += commission.commissionAmount
        }

        let avgAmount = commissions.isEmpty ? 0 : totalAmount / Double(commissions.count)

        let monthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
        let commissionsThisMonth = commissions.filter { $0.createdAt >= monthStart }.count

        return CommissionStats(
            totalAmount: totalAmount,
            pendingAmount: pendingAmount,
            eligibleAmount: eligibleAmount,
            approvedAmount: approvedAmount,
            paidAmount: paidAmount,
            voidedAmount: voidedAmount,
            byPartner: byPartner,
            avgCommissionAmount: avgAmount,
            commissionsThisMonth: commissionsThisMonth
        )
    }

    // MARK: - Response Generation

    struct CommissionResponse {
        let text: String
        let toolsUsed: [String]
        let suggestedActions: [SuggestedAction]
        let confidence: Double
    }

    private func generateResponse(input: AgentInput, data: CommissionData, action: CommissionAction) async throws -> CommissionResponse {
        var contextPrompt = buildContextPrompt(data: data, action: action)
        var suggestedActions: [SuggestedAction] = []
        var toolsUsed: [String] = ["convex_query", "commission_calculation"]

        switch action {
        case .listCommissions:
            suggestedActions = [
                SuggestedAction(title: "View Eligible", action: "filter_eligible", icon: "checkmark.circle"),
                SuggestedAction(title: "Process Payouts", action: "process_payouts", icon: "banknote"),
                SuggestedAction(title: "Export Report", action: "export_report", icon: "square.and.arrow.up")
            ]

        case .getPartnerCommissions:
            suggestedActions = [
                SuggestedAction(title: "Process Payout", action: "process_payout", icon: "banknote"),
                SuggestedAction(title: "View History", action: "payout_history", icon: "clock"),
                SuggestedAction(title: "View Partner", action: "view_partner", icon: "person.crop.circle")
            ]

        case .processPayouts:
            toolsUsed.append("payout_processing")
            suggestedActions = [
                SuggestedAction(title: "Confirm Payouts", action: "confirm_payouts", icon: "checkmark.seal"),
                SuggestedAction(title: "Cancel", action: "cancel", icon: "xmark.circle")
            ]

        default:
            suggestedActions = [
                SuggestedAction(title: "View All", action: "list_commissions", icon: "dollarsign.circle"),
                SuggestedAction(title: "Eligible Payouts", action: "eligible_payouts", icon: "checkmark.circle")
            ]
        }

        let systemPrompt = """
        You are the Commission Agent for 365Weapons admin. You help manage partner commissions and payouts.

        \(contextPrompt)

        Guidelines:
        - Be concise and informative
        - Highlight commissions ready for payout
        - Group by partner when showing totals
        - Format currency as $X,XXX.XX
        - Mention payout hold periods when relevant
        """

        let response = try await openRouter.chat(
            messages: [ChatCompletionMessage(role: "user", content: input.message)],
            temperature: 0.5,
            systemPrompt: systemPrompt
        )

        return CommissionResponse(
            text: response,
            toolsUsed: toolsUsed,
            suggestedActions: suggestedActions,
            confidence: 0.9
        )
    }

    private func buildContextPrompt(data: CommissionData, action: CommissionAction) -> String {
        var context = """
        ## Commission Data

        ### Overview
        - Total Commissions: \(data.commissions.count)
        - Pending: \(data.commissions.filter { $0.status == .pending }.count)
        - Eligible: \(data.commissions.filter { $0.status == .eligible }.count)
        - Approved: \(data.commissions.filter { $0.status == .approved }.count)
        - Paid: \(data.commissions.filter { $0.status == .paid }.count)

        """

        if let stats = data.stats {
            context += """

            ### Financial Summary
            - Total Commission Amount: $\(String(format: "%.2f", stats.totalAmount))
            - Pending Amount: $\(String(format: "%.2f", stats.pendingAmount))
            - Eligible for Payout: $\(String(format: "%.2f", stats.eligibleAmount))
            - Approved: $\(String(format: "%.2f", stats.approvedAmount))
            - Paid Out: $\(String(format: "%.2f", stats.paidAmount))
            - Average Commission: $\(String(format: "%.2f", stats.avgCommissionAmount))
            - Commissions This Month: \(stats.commissionsThisMonth)

            ### By Partner
            \(stats.byPartner.sorted { $0.value > $1.value }.prefix(10).map { "- \($0.key): $\(String(format: "%.2f", $0.value))" }.joined(separator: "\n"))

            """
        }

        if let selectedCommission = data.selectedCommission {
            context += """

            ### Selected Commission
            - Order: #\(selectedCommission.orderNumber)
            - Amount: \(selectedCommission.formattedAmount)
            - Base Amount: $\(String(format: "%.2f", selectedCommission.commissionBaseAmount))
            - Status: \(selectedCommission.status.displayName)
            - Service: \(selectedCommission.serviceType ?? "N/A")
            - Placed By: \(selectedCommission.placedBy)
            - Created: \(selectedCommission.createdAt.formatted())
            - Eligible At: \(selectedCommission.eligibleAt?.formatted() ?? "N/A")
            - Paid At: \(selectedCommission.paidAt?.formatted() ?? "Not paid")

            """
        }

        // List recent commissions
        if data.selectedCommission == nil {
            context += """

            ### Recent Commissions
            \(data.commissions.prefix(10).map { "- Order #\($0.orderNumber): \($0.formattedAmount) - \($0.status.displayName)" }.joined(separator: "\n"))

            """
        }

        return context
    }

    // MARK: - Public Helper Methods

    func getCommission(byId id: String) async throws -> Commission? {
        let commissions = try await convex.fetchCommissions()
        return commissions.first { $0.id == id }
    }

    func getEligibleCommissions() async throws -> [Commission] {
        let commissions = try await convex.fetchCommissions()
        return commissions.filter { $0.status == .eligible }
    }

    func getCommissionsByPartner(partnerId: String) async throws -> [Commission] {
        return try await convex.fetchPartnerCommissions(partnerId: partnerId)
    }

    func getCommissionsByStatus(status: CommissionStatus) async throws -> [Commission] {
        let commissions = try await convex.fetchCommissions()
        return commissions.filter { $0.status == status }
    }

    func getTotalEligibleAmount() async throws -> Double {
        let commissions = try await convex.fetchCommissions()
        return commissions.filter { $0.status == .eligible }.reduce(0) { $0 + $1.commissionAmount }
    }
}

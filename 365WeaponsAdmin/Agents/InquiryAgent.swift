//
//  InquiryAgent.swift
//  365WeaponsAdmin
//
//  Agent for service inquiry management
//

import Foundation
import Combine

// MARK: - Inquiry Action Types
enum InquiryAction {
    case listInquiries(status: InquiryStatus?)
    case getInquiryDetails(inquiryId: String)
    case updateStatus(inquiryId: String, status: InquiryStatus)
    case addQuote(inquiryId: String, amount: Double)
    case addNote(inquiryId: String, note: String)
    case createInvoice(inquiryId: String)
    case custom(query: String)
}

// MARK: - Inquiry Agent
class InquiryAgent: Agent, ObservableObject {
    let name = "inquiry"
    let description = "Manages service inquiries including status updates, quotes, and invoice creation"

    @Published var isProcessing: Bool = false
    @Published var cachedInquiries: [ServiceInquiry] = []
    @Published var lastRefresh: Date?

    private let openRouter = OpenRouterClient.shared
    private let convex = ConvexClient.shared

    private var logger: DebugLogger {
        DebugLogger.shared
    }

    // MARK: - Agent Protocol

    func canHandle(input: AgentInput) -> Bool {
        let keywords = [
            "inquiry", "inquiries", "quote", "service request",
            "customer question", "pricing request", "invoice"
        ]

        let message = input.message.lowercased()
        return keywords.contains { message.contains($0) }
    }

    func process(input: AgentInput) async throws -> AgentOutput {
        await MainActor.run {
            logger.log("InquiryAgent.process() called with: '\(input.message.prefix(50))...'", category: .agent)
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
        let inquiryData = try await executeAction(action)

        // Generate response
        let response = try await generateResponse(input: input, data: inquiryData, action: action)

        return AgentOutput(
            response: response.text,
            agentName: name,
            toolsUsed: response.toolsUsed,
            data: inquiryData.asDictionary,
            suggestedActions: response.suggestedActions,
            confidence: response.confidence
        )
    }

    // MARK: - Action Determination

    private func determineAction(input: AgentInput) async -> InquiryAction {
        let message = input.message.lowercased()

        if message.contains("list") || message.contains("all inquir") || message.contains("show inquir") {
            return .listInquiries(status: nil)
        } else if message.contains("new inquir") || message.contains("pending inquir") {
            return .listInquiries(status: .new)
        } else if message.contains("quoted") {
            return .listInquiries(status: .quoted)
        } else if message.contains("detail") {
            return .custom(query: input.message)
        } else if message.contains("quote") || message.contains("pricing") {
            return .custom(query: input.message)
        } else if message.contains("invoice") {
            return .custom(query: input.message)
        } else if message.contains("note") {
            return .custom(query: input.message)
        }

        return .custom(query: input.message)
    }

    // MARK: - Action Execution

    struct InquiryData {
        let inquiries: [ServiceInquiry]
        let selectedInquiry: ServiceInquiry?
        let stats: InquiryStats?

        var asDictionary: [String: Any] {
            var dict: [String: Any] = [
                "totalInquiries": inquiries.count,
                "newCount": inquiries.filter { $0.status == .new }.count,
                "quotedCount": inquiries.filter { $0.status == .quoted }.count,
                "inProgressCount": inquiries.filter { $0.status == .inProgress }.count
            ]

            if let selected = selectedInquiry {
                dict["selectedInquiry"] = selected.customerName
            }

            if let stats = stats {
                dict["avgQuoteAmount"] = stats.averageQuoteAmount
            }

            return dict
        }
    }

    struct InquiryStats {
        let totalInquiries: Int
        let byStatus: [InquiryStatus: Int]
        let byServiceType: [String: Int]
        let averageQuoteAmount: Double
        let conversionRate: Double
        let newThisWeek: Int
    }

    private func executeAction(_ action: InquiryAction) async throws -> InquiryData {
        let inquiries = try await convex.fetchInquiries()
        await MainActor.run {
            self.cachedInquiries = inquiries
            self.lastRefresh = Date()
        }

        switch action {
        case .listInquiries(let status):
            var filteredInquiries = inquiries
            if let status = status {
                filteredInquiries = inquiries.filter { $0.status == status }
            }
            let stats = calculateInquiryStats(inquiries: inquiries)
            return InquiryData(inquiries: filteredInquiries, selectedInquiry: nil, stats: stats)

        case .getInquiryDetails(let inquiryId):
            let inquiry = inquiries.first { $0.id == inquiryId }
            return InquiryData(inquiries: inquiries, selectedInquiry: inquiry, stats: nil)

        case .updateStatus(let inquiryId, let status):
            try await convex.updateInquiryStatus(inquiryId: inquiryId, status: status.rawValue)
            let updatedInquiries = try await convex.fetchInquiries()
            let inquiry = updatedInquiries.first { $0.id == inquiryId }
            return InquiryData(inquiries: updatedInquiries, selectedInquiry: inquiry, stats: nil)

        case .addQuote(let inquiryId, let amount):
            try await convex.updateInquiryQuote(inquiryId: inquiryId, amount: amount)
            let updatedInquiries = try await convex.fetchInquiries()
            let inquiry = updatedInquiries.first { $0.id == inquiryId }
            return InquiryData(inquiries: updatedInquiries, selectedInquiry: inquiry, stats: nil)

        case .addNote(let inquiryId, let note):
            try await convex.updateInquiryNotes(inquiryId: inquiryId, notes: note)
            let updatedInquiries = try await convex.fetchInquiries()
            let inquiry = updatedInquiries.first { $0.id == inquiryId }
            return InquiryData(inquiries: updatedInquiries, selectedInquiry: inquiry, stats: nil)

        case .createInvoice:
            // Invoice creation would need additional implementation
            let stats = calculateInquiryStats(inquiries: inquiries)
            return InquiryData(inquiries: inquiries, selectedInquiry: nil, stats: stats)

        case .custom:
            let stats = calculateInquiryStats(inquiries: inquiries)
            return InquiryData(inquiries: inquiries, selectedInquiry: nil, stats: stats)
        }
    }

    private func calculateInquiryStats(inquiries: [ServiceInquiry]) -> InquiryStats {
        var byStatus: [InquiryStatus: Int] = [:]
        var byServiceType: [String: Int] = [:]

        for inquiry in inquiries {
            byStatus[inquiry.status, default: 0] += 1
            byServiceType[inquiry.serviceType, default: 0] += 1
        }

        let quotedInquiries = inquiries.filter { $0.quotedAmount != nil }
        let avgQuote = quotedInquiries.isEmpty ? 0 : quotedInquiries.compactMap { $0.quotedAmount }.reduce(0, +) / Double(quotedInquiries.count)

        let completedCount = inquiries.filter { $0.status == .completed || $0.status == .paid }.count
        let conversionRate = inquiries.isEmpty ? 0 : Double(completedCount) / Double(inquiries.count)

        let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let newThisWeek = inquiries.filter { $0.createdAt >= weekStart }.count

        return InquiryStats(
            totalInquiries: inquiries.count,
            byStatus: byStatus,
            byServiceType: byServiceType,
            averageQuoteAmount: avgQuote,
            conversionRate: conversionRate,
            newThisWeek: newThisWeek
        )
    }

    // MARK: - Response Generation

    struct InquiryResponse {
        let text: String
        let toolsUsed: [String]
        let suggestedActions: [SuggestedAction]
        let confidence: Double
    }

    private func generateResponse(input: AgentInput, data: InquiryData, action: InquiryAction) async throws -> InquiryResponse {
        var contextPrompt = buildContextPrompt(data: data, action: action)
        var suggestedActions: [SuggestedAction] = []
        var toolsUsed: [String] = ["convex_query"]

        switch action {
        case .listInquiries:
            suggestedActions = [
                SuggestedAction(title: "View New", action: "filter_new", icon: "star"),
                SuggestedAction(title: "View Quoted", action: "filter_quoted", icon: "dollarsign.circle"),
                SuggestedAction(title: "View All", action: "list_all", icon: "list.bullet")
            ]

        case .getInquiryDetails:
            suggestedActions = [
                SuggestedAction(title: "Add Quote", action: "add_quote", icon: "dollarsign.circle"),
                SuggestedAction(title: "Update Status", action: "update_status", icon: "arrow.triangle.2.circlepath"),
                SuggestedAction(title: "Create Invoice", action: "create_invoice", icon: "doc.text")
            ]

        case .addQuote, .updateStatus:
            toolsUsed.append("inquiry_update")
            suggestedActions = [
                SuggestedAction(title: "Send Email", action: "send_email", icon: "envelope"),
                SuggestedAction(title: "Create Invoice", action: "create_invoice", icon: "doc.text")
            ]

        default:
            suggestedActions = [
                SuggestedAction(title: "View Inquiries", action: "list_inquiries", icon: "questionmark.circle"),
                SuggestedAction(title: "New Inquiries", action: "new_inquiries", icon: "star")
            ]
        }

        let systemPrompt = """
        You are the Inquiry Agent for 365Weapons admin. You help manage service inquiries and quotes.

        \(contextPrompt)

        Guidelines:
        - Be concise and informative
        - Highlight new inquiries needing attention
        - Mention quote amounts when relevant
        - Format currency as $X,XXX.XX
        - Track inquiry lifecycle stages
        """

        let response = try await openRouter.chat(
            messages: [ChatCompletionMessage(role: "user", content: input.message)],
            temperature: 0.5,
            systemPrompt: systemPrompt
        )

        return InquiryResponse(
            text: response,
            toolsUsed: toolsUsed,
            suggestedActions: suggestedActions,
            confidence: 0.9
        )
    }

    private func buildContextPrompt(data: InquiryData, action: InquiryAction) -> String {
        var context = """
        ## Inquiry Data

        ### Overview
        - Total Inquiries: \(data.inquiries.count)
        - New: \(data.inquiries.filter { $0.status == .new }.count)
        - Reviewed: \(data.inquiries.filter { $0.status == .reviewed }.count)
        - Quoted: \(data.inquiries.filter { $0.status == .quoted }.count)
        - In Progress: \(data.inquiries.filter { $0.status == .inProgress }.count)
        - Completed: \(data.inquiries.filter { $0.status == .completed }.count)

        """

        if let stats = data.stats {
            context += """

            ### Statistics
            - Average Quote: $\(String(format: "%.2f", stats.averageQuoteAmount))
            - Conversion Rate: \(String(format: "%.1f", stats.conversionRate * 100))%
            - New This Week: \(stats.newThisWeek)

            """
        }

        if let selectedInquiry = data.selectedInquiry {
            context += """

            ### Selected Inquiry
            - Customer: \(selectedInquiry.customerName)
            - Email: \(selectedInquiry.customerEmail)
            - Phone: \(selectedInquiry.customerPhone ?? "Not provided")
            - Service: \(selectedInquiry.productTitle)
            - Status: \(selectedInquiry.status.displayName)
            - Quote: \(selectedInquiry.formattedQuote ?? "Not quoted")
            - Message: \(selectedInquiry.message ?? "No message")
            - Created: \(selectedInquiry.createdAt.formatted())

            """
        }

        // List recent inquiries
        if data.selectedInquiry == nil {
            context += """

            ### Recent Inquiries
            \(data.inquiries.prefix(10).map { "- \($0.customerName): \($0.productTitle) - \($0.status.displayName) \($0.formattedQuote ?? "")" }.joined(separator: "\n"))

            """
        }

        return context
    }

    // MARK: - Public Helper Methods

    func getInquiry(byId id: String) async throws -> ServiceInquiry? {
        let inquiries = try await convex.fetchInquiries()
        return inquiries.first { $0.id == id }
    }

    func getNewInquiries() async throws -> [ServiceInquiry] {
        let inquiries = try await convex.fetchInquiries()
        return inquiries.filter { $0.status == .new }
    }

    func getInquiriesByStatus(status: InquiryStatus) async throws -> [ServiceInquiry] {
        let inquiries = try await convex.fetchInquiries()
        return inquiries.filter { $0.status == status }
    }

    func getInquiriesByCustomer(email: String) async throws -> [ServiceInquiry] {
        let inquiries = try await convex.fetchInquiries()
        return inquiries.filter { $0.customerEmail.lowercased() == email.lowercased() }
    }
}

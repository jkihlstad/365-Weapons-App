//
//  OrchestrationAgent.swift
//  365WeaponsAdmin
//
//  Main Orchestration Agent that coordinates all sub-agents
//

import Foundation
import Combine

// MARK: - Agent Protocol
protocol Agent {
    var name: String { get }
    var description: String { get }
    var isProcessing: Bool { get }

    func process(input: AgentInput) async throws -> AgentOutput
    func canHandle(input: AgentInput) -> Bool
}

// MARK: - Agent Types
struct AgentInput {
    let message: String
    let context: [String: Any]
    let conversationHistory: [ChatMessage]
    let metadata: [String: String]

    init(
        message: String,
        context: [String: Any] = [:],
        conversationHistory: [ChatMessage] = [],
        metadata: [String: String] = [:]
    ) {
        self.message = message
        self.context = context
        self.conversationHistory = conversationHistory
        self.metadata = metadata
    }
}

struct AgentOutput {
    let response: String
    let agentName: String
    let toolsUsed: [String]
    let data: [String: Any]?
    let suggestedActions: [SuggestedAction]
    let confidence: Double

    init(
        response: String,
        agentName: String,
        toolsUsed: [String] = [],
        data: [String: Any]? = nil,
        suggestedActions: [SuggestedAction] = [],
        confidence: Double = 1.0
    ) {
        self.response = response
        self.agentName = agentName
        self.toolsUsed = toolsUsed
        self.data = data
        self.suggestedActions = suggestedActions
        self.confidence = confidence
    }
}

struct SuggestedAction: Identifiable {
    let id = UUID()
    let title: String
    let action: String
    let icon: String
}

// MARK: - Orchestration Agent
class OrchestrationAgent: ObservableObject {
    static let shared = OrchestrationAgent()

    // MARK: - Published Properties
    @Published var isProcessing: Bool = false
    @Published var currentAgent: String?
    @Published var conversationHistory: [ChatMessage] = []
    @Published var lastOutput: AgentOutput?
    @Published var error: OrchestrationError?

    // MARK: - Sub-Agents
    lazy var dashboardAgent = DashboardAgent()
    lazy var productsAgent = ProductsAgent()
    lazy var chatAgent = ChatAgent()
    lazy var vendorAgent = VendorAgent()
    lazy var customerAgent = CustomerAgent()
    lazy var orderAgent = OrderAgent()
    lazy var inquiryAgent = InquiryAgent()
    lazy var commissionAgent = CommissionAgent()

    private var allAgents: [Agent] {
        [dashboardAgent, productsAgent, chatAgent, vendorAgent, customerAgent, orderAgent, inquiryAgent, commissionAgent]
    }

    // MARK: - Dependencies
    private let openRouter = OpenRouterClient.shared
    private let convex = ConvexClient.shared
    private let langGraph = LangGraphService.shared
    private let lanceDB = LanceDBClient.shared

    private var cancellables = Set<AnyCancellable>()

    private var logger: DebugLogger {
        DebugLogger.shared
    }

    private init() {
        setupAgentCommunication()
    }

    private func setupAgentCommunication() {
        // Setup inter-agent communication if needed
    }

    // MARK: - Main Processing

    /// Process a user message through the orchestrator
    @MainActor
    func process(message: String, context: [String: Any] = [:]) async throws -> AgentOutput {
        logger.log("Orchestrator.process() called with: '\(message.prefix(50))...'", category: .orchestrator)
        isProcessing = true
        defer { isProcessing = false }

        // Add user message to history
        let userMessage = ChatMessage(role: .user, content: message, timestamp: Date())
        conversationHistory.append(userMessage)
        logger.log("Added user message to history, total: \(conversationHistory.count)", category: .orchestrator)

        let input = AgentInput(
            message: message,
            context: context,
            conversationHistory: conversationHistory
        )

        // Route to appropriate agent
        logger.log("Routing to appropriate agent...", category: .orchestrator)
        let targetAgent = try await routeToAgent(input: input)
        currentAgent = targetAgent.name
        logger.log("Routed to agent: \(targetAgent.name)", category: .orchestrator)

        // Process with selected agent
        logger.log("Processing with \(targetAgent.name)...", category: .orchestrator)
        let output = try await targetAgent.process(input: input)
        logger.success("Agent returned response: '\(output.response.prefix(100))...'", category: .orchestrator)

        // Add assistant response to history
        let assistantMessage = ChatMessage(
            role: .assistant,
            content: output.response,
            timestamp: Date()
        )
        conversationHistory.append(assistantMessage)

        lastOutput = output
        currentAgent = nil

        return output
    }

    /// Process with streaming response
    @MainActor
    func processStreaming(
        message: String,
        context: [String: Any] = [:],
        onToken: @escaping (String) -> Void
    ) async throws -> AgentOutput {
        logger.log("Orchestrator.processStreaming() called with: '\(message.prefix(50))...'", category: .orchestrator)
        isProcessing = true
        defer { isProcessing = false }

        // Add user message
        let userMessage = ChatMessage(role: .user, content: message, timestamp: Date())
        conversationHistory.append(userMessage)
        logger.log("Added user message to history, total: \(conversationHistory.count)", category: .orchestrator)

        let input = AgentInput(
            message: message,
            context: context,
            conversationHistory: conversationHistory
        )

        // Route to agent
        logger.log("Routing to appropriate agent...", category: .orchestrator)
        let targetAgent = try await routeToAgent(input: input)
        currentAgent = targetAgent.name
        logger.log("Routed to agent: \(targetAgent.name)", category: .orchestrator)

        // For streaming, use the chat agent with streaming
        var fullResponse = ""

        if let chatAgent = targetAgent as? ChatAgent {
            logger.log("Using ChatAgent with streaming...", category: .orchestrator)
            fullResponse = try await chatAgent.processStreaming(input: input, onToken: onToken)
            logger.success("Streaming completed, response length: \(fullResponse.count)", category: .orchestrator)
        } else {
            logger.log("Non-ChatAgent, processing without streaming...", category: .orchestrator)
            let output = try await targetAgent.process(input: input)
            fullResponse = output.response
            onToken(fullResponse)
            logger.success("Non-streaming response received: \(fullResponse.count) chars", category: .orchestrator)
        }

        let output = AgentOutput(
            response: fullResponse,
            agentName: targetAgent.name
        )

        // Add to history
        let assistantMessage = ChatMessage(
            role: .assistant,
            content: fullResponse,
            timestamp: Date()
        )
        conversationHistory.append(assistantMessage)

        lastOutput = output
        currentAgent = nil

        return output
    }

    // MARK: - Routing

    /// Route input to the most appropriate agent
    private func routeToAgent(input: AgentInput) async throws -> Agent {
        await MainActor.run {
            logger.log("routeToAgent called for: '\(input.message.prefix(30))...'", category: .orchestrator)
        }

        // Check if any agent explicitly can handle this
        for agent in allAgents {
            if agent.canHandle(input: input) {
                await MainActor.run {
                    logger.log("Agent \(agent.name) can explicitly handle this", category: .orchestrator)
                }
                return agent
            }
        }

        await MainActor.run {
            logger.log("No explicit handler, using LLM for routing...", category: .orchestrator)
        }

        // Use LLM to determine routing
        let routingPrompt = """
        Analyze the following user request and determine which agent should handle it.

        Available agents:
        1. dashboard - Analytics, statistics, revenue, business insights, charts, graphs, overall metrics
        2. products - Product management, inventory, catalog, creating/updating products, stock
        3. vendor - Vendor/partner management, partner details, partner settings, FFL dealers
        4. customer - Customer management, contact lists, newsletter subscribers, customer info
        5. order - Order management, order status, shipping, tracking, bulk order operations
        6. inquiry - Service inquiries, quotes, pricing requests, inquiry status
        7. commission - Partner commissions, payouts, commission reports, payment processing
        8. chat - General questions, help, conversational AI, anything not specific to above

        User request: "\(input.message)"

        Respond with ONLY one word from: "dashboard", "products", "vendor", "customer", "order", "inquiry", "commission", or "chat"
        """

        let response = try await openRouter.chat(
            messages: [ChatCompletionMessage(role: "user", content: routingPrompt)],
            model: OpenRouterConfig.fastModel,
            temperature: 0.1,
            maxTokens: 10
        )

        let agentName = response.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        await MainActor.run {
            logger.log("LLM routing response: '\(agentName)'", category: .orchestrator)
        }

        switch agentName {
        case let name where name.contains("dashboard"):
            return dashboardAgent
        case let name where name.contains("product"):
            return productsAgent
        case let name where name.contains("vendor"):
            return vendorAgent
        case let name where name.contains("customer"):
            return customerAgent
        case let name where name.contains("order"):
            return orderAgent
        case let name where name.contains("inquiry"):
            return inquiryAgent
        case let name where name.contains("commission"):
            return commissionAgent
        default:
            return chatAgent
        }
    }

    // MARK: - Direct Agent Access

    /// Get dashboard insights
    func getDashboardInsights() async throws -> AgentOutput {
        let input = AgentInput(message: "Give me a summary of the current dashboard metrics and any notable trends or issues.")
        return try await dashboardAgent.process(input: input)
    }

    /// Get product recommendations
    func getProductRecommendations() async throws -> AgentOutput {
        let input = AgentInput(message: "What products need attention? Check for low stock, popular items, and pricing recommendations.")
        return try await productsAgent.process(input: input)
    }

    // MARK: - Conversation Management

    /// Clear conversation history
    @MainActor
    func clearHistory() {
        conversationHistory.removeAll()
        lastOutput = nil
    }

    /// Get conversation summary
    func getConversationSummary() async throws -> String {
        guard !conversationHistory.isEmpty else {
            return "No conversation history."
        }

        let historyText = conversationHistory.map { "\($0.role.rawValue): \($0.content)" }.joined(separator: "\n")

        let summary = try await openRouter.chat(
            messages: [ChatCompletionMessage(role: "user", content: "Summarize this conversation in 2-3 sentences:\n\(historyText)")],
            model: OpenRouterConfig.fastModel,
            maxTokens: 200
        )

        return summary
    }

    // MARK: - Multi-Agent Coordination

    /// Run a complex task requiring multiple agents
    func runMultiAgentTask(task: String) async throws -> [AgentOutput] {
        var outputs: [AgentOutput] = []

        // Decompose task
        let decompositionPrompt = """
        Break down this task into subtasks that can be handled by different agents:
        - dashboard: analytics and insights
        - products: product management
        - chat: general assistance

        Task: \(task)

        Respond as JSON array: [{"agent": "name", "subtask": "description"}]
        """

        let decomposition = try await openRouter.chat(
            messages: [ChatCompletionMessage(role: "user", content: decompositionPrompt)],
            model: OpenRouterConfig.fastModel
        )

        // Parse and execute subtasks
        if let data = decomposition.data(using: .utf8),
           let subtasks = try? JSONDecoder().decode([SubTask].self, from: data) {
            for subtask in subtasks {
                let input = AgentInput(message: subtask.subtask)
                let agent: Agent

                switch subtask.agent {
                case "dashboard": agent = dashboardAgent
                case "products": agent = productsAgent
                default: agent = chatAgent
                }

                let output = try await agent.process(input: input)
                outputs.append(output)
            }
        }

        return outputs
    }
}

// MARK: - Supporting Types
struct SubTask: Codable {
    let agent: String
    let subtask: String
}

// MARK: - Error Types
enum OrchestrationError: Error, LocalizedError {
    case noAgentAvailable
    case routingFailed(String)
    case processingFailed(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .noAgentAvailable:
            return "No agent available to handle this request"
        case .routingFailed(let message):
            return "Routing failed: \(message)"
        case .processingFailed(let message):
            return "Processing failed: \(message)"
        case .timeout:
            return "Request timed out"
        }
    }
}

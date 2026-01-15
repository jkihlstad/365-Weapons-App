//
//  LangGraphService.swift
//  365WeaponsAdmin
//
//  LangChain/LangGraph integration for agent orchestration
//

import Foundation
import Combine

// MARK: - LangGraph Configuration
struct LangGraphConfig {
    static var serverEndpoint: String = "https://api.365weapons.com/langgraph"
    static let defaultTimeout: TimeInterval = 120
}

// MARK: - Graph State
struct GraphState: Codable {
    var messages: [AgentMessage]
    var currentAgent: String?
    var context: [String: AnyCodable]
    var toolCalls: [ToolCall]
    var result: String?
    var error: String?
    var isComplete: Bool

    init() {
        self.messages = []
        self.currentAgent = nil
        self.context = [:]
        self.toolCalls = []
        self.result = nil
        self.error = nil
        self.isComplete = false
    }
}

struct AgentMessage: Codable, Identifiable {
    let id: String
    let role: String
    let content: String
    let agentName: String?
    let timestamp: Date

    init(id: String = UUID().uuidString, role: String, content: String, agentName: String? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.agentName = agentName
        self.timestamp = Date()
    }
}

struct ToolCall: Codable, Identifiable {
    let id: String
    let toolName: String
    let arguments: [String: AnyCodable]
    let result: String?
    let status: ToolCallStatus
}

enum ToolCallStatus: String, Codable {
    case pending
    case running
    case completed
    case failed
}

// MARK: - AnyCodable for flexible JSON
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - LangGraph Service
class LangGraphService: ObservableObject {
    static let shared = LangGraphService()

    @Published var currentState: GraphState = GraphState()
    @Published var isProcessing: Bool = false
    @Published var executionHistory: [GraphExecution] = []
    @Published var error: LangGraphError?

    private let session: URLSession
    private var authToken: String?
    private var openRouterClient: OpenRouterClient { OpenRouterClient.shared }
    private var cancellables = Set<AnyCancellable>()

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = LangGraphConfig.defaultTimeout
        self.session = URLSession(configuration: config)
    }

    // MARK: - Configuration
    func configure(serverEndpoint: String, authToken: String) {
        LangGraphConfig.serverEndpoint = serverEndpoint
        self.authToken = authToken
    }

    // MARK: - Graph Execution

    /// Run a graph with the given input
    func runGraph(
        graphName: String,
        input: String,
        context: [String: Any] = [:]
    ) async throws -> GraphState {
        isProcessing = true
        defer { isProcessing = false }

        var state = GraphState()
        state.messages.append(AgentMessage(role: "user", content: input))
        state.context = context.mapValues { AnyCodable($0) }

        let execution = GraphExecution(
            id: UUID().uuidString,
            graphName: graphName,
            input: input,
            startTime: Date()
        )

        do {
            // Execute the graph
            state = try await executeGraph(graphName: graphName, state: state)

            var completedExecution = execution
            completedExecution.endTime = Date()
            completedExecution.status = .completed
            completedExecution.output = state.result

            await MainActor.run {
                self.executionHistory.insert(completedExecution, at: 0)
                self.currentState = state
            }

            return state
        } catch {
            var failedExecution = execution
            failedExecution.endTime = Date()
            failedExecution.status = .failed
            failedExecution.error = error.localizedDescription

            await MainActor.run {
                self.executionHistory.insert(failedExecution, at: 0)
                self.error = error as? LangGraphError ?? .executionFailed(error.localizedDescription)
            }

            throw error
        }
    }

    /// Execute the graph on the server
    private func executeGraph(graphName: String, state: GraphState) async throws -> GraphState {
        guard let authToken = authToken else {
            // Fall back to local execution if no server configured
            return try await executeGraphLocally(graphName: graphName, state: state)
        }

        var request = URLRequest(url: URL(string: "\(LangGraphConfig.serverEndpoint)/run")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let body = GraphExecutionRequest(
            graphName: graphName,
            state: state
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LangGraphError.executionFailed(errorMessage)
        }

        let result = try JSONDecoder().decode(GraphState.self, from: data)
        return result
    }

    // MARK: - Local Graph Execution (Fallback)

    /// Execute graph locally using OpenRouter for LLM calls
    private func executeGraphLocally(graphName: String, state: GraphState) async throws -> GraphState {
        var currentState = state

        switch graphName {
        case "admin_orchestrator":
            currentState = try await runAdminOrchestratorGraph(state: currentState)
        case "dashboard_agent":
            currentState = try await runDashboardAgentGraph(state: currentState)
        case "products_agent":
            currentState = try await runProductsAgentGraph(state: currentState)
        case "chat_agent":
            currentState = try await runChatAgentGraph(state: currentState)
        default:
            throw LangGraphError.unknownGraph(graphName)
        }

        return currentState
    }

    /// Admin Orchestrator Graph
    private func runAdminOrchestratorGraph(state: GraphState) async throws -> GraphState {
        var currentState = state
        currentState.currentAgent = "orchestrator"

        guard let userMessage = state.messages.last?.content else {
            currentState.error = "No input message"
            currentState.isComplete = true
            return currentState
        }

        // Determine which sub-agent to route to
        let routingPrompt = """
        You are an orchestrator that routes user requests to the appropriate sub-agent.

        Available agents:
        1. dashboard_agent - For analytics, statistics, revenue data, order summaries, and business insights
        2. products_agent - For product management, inventory, creating/updating products, and catalog queries
        3. chat_agent - For general questions, conversational AI, and help with using the admin dashboard

        User request: \(userMessage)

        Respond with ONLY the agent name (dashboard_agent, products_agent, or chat_agent) that should handle this request.
        """

        let routingResponse = try await openRouterClient.chat(
            messages: [ChatCompletionMessage(role: "user", content: routingPrompt)],
            model: OpenRouterConfig.fastModel,
            temperature: 0.1
        )

        let targetAgent = routingResponse.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        currentState.messages.append(AgentMessage(
            role: "assistant",
            content: "Routing to \(targetAgent)",
            agentName: "orchestrator"
        ))

        // Route to appropriate agent
        switch targetAgent {
        case let agent where agent.contains("dashboard"):
            currentState = try await runDashboardAgentGraph(state: currentState)
        case let agent where agent.contains("product"):
            currentState = try await runProductsAgentGraph(state: currentState)
        default:
            currentState = try await runChatAgentGraph(state: currentState)
        }

        return currentState
    }

    /// Dashboard Agent Graph
    private func runDashboardAgentGraph(state: GraphState) async throws -> GraphState {
        var currentState = state
        currentState.currentAgent = "dashboard_agent"

        guard let userMessage = state.messages.first(where: { $0.role == "user" })?.content else {
            currentState.error = "No user message found"
            currentState.isComplete = true
            return currentState
        }

        // Fetch dashboard data
        let stats = try? await ConvexClient.shared.fetchDashboardStats()
        let orders = try? await ConvexClient.shared.fetchOrders(limit: 10)

        let contextData = """
        Dashboard Statistics:
        - Total Revenue: $\(String(format: "%.2f", stats?.totalRevenue ?? 0))
        - Total Orders: \(stats?.totalOrders ?? 0)
        - Total Products: \(stats?.totalProducts ?? 0)
        - Total Partners: \(stats?.totalPartners ?? 0)
        - Pending Orders: \(stats?.pendingOrders ?? 0)
        - Revenue Growth: \(String(format: "%.1f", stats?.revenueGrowth ?? 0))%

        Recent Orders:
        \(orders?.prefix(5).map { "- #\($0.orderNumber): \($0.status.displayName) - \($0.formattedTotal)" }.joined(separator: "\n") ?? "No orders")
        """

        let response = try await openRouterClient.chat(
            messages: [ChatCompletionMessage(role: "user", content: userMessage)],
            systemPrompt: """
            You are the Dashboard Agent for 365Weapons admin. You provide insights about business analytics, statistics, and performance metrics.

            Current Data:
            \(contextData)

            Provide helpful, data-driven insights based on the user's question.
            """
        )

        currentState.messages.append(AgentMessage(
            role: "assistant",
            content: response,
            agentName: "dashboard_agent"
        ))

        currentState.result = response
        currentState.isComplete = true

        return currentState
    }

    /// Products Agent Graph
    private func runProductsAgentGraph(state: GraphState) async throws -> GraphState {
        var currentState = state
        currentState.currentAgent = "products_agent"

        guard let userMessage = state.messages.first(where: { $0.role == "user" })?.content else {
            currentState.error = "No user message found"
            currentState.isComplete = true
            return currentState
        }

        // Fetch products data
        let products = try? await ConvexClient.shared.fetchProducts()

        let contextData = """
        Product Catalog:
        Total Products: \(products?.count ?? 0)

        Categories:
        \(Set(products?.map { $0.category } ?? []).joined(separator: ", "))

        Sample Products:
        \(products?.prefix(10).map { "- \($0.title) (\($0.category)): \($0.formattedPrice) - \($0.inStock ? "In Stock" : "Out of Stock")" }.joined(separator: "\n") ?? "No products")
        """

        let response = try await openRouterClient.chat(
            messages: [ChatCompletionMessage(role: "user", content: userMessage)],
            systemPrompt: """
            You are the Products Agent for 365Weapons admin. You help with product management, inventory, and catalog queries.

            Current Product Data:
            \(contextData)

            If the user wants to create or update products, provide guidance on what information is needed.
            """
        )

        currentState.messages.append(AgentMessage(
            role: "assistant",
            content: response,
            agentName: "products_agent"
        ))

        currentState.result = response
        currentState.isComplete = true

        return currentState
    }

    /// Chat Agent Graph
    private func runChatAgentGraph(state: GraphState) async throws -> GraphState {
        var currentState = state
        currentState.currentAgent = "chat_agent"

        guard let userMessage = state.messages.first(where: { $0.role == "user" })?.content else {
            currentState.error = "No user message found"
            currentState.isComplete = true
            return currentState
        }

        // Try to get RAG context
        let ragContext = try? await LanceDBClient.shared.getRAGContext(query: userMessage)

        let response = try await openRouterClient.chat(
            messages: [ChatCompletionMessage(role: "user", content: userMessage)],
            systemPrompt: """
            You are a helpful AI assistant for the 365Weapons admin dashboard. You help administrators with questions about using the dashboard, understanding features, and general inquiries.

            \(ragContext.map { "Relevant Context:\n\($0)" } ?? "")

            Be helpful, concise, and professional.
            """
        )

        currentState.messages.append(AgentMessage(
            role: "assistant",
            content: response,
            agentName: "chat_agent"
        ))

        currentState.result = response
        currentState.isComplete = true

        return currentState
    }

    // MARK: - Streaming Execution

    /// Run graph with streaming output
    func streamGraph(
        graphName: String,
        input: String,
        context: [String: Any] = [:],
        onToken: @escaping (String) -> Void
    ) async throws -> GraphState {
        isProcessing = true
        defer { isProcessing = false }

        var state = GraphState()
        state.messages.append(AgentMessage(role: "user", content: input))
        state.context = context.mapValues { AnyCodable($0) }
        state.currentAgent = "orchestrator"

        // Stream the response
        var fullResponse = ""

        try await openRouterClient.streamChat(
            messages: [ChatCompletionMessage(role: "user", content: input)],
            systemPrompt: "You are an intelligent admin assistant for 365Weapons."
        ) { token in
            fullResponse += token
            onToken(token)
        }

        state.messages.append(AgentMessage(
            role: "assistant",
            content: fullResponse,
            agentName: "chat_agent"
        ))

        state.result = fullResponse
        state.isComplete = true

        await MainActor.run {
            self.currentState = state
        }

        return state
    }
}

// MARK: - Graph Execution Types
struct GraphExecution: Identifiable {
    let id: String
    let graphName: String
    let input: String
    let startTime: Date
    var endTime: Date?
    var status: ExecutionStatus = .running
    var output: String?
    var error: String?

    var duration: TimeInterval? {
        guard let end = endTime else { return nil }
        return end.timeIntervalSince(startTime)
    }
}

enum ExecutionStatus: String {
    case running
    case completed
    case failed
}

struct GraphExecutionRequest: Encodable {
    let graphName: String
    let state: GraphState
}

// MARK: - Error Types
enum LangGraphError: Error, LocalizedError {
    case notConfigured
    case unknownGraph(String)
    case executionFailed(String)
    case invalidState
    case timeout

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "LangGraph service not configured"
        case .unknownGraph(let name):
            return "Unknown graph: \(name)"
        case .executionFailed(let message):
            return "Execution failed: \(message)"
        case .invalidState:
            return "Invalid graph state"
        case .timeout:
            return "Graph execution timed out"
        }
    }
}

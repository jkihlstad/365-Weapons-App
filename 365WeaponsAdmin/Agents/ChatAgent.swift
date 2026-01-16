//
//  ChatAgent.swift
//  365WeaponsAdmin
//
//  Chat Agent for general AI assistance with voice capabilities
//

import Foundation
import Combine

// MARK: - Chat Agent
class ChatAgent: Agent, ObservableObject {
    let name = "chat"
    let description = "Handles general questions, conversational AI, help, and voice interactions"

    @Published var isProcessing: Bool = false
    @Published var conversationHistory: [ChatCompletionMessage] = []
    @Published var isListening: Bool = false
    @Published var isSpeaking: Bool = false

    private let openRouter = OpenRouterClient.shared
    private let openAI = OpenAIClient.shared
    private let lanceDB = LanceDBClient.shared
    private let convex = ConvexClient.shared
    private let tavily = TavilyClient.shared

    /// Whether web search is enabled for this agent
    var canSearchWeb: Bool = true

    private var logger: DebugLogger {
        DebugLogger.shared
    }

    private var systemPrompt: String {
        """
        You are a friendly and helpful AI assistant for the 365Weapons admin dashboard. You help administrators manage their firearms service business.

        About 365Weapons:
        365Weapons is a firearms service company offering porting services, optic cuts, slide engraving, and custom gunsmithing.

        Your Capabilities:
        You can answer questions about the admin dashboard, explain business metrics, help with order and product management, provide insights about partners, troubleshoot issues, and offer business recommendations.

        Important Guidelines:
        - Respond in a natural, conversational tone like you're talking to a colleague
        - Keep responses concise and easy to read
        - Do NOT use markdown formatting like **bold**, *italic*, ##headers, or bullet points with dashes
        - Write in plain, flowing sentences instead of lists when possible
        - If you need to list items, use simple numbered lists or commas
        - Be helpful and professional, but also personable
        - If you don't know something, just say so naturally
        - Reference specific dashboard features when helpful
        """
    }

    // MARK: - Agent Protocol

    func canHandle(input: AgentInput) -> Bool {
        // Chat agent is the default fallback, but prioritize explicit chat requests
        let keywords = ["help", "how do i", "what is", "explain", "can you", "tell me"]
        let message = input.message.lowercased()
        return keywords.contains { message.contains($0) }
    }

    func process(input: AgentInput) async throws -> AgentOutput {
        await MainActor.run {
            logger.log("ChatAgent.process() called with: '\(input.message.prefix(50))...'", category: .chat)
            isProcessing = true
        }
        defer {
            Task { @MainActor in
                self.isProcessing = false
            }
        }

        var toolsUsed: [String] = []

        // Get RAG context if available
        await MainActor.run {
            logger.log("Fetching RAG context...", category: .chat)
        }
        let ragContext = try? await lanceDB.getRAGContext(query: input.message)
        await MainActor.run {
            logger.log("RAG context: \(ragContext != nil ? "found" : "none")", category: .chat)
        }
        if ragContext != nil {
            toolsUsed.append("lancedb_rag")
        }

        // Check if web search would be helpful
        var webSearchContext: String?
        if canSearchWeb && tavily.shouldSearchWeb(for: input.message) {
            await MainActor.run {
                logger.log("Performing web search for: '\(input.message.prefix(30))...'", category: .chat)
            }
            do {
                let searchResults = try await tavily.search(query: input.message, maxResults: 5)
                if !searchResults.isEmpty {
                    webSearchContext = tavily.formatResultsForContext(searchResults)
                    toolsUsed.append("tavily_search")
                    await MainActor.run {
                        logger.success("Web search returned \(searchResults.count) results", category: .chat)
                    }
                }
            } catch {
                await MainActor.run {
                    logger.error("Web search failed: \(error.localizedDescription)", category: .chat)
                }
            }
        }

        // Get business context
        await MainActor.run {
            logger.log("Fetching business context...", category: .chat)
        }
        let businessContext = try? await getBusinessContext()
        await MainActor.run {
            logger.log("Business context: \(businessContext != nil ? "found" : "none")", category: .chat)
        }

        // Build enhanced system prompt
        var enhancedPrompt = systemPrompt

        if let ragContext = ragContext, !ragContext.isEmpty {
            enhancedPrompt += "\n\n## Relevant Context\n\(ragContext)"
        }

        if let webContext = webSearchContext {
            enhancedPrompt += "\n\n## Web Search Results\n\(webContext)\n\nUse these web search results to provide current and accurate information. Cite sources when relevant."
        }

        if let businessContext = businessContext {
            enhancedPrompt += "\n\n## Current Business State\n\(businessContext)"
        }

        // Add conversation history
        var messages = conversationHistory
        messages.append(ChatCompletionMessage(role: "user", content: input.message))
        await MainActor.run {
            logger.log("Sending \(messages.count) messages to OpenRouter...", category: .chat)
        }

        toolsUsed.append("openrouter_chat")

        // Generate response
        let response = try await openRouter.chat(
            messages: messages,
            temperature: 0.7,
            systemPrompt: enhancedPrompt
        )
        await MainActor.run {
            logger.success("ChatAgent received response: '\(response.prefix(100))...'", category: .chat)
        }

        // Update conversation history
        conversationHistory.append(ChatCompletionMessage(role: "user", content: input.message))
        conversationHistory.append(ChatCompletionMessage(role: "assistant", content: response))

        // Keep history manageable (last 20 messages)
        if conversationHistory.count > 20 {
            conversationHistory = Array(conversationHistory.suffix(20))
        }

        // Generate suggested actions based on response
        let suggestedActions = await generateSuggestedActions(response: response, input: input)

        return AgentOutput(
            response: response,
            agentName: name,
            toolsUsed: toolsUsed,
            data: nil,
            suggestedActions: suggestedActions,
            confidence: 0.9
        )
    }

    /// Process with streaming output
    func processStreaming(input: AgentInput, onToken: @escaping (String) -> Void) async throws -> String {
        await MainActor.run {
            logger.log("ChatAgent.processStreaming() called with: '\(input.message.prefix(50))...'", category: .chat)
            isProcessing = true
        }
        defer {
            Task { @MainActor in
                self.isProcessing = false
            }
        }

        // Get context
        await MainActor.run {
            logger.log("Fetching RAG and business context...", category: .chat)
        }
        let ragContext = try? await lanceDB.getRAGContext(query: input.message)
        let businessContext = try? await getBusinessContext()

        // Check if web search would be helpful
        var webSearchContext: String?
        if canSearchWeb && tavily.shouldSearchWeb(for: input.message) {
            await MainActor.run {
                logger.log("Performing web search for streaming...", category: .chat)
            }
            do {
                let searchResults = try await tavily.search(query: input.message, maxResults: 5)
                if !searchResults.isEmpty {
                    webSearchContext = tavily.formatResultsForContext(searchResults)
                    await MainActor.run {
                        logger.success("Web search returned \(searchResults.count) results", category: .chat)
                    }
                }
            } catch {
                await MainActor.run {
                    logger.error("Web search failed: \(error.localizedDescription)", category: .chat)
                }
            }
        }

        var enhancedPrompt = systemPrompt
        if let ragContext = ragContext, !ragContext.isEmpty {
            enhancedPrompt += "\n\n## Relevant Context\n\(ragContext)"
        }
        if let webContext = webSearchContext {
            enhancedPrompt += "\n\n## Web Search Results\n\(webContext)\n\nUse these web search results to provide current and accurate information. Cite sources when relevant."
        }
        if let businessContext = businessContext {
            enhancedPrompt += "\n\n## Current Business State\n\(businessContext)"
        }

        var messages = conversationHistory
        messages.append(ChatCompletionMessage(role: "user", content: input.message))

        await MainActor.run {
            logger.log("Starting stream chat with \(messages.count) messages...", category: .chat)
        }

        var fullResponse = ""

        try await openRouter.streamChat(
            messages: messages,
            systemPrompt: enhancedPrompt,
            onChunk: { chunk in
                fullResponse += chunk
                onToken(chunk)
            }
        )

        await MainActor.run {
            logger.success("Streaming completed, response length: \(fullResponse.count)", category: .chat)
        }

        // Update history
        conversationHistory.append(ChatCompletionMessage(role: "user", content: input.message))
        conversationHistory.append(ChatCompletionMessage(role: "assistant", content: fullResponse))

        return fullResponse
    }

    // MARK: - Voice Capabilities

    /// Start voice input
    @MainActor
    func startListening() async throws {
        isListening = true
        try openAI.startRecording()
    }

    /// Stop listening and process voice input
    @MainActor
    func stopListening() async throws -> String {
        isListening = false
        let transcript = try await openAI.stopRecording()
        return transcript
    }

    /// Alias for startListening for compatibility
    @MainActor
    func startRecording() throws {
        Task {
            try await startListening()
        }
    }

    /// Alias for stopListening for compatibility
    @MainActor
    func stopRecording() async throws -> String {
        return try await stopListening()
    }

    /// Process voice input and get response
    @MainActor
    func processVoiceInput() async throws -> AgentOutput {
        let transcript = try await stopListening()

        let input = AgentInput(
            message: transcript,
            metadata: ["inputType": "voice"]
        )

        return try await process(input: input)
    }

    /// Speak the response
    @MainActor
    func speak(text: String, voice: String? = nil) async throws {
        isSpeaking = true
        defer { isSpeaking = false }
        try await openAI.speak(text: text, voice: voice)
    }

    /// Process voice input and speak response
    @MainActor
    func voiceConversation() async throws {
        // Get voice input
        let output = try await processVoiceInput()

        // Speak the response
        try await speak(text: output.response)
    }

    /// Cancel any ongoing voice activity
    @MainActor
    func cancelVoice() {
        if isListening {
            openAI.cancelRecording()
            isListening = false
        }
        if isSpeaking {
            openAI.stopSpeaking()
            isSpeaking = false
        }
    }

    // MARK: - Context Building

    private func getBusinessContext() async throws -> String {
        let stats = try await convex.fetchDashboardStats()

        return """
        - Total Revenue: $\(String(format: "%.2f", stats.totalRevenue))
        - Orders: \(stats.totalOrders) total, \(stats.pendingOrders) pending
        - Products: \(stats.totalProducts)
        - Partners: \(stats.totalPartners)
        - Pending Inquiries: \(stats.pendingInquiries)
        """
    }

    private func generateSuggestedActions(response: String, input: AgentInput) async -> [SuggestedAction] {
        var actions: [SuggestedAction] = []

        let responseLower = response.lowercased()

        // Suggest relevant actions based on response content
        if responseLower.contains("order") {
            actions.append(SuggestedAction(title: "View Orders", action: "navigate_orders", icon: "list.clipboard"))
        }

        if responseLower.contains("product") {
            actions.append(SuggestedAction(title: "View Products", action: "navigate_products", icon: "cube.box"))
        }

        if responseLower.contains("partner") || responseLower.contains("vendor") {
            actions.append(SuggestedAction(title: "View Partners", action: "navigate_partners", icon: "person.2"))
        }

        if responseLower.contains("analytics") || responseLower.contains("revenue") {
            actions.append(SuggestedAction(title: "View Dashboard", action: "navigate_dashboard", icon: "chart.bar"))
        }

        if responseLower.contains("inquiry") || responseLower.contains("inquiries") {
            actions.append(SuggestedAction(title: "View Inquiries", action: "navigate_inquiries", icon: "questionmark.circle"))
        }

        // Limit to 3 actions
        return Array(actions.prefix(3))
    }

    // MARK: - Conversation Management

    /// Clear conversation history
    func clearHistory() {
        conversationHistory.removeAll()
    }

    /// Get conversation summary
    func getSummary() async throws -> String {
        guard !conversationHistory.isEmpty else {
            return "No conversation history."
        }

        let historyText = conversationHistory.map { "\($0.role): \($0.content)" }.joined(separator: "\n")

        return try await openRouter.chat(
            messages: [ChatCompletionMessage(role: "user", content: "Summarize this conversation briefly:\n\(historyText)")],
            model: OpenRouterConfig.fastModel,
            maxTokens: 200
        )
    }

    /// Export conversation
    func exportConversation() -> String {
        var export = "# 365Weapons Admin Chat Export\n"
        export += "Date: \(Date())\n\n"

        for message in conversationHistory {
            let role = message.role == "user" ? "You" : "Assistant"
            export += "**\(role):** \(message.content)\n\n"
        }

        return export
    }

    // MARK: - Quick Actions

    /// Get quick help for a topic
    func quickHelp(topic: String) async throws -> String {
        let prompt = "Provide a brief, helpful explanation about: \(topic) in the context of the 365Weapons admin dashboard."

        return try await openRouter.chat(
            messages: [ChatCompletionMessage(role: "user", content: prompt)],
            model: OpenRouterConfig.fastModel,
            maxTokens: 300,
            systemPrompt: systemPrompt
        )
    }

    /// Generate a daily briefing
    func getDailyBriefing() async throws -> String {
        let stats = try await convex.fetchDashboardStats()
        let orders = try await convex.fetchOrders(limit: 5)
        let inquiries = try await convex.fetchInquiries(status: "NEW")

        let context = """
        Today's Dashboard State:
        - Revenue: $\(String(format: "%.2f", stats.totalRevenue)) (\(String(format: "%.1f", stats.revenueGrowth))% growth)
        - Orders: \(stats.totalOrders) total, \(stats.pendingOrders) pending
        - New inquiries: \(inquiries.count)
        - Eligible commissions: $\(String(format: "%.2f", stats.eligibleCommissions))

        Recent orders:
        \(orders.prefix(3).map { "- #\($0.orderNumber): \($0.status.displayName)" }.joined(separator: "\n"))
        """

        let prompt = """
        Generate a brief daily briefing for the admin based on this data:
        \(context)

        Include:
        1. Quick summary of business status
        2. Important items needing attention
        3. One actionable recommendation
        """

        return try await openRouter.chat(
            messages: [ChatCompletionMessage(role: "user", content: prompt)],
            temperature: 0.6,
            systemPrompt: systemPrompt
        )
    }

    /// Answer a FAQ
    func answerFAQ(question: String) async throws -> String {
        // Check RAG first for documented answers
        if let ragContext = try? await lanceDB.getRAGContext(query: question, limit: 3),
           !ragContext.isEmpty {
            let prompt = "Answer this question using the provided context:\n\nQuestion: \(question)\n\nContext:\n\(ragContext)"

            return try await openRouter.chat(
                messages: [ChatCompletionMessage(role: "user", content: prompt)],
                model: OpenRouterConfig.fastModel,
                maxTokens: 400
            )
        }

        // Fall back to general knowledge
        return try await quickHelp(topic: question)
    }
}

// MARK: - Voice Conversation State
struct VoiceConversationState {
    var isActive: Bool = false
    var lastTranscript: String?
    var lastResponse: String?
    var error: Error?
}

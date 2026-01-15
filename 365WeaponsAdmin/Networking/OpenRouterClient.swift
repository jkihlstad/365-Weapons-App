//
//  OpenRouterClient.swift
//  365WeaponsAdmin
//
//  OpenRouter AI Client for intelligent chat capabilities
//  Enhanced with unified error handling and retry support
//

import Foundation
import Combine

// MARK: - OpenRouter Configuration
struct OpenRouterConfig {
    static let baseURL = "https://openrouter.ai/api/v1"
    static let chatEndpoint = "\(baseURL)/chat/completions"
    static let modelsEndpoint = "\(baseURL)/models"

    // Default model - updated to current OpenRouter model IDs (Dec 2025)
    static let defaultModel = "anthropic/claude-sonnet-4"        // Best balance of speed/quality
    static let fastModel = "anthropic/claude-3.5-haiku"          // Fast responses
    static let advancedModel = "anthropic/claude-sonnet-4.5"     // Most capable

    // App identification for OpenRouter
    static let siteURL = "https://365weapons.com"
    static let siteName = "365Weapons Admin"

    // Retry configuration for AI requests
    static let defaultRetryConfig = RetryConfiguration(
        maxAttempts: 2,
        baseDelay: 2.0,
        maxDelay: 10.0,
        exponentialBackoff: true,
        jitter: 0.3
    )

    // Timeout configuration
    static let requestTimeout: TimeInterval = 120
    static let resourceTimeout: TimeInterval = 300
}

// MARK: - OpenRouter Client
class OpenRouterClient: ObservableObject {
    static let shared = OpenRouterClient()

    @Published var isProcessing: Bool = false
    @Published var availableModels: [OpenRouterModel] = []
    @Published var selectedModel: String = OpenRouterConfig.defaultModel
    @Published var error: OpenRouterError?
    @Published var lastAppError: AppError?

    private let session: URLSession
    private var apiKey: String?
    private var cancellables = Set<AnyCancellable>()
    private var retryConfig: RetryConfiguration

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = OpenRouterConfig.requestTimeout
        config.timeoutIntervalForResource = OpenRouterConfig.resourceTimeout
        self.session = URLSession(configuration: config)
        self.retryConfig = OpenRouterConfig.defaultRetryConfig
    }

    /// Configure retry behavior
    func setRetryConfiguration(_ config: RetryConfiguration) {
        self.retryConfig = config
    }

    // MARK: - Debug Logger
    private var logger: DebugLogger {
        DebugLogger.shared
    }

    // MARK: - Configuration
    func configure(apiKey: String) {
        self.apiKey = apiKey
        let maskedKey = String(apiKey.prefix(10)) + "..." + String(apiKey.suffix(4))
        Task { @MainActor in
            logger.log("OpenRouter configured with API key: \(maskedKey)", category: .openRouter)
        }
        Task {
            await fetchAvailableModels()
        }
    }

    // MARK: - Chat Completion

    /// Execute a chat completion with automatic retry support
    /// - Parameters:
    ///   - messages: The conversation messages
    ///   - model: Optional model override
    ///   - temperature: Temperature for response generation
    ///   - maxTokens: Maximum tokens in response
    ///   - systemPrompt: Optional system prompt
    ///   - useRetry: Whether to use automatic retry for transient errors
    /// - Returns: The AI response content
    func chat(
        messages: [ChatCompletionMessage],
        model: String? = nil,
        temperature: Double = 0.7,
        maxTokens: Int = 4096,
        systemPrompt: String? = nil,
        useRetry: Bool = true
    ) async throws -> String {
        if useRetry {
            return try await executeWithRetry {
                try await self.executeChat(
                    messages: messages,
                    model: model,
                    temperature: temperature,
                    maxTokens: maxTokens,
                    systemPrompt: systemPrompt
                )
            }
        } else {
            return try await executeChat(
                messages: messages,
                model: model,
                temperature: temperature,
                maxTokens: maxTokens,
                systemPrompt: systemPrompt
            )
        }
    }

    /// Internal chat execution
    private func executeChat(
        messages: [ChatCompletionMessage],
        model: String?,
        temperature: Double,
        maxTokens: Int,
        systemPrompt: String?
    ) async throws -> String {
        await MainActor.run {
            logger.log("chat() called with \(messages.count) messages", category: .openRouter)
        }

        guard let apiKey = apiKey else {
            await MainActor.run {
                logger.error("API key not configured!", category: .openRouter)
            }
            let appError = AppError.openRouterNotConfigured
            await MainActor.run { self.lastAppError = appError }
            throw appError
        }

        await MainActor.run {
            logger.log("API key present, preparing request...", category: .openRouter)
            isProcessing = true
        }
        defer {
            Task { @MainActor in
                isProcessing = false
            }
        }

        var allMessages = messages

        // Add system prompt if provided
        if let systemPrompt = systemPrompt {
            allMessages.insert(ChatCompletionMessage(role: "system", content: systemPrompt), at: 0)
            await MainActor.run {
                logger.log("Added system prompt (\(systemPrompt.prefix(50))...)", category: .openRouter)
            }
        }

        let modelToUse = model ?? selectedModel
        let request = ChatCompletionRequest(
            model: modelToUse,
            messages: allMessages,
            temperature: temperature,
            maxTokens: maxTokens
        )

        await MainActor.run {
            logger.log("Using model: \(modelToUse)", category: .openRouter)
            logger.log("Request: \(allMessages.count) messages, temp=\(temperature), maxTokens=\(maxTokens)", category: .openRouter)
        }

        var urlRequest = URLRequest(url: URL(string: OpenRouterConfig.chatEndpoint)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue(OpenRouterConfig.siteURL, forHTTPHeaderField: "HTTP-Referer")
        urlRequest.setValue(OpenRouterConfig.siteName, forHTTPHeaderField: "X-Title")

        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
            await MainActor.run {
                logger.log("Request encoded, sending to \(OpenRouterConfig.chatEndpoint)...", category: .openRouter)
            }
        } catch {
            await MainActor.run {
                logger.error("Failed to encode request: \(error.localizedDescription)", category: .openRouter)
            }
            let appError = AppError.invalidInput("Failed to encode chat request")
            await MainActor.run { self.lastAppError = appError }
            throw appError
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: urlRequest)
            await MainActor.run {
                logger.log("Received response, size: \(data.count) bytes", category: .openRouter)
            }
        } catch let urlError as URLError {
            await MainActor.run {
                logger.error("Network error: \(urlError.localizedDescription)", category: .openRouter)
            }
            let appError = AppError.from(urlError)
            await MainActor.run { self.lastAppError = appError }
            throw appError
        } catch {
            await MainActor.run {
                logger.error("Unknown error: \(error.localizedDescription)", category: .openRouter)
            }
            let appError = AppError.unknown(error)
            await MainActor.run { self.lastAppError = appError }
            throw appError
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            await MainActor.run {
                logger.error("Invalid response type", category: .openRouter)
            }
            let appError = AppError.invalidResponse
            await MainActor.run { self.lastAppError = appError }
            throw appError
        }

        await MainActor.run {
            logger.log("HTTP Status: \(httpResponse.statusCode)", category: .openRouter)
        }

        // Handle HTTP status codes with unified errors
        if httpResponse.statusCode != 200 {
            let errorResponse = try? JSONDecoder().decode(OpenRouterErrorResponse.self, from: data)
            let errorMessage = errorResponse?.error?.message ?? String(data: data, encoding: .utf8) ?? "Unknown error"

            await MainActor.run {
                logger.error("API Error (\(httpResponse.statusCode)): \(errorMessage)", category: .openRouter)
            }

            let appError: AppError
            switch httpResponse.statusCode {
            case 401:
                appError = .notAuthenticated
            case 402:
                appError = .openRouterQuotaExceeded
            case 403:
                appError = .notAuthorized
            case 404:
                appError = .openRouterModelUnavailable(model: modelToUse)
            case 429:
                // Try to parse retry-after header
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap { Double($0) }
                appError = .openRouterRateLimited(retryAfter: retryAfter)
            case 500...599:
                appError = .openRouterAPIError(code: httpResponse.statusCode, message: errorMessage)
            default:
                appError = .openRouterAPIError(code: httpResponse.statusCode, message: errorMessage)
            }

            await MainActor.run { self.lastAppError = appError }
            throw appError
        }

        let completionResponse: ChatCompletionResponse
        do {
            completionResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
            await MainActor.run {
                logger.success("Response decoded successfully", category: .openRouter)
            }
        } catch {
            let rawResponse = String(data: data, encoding: .utf8) ?? "Unable to decode"
            await MainActor.run {
                logger.error("Decode error: \(error.localizedDescription)", category: .openRouter)
                logger.error("Raw response: \(rawResponse.prefix(500))", category: .openRouter)
            }
            let appError = AppError.dataCorrupted("Failed to decode AI response: \(error.localizedDescription)")
            await MainActor.run { self.lastAppError = appError }
            throw appError
        }

        guard let content = completionResponse.choices.first?.message.content else {
            await MainActor.run {
                logger.error("No content in response choices", category: .openRouter)
            }
            let appError = AppError.openRouterContentFiltered
            await MainActor.run { self.lastAppError = appError }
            throw appError
        }

        await MainActor.run {
            logger.success("Chat completed: \(content.prefix(100))...", category: .openRouter)
            self.lastAppError = nil
        }

        return content
    }

    /// Execute operation with retry logic
    private func executeWithRetry<T>(operation: () async throws -> T) async throws -> T {
        var lastError: Error?

        for attempt in 1...retryConfig.maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                let appError = AppError.from(error)

                // Log the attempt
                await MainActor.run {
                    logger.warning(
                        "OpenRouter attempt \(attempt)/\(retryConfig.maxAttempts) failed: \(appError.userMessage)",
                        category: .openRouter
                    )
                }

                // Check if error is retryable
                guard appError.isRetryable && attempt < retryConfig.maxAttempts else {
                    break
                }

                // Calculate delay
                let delay = retryConfig.delay(for: attempt)
                await MainActor.run {
                    logger.log("Retrying in \(String(format: "%.1f", delay))s...", category: .openRouter)
                }

                // Wait before retry
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        let finalError = AppError.from(lastError ?? AppError.unknown(NSError(domain: "OpenRouter", code: -1)))
        await MainActor.run {
            self.lastAppError = finalError
        }
        throw finalError
    }

    // MARK: - Streaming Chat
    func streamChat(
        messages: [ChatCompletionMessage],
        model: String? = nil,
        temperature: Double = 0.7,
        maxTokens: Int = 4096,
        systemPrompt: String? = nil,
        onChunk: @escaping (String) -> Void
    ) async throws {
        await MainActor.run {
            logger.log("streamChat() called with \(messages.count) messages", category: .openRouter)
        }

        guard let apiKey = apiKey else {
            await MainActor.run {
                logger.error("streamChat: API key not configured!", category: .openRouter)
            }
            throw OpenRouterError.notConfigured
        }

        await MainActor.run {
            isProcessing = true
        }
        defer {
            Task { @MainActor in
                isProcessing = false
            }
        }

        var allMessages = messages

        if let systemPrompt = systemPrompt {
            allMessages.insert(ChatCompletionMessage(role: "system", content: systemPrompt), at: 0)
            await MainActor.run {
                logger.log("Added system prompt to stream request", category: .openRouter)
            }
        }

        let modelToUse = model ?? selectedModel
        let request = ChatCompletionRequest(
            model: modelToUse,
            messages: allMessages,
            temperature: temperature,
            maxTokens: maxTokens,
            stream: true
        )

        await MainActor.run {
            logger.log("Stream request: model=\(modelToUse), messages=\(allMessages.count)", category: .openRouter)
        }

        var urlRequest = URLRequest(url: URL(string: OpenRouterConfig.chatEndpoint)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue(OpenRouterConfig.siteURL, forHTTPHeaderField: "HTTP-Referer")
        urlRequest.setValue(OpenRouterConfig.siteName, forHTTPHeaderField: "X-Title")

        urlRequest.httpBody = try JSONEncoder().encode(request)

        await MainActor.run {
            logger.log("Sending streaming request to OpenRouter...", category: .openRouter)
        }

        let (bytes, response) = try await session.bytes(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            await MainActor.run {
                logger.error("streamChat: Invalid response type", category: .openRouter)
            }
            throw OpenRouterError.invalidResponse
        }

        await MainActor.run {
            logger.log("Stream HTTP Status: \(httpResponse.statusCode)", category: .openRouter)
        }

        if httpResponse.statusCode != 200 {
            // Try to read error message from stream
            var errorBody = ""
            for try await line in bytes.lines {
                errorBody += line
                if errorBody.count > 500 { break }
            }
            await MainActor.run {
                logger.error("Stream API Error (\(httpResponse.statusCode)): \(errorBody.prefix(300))", category: .openRouter)
            }
            throw OpenRouterError.apiError(code: httpResponse.statusCode, message: errorBody)
        }

        var chunkCount = 0
        for try await line in bytes.lines {
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6))

                if jsonString == "[DONE]" {
                    await MainActor.run {
                        logger.success("Stream completed, received \(chunkCount) chunks", category: .openRouter)
                    }
                    break
                }

                if let data = jsonString.data(using: .utf8),
                   let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data),
                   let content = chunk.choices.first?.delta.content {
                    chunkCount += 1
                    onChunk(content)
                }
            }
        }
    }

    // MARK: - Admin Dashboard Context Chat
    func chatWithContext(
        userMessage: String,
        context: AdminContext,
        conversationHistory: [ChatCompletionMessage] = []
    ) async throws -> String {
        let systemPrompt = buildAdminSystemPrompt(context: context)

        var messages = conversationHistory
        messages.append(ChatCompletionMessage(role: "user", content: userMessage))

        return try await chat(
            messages: messages,
            model: OpenRouterConfig.defaultModel,
            temperature: 0.7,
            maxTokens: 4096,
            systemPrompt: systemPrompt
        )
    }

    private func buildAdminSystemPrompt(context: AdminContext) -> String {
        return """
        You are an intelligent AI assistant for the 365Weapons admin dashboard. You have access to the following real-time business data:

        ## Current Dashboard Statistics:
        - Total Revenue: $\(String(format: "%.2f", context.stats.totalRevenue))
        - Total Orders: \(context.stats.totalOrders)
        - Total Products: \(context.stats.totalProducts)
        - Total Partners/Vendors: \(context.stats.totalPartners)
        - Pending Orders: \(context.stats.pendingOrders)
        - Pending Inquiries: \(context.stats.pendingInquiries)
        - Eligible Commissions: $\(String(format: "%.2f", context.stats.eligibleCommissions))

        ## Recent Orders:
        \(context.recentOrders.prefix(10).map { order in
            "- Order #\(order.orderNumber): \(order.status.displayName) - \(order.formattedTotal) (\(order.customerEmail))"
        }.joined(separator: "\n"))

        ## Products Summary:
        - Categories: \(Set(context.products.map { $0.category }).joined(separator: ", "))
        - In Stock: \(context.products.filter { $0.inStock }.count)
        - Out of Stock: \(context.products.filter { !$0.inStock }.count)

        ## Partners/Vendors:
        \(context.partners.prefix(5).map { partner in
            "- \(partner.storeName) (\(partner.storeCode)): \(partner.active ? "Active" : "Inactive")"
        }.joined(separator: "\n"))

        ## Your Capabilities:
        1. Answer questions about business performance, orders, products, and partners
        2. Provide insights and recommendations based on the data
        3. Help with administrative tasks and decision-making
        4. Explain trends and patterns in the business data
        5. Assist with product management and inventory decisions

        Be helpful, concise, and data-driven in your responses. If you don't have enough information to answer a question, say so clearly.
        """
    }

    // MARK: - Model Management
    @MainActor
    func fetchAvailableModels() async {
        guard let apiKey = apiKey else { return }

        var request = URLRequest(url: URL(string: OpenRouterConfig.modelsEndpoint)!)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await session.data(for: request)
            let response = try JSONDecoder().decode(ModelsResponse.self, from: data)
            availableModels = response.data.sorted { $0.name < $1.name }
        } catch {
            print("Failed to fetch models: \(error)")
        }
    }

    func selectModel(_ modelId: String) {
        selectedModel = modelId
    }
}

// MARK: - Request/Response Types
struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [ChatCompletionMessage]
    let temperature: Double
    let maxTokens: Int
    let stream: Bool

    init(model: String, messages: [ChatCompletionMessage], temperature: Double = 0.7, maxTokens: Int = 4096, stream: Bool = false) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.stream = stream
    }

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, stream
        case maxTokens = "max_tokens"
    }
}

struct ChatCompletionMessage: Codable, Equatable {
    let role: String
    let content: String
}

struct ChatCompletionResponse: Decodable {
    let id: String
    let choices: [ChatChoice]
    let usage: ChatUsage?
}

struct ChatChoice: Decodable {
    let index: Int
    let message: ChatCompletionMessage
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case index, message
        case finishReason = "finish_reason"
    }
}

struct ChatUsage: Decodable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

struct StreamChunk: Decodable {
    let choices: [StreamChoice]
}

struct StreamChoice: Decodable {
    let delta: StreamDelta
}

struct StreamDelta: Decodable {
    let content: String?
}

// MARK: - Models Response
struct ModelsResponse: Decodable {
    let data: [OpenRouterModel]
}

struct OpenRouterModel: Decodable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let contextLength: Int?
    let pricing: ModelPricing?

    var displayName: String {
        name.isEmpty ? id : name
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case contextLength = "context_length"
        case pricing
    }
}

struct ModelPricing: Decodable {
    let prompt: String?
    let completion: String?
}

// MARK: - Admin Context for AI
struct AdminContext {
    let stats: DashboardStats
    let recentOrders: [Order]
    let products: [Product]
    let partners: [PartnerStore]
    let inquiries: [ServiceInquiry]
}

// MARK: - Error Types
struct OpenRouterErrorResponse: Decodable {
    let error: OpenRouterAPIError?
}

struct OpenRouterAPIError: Decodable {
    let message: String
    let type: String?
    let code: String?
}

enum OpenRouterError: Error, LocalizedError {
    case notConfigured
    case invalidResponse
    case noContent
    case apiError(code: Int, message: String)
    case streamingError(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "OpenRouter API key not configured"
        case .invalidResponse:
            return "Invalid response from OpenRouter"
        case .noContent:
            return "No content in response"
        case .apiError(let code, let message):
            return "API Error (\(code)): \(message)"
        case .streamingError(let message):
            return "Streaming error: \(message)"
        }
    }
}

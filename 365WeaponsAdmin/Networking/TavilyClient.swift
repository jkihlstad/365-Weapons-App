//
//  TavilyClient.swift
//  365WeaponsAdmin
//
//  Tavily Search API client for web search capabilities
//

import Foundation

// MARK: - Tavily Search Result
struct TavilySearchResult: Codable, Identifiable {
    let title: String
    let url: String
    let content: String
    let score: Double

    var id: String { url }
}

// MARK: - Tavily Response
struct TavilySearchResponse: Codable {
    let query: String
    let results: [TavilySearchResult]
    let answer: String?
    let responseTime: Double?

    enum CodingKeys: String, CodingKey {
        case query, results, answer
        case responseTime = "response_time"
    }
}

// MARK: - Tavily Request
struct TavilySearchRequest: Codable {
    let apiKey: String
    let query: String
    let searchDepth: String
    let includeAnswer: Bool
    let includeRawContent: Bool
    let maxResults: Int
    let includeDomains: [String]?
    let excludeDomains: [String]?

    enum CodingKeys: String, CodingKey {
        case apiKey = "api_key"
        case query
        case searchDepth = "search_depth"
        case includeAnswer = "include_answer"
        case includeRawContent = "include_raw_content"
        case maxResults = "max_results"
        case includeDomains = "include_domains"
        case excludeDomains = "exclude_domains"
    }

    init(
        apiKey: String,
        query: String,
        searchDepth: String = "basic",
        includeAnswer: Bool = true,
        includeRawContent: Bool = false,
        maxResults: Int = 5,
        includeDomains: [String]? = nil,
        excludeDomains: [String]? = nil
    ) {
        self.apiKey = apiKey
        self.query = query
        self.searchDepth = searchDepth
        self.includeAnswer = includeAnswer
        self.includeRawContent = includeRawContent
        self.maxResults = maxResults
        self.includeDomains = includeDomains
        self.excludeDomains = excludeDomains
    }
}

// MARK: - Tavily Error
enum TavilyError: Error, LocalizedError {
    case invalidAPIKey
    case networkError(String)
    case decodingError(String)
    case rateLimited
    case searchFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid or missing Tavily API key"
        case .networkError(let message):
            return "Network error: \(message)"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .rateLimited:
            return "Tavily API rate limit exceeded"
        case .searchFailed(let message):
            return "Search failed: \(message)"
        }
    }
}

// MARK: - Tavily Client
class TavilyClient {
    static let shared = TavilyClient()

    private let baseURL = "https://api.tavily.com"
    private let session: URLSession

    private var logger: DebugLogger {
        DebugLogger.shared
    }

    @MainActor
    private func getAPIKey() -> String? {
        ConfigurationManager.shared.getAPIKey(for: .tavily)
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Search Methods

    /// Perform a web search using Tavily API
    /// - Parameters:
    ///   - query: The search query
    ///   - maxResults: Maximum number of results to return (default: 5)
    ///   - searchDepth: Search depth - "basic" or "advanced" (default: "basic")
    /// - Returns: Array of search results
    func search(
        query: String,
        maxResults: Int = 5,
        searchDepth: String = "basic"
    ) async throws -> [TavilySearchResult] {
        let apiKey = await getAPIKey()
        guard let apiKey = apiKey else {
            throw TavilyError.invalidAPIKey
        }

        await MainActor.run {
            logger.log("Tavily search: '\(query)' (max: \(maxResults))", category: .network)
        }

        let request = TavilySearchRequest(
            apiKey: apiKey,
            query: query,
            searchDepth: searchDepth,
            includeAnswer: false,
            maxResults: maxResults
        )

        let response = try await performSearch(request: request)
        await MainActor.run {
            logger.success("Tavily returned \(response.results.count) results", category: .network)
        }

        return response.results
    }

    /// Perform a web search and get a summarized answer
    /// - Parameters:
    ///   - query: The search query
    ///   - maxResults: Maximum number of results for context (default: 5)
    /// - Returns: Summarized answer from search results
    func searchAndSummarize(query: String, maxResults: Int = 5) async throws -> String {
        let apiKey = await getAPIKey()
        guard let apiKey = apiKey else {
            throw TavilyError.invalidAPIKey
        }

        await MainActor.run {
            logger.log("Tavily search with answer: '\(query)'", category: .network)
        }

        let request = TavilySearchRequest(
            apiKey: apiKey,
            query: query,
            searchDepth: "advanced",
            includeAnswer: true,
            maxResults: maxResults
        )

        let response = try await performSearch(request: request)

        if let answer = response.answer, !answer.isEmpty {
            await MainActor.run {
                logger.success("Tavily returned answer: '\(answer.prefix(100))...'", category: .network)
            }
            return answer
        }

        // If no direct answer, concatenate top results
        let summary = response.results.prefix(3).map { result in
            "\(result.title): \(result.content)"
        }.joined(separator: "\n\n")

        return summary.isEmpty ? "No relevant results found." : summary
    }

    /// Search with specific domain filtering
    /// - Parameters:
    ///   - query: The search query
    ///   - includeDomains: Only search these domains
    ///   - excludeDomains: Exclude these domains from search
    ///   - maxResults: Maximum number of results
    /// - Returns: Array of search results
    func searchWithDomains(
        query: String,
        includeDomains: [String]? = nil,
        excludeDomains: [String]? = nil,
        maxResults: Int = 5
    ) async throws -> [TavilySearchResult] {
        let apiKey = await getAPIKey()
        guard let apiKey = apiKey else {
            throw TavilyError.invalidAPIKey
        }

        await MainActor.run {
            logger.log("Tavily domain search: '\(query)'", category: .network)
        }

        let request = TavilySearchRequest(
            apiKey: apiKey,
            query: query,
            searchDepth: "basic",
            includeAnswer: false,
            maxResults: maxResults,
            includeDomains: includeDomains,
            excludeDomains: excludeDomains
        )

        let response = try await performSearch(request: request)
        return response.results
    }

    /// Format search results for AI context
    /// - Parameter results: Array of search results
    /// - Returns: Formatted string for LLM context
    func formatResultsForContext(_ results: [TavilySearchResult]) -> String {
        guard !results.isEmpty else {
            return "No web search results available."
        }

        var context = "Web Search Results:\n\n"

        for (index, result) in results.enumerated() {
            context += "[\(index + 1)] \(result.title)\n"
            context += "Source: \(result.url)\n"
            context += "\(result.content)\n\n"
        }

        return context
    }

    // MARK: - Private Methods

    private func performSearch(request: TavilySearchRequest) async throws -> TavilySearchResponse {
        let url = URL(string: "\(baseURL)/search")!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TavilyError.networkError("Invalid response type")
        }

        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            do {
                return try decoder.decode(TavilySearchResponse.self, from: data)
            } catch {
                await MainActor.run {
                    logger.error("Tavily decode error: \(error)", category: .network)
                }
                throw TavilyError.decodingError(error.localizedDescription)
            }

        case 401:
            throw TavilyError.invalidAPIKey

        case 429:
            throw TavilyError.rateLimited

        default:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TavilyError.searchFailed("Status \(httpResponse.statusCode): \(errorMessage)")
        }
    }
}

// MARK: - Web Search Detection
extension TavilyClient {
    /// Determines if a query would benefit from web search
    /// - Parameter query: The user's query
    /// - Returns: True if web search would be helpful
    func shouldSearchWeb(for query: String) -> Bool {
        let searchIndicators = [
            // Current events
            "latest", "recent", "current", "today", "news", "update",
            // Specific information
            "what is the price", "how much does", "where can i",
            // Research queries
            "research", "find out", "look up", "search for",
            // Comparisons
            "compare", "vs", "versus", "difference between",
            // Factual queries
            "who is", "when did", "where is", "how many",
            // Product/service info
            "reviews", "best", "top rated", "recommendation"
        ]

        let lowercaseQuery = query.lowercased()

        // Check for search indicators
        for indicator in searchIndicators {
            if lowercaseQuery.contains(indicator) {
                return true
            }
        }

        // Check for question patterns
        let questionPatterns = ["what", "who", "when", "where", "why", "how"]
        for pattern in questionPatterns {
            if lowercaseQuery.hasPrefix(pattern) {
                return true
            }
        }

        return false
    }
}

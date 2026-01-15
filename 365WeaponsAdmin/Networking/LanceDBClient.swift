//
//  LanceDBClient.swift
//  365WeaponsAdmin
//
//  LanceDB Client for vector search and RAG capabilities
//

import Foundation
import Combine

// MARK: - LanceDB Configuration
struct LanceDBConfig {
    // LanceDB server endpoint (using LanceDB Cloud or self-hosted)
    static var serverEndpoint: String = "https://api.365weapons.com/lancedb"

    // Embedding model configuration
    static let embeddingModel = "text-embedding-3-small"
    static let embeddingDimension = 1536

    // Table names
    static let productsTable = "products_embeddings"
    static let ordersTable = "orders_embeddings"
    static let documentsTable = "documents_embeddings"
    static let chatHistoryTable = "chat_history_embeddings"
}

// MARK: - LanceDB Client
class LanceDBClient: ObservableObject {
    static let shared = LanceDBClient()

    @Published var isConnected: Bool = false
    @Published var isIndexing: Bool = false
    @Published var lastSyncTime: Date?
    @Published var error: LanceDBError?

    private let session: URLSession
    private var authToken: String?
    private var openAIKey: String?

    private var cancellables = Set<AnyCancellable>()

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Configuration
    func configure(serverEndpoint: String, authToken: String, openAIKey: String) {
        LanceDBConfig.serverEndpoint = serverEndpoint
        self.authToken = authToken
        self.openAIKey = openAIKey
        self.isConnected = true
    }

    // MARK: - Embedding Generation
    private func generateEmbedding(text: String) async throws -> [Float] {
        guard let openAIKey = openAIKey else {
            throw LanceDBError.notConfigured
        }

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/embeddings")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = EmbeddingRequest(
            model: LanceDBConfig.embeddingModel,
            input: text
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw LanceDBError.embeddingFailed("Failed to generate embedding")
        }

        let embeddingResponse = try JSONDecoder().decode(EmbeddingResponse.self, from: data)

        guard let embedding = embeddingResponse.data.first?.embedding else {
            throw LanceDBError.embeddingFailed("No embedding returned")
        }

        return embedding
    }

    // MARK: - Vector Operations

    /// Add a document to the vector store
    func addDocument(
        table: String,
        id: String,
        text: String,
        metadata: [String: String] = [:]
    ) async throws {
        let embedding = try await generateEmbedding(text: text)

        let document = VectorDocument(
            id: id,
            text: text,
            vector: embedding,
            metadata: metadata
        )

        try await insertDocument(table: table, document: document)
    }

    /// Add multiple documents
    func addDocuments(
        table: String,
        documents: [(id: String, text: String, metadata: [String: String])]
    ) async throws {
        isIndexing = true
        defer { isIndexing = false }

        for doc in documents {
            try await addDocument(
                table: table,
                id: doc.id,
                text: doc.text,
                metadata: doc.metadata
            )
        }

        lastSyncTime = Date()
    }

    /// Search for similar documents
    func search(
        table: String,
        query: String,
        limit: Int = 10,
        filter: [String: String]? = nil
    ) async throws -> [SearchResult] {
        let queryEmbedding = try await generateEmbedding(text: query)

        return try await vectorSearch(
            table: table,
            vector: queryEmbedding,
            limit: limit,
            filter: filter
        )
    }

    /// Hybrid search (vector + keyword)
    func hybridSearch(
        table: String,
        query: String,
        limit: Int = 10,
        vectorWeight: Float = 0.7,
        keywordWeight: Float = 0.3
    ) async throws -> [SearchResult] {
        guard let authToken = authToken else {
            throw LanceDBError.notConfigured
        }

        let queryEmbedding = try await generateEmbedding(text: query)

        var request = URLRequest(url: URL(string: "\(LanceDBConfig.serverEndpoint)/hybrid-search")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let body = HybridSearchRequest(
            table: table,
            query: query,
            vector: queryEmbedding,
            limit: limit,
            vectorWeight: vectorWeight,
            keywordWeight: keywordWeight
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LanceDBError.searchFailed(errorMessage)
        }

        let searchResponse = try JSONDecoder().decode(SearchResponse.self, from: data)
        return searchResponse.results
    }

    // MARK: - Private API Methods

    private func insertDocument(table: String, document: VectorDocument) async throws {
        guard let authToken = authToken else {
            throw LanceDBError.notConfigured
        }

        var request = URLRequest(url: URL(string: "\(LanceDBConfig.serverEndpoint)/insert")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let body = InsertRequest(table: table, document: document)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LanceDBError.insertFailed(errorMessage)
        }
    }

    private func vectorSearch(
        table: String,
        vector: [Float],
        limit: Int,
        filter: [String: String]?
    ) async throws -> [SearchResult] {
        guard let authToken = authToken else {
            throw LanceDBError.notConfigured
        }

        var request = URLRequest(url: URL(string: "\(LanceDBConfig.serverEndpoint)/search")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let body = VectorSearchRequest(
            table: table,
            vector: vector,
            limit: limit,
            filter: filter
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LanceDBError.searchFailed(errorMessage)
        }

        let searchResponse = try JSONDecoder().decode(SearchResponse.self, from: data)
        return searchResponse.results
    }

    // MARK: - RAG (Retrieval Augmented Generation)

    /// Get relevant context for a query
    func getRAGContext(query: String, tables: [String] = [LanceDBConfig.documentsTable], limit: Int = 5) async throws -> String {
        var allResults: [SearchResult] = []

        for table in tables {
            let results = try await search(table: table, query: query, limit: limit)
            allResults.append(contentsOf: results)
        }

        // Sort by score and take top results
        let topResults = allResults
            .sorted { $0.score > $1.score }
            .prefix(limit)

        // Build context string
        let context = topResults.map { result in
            """
            [Source: \(result.metadata["source"] ?? "unknown")]
            \(result.text)
            """
        }.joined(separator: "\n\n---\n\n")

        return context
    }

    /// Perform RAG-enhanced query
    func ragQuery(
        query: String,
        openRouterClient: OpenRouterClient,
        conversationHistory: [ChatCompletionMessage] = []
    ) async throws -> String {
        // Get relevant context
        let context = try await getRAGContext(query: query)

        // Build RAG prompt
        let ragSystemPrompt = """
        You are an intelligent assistant for the 365Weapons admin dashboard. Use the following context to answer questions accurately.

        ## Retrieved Context:
        \(context)

        ## Instructions:
        1. Use the context above to answer questions when relevant
        2. If the context doesn't contain relevant information, say so
        3. Be concise and accurate in your responses
        4. Cite sources when using information from the context
        """

        var messages = conversationHistory
        messages.append(ChatCompletionMessage(role: "user", content: query))

        return try await openRouterClient.chat(
            messages: messages,
            systemPrompt: ragSystemPrompt
        )
    }

    // MARK: - Index Management

    /// Create a table/index
    func createTable(name: String) async throws {
        guard let authToken = authToken else {
            throw LanceDBError.notConfigured
        }

        var request = URLRequest(url: URL(string: "\(LanceDBConfig.serverEndpoint)/tables")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let body = CreateTableRequest(
            name: name,
            dimension: LanceDBConfig.embeddingDimension
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LanceDBError.tableCreationFailed(errorMessage)
        }
    }

    /// Delete a document from the vector store
    func deleteDocument(table: String, id: String) async throws {
        guard let authToken = authToken else {
            throw LanceDBError.notConfigured
        }

        var request = URLRequest(url: URL(string: "\(LanceDBConfig.serverEndpoint)/delete")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let body = DeleteRequest(table: table, id: id)
        request.httpBody = try JSONEncoder().encode(body)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw LanceDBError.deleteFailed("Failed to delete document")
        }
    }

    // MARK: - Product Indexing for Search

    /// Index products for semantic search
    func indexProducts(_ products: [Product]) async throws {
        isIndexing = true
        defer { isIndexing = false }

        for product in products {
            let text = """
            Product: \(product.title)
            Category: \(product.category)
            Description: \(product.description ?? "")
            Price: \(product.formattedPrice)
            In Stock: \(product.inStock ? "Yes" : "No")
            """

            try await addDocument(
                table: LanceDBConfig.productsTable,
                id: product.id,
                text: text,
                metadata: [
                    "source": "product",
                    "category": product.category,
                    "title": product.title,
                    "inStock": product.inStock ? "true" : "false"
                ]
            )
        }

        lastSyncTime = Date()
    }

    /// Search products semantically
    func searchProducts(query: String, limit: Int = 10) async throws -> [SearchResult] {
        return try await search(
            table: LanceDBConfig.productsTable,
            query: query,
            limit: limit
        )
    }
}

// MARK: - Request/Response Types

struct EmbeddingRequest: Encodable {
    let model: String
    let input: String
}

struct EmbeddingResponse: Decodable {
    let data: [EmbeddingData]
}

struct EmbeddingData: Decodable {
    let embedding: [Float]
}

struct VectorDocument: Codable {
    let id: String
    let text: String
    let vector: [Float]
    let metadata: [String: String]
}

struct InsertRequest: Encodable {
    let table: String
    let document: VectorDocument
}

struct VectorSearchRequest: Encodable {
    let table: String
    let vector: [Float]
    let limit: Int
    let filter: [String: String]?
}

struct HybridSearchRequest: Encodable {
    let table: String
    let query: String
    let vector: [Float]
    let limit: Int
    let vectorWeight: Float
    let keywordWeight: Float

    enum CodingKeys: String, CodingKey {
        case table, query, vector, limit
        case vectorWeight = "vector_weight"
        case keywordWeight = "keyword_weight"
    }
}

struct SearchResponse: Decodable {
    let results: [SearchResult]
}

struct SearchResult: Decodable, Identifiable {
    let id: String
    let text: String
    let score: Float
    let metadata: [String: String]
}

struct CreateTableRequest: Encodable {
    let name: String
    let dimension: Int
}

struct DeleteRequest: Encodable {
    let table: String
    let id: String
}

// MARK: - Error Types
enum LanceDBError: Error, LocalizedError {
    case notConfigured
    case embeddingFailed(String)
    case insertFailed(String)
    case searchFailed(String)
    case deleteFailed(String)
    case tableCreationFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "LanceDB not configured"
        case .embeddingFailed(let message):
            return "Embedding generation failed: \(message)"
        case .insertFailed(let message):
            return "Insert failed: \(message)"
        case .searchFailed(let message):
            return "Search failed: \(message)"
        case .deleteFailed(let message):
            return "Delete failed: \(message)"
        case .tableCreationFailed(let message):
            return "Table creation failed: \(message)"
        }
    }
}

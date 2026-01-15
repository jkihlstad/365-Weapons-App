//
//  ProductsAgent.swift
//  365WeaponsAdmin
//
//  Products Agent for product management, inventory, and catalog operations
//

import Foundation
import Combine

// MARK: - Products Agent
class ProductsAgent: Agent, ObservableObject {
    let name = "products"
    let description = "Handles product management, inventory, catalog queries, and product creation/updates"

    @Published var isProcessing: Bool = false
    @Published var cachedProducts: [Product] = []
    @Published var lastRefresh: Date?

    private let openRouter = OpenRouterClient.shared
    private let convex = ConvexClient.shared
    private let lanceDB = LanceDBClient.shared

    // MARK: - Agent Protocol

    func canHandle(input: AgentInput) -> Bool {
        let keywords = [
            "product", "inventory", "stock", "catalog", "item", "price",
            "category", "create product", "add product", "update product",
            "delete product", "out of stock", "in stock", "listing"
        ]

        let message = input.message.lowercased()
        return keywords.contains { message.contains($0) }
    }

    func process(input: AgentInput) async throws -> AgentOutput {
        isProcessing = true
        defer { isProcessing = false }

        // Gather product data
        let products = try await convex.fetchProducts()
        cachedProducts = products
        lastRefresh = Date()

        // Determine the specific action
        let action = try await determineAction(input: input, products: products)

        // Execute action
        let response = try await executeAction(action: action, input: input, products: products)

        return response
    }

    // MARK: - Action Types

    enum ProductAction {
        case list(category: String?)
        case search(query: String)
        case getDetails(productId: String)
        case create(product: CreateProductRequest)
        case update(productId: String, updates: [String: Any])
        case delete(productId: String)
        case stockCheck
        case priceAnalysis
        case categoryAnalysis
        case recommendations
        case general(query: String)
    }

    private func determineAction(input: AgentInput, products: [Product]) async throws -> ProductAction {
        let message = input.message.lowercased()

        // Check for explicit actions
        if message.contains("create") || message.contains("add new") {
            return .create(product: try await extractProductDetails(from: input.message))
        }

        if message.contains("update") || message.contains("change") || message.contains("modify") {
            if let productId = extractProductId(from: input.message, products: products) {
                let updates = try await extractUpdates(from: input.message)
                return .update(productId: productId, updates: updates)
            }
        }

        if message.contains("delete") || message.contains("remove") {
            if let productId = extractProductId(from: input.message, products: products) {
                return .delete(productId: productId)
            }
        }

        if message.contains("out of stock") || message.contains("low stock") || message.contains("inventory") {
            return .stockCheck
        }

        if message.contains("price") && (message.contains("analysis") || message.contains("compare")) {
            return .priceAnalysis
        }

        if message.contains("category") || message.contains("categories") {
            return .categoryAnalysis
        }

        if message.contains("recommend") || message.contains("suggest") {
            return .recommendations
        }

        if message.contains("search") || message.contains("find") {
            let query = extractSearchQuery(from: input.message)
            return .search(query: query)
        }

        if message.contains("list") || message.contains("show") || message.contains("all") {
            let category = extractCategory(from: input.message, products: products)
            return .list(category: category)
        }

        // Default to general query
        return .general(query: input.message)
    }

    // MARK: - Action Execution

    private func executeAction(action: ProductAction, input: AgentInput, products: [Product]) async throws -> AgentOutput {
        var response: String = ""
        var toolsUsed: [String] = []
        var suggestedActions: [SuggestedAction] = []
        var data: [String: Any]? = nil

        switch action {
        case .list(let category):
            let filteredProducts = category != nil
                ? products.filter { $0.category.lowercased() == category!.lowercased() }
                : products

            response = formatProductList(filteredProducts)
            toolsUsed = ["convex_query"]
            suggestedActions = [
                SuggestedAction(title: "Add Product", action: "create_product", icon: "plus.circle"),
                SuggestedAction(title: "Export List", action: "export_products", icon: "square.and.arrow.up")
            ]
            data = ["products": filteredProducts.map { $0.title }, "count": filteredProducts.count]

        case .search(let query):
            // Use semantic search with LanceDB
            let searchResults = try? await lanceDB.searchProducts(query: query)
            let matchingProducts = searchResults?.compactMap { result in
                products.first { $0.id == result.id }
            } ?? products.filter { $0.title.lowercased().contains(query.lowercased()) }

            response = "Found \(matchingProducts.count) products matching '\(query)':\n\n"
            response += formatProductList(matchingProducts)
            toolsUsed = ["lancedb_search", "convex_query"]

        case .getDetails(let productId):
            if let product = products.first(where: { $0.id == productId }) {
                response = formatProductDetails(product)
                data = ["product": productId]
            } else {
                response = "Product not found with ID: \(productId)"
            }
            toolsUsed = ["convex_query"]

        case .create(let productRequest):
            let newProductId = try await convex.createProduct(productRequest)
            response = "Successfully created product '\(productRequest.title)' with ID: \(newProductId)"
            toolsUsed = ["convex_mutation"]
            suggestedActions = [
                SuggestedAction(title: "View Product", action: "view_product_\(newProductId)", icon: "eye"),
                SuggestedAction(title: "Add Another", action: "create_product", icon: "plus.circle")
            ]
            data = ["newProductId": newProductId]

        case .update(let productId, let updates):
            let success = try await convex.updateProduct(id: productId, updates: updates)
            response = success
                ? "Successfully updated product \(productId)"
                : "Failed to update product \(productId)"
            toolsUsed = ["convex_mutation"]

        case .delete(let productId):
            // Note: Implementation would call delete mutation
            response = "Product deletion requires confirmation. Product ID: \(productId)"
            suggestedActions = [
                SuggestedAction(title: "Confirm Delete", action: "confirm_delete_\(productId)", icon: "trash"),
                SuggestedAction(title: "Cancel", action: "cancel", icon: "xmark.circle")
            ]

        case .stockCheck:
            let outOfStock = products.filter { !$0.inStock }
            let inStock = products.filter { $0.inStock }

            response = """
            ## Inventory Status

            **In Stock:** \(inStock.count) products
            **Out of Stock:** \(outOfStock.count) products

            """

            if !outOfStock.isEmpty {
                response += "### Out of Stock Items:\n"
                response += outOfStock.prefix(10).map { "- \($0.title) (\($0.category))" }.joined(separator: "\n")
            }

            toolsUsed = ["convex_query"]
            suggestedActions = [
                SuggestedAction(title: "Update Stock", action: "batch_stock_update", icon: "arrow.clockwise"),
                SuggestedAction(title: "Export Report", action: "export_inventory", icon: "square.and.arrow.up")
            ]
            data = ["inStock": inStock.count, "outOfStock": outOfStock.count]

        case .priceAnalysis:
            let analysis = analyzePrices(products: products)
            response = formatPriceAnalysis(analysis)
            toolsUsed = ["price_analysis"]
            data = analysis

        case .categoryAnalysis:
            let categories = analyzeCategories(products: products)
            response = formatCategoryAnalysis(categories)
            toolsUsed = ["category_analysis"]

        case .recommendations:
            response = try await generateRecommendations(products: products)
            toolsUsed = ["openrouter_chat", "analytics"]

        case .general(let query):
            response = try await handleGeneralQuery(query: query, products: products)
            toolsUsed = ["openrouter_chat"]
        }

        return AgentOutput(
            response: response,
            agentName: name,
            toolsUsed: toolsUsed,
            data: data,
            suggestedActions: suggestedActions,
            confidence: 0.85
        )
    }

    // MARK: - Helper Functions

    private func formatProductList(_ products: [Product]) -> String {
        if products.isEmpty {
            return "No products found."
        }

        var result = "### Products (\(products.count) total)\n\n"

        // Group by category
        let grouped = Dictionary(grouping: products) { $0.category }

        for (category, categoryProducts) in grouped.sorted(by: { $0.key < $1.key }) {
            result += "**\(category)** (\(categoryProducts.count))\n"
            for product in categoryProducts.prefix(5) {
                let stockStatus = product.inStock ? "In Stock" : "Out of Stock"
                result += "  - \(product.title): \(product.formattedPrice) [\(stockStatus)]\n"
            }
            if categoryProducts.count > 5 {
                result += "  - ... and \(categoryProducts.count - 5) more\n"
            }
            result += "\n"
        }

        return result
    }

    private func formatProductDetails(_ product: Product) -> String {
        return """
        ## \(product.title)

        **Category:** \(product.category)
        **Price:** \(product.formattedPrice)
        **Status:** \(product.inStock ? "In Stock" : "Out of Stock")
        **Has Options:** \(product.hasOptions ?? false ? "Yes" : "No")

        **Description:**
        \(product.description ?? "No description available")

        **Created:** \(formatDate(product.createdAt))
        """
    }

    private func analyzePrices(products: [Product]) -> [String: Any] {
        let prices = products.map { $0.price }
        let average = prices.reduce(0, +) / Double(prices.count)
        let sorted = prices.sorted()
        let median = sorted[sorted.count / 2]
        let min = sorted.first ?? 0
        let max = sorted.last ?? 0

        // Price distribution by category
        var byCategory: [String: [String: Double]] = [:]
        let grouped = Dictionary(grouping: products) { $0.category }
        for (category, categoryProducts) in grouped {
            let categoryPrices = categoryProducts.map { $0.price }
            byCategory[category] = [
                "average": categoryPrices.reduce(0, +) / Double(categoryPrices.count),
                "min": categoryPrices.min() ?? 0,
                "max": categoryPrices.max() ?? 0,
                "count": Double(categoryProducts.count)
            ]
        }

        return [
            "average": average,
            "median": median,
            "min": min,
            "max": max,
            "byCategory": byCategory
        ]
    }

    private func formatPriceAnalysis(_ analysis: [String: Any]) -> String {
        var result = "## Price Analysis\n\n"

        if let average = analysis["average"] as? Double,
           let median = analysis["median"] as? Double,
           let min = analysis["min"] as? Double,
           let max = analysis["max"] as? Double {
            result += """
            **Overall Statistics:**
            - Average: $\(String(format: "%.2f", average))
            - Median: $\(String(format: "%.2f", median))
            - Range: $\(String(format: "%.2f", min)) - $\(String(format: "%.2f", max))

            """
        }

        if let byCategory = analysis["byCategory"] as? [String: [String: Double]] {
            result += "**By Category:**\n"
            for (category, stats) in byCategory.sorted(by: { $0.key < $1.key }) {
                let avg = stats["average"] ?? 0
                let count = Int(stats["count"] ?? 0)
                result += "- \(category): $\(String(format: "%.2f", avg)) avg (\(count) products)\n"
            }
        }

        return result
    }

    private func analyzeCategories(products: [Product]) -> [(String, Int, Int, Int)] {
        let grouped = Dictionary(grouping: products) { $0.category }
        return grouped.map { (category, items) in
            let inStock = items.filter { $0.inStock }.count
            let outOfStock = items.count - inStock
            return (category, items.count, inStock, outOfStock)
        }.sorted { $0.1 > $1.1 }
    }

    private func formatCategoryAnalysis(_ categories: [(String, Int, Int, Int)]) -> String {
        var result = "## Category Analysis\n\n"

        for (category, total, inStock, outOfStock) in categories {
            result += "**\(category)**\n"
            result += "  - Total: \(total) products\n"
            result += "  - In Stock: \(inStock)\n"
            result += "  - Out of Stock: \(outOfStock)\n\n"
        }

        return result
    }

    private func generateRecommendations(products: [Product]) async throws -> String {
        let outOfStockCount = products.filter { !$0.inStock }.count
        let categories = Set(products.map { $0.category })
        let avgPrice = products.map { $0.price }.reduce(0, +) / Double(products.count)

        let prompt = """
        Based on this product catalog data, provide 3-5 actionable recommendations:

        - Total products: \(products.count)
        - Categories: \(categories.joined(separator: ", "))
        - Out of stock: \(outOfStockCount)
        - Average price: $\(String(format: "%.2f", avgPrice))

        Consider:
        1. Inventory management
        2. Pricing strategy
        3. Category expansion
        4. Product optimization
        """

        return try await openRouter.chat(
            messages: [ChatCompletionMessage(role: "user", content: prompt)],
            model: OpenRouterConfig.defaultModel,
            temperature: 0.7
        )
    }

    private func handleGeneralQuery(query: String, products: [Product]) async throws -> String {
        let context = """
        Product catalog data:
        - Total products: \(products.count)
        - Categories: \(Set(products.map { $0.category }).joined(separator: ", "))
        - In stock: \(products.filter { $0.inStock }.count)
        - Out of stock: \(products.filter { !$0.inStock }.count)
        - Price range: $\(String(format: "%.2f", products.map { $0.price }.min() ?? 0)) - $\(String(format: "%.2f", products.map { $0.price }.max() ?? 0))
        """

        return try await openRouter.chat(
            messages: [ChatCompletionMessage(role: "user", content: query)],
            temperature: 0.6,
            systemPrompt: "You are a product management assistant. \(context)"
        )
    }

    // MARK: - Extraction Helpers

    private func extractProductDetails(from message: String) async throws -> CreateProductRequest {
        let extractionPrompt = """
        Extract product details from this message to create a new product.
        Return as JSON with these fields: title, description, price, category, inStock

        Message: \(message)

        If any field is missing, use reasonable defaults:
        - price: 0
        - category: "Uncategorized"
        - inStock: true
        - description: ""

        Return ONLY valid JSON.
        """

        let response = try await openRouter.chat(
            messages: [ChatCompletionMessage(role: "user", content: extractionPrompt)],
            model: OpenRouterConfig.fastModel,
            temperature: 0.1
        )

        // Parse the JSON response
        if let data = response.data(using: .utf8) {
            struct ExtractedProduct: Decodable {
                let title: String
                let description: String?
                let price: Double
                let category: String
                let inStock: Bool?
            }

            let extracted = try JSONDecoder().decode(ExtractedProduct.self, from: data)

            return CreateProductRequest(
                title: extracted.title,
                description: extracted.description,
                price: extracted.price,
                priceRange: nil,
                category: extracted.category,
                image: "/images/products/default.jpg",
                inStock: extracted.inStock ?? true,
                hasOptions: false
            )
        }

        throw ProductAgentError.extractionFailed("Could not extract product details")
    }

    private func extractProductId(from message: String, products: [Product]) -> String? {
        // Try to match product by name
        for product in products {
            if message.lowercased().contains(product.title.lowercased()) {
                return product.id
            }
        }
        return nil
    }

    private func extractUpdates(from message: String) async throws -> [String: Any] {
        let extractionPrompt = """
        Extract the fields to update from this message.
        Return as JSON with only the fields to change.
        Possible fields: title, description, price, category, inStock

        Message: \(message)

        Return ONLY valid JSON or empty object {}.
        """

        let response = try await openRouter.chat(
            messages: [ChatCompletionMessage(role: "user", content: extractionPrompt)],
            model: OpenRouterConfig.fastModel,
            temperature: 0.1
        )

        if let data = response.data(using: .utf8),
           let updates = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return updates
        }

        return [:]
    }

    private func extractSearchQuery(from message: String) -> String {
        let patterns = ["search for ", "find ", "looking for ", "search "]
        var query = message.lowercased()

        for pattern in patterns {
            if let range = query.range(of: pattern) {
                query = String(query[range.upperBound...])
                break
            }
        }

        return query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractCategory(from message: String, products: [Product]) -> String? {
        let categories = Set(products.map { $0.category.lowercased() })
        let message = message.lowercased()

        for category in categories {
            if message.contains(category) {
                return category
            }
        }

        return nil
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Direct Product Operations

    /// Create a new product
    func createProduct(_ request: CreateProductRequest) async throws -> String {
        return try await convex.createProduct(request)
    }

    /// Update product stock status
    func updateStock(productId: String, inStock: Bool) async throws -> Bool {
        return try await convex.updateProduct(id: productId, updates: ["inStock": inStock])
    }

    /// Update product price
    func updatePrice(productId: String, price: Double) async throws -> Bool {
        return try await convex.updateProduct(id: productId, updates: ["price": price])
    }

    /// Get products by category
    func getByCategory(_ category: String) async throws -> [Product] {
        let products = try await convex.fetchProducts(category: category)
        cachedProducts = products
        return products
    }

    /// Search products semantically
    func searchProducts(query: String) async throws -> [Product] {
        let results = try await lanceDB.searchProducts(query: query)
        let products = try await convex.fetchProducts()

        return results.compactMap { result in
            products.first { $0.id == result.id }
        }
    }
}

// MARK: - Error Types
enum ProductAgentError: Error, LocalizedError {
    case extractionFailed(String)
    case productNotFound(String)
    case updateFailed(String)

    var errorDescription: String? {
        switch self {
        case .extractionFailed(let message):
            return "Extraction failed: \(message)"
        case .productNotFound(let id):
            return "Product not found: \(id)"
        case .updateFailed(let message):
            return "Update failed: \(message)"
        }
    }
}

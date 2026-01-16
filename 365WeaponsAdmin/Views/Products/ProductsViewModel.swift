//
//  ProductsViewModel.swift
//  365WeaponsAdmin
//
//  ViewModel for Products data management following MVVM pattern with offline support
//

import Foundation
import Combine

// MARK: - Display Mode
enum ProductDisplayMode: String, CaseIterable {
    case grid
    case list

    var icon: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet"
        }
    }

    var toggledMode: ProductDisplayMode {
        self == .grid ? .list : .grid
    }
}

// MARK: - Products ViewModel
@MainActor
class ProductsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var products: [Product] = []
    @Published var categories: [String] = []
    @Published var isLoading: Bool = false
    @Published var isCreating: Bool = false
    @Published var isUpdating: Bool = false
    @Published var error: ProductsError?
    @Published var searchText: String = ""
    @Published var selectedCategory: String?
    @Published var displayMode: ProductDisplayMode = .grid
    @Published var selectedProduct: Product?

    // MARK: - Cache Properties
    @Published var lastRefreshTime: Date?
    private var cacheExpirationInterval: TimeInterval = 300 // 5 minutes
    private var cachedProducts: [Product] = []
    private var isCacheValid: Bool {
        guard let lastRefresh = lastRefreshTime else { return false }
        return Date().timeIntervalSince(lastRefresh) < cacheExpirationInterval
    }

    // MARK: - Offline Support
    @Published var isOffline: Bool = false
    @Published var isUsingCachedData: Bool = false
    @Published var lastCacheUpdate: Date?
    @Published var pendingCreates: Int = 0
    @Published var pendingUpdates: Int = 0

    // MARK: - Semantic Search Properties
    @Published var isSemanticSearchEnabled: Bool = false
    @Published var semanticSearchResults: [SearchResult] = []

    // MARK: - Computed Properties
    var filteredProducts: [Product] {
        var result = products

        // Filter by category
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        // Filter by search text (local filtering)
        if !searchText.isEmpty && !isSemanticSearchEnabled {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText) ||
                ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return result
    }

    var productCountByCategory: [String: Int] {
        Dictionary(grouping: products, by: { $0.category })
            .mapValues { $0.count }
    }

    var inStockCount: Int {
        products.filter { $0.inStock }.count
    }

    var outOfStockCount: Int {
        products.filter { !$0.inStock }.count
    }

    var totalProductsValue: Double {
        products.reduce(0) { $0 + $1.price }
    }

    var averagePrice: Double {
        guard !products.isEmpty else { return 0 }
        return totalProductsValue / Double(products.count)
    }

    var hasError: Bool {
        error != nil
    }

    var errorMessage: String {
        error?.localizedDescription ?? ""
    }

    // MARK: - Dependencies
    private let convex = ConvexClient.shared
    private let lanceDB = LanceDBClient.shared
    private let productsAgent = ProductsAgent()
    private let offlineManager = OfflineManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?

    // MARK: - Initialization
    init() {
        setupSearchDebounce()
        setupOfflineObserver()
    }

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: - Offline Observer Setup
    private func setupOfflineObserver() {
        offlineManager.$isOnline
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isOnline in
                self?.isOffline = !isOnline
                if isOnline {
                    // Refresh data when coming back online
                    self?.refresh()
                }
            }
            .store(in: &cancellables)

        offlineManager.$pendingActions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] actions in
                self?.pendingCreates = actions.filter { $0.type == .createProduct }.count
                self?.pendingUpdates = actions.filter { $0.type == .updateProduct }.count
            }
            .store(in: &cancellables)
    }

    // MARK: - Search Debounce
    private func setupSearchDebounce() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self = self else { return }
                if !query.isEmpty && self.isSemanticSearchEnabled {
                    Task {
                        await self.performSemanticSearch(query: query)
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Loading

    /// Load products from the backend
    func loadProducts(forceRefresh: Bool = false) async {
        // Check if we're offline first
        if offlineManager.shouldUseCachedData() {
            await loadCachedProducts()
            return
        }

        // Use cache if valid and not forcing refresh
        if !forceRefresh && isCacheValid && !cachedProducts.isEmpty {
            products = cachedProducts
            return
        }

        guard !isLoading else { return }

        isLoading = true
        error = nil

        do {
            let fetchedProducts = try await convex.fetchProducts()
            products = fetchedProducts
            cachedProducts = fetchedProducts
            categories = Array(Set(fetchedProducts.map { $0.category })).sorted()
            lastRefreshTime = Date()

            // Cache the products for offline use
            await cacheProducts()

            self.isUsingCachedData = false
            self.lastCacheUpdate = Date()

        } catch let fetchError {
            // Ignore cancelled request errors (e.g., when view refreshes)
            let nsError = fetchError as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                print("Request cancelled (normal during view refresh)")
            } else {
                self.error = ProductsError.loadFailed(fetchError.localizedDescription)
                print("Products load error: \(fetchError)")

                // Fall back to cached data
                await loadCachedProducts()
            }
        }

        isLoading = false
    }

    /// Refresh products (invalidates cache)
    func refreshProducts() async {
        invalidateCache()
        await loadProducts(forceRefresh: true)
    }

    /// Convenience method for pull-to-refresh and button actions
    func refresh() {
        Task {
            await refreshProducts()
        }
    }

    // MARK: - Cache Operations

    private func cacheProducts() async {
        let cache = CacheService.shared

        do {
            try await cache.cache(
                products,
                forKey: CacheKeys.allProducts,
                expiration: CachedDataType.products.defaultExpiration,
                dataType: .products
            )

            // Also cache categories
            try await cache.cache(
                categories,
                forKey: CacheKeys.productCategories,
                expiration: CachedDataType.products.defaultExpiration,
                dataType: .products
            )
        } catch {
            print("Failed to cache products: \(error)")
        }
    }

    private func loadCachedProducts() async {
        let cache = CacheService.shared

        do {
            if let cachedProds: [Product] = try await cache.retrieve(forKey: CacheKeys.allProducts) {
                self.products = cachedProds
                self.cachedProducts = cachedProds
                self.isUsingCachedData = true

                let metadata = await cache.getAllMetadata()
                if let productsMeta = metadata.first(where: { $0.key == CacheKeys.allProducts }) {
                    self.lastCacheUpdate = productsMeta.createdAt
                }
            }

            if let cachedCats: [String] = try await cache.retrieve(forKey: CacheKeys.productCategories) {
                self.categories = cachedCats
            }
        } catch {
            print("Failed to load cached products: \(error)")
        }
    }

    // MARK: - Cache Management

    /// Invalidate the products cache
    func invalidateCache() {
        cachedProducts = []
        lastRefreshTime = nil
    }

    /// Set cache expiration interval
    func setCacheExpiration(_ interval: TimeInterval) {
        cacheExpirationInterval = interval
    }

    // MARK: - Search

    /// Search products by query (local search)
    func searchProducts(query: String) async {
        searchText = query
        // Local search is handled by filteredProducts computed property
    }

    /// Perform semantic search using LanceDB
    func performSemanticSearch(query: String) async {
        guard !query.isEmpty else {
            semanticSearchResults = []
            return
        }

        do {
            let results = try await lanceDB.searchProducts(query: query, limit: 20)
            semanticSearchResults = results

            // Map search results to products
            let matchedProductIds = Set(results.map { $0.id })
            let matchedProducts = products.filter { matchedProductIds.contains($0.id) }

            // Reorder products based on search score
            let orderedProducts = results.compactMap { result in
                products.first { $0.id == result.id }
            }

            // Update products array with semantic search results
            products = orderedProducts + products.filter { !matchedProductIds.contains($0.id) }

        } catch let searchError {
            print("Semantic search error: \(searchError)")
            // Fall back to local search
            semanticSearchResults = []
        }
    }

    /// Toggle semantic search mode
    func toggleSemanticSearch() {
        isSemanticSearchEnabled.toggle()
        if !isSemanticSearchEnabled {
            semanticSearchResults = []
            // Restore original product order
            Task {
                await loadProducts()
            }
        }
    }

    // MARK: - Filtering

    /// Filter products by category
    func filterByCategory(_ category: String?) {
        selectedCategory = category
    }

    /// Clear all filters
    func clearFilters() {
        selectedCategory = nil
        searchText = ""
        semanticSearchResults = []
    }

    // MARK: - Display Mode

    /// Toggle display mode between grid and list
    func toggleDisplayMode() {
        displayMode = displayMode.toggledMode
    }

    /// Set display mode
    func setDisplayMode(_ mode: ProductDisplayMode) {
        displayMode = mode
    }

    // MARK: - Product Operations

    /// Create a new product
    @discardableResult
    func createProduct(_ request: CreateProductRequest) async throws -> String {
        // If offline, queue the action
        if !offlineManager.isOnline {
            try await queueProductCreate(request)
            return "pending_\(UUID().uuidString)"
        }

        isCreating = true
        error = nil

        defer { isCreating = false }

        do {
            let productId = try await convex.createProduct(request)

            // Invalidate cache and reload
            invalidateCache()
            await loadProducts(forceRefresh: true)

            // Index the new product in LanceDB for semantic search
            if let newProduct = products.first(where: { $0.id == productId }) {
                try? await indexProductForSearch(newProduct)
            }

            return productId
        } catch let createError {
            // If the request fails, queue it for later
            try await queueProductCreate(request)
            self.error = ProductsError.createFailed(createError.localizedDescription)
            throw createError
        }
    }

    /// Update an existing product
    @discardableResult
    func updateProduct(id: String, updates: [String: Any]) async throws -> Bool {
        // If offline, queue the action
        if !offlineManager.isOnline {
            try await queueProductUpdate(id: id, updates: updates)
            return true
        }

        isUpdating = true
        error = nil

        defer { isUpdating = false }

        do {
            let success = try await convex.updateProduct(id: id, updates: updates)

            if success {
                // Invalidate cache and reload
                invalidateCache()
                await loadProducts(forceRefresh: true)

                // Re-index the updated product in LanceDB
                if let updatedProduct = products.first(where: { $0.id == id }) {
                    try? await indexProductForSearch(updatedProduct)
                }
            } else {
                self.error = ProductsError.updateFailed("Update operation returned false")
            }

            return success
        } catch let updateError {
            // If the request fails, queue it for later
            try await queueProductUpdate(id: id, updates: updates)
            self.error = ProductsError.updateFailed(updateError.localizedDescription)
            throw updateError
        }
    }

    /// Queue a product create for offline sync
    private func queueProductCreate(_ request: CreateProductRequest) async throws {
        let payload = CreateProductPayload(
            title: request.title,
            description: request.description,
            price: request.price,
            priceRange: request.priceRange,
            category: request.category,
            image: request.image,
            inStock: request.inStock,
            hasOptions: request.hasOptions
        )

        try await offlineManager.queueAction(type: .createProduct, payload: payload)
    }

    /// Queue a product update for offline sync
    private func queueProductUpdate(id: String, updates: [String: Any]) async throws {
        // Convert updates to string-string dictionary for Codable compliance
        var stringUpdates: [String: String] = [:]
        for (key, value) in updates {
            stringUpdates[key] = String(describing: value)
        }

        let payload = UpdateProductPayload(
            productId: id,
            updates: stringUpdates
        )

        try await offlineManager.queueAction(type: .updateProduct, payload: payload)
    }

    /// Delete a product
    func deleteProduct(_ productId: String) async throws {
        error = nil

        do {
            // Note: Implement delete mutation in ConvexClient if needed
            // For now, we'll simulate by marking as out of stock
            _ = try await updateProduct(id: productId, updates: ["inStock": false])

            // Remove from LanceDB index
            try? await lanceDB.deleteDocument(table: LanceDBConfig.productsTable, id: productId)

            // Invalidate cache and reload
            invalidateCache()
            await loadProducts(forceRefresh: true)

        } catch let deleteError {
            self.error = ProductsError.deleteFailed(deleteError.localizedDescription)
            throw deleteError
        }
    }

    /// Toggle product stock status
    func toggleStock(for productId: String) async throws {
        guard let product = products.first(where: { $0.id == productId }) else {
            throw ProductsError.productNotFound(productId)
        }

        _ = try await updateProduct(id: productId, updates: ["inStock": !product.inStock])
    }

    /// Update product price
    func updatePrice(for productId: String, newPrice: Double) async throws {
        _ = try await updateProduct(id: productId, updates: ["price": newPrice])
    }

    // MARK: - Selection

    /// Select a product for detail view
    func selectProduct(_ product: Product) {
        selectedProduct = product
    }

    /// Deselect product
    func deselectProduct() {
        selectedProduct = nil
    }

    // MARK: - Error Handling

    /// Clear current error
    func clearError() {
        error = nil
    }

    /// Retry last failed operation
    func retry() {
        Task {
            await loadProducts(forceRefresh: true)
        }
    }

    // MARK: - Offline Status

    func getOfflineStatus() -> OfflineStatusSummary {
        offlineManager.getStatusSummary()
    }

    func getCacheAge() -> String? {
        guard let lastUpdate = lastCacheUpdate else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastUpdate, relativeTo: Date())
    }

    // MARK: - Semantic Search Indexing

    /// Index a single product for semantic search
    private func indexProductForSearch(_ product: Product) async throws {
        let text = """
        Product: \(product.title)
        Category: \(product.category)
        Description: \(product.description ?? "")
        Price: \(product.formattedPrice)
        In Stock: \(product.inStock ? "Yes" : "No")
        """

        try await lanceDB.addDocument(
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

    /// Index all products for semantic search
    func indexAllProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await lanceDB.indexProducts(products)
        } catch let indexError {
            print("Product indexing error: \(indexError)")
        }
    }

    // MARK: - Statistics

    /// Get product statistics
    func getStatistics() -> ProductStatistics {
        let priceRange: (min: Double, max: Double) = products.isEmpty
            ? (0, 0)
            : (products.map { $0.price }.min() ?? 0, products.map { $0.price }.max() ?? 0)

        let categoryBreakdown = Dictionary(grouping: products, by: { $0.category })
            .mapValues { CategoryStats(count: $0.count, inStock: $0.filter { $0.inStock }.count) }

        return ProductStatistics(
            totalProducts: products.count,
            inStockProducts: inStockCount,
            outOfStockProducts: outOfStockCount,
            totalCategories: categories.count,
            averagePrice: averagePrice,
            priceRange: priceRange,
            categoryBreakdown: categoryBreakdown
        )
    }

    /// Get products grouped by category
    func getProductsByCategory() -> [String: [Product]] {
        Dictionary(grouping: products, by: { $0.category })
    }

    /// Get out of stock products
    func getOutOfStockProducts() -> [Product] {
        products.filter { !$0.inStock }
    }

    /// Get products with options
    func getProductsWithOptions() -> [Product] {
        products.filter { $0.hasOptions ?? false }
    }

    // MARK: - Auto Refresh

    /// Start auto-refresh timer
    func startAutoRefresh(interval: TimeInterval = 300) {
        stopAutoRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                // Only auto-refresh when online
                if self?.offlineManager.isOnline == true {
                    await self?.loadProducts(forceRefresh: true)
                }
            }
        }
    }

    /// Stop auto-refresh timer
    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - Product Statistics
struct ProductStatistics {
    let totalProducts: Int
    let inStockProducts: Int
    let outOfStockProducts: Int
    let totalCategories: Int
    let averagePrice: Double
    let priceRange: (min: Double, max: Double)
    let categoryBreakdown: [String: CategoryStats]

    var formattedAveragePrice: String {
        String(format: "$%.2f", averagePrice)
    }

    var formattedPriceRange: String {
        String(format: "$%.2f - $%.2f", priceRange.min, priceRange.max)
    }

    var inStockPercentage: Double {
        guard totalProducts > 0 else { return 0 }
        return Double(inStockProducts) / Double(totalProducts) * 100
    }
}

struct CategoryStats {
    let count: Int
    let inStock: Int

    var outOfStock: Int {
        count - inStock
    }

    var inStockPercentage: Double {
        guard count > 0 else { return 0 }
        return Double(inStock) / Double(count) * 100
    }
}

// MARK: - Products Errors
enum ProductsError: Error, LocalizedError {
    case loadFailed(String)
    case createFailed(String)
    case updateFailed(String)
    case deleteFailed(String)
    case productNotFound(String)
    case invalidData(String)
    case searchFailed(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .loadFailed(let message):
            return "Failed to load products: \(message)"
        case .createFailed(let message):
            return "Failed to create product: \(message)"
        case .updateFailed(let message):
            return "Failed to update product: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete product: \(message)"
        case .productNotFound(let id):
            return "Product not found: \(id)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .searchFailed(let message):
            return "Search failed: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }

    var userFriendlyMessage: String {
        switch self {
        case .loadFailed:
            return "Unable to load products. Please check your connection and try again."
        case .createFailed:
            return "Unable to create product. Please check your input and try again."
        case .updateFailed:
            return "Unable to update product. Please try again."
        case .deleteFailed:
            return "Unable to delete product. Please try again."
        case .productNotFound:
            return "This product could not be found. It may have been deleted."
        case .invalidData:
            return "The data provided is invalid. Please check your input."
        case .searchFailed:
            return "Search failed. Please try a different query."
        case .networkError:
            return "Connection error. Please check your internet connection."
        }
    }

    var isRetryable: Bool {
        switch self {
        case .loadFailed, .searchFailed, .networkError:
            return true
        case .createFailed, .updateFailed, .deleteFailed, .productNotFound, .invalidData:
            return false
        }
    }
}

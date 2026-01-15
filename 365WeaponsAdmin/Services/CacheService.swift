//
//  CacheService.swift
//  365WeaponsAdmin
//
//  Generic caching service using UserDefaults for small data and FileManager for larger datasets
//  Thread-safe implementation using Swift actor
//

import Foundation

// MARK: - Cache Service Actor
/// Thread-safe caching service that uses UserDefaults for small data and FileManager for larger datasets
actor CacheService {
    // MARK: - Singleton
    static let shared = CacheService()

    // MARK: - Configuration
    private let smallDataThreshold: Int = 100_000  // 100KB threshold for UserDefaults
    private let userDefaultsKeyPrefix = "cache_"
    private let fileManagerDirectory = "CacheStorage"

    // MARK: - Storage
    private var metadataStore: [String: CacheMetadata] = [:]
    private let metadataKey = "cache_metadata_store"

    // MARK: - File Management
    private var cacheDirectoryURL: URL? {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let cacheURL = documentsURL.appendingPathComponent(fileManagerDirectory)

        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: cacheURL.path) {
            try? fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        }

        return cacheURL
    }

    // MARK: - Initialization
    private init() {
        // Load metadata from UserDefaults on init
        Task {
            await loadMetadata()
        }
    }

    // MARK: - Public API

    /// Cache data with an optional expiration time
    /// - Parameters:
    ///   - value: The value to cache (must be Codable)
    ///   - key: The unique key for this cached item
    ///   - expiration: Optional expiration time interval from now
    ///   - dataType: The type of data being cached
    func cache<T: Codable>(
        _ value: T,
        forKey key: String,
        expiration: TimeInterval? = nil,
        dataType: CachedDataType = .other
    ) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(value)
        let expiresAt = expiration.map { Date().addingTimeInterval($0) }

        // Create metadata
        let metadata = CacheMetadata(
            key: key,
            size: data.count,
            createdAt: Date(),
            expiresAt: expiresAt,
            dataType: dataType
        )

        // Store based on size
        if data.count < smallDataThreshold {
            // Use UserDefaults for small data
            UserDefaults.standard.set(data, forKey: userDefaultsKeyPrefix + key)
        } else {
            // Use FileManager for large data
            try storeToFile(data: data, key: key)
        }

        // Update metadata
        metadataStore[key] = metadata
        saveMetadata()
    }

    /// Retrieve cached data
    /// - Parameter key: The key for the cached item
    /// - Returns: The cached value if found and not expired, nil otherwise
    func retrieve<T: Codable>(forKey key: String) throws -> T? {
        // Check if key exists in metadata
        guard let metadata = metadataStore[key] else {
            return nil
        }

        // Check expiration
        if metadata.isExpired {
            try? invalidate(forKey: key)
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var data: Data?

        // Try to retrieve from UserDefaults first
        if let smallData = UserDefaults.standard.data(forKey: userDefaultsKeyPrefix + key) {
            data = smallData
        } else {
            // Try to retrieve from file
            data = try retrieveFromFile(key: key)
        }

        guard let cachedData = data else {
            // Data not found, clean up metadata
            try? invalidate(forKey: key)
            return nil
        }

        return try decoder.decode(T.self, from: cachedData)
    }

    /// Retrieve cached data with metadata
    /// - Parameter key: The key for the cached item
    /// - Returns: CachedData wrapper with the value and metadata if found and not expired
    func retrieveWithMetadata<T: Codable>(forKey key: String) throws -> CachedData<T>? {
        guard let metadata = metadataStore[key] else {
            return nil
        }

        if metadata.isExpired {
            try? invalidate(forKey: key)
            return nil
        }

        guard let value: T = try retrieve(forKey: key) else {
            return nil
        }

        return CachedData(
            data: value,
            cachedAt: metadata.createdAt,
            expiresAt: metadata.expiresAt,
            syncStatus: .synced
        )
    }

    /// Invalidate (remove) cached data for a specific key
    /// - Parameter key: The key to invalidate
    func invalidate(forKey key: String) throws {
        // Remove from UserDefaults
        UserDefaults.standard.removeObject(forKey: userDefaultsKeyPrefix + key)

        // Remove from file system
        try removeFile(key: key)

        // Remove metadata
        metadataStore.removeValue(forKey: key)
        saveMetadata()
    }

    /// Invalidate all cached data of a specific type
    /// - Parameter dataType: The type of data to invalidate
    func invalidate(forType dataType: CachedDataType) throws {
        let keysToRemove = metadataStore.filter { $0.value.dataType == dataType }.map { $0.key }
        for key in keysToRemove {
            try invalidate(forKey: key)
        }
    }

    /// Clear all cached data
    func clearAll() throws {
        // Clear all keys from UserDefaults
        let userDefaults = UserDefaults.standard
        let allKeys = metadataStore.keys
        for key in allKeys {
            userDefaults.removeObject(forKey: userDefaultsKeyPrefix + key)
        }

        // Clear cache directory
        if let cacheURL = cacheDirectoryURL {
            let fileManager = FileManager.default
            try? fileManager.removeItem(at: cacheURL)
            try? fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        }

        // Clear metadata
        metadataStore.removeAll()
        saveMetadata()
    }

    /// Get the total size of all cached data
    /// - Returns: Total cache size in bytes
    func getCacheSize() -> Int {
        return metadataStore.values.reduce(0) { $0 + $1.size }
    }

    /// Get cache size for a specific data type
    /// - Parameter dataType: The type of data to measure
    /// - Returns: Size in bytes for that data type
    func getCacheSize(forType dataType: CachedDataType) -> Int {
        return metadataStore.values
            .filter { $0.dataType == dataType }
            .reduce(0) { $0 + $1.size }
    }

    /// Get formatted cache size string
    /// - Returns: Human-readable cache size
    func getFormattedCacheSize() -> String {
        let size = getCacheSize()
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }

    /// Get all cache metadata
    /// - Returns: Array of all cache metadata entries
    func getAllMetadata() -> [CacheMetadata] {
        return Array(metadataStore.values)
    }

    /// Get metadata for a specific data type
    /// - Parameter dataType: The type of data
    /// - Returns: Array of metadata entries for that type
    func getMetadata(forType dataType: CachedDataType) -> [CacheMetadata] {
        return metadataStore.values.filter { $0.dataType == dataType }
    }

    /// Check if a key exists and is not expired
    /// - Parameter key: The key to check
    /// - Returns: True if the key exists and is valid
    func hasValidCache(forKey key: String) -> Bool {
        guard let metadata = metadataStore[key] else {
            return false
        }
        return !metadata.isExpired
    }

    /// Clean up expired cache entries
    func cleanupExpired() throws {
        let expiredKeys = metadataStore.filter { $0.value.isExpired }.map { $0.key }
        for key in expiredKeys {
            try invalidate(forKey: key)
        }
    }

    // MARK: - Cache Statistics

    /// Get cache statistics
    /// - Returns: Dictionary with cache statistics
    func getStatistics() -> CacheStatistics {
        let allMetadata = Array(metadataStore.values)
        let totalSize = allMetadata.reduce(0) { $0 + $1.size }
        let expiredCount = allMetadata.filter { $0.isExpired }.count
        let validCount = allMetadata.count - expiredCount

        var sizeByType: [CachedDataType: Int] = [:]
        for dataType in CachedDataType.allCases {
            sizeByType[dataType] = allMetadata
                .filter { $0.dataType == dataType }
                .reduce(0) { $0 + $1.size }
        }

        return CacheStatistics(
            totalEntries: allMetadata.count,
            validEntries: validCount,
            expiredEntries: expiredCount,
            totalSize: totalSize,
            sizeByType: sizeByType
        )
    }

    // MARK: - Private Helpers

    private func storeToFile(data: Data, key: String) throws {
        guard let cacheURL = cacheDirectoryURL else {
            throw CacheError.fileSystemError("Could not access cache directory")
        }

        let fileURL = cacheURL.appendingPathComponent(sanitizedFileName(for: key))
        try data.write(to: fileURL, options: .atomic)
    }

    private func retrieveFromFile(key: String) throws -> Data? {
        guard let cacheURL = cacheDirectoryURL else {
            return nil
        }

        let fileURL = cacheURL.appendingPathComponent(sanitizedFileName(for: key))
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        return try Data(contentsOf: fileURL)
    }

    private func removeFile(key: String) throws {
        guard let cacheURL = cacheDirectoryURL else {
            return
        }

        let fileURL = cacheURL.appendingPathComponent(sanitizedFileName(for: key))
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    private func sanitizedFileName(for key: String) -> String {
        // Replace invalid filename characters
        let invalidCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return key.components(separatedBy: invalidCharacters).joined(separator: "_") + ".cache"
    }

    private func loadMetadata() {
        if let data = UserDefaults.standard.data(forKey: metadataKey),
           let decoded = try? JSONDecoder().decode([String: CacheMetadata].self, from: data) {
            metadataStore = decoded
        }
    }

    private func saveMetadata() {
        if let encoded = try? JSONEncoder().encode(metadataStore) {
            UserDefaults.standard.set(encoded, forKey: metadataKey)
        }
    }
}

// MARK: - Cache Statistics
struct CacheStatistics {
    let totalEntries: Int
    let validEntries: Int
    let expiredEntries: Int
    let totalSize: Int
    let sizeByType: [CachedDataType: Int]

    var formattedTotalSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(totalSize))
    }

    func formattedSize(forType type: CachedDataType) -> String {
        let size = sizeByType[type] ?? 0
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

// MARK: - Cache Error
enum CacheError: Error, LocalizedError {
    case encodingError(String)
    case decodingError(String)
    case fileSystemError(String)
    case keyNotFound(String)
    case expired(String)

    var errorDescription: String? {
        switch self {
        case .encodingError(let message):
            return "Cache encoding error: \(message)"
        case .decodingError(let message):
            return "Cache decoding error: \(message)"
        case .fileSystemError(let message):
            return "Cache file system error: \(message)"
        case .keyNotFound(let key):
            return "Cache key not found: \(key)"
        case .expired(let key):
            return "Cache expired for key: \(key)"
        }
    }
}

// MARK: - Cache Keys
/// Predefined cache keys for common data types
enum CacheKeys {
    static let dashboardStats = "dashboard_stats"
    static let recentOrders = "recent_orders"
    static let allOrders = "all_orders"
    static let allProducts = "all_products"
    static let productCategories = "product_categories"
    static let partners = "partners"
    static let commissions = "commissions"
    static let inquiries = "inquiries"
    static let userProfile = "user_profile"
    static let revenueData = "revenue_data"
    static let lastSyncDate = "last_sync_date"
    static let pendingActions = "pending_actions"

    static func orderDetail(_ orderId: String) -> String {
        "order_detail_\(orderId)"
    }

    static func productDetail(_ productId: String) -> String {
        "product_detail_\(productId)"
    }

    static func partnerDetail(_ partnerId: String) -> String {
        "partner_detail_\(partnerId)"
    }
}

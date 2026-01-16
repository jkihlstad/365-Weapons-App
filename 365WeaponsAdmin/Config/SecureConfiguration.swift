//
//  SecureConfiguration.swift
//  365WeaponsAdmin
//
//  Secure API key management using iOS Keychain
//

import Foundation
import Security

// MARK: - Keychain Error Types

/// Errors that can occur during Keychain operations
enum KeychainError: LocalizedError {
    case itemNotFound
    case duplicateItem
    case unexpectedStatus(OSStatus)
    case invalidData
    case encodingFailed
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "The requested item was not found in the Keychain."
        case .duplicateItem:
            return "An item with this key already exists in the Keychain."
        case .unexpectedStatus(let status):
            return "Keychain operation failed with status: \(status)"
        case .invalidData:
            return "The data retrieved from Keychain is invalid."
        case .encodingFailed:
            return "Failed to encode data for Keychain storage."
        case .accessDenied:
            return "Access to Keychain was denied."
        }
    }
}

// MARK: - API Key Types

/// Supported API key types for the application
enum APIKeyType: String, CaseIterable, Identifiable {
    case openRouter = "com.365weapons.admin.openrouter"
    case openAI = "com.365weapons.admin.openai"
    case clerk = "com.365weapons.admin.clerk"
    case convex = "com.365weapons.admin.convex"
    case backendAuth = "com.365weapons.admin.backend"
    case tavily = "com.365weapons.admin.tavily"

    var id: String { rawValue }

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .openRouter: return "OpenRouter"
        case .openAI: return "OpenAI"
        case .clerk: return "Clerk"
        case .convex: return "Convex"
        case .backendAuth: return "Backend API"
        case .tavily: return "Tavily"
        }
    }

    /// Environment variable name for fallback
    var environmentVariableName: String {
        switch self {
        case .openRouter: return "OPENROUTER_API_KEY"
        case .openAI: return "OPENAI_API_KEY"
        case .clerk: return "CLERK_PUBLISHABLE_KEY"
        case .convex: return "CONVEX_DEPLOYMENT_URL"
        case .backendAuth: return "API_AUTH_TOKEN"
        case .tavily: return "TAVILY_API_KEY"
        }
    }

    /// Description of what this key is used for
    var usageDescription: String {
        switch self {
        case .openRouter: return "AI Chat via OpenRouter"
        case .openAI: return "Voice (Whisper & TTS)"
        case .clerk: return "Authentication"
        case .convex: return "Backend Database"
        case .backendAuth: return "LanceDB & Backend API"
        case .tavily: return "Web Search"
        }
    }
}

// MARK: - Secure Configuration

/// Manages secure storage of API keys using iOS Keychain
/// with fallback to environment variables for development
final class SecureConfiguration {

    // MARK: - Singleton

    static let shared = SecureConfiguration()

    // MARK: - Properties

    /// Service identifier for Keychain items
    private let serviceName = "com.365weapons.admin"

    /// Access group for shared Keychain access (if needed for extensions)
    private let accessGroup: String? = nil

    /// In-memory cache for performance (cleared on app termination)
    private var cache: [String: String] = [:]
    private let cacheQueue = DispatchQueue(label: "com.365weapons.admin.keychain.cache", attributes: .concurrent)

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Stores an API key securely in the Keychain
    /// - Parameters:
    ///   - key: The API key value to store
    ///   - keyType: The type of API key being stored
    /// - Throws: KeychainError if the operation fails
    func storeAPIKey(_ key: String, for keyType: APIKeyType) throws {
        guard !key.isEmpty else {
            throw KeychainError.invalidData
        }

        guard let data = key.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // Build the query
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: keyType.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        // Delete any existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: keyType.rawValue
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add the new item
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }

        // Update cache
        cacheQueue.async(flags: .barrier) {
            self.cache[keyType.rawValue] = key
        }
    }

    /// Retrieves an API key from secure storage
    /// Falls back to environment variables if not found in Keychain
    /// - Parameter keyType: The type of API key to retrieve
    /// - Returns: The API key if found, nil otherwise
    func retrieveAPIKey(for keyType: APIKeyType) -> String? {
        // Check cache first
        var cachedValue: String?
        cacheQueue.sync {
            cachedValue = cache[keyType.rawValue]
        }
        if let cached = cachedValue {
            return cached
        }

        // Try Keychain
        if let keychainValue = retrieveFromKeychain(keyType: keyType) {
            cacheQueue.async(flags: .barrier) {
                self.cache[keyType.rawValue] = keychainValue
            }
            return keychainValue
        }

        // Fallback to environment variable (useful for development)
        if let envValue = ProcessInfo.processInfo.environment[keyType.environmentVariableName],
           !envValue.isEmpty {
            return envValue
        }

        return nil
    }

    /// Deletes an API key from secure storage
    /// - Parameter keyType: The type of API key to delete
    /// - Throws: KeychainError if the operation fails
    func deleteAPIKey(for keyType: APIKeyType) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: keyType.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }

        // Clear from cache
        cacheQueue.async(flags: .barrier) {
            self.cache.removeValue(forKey: keyType.rawValue)
        }
    }

    /// Checks if an API key exists in secure storage or environment
    /// - Parameter keyType: The type of API key to check
    /// - Returns: true if the key exists, false otherwise
    func hasAPIKey(for keyType: APIKeyType) -> Bool {
        return retrieveAPIKey(for: keyType) != nil
    }

    /// Checks if an API key exists specifically in the Keychain (not environment)
    /// - Parameter keyType: The type of API key to check
    /// - Returns: true if the key exists in Keychain, false otherwise
    func hasKeychainAPIKey(for keyType: APIKeyType) -> Bool {
        return retrieveFromKeychain(keyType: keyType) != nil
    }

    /// Deletes all stored API keys
    /// - Throws: KeychainError if any deletion fails
    func deleteAllAPIKeys() throws {
        for keyType in APIKeyType.allCases {
            try deleteAPIKey(for: keyType)
        }
    }

    /// Clears the in-memory cache
    func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }

    // MARK: - Private Methods

    /// Retrieves a value directly from Keychain
    private func retrieveFromKeychain(keyType: APIKeyType) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: keyType.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension SecureConfiguration {
    /// Lists all stored keys (for debugging only)
    func debugListStoredKeys() -> [APIKeyType: Bool] {
        var result: [APIKeyType: Bool] = [:]
        for keyType in APIKeyType.allCases {
            result[keyType] = hasKeychainAPIKey(for: keyType)
        }
        return result
    }

    /// Prints debug info about key storage status
    func debugPrintStatus() {
        print("=== SecureConfiguration Debug Status ===")
        for keyType in APIKeyType.allCases {
            let inKeychain = hasKeychainAPIKey(for: keyType)
            let inEnv = ProcessInfo.processInfo.environment[keyType.environmentVariableName] != nil
            let hasKey = hasAPIKey(for: keyType)
            print("\(keyType.displayName): Keychain=\(inKeychain), Env=\(inEnv), Available=\(hasKey)")
        }
        print("=========================================")
    }
}
#endif

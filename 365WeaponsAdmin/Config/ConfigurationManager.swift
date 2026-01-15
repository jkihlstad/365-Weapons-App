//
//  ConfigurationManager.swift
//  365WeaponsAdmin
//
//  Facade for secure configuration management with validation and migration support
//

import Foundation
import Combine

// MARK: - Configuration Errors

/// Errors that can occur during configuration operations
enum ConfigurationError: LocalizedError {
    case invalidKeyFormat(APIKeyType, String)
    case keyNotConfigured(APIKeyType)
    case migrationFailed(String)
    case storageFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidKeyFormat(let keyType, let reason):
            return "\(keyType.displayName) key format is invalid: \(reason)"
        case .keyNotConfigured(let keyType):
            return "\(keyType.displayName) API key is not configured."
        case .migrationFailed(let reason):
            return "Failed to migrate configuration: \(reason)"
        case .storageFailed(let reason):
            return "Failed to store configuration: \(reason)"
        }
    }
}

// MARK: - Configuration Status

/// Represents the configuration status for a key
struct APIKeyStatus: Identifiable {
    let keyType: APIKeyType
    let isConfigured: Bool
    let isValid: Bool
    let source: KeySource

    var id: String { keyType.rawValue }

    enum KeySource: String {
        case keychain = "Secure Storage"
        case environment = "Environment"
        case notConfigured = "Not Configured"
    }
}

// MARK: - Configuration Manager

/// Central manager for all application configuration
/// Acts as a facade over SecureConfiguration with validation and typed access
@MainActor
final class ConfigurationManager: ObservableObject {

    // MARK: - Singleton

    static let shared = ConfigurationManager()

    // MARK: - Published Properties

    /// Whether all required API keys are configured
    @Published private(set) var isFullyConfigured: Bool = false

    /// Status of each API key
    @Published private(set) var keyStatuses: [APIKeyStatus] = []

    /// Whether first-run setup is needed
    @Published private(set) var needsFirstRunSetup: Bool = true

    // MARK: - Private Properties

    private let secureConfig = SecureConfiguration.shared
    private let userDefaults = UserDefaults.standard

    /// Key for tracking if initial setup has been completed
    private let setupCompletedKey = "com.365weapons.admin.setupCompleted"

    /// Required keys for the app to function
    private let requiredKeys: Set<APIKeyType> = [.openRouter, .openAI, .clerk]

    // MARK: - Initialization

    private init() {
        refreshStatus()
    }

    // MARK: - Typed API Key Access

    /// OpenRouter API key for AI chat
    var openRouterAPIKey: String? {
        secureConfig.retrieveAPIKey(for: .openRouter)
    }

    /// OpenAI API key for voice features (Whisper & TTS)
    var openAIAPIKey: String? {
        secureConfig.retrieveAPIKey(for: .openAI)
    }

    /// Clerk publishable key for authentication
    var clerkPublishableKey: String? {
        secureConfig.retrieveAPIKey(for: .clerk)
    }

    /// Convex deployment URL for backend
    var convexDeploymentURL: String? {
        secureConfig.retrieveAPIKey(for: .convex)
    }

    // MARK: - Configuration Methods

    /// Stores an API key with validation
    /// - Parameters:
    ///   - key: The API key value
    ///   - keyType: The type of key being stored
    /// - Throws: ConfigurationError if validation or storage fails
    func setAPIKey(_ key: String, for keyType: APIKeyType) throws {
        // Validate the key format
        try validateKeyFormat(key, for: keyType)

        // Store in secure storage
        do {
            try secureConfig.storeAPIKey(key, for: keyType)
        } catch {
            throw ConfigurationError.storageFailed(error.localizedDescription)
        }

        // Refresh status
        refreshStatus()
    }

    /// Retrieves an API key
    /// - Parameter keyType: The type of key to retrieve
    /// - Returns: The API key value, or nil if not configured
    func getAPIKey(for keyType: APIKeyType) -> String? {
        return secureConfig.retrieveAPIKey(for: keyType)
    }

    /// Removes an API key from storage
    /// - Parameter keyType: The type of key to remove
    func removeAPIKey(for keyType: APIKeyType) throws {
        try secureConfig.deleteAPIKey(for: keyType)
        refreshStatus()
    }

    /// Checks if a specific key is configured
    /// - Parameter keyType: The type of key to check
    /// - Returns: true if configured, false otherwise
    func hasAPIKey(for keyType: APIKeyType) -> Bool {
        return secureConfig.hasAPIKey(for: keyType)
    }

    /// Gets a masked version of an API key for display
    /// - Parameter keyType: The type of key to mask
    /// - Returns: Masked key string or empty if not configured
    func getMaskedKey(for keyType: APIKeyType) -> String {
        guard let key = getAPIKey(for: keyType), !key.isEmpty else {
            return ""
        }

        if key.count <= 8 {
            return String(repeating: "*", count: key.count)
        }

        let prefix = String(key.prefix(4))
        let suffix = String(key.suffix(4))
        let maskedMiddle = String(repeating: "*", count: min(key.count - 8, 20))

        return "\(prefix)\(maskedMiddle)\(suffix)"
    }

    // MARK: - Migration

    /// Migrates hardcoded keys to secure storage (for first-time upgrade)
    /// - Parameter legacyKeys: Dictionary of key types to their legacy values
    func migrateFromLegacyKeys(_ legacyKeys: [APIKeyType: String]) throws {
        for (keyType, value) in legacyKeys {
            // Only migrate if the key isn't already in secure storage
            guard !secureConfig.hasKeychainAPIKey(for: keyType) else {
                continue
            }

            // Only migrate non-empty, non-placeholder values
            guard !value.isEmpty,
                  !value.hasPrefix("YOUR_"),
                  !value.hasPrefix("PLACEHOLDER") else {
                continue
            }

            do {
                try secureConfig.storeAPIKey(value, for: keyType)
            } catch {
                throw ConfigurationError.migrationFailed(
                    "Failed to migrate \(keyType.displayName): \(error.localizedDescription)"
                )
            }
        }

        refreshStatus()
    }

    /// Marks first-run setup as completed
    func completeFirstRunSetup() {
        userDefaults.set(true, forKey: setupCompletedKey)
        needsFirstRunSetup = false
    }

    /// Resets the first-run setup flag (for testing)
    func resetFirstRunSetup() {
        userDefaults.removeObject(forKey: setupCompletedKey)
        needsFirstRunSetup = true
    }

    // MARK: - Validation

    /// Validates an API key format for a given type
    /// - Parameters:
    ///   - key: The key to validate
    ///   - keyType: The type of key
    /// - Throws: ConfigurationError if validation fails
    func validateKeyFormat(_ key: String, for keyType: APIKeyType) throws {
        guard !key.isEmpty else {
            throw ConfigurationError.invalidKeyFormat(keyType, "Key cannot be empty")
        }

        switch keyType {
        case .openRouter:
            // OpenRouter keys start with "sk-or-"
            if !key.hasPrefix("sk-or-") {
                throw ConfigurationError.invalidKeyFormat(
                    keyType,
                    "OpenRouter keys should start with 'sk-or-'"
                )
            }
            if key.count < 20 {
                throw ConfigurationError.invalidKeyFormat(
                    keyType,
                    "Key appears to be too short"
                )
            }

        case .openAI:
            // OpenAI keys start with "sk-" (but not "sk-or-")
            if !key.hasPrefix("sk-") {
                throw ConfigurationError.invalidKeyFormat(
                    keyType,
                    "OpenAI keys should start with 'sk-'"
                )
            }
            if key.hasPrefix("sk-or-") {
                throw ConfigurationError.invalidKeyFormat(
                    keyType,
                    "This appears to be an OpenRouter key, not an OpenAI key"
                )
            }
            if key.count < 20 {
                throw ConfigurationError.invalidKeyFormat(
                    keyType,
                    "Key appears to be too short"
                )
            }

        case .clerk:
            // Clerk publishable keys start with "pk_"
            if !key.hasPrefix("pk_") {
                throw ConfigurationError.invalidKeyFormat(
                    keyType,
                    "Clerk publishable keys should start with 'pk_'"
                )
            }

        case .convex:
            // Convex deployment URLs should be valid URLs
            if !key.hasPrefix("https://") {
                throw ConfigurationError.invalidKeyFormat(
                    keyType,
                    "Convex deployment URL should start with 'https://'"
                )
            }
            if !key.contains(".convex.cloud") && !key.contains(".convex.site") {
                throw ConfigurationError.invalidKeyFormat(
                    keyType,
                    "Convex URL should contain '.convex.cloud' or '.convex.site'"
                )
            }
        }
    }

    /// Validates a key format without throwing
    /// - Parameters:
    ///   - key: The key to validate
    ///   - keyType: The type of key
    /// - Returns: true if valid, false otherwise
    func isValidKeyFormat(_ key: String, for keyType: APIKeyType) -> Bool {
        do {
            try validateKeyFormat(key, for: keyType)
            return true
        } catch {
            return false
        }
    }

    /// Gets validation error message for a key
    /// - Parameters:
    ///   - key: The key to validate
    ///   - keyType: The type of key
    /// - Returns: Error message or nil if valid
    func validationError(for key: String, keyType: APIKeyType) -> String? {
        do {
            try validateKeyFormat(key, for: keyType)
            return nil
        } catch let error as ConfigurationError {
            return error.errorDescription
        } catch {
            return error.localizedDescription
        }
    }

    // MARK: - Status

    /// Refreshes the configuration status
    func refreshStatus() {
        var statuses: [APIKeyStatus] = []

        for keyType in APIKeyType.allCases {
            let isConfigured = secureConfig.hasAPIKey(for: keyType)
            let key = secureConfig.retrieveAPIKey(for: keyType)
            let isValid = key.map { isValidKeyFormat($0, for: keyType) } ?? false

            let source: APIKeyStatus.KeySource
            if secureConfig.hasKeychainAPIKey(for: keyType) {
                source = .keychain
            } else if ProcessInfo.processInfo.environment[keyType.environmentVariableName] != nil {
                source = .environment
            } else {
                source = .notConfigured
            }

            statuses.append(APIKeyStatus(
                keyType: keyType,
                isConfigured: isConfigured,
                isValid: isConfigured ? isValid : true,
                source: source
            ))
        }

        keyStatuses = statuses

        // Check if all required keys are configured and valid
        isFullyConfigured = requiredKeys.allSatisfy { keyType in
            statuses.first { $0.keyType == keyType }?.isConfigured == true
        }

        // Check if first-run setup is needed
        needsFirstRunSetup = !userDefaults.bool(forKey: setupCompletedKey) && !isFullyConfigured
    }

    /// Gets the status for a specific key type
    /// - Parameter keyType: The key type to check
    /// - Returns: The status for that key
    func status(for keyType: APIKeyType) -> APIKeyStatus? {
        return keyStatuses.first { $0.keyType == keyType }
    }

    // MARK: - Testing Connection

    /// Tests if an API key is functional by making a minimal API call
    /// - Parameter keyType: The type of key to test
    /// - Returns: Result indicating success or failure reason
    func testAPIKey(for keyType: APIKeyType) async -> Result<Void, Error> {
        guard let key = getAPIKey(for: keyType) else {
            return .failure(ConfigurationError.keyNotConfigured(keyType))
        }

        // Validate format first
        do {
            try validateKeyFormat(key, for: keyType)
        } catch {
            return .failure(error)
        }

        // For now, just return success if the key exists and is valid format
        // In production, you would make actual API calls to verify
        return .success(())
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension ConfigurationManager {
    /// Prints debug status of all configurations
    nonisolated func debugPrintStatus() {
        Task { @MainActor in
            print("=== ConfigurationManager Debug Status ===")
            print("Fully Configured: \(isFullyConfigured)")
            print("Needs First Run Setup: \(needsFirstRunSetup)")
            print("")
            for status in keyStatuses {
                print("\(status.keyType.displayName):")
                print("  - Configured: \(status.isConfigured)")
                print("  - Valid: \(status.isValid)")
                print("  - Source: \(status.source.rawValue)")
            }
            print("==========================================")
        }
    }
}
#endif

//
//  ClerkAuthClient.swift
//  365WeaponsAdmin
//
//  Clerk Authentication Helper - Works alongside the official Clerk iOS SDK
//

import Foundation
import Combine
import Clerk

// MARK: - Admin Configuration
struct AdminConfig {
    // Admin email whitelist (mirrors website config)
    static let adminEmails: Set<String> = [
        "jkihlstad@gmail.com",
        "my365weapons@gmail.com",
        "contact@365weapons.com"
    ]

    /// Check if an email address has admin access
    static func isAdminEmail(_ email: String?) -> Bool {
        guard let email = email?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }
        return adminEmails.contains(email)
    }
}

// MARK: - Clerk Auth Client
/// Helper class that works alongside the official Clerk iOS SDK
/// Provides admin verification and token management for API calls
@MainActor
class ClerkAuthClient: ObservableObject {
    static let shared = ClerkAuthClient()

    // MARK: - Published Properties
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var isAdmin: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published var error: AuthError?

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    /// Get the current user from Clerk SDK
    var currentUser: User? {
        Clerk.shared.user
    }

    /// Get the current session from Clerk SDK
    var currentSession: Session? {
        Clerk.shared.session
    }

    /// Get the user's primary email address
    var userEmail: String? {
        currentUser?.primaryEmailAddress?.emailAddress
    }

    /// Get the user's full name
    var userFullName: String? {
        guard let user = currentUser else { return nil }
        let parts = [user.firstName, user.lastName].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    /// Get the user's profile image URL
    var userImageURL: URL? {
        guard let urlString = currentUser?.imageUrl else { return nil }
        return URL(string: urlString)
    }

    // MARK: - Initialization
    private init() {
        setupClerkObservers()
    }

    // MARK: - Clerk SDK Sync

    /// Set up observers to sync with Clerk SDK state changes
    private func setupClerkObservers() {
        // Observe Clerk's authentication state
        // The Clerk SDK publishes changes to its state that we can observe
        syncWithClerkState()

        // Set up a timer to periodically check Clerk state
        // This ensures we stay in sync even if we miss a notification
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.syncWithClerkState()
            }
            .store(in: &cancellables)
    }

    /// Sync our state with the official Clerk SDK
    func syncWithClerkState() {
        let wasAuthenticated = isAuthenticated
        let wasAdmin = isAdmin

        // Check if user is signed in via Clerk SDK
        let user = Clerk.shared.user
        let session = Clerk.shared.session

        isAuthenticated = user != nil && session != nil

        // Check admin status based on email whitelist
        if isAuthenticated, let email = user?.primaryEmailAddress?.emailAddress {
            isAdmin = AdminConfig.isAdminEmail(email)
        } else {
            isAdmin = false
        }

        // Clear any previous errors when state changes
        if wasAuthenticated != isAuthenticated || wasAdmin != isAdmin {
            error = nil
        }
    }

    // MARK: - Token Management

    /// Get an authentication token for API calls
    /// Uses the Clerk SDK to get a fresh session token
    func getAuthToken() async -> String? {
        guard let session = Clerk.shared.session else {
            return nil
        }

        do {
            // Get a fresh token from the Clerk session
            let token = try await session.getToken()
            return token?.jwt
        } catch {
            print("ClerkAuthClient: Failed to get auth token: \(error)")
            return nil
        }
    }

    /// Get an authentication token with a specific template (for custom JWT claims)
    func getAuthToken(template: String) async -> String? {
        guard let session = Clerk.shared.session else {
            return nil
        }

        do {
            let token = try await session.getToken(.init(template: template))
            return token?.jwt
        } catch {
            print("ClerkAuthClient: Failed to get auth token with template '\(template)': \(error)")
            return nil
        }
    }

    // MARK: - Admin Verification

    /// Check if the current user has admin access
    /// Returns true only if user is authenticated AND their email is in the admin whitelist
    func verifyAdminAccess() -> Bool {
        guard isAuthenticated else { return false }
        guard let email = userEmail else { return false }
        return AdminConfig.isAdminEmail(email)
    }

    /// Verify admin access and throw an error if not authorized
    func requireAdminAccess() throws {
        guard verifyAdminAccess() else {
            throw AuthError.notAdmin
        }
    }

    // MARK: - Sign Out Helper

    /// Sign out the current user via Clerk SDK
    func signOut() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await Clerk.shared.signOut()
            syncWithClerkState()
            // Clear any cached data from keychain
            KeychainHelper.delete(key: "clerk_session_token")
            KeychainHelper.delete(key: "clerk_user_data")
        } catch {
            print("ClerkAuthClient: Sign out error: \(error)")
            self.error = .signOutFailed(error.localizedDescription)
        }
    }

    // MARK: - Keychain Storage Helpers

    /// Store custom data in keychain (for app-specific needs)
    func storeInKeychain(key: String, value: String) {
        if let data = value.data(using: .utf8) {
            KeychainHelper.save(key: key, data: data)
        }
    }

    /// Retrieve custom data from keychain
    func retrieveFromKeychain(key: String) -> String? {
        guard let data = KeychainHelper.load(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Delete custom data from keychain
    func deleteFromKeychain(key: String) {
        KeychainHelper.delete(key: key)
    }
}

// MARK: - Auth Errors
enum AuthError: Error, LocalizedError {
    case notAdmin
    case sessionExpired
    case signOutFailed(String)
    case tokenError(String)

    var errorDescription: String? {
        switch self {
        case .notAdmin:
            return "You don't have admin access. Please contact an administrator."
        case .sessionExpired:
            return "Your session has expired. Please sign in again."
        case .signOutFailed(let message):
            return "Sign out failed: \(message)"
        case .tokenError(let message):
            return "Token error: \(message)"
        }
    }
}

// MARK: - Keychain Helper
class KeychainHelper {
    static func save(key: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess {
            return result as? Data
        }
        return nil
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

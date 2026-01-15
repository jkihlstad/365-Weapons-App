//
//  ErrorHandling.swift
//  365WeaponsAdmin
//
//  Comprehensive error handling system with unified error types,
//  user-friendly messages, and recovery suggestions.
//

import Foundation
import SwiftUI

// MARK: - Error Severity

/// Defines the severity level of an error for appropriate UI treatment
public enum ErrorSeverity: String, Codable, CaseIterable {
    /// Informational - not really an error, just a notice
    case info
    /// Warning - something might be wrong but operation can continue
    case warning
    /// Error - operation failed but recovery may be possible
    case error
    /// Critical - serious error requiring immediate attention
    case critical

    /// System image name for the severity level
    var iconName: String {
        switch self {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }

    /// Color associated with the severity level
    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .purple
        }
    }

    /// Priority for error handling (higher = more urgent)
    var priority: Int {
        switch self {
        case .info: return 0
        case .warning: return 1
        case .error: return 2
        case .critical: return 3
        }
    }
}

// MARK: - Error Domain

/// Categorizes errors by their source domain
public enum ErrorDomain: String, Codable {
    case network
    case authentication
    case convex
    case openRouter
    case database
    case validation
    case permission
    case storage
    case unknown
}

// MARK: - Recovery Action

/// Defines possible recovery actions for an error
public enum ErrorRecoveryAction: Equatable {
    case retry
    case signIn
    case refresh
    case contactSupport
    case checkConnection
    case updateApp
    case clearCache
    case dismiss
    case custom(String, () -> Void)

    var title: String {
        switch self {
        case .retry: return "Retry"
        case .signIn: return "Sign In"
        case .refresh: return "Refresh"
        case .contactSupport: return "Contact Support"
        case .checkConnection: return "Check Connection"
        case .updateApp: return "Update App"
        case .clearCache: return "Clear Cache"
        case .dismiss: return "Dismiss"
        case .custom(let title, _): return title
        }
    }

    var iconName: String {
        switch self {
        case .retry: return "arrow.clockwise"
        case .signIn: return "person.crop.circle"
        case .refresh: return "arrow.triangle.2.circlepath"
        case .contactSupport: return "envelope"
        case .checkConnection: return "wifi"
        case .updateApp: return "arrow.down.circle"
        case .clearCache: return "trash"
        case .dismiss: return "xmark"
        case .custom: return "gear"
        }
    }

    public static func == (lhs: ErrorRecoveryAction, rhs: ErrorRecoveryAction) -> Bool {
        switch (lhs, rhs) {
        case (.retry, .retry),
             (.signIn, .signIn),
             (.refresh, .refresh),
             (.contactSupport, .contactSupport),
             (.checkConnection, .checkConnection),
             (.updateApp, .updateApp),
             (.clearCache, .clearCache),
             (.dismiss, .dismiss):
            return true
        case (.custom(let lhsTitle, _), .custom(let rhsTitle, _)):
            return lhsTitle == rhsTitle
        default:
            return false
        }
    }
}

// MARK: - AppError

/// Unified error type that encompasses all error types in the application
public enum AppError: Error, LocalizedError, Identifiable {
    public var id: String { localizedDescription }

    // MARK: - Network Errors
    case networkUnavailable
    case networkTimeout
    case networkRequestFailed(statusCode: Int, message: String)
    case invalidURL(String)
    case invalidResponse
    case sslError(String)

    // MARK: - Authentication Errors
    case notAuthenticated
    case sessionExpired
    case invalidCredentials
    case notAuthorized
    case tokenRefreshFailed(String)
    case signOutFailed(String)

    // MARK: - Convex Backend Errors
    case convexQueryFailed(function: String, message: String)
    case convexMutationFailed(function: String, message: String)
    case convexActionFailed(function: String, message: String)
    case convexConnectionLost
    case convexDataNotFound(entity: String)
    case convexServerError(statusCode: Int, message: String)

    // MARK: - OpenRouter AI Errors
    case openRouterNotConfigured
    case openRouterRateLimited(retryAfter: TimeInterval?)
    case openRouterQuotaExceeded
    case openRouterModelUnavailable(model: String)
    case openRouterContentFiltered
    case openRouterAPIError(code: Int, message: String)
    case openRouterStreamingFailed(String)

    // MARK: - Database Errors
    case databaseConnectionFailed(String)
    case databaseQueryFailed(String)
    case databaseWriteFailed(String)
    case dataCorrupted(String)

    // MARK: - Validation Errors
    case validationFailed(field: String, reason: String)
    case invalidInput(String)
    case missingRequiredField(String)
    case formatError(field: String, expected: String)

    // MARK: - Permission Errors
    case permissionDenied(String)
    case adminAccessRequired
    case featureNotAvailable

    // MARK: - Storage Errors
    case storageFull
    case fileNotFound(String)
    case fileAccessDenied(String)
    case cacheError(String)

    // MARK: - General Errors
    case unknown(Error)
    case custom(message: String, suggestion: String?)

    // MARK: - LocalizedError Implementation

    public var errorDescription: String? {
        userMessage
    }

    /// User-friendly error message
    public var userMessage: String {
        switch self {
        // Network
        case .networkUnavailable:
            return "No internet connection available. Please check your network settings."
        case .networkTimeout:
            return "The request timed out. The server may be busy or your connection is slow."
        case .networkRequestFailed(let statusCode, let message):
            return "Request failed (Error \(statusCode)): \(message)"
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .sslError(let message):
            return "Security error: \(message)"

        // Authentication
        case .notAuthenticated:
            return "You need to sign in to access this feature."
        case .sessionExpired:
            return "Your session has expired. Please sign in again."
        case .invalidCredentials:
            return "Invalid email or password. Please try again."
        case .notAuthorized:
            return "You don't have permission to perform this action."
        case .tokenRefreshFailed(let message):
            return "Failed to refresh authentication: \(message)"
        case .signOutFailed(let message):
            return "Failed to sign out: \(message)"

        // Convex
        case .convexQueryFailed(let function, let message):
            return "Failed to load data from \(function): \(message)"
        case .convexMutationFailed(let function, let message):
            return "Failed to save data (\(function)): \(message)"
        case .convexActionFailed(let function, let message):
            return "Action failed (\(function)): \(message)"
        case .convexConnectionLost:
            return "Lost connection to the server. Attempting to reconnect..."
        case .convexDataNotFound(let entity):
            return "\(entity) not found. It may have been deleted."
        case .convexServerError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message)"

        // OpenRouter
        case .openRouterNotConfigured:
            return "AI features are not configured. Please add your API key in Settings."
        case .openRouterRateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "AI service is rate limited. Please try again in \(Int(seconds)) seconds."
            }
            return "AI service is rate limited. Please try again later."
        case .openRouterQuotaExceeded:
            return "AI usage quota exceeded. Please check your OpenRouter account."
        case .openRouterModelUnavailable(let model):
            return "AI model '\(model)' is currently unavailable. Please try a different model."
        case .openRouterContentFiltered:
            return "The AI response was filtered due to content policy."
        case .openRouterAPIError(let code, let message):
            return "AI service error (\(code)): \(message)"
        case .openRouterStreamingFailed(let message):
            return "AI streaming failed: \(message)"

        // Database
        case .databaseConnectionFailed(let message):
            return "Database connection failed: \(message)"
        case .databaseQueryFailed(let message):
            return "Database query failed: \(message)"
        case .databaseWriteFailed(let message):
            return "Failed to save data: \(message)"
        case .dataCorrupted(let message):
            return "Data corruption detected: \(message)"

        // Validation
        case .validationFailed(let field, let reason):
            return "\(field): \(reason)"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .missingRequiredField(let field):
            return "\(field) is required."
        case .formatError(let field, let expected):
            return "\(field) format is invalid. Expected: \(expected)"

        // Permission
        case .permissionDenied(let resource):
            return "Permission denied for \(resource)."
        case .adminAccessRequired:
            return "Admin access is required for this action."
        case .featureNotAvailable:
            return "This feature is not available yet."

        // Storage
        case .storageFull:
            return "Device storage is full. Please free up some space."
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .fileAccessDenied(let path):
            return "Cannot access file: \(path)"
        case .cacheError(let message):
            return "Cache error: \(message)"

        // General
        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        case .custom(let message, _):
            return message
        }
    }

    /// Recovery suggestion for the error
    public var recoverySuggestion: String? {
        switch self {
        // Network
        case .networkUnavailable:
            return "Check your WiFi or cellular connection and try again."
        case .networkTimeout:
            return "Try again later or check if the server is responding."
        case .networkRequestFailed:
            return "Please try again. If the problem persists, contact support."
        case .invalidURL:
            return "Please report this issue to the development team."
        case .invalidResponse:
            return "Try refreshing or contact support if the issue persists."
        case .sslError:
            return "Ensure your device's date and time are correct."

        // Authentication
        case .notAuthenticated, .sessionExpired:
            return "Tap 'Sign In' to authenticate with your admin account."
        case .invalidCredentials:
            return "Double-check your email and password."
        case .notAuthorized:
            return "Contact an administrator to request access."
        case .tokenRefreshFailed:
            return "Try signing out and signing back in."
        case .signOutFailed:
            return "Force close the app and try again."

        // Convex
        case .convexQueryFailed, .convexMutationFailed, .convexActionFailed:
            return "Check your connection and try again."
        case .convexConnectionLost:
            return "The app will automatically reconnect when possible."
        case .convexDataNotFound:
            return "Refresh the page to get the latest data."
        case .convexServerError:
            return "The server may be experiencing issues. Try again later."

        // OpenRouter
        case .openRouterNotConfigured:
            return "Go to Settings > API Keys to configure your OpenRouter API key."
        case .openRouterRateLimited:
            return "Wait a moment before trying again, or upgrade your API plan."
        case .openRouterQuotaExceeded:
            return "Add credits to your OpenRouter account or wait for quota reset."
        case .openRouterModelUnavailable:
            return "Select a different model in Settings."
        case .openRouterContentFiltered:
            return "Try rephrasing your message."
        case .openRouterAPIError, .openRouterStreamingFailed:
            return "Try again or check OpenRouter's status page."

        // Database
        case .databaseConnectionFailed:
            return "Check your connection and database configuration."
        case .databaseQueryFailed, .databaseWriteFailed:
            return "Try again. If the problem persists, contact support."
        case .dataCorrupted:
            return "Try clearing the cache in Settings."

        // Validation
        case .validationFailed, .invalidInput, .missingRequiredField, .formatError:
            return "Please correct the input and try again."

        // Permission
        case .permissionDenied:
            return "Request access from an administrator."
        case .adminAccessRequired:
            return "Only admin users can perform this action."
        case .featureNotAvailable:
            return "This feature will be available in a future update."

        // Storage
        case .storageFull:
            return "Delete unused files or apps to free up storage."
        case .fileNotFound, .fileAccessDenied:
            return "Check that the file exists and you have permission to access it."
        case .cacheError:
            return "Try clearing the cache in Settings."

        // General
        case .unknown:
            return "Try restarting the app. If the problem persists, contact support."
        case .custom(_, let suggestion):
            return suggestion
        }
    }

    /// Severity level of the error
    public var severity: ErrorSeverity {
        switch self {
        // Info level
        case .featureNotAvailable:
            return .info

        // Warning level
        case .networkTimeout,
             .convexConnectionLost,
             .openRouterRateLimited,
             .validationFailed,
             .invalidInput,
             .missingRequiredField,
             .formatError:
            return .warning

        // Error level
        case .networkUnavailable,
             .networkRequestFailed,
             .invalidResponse,
             .notAuthenticated,
             .sessionExpired,
             .invalidCredentials,
             .notAuthorized,
             .convexQueryFailed,
             .convexMutationFailed,
             .convexActionFailed,
             .convexDataNotFound,
             .openRouterNotConfigured,
             .openRouterModelUnavailable,
             .openRouterContentFiltered,
             .openRouterAPIError,
             .openRouterStreamingFailed,
             .databaseConnectionFailed,
             .databaseQueryFailed,
             .databaseWriteFailed,
             .permissionDenied,
             .fileNotFound,
             .fileAccessDenied,
             .cacheError,
             .custom:
            return .error

        // Critical level
        case .invalidURL,
             .sslError,
             .tokenRefreshFailed,
             .signOutFailed,
             .convexServerError,
             .openRouterQuotaExceeded,
             .dataCorrupted,
             .adminAccessRequired,
             .storageFull,
             .unknown:
            return .critical
        }
    }

    /// Domain of the error
    public var domain: ErrorDomain {
        switch self {
        case .networkUnavailable, .networkTimeout, .networkRequestFailed,
             .invalidURL, .invalidResponse, .sslError:
            return .network

        case .notAuthenticated, .sessionExpired, .invalidCredentials,
             .notAuthorized, .tokenRefreshFailed, .signOutFailed:
            return .authentication

        case .convexQueryFailed, .convexMutationFailed, .convexActionFailed,
             .convexConnectionLost, .convexDataNotFound, .convexServerError:
            return .convex

        case .openRouterNotConfigured, .openRouterRateLimited, .openRouterQuotaExceeded,
             .openRouterModelUnavailable, .openRouterContentFiltered, .openRouterAPIError,
             .openRouterStreamingFailed:
            return .openRouter

        case .databaseConnectionFailed, .databaseQueryFailed, .databaseWriteFailed,
             .dataCorrupted:
            return .database

        case .validationFailed, .invalidInput, .missingRequiredField, .formatError:
            return .validation

        case .permissionDenied, .adminAccessRequired, .featureNotAvailable:
            return .permission

        case .storageFull, .fileNotFound, .fileAccessDenied, .cacheError:
            return .storage

        case .unknown, .custom:
            return .unknown
        }
    }

    /// Whether the error is recoverable through retry
    public var isRetryable: Bool {
        switch self {
        case .networkUnavailable,
             .networkTimeout,
             .convexConnectionLost,
             .convexServerError,
             .openRouterRateLimited:
            return true
        case .networkRequestFailed(let statusCode, _) where statusCode >= 500:
            return true
        case .openRouterAPIError(let code, _) where code >= 500:
            return true
        default:
            return false
        }
    }

    /// Suggested recovery actions for this error
    public var recoveryActions: [ErrorRecoveryAction] {
        switch self {
        // Network errors
        case .networkUnavailable:
            return [.checkConnection, .retry, .dismiss]
        case .networkTimeout, .networkRequestFailed:
            return [.retry, .dismiss]
        case .invalidResponse, .sslError:
            return [.refresh, .contactSupport]

        // Auth errors
        case .notAuthenticated, .sessionExpired, .invalidCredentials:
            return [.signIn, .dismiss]
        case .notAuthorized, .adminAccessRequired:
            return [.contactSupport, .dismiss]
        case .tokenRefreshFailed, .signOutFailed:
            return [.signIn, .dismiss]

        // Convex errors
        case .convexQueryFailed, .convexMutationFailed, .convexActionFailed:
            return [.retry, .refresh, .dismiss]
        case .convexConnectionLost:
            return [.retry, .checkConnection]
        case .convexDataNotFound:
            return [.refresh, .dismiss]
        case .convexServerError:
            return [.retry, .contactSupport]

        // OpenRouter errors
        case .openRouterNotConfigured:
            return [.dismiss]
        case .openRouterRateLimited:
            return [.retry, .dismiss]
        case .openRouterQuotaExceeded:
            return [.contactSupport, .dismiss]
        case .openRouterModelUnavailable, .openRouterContentFiltered,
             .openRouterAPIError, .openRouterStreamingFailed:
            return [.retry, .dismiss]

        // Database errors
        case .databaseConnectionFailed, .databaseQueryFailed, .databaseWriteFailed:
            return [.retry, .contactSupport]
        case .dataCorrupted:
            return [.clearCache, .contactSupport]

        // Validation errors
        case .validationFailed, .invalidInput, .missingRequiredField, .formatError:
            return [.dismiss]

        // Permission errors
        case .permissionDenied, .featureNotAvailable:
            return [.dismiss]

        // Storage errors
        case .storageFull:
            return [.dismiss]
        case .fileNotFound, .fileAccessDenied:
            return [.refresh, .dismiss]
        case .cacheError:
            return [.clearCache, .dismiss]

        // General
        case .unknown, .custom:
            return [.retry, .dismiss]
        case .invalidURL:
            return [.contactSupport]
        }
    }

    /// Technical details for logging purposes
    public var technicalDescription: String {
        switch self {
        case .networkRequestFailed(let statusCode, let message):
            return "HTTP \(statusCode): \(message)"
        case .convexQueryFailed(let function, let message):
            return "Convex query '\(function)' failed: \(message)"
        case .convexMutationFailed(let function, let message):
            return "Convex mutation '\(function)' failed: \(message)"
        case .convexActionFailed(let function, let message):
            return "Convex action '\(function)' failed: \(message)"
        case .convexServerError(let statusCode, let message):
            return "Convex server error \(statusCode): \(message)"
        case .openRouterAPIError(let code, let message):
            return "OpenRouter API error \(code): \(message)"
        case .unknown(let error):
            return "Unknown error: \(String(describing: error))"
        default:
            return userMessage
        }
    }
}

// MARK: - Error Conversion Extensions

extension AppError {

    /// Create an AppError from a ConvexError
    static func from(_ convexError: ConvexError) -> AppError {
        switch convexError {
        case .invalidResponse:
            return .invalidResponse
        case .noData:
            return .convexDataNotFound(entity: "Data")
        case .queryError(let message):
            return .convexQueryFailed(function: "query", message: message)
        case .mutationError(let message):
            return .convexMutationFailed(function: "mutation", message: message)
        case .serverError(let statusCode, let message):
            return .convexServerError(statusCode: statusCode, message: message)
        case .encodingError:
            return .invalidInput("Failed to encode request data")
        }
    }

    /// Create an AppError from an OpenRouterError
    static func from(_ openRouterError: OpenRouterError) -> AppError {
        switch openRouterError {
        case .notConfigured:
            return .openRouterNotConfigured
        case .invalidResponse:
            return .invalidResponse
        case .noContent:
            return .openRouterContentFiltered
        case .apiError(let code, let message):
            if code == 429 {
                return .openRouterRateLimited(retryAfter: nil)
            } else if code == 402 {
                return .openRouterQuotaExceeded
            }
            return .openRouterAPIError(code: code, message: message)
        case .streamingError(let message):
            return .openRouterStreamingFailed(message)
        }
    }

    /// Create an AppError from an AuthError
    static func from(_ authError: AuthError) -> AppError {
        switch authError {
        case .notAdmin:
            return .adminAccessRequired
        case .sessionExpired:
            return .sessionExpired
        case .signOutFailed(let message):
            return .signOutFailed(message)
        case .tokenError(let message):
            return .tokenRefreshFailed(message)
        }
    }

    /// Create an AppError from any Error
    static func from(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        } else if let convexError = error as? ConvexError {
            return from(convexError)
        } else if let openRouterError = error as? OpenRouterError {
            return from(openRouterError)
        } else if let authError = error as? AuthError {
            return from(authError)
        } else if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkUnavailable
            case .timedOut:
                return .networkTimeout
            case .badURL:
                return .invalidURL(urlError.localizedDescription)
            case .secureConnectionFailed:
                return .sslError(urlError.localizedDescription)
            default:
                return .networkRequestFailed(statusCode: urlError.errorCode, message: urlError.localizedDescription)
            }
        } else {
            return .unknown(error)
        }
    }
}

// MARK: - ErrorWrapper for Published Properties

/// Wrapper for holding an error with additional context
public struct ErrorWrapper: Identifiable, Equatable {
    public let id = UUID()
    public let error: AppError
    public let timestamp: Date
    public let context: String?

    public init(error: AppError, context: String? = nil) {
        self.error = error
        self.timestamp = Date()
        self.context = context
    }

    public static func == (lhs: ErrorWrapper, rhs: ErrorWrapper) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Retry Configuration

/// Configuration for retry behavior
public struct RetryConfiguration {
    /// Maximum number of retry attempts
    public let maxAttempts: Int
    /// Base delay between retries (in seconds)
    public let baseDelay: TimeInterval
    /// Maximum delay between retries (in seconds)
    public let maxDelay: TimeInterval
    /// Whether to use exponential backoff
    public let exponentialBackoff: Bool
    /// Jitter factor for randomizing delay (0-1)
    public let jitter: Double

    public static let `default` = RetryConfiguration(
        maxAttempts: 3,
        baseDelay: 1.0,
        maxDelay: 30.0,
        exponentialBackoff: true,
        jitter: 0.2
    )

    public static let aggressive = RetryConfiguration(
        maxAttempts: 5,
        baseDelay: 0.5,
        maxDelay: 60.0,
        exponentialBackoff: true,
        jitter: 0.3
    )

    public static let conservative = RetryConfiguration(
        maxAttempts: 2,
        baseDelay: 2.0,
        maxDelay: 10.0,
        exponentialBackoff: false,
        jitter: 0.1
    )

    public init(
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0,
        exponentialBackoff: Bool = true,
        jitter: Double = 0.2
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.exponentialBackoff = exponentialBackoff
        self.jitter = jitter
    }

    /// Calculate the delay for a given attempt number
    public func delay(for attempt: Int) -> TimeInterval {
        var delay: TimeInterval

        if exponentialBackoff {
            delay = baseDelay * pow(2.0, Double(attempt - 1))
        } else {
            delay = baseDelay
        }

        delay = min(delay, maxDelay)

        // Add jitter
        let jitterAmount = delay * jitter * Double.random(in: -1...1)
        delay += jitterAmount

        return max(0, delay)
    }
}

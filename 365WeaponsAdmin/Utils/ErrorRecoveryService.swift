//
//  ErrorRecoveryService.swift
//  365WeaponsAdmin
//
//  Global error handling and recovery service. Provides centralized
//  error management, retry logic, logging, and alert suppression.
//

import Foundation
import SwiftUI
import Combine

// MARK: - ErrorRecoveryService

/// Singleton service for handling errors globally throughout the application
@MainActor
public final class ErrorRecoveryService: ObservableObject {

    // MARK: - Singleton

    public static let shared = ErrorRecoveryService()

    // MARK: - Published Properties

    /// The current error to display (if any)
    @Published public private(set) var currentError: ErrorWrapper?

    /// Stack of errors for handling multiple errors
    @Published public private(set) var errorStack: [ErrorWrapper] = []

    /// Whether an error alert should be shown
    @Published public var showError: Bool = false

    /// Whether error handling is currently in progress
    @Published public private(set) var isHandling: Bool = false

    /// Recent error history for debugging
    @Published public private(set) var errorHistory: [ErrorWrapper] = []

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var errorCounts: [String: (count: Int, firstOccurrence: Date)] = [:]
    private var lastErrorTime: Date?
    private var suppressedErrorTypes: Set<String> = []

    /// Minimum time between showing the same error type (seconds)
    private let errorCooldownPeriod: TimeInterval = 5.0

    /// Maximum errors per type before suppression
    private let maxErrorsBeforeSuppression: Int = 3

    /// Time window for error aggregation (seconds)
    private let errorAggregationWindow: TimeInterval = 60.0

    /// Maximum history size
    private let maxHistorySize: Int = 100

    // MARK: - Debug Logger Reference

    private var logger: DebugLogger {
        DebugLogger.shared
    }

    // MARK: - Initialization

    private init() {
        setupErrorCleanup()
    }

    // MARK: - Public Methods

    /// Handle an error with optional context
    /// - Parameters:
    ///   - error: The error to handle
    ///   - context: Optional context describing where the error occurred
    ///   - showAlert: Whether to show an alert to the user
    public func handleError(_ error: Error, context: String? = nil, showAlert: Bool = true) {
        let appError = AppError.from(error)
        let wrapper = ErrorWrapper(error: appError, context: context)

        // Log the error
        logError(wrapper)

        // Add to history
        addToHistory(wrapper)

        // Check if we should show this error
        guard shouldShowError(appError) else {
            logger.log("Error suppressed (rate limited): \(appError.userMessage)", category: .general, level: .warning)
            return
        }

        // Update error counts
        updateErrorCount(for: appError)

        if showAlert {
            // Add to error stack
            errorStack.append(wrapper)

            // Show the most recent error
            if currentError == nil {
                showNextError()
            }
        }
    }

    /// Handle an AppError directly
    public func handleError(_ appError: AppError, context: String? = nil, showAlert: Bool = true) {
        let wrapper = ErrorWrapper(error: appError, context: context)

        logError(wrapper)
        addToHistory(wrapper)

        guard shouldShowError(appError) else {
            logger.log("Error suppressed (rate limited): \(appError.userMessage)", category: .general, level: .warning)
            return
        }

        updateErrorCount(for: appError)

        if showAlert {
            errorStack.append(wrapper)

            if currentError == nil {
                showNextError()
            }
        }
    }

    /// Show an error alert to the user
    /// - Parameter error: The error to display
    public func showErrorAlert(_ error: AppError) {
        let wrapper = ErrorWrapper(error: error)
        currentError = wrapper
        showError = true
        logError(wrapper)
    }

    /// Log an error for debugging purposes
    /// - Parameter wrapper: The error wrapper to log
    public func logError(_ wrapper: ErrorWrapper) {
        let error = wrapper.error
        let contextString = wrapper.context.map { " [Context: \($0)]" } ?? ""
        let message = "\(error.technicalDescription)\(contextString)"

        let level: DebugLevel
        switch error.severity {
        case .info:
            level = .info
        case .warning:
            level = .warning
        case .error, .critical:
            level = .error
        }

        let category: DebugCategory
        switch error.domain {
        case .network:
            category = .network
        case .convex:
            category = .convex
        case .openRouter:
            category = .openRouter
        case .authentication:
            category = .clerk
        default:
            category = .general
        }

        logger.log(message, category: category, level: level)
    }

    /// Attempt automatic recovery for an error
    /// - Parameters:
    ///   - error: The error to recover from
    ///   - retryAction: The action to retry on recovery
    /// - Returns: Whether recovery was successful
    @discardableResult
    public func attemptRecovery(for error: AppError, retryAction: (() async throws -> Void)? = nil) async -> Bool {
        isHandling = true
        defer { isHandling = false }

        logger.log("Attempting recovery for: \(error.userMessage)", category: .general, level: .info)

        // Check if error is retryable
        guard error.isRetryable else {
            logger.log("Error is not retryable", category: .general, level: .warning)
            return false
        }

        // Perform automatic recovery based on error type
        switch error {
        case .networkUnavailable:
            // Wait for network to become available
            return await waitForNetwork(timeout: 10)

        case .sessionExpired, .tokenRefreshFailed:
            // Attempt to refresh authentication
            return await attemptAuthRefresh()

        case .convexConnectionLost:
            // Attempt to reconnect
            return await attemptConvexReconnect()

        case .openRouterRateLimited(let retryAfter):
            // Wait for rate limit to clear
            if let delay = retryAfter {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return true
            }
            return false

        default:
            // For other errors, try the retry action if provided
            if let action = retryAction {
                do {
                    try await action()
                    logger.success("Recovery successful via retry action", category: .general)
                    return true
                } catch {
                    logger.error("Recovery failed: \(error.localizedDescription)", category: .general)
                    return false
                }
            }
            return false
        }
    }

    /// Execute an operation with automatic retry
    /// - Parameters:
    ///   - config: Retry configuration
    ///   - context: Context for error logging
    ///   - operation: The operation to execute
    /// - Returns: The result of the operation
    public func withRetry<T>(
        config: RetryConfiguration = .default,
        context: String? = nil,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 1...config.maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                let appError = AppError.from(error)

                // Log the attempt
                logger.warning(
                    "Attempt \(attempt)/\(config.maxAttempts) failed: \(appError.userMessage)",
                    category: .network
                )

                // Check if error is retryable
                guard appError.isRetryable && attempt < config.maxAttempts else {
                    break
                }

                // Calculate delay
                let delay = config.delay(for: attempt)
                logger.log("Retrying in \(String(format: "%.1f", delay)) seconds...", category: .network)

                // Wait before retry
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        // All attempts failed
        let finalError = AppError.from(lastError ?? AppError.unknown(NSError(domain: "Retry", code: -1)))
        handleError(finalError, context: context, showAlert: true)
        throw finalError
    }

    /// Dismiss the current error
    public func dismissCurrentError() {
        currentError = nil
        showError = false
        showNextError()
    }

    /// Dismiss all errors
    public func dismissAllErrors() {
        errorStack.removeAll()
        currentError = nil
        showError = false
    }

    /// Clear error history
    public func clearHistory() {
        errorHistory.removeAll()
        errorCounts.removeAll()
    }

    /// Suppress a specific error type temporarily
    /// - Parameter errorType: The error type to suppress
    public func suppressErrorType(_ errorType: String) {
        suppressedErrorTypes.insert(errorType)

        // Auto-remove suppression after 5 minutes
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000_000)
            await MainActor.run {
                suppressedErrorTypes.remove(errorType)
            }
        }
    }

    /// Reset suppression for all error types
    public func resetSuppression() {
        suppressedErrorTypes.removeAll()
        errorCounts.removeAll()
    }

    // MARK: - Private Methods

    private func setupErrorCleanup() {
        // Periodically clean up old error counts
        Timer.publish(every: errorAggregationWindow, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.cleanupErrorCounts()
            }
            .store(in: &cancellables)
    }

    private func showNextError() {
        guard !errorStack.isEmpty else {
            showError = false
            return
        }

        // Sort by severity (highest first)
        errorStack.sort { $0.error.severity.priority > $1.error.severity.priority }

        currentError = errorStack.removeFirst()
        showError = true
    }

    private func shouldShowError(_ error: AppError) -> Bool {
        let errorKey = String(describing: error)

        // Check if error type is suppressed
        if suppressedErrorTypes.contains(errorKey) {
            return false
        }

        // Check cooldown period
        if let lastTime = lastErrorTime,
           Date().timeIntervalSince(lastTime) < errorCooldownPeriod {
            // Check if it's the same error type
            if let current = currentError, current.error.userMessage == error.userMessage {
                return false
            }
        }

        // Check if error has occurred too many times
        if let (count, firstOccurrence) = errorCounts[errorKey] {
            let timeSinceFirst = Date().timeIntervalSince(firstOccurrence)

            if count >= maxErrorsBeforeSuppression && timeSinceFirst < errorAggregationWindow {
                // Auto-suppress this error type
                suppressErrorType(errorKey)
                logger.warning("Auto-suppressing error type: \(errorKey) (occurred \(count) times)", category: .general)
                return false
            }
        }

        return true
    }

    private func updateErrorCount(for error: AppError) {
        let errorKey = String(describing: error)
        let now = Date()

        if var existing = errorCounts[errorKey] {
            existing.count += 1
            errorCounts[errorKey] = existing
        } else {
            errorCounts[errorKey] = (count: 1, firstOccurrence: now)
        }

        lastErrorTime = now
    }

    private func cleanupErrorCounts() {
        let now = Date()
        errorCounts = errorCounts.filter { _, value in
            now.timeIntervalSince(value.firstOccurrence) < errorAggregationWindow
        }
    }

    private func addToHistory(_ wrapper: ErrorWrapper) {
        errorHistory.append(wrapper)

        // Trim history if needed
        if errorHistory.count > maxHistorySize {
            errorHistory.removeFirst(errorHistory.count - maxHistorySize)
        }
    }

    // MARK: - Recovery Helpers

    private func waitForNetwork(timeout: TimeInterval) async -> Bool {
        // Simple polling for network availability
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeout {
            // Check network reachability (simplified)
            let url = URL(string: "https://www.apple.com")!
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 5

            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    logger.success("Network recovered", category: .network)
                    return true
                }
            } catch {
                // Network still unavailable
            }

            try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
        }

        logger.error("Network recovery timeout", category: .network)
        return false
    }

    private func attemptAuthRefresh() async -> Bool {
        // Attempt to refresh the auth token
        if let token = await ClerkAuthClient.shared.getAuthToken() {
            ConvexClient.shared.setAuthToken(token)
            logger.success("Auth token refreshed successfully", category: .clerk)
            return true
        }

        logger.error("Auth refresh failed", category: .clerk)
        return false
    }

    private func attemptConvexReconnect() async -> Bool {
        // Simple reconnection attempt
        do {
            // Try a simple query to test connection
            let _: [String] = try await ConvexClient.shared.query("test:ping")
            logger.success("Convex reconnection successful", category: .convex)
            return true
        } catch {
            logger.error("Convex reconnection failed: \(error.localizedDescription)", category: .convex)
            return false
        }
    }
}

// MARK: - Error Handling View Extensions

extension View {

    /// Attaches the global error alert handler to a view
    public func withErrorHandling() -> some View {
        modifier(ErrorHandlingModifier())
    }
}

// MARK: - ErrorHandlingModifier

/// View modifier that attaches global error handling to any view
struct ErrorHandlingModifier: ViewModifier {
    @StateObject private var errorService = ErrorRecoveryService.shared

    func body(content: Content) -> some View {
        content
            .alert(
                errorService.currentError?.error.severity == .critical ? "Critical Error" : "Error",
                isPresented: $errorService.showError,
                presenting: errorService.currentError
            ) { wrapper in
                ForEach(Array(wrapper.error.recoveryActions.prefix(3).enumerated()), id: \.offset) { _, action in
                    Button(action.title) {
                        performRecoveryAction(action, for: wrapper.error)
                    }
                }
            } message: { wrapper in
                VStack {
                    Text(wrapper.error.userMessage)
                    if let suggestion = wrapper.error.recoverySuggestion {
                        Text(suggestion)
                            .font(.caption)
                    }
                }
            }
    }

    private func performRecoveryAction(_ action: ErrorRecoveryAction, for error: AppError) {
        switch action {
        case .retry:
            Task {
                await errorService.attemptRecovery(for: error)
            }
        case .dismiss:
            errorService.dismissCurrentError()
        case .signIn:
            // Navigate to sign in - would need to integrate with app navigation
            errorService.dismissCurrentError()
        case .refresh:
            // Post notification for refresh
            NotificationCenter.default.post(name: .errorRecoveryRefresh, object: nil)
            errorService.dismissCurrentError()
        case .checkConnection:
            // Open settings
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
            errorService.dismissCurrentError()
        case .contactSupport:
            // Open support email
            if let url = URL(string: "mailto:support@365weapons.com") {
                UIApplication.shared.open(url)
            }
            errorService.dismissCurrentError()
        case .clearCache:
            // Clear caches
            URLCache.shared.removeAllCachedResponses()
            errorService.dismissCurrentError()
        case .updateApp:
            // Open App Store
            if let url = URL(string: "https://apps.apple.com/app/365weapons-admin") {
                UIApplication.shared.open(url)
            }
            errorService.dismissCurrentError()
        case .custom(_, let handler):
            handler()
            errorService.dismissCurrentError()
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let errorRecoveryRefresh = Notification.Name("errorRecoveryRefresh")
    static let errorOccurred = Notification.Name("errorOccurred")
}

// MARK: - Environment Key

private struct ErrorRecoveryServiceKey: EnvironmentKey {
    static let defaultValue = ErrorRecoveryService.shared
}

extension EnvironmentValues {
    var errorService: ErrorRecoveryService {
        get { self[ErrorRecoveryServiceKey.self] }
        set { self[ErrorRecoveryServiceKey.self] = newValue }
    }
}

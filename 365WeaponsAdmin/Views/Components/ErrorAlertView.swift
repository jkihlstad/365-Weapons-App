//
//  ErrorAlertView.swift
//  365WeaponsAdmin
//
//  SwiftUI view modifier and components for displaying error alerts
//  with support for retry actions, dismissal callbacks, and severity-based styling.
//

import SwiftUI

// MARK: - ErrorAlertView

/// A customizable error alert view that displays error information with recovery actions
public struct ErrorAlertView: View {
    let error: AppError
    let onDismiss: (() -> Void)?
    let onRetry: (() -> Void)?

    @State private var showDetails = false

    public init(
        error: AppError,
        onDismiss: (() -> Void)? = nil,
        onRetry: (() -> Void)? = nil
    ) {
        self.error = error
        self.onDismiss = onDismiss
        self.onRetry = onRetry
    }

    public var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: error.severity.iconName)
                .font(.system(size: 48))
                .foregroundColor(error.severity.color)
                .padding(.top, 20)

            // Title
            Text(severityTitle)
                .font(.title2.weight(.bold))
                .foregroundColor(.primary)

            // Error message
            Text(error.userMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Recovery suggestion
            if let suggestion = error.recoverySuggestion {
                Text(suggestion)
                    .font(.callout)
                    .foregroundColor(.secondary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Details section (collapsible)
            if showDetails {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()

                    Group {
                        ErrorDetailRow(label: "Domain", value: error.domain.rawValue.capitalized)
                        ErrorDetailRow(label: "Severity", value: error.severity.rawValue.capitalized)
                        ErrorDetailRow(label: "Retryable", value: error.isRetryable ? "Yes" : "No")

                        Text("Technical Details")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)

                        Text(error.technicalDescription)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(4)
                    }
                }
                .padding(.horizontal)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Show/Hide details button
            Button(action: { withAnimation { showDetails.toggle() } }) {
                HStack(spacing: 4) {
                    Text(showDetails ? "Hide Details" : "Show Details")
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            // Action buttons
            actionButtons
                .padding(.horizontal)
                .padding(.bottom, 20)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: error.severity.color.opacity(0.2), radius: 10, x: 0, y: 5)
    }

    private var severityTitle: String {
        switch error.severity {
        case .info: return "Information"
        case .warning: return "Warning"
        case .error: return "Error"
        case .critical: return "Critical Error"
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Primary action (Retry if available)
            if error.isRetryable, let retry = onRetry {
                Button(action: retry) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Retry")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(error.severity.color)
                    .cornerRadius(12)
                }
            }

            // Secondary actions
            HStack(spacing: 12) {
                ForEach(Array(error.recoveryActions.filter { $0 != .retry && $0 != .dismiss }.prefix(2).enumerated()), id: \.offset) { _, action in
                    RecoveryActionButton(action: action, style: .secondary)
                }
            }

            // Dismiss button
            Button(action: { onDismiss?() }) {
                Text("Dismiss")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - ErrorDetailRow

private struct ErrorDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - RecoveryActionButton

struct RecoveryActionButton: View {
    let action: ErrorRecoveryAction
    let style: ButtonStyle
    var onTap: (() -> Void)?

    enum ButtonStyle {
        case primary
        case secondary
        case tertiary
    }

    var body: some View {
        Button(action: { performAction() }) {
            HStack(spacing: 6) {
                Image(systemName: action.iconName)
                    .font(.system(size: 14))
                Text(action.title)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(backgroundColor)
            .cornerRadius(8)
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return .white
        case .secondary: return .primary
        case .tertiary: return .secondary
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return .orange
        case .secondary: return Color(.systemGray5)
        case .tertiary: return .clear
        }
    }

    private func performAction() {
        if let customAction = onTap {
            customAction()
            return
        }

        switch action {
        case .checkConnection:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        case .contactSupport:
            if let url = URL(string: "mailto:support@365weapons.com") {
                UIApplication.shared.open(url)
            }
        case .custom(_, let handler):
            handler()
        default:
            break
        }
    }
}

// MARK: - Error Alert Modifier

/// View modifier for displaying error alerts
public struct ErrorAlertModifier: ViewModifier {
    @Binding var error: AppError?
    let onRetry: (() -> Void)?

    public func body(content: Content) -> some View {
        content
            .alert(
                alertTitle,
                isPresented: Binding(
                    get: { error != nil },
                    set: { if !$0 { error = nil } }
                ),
                presenting: error
            ) { presentedError in
                if presentedError.isRetryable, let retry = onRetry {
                    Button("Retry", action: retry)
                }
                Button("Dismiss", role: .cancel) {
                    error = nil
                }
            } message: { presentedError in
                VStack {
                    Text(presentedError.userMessage)
                    if let suggestion = presentedError.recoverySuggestion {
                        Text(suggestion)
                            .font(.caption)
                    }
                }
            }
    }

    private var alertTitle: String {
        guard let error = error else { return "Error" }
        switch error.severity {
        case .info: return "Notice"
        case .warning: return "Warning"
        case .error: return "Error"
        case .critical: return "Critical Error"
        }
    }
}

// MARK: - Error Sheet Modifier

/// View modifier for displaying error as a sheet
public struct ErrorSheetModifier: ViewModifier {
    @Binding var error: AppError?
    let onRetry: (() -> Void)?
    let onDismiss: (() -> Void)?

    public func body(content: Content) -> some View {
        content
            .sheet(item: Binding(
                get: { error.map { ErrorWrapper(error: $0) } },
                set: { _ in error = nil }
            )) { wrapper in
                ErrorAlertView(
                    error: wrapper.error,
                    onDismiss: {
                        error = nil
                        onDismiss?()
                    },
                    onRetry: onRetry
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
    }
}

// MARK: - Inline Error View

/// A compact inline error view for displaying errors within content
public struct InlineErrorView: View {
    let error: AppError
    var onRetry: (() -> Void)?
    var onDismiss: (() -> Void)?

    public init(error: AppError, onRetry: (() -> Void)? = nil, onDismiss: (() -> Void)? = nil) {
        self.error = error
        self.onRetry = onRetry
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: error.severity.iconName)
                .font(.title3)
                .foregroundColor(error.severity.color)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(error.userMessage)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                if error.isRetryable, let retry = onRetry {
                    Button(action: retry) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(error.severity.color)
                    }
                }

                if let dismiss = onDismiss {
                    Button(action: dismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(error.severity.color.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(error.severity.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Full Screen Error View

/// A full-screen error view for critical errors
public struct FullScreenErrorView: View {
    let error: AppError
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void

    public init(error: AppError, onRetry: (() -> Void)? = nil, onDismiss: @escaping () -> Void) {
        self.error = error
        self.onRetry = onRetry
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Icon with animation
                ZStack {
                    Circle()
                        .fill(error.severity.color.opacity(0.1))
                        .frame(width: 120, height: 120)

                    Image(systemName: error.severity.iconName)
                        .font(.system(size: 48))
                        .foregroundColor(error.severity.color)
                }

                // Title
                Text(titleText)
                    .font(.title.weight(.bold))
                    .foregroundColor(.primary)

                // Message
                VStack(spacing: 8) {
                    Text(error.userMessage)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    if let suggestion = error.recoverySuggestion {
                        Text(suggestion)
                            .font(.callout)
                            .foregroundColor(.secondary.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                // Actions
                VStack(spacing: 16) {
                    if error.isRetryable, let retry = onRetry {
                        Button(action: retry) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Try Again")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(error.severity.color)
                            .cornerRadius(12)
                        }
                    }

                    Button(action: onDismiss) {
                        Text("Go Back")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }

    private var titleText: String {
        switch error.severity {
        case .info: return "Just so you know"
        case .warning: return "Warning"
        case .error: return "Something went wrong"
        case .critical: return "Critical Error"
        }
    }
}

// MARK: - View Extensions

extension View {

    /// Display an error alert
    /// - Parameters:
    ///   - error: Binding to the error to display
    ///   - onRetry: Optional retry action
    public func errorAlert(_ error: Binding<AppError?>, onRetry: (() -> Void)? = nil) -> some View {
        modifier(ErrorAlertModifier(error: error, onRetry: onRetry))
    }

    /// Display an error as a sheet
    /// - Parameters:
    ///   - error: Binding to the error to display
    ///   - onRetry: Optional retry action
    ///   - onDismiss: Optional dismiss callback
    public func errorSheet(
        _ error: Binding<AppError?>,
        onRetry: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        modifier(ErrorSheetModifier(error: error, onRetry: onRetry, onDismiss: onDismiss))
    }

    /// Display a full-screen error overlay
    /// - Parameters:
    ///   - error: Binding to the error to display
    ///   - onRetry: Optional retry action
    public func errorOverlay(_ error: Binding<AppError?>, onRetry: (() -> Void)? = nil) -> some View {
        ZStack {
            self

            if let appError = error.wrappedValue {
                FullScreenErrorView(
                    error: appError,
                    onRetry: onRetry,
                    onDismiss: { error.wrappedValue = nil }
                )
                .transition(.opacity)
            }
        }
    }
}

// MARK: - Preview

#Preview("Error Alert View") {
    VStack {
        ErrorAlertView(
            error: .networkUnavailable,
            onDismiss: {},
            onRetry: {}
        )
        .padding()
    }
    .background(Color.gray.opacity(0.3))
}

#Preview("Inline Error View") {
    VStack(spacing: 16) {
        InlineErrorView(error: .networkUnavailable, onRetry: {}, onDismiss: {})
        InlineErrorView(error: .openRouterNotConfigured, onDismiss: {})
        InlineErrorView(error: .sessionExpired, onRetry: {}, onDismiss: {})
    }
    .padding()
}

#Preview("Full Screen Error") {
    FullScreenErrorView(
        error: .networkUnavailable,
        onRetry: {},
        onDismiss: {}
    )
}

//
//  ErrorBanner.swift
//  365WeaponsAdmin
//
//  Non-intrusive error banner for displaying persistent errors.
//  Supports expand/collapse for details and can be placed at top or bottom of views.
//

import SwiftUI

// MARK: - ErrorBanner Position

/// Position of the error banner in the view
public enum ErrorBannerPosition {
    case top
    case bottom
}

// MARK: - ErrorBanner Style

/// Visual style of the error banner
public enum ErrorBannerStyle {
    case minimal      // Just icon and message
    case standard     // Icon, message, and action button
    case expanded     // Full details with recovery options

    var showsAction: Bool {
        self != .minimal
    }

    var showsDetails: Bool {
        self == .expanded
    }
}

// MARK: - ErrorBanner

/// A non-intrusive banner for displaying persistent or ongoing errors
public struct ErrorBanner: View {
    let error: AppError
    let position: ErrorBannerPosition
    var onDismiss: (() -> Void)?
    var onRetry: (() -> Void)?
    var onTap: (() -> Void)?

    @State private var isExpanded = false
    @State private var isVisible = true
    @State private var dragOffset: CGFloat = 0

    public init(
        error: AppError,
        position: ErrorBannerPosition = .top,
        onDismiss: (() -> Void)? = nil,
        onRetry: (() -> Void)? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.error = error
        self.position = position
        self.onDismiss = onDismiss
        self.onRetry = onRetry
        self.onTap = onTap
    }

    public var body: some View {
        VStack(spacing: 0) {
            if position == .bottom {
                Spacer(minLength: 0)
            }

            if isVisible {
                bannerContent
                    .offset(y: dragOffset)
                    .gesture(dismissGesture)
                    .transition(bannerTransition)
            }

            if position == .top {
                Spacer(minLength: 0)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isVisible)
    }

    // MARK: - Banner Content

    @ViewBuilder
    private var bannerContent: some View {
        VStack(spacing: 0) {
            // Main banner
            HStack(spacing: 12) {
                // Severity icon
                Image(systemName: error.severity.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(iconColor)

                // Message
                VStack(alignment: .leading, spacing: 2) {
                    Text(error.userMessage)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                        .lineLimit(isExpanded ? nil : 2)

                    if !isExpanded, let suggestion = error.recoverySuggestion {
                        Text(suggestion)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Action buttons
                HStack(spacing: 8) {
                    // Expand/Collapse button
                    Button(action: { withAnimation { isExpanded.toggle() } }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 24, height: 24)
                    }

                    // Dismiss button
                    if onDismiss != nil {
                        Button(action: dismissBanner) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(width: 24, height: 24)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .onTapGesture {
                if let tap = onTap {
                    tap()
                } else {
                    withAnimation { isExpanded.toggle() }
                }
            }

            // Expanded content
            if isExpanded {
                expandedContent
            }
        }
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: shadowColor, radius: 8, x: 0, y: position == .top ? 4 : -4)
        .padding(.horizontal, 16)
        .padding(position == .top ? .top : .bottom, 8)
    }

    // MARK: - Expanded Content

    @ViewBuilder
    private var expandedContent: some View {
        VStack(spacing: 12) {
            Divider()

            // Recovery suggestion
            if let suggestion = error.recoverySuggestion {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb")
                        .font(.caption)
                        .foregroundColor(.orange)

                    Text(suggestion)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()
                }
            }

            // Error details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Domain:")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.secondary)
                    Text(error.domain.rawValue.capitalized)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("Severity:")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.secondary)
                    Text(error.severity.rawValue.capitalized)
                        .font(.caption2)
                        .foregroundColor(error.severity.color)
                }

                if error.isRetryable {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption2)
                        Text("This error can be retried")
                            .font(.caption2)
                    }
                    .foregroundColor(.green)
                }
            }

            // Action buttons
            actionButtons
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Retry button
            if error.isRetryable, let retry = onRetry {
                Button(action: retry) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Retry")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(error.severity.color)
                    .cornerRadius(8)
                }
            }

            // Other recovery actions
            ForEach(Array(error.recoveryActions.filter { $0 != .retry && $0 != .dismiss }.prefix(2).enumerated()), id: \.offset) { _, action in
                Button(action: { performRecoveryAction(action) }) {
                    HStack(spacing: 4) {
                        Image(systemName: action.iconName)
                        Text(action.title)
                    }
                    .font(.caption.weight(.medium))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                }
            }

            Spacer()
        }
    }

    // MARK: - Appearance

    private var iconColor: Color {
        switch error.severity {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .purple
        }
    }

    private var backgroundColor: Color {
        Color(.systemBackground)
    }

    private var borderColor: Color {
        error.severity.color.opacity(0.3)
    }

    private var shadowColor: Color {
        error.severity.color.opacity(0.15)
    }

    private var cornerRadius: CGFloat {
        position == .top ? 12 : 16
    }

    private var bannerTransition: AnyTransition {
        switch position {
        case .top:
            return .asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            )
        case .bottom:
            return .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            )
        }
    }

    // MARK: - Gestures

    private var dismissGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let translation = position == .top ? value.translation.height : -value.translation.height
                if translation < 0 {
                    dragOffset = position == .top ? value.translation.height : -value.translation.height
                }
            }
            .onEnded { value in
                let translation = position == .top ? value.translation.height : -value.translation.height
                if translation < -50 {
                    dismissBanner()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dragOffset = 0
                    }
                }
            }
    }

    // MARK: - Actions

    private func dismissBanner() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isVisible = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss?()
        }
    }

    private func performRecoveryAction(_ action: ErrorRecoveryAction) {
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
        case .signIn:
            // Post notification to navigate to sign in
            NotificationCenter.default.post(name: .errorRecoverySignIn, object: nil)
        case .refresh:
            NotificationCenter.default.post(name: .errorRecoveryRefresh, object: nil)
        default:
            break
        }
    }
}

// MARK: - ErrorBannerContainer

/// A container that can display multiple error banners
public struct ErrorBannerContainer: View {
    @ObservedObject var errorService = ErrorRecoveryService.shared
    let position: ErrorBannerPosition
    var maxBanners: Int = 3

    public init(position: ErrorBannerPosition = .top, maxBanners: Int = 3) {
        self.position = position
        self.maxBanners = maxBanners
    }

    public var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(errorService.errorStack.prefix(maxBanners).enumerated()), id: \.element.id) { index, wrapper in
                ErrorBanner(
                    error: wrapper.error,
                    position: position,
                    onDismiss: {
                        errorService.dismissCurrentError()
                    },
                    onRetry: wrapper.error.isRetryable ? {
                        Task {
                            await errorService.attemptRecovery(for: wrapper.error)
                        }
                    } : nil
                )
                .opacity(1.0 - Double(index) * 0.15)
                .scaleEffect(1.0 - Double(index) * 0.03)
            }
        }
    }
}

// MARK: - Connection Status Banner

/// A specialized banner for connection status
public struct ConnectionStatusBanner: View {
    @ObservedObject var convexClient = ConvexClient.shared
    @State private var showBanner = false

    public var body: some View {
        Group {
            if showBanner && !convexClient.isConnected {
                ErrorBanner(
                    error: .convexConnectionLost,
                    position: .top,
                    onDismiss: { showBanner = false },
                    onRetry: {
                        Task {
                            await ErrorRecoveryService.shared.attemptRecovery(for: .convexConnectionLost)
                        }
                    }
                )
            }
        }
        .onReceive(convexClient.$isConnected) { isConnected in
            withAnimation {
                showBanner = !isConnected
            }
        }
    }
}

// MARK: - Error Banner View Modifier

/// View modifier to attach an error banner to any view
public struct ErrorBannerModifier: ViewModifier {
    @Binding var error: AppError?
    let position: ErrorBannerPosition
    var onRetry: (() -> Void)?

    public func body(content: Content) -> some View {
        ZStack {
            content

            if let appError = error {
                ErrorBanner(
                    error: appError,
                    position: position,
                    onDismiss: { error = nil },
                    onRetry: onRetry
                )
            }
        }
    }
}

// MARK: - View Extension

extension View {

    /// Attach an error banner to the view
    /// - Parameters:
    ///   - error: Binding to the error to display
    ///   - position: Position of the banner (top or bottom)
    ///   - onRetry: Optional retry action
    public func errorBanner(
        _ error: Binding<AppError?>,
        position: ErrorBannerPosition = .top,
        onRetry: (() -> Void)? = nil
    ) -> some View {
        modifier(ErrorBannerModifier(error: error, position: position, onRetry: onRetry))
    }

    /// Attach multiple error banners using the global error service
    public func errorBanners(position: ErrorBannerPosition = .top) -> some View {
        ZStack {
            self
            ErrorBannerContainer(position: position)
        }
    }

    /// Attach a connection status banner
    public func connectionStatusBanner() -> some View {
        ZStack {
            self
            ConnectionStatusBanner()
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let errorRecoverySignIn = Notification.Name("errorRecoverySignIn")
}

// MARK: - Previews

#Preview("Error Banner - Top") {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()

        VStack {
            Text("Main Content")
                .font(.title)
        }
    }
    .overlay(
        ErrorBanner(
            error: .networkUnavailable,
            position: .top,
            onDismiss: {},
            onRetry: {}
        ),
        alignment: .top
    )
}

#Preview("Error Banner - Bottom") {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()

        VStack {
            Text("Main Content")
                .font(.title)
        }
    }
    .overlay(
        ErrorBanner(
            error: .openRouterRateLimited(retryAfter: 30),
            position: .bottom,
            onDismiss: {},
            onRetry: {}
        ),
        alignment: .bottom
    )
}

#Preview("Error Banner - Expanded") {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()

        VStack {
            Text("Main Content")
                .font(.title)
        }
    }
    .overlay(
        ErrorBanner(
            error: .convexServerError(statusCode: 500, message: "Internal server error"),
            position: .top,
            onDismiss: {},
            onRetry: {}
        ),
        alignment: .top
    )
}

#Preview("Multiple Banners") {
    struct PreviewWrapper: View {
        @State var errors: [AppError] = [
            .networkUnavailable,
            .openRouterRateLimited(retryAfter: 30)
        ]

        var body: some View {
            ZStack {
                Color.gray.opacity(0.2)
                    .ignoresSafeArea()

                VStack {
                    Text("Main Content")
                        .font(.title)
                }
            }
            .overlay(
                VStack(spacing: 8) {
                    ForEach(Array(errors.enumerated()), id: \.offset) { index, error in
                        ErrorBanner(
                            error: error,
                            position: .top,
                            onDismiss: { errors.remove(at: index) },
                            onRetry: {}
                        )
                    }
                },
                alignment: .top
            )
        }
    }

    return PreviewWrapper()
}

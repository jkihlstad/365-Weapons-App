//
//  EmptyStateView.swift
//  365WeaponsAdmin
//
//  Empty state placeholder component with customizable appearance.
//

import SwiftUI

// MARK: - EmptyStateView

/// A customizable empty state placeholder view.
///
/// Use this component to display meaningful empty states when content is unavailable.
///
/// Example usage:
/// ```swift
/// EmptyStateView(
///     icon: "cube.box",
///     title: "No Products",
///     subtitle: "You haven't added any products yet.",
///     actionTitle: "Add Product",
///     action: { showAddProduct = true }
/// )
/// ```
struct EmptyStateView: View {
    // MARK: - Properties

    /// SF Symbol name for the icon
    let icon: String

    /// Primary title text
    let title: String

    /// Optional subtitle text
    var subtitle: String? = nil

    /// Optional action button title
    var actionTitle: String? = nil

    /// Optional action callback
    var action: (() -> Void)? = nil

    /// The style of the empty state
    var style: EmptyStateStyle = .standard

    /// Custom icon color (defaults to gray)
    var iconColor: Color = .gray

    // MARK: - Body

    var body: some View {
        VStack(spacing: style.spacing) {
            iconView
            textContent

            if let actionTitle = actionTitle, let action = action {
                actionButton(title: actionTitle, action: action)
            }
        }
        .frame(maxWidth: style.maxWidth)
        .padding(style.padding)
    }

    // MARK: - Private Views

    private var iconView: some View {
        Image(systemName: icon)
            .font(.system(size: style.iconSize))
            .foregroundStyle(
                style.useGradient
                    ? AnyShapeStyle(LinearGradient(
                        colors: [iconColor.opacity(0.6), iconColor.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    : AnyShapeStyle(iconColor.opacity(0.5))
            )
    }

    private var textContent: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(style.titleFont)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(style.subtitleFont)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func actionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.orange)
                .cornerRadius(10)
        }
        .padding(.top, 8)
    }
}

// MARK: - Empty State Style

/// Visual styles for EmptyStateView.
enum EmptyStateStyle {
    /// Standard centered empty state
    case standard
    /// Compact empty state for smaller areas
    case compact
    /// Card-style empty state with background
    case card
    /// Full-screen empty state
    case fullscreen

    var iconSize: CGFloat {
        switch self {
        case .standard: return 60
        case .compact: return 40
        case .card: return 50
        case .fullscreen: return 80
        }
    }

    var titleFont: Font {
        switch self {
        case .standard: return .title3.weight(.medium)
        case .compact: return .subheadline.weight(.medium)
        case .card: return .headline
        case .fullscreen: return .title2.weight(.bold)
        }
    }

    var subtitleFont: Font {
        switch self {
        case .standard: return .subheadline
        case .compact: return .caption
        case .card: return .subheadline
        case .fullscreen: return .body
        }
    }

    var spacing: CGFloat {
        switch self {
        case .standard: return 20
        case .compact: return 12
        case .card: return 16
        case .fullscreen: return 24
        }
    }

    var padding: CGFloat {
        switch self {
        case .standard: return 40
        case .compact: return 20
        case .card: return 24
        case .fullscreen: return 60
        }
    }

    var maxWidth: CGFloat? {
        switch self {
        case .standard: return 280
        case .compact: return 200
        case .card: return nil
        case .fullscreen: return 320
        }
    }

    var useGradient: Bool {
        switch self {
        case .fullscreen: return true
        default: return false
        }
    }
}

// MARK: - Empty State Card

/// An empty state view with a card background.
struct EmptyStateCard: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        EmptyStateView(
            icon: icon,
            title: title,
            subtitle: subtitle,
            actionTitle: actionTitle,
            action: action,
            style: .card
        )
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

// MARK: - No Results View

/// A specialized empty state for search results.
struct NoResultsView: View {
    var searchQuery: String
    var suggestions: [String]? = nil
    var onSuggestionTap: ((String) -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))

            VStack(spacing: 8) {
                Text("No Results")
                    .font(.title3.weight(.medium))
                    .foregroundColor(.white)

                Text("No results found for \"\(searchQuery)\"")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }

            if let suggestions = suggestions, !suggestions.isEmpty {
                VStack(spacing: 12) {
                    Text("Try searching for:")
                        .font(.caption)
                        .foregroundColor(.gray)

                    FlowLayout(spacing: 8) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button(action: { onSuggestionTap?(suggestion) }) {
                                Text(suggestion)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.1))
                                    .foregroundColor(.white)
                                    .cornerRadius(16)
                            }
                        }
                    }
                }
            }
        }
        .padding(40)
    }
}

// MARK: - Error State View

/// A specialized empty state for error conditions.
struct ErrorStateView: View {
    var title: String = "Something went wrong"
    var message: String? = nil
    var retryTitle: String = "Try Again"
    var retryAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.red.opacity(0.8), .orange.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 8) {
                Text(title)
                    .font(.title3.weight(.medium))
                    .foregroundColor(.white)

                if let message = message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
            }

            if let retryAction = retryAction {
                Button(action: retryAction) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text(retryTitle)
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .cornerRadius(10)
                }
            }
        }
        .frame(maxWidth: 280)
        .padding(40)
    }
}

// MARK: - Coming Soon View

/// A specialized empty state for features that are coming soon.
struct ComingSoonView: View {
    let feature: String
    var description: String? = nil
    var icon: String = "sparkles"

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text(feature)
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)

                Text("Coming Soon")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.orange)

                if let description = description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
        }
        .frame(maxWidth: 280)
        .padding(40)
    }
}

// MARK: - Flow Layout

/// A simple flow layout for arranging items that wrap to new lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )

        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var maxHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y += maxHeight + spacing
                    maxHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                maxHeight = max(maxHeight, size.height)
                x += size.width + spacing
            }

            size = CGSize(width: maxWidth, height: y + maxHeight)
        }
    }
}

// MARK: - Preview

#Preview("Empty State Variants") {
    ScrollView {
        VStack(spacing: 32) {
            // Standard empty state
            EmptyStateView(
                icon: "cube.box",
                title: "No Products",
                subtitle: "You haven't added any products yet.",
                actionTitle: "Add Product",
                action: {}
            )
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)

            // Compact empty state
            EmptyStateView(
                icon: "list.clipboard",
                title: "No Orders",
                subtitle: "No orders to display",
                style: .compact
            )
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)

            // Card empty state
            EmptyStateCard(
                icon: "person.2",
                title: "No Partners",
                subtitle: "Partner stores will appear here.",
                actionTitle: "Invite Partner",
                action: {}
            )

            // Error state
            ErrorStateView(
                title: "Failed to Load",
                message: "Please check your connection and try again.",
                retryAction: {}
            )
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)

            // Coming soon
            ComingSoonView(
                feature: "Advanced Analytics",
                description: "Detailed insights and reporting will be available in a future update."
            )
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)

            // No results
            NoResultsView(
                searchQuery: "Glock 19",
                suggestions: ["Glock", "Pistol", "Handgun"],
                onSuggestionTap: { _ in }
            )
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
        .padding()
    }
    .background(Color.black)
}

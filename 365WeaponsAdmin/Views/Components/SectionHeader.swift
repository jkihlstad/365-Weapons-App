//
//  SectionHeader.swift
//  365WeaponsAdmin
//
//  Reusable section header component with optional actions.
//

import SwiftUI

// MARK: - SectionHeader

/// A reusable section header with title, optional "See All" button, and trailing content.
///
/// Example usage:
/// ```swift
/// // Basic header
/// SectionHeader(title: "Recent Orders")
///
/// // With "See All" action
/// SectionHeader(
///     title: "Recent Orders",
///     seeAllAction: { navigateToOrders() }
/// )
///
/// // With custom trailing content
/// SectionHeader(title: "Revenue") {
///     Text("$12,345")
///         .font(.headline)
///         .foregroundColor(.green)
/// }
/// ```
struct SectionHeader<TrailingContent: View>: View {
    // MARK: - Properties

    /// The section title
    let title: String

    /// Optional subtitle
    var subtitle: String? = nil

    /// Optional "See All" button action
    var seeAllAction: (() -> Void)? = nil

    /// Custom text for the "See All" button
    var seeAllText: String = "See All"

    /// The style of the header
    var style: SectionHeaderStyle = .standard

    /// Custom trailing content builder
    @ViewBuilder var trailingContent: () -> TrailingContent

    // MARK: - Initialization

    init(
        title: String,
        subtitle: String? = nil,
        seeAllAction: (() -> Void)? = nil,
        seeAllText: String = "See All",
        style: SectionHeaderStyle = .standard,
        @ViewBuilder trailingContent: @escaping () -> TrailingContent = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.seeAllAction = seeAllAction
        self.seeAllText = seeAllText
        self.style = style
        self.trailingContent = trailingContent
    }

    // MARK: - Body

    var body: some View {
        HStack(alignment: .center) {
            titleSection

            Spacer()

            trailingSection
        }
        .padding(.vertical, style.verticalPadding)
    }

    // MARK: - Private Views

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(style.titleFont)
                .foregroundColor(.white)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(style.subtitleFont)
                    .foregroundColor(.gray)
            }
        }
    }

    @ViewBuilder
    private var trailingSection: some View {
        HStack(spacing: 12) {
            trailingContent()

            if let action = seeAllAction {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(seeAllText)
                            .font(style.actionFont)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Section Header Style

/// Visual styles for SectionHeader.
enum SectionHeaderStyle {
    /// Standard section header
    case standard
    /// Large section header for primary sections
    case large
    /// Compact section header for dense layouts
    case compact

    var titleFont: Font {
        switch self {
        case .standard: return .headline
        case .large: return .title2.weight(.bold)
        case .compact: return .subheadline.weight(.medium)
        }
    }

    var subtitleFont: Font {
        switch self {
        case .standard: return .caption
        case .large: return .subheadline
        case .compact: return .caption2
        }
    }

    var actionFont: Font {
        switch self {
        case .standard: return .caption
        case .large: return .subheadline
        case .compact: return .caption2
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .standard: return 4
        case .large: return 8
        case .compact: return 2
        }
    }
}

// MARK: - Simple Section Header

/// A simplified section header without trailing content builder complexity.
struct SimpleSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var seeAllAction: (() -> Void)? = nil
    var style: SectionHeaderStyle = .standard

    var body: some View {
        SectionHeader(
            title: title,
            subtitle: subtitle,
            seeAllAction: seeAllAction,
            style: style
        )
    }
}

// MARK: - Section Header with Badge

/// A section header with a count badge.
struct BadgedSectionHeader: View {
    let title: String
    let count: Int
    var seeAllAction: (() -> Void)? = nil
    var badgeColor: Color = .orange

    var body: some View {
        SectionHeader(title: title, seeAllAction: seeAllAction) {
            if count > 0 {
                Text("\(count)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(badgeColor)
                    .cornerRadius(10)
            }
        }
    }
}

// MARK: - Section Header with Icon

/// A section header with a leading icon.
struct IconSectionHeader: View {
    let icon: String
    let title: String
    var iconColor: Color = .orange
    var seeAllAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.subheadline)

            SectionHeader(title: title, seeAllAction: seeAllAction)
        }
    }
}

// MARK: - Section Header with Live Indicator

/// A section header with a live/active indicator.
struct LiveSectionHeader: View {
    let title: String
    var isLive: Bool = true
    var seeAllAction: (() -> Void)? = nil

    var body: some View {
        SectionHeader(title: title, seeAllAction: seeAllAction) {
            if isLive {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                        .modifier(PulseAnimationModifier())

                    Text("Live")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

// MARK: - Pulse Animation Modifier

private struct PulseAnimationModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .opacity(isPulsing ? 0.6 : 1.0)
            .animation(
                Animation.easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - Card Section

/// A complete section with header and content in a card.
struct CardSection<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var seeAllAction: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: title,
                subtitle: subtitle,
                seeAllAction: seeAllAction
            )

            content()
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

// MARK: - Preview

#Preview("Section Headers") {
    ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            // Standard header
            SimpleSectionHeader(title: "Recent Orders")

            // Header with See All
            SimpleSectionHeader(
                title: "Top Products",
                seeAllAction: {}
            )

            // Header with subtitle
            SimpleSectionHeader(
                title: "Revenue Overview",
                subtitle: "Last 30 days"
            )

            // Large header
            SimpleSectionHeader(
                title: "Dashboard",
                style: .large
            )

            // Badged header
            BadgedSectionHeader(
                title: "Pending Orders",
                count: 12,
                seeAllAction: {}
            )

            // Icon header
            IconSectionHeader(
                icon: "chart.bar.xaxis",
                title: "Analytics",
                seeAllAction: {}
            )

            // Live header
            LiveSectionHeader(
                title: "Activity Feed",
                seeAllAction: {}
            )

            // Header with custom trailing content
            SectionHeader(title: "Total Revenue") {
                Text("$12,345.00")
                    .font(.headline)
                    .foregroundColor(.green)
            }

            // Card section
            CardSection(title: "Quick Stats", seeAllAction: {}) {
                HStack(spacing: 16) {
                    StatCard(
                        title: "Orders",
                        value: "156",
                        icon: "list.clipboard.fill",
                        color: .blue
                    )
                    StatCard(
                        title: "Revenue",
                        value: "$12K",
                        icon: "dollarsign.circle.fill",
                        color: .green
                    )
                }
            }
        }
        .padding()
    }
    .background(Color.black)
}

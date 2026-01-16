//
//  StatCard.swift
//  365WeaponsAdmin
//
//  Reusable statistics card component with trend indicator and customizable appearance.
//

import SwiftUI

// MARK: - StatCard

/// A reusable statistics card component that displays a metric with optional trend indicator.
///
/// Use this component to display key metrics on dashboards and analytics screens.
///
/// Example usage:
/// ```swift
/// StatCard(
///     title: "Total Revenue",
///     value: "$12,345.00",
///     icon: "dollarsign.circle.fill",
///     color: .green,
///     trend: 12.5,
///     subtitle: "This month"
/// )
/// ```
struct StatCard: View {
    // MARK: - Properties

    @ObservedObject private var appearanceManager = AppearanceManager.shared

    /// The title displayed at the bottom of the card
    let title: String

    /// The main value displayed prominently
    let value: String

    /// SF Symbol name for the icon
    let icon: String

    /// Primary color for the icon and trend indicator
    let color: Color

    /// Optional trend percentage (positive = up, negative = down)
    var trend: Double? = nil

    /// Optional subtitle displayed below the title
    var subtitle: String? = nil

    /// Whether this card represents a "coming soon" feature
    var isComingSoon: Bool = false

    /// Optional tap action
    var action: (() -> Void)? = nil

    // MARK: - Body

    var body: some View {
        Button(action: { action?() }) {
            cardContent
        }
        .buttonStyle(StatCardButtonStyle(hasAction: action != nil))
    }

    // MARK: - Private Views

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            valueSection
        }
        .padding()
        .background(appearanceManager.isDarkMode ? Color.white.opacity(0.05) : Color.white)
        .cornerRadius(16)
    }

    private var headerRow: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isComingSoon ? .gray : color)

            Spacer()

            trendBadge
        }
    }

    @ViewBuilder
    private var trendBadge: some View {
        if isComingSoon {
            ComingSoonBadge()
        } else if let trend = trend {
            TrendBadge(trend: trend)
        }
    }

    private var valueSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title.weight(.bold))
                .foregroundColor(isComingSoon ? .gray : .white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.caption)
                .foregroundColor(.gray)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.7))
            }
        }
    }
}

// MARK: - Trend Badge

/// A badge showing trend direction and percentage.
struct TrendBadge: View {
    let trend: Double

    private var isPositive: Bool { trend >= 0 }
    private var trendColor: Color { isPositive ? .green : .red }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                .font(.caption2)
            Text("\(String(format: "%.1f", abs(trend)))%")
                .font(.caption)
        }
        .foregroundColor(trendColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(trendColor.opacity(0.2))
        .cornerRadius(4)
    }
}

// MARK: - Coming Soon Badge

/// A badge indicating a feature is coming soon.
struct ComingSoonBadge: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared

    var body: some View {
        Text("Soon")
            .font(.caption2)
            .foregroundColor(appearanceManager.isDarkMode ? .orange : .red)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(appearanceManager.isDarkMode ? Color.orange.opacity(0.2) : Color.red.opacity(0.15))
            .cornerRadius(4)
    }
}

// MARK: - Stat Card Button Style

/// Custom button style for StatCard that handles tap effects.
private struct StatCardButtonStyle: ButtonStyle {
    let hasAction: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(hasAction && configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Compact Stat Card

/// A more compact version of StatCard for dense layouts.
struct CompactStatCard: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared

    let title: String
    let value: String
    let icon: String
    let color: Color
    var trend: Double? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(title)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            Spacer()

            if let trend = trend {
                TrendBadge(trend: trend)
            }
        }
        .padding(12)
        .background(appearanceManager.isDarkMode ? Color.white.opacity(0.05) : Color.white)
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview("StatCard - Standard") {
    VStack(spacing: 16) {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(
                title: "Total Revenue",
                value: "$12,345.00",
                icon: "dollarsign.circle.fill",
                color: .green,
                trend: 12.5,
                subtitle: "This month"
            )

            StatCard(
                title: "Total Orders",
                value: "156",
                icon: "list.clipboard.fill",
                color: .blue,
                trend: -3.2
            )

            StatCard(
                title: "Products",
                value: "48",
                icon: "cube.box.fill",
                color: .purple,
                subtitle: "Active items"
            )

            StatCard(
                title: "Partners",
                value: "Coming Soon",
                icon: "person.2.fill",
                color: .orange,
                isComingSoon: true
            )
        }

        CompactStatCard(
            title: "Avg Order Value",
            value: "$79.14",
            icon: "cart.fill",
            color: .orange,
            trend: 5.3
        )
    }
    .padding()
    .background(AppearanceManager.shared.isDarkMode ? Color.black : Color(UIColor.systemGroupedBackground))
}

//
//  StatusBadge.swift
//  365WeaponsAdmin
//
//  Reusable status badge component supporting various status types.
//

import SwiftUI

// MARK: - StatusBadge

/// A reusable badge component for displaying status indicators.
///
/// Supports built-in status types (OrderStatus, CommissionStatus, InquiryStatus)
/// as well as custom status strings with configurable colors.
///
/// Example usage:
/// ```swift
/// // Using OrderStatus
/// StatusBadge(orderStatus: .inProgress)
///
/// // Using custom status
/// StatusBadge(status: "Active", color: .green)
///
/// // Pill style
/// StatusBadge(status: "New", color: .blue, style: .pill)
/// ```
struct StatusBadge: View {
    // MARK: - Properties

    /// The status text to display
    let status: String

    /// The color of the badge
    let color: Color

    /// The visual style of the badge
    var style: BadgeStyle = .standard

    /// The size of the badge
    var size: BadgeSize = .medium

    // MARK: - Initialization

    /// Initialize with a custom status string and color.
    init(status: String, color: Color, style: BadgeStyle = .standard, size: BadgeSize = .medium) {
        self.status = status
        self.color = color
        self.style = style
        self.size = size
    }

    /// Initialize with an OrderStatus.
    init(orderStatus: OrderStatus, style: BadgeStyle = .standard, size: BadgeSize = .medium) {
        self.status = orderStatus.displayName
        self.color = Self.color(for: orderStatus)
        self.style = style
        self.size = size
    }

    /// Initialize with a CommissionStatus.
    init(commissionStatus: CommissionStatus, style: BadgeStyle = .standard, size: BadgeSize = .medium) {
        self.status = commissionStatus.displayName
        self.color = Self.color(for: commissionStatus)
        self.style = style
        self.size = size
    }

    /// Initialize with an InquiryStatus.
    init(inquiryStatus: InquiryStatus, style: BadgeStyle = .standard, size: BadgeSize = .medium) {
        self.status = inquiryStatus.displayName
        self.color = Self.color(for: inquiryStatus)
        self.style = style
        self.size = size
    }

    // MARK: - Body

    var body: some View {
        Text(status)
            .font(size.font)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(style.cornerRadius(for: size))
            .overlay(overlayBorder)
    }

    // MARK: - Private Properties

    private var backgroundColor: Color {
        switch style {
        case .standard, .pill:
            return color.opacity(0.2)
        case .outline:
            return .clear
        case .solid:
            return color
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .standard, .pill, .outline:
            return color
        case .solid:
            return Color.appTextPrimary
        }
    }

    @ViewBuilder
    private var overlayBorder: some View {
        if style == .outline {
            RoundedRectangle(cornerRadius: style.cornerRadius(for: size))
                .stroke(color, lineWidth: 1)
        }
    }

    // MARK: - Static Color Helpers

    /// Returns the appropriate color for an OrderStatus.
    static func color(for status: OrderStatus) -> Color {
        switch status {
        case .pending: return Color.appWarning
        case .awaitingPayment: return Color.appAccent
        case .awaitingShipment: return Color.blue
        case .inProgress: return Color.purple
        case .completed: return Color.appSuccess
        case .cancelled: return Color.appDanger
        }
    }

    /// Returns the appropriate color for a CommissionStatus.
    static func color(for status: CommissionStatus) -> Color {
        switch status {
        case .pending: return Color.appAccent
        case .eligible: return Color.blue
        case .approved: return Color.purple
        case .paid: return Color.appSuccess
        case .voided: return Color.appDanger
        }
    }

    /// Returns the appropriate color for an InquiryStatus.
    static func color(for status: InquiryStatus) -> Color {
        switch status {
        case .new: return Color.blue
        case .reviewed: return Color.purple
        case .quoted: return Color.appAccent
        case .invoiceSent: return Color.appWarning
        case .paid: return Color.teal
        case .inProgress: return Color.indigo
        case .completed: return Color.appSuccess
        case .cancelled: return Color.appDanger
        }
    }
}

// MARK: - Badge Style

/// Visual styles for StatusBadge.
enum BadgeStyle {
    /// Standard filled background with rounded corners
    case standard
    /// Fully rounded (pill-shaped) badge
    case pill
    /// Outline-only badge with transparent background
    case outline
    /// Solid filled badge with white text
    case solid

    func cornerRadius(for size: BadgeSize) -> CGFloat {
        switch self {
        case .standard:
            return 4
        case .pill:
            return size.pillRadius
        case .outline, .solid:
            return 6
        }
    }
}

// MARK: - Badge Size

/// Size variants for StatusBadge.
enum BadgeSize {
    case small
    case medium
    case large

    var font: Font {
        switch self {
        case .small: return .caption2
        case .medium: return .caption
        case .large: return .subheadline
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .small: return 4
        case .medium: return 6
        case .large: return 10
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .small: return 1
        case .medium: return 2
        case .large: return 4
        }
    }

    var pillRadius: CGFloat {
        switch self {
        case .small: return 8
        case .medium: return 10
        case .large: return 14
        }
    }
}

// MARK: - Status Badge with Icon

/// A status badge that includes an icon.
struct IconStatusBadge: View {
    let status: String
    let icon: String
    let color: Color
    var style: BadgeStyle = .standard
    var size: BadgeSize = .medium

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(iconFont)
            Text(status)
                .font(size.font)
        }
        .padding(.horizontal, size.horizontalPadding + 2)
        .padding(.vertical, size.verticalPadding)
        .background(backgroundColor)
        .foregroundColor(foregroundColor)
        .cornerRadius(style.cornerRadius(for: size))
    }

    private var iconFont: Font {
        switch size {
        case .small: return .caption2
        case .medium: return .caption
        case .large: return .subheadline
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .standard, .pill:
            return color.opacity(0.2)
        case .outline:
            return .clear
        case .solid:
            return color
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .standard, .pill, .outline:
            return color
        case .solid:
            return Color.appTextPrimary
        }
    }
}

// MARK: - Status Dot

/// A simple status indicator dot.
struct StatusDot: View {
    let color: Color
    var size: CGFloat = 8
    var isPulsing: Bool = false

    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .scaleEffect(isPulsing && isAnimating ? 1.2 : 1.0)
            .opacity(isPulsing && isAnimating ? 0.6 : 1.0)
            .animation(
                isPulsing
                    ? Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)
                    : .default,
                value: isAnimating
            )
            .onAppear {
                if isPulsing {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Preview

#Preview("StatusBadge - All Variants") {
    ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            // Order Statuses
            VStack(alignment: .leading, spacing: 8) {
                Text("Order Statuses")
                    .font(.headline)
                    .foregroundColor(Color.appTextPrimary)

                HStack(spacing: 8) {
                    ForEach(OrderStatus.allCases, id: \.self) { status in
                        StatusBadge(orderStatus: status)
                    }
                }
            }

            // Commission Statuses
            VStack(alignment: .leading, spacing: 8) {
                Text("Commission Statuses")
                    .font(.headline)
                    .foregroundColor(Color.appTextPrimary)

                HStack(spacing: 8) {
                    ForEach(CommissionStatus.allCases, id: \.self) { status in
                        StatusBadge(commissionStatus: status)
                    }
                }
            }

            // Inquiry Statuses
            VStack(alignment: .leading, spacing: 8) {
                Text("Inquiry Statuses")
                    .font(.headline)
                    .foregroundColor(Color.appTextPrimary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                    ForEach(InquiryStatus.allCases, id: \.self) { status in
                        StatusBadge(inquiryStatus: status, size: .small)
                    }
                }
            }

            // Styles
            VStack(alignment: .leading, spacing: 8) {
                Text("Badge Styles")
                    .font(.headline)
                    .foregroundColor(Color.appTextPrimary)

                HStack(spacing: 8) {
                    StatusBadge(status: "Standard", color: Color.blue, style: .standard)
                    StatusBadge(status: "Pill", color: Color.appSuccess, style: .pill)
                    StatusBadge(status: "Outline", color: Color.appAccent, style: .outline)
                    StatusBadge(status: "Solid", color: Color.purple, style: .solid)
                }
            }

            // Sizes
            VStack(alignment: .leading, spacing: 8) {
                Text("Badge Sizes")
                    .font(.headline)
                    .foregroundColor(Color.appTextPrimary)

                HStack(spacing: 8) {
                    StatusBadge(status: "Small", color: Color.blue, size: .small)
                    StatusBadge(status: "Medium", color: Color.blue, size: .medium)
                    StatusBadge(status: "Large", color: Color.blue, size: .large)
                }
            }

            // Icon Badge
            VStack(alignment: .leading, spacing: 8) {
                Text("Icon Badge")
                    .font(.headline)
                    .foregroundColor(Color.appTextPrimary)

                HStack(spacing: 8) {
                    IconStatusBadge(status: "Active", icon: "checkmark.circle", color: Color.appSuccess)
                    IconStatusBadge(status: "Pending", icon: "clock", color: Color.appAccent)
                    IconStatusBadge(status: "Error", icon: "exclamationmark.triangle", color: Color.appDanger)
                }
            }

            // Status Dot
            VStack(alignment: .leading, spacing: 8) {
                Text("Status Dots")
                    .font(.headline)
                    .foregroundColor(Color.appTextPrimary)

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        StatusDot(color: Color.appSuccess)
                        Text("Online")
                            .font(.caption)
                            .foregroundColor(Color.appTextSecondary)
                    }

                    HStack(spacing: 4) {
                        StatusDot(color: Color.appSuccess, isPulsing: true)
                        Text("Live")
                            .font(.caption)
                            .foregroundColor(Color.appTextSecondary)
                    }

                    HStack(spacing: 4) {
                        StatusDot(color: Color.appDanger)
                        Text("Offline")
                            .font(.caption)
                            .foregroundColor(Color.appTextSecondary)
                    }
                }
            }
        }
        .padding()
    }
    .background(Color.appBackground)
}

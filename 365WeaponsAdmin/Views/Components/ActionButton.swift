//
//  ActionButton.swift
//  365WeaponsAdmin
//
//  Styled action button component with multiple variants.
//

import SwiftUI

// MARK: - ActionButton

/// A styled action button with support for primary, secondary, and destructive variants.
///
/// Example usage:
/// ```swift
/// // Primary button
/// ActionButton(title: "Save Changes", action: saveChanges)
///
/// // Secondary button
/// ActionButton(title: "Cancel", style: .secondary, action: cancel)
///
/// // Destructive button with loading state
/// ActionButton(
///     "Delete",
///     icon: "trash",
///     style: .destructive,
///     isLoading: isDeleting,
///     action: deleteItem
/// )
/// ```
struct ActionButton: View {
    // MARK: - Properties

    /// The button title
    let title: String

    /// Optional SF Symbol icon name
    var icon: String? = nil

    /// The button style variant
    var style: ActionButtonStyle = .primary

    /// The button size
    var size: ActionButtonSize = .medium

    /// Whether the button is in a loading state
    var isLoading: Bool = false

    /// Whether the button is disabled
    var isDisabled: Bool = false

    /// Whether the button should expand to fill available width
    var fullWidth: Bool = true

    /// The action to perform when tapped
    let action: () -> Void

    // MARK: - Body

    var body: some View {
        Button(action: performAction) {
            buttonContent
        }
        .buttonStyle(ActionButtonButtonStyle(
            style: style,
            size: size,
            fullWidth: fullWidth,
            isDisabled: isDisabled || isLoading
        ))
        .disabled(isDisabled || isLoading)
    }

    // MARK: - Private Views

    private var buttonContent: some View {
        HStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: style.loadingTint))
                    .scaleEffect(size.progressScale)
            } else if let icon = icon {
                Image(systemName: icon)
                    .font(size.iconFont)
            }

            if !isLoading || size != .small {
                Text(title)
                    .font(size.font)
            }
        }
        .opacity(isLoading && size == .small ? 0 : 1)
        .overlay {
            if isLoading && size == .small {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: style.loadingTint))
                    .scaleEffect(size.progressScale)
            }
        }
    }

    // MARK: - Private Methods

    private func performAction() {
        guard !isLoading && !isDisabled else { return }
        action()
    }
}

// MARK: - Action Button Style

/// Visual style variants for ActionButton.
enum ActionButtonStyle {
    /// Primary orange filled button
    case primary
    /// Secondary outlined button
    case secondary
    /// Destructive red button
    case destructive
    /// Ghost/text-only button
    case ghost
    /// Subtle background button
    case subtle

    var backgroundColor: Color {
        switch self {
        case .primary: return .orange
        case .secondary: return .clear
        case .destructive: return .red
        case .ghost: return .clear
        case .subtle: return .white.opacity(0.1)
        }
    }

    var foregroundColor: Color {
        switch self {
        case .primary: return .white
        case .secondary: return .orange
        case .destructive: return .white
        case .ghost: return .orange
        case .subtle: return .white
        }
    }

    var borderColor: Color? {
        switch self {
        case .secondary: return .orange
        default: return nil
        }
    }

    var loadingTint: Color {
        switch self {
        case .primary, .destructive: return .white
        case .secondary, .ghost: return .orange
        case .subtle: return .white
        }
    }

    var pressedOpacity: Double {
        switch self {
        case .ghost: return 0.6
        default: return 0.8
        }
    }

    var disabledOpacity: Double {
        return 0.5
    }
}

// MARK: - Action Button Size

/// Size variants for ActionButton.
enum ActionButtonSize {
    case small
    case medium
    case large

    var font: Font {
        switch self {
        case .small: return .subheadline.weight(.medium)
        case .medium: return .body.weight(.medium)
        case .large: return .headline.weight(.semibold)
        }
    }

    var iconFont: Font {
        switch self {
        case .small: return .caption
        case .medium: return .body
        case .large: return .title3
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 20
        case .large: return 24
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .small: return 8
        case .medium: return 14
        case .large: return 18
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .small: return 8
        case .medium: return 12
        case .large: return 14
        }
    }

    var progressScale: CGFloat {
        switch self {
        case .small: return 0.7
        case .medium: return 0.8
        case .large: return 1.0
        }
    }
}

// MARK: - Action Button Button Style

private struct ActionButtonButtonStyle: ButtonStyle {
    let style: ActionButtonStyle
    let size: ActionButtonSize
    let fullWidth: Bool
    let isDisabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(style.backgroundColor)
            .foregroundColor(style.foregroundColor)
            .cornerRadius(size.cornerRadius)
            .overlay {
                if let borderColor = style.borderColor {
                    RoundedRectangle(cornerRadius: size.cornerRadius)
                        .stroke(borderColor, lineWidth: 1.5)
                }
            }
            .opacity(isDisabled ? style.disabledOpacity : (configuration.isPressed ? style.pressedOpacity : 1.0))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Icon Button

/// A button that displays only an icon.
struct IconButton: View {
    let icon: String
    var color: Color = .orange
    var size: CGFloat = 24
    var backgroundColor: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.6))
                .foregroundColor(color)
                .frame(width: size, height: size)
                .background(backgroundColor ?? .clear)
                .cornerRadius(size / 4)
        }
        .buttonStyle(IconButtonStyle())
    }
}

private struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Link Button

/// A text-only button styled as a link.
struct LinkButton: View {
    let title: String
    var icon: String? = nil
    var color: Color = .orange
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.subheadline)
            }
            .foregroundColor(color)
        }
        .buttonStyle(LinkButtonStyle())
    }
}

private struct LinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

// MARK: - Async Action Button

/// An action button that handles async operations automatically.
struct AsyncActionButton: View {
    let title: String
    var icon: String? = nil
    var style: ActionButtonStyle = .primary
    var size: ActionButtonSize = .medium
    var fullWidth: Bool = true
    let action: () async -> Void

    @State private var isLoading = false

    var body: some View {
        ActionButton(
            title: title,
            icon: icon,
            style: style,
            size: size,
            isLoading: isLoading,
            fullWidth: fullWidth
        ) {
            Task {
                isLoading = true
                await action()
                isLoading = false
            }
        }
    }
}

// MARK: - Button Group

/// A group of buttons arranged horizontally or vertically.
struct ButtonGroup<Content: View>: View {
    var axis: Axis = .horizontal
    var spacing: CGFloat = 12
    @ViewBuilder var content: () -> Content

    var body: some View {
        switch axis {
        case .horizontal:
            HStack(spacing: spacing) {
                content()
            }
        case .vertical:
            VStack(spacing: spacing) {
                content()
            }
        }
    }
}

// MARK: - Preview

#Preview("Action Buttons") {
    ScrollView {
        VStack(spacing: 24) {
            // Primary buttons
            VStack(alignment: .leading, spacing: 8) {
                Text("Primary")
                    .font(.headline)
                    .foregroundColor(.white)

                ActionButton(title: "Save Changes", action: {})
                ActionButton(title: "Add Product", icon: "plus", action: {})
                ActionButton(title: "Processing...", isLoading: true, action: {})
                ActionButton(title: "Disabled", isDisabled: true, action: {})
            }

            // Secondary buttons
            VStack(alignment: .leading, spacing: 8) {
                Text("Secondary")
                    .font(.headline)
                    .foregroundColor(.white)

                ActionButton(title: "Cancel", style: .secondary, action: {})
                ActionButton(title: "View Details", icon: "eye", style: .secondary, action: {})
            }

            // Destructive buttons
            VStack(alignment: .leading, spacing: 8) {
                Text("Destructive")
                    .font(.headline)
                    .foregroundColor(.white)

                ActionButton(title: "Delete", icon: "trash", style: .destructive, action: {})
                ActionButton(title: "Deleting...", style: .destructive, isLoading: true, action: {})
            }

            // Other styles
            VStack(alignment: .leading, spacing: 8) {
                Text("Other Styles")
                    .font(.headline)
                    .foregroundColor(.white)

                ActionButton(title: "Ghost Button", style: .ghost, action: {})
                ActionButton(title: "Subtle Button", style: .subtle, action: {})
            }

            // Sizes
            VStack(alignment: .leading, spacing: 8) {
                Text("Sizes")
                    .font(.headline)
                    .foregroundColor(.white)

                ActionButton(title: "Small", size: .small, action: {})
                ActionButton(title: "Medium", size: .medium, action: {})
                ActionButton(title: "Large", size: .large, action: {})
            }

            // Inline buttons
            VStack(alignment: .leading, spacing: 8) {
                Text("Inline Buttons")
                    .font(.headline)
                    .foregroundColor(.white)

                HStack(spacing: 12) {
                    ActionButton(title: "Cancel", style: .secondary, fullWidth: false, action: {})
                    ActionButton(title: "Confirm", fullWidth: false, action: {})
                }
            }

            // Icon buttons
            VStack(alignment: .leading, spacing: 8) {
                Text("Icon Buttons")
                    .font(.headline)
                    .foregroundColor(.white)

                HStack(spacing: 16) {
                    IconButton(icon: "plus", action: {})
                    IconButton(icon: "trash", color: .red, action: {})
                    IconButton(icon: "gearshape", backgroundColor: .white.opacity(0.1), action: {})
                }
            }

            // Link buttons
            VStack(alignment: .leading, spacing: 8) {
                Text("Link Buttons")
                    .font(.headline)
                    .foregroundColor(.white)

                HStack(spacing: 16) {
                    LinkButton(title: "See All", action: {})
                    LinkButton(title: "Learn More", icon: "arrow.right", action: {})
                }
            }

            // Button group
            VStack(alignment: .leading, spacing: 8) {
                Text("Button Group")
                    .font(.headline)
                    .foregroundColor(.white)

                ButtonGroup {
                    ActionButton(title: "Cancel", style: .secondary, action: {})
                    ActionButton(title: "Save", action: {})
                }
            }
        }
        .padding()
    }
    .background(AppearanceManager.shared.isDarkMode ? Color.black : Color(UIColor.systemGroupedBackground))
}

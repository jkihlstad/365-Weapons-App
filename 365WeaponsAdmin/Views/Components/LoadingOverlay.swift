//
//  LoadingOverlay.swift
//  365WeaponsAdmin
//
//  Loading state component with customizable appearance.
//

import SwiftUI

// MARK: - LoadingOverlay

/// A full-screen or inline loading overlay with customizable appearance.
///
/// Use this component to indicate loading states in your views.
///
/// Example usage:
/// ```swift
/// // As an overlay
/// SomeView()
///     .overlay {
///         if isLoading {
///             LoadingOverlay(message: "Loading data...")
///         }
///     }
///
/// // Inline
/// LoadingOverlay(
///     message: "Processing...",
///     style: .inline,
///     showBackground: false
/// )
/// ```
struct LoadingOverlay: View {
    // MARK: - Properties

    @ObservedObject private var appearanceManager = AppearanceManager.shared

    /// Optional message to display below the progress indicator
    var message: String? = nil

    /// The style of the loading overlay
    var style: LoadingStyle = .fullscreen

    /// Whether to show the blur background (fullscreen only)
    var showBackground: Bool = true

    /// The tint color for the progress indicator
    var tintColor: Color = Color.appAccent

    // MARK: - Body

    var body: some View {
        switch style {
        case .fullscreen:
            fullscreenView
        case .card:
            cardView
        case .inline:
            inlineView
        case .minimal:
            minimalView
        }
    }

    // MARK: - Private Views

    private var fullscreenView: some View {
        ZStack {
            if showBackground {
                Color.appBackground.opacity(0.6)
                    .ignoresSafeArea()
                    .background(.ultraThinMaterial)
            }

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: tintColor))
                    .scaleEffect(1.5)

                if let message = message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(Color.appTextPrimary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(32)
            .background(appearanceManager.isDarkMode ? Color.appSurface2 : Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
        }
    }

    private var cardView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: tintColor))
                .scaleEffect(1.2)

            if let message = message {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(appearanceManager.isDarkMode ? Color.appSurface : Color.white)
        .cornerRadius(16)
    }

    private var inlineView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: tintColor))

            if let message = message {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(Color.appTextSecondary)
            }
        }
    }

    private var minimalView: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: tintColor))
    }
}

// MARK: - Loading Style

/// Visual styles for LoadingOverlay.
enum LoadingStyle {
    /// Full-screen overlay with blur background
    case fullscreen
    /// Card-style loading indicator
    case card
    /// Inline horizontal loading indicator
    case inline
    /// Minimal progress view only
    case minimal
}

// MARK: - Loading View Modifier

/// A view modifier that adds a loading overlay.
struct LoadingModifier: ViewModifier {
    let isLoading: Bool
    let message: String?
    let style: LoadingStyle

    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isLoading)

            if isLoading {
                LoadingOverlay(
                    message: message,
                    style: style
                )
            }
        }
    }
}

extension View {
    /// Adds a loading overlay to the view.
    ///
    /// - Parameters:
    ///   - isLoading: Whether the loading overlay should be shown
    ///   - message: Optional message to display
    ///   - style: The style of the loading overlay
    func loading(
        _ isLoading: Bool,
        message: String? = nil,
        style: LoadingStyle = .fullscreen
    ) -> some View {
        modifier(LoadingModifier(isLoading: isLoading, message: message, style: style))
    }
}

// MARK: - Skeleton Loading View

/// A placeholder view that shows a pulsing skeleton loading effect.
struct SkeletonView: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared

    var width: CGFloat? = nil
    var height: CGFloat = 16
    var cornerRadius: CGFloat = 4

    @State private var isAnimating = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.appSurface.opacity(isAnimating ? 0.6 : 0.3))
            .frame(width: width, height: height)
            .animation(
                Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Skeleton Card

/// A skeleton placeholder for card-shaped content.
struct SkeletonCard: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SkeletonView(width: 32, height: 32, cornerRadius: 8)
                Spacer()
                SkeletonView(width: 60, height: 20, cornerRadius: 4)
            }

            SkeletonView(height: 24)
            SkeletonView(width: 120, height: 14)
        }
        .padding()
        .background(appearanceManager.isDarkMode ? Color.appSurface : Color.white)
        .cornerRadius(16)
    }
}

// MARK: - Loading Button Content

/// A view that shows either content or a loading indicator.
struct LoadingButtonContent<Content: View>: View {
    let isLoading: Bool
    let tintColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            content()
                .opacity(isLoading ? 0 : 1)

            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: tintColor))
            }
        }
    }
}

// MARK: - Determinate Progress Overlay

/// A loading overlay with determinate progress indication.
struct DeterminateLoadingOverlay: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared

    let progress: Double
    var message: String? = nil
    var showPercentage: Bool = true
    var tintColor: Color = Color.appAccent

    var body: some View {
        ZStack {
            Color.appBackground.opacity(0.6)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.appSurface, lineWidth: 8)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(tintColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: progress)

                    if showPercentage {
                        Text("\(Int(progress * 100))%")
                            .font(.headline)
                            .foregroundColor(Color.appTextPrimary)
                    }
                }

                if let message = message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(Color.appTextPrimary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(32)
            .background(appearanceManager.isDarkMode ? Color.appSurface2 : Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
        }
    }
}

// MARK: - Preview

#Preview("Loading Overlays") {
    ZStack {
        (AppearanceManager.shared.isDarkMode ? Color.appBackground : Color(UIColor.systemGroupedBackground)).ignoresSafeArea()

        VStack(spacing: 24) {
            Text("Background Content")
                .foregroundColor(Color.appTextPrimary)
        }

        LoadingOverlay(
            message: "Loading dashboard...",
            style: .fullscreen
        )
    }
}

#Preview("Loading Styles") {
    ScrollView {
        VStack(spacing: 24) {
            // Card style
            LoadingOverlay(
                message: "Fetching data...",
                style: .card
            )

            // Inline style
            LoadingOverlay(
                message: "Processing...",
                style: .inline
            )

            // Skeleton loading
            VStack(spacing: 16) {
                Text("Skeleton Loading")
                    .font(.headline)
                    .foregroundColor(Color.appTextPrimary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    SkeletonCard()
                    SkeletonCard()
                }
            }

            // Determinate progress
            DeterminateLoadingOverlay(
                progress: 0.65,
                message: "Uploading..."
            )
            .frame(height: 200)
            .cornerRadius(16)
        }
        .padding()
    }
    .background(AppearanceManager.shared.isDarkMode ? Color.appBackground : Color(UIColor.systemGroupedBackground))
}

//
//  AppearanceManager.swift
//  365WeaponsAdmin
//
//  Manages app appearance (light/dark/system mode) properly using SwiftUI best practices
//

import SwiftUI
import Combine

// MARK: - Appearance Mode

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    /// Returns the ColorScheme to use, or nil for system default
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Appearance Manager

@MainActor
class AppearanceManager: ObservableObject {
    static let shared = AppearanceManager()

    // MARK: - Published Properties

    @Published var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode")
            updateUIKitAppearance()
        }
    }

    // MARK: - Computed Properties

    /// The color scheme to apply, or nil for system
    var preferredColorScheme: ColorScheme? {
        appearanceMode.colorScheme
    }

    /// Whether currently displaying dark mode (considers system setting when in system mode)
    var isDarkMode: Bool {
        switch appearanceMode {
        case .dark:
            return true
        case .light:
            return false
        case .system:
            // Check the current trait collection
            return UITraitCollection.current.userInterfaceStyle == .dark
        }
    }

    // MARK: - Initialization

    private init() {
        // Load saved preference, default to system
        let savedMode = UserDefaults.standard.string(forKey: "appearanceMode") ?? "system"
        self.appearanceMode = AppearanceMode(rawValue: savedMode) ?? .system

        // Set up UIKit navigation bar appearance
        updateUIKitAppearance()

        // Listen for trait collection changes to update isDarkMode when in system mode
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(traitCollectionDidChange),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    // MARK: - UIKit Appearance Setup

    /// Configure UIKit appearances to match theme
    private func updateUIKitAppearance() {
        // Get colors from named assets with fallbacks
        let backgroundColor = UIColor(named: "AppBackground") ?? .systemBackground
        let textColor = UIColor(named: "AppTextPrimary") ?? .label
        let accentColor = UIColor(named: "AppAccent") ?? .orange

        // Navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = backgroundColor
        navBarAppearance.titleTextAttributes = [.foregroundColor: textColor]
        navBarAppearance.largeTitleTextAttributes = [.foregroundColor: textColor]

        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().tintColor = accentColor

        // Tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = backgroundColor

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

        // Table view appearance
        UITableView.appearance().backgroundColor = .clear

        // Force refresh windows
        for scene in UIApplication.shared.connectedScenes {
            if let windowScene = scene as? UIWindowScene {
                for window in windowScene.windows {
                    // Apply the override if not using system
                    if let scheme = appearanceMode.colorScheme {
                        window.overrideUserInterfaceStyle = scheme == .dark ? .dark : .light
                    } else {
                        window.overrideUserInterfaceStyle = .unspecified
                    }
                }
            }
        }
    }

    @objc private func traitCollectionDidChange() {
        // Trigger a refresh when system appearance changes (only matters in system mode)
        if appearanceMode == .system {
            objectWillChange.send()
        }
    }

    // MARK: - Public Methods

    func setMode(_ mode: AppearanceMode) {
        appearanceMode = mode
    }
}

// MARK: - View Modifier for Theme Root

/// Apply this modifier ONLY at the root of the app (WindowGroup)
struct ThemeRootModifier: ViewModifier {
    @ObservedObject var appearanceManager = AppearanceManager.shared

    func body(content: Content) -> some View {
        content
            .preferredColorScheme(appearanceManager.preferredColorScheme)
            .transaction { transaction in
                // Disable animations on color scheme changes to prevent flashing
                transaction.animation = nil
            }
    }
}

extension View {
    /// Apply theme at root level only
    func themeRoot() -> some View {
        modifier(ThemeRootModifier())
    }
}

// MARK: - View Modifier for Screen Background

/// Apply this modifier to every screen's root view
struct ThemedBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.appBackground.ignoresSafeArea())
    }
}

extension View {
    /// Apply themed background to screen
    func themedBackground() -> some View {
        modifier(ThemedBackgroundModifier())
    }
}

// MARK: - View Modifier for Lists

/// Apply this modifier to Lists to fix UIKit bleed-through
struct ThemedListModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
    }
}

extension View {
    /// Apply themed styling to Lists
    func themedList() -> some View {
        modifier(ThemedListModifier())
    }
}

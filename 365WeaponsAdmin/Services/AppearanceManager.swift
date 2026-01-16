//
//  AppearanceManager.swift
//  365WeaponsAdmin
//
//  Manages app appearance (light/dark mode) with auto-switching support
//

import SwiftUI
import Combine

// MARK: - Appearance Mode

enum AppearanceMode: String, CaseIterable, Identifiable {
    case light = "light"
    case dark = "dark"
    case auto = "auto"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .auto: return "Auto"
        }
    }

    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .auto: return "circle.lefthalf.filled"
        }
    }

    var description: String {
        switch self {
        case .light: return "Always use light mode"
        case .dark: return "Always use dark mode"
        case .auto: return "Switch automatically based on time"
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
            updateColorScheme()
        }
    }

    @Published var currentColorScheme: ColorScheme = .dark

    /// Hours for auto mode (24-hour format)
    @Published var autoLightStartHour: Int {
        didSet {
            UserDefaults.standard.set(autoLightStartHour, forKey: "autoLightStartHour")
            updateColorScheme()
        }
    }

    @Published var autoDarkStartHour: Int {
        didSet {
            UserDefaults.standard.set(autoDarkStartHour, forKey: "autoDarkStartHour")
            updateColorScheme()
        }
    }

    // MARK: - Private Properties

    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        // Load saved preferences
        let savedMode = UserDefaults.standard.string(forKey: "appearanceMode") ?? "dark"
        self.appearanceMode = AppearanceMode(rawValue: savedMode) ?? .dark

        // Default: Light mode from 7 AM to 7 PM
        self.autoLightStartHour = UserDefaults.standard.object(forKey: "autoLightStartHour") as? Int ?? 7
        self.autoDarkStartHour = UserDefaults.standard.object(forKey: "autoDarkStartHour") as? Int ?? 19

        // Initial update
        updateColorScheme()

        // Start timer for auto mode checking (every minute)
        startAutoModeTimer()
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Public Methods

    /// Force update the color scheme
    func updateColorScheme() {
        switch appearanceMode {
        case .light:
            currentColorScheme = .light
        case .dark:
            currentColorScheme = .dark
        case .auto:
            currentColorScheme = calculateAutoColorScheme()
        }
    }

    /// Check if currently in dark mode
    var isDarkMode: Bool {
        currentColorScheme == .dark
    }

    // MARK: - Private Methods

    private func calculateAutoColorScheme() -> ColorScheme {
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: Date())

        // Check if current hour falls within light mode hours
        if autoLightStartHour < autoDarkStartHour {
            // Normal case: light during day (e.g., 7 AM to 7 PM)
            if currentHour >= autoLightStartHour && currentHour < autoDarkStartHour {
                return .light
            } else {
                return .dark
            }
        } else {
            // Inverted case: light during night (unlikely but handle it)
            if currentHour >= autoLightStartHour || currentHour < autoDarkStartHour {
                return .light
            } else {
                return .dark
            }
        }
    }

    private func startAutoModeTimer() {
        // Check every minute for auto mode changes
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                if self?.appearanceMode == .auto {
                    self?.updateColorScheme()
                }
            }
        }
    }
}

// MARK: - Theme Colors

struct Theme {
    let colorScheme: ColorScheme

    init(_ colorScheme: ColorScheme) {
        self.colorScheme = colorScheme
    }

    var isDark: Bool {
        colorScheme == .dark
    }

    // MARK: - Background Colors

    var background: Color {
        isDark ? Color.black : Color(UIColor.systemBackground)
    }

    var secondaryBackground: Color {
        isDark ? Color.white.opacity(0.05) : Color(UIColor.secondarySystemBackground)
    }

    var tertiaryBackground: Color {
        isDark ? Color.white.opacity(0.1) : Color(UIColor.tertiarySystemBackground)
    }

    var cardBackground: Color {
        isDark ? Color.white.opacity(0.05) : Color.white
    }

    // MARK: - Text Colors

    var primaryText: Color {
        isDark ? Color.white : Color.black
    }

    var secondaryText: Color {
        isDark ? Color.white.opacity(0.7) : Color(UIColor.secondaryLabel)
    }

    var tertiaryText: Color {
        isDark ? Color.gray : Color(UIColor.tertiaryLabel)
    }

    // MARK: - Accent Colors

    var accent: Color {
        isDark ? .orange : .red
    }

    var accentSecondary: Color {
        isDark ? .red : .orange
    }

    var accentBackground: Color {
        isDark ? Color.orange.opacity(0.2) : Color.red.opacity(0.15)
    }

    // MARK: - Status Colors

    var success: Color {
        .green
    }

    var warning: Color {
        .orange
    }

    var error: Color {
        .red
    }

    var info: Color {
        .blue
    }

    // MARK: - Separator

    var separator: Color {
        isDark ? Color.white.opacity(0.1) : Color(UIColor.separator)
    }

    // MARK: - Form Colors

    var inputBackground: Color {
        isDark ? Color.white.opacity(0.1) : Color(UIColor.secondarySystemBackground)
    }

    var inputBorder: Color {
        isDark ? Color.white.opacity(0.2) : Color(UIColor.separator)
    }

    // MARK: - Navigation Bar

    var navBarBackground: Color {
        isDark ? Color.black : Color(UIColor.systemBackground)
    }

    // MARK: - Tab Bar

    var tabBarBackground: Color {
        isDark ? Color.black.opacity(0.9) : Color(UIColor.systemBackground).opacity(0.9)
    }

    var tabBarSelectedTint: Color {
        accent
    }

    var tabBarUnselectedTint: Color {
        isDark ? .gray : Color(UIColor.secondaryLabel)
    }
}

// MARK: - Environment Key

struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme(.dark)
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    func themed(_ theme: Theme) -> some View {
        self.environment(\.theme, theme)
    }
}

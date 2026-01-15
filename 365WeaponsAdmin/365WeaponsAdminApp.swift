//
//  365WeaponsAdminApp.swift
//  365WeaponsAdmin
//
//  Companion Admin Dashboard for 365Weapons Website
//

import SwiftUI
import Clerk

// MARK: - Legacy API Configuration (for migration only)
// These placeholders are used for initial migration to secure storage
// Do NOT store actual API keys here - use ConfigurationManager instead
struct LegacyAPIConfig {
    // Placeholder values - actual keys should be stored securely via Settings
    static let openRouterAPIKey = ""
    static let openAIAPIKey = ""
    static let clerkPublishableKey = ""
}

@main
struct WeaponsAdminApp: App {
    @StateObject private var orchestrator = OrchestrationAgent.shared
    @StateObject private var appState = AppState.shared
    @StateObject private var configManager = ConfigurationManager.shared
    @State private var clerk = Clerk.shared
    @State private var showSetupSheet = false
    @State private var isInitialized = false

    init() {
        // Initial configuration happens in task modifier after view loads
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isInitialized {
                    ContentView()
                } else {
                    // Show loading screen while initializing
                    ZStack {
                        Color.black.ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(.orange)
                            Text("Initializing...")
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .environment(\.clerk, clerk)
            .environmentObject(orchestrator)
            .environmentObject(appState)
            .environmentObject(configManager)
            .preferredColorScheme(.dark)
            .task {
                await initializeApp()
            }
            .sheet(isPresented: $showSetupSheet) {
                APISetupView(isPresented: $showSetupSheet) {
                    Task {
                        await configureAPIClients()
                        isInitialized = true
                    }
                }
            }
            .onChange(of: configManager.needsFirstRunSetup) { _, needsSetup in
                if needsSetup && isInitialized {
                    showSetupSheet = true
                }
            }
        }
    }

    /// Initializes the application, checking for required configuration
    private func initializeApp() async {
        // Refresh configuration status
        await MainActor.run {
            configManager.refreshStatus()
        }

        // Check if we need first-run setup
        if configManager.needsFirstRunSetup && !configManager.isFullyConfigured {
            showSetupSheet = true
        } else {
            // Configure API clients with stored keys
            await configureAPIClients()
            isInitialized = true
        }
    }

    /// Configures API clients using securely stored keys
    private func configureAPIClients() async {
        // Configure OpenRouter for AI chat
        if let openRouterKey = configManager.openRouterAPIKey {
            OpenRouterClient.shared.configure(apiKey: openRouterKey)
        }

        // Configure OpenAI for Whisper (speech-to-text) and TTS
        if let openAIKey = configManager.openAIAPIKey {
            OpenAIClient.shared.configure(apiKey: openAIKey)
        }

        // Configure Clerk for authentication
        if let clerkKey = configManager.clerkPublishableKey {
            clerk.configure(publishableKey: clerkKey)
            try? await clerk.load()
        }
    }
}

// MARK: - First-Run API Setup View
struct APISetupView: View {
    @Binding var isPresented: Bool
    @StateObject private var configManager = ConfigurationManager.shared

    @State private var openRouterKey = ""
    @State private var openAIKey = ""
    @State private var clerkKey = ""
    @State private var convexURL = ""

    @State private var openRouterError: String?
    @State private var openAIError: String?
    @State private var clerkError: String?
    @State private var convexError: String?

    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""

    var onComplete: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("Configure API Keys")
                            .font(.title.weight(.bold))

                        Text("Enter your API keys to enable all features. Keys are stored securely in the iOS Keychain.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)

                    // API Key Fields
                    VStack(spacing: 20) {
                        // OpenRouter
                        APIKeyInputField(
                            title: "OpenRouter API Key",
                            subtitle: "Required for AI Chat",
                            placeholder: "sk-or-...",
                            text: $openRouterKey,
                            errorMessage: openRouterError,
                            helpURL: URL(string: "https://openrouter.ai/keys")
                        )
                        .onChange(of: openRouterKey) { _, newValue in
                            openRouterError = configManager.validationError(for: newValue, keyType: .openRouter)
                        }

                        // OpenAI
                        APIKeyInputField(
                            title: "OpenAI API Key",
                            subtitle: "Required for Voice Features",
                            placeholder: "sk-...",
                            text: $openAIKey,
                            errorMessage: openAIError,
                            helpURL: URL(string: "https://platform.openai.com/api-keys")
                        )
                        .onChange(of: openAIKey) { _, newValue in
                            openAIError = configManager.validationError(for: newValue, keyType: .openAI)
                        }

                        // Clerk
                        APIKeyInputField(
                            title: "Clerk Publishable Key",
                            subtitle: "Required for Authentication",
                            placeholder: "pk_...",
                            text: $clerkKey,
                            errorMessage: clerkError,
                            helpURL: URL(string: "https://dashboard.clerk.com")
                        )
                        .onChange(of: clerkKey) { _, newValue in
                            clerkError = configManager.validationError(for: newValue, keyType: .clerk)
                        }

                        // Convex (optional)
                        APIKeyInputField(
                            title: "Convex Deployment URL",
                            subtitle: "Optional - Backend Database",
                            placeholder: "https://....convex.cloud",
                            text: $convexURL,
                            errorMessage: convexError,
                            helpURL: URL(string: "https://dashboard.convex.dev"),
                            isOptional: true
                        )
                        .onChange(of: convexURL) { _, newValue in
                            if !newValue.isEmpty {
                                convexError = configManager.validationError(for: newValue, keyType: .convex)
                            } else {
                                convexError = nil
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Save Button
                    Button(action: saveConfiguration) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Save Configuration")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canSave ? Color.orange : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!canSave || isSaving)
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Skip Button (if keys already exist)
                    if configManager.isFullyConfigured {
                        Button("Skip - Use Existing Keys") {
                            configManager.completeFirstRunSetup()
                            isPresented = false
                            onComplete()
                        }
                        .foregroundColor(.gray)
                    }

                    Spacer(minLength: 40)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if configManager.isFullyConfigured {
                        Button("Skip") {
                            configManager.completeFirstRunSetup()
                            isPresented = false
                            onComplete()
                        }
                    }
                }
            }
            .alert("Configuration Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .interactiveDismissDisabled(!configManager.isFullyConfigured)
    }

    private var canSave: Bool {
        let hasRequiredKeys = !openRouterKey.isEmpty && !openAIKey.isEmpty && !clerkKey.isEmpty
        let noErrors = openRouterError == nil && openAIError == nil && clerkError == nil
        let convexValid = convexURL.isEmpty || convexError == nil
        return hasRequiredKeys && noErrors && convexValid
    }

    private func saveConfiguration() {
        isSaving = true

        Task {
            do {
                // Save all keys
                try configManager.setAPIKey(openRouterKey, for: .openRouter)
                try configManager.setAPIKey(openAIKey, for: .openAI)
                try configManager.setAPIKey(clerkKey, for: .clerk)

                if !convexURL.isEmpty {
                    try configManager.setAPIKey(convexURL, for: .convex)
                }

                // Mark setup as complete
                await MainActor.run {
                    configManager.completeFirstRunSetup()
                    isSaving = false
                    isPresented = false
                    onComplete()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - API Key Input Field Component
struct APIKeyInputField: View {
    let title: String
    let subtitle: String
    let placeholder: String
    @Binding var text: String
    let errorMessage: String?
    let helpURL: URL?
    var isOptional: Bool = false

    @State private var isSecure = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                if isOptional {
                    Text("(Optional)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.gray)

            HStack {
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } else {
                    TextField(placeholder, text: $text)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }

                Button(action: { isSecure.toggle() }) {
                    Image(systemName: isSecure ? "eye" : "eye.slash")
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(errorMessage != nil ? Color.red : Color.clear, lineWidth: 1)
            )

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            if let url = helpURL {
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Image(systemName: "questionmark.circle")
                        Text("Get API Key")
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                }
            }
        }
    }
}

// MARK: - App State
class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isAuthenticated: Bool = false
    @Published var currentUser: AdminUser?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false

    private init() {}

    func showError(_ message: String) {
        errorMessage = message
        showError = true
    }
}

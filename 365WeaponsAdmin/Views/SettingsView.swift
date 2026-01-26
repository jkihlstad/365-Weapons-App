//
//  SettingsView.swift
//  365WeaponsAdmin
//
//  App settings and configuration
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var authClient = ClerkAuthClient.shared
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @Environment(\.dismiss) private var dismiss

    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("autoRefresh") private var autoRefresh = true
    @AppStorage("refreshInterval") private var refreshInterval = 30
    @AppStorage("hapticFeedback") private var hapticFeedback = true

    @State private var showAPISettings = false
    @State private var showAbout = false
    @State private var showLogoutConfirmation = false
    @State private var showDebugConsole = false

    var body: some View {
        NavigationStack {
            Form {
                // User section
                Section {
                    HStack(spacing: 16) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.appAccent, Color.appDanger],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Text(authClient.userFullName?.prefix(1).uppercased() ?? "A")
                                .font(.title2.weight(.bold))
                                .foregroundColor(Color.appTextPrimary)
                        }
                        .frame(width: 60, height: 60)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(authClient.userFullName ?? "Admin")
                                .font(.headline)
                            Text(authClient.userEmail ?? "")
                                .font(.caption)
                                .foregroundColor(Color.appTextSecondary)

                            HStack {
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundColor(Color.appSuccess)
                                Text("Admin Access")
                                    .font(.caption)
                                    .foregroundColor(Color.appSuccess)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Notifications
                Section("Notifications") {
                    Toggle("Push Notifications", isOn: $notificationsEnabled)
                    Toggle("Order Alerts", isOn: .constant(true))
                        .disabled(!notificationsEnabled)
                    Toggle("Inquiry Alerts", isOn: .constant(true))
                        .disabled(!notificationsEnabled)
                    Toggle("Partner Activity", isOn: .constant(true))
                        .disabled(!notificationsEnabled)
                }

                // Data & Sync
                Section("Data & Sync") {
                    Toggle("Auto Refresh", isOn: $autoRefresh)

                    if autoRefresh {
                        Picker("Refresh Interval", selection: $refreshInterval) {
                            Text("15 seconds").tag(15)
                            Text("30 seconds").tag(30)
                            Text("1 minute").tag(60)
                            Text("5 minutes").tag(300)
                        }
                    }

                    NavigationLink(destination: CacheManagementView()) {
                        Label("Cache Management", systemImage: "internaldrive")
                    }
                }

                // Appearance
                Section("Appearance") {
                    // Appearance Mode Picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Theme")
                            .font(.subheadline)
                            .foregroundColor(Color.appTextSecondary)

                        HStack(spacing: 8) {
                            ForEach(AppearanceMode.allCases) { mode in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        appearanceManager.appearanceMode = mode
                                    }
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: mode.icon)
                                            .font(.title2)
                                        Text(mode.displayName)
                                            .font(.caption)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        appearanceManager.appearanceMode == mode
                                            ? Color.appAccent.opacity(0.2)
                                            : Color.clear
                                    )
                                    .foregroundColor(
                                        appearanceManager.appearanceMode == mode
                                            ? Color.appAccent
                                            : Color.appTextSecondary
                                    )
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(
                                                appearanceManager.appearanceMode == mode
                                                    ? Color.appAccent
                                                    : Color.appTextSecondary.opacity(0.3),
                                                lineWidth: 1
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // System mode info
                    if appearanceManager.appearanceMode == .system {
                        HStack {
                            Image(systemName: appearanceManager.isDarkMode ? "moon.fill" : "sun.max.fill")
                                .foregroundColor(appearanceManager.isDarkMode ? .indigo : .yellow)
                            Text("Following system: \(appearanceManager.isDarkMode ? "Dark" : "Light") mode")
                                .font(.caption)
                                .foregroundColor(Color.appTextSecondary)
                        }
                        .padding(.horizontal)
                    }

                    Toggle("Haptic Feedback", isOn: $hapticFeedback)
                }

                // API Configuration
                Section("API Configuration") {
                    NavigationLink(destination: APISettingsView()) {
                        Label("API Keys", systemImage: "key")
                    }

                    NavigationLink(destination: WebhookSettingsView()) {
                        Label("Webhooks", systemImage: "arrow.left.arrow.right")
                    }
                }

                // Developer Tools
                Section("Developer Tools") {
                    Button {
                        showDebugConsole = true
                    } label: {
                        HStack {
                            Label("Debug Console", systemImage: "ant")
                            Spacer()
                            Text("\(DebugLogger.shared.logs.count) logs")
                                .font(.caption)
                                .foregroundColor(Color.appTextSecondary)
                        }
                    }
                }

                // About
                Section("About") {
                    NavigationLink(destination: AboutView()) {
                        Label("About 365Weapons Admin", systemImage: "info.circle")
                    }

                    Link(destination: URL(string: "https://365weapons.com")!) {
                        Label("Visit Website", systemImage: "globe")
                    }

                    Link(destination: URL(string: "mailto:support@365weapons.com")!) {
                        Label("Contact Support", systemImage: "envelope")
                    }
                }

                // Logout
                Section {
                    Button(role: .destructive) {
                        showLogoutConfirmation = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Sign Out", isPresented: $showLogoutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    Task {
                        await authClient.signOut()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .sheet(isPresented: $showDebugConsole) {
                DebugConsoleView()
            }
        }
    }

}

// MARK: - Cache Management View
struct CacheManagementView: View {
    @State private var cacheStatistics: CacheStatistics?
    @State private var isLoading = true
    @State private var isClearing = false
    @State private var lastSyncDate: Date?
    @State private var showClearConfirmation = false
    @State private var clearType: CachedDataType?
    @State private var showClearAllConfirmation = false

    @StateObject private var offlineManager = OfflineManager.shared

    var body: some View {
        Form {
            // Overall Cache Status
            Section("Cache Overview") {
                if isLoading {
                    HStack {
                        ProgressView()
                        Text("Loading cache information...")
                            .foregroundColor(Color.appTextSecondary)
                    }
                } else if let stats = cacheStatistics {
                    HStack {
                        Label("Total Size", systemImage: "internaldrive")
                        Spacer()
                        Text(stats.formattedTotalSize)
                            .font(.headline)
                            .foregroundColor(Color.appAccent)
                    }

                    HStack {
                        Label("Cached Items", systemImage: "doc.on.doc")
                        Spacer()
                        Text("\(stats.validEntries) items")
                            .foregroundColor(Color.appTextSecondary)
                    }

                    if stats.expiredEntries > 0 {
                        HStack {
                            Label("Expired Items", systemImage: "clock.badge.exclamationmark")
                            Spacer()
                            Text("\(stats.expiredEntries) items")
                                .foregroundColor(Color.appAccent)
                        }
                    }

                    HStack {
                        Label("Last Sync", systemImage: "arrow.triangle.2.circlepath")
                        Spacer()
                        Text(offlineManager.formattedLastSyncDate)
                            .foregroundColor(Color.appTextSecondary)
                    }
                }
            }

            // Cache by Type
            Section("Cache by Category") {
                ForEach(CachedDataType.allCases.filter { cacheStatistics?.sizeByType[$0] ?? 0 > 0 }, id: \.self) { dataType in
                    CacheTypeCellView(
                        dataType: dataType,
                        size: cacheStatistics?.formattedSize(forType: dataType) ?? "0 bytes",
                        onClear: {
                            clearType = dataType
                            showClearConfirmation = true
                        }
                    )
                }

                if cacheStatistics?.sizeByType.values.reduce(0, +) == 0 {
                    HStack {
                        Image(systemName: "tray")
                            .foregroundColor(Color.appTextSecondary)
                        Text("No cached data")
                            .foregroundColor(Color.appTextSecondary)
                    }
                }
            }

            // Offline Sync Status
            Section("Sync Status") {
                HStack {
                    Label("Connection", systemImage: offlineManager.isOnline ? "wifi" : "wifi.slash")
                    Spacer()
                    Text(offlineManager.isOnline ? "Online" : "Offline")
                        .foregroundColor(offlineManager.isOnline ? Color.appSuccess : Color.appDanger)
                }

                HStack {
                    Label("Connection Type", systemImage: offlineManager.connectionType.icon)
                    Spacer()
                    Text(offlineManager.connectionType.displayName)
                        .foregroundColor(Color.appTextSecondary)
                }

                if offlineManager.hasPendingActions {
                    HStack {
                        Label("Pending Actions", systemImage: "clock.badge.exclamationmark")
                        Spacer()
                        Text("\(offlineManager.pendingActionsCount)")
                            .foregroundColor(Color.appAccent)
                    }

                    Button(action: syncNow) {
                        HStack {
                            if offlineManager.isSyncing {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            Text("Sync Now")
                        }
                    }
                    .disabled(!offlineManager.isOnline || offlineManager.isSyncing)
                }
            }

            // Actions
            Section("Actions") {
                Button(action: cleanupExpired) {
                    HStack {
                        Image(systemName: "trash.slash")
                        Text("Clear Expired Cache")
                    }
                }

                Button(action: { showClearAllConfirmation = true }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear All Cache")
                    }
                    .foregroundColor(Color.appAccent)
                }
                .disabled(isClearing)

                if offlineManager.hasPendingActions {
                    Button(action: clearPendingActions) {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Clear Pending Actions")
                        }
                        .foregroundColor(Color.appAccent)
                    }
                }
            }

            // Cache Settings
            Section("Cache Settings") {
                NavigationLink(destination: CacheExpirationSettingsView()) {
                    Label("Expiration Settings", systemImage: "clock")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Cache Management")
        .task {
            await loadCacheStatistics()
        }
        .refreshable {
            await loadCacheStatistics()
        }
        .alert("Clear Cache", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {
                clearType = nil
            }
            Button("Clear", role: .destructive) {
                if let type = clearType {
                    Task {
                        await clearCache(forType: type)
                    }
                }
            }
        } message: {
            if let type = clearType {
                Text("Are you sure you want to clear all \(type.displayName) cache? This cannot be undone.")
            }
        }
        .alert("Clear All Cache", isPresented: $showClearAllConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                Task {
                    await clearAllCache()
                }
            }
        } message: {
            Text("Are you sure you want to clear all cached data? This will remove all locally stored data and cannot be undone.")
        }
    }

    // MARK: - Data Loading

    private func loadCacheStatistics() async {
        isLoading = true
        let cache = CacheService.shared
        cacheStatistics = await cache.getStatistics()
        isLoading = false
    }

    // MARK: - Actions

    private func clearCache(forType type: CachedDataType) async {
        isClearing = true
        let cache = CacheService.shared
        try? await cache.invalidate(forType: type)
        await loadCacheStatistics()
        isClearing = false
        clearType = nil
    }

    private func clearAllCache() async {
        isClearing = true
        let cache = CacheService.shared
        try? await cache.clearAll()
        await loadCacheStatistics()
        isClearing = false
    }

    private func cleanupExpired() {
        Task {
            isClearing = true
            let cache = CacheService.shared
            try? await cache.cleanupExpired()
            await loadCacheStatistics()
            isClearing = false
        }
    }

    private func syncNow() {
        Task {
            await offlineManager.syncPendingActions()
        }
    }

    private func clearPendingActions() {
        offlineManager.clearAllPendingActions()
    }
}

// MARK: - Cache Type Cell View
struct CacheTypeCellView: View {
    let dataType: CachedDataType
    let size: String
    let onClear: () -> Void

    var body: some View {
        HStack {
            Image(systemName: dataType.icon)
                .foregroundColor(Color.appAccent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(dataType.displayName)
                    .font(.subheadline)
                Text(size)
                    .font(.caption)
                    .foregroundColor(Color.appTextSecondary)
            }

            Spacer()

            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(Color.appTextSecondary)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Cache Expiration Settings View
struct CacheExpirationSettingsView: View {
    @AppStorage("cache_dashboard_expiration") private var dashboardExpiration = 60
    @AppStorage("cache_orders_expiration") private var ordersExpiration = 120
    @AppStorage("cache_products_expiration") private var productsExpiration = 300

    var body: some View {
        Form {
            Section("Cache Expiration Times") {
                Picker("Dashboard Data", selection: $dashboardExpiration) {
                    Text("30 seconds").tag(30)
                    Text("1 minute").tag(60)
                    Text("2 minutes").tag(120)
                    Text("5 minutes").tag(300)
                }

                Picker("Orders Data", selection: $ordersExpiration) {
                    Text("1 minute").tag(60)
                    Text("2 minutes").tag(120)
                    Text("5 minutes").tag(300)
                    Text("10 minutes").tag(600)
                }

                Picker("Products Data", selection: $productsExpiration) {
                    Text("2 minutes").tag(120)
                    Text("5 minutes").tag(300)
                    Text("10 minutes").tag(600)
                    Text("30 minutes").tag(1800)
                }
            }

            Section {
                Text("Shorter expiration times provide more up-to-date data but may increase network usage. Longer times improve offline performance but data may be stale.")
                    .font(.caption)
                    .foregroundColor(Color.appTextSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Expiration Settings")
    }
}

// MARK: - API Settings View
struct APISettingsView: View {
    @StateObject private var configManager = ConfigurationManager.shared

    // Input fields for editing
    @State private var openRouterKey = ""
    @State private var openAIKey = ""
    @State private var clerkKey = ""
    @State private var convexURL = ""
    @State private var tavilyKey = ""
    @State private var backendURL = ""

    // Visibility toggles
    @State private var showOpenRouterKey = false
    @State private var showOpenAIKey = false
    @State private var showClerkKey = false
    @State private var showTavilyKey = false
    @State private var showBackendKey = false

    // Validation errors
    @State private var openRouterError: String?
    @State private var openAIError: String?
    @State private var clerkError: String?
    @State private var convexError: String?
    @State private var tavilyError: String?
    @State private var backendError: String?

    // UI State
    @State private var isTesting = false
    @State private var testResults: [APIKeyType: Bool] = [:]
    @State private var showDeleteConfirmation = false
    @State private var keyToDelete: APIKeyType?
    @State private var showSaveSuccess = false
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""

    var body: some View {
        Form {
            // Status Overview
            Section("Configuration Status") {
                ForEach(configManager.keyStatuses) { status in
                    HStack {
                        Image(systemName: status.isConfigured ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(status.isConfigured ? Color.appSuccess : Color.appTextSecondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(status.keyType.displayName)
                                .font(.subheadline)
                            Text(status.source.rawValue)
                                .font(.caption)
                                .foregroundColor(Color.appTextSecondary)
                        }

                        Spacer()

                        if let result = testResults[status.keyType] {
                            Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result ? Color.appSuccess : Color.appDanger)
                        }
                    }
                }
            }

            // OpenRouter
            Section {
                SecureKeyInputRow(
                    title: "API Key",
                    placeholder: "sk-or-...",
                    text: $openRouterKey,
                    isVisible: $showOpenRouterKey,
                    errorMessage: openRouterError,
                    existingKeyMasked: configManager.getMaskedKey(for: .openRouter)
                )
                .onChange(of: openRouterKey) { _, newValue in
                    if !newValue.isEmpty {
                        openRouterError = configManager.validationError(for: newValue, keyType: .openRouter)
                    } else {
                        openRouterError = nil
                    }
                }

                HStack {
                    Link("Get API Key", destination: URL(string: "https://openrouter.ai/keys")!)
                        .font(.caption)

                    Spacer()

                    if configManager.hasAPIKey(for: .openRouter) {
                        Button("Delete", role: .destructive) {
                            keyToDelete = .openRouter
                            showDeleteConfirmation = true
                        }
                        .font(.caption)
                    }
                }
            } header: {
                HStack {
                    Text("OpenRouter (AI Chat)")
                    Spacer()
                    if configManager.hasAPIKey(for: .openRouter) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(Color.appSuccess)
                            .font(.caption)
                    }
                }
            }

            // OpenAI
            Section {
                SecureKeyInputRow(
                    title: "API Key",
                    placeholder: "sk-...",
                    text: $openAIKey,
                    isVisible: $showOpenAIKey,
                    errorMessage: openAIError,
                    existingKeyMasked: configManager.getMaskedKey(for: .openAI)
                )
                .onChange(of: openAIKey) { _, newValue in
                    if !newValue.isEmpty {
                        openAIError = configManager.validationError(for: newValue, keyType: .openAI)
                    } else {
                        openAIError = nil
                    }
                }

                HStack {
                    Link("Get API Key", destination: URL(string: "https://platform.openai.com/api-keys")!)
                        .font(.caption)

                    Spacer()

                    if configManager.hasAPIKey(for: .openAI) {
                        Button("Delete", role: .destructive) {
                            keyToDelete = .openAI
                            showDeleteConfirmation = true
                        }
                        .font(.caption)
                    }
                }
            } header: {
                HStack {
                    Text("OpenAI (Voice)")
                    Spacer()
                    if configManager.hasAPIKey(for: .openAI) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(Color.appSuccess)
                            .font(.caption)
                    }
                }
            }

            // Clerk
            Section {
                SecureKeyInputRow(
                    title: "Publishable Key",
                    placeholder: "pk_...",
                    text: $clerkKey,
                    isVisible: $showClerkKey,
                    errorMessage: clerkError,
                    existingKeyMasked: configManager.getMaskedKey(for: .clerk)
                )
                .onChange(of: clerkKey) { _, newValue in
                    if !newValue.isEmpty {
                        clerkError = configManager.validationError(for: newValue, keyType: .clerk)
                    } else {
                        clerkError = nil
                    }
                }

                HStack {
                    Link("Get API Key", destination: URL(string: "https://dashboard.clerk.com")!)
                        .font(.caption)

                    Spacer()

                    if configManager.hasAPIKey(for: .clerk) {
                        Button("Delete", role: .destructive) {
                            keyToDelete = .clerk
                            showDeleteConfirmation = true
                        }
                        .font(.caption)
                    }
                }
            } header: {
                HStack {
                    Text("Clerk (Authentication)")
                    Spacer()
                    if configManager.hasAPIKey(for: .clerk) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(Color.appSuccess)
                            .font(.caption)
                    }
                }
            }

            // Convex
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Deployment URL", text: $convexURL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()

                    if let existingURL = configManager.convexDeploymentURL, convexURL.isEmpty {
                        Text("Current: \(existingURL)")
                            .font(.caption)
                            .foregroundColor(Color.appTextSecondary)
                    }

                    if let error = convexError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(Color.appAccent)
                    }
                }
                .onChange(of: convexURL) { _, newValue in
                    if !newValue.isEmpty {
                        convexError = configManager.validationError(for: newValue, keyType: .convex)
                    } else {
                        convexError = nil
                    }
                }

                HStack {
                    Link("Convex Dashboard", destination: URL(string: "https://dashboard.convex.dev")!)
                        .font(.caption)

                    Spacer()

                    if configManager.hasAPIKey(for: .convex) {
                        Button("Delete", role: .destructive) {
                            keyToDelete = .convex
                            showDeleteConfirmation = true
                        }
                        .font(.caption)
                    }
                }
            } header: {
                HStack {
                    Text("Convex Backend")
                    Spacer()
                    if configManager.hasAPIKey(for: .convex) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(Color.appSuccess)
                            .font(.caption)
                    }
                }
            }

            // Tavily (AI Search)
            Section {
                SecureKeyInputRow(
                    title: "API Key",
                    placeholder: "tvly-...",
                    text: $tavilyKey,
                    isVisible: $showTavilyKey,
                    errorMessage: tavilyError,
                    existingKeyMasked: configManager.getMaskedKey(for: .tavily)
                )
                .onChange(of: tavilyKey) { _, newValue in
                    if !newValue.isEmpty {
                        tavilyError = configManager.validationError(for: newValue, keyType: .tavily)
                    } else {
                        tavilyError = nil
                    }
                }

                HStack {
                    Link("Get API Key", destination: URL(string: "https://tavily.com")!)
                        .font(.caption)

                    Spacer()

                    if configManager.hasAPIKey(for: .tavily) {
                        Button("Delete", role: .destructive) {
                            keyToDelete = .tavily
                            showDeleteConfirmation = true
                        }
                        .font(.caption)
                    }
                }
            } header: {
                HStack {
                    Text("Tavily (AI Search)")
                    Spacer()
                    if configManager.hasAPIKey(for: .tavily) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(Color.appSuccess)
                            .font(.caption)
                    }
                }
            }

            // Backend API (Railway)
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        if showBackendKey {
                            TextField("Backend URL", text: $backendURL)
                                .autocapitalization(.none)
                                .keyboardType(.URL)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("Backend URL", text: $backendURL)
                        }

                        Button(action: { showBackendKey.toggle() }) {
                            Image(systemName: showBackendKey ? "eye.slash" : "eye")
                                .foregroundColor(Color.appTextSecondary)
                        }
                    }

                    if let existingURL = configManager.getAPIKey(for: .backendAuth), backendURL.isEmpty {
                        Text("Stored: \(String(existingURL.prefix(30)))...")
                            .font(.caption)
                            .foregroundColor(Color.appTextSecondary)
                    }

                    if let error = backendError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(Color.appAccent)
                    }
                }
                .onChange(of: backendURL) { _, newValue in
                    if !newValue.isEmpty {
                        backendError = configManager.validationError(for: newValue, keyType: .backendAuth)
                    } else {
                        backendError = nil
                    }
                }

                HStack {
                    Link("Railway Dashboard", destination: URL(string: "https://railway.app/dashboard")!)
                        .font(.caption)

                    Spacer()

                    if configManager.hasAPIKey(for: .backendAuth) {
                        Button("Delete", role: .destructive) {
                            keyToDelete = .backendAuth
                            showDeleteConfirmation = true
                        }
                        .font(.caption)
                    }
                }
            } header: {
                HStack {
                    Text("Backend API (Railway)")
                    Spacer()
                    if configManager.hasAPIKey(for: .backendAuth) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(Color.appSuccess)
                            .font(.caption)
                    }
                }
            }

            // Actions
            Section {
                Button(action: saveChanges) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save Changes")
                    }
                }
                .disabled(!hasChanges)

                Button(action: testConnections) {
                    HStack {
                        if isTesting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                        }
                        Text("Test Connections")
                    }
                }
                .disabled(isTesting)

                Button(action: clearAllFields) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Clear Input Fields")
                    }
                }
                .foregroundColor(Color.appAccent)
            }

            // Security Info
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Keys stored in iOS Keychain", systemImage: "lock.shield")
                        .font(.caption)
                        .foregroundColor(Color.appTextSecondary)

                    Label("Encrypted and protected by device security", systemImage: "checkmark.shield")
                        .font(.caption)
                        .foregroundColor(Color.appTextSecondary)

                    Label("Keys persist across app reinstalls", systemImage: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(Color.appTextSecondary)
                }
            } header: {
                Text("Security")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("API Keys")
        .onAppear {
            configManager.refreshStatus()
        }
        .alert("Delete API Key", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                keyToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let key = keyToDelete {
                    deleteKey(key)
                }
            }
        } message: {
            if let key = keyToDelete {
                Text("Are you sure you want to delete the \(key.displayName) API key? This action cannot be undone.")
            }
        }
        .alert("Saved", isPresented: $showSaveSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("API keys have been securely saved.")
        }
        .alert("Error", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage)
        }
    }

    private var hasChanges: Bool {
        !openRouterKey.isEmpty || !openAIKey.isEmpty || !clerkKey.isEmpty || !convexURL.isEmpty || !tavilyKey.isEmpty || !backendURL.isEmpty
    }

    private func saveChanges() {
        Task {
            do {
                var saved = false

                if !openRouterKey.isEmpty && openRouterError == nil {
                    try configManager.setAPIKey(openRouterKey, for: .openRouter)
                    OpenRouterClient.shared.configure(apiKey: openRouterKey)
                    saved = true
                }

                if !openAIKey.isEmpty && openAIError == nil {
                    try configManager.setAPIKey(openAIKey, for: .openAI)
                    OpenAIClient.shared.configure(apiKey: openAIKey)
                    saved = true
                }

                if !clerkKey.isEmpty && clerkError == nil {
                    try configManager.setAPIKey(clerkKey, for: .clerk)
                    saved = true
                }

                if !convexURL.isEmpty && convexError == nil {
                    try configManager.setAPIKey(convexURL, for: .convex)
                    saved = true
                }

                if !tavilyKey.isEmpty && tavilyError == nil {
                    try configManager.setAPIKey(tavilyKey, for: .tavily)
                    saved = true
                }

                if !backendURL.isEmpty && backendError == nil {
                    try configManager.setAPIKey(backendURL, for: .backendAuth)
                    saved = true
                }

                if saved {
                    await MainActor.run {
                        clearAllFields()
                        configManager.refreshStatus()
                        showSaveSuccess = true
                    }
                }
            } catch {
                await MainActor.run {
                    saveErrorMessage = error.localizedDescription
                    showSaveError = true
                }
            }
        }
    }

    private func testConnections() {
        isTesting = true
        testResults = [:]

        Task {
            for keyType in APIKeyType.allCases {
                let result = await configManager.testAPIKey(for: keyType)
                await MainActor.run {
                    switch result {
                    case .success:
                        testResults[keyType] = true
                    case .failure:
                        testResults[keyType] = false
                    }
                }
            }

            await MainActor.run {
                isTesting = false
            }
        }
    }

    private func deleteKey(_ keyType: APIKeyType) {
        Task {
            do {
                try configManager.removeAPIKey(for: keyType)
                await MainActor.run {
                    configManager.refreshStatus()
                    testResults.removeValue(forKey: keyType)
                }
            } catch {
                await MainActor.run {
                    saveErrorMessage = "Failed to delete key: \(error.localizedDescription)"
                    showSaveError = true
                }
            }
        }
    }

    private func clearAllFields() {
        openRouterKey = ""
        openAIKey = ""
        clerkKey = ""
        convexURL = ""
        tavilyKey = ""
        backendURL = ""
        openRouterError = nil
        openAIError = nil
        clerkError = nil
        convexError = nil
        tavilyError = nil
        backendError = nil
    }
}

// MARK: - Secure Key Input Row
struct SecureKeyInputRow: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    @Binding var isVisible: Bool
    let errorMessage: String?
    let existingKeyMasked: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if isVisible {
                    TextField(placeholder, text: $text)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } else {
                    SecureField(placeholder, text: $text)
                }

                Button(action: { isVisible.toggle() }) {
                    Image(systemName: isVisible ? "eye.slash" : "eye")
                        .foregroundColor(Color.appTextSecondary)
                }
            }

            if text.isEmpty && !existingKeyMasked.isEmpty {
                Text("Stored: \(existingKeyMasked)")
                    .font(.caption)
                    .foregroundColor(Color.appTextSecondary)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(Color.appAccent)
            }
        }
    }
}

// MARK: - Webhook Settings View
// The full WebhookSettingsView implementation is located in:
// Views/Settings/WebhookSettingsView.swift
// This provides comprehensive webhook management with:
// - Multiple webhook configurations
// - Event subscription management
// - Delivery history tracking
// - Test functionality
// - Secret key management

// MARK: - About View
struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Logo
                Image(systemName: "shield.checkered")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.appAccent, Color.appDanger],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 8) {
                    Text("365Weapons Admin")
                        .font(.title.weight(.bold))

                    Text("Version 1.0.0")
                        .font(.subheadline)
                        .foregroundColor(Color.appTextSecondary)
                }

                // Features
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(icon: "chart.bar.xaxis", title: "Real-time Analytics", description: "Monitor your business performance with live data")
                    FeatureRow(icon: "cube.box", title: "Product Management", description: "Create and manage your product catalog")
                    FeatureRow(icon: "list.clipboard", title: "Order Tracking", description: "Track and manage all customer orders")
                    FeatureRow(icon: "sparkles", title: "AI Assistant", description: "Get intelligent insights with AI-powered chat")
                    FeatureRow(icon: "mic", title: "Voice Control", description: "Use voice commands for hands-free operation")
                }
                .padding()
                .background(Color.appSurface)
                .cornerRadius(16)

                // Credits
                VStack(spacing: 8) {
                    Text("Powered by")
                        .font(.caption)
                        .foregroundColor(Color.appTextSecondary)

                    HStack(spacing: 16) {
                        TechBadge(name: "Convex")
                        TechBadge(name: "OpenRouter")
                        TechBadge(name: "OpenAI")
                    }
                }

                Text("2024 365Weapons. All rights reserved.")
                    .font(.caption2)
                    .foregroundColor(Color.appTextSecondary)
            }
            .padding()
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("About")
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Color.appAccent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(description)
                    .font(.caption)
                    .foregroundColor(Color.appTextSecondary)
            }
        }
    }
}

struct TechBadge: View {
    let name: String

    var body: some View {
        Text(name)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.appSurface2)
            .cornerRadius(12)
    }
}

// MARK: - Preview
#Preview {
    SettingsView()
}

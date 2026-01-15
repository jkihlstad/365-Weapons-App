//
//  WebhookSettingsView.swift
//  365WeaponsAdmin
//
//  Full-featured webhook management view
//

import SwiftUI

// MARK: - Webhook Settings View
struct WebhookSettingsView: View {
    @StateObject private var webhookService = WebhookService.shared
    @State private var showAddWebhook = false
    @State private var selectedWebhook: WebhookConfiguration?
    @State private var webhookToDelete: WebhookConfiguration?
    @State private var showDeleteConfirmation = false
    @State private var searchText = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header Stats
                WebhookStatsHeader(webhooks: webhookService.webhooks)
                    .padding()

                // Search Bar
                if !webhookService.webhooks.isEmpty {
                    SearchBar(text: $searchText, placeholder: "Search webhooks...")
                        .padding(.horizontal)
                        .padding(.bottom)
                }

                // Content
                if webhookService.isLoading && webhookService.webhooks.isEmpty {
                    LoadingView()
                } else if webhookService.webhooks.isEmpty {
                    EmptyWebhooksView(onAddTapped: { showAddWebhook = true })
                } else {
                    WebhookListView(
                        webhooks: filteredWebhooks,
                        onSelect: { webhook in
                            selectedWebhook = webhook
                        },
                        onToggle: { webhook in
                            toggleWebhook(webhook)
                        },
                        onDelete: { webhook in
                            webhookToDelete = webhook
                            showDeleteConfirmation = true
                        }
                    )
                }
            }
        }
        .navigationTitle("Webhooks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddWebhook = true }) {
                    Image(systemName: "plus")
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: refreshWebhooks) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(webhookService.isLoading)
            }
        }
        .sheet(isPresented: $showAddWebhook) {
            NavigationStack {
                WebhookEditView(mode: .add) { newWebhook in
                    Task {
                        try? await webhookService.createWebhook(newWebhook)
                    }
                }
            }
        }
        .sheet(item: $selectedWebhook) { webhook in
            NavigationStack {
                WebhookDetailView(webhook: webhook)
            }
        }
        .alert("Delete Webhook", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                webhookToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let webhook = webhookToDelete {
                    deleteWebhook(webhook)
                }
            }
        } message: {
            Text("Are you sure you want to delete \"\(webhookToDelete?.name ?? "this webhook")\"? This action cannot be undone.")
        }
        .onAppear {
            refreshWebhooks()
        }
    }

    private var filteredWebhooks: [WebhookConfiguration] {
        if searchText.isEmpty {
            return webhookService.webhooks
        }
        return webhookService.webhooks.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.url.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func refreshWebhooks() {
        Task {
            await webhookService.refresh()
        }
    }

    private func toggleWebhook(_ webhook: WebhookConfiguration) {
        Task {
            try? await webhookService.toggleWebhook(webhook.id, isActive: !webhook.isActive)
        }
    }

    private func deleteWebhook(_ webhook: WebhookConfiguration) {
        Task {
            try? await webhookService.deleteWebhook(webhook.id)
            webhookToDelete = nil
        }
    }
}

// MARK: - Webhook Stats Header
struct WebhookStatsHeader: View {
    let webhooks: [WebhookConfiguration]

    var body: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Total",
                value: "\(webhooks.count)",
                icon: "arrow.left.arrow.right",
                color: .blue
            )

            StatCard(
                title: "Active",
                value: "\(webhooks.filter { $0.isActive }.count)",
                icon: "checkmark.circle",
                color: .green
            )

            StatCard(
                title: "Failing",
                value: "\(webhooks.filter { $0.status == .failing }.count)",
                icon: "exclamationmark.triangle",
                color: .red
            )
        }
    }
}

// Note: StatCard and SearchBar are imported from Components/StatCard.swift and Components/SearchBar.swift

// MARK: - Loading View
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading webhooks...")
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Empty Webhooks View
struct EmptyWebhooksView: View {
    let onAddTapped: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "arrow.left.arrow.right.circle")
                .font(.system(size: 64))
                .foregroundColor(.gray)

            Text("No Webhooks Configured")
                .font(.title2.bold())

            Text("Webhooks allow you to receive real-time notifications when events occur in your store.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: onAddTapped) {
                Label("Add Webhook", systemImage: "plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: 200)
                    .background(Color.orange)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Webhook List View
struct WebhookListView: View {
    let webhooks: [WebhookConfiguration]
    let onSelect: (WebhookConfiguration) -> Void
    let onToggle: (WebhookConfiguration) -> Void
    let onDelete: (WebhookConfiguration) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(webhooks) { webhook in
                    WebhookRowView(
                        webhook: webhook,
                        onSelect: { onSelect(webhook) },
                        onToggle: { onToggle(webhook) },
                        onDelete: { onDelete(webhook) }
                    )
                }
            }
            .padding()
        }
    }
}

// MARK: - Webhook Row View
struct WebhookRowView: View {
    let webhook: WebhookConfiguration
    let onSelect: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Status Indicator
                VStack {
                    Image(systemName: webhook.status.icon)
                        .font(.title2)
                        .foregroundColor(statusColor)
                }
                .frame(width: 40)

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(webhook.name)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(webhook.url)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text("\(webhook.events.count) events")
                            .font(.caption2)
                            .foregroundColor(.gray)

                        if let lastTriggered = webhook.lastTriggeredAt {
                            Text("Last: \(lastTriggered.timeAgo)")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }

                Spacer()

                // Toggle and Menu
                VStack(alignment: .trailing, spacing: 8) {
                    Toggle("", isOn: .constant(webhook.isActive))
                        .labelsHidden()
                        .tint(.orange)
                        .onTapGesture {
                            onToggle()
                        }

                    Menu {
                        Button(action: onSelect) {
                            Label("Edit", systemImage: "pencil")
                        }

                        Button(action: onToggle) {
                            Label(webhook.isActive ? "Disable" : "Enable",
                                  systemImage: webhook.isActive ? "pause.circle" : "play.circle")
                        }

                        Divider()

                        Button(role: .destructive, action: onDelete) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private var statusColor: Color {
        switch webhook.status {
        case .healthy: return .green
        case .warning: return .orange
        case .failing: return .red
        case .disabled: return .gray
        }
    }
}

// MARK: - Webhook Detail View
struct WebhookDetailView: View {
    @StateObject private var webhookService = WebhookService.shared
    @Environment(\.dismiss) private var dismiss
    @State var webhook: WebhookConfiguration
    @State private var showEditSheet = false
    @State private var showDeliveryHistory = false
    @State private var testResult: WebhookTestResult?
    @State private var isTesting = false
    @State private var showSecretCopied = false
    @State private var showRegenerateConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Status Card
                StatusCard(webhook: webhook)

                // Quick Actions
                QuickActionsCard(
                    webhook: webhook,
                    isTesting: isTesting,
                    onTest: testWebhook,
                    onEdit: { showEditSheet = true },
                    onViewHistory: { showDeliveryHistory = true }
                )

                // Test Result
                if let result = testResult {
                    TestResultCard(result: result)
                }

                // Configuration Details
                ConfigurationCard(
                    webhook: webhook,
                    showSecretCopied: showSecretCopied,
                    onCopySecret: copySecret,
                    onRegenerateSecret: { showRegenerateConfirmation = true }
                )

                // Events Card
                EventsCard(events: webhook.events)

                // Statistics Card
                StatisticsCard(webhookId: webhook.id)
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(webhook.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            NavigationStack {
                WebhookEditView(mode: .edit(webhook)) { updatedWebhook in
                    Task {
                        if let updated = try? await webhookService.updateWebhook(updatedWebhook) {
                            webhook = updated
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showDeliveryHistory) {
            NavigationStack {
                DeliveryHistoryView(webhookId: webhook.id, webhookName: webhook.name)
            }
        }
        .alert("Regenerate Secret", isPresented: $showRegenerateConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Regenerate", role: .destructive) {
                regenerateSecret()
            }
        } message: {
            Text("This will invalidate the current webhook secret. You will need to update your endpoint with the new secret.")
        }
    }

    private func testWebhook() {
        isTesting = true
        testResult = nil

        Task {
            let result = try? await webhookService.testWebhook(webhook)
            await MainActor.run {
                testResult = result
                isTesting = false
                HapticFeedback.medium()
            }
        }
    }

    private func copySecret() {
        UIPasteboard.general.string = webhook.secret
        showSecretCopied = true
        HapticFeedback.success()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showSecretCopied = false
        }
    }

    private func regenerateSecret() {
        Task {
            if let newSecret = try? await webhookService.regenerateSecret(for: webhook.id) {
                await MainActor.run {
                    webhook.secret = newSecret
                    HapticFeedback.success()
                }
            }
        }
    }
}

// MARK: - Status Card
struct StatusCard: View {
    let webhook: WebhookConfiguration

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: webhook.status.icon)
                    .font(.largeTitle)
                    .foregroundColor(statusColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(webhook.status.rawValue)
                        .font(.headline)

                    Text(statusDescription)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                if webhook.isActive {
                    Text("Active")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                } else {
                    Text("Disabled")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.gray)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    private var statusColor: Color {
        switch webhook.status {
        case .healthy: return .green
        case .warning: return .orange
        case .failing: return .red
        case .disabled: return .gray
        }
    }

    private var statusDescription: String {
        switch webhook.status {
        case .healthy:
            return "Webhook is working correctly"
        case .warning:
            return "\(webhook.failureCount) recent failure(s)"
        case .failing:
            return "Webhook is failing - check configuration"
        case .disabled:
            return "Webhook is currently disabled"
        }
    }
}

// MARK: - Quick Actions Card
struct QuickActionsCard: View {
    let webhook: WebhookConfiguration
    let isTesting: Bool
    let onTest: () -> Void
    let onEdit: () -> Void
    let onViewHistory: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            WebhookActionButton(
                title: "Test",
                icon: "paperplane",
                color: .blue,
                isLoading: isTesting,
                action: onTest
            )

            WebhookActionButton(
                title: "Edit",
                icon: "pencil",
                color: .orange,
                action: onEdit
            )

            WebhookActionButton(
                title: "History",
                icon: "clock",
                color: .purple,
                action: onViewHistory
            )
        }
    }
}

// Note: ActionButton is imported from Components/ActionButton.swift
// The QuickActionsCard below uses a local WebhookActionButton to avoid conflicts
struct WebhookActionButton: View {
    let title: String
    let icon: String
    let color: Color
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: color))
                } else {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                }

                Text(title)
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
        .disabled(isLoading)
    }
}

// MARK: - Test Result Card
struct TestResultCard: View {
    let result: WebhookTestResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.success ? .green : .red)

                Text(result.success ? "Test Successful" : "Test Failed")
                    .font(.headline)

                Spacer()

                if let statusCode = result.statusCode {
                    Text("HTTP \(statusCode)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(result.isSuccessStatusCode ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                        .foregroundColor(result.isSuccessStatusCode ? .green : .red)
                        .cornerRadius(4)
                }
            }

            if let duration = result.duration {
                HStack {
                    Text("Response Time:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(String(format: "%.0fms", duration * 1000))
                        .font(.caption.monospaced())
                }
            }

            if let error = result.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            if let response = result.response, !response.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Response:")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Text(response.prefix(200) + (response.count > 200 ? "..." : ""))
                        .font(.caption.monospaced())
                        .foregroundColor(.white.opacity(0.8))
                        .padding(8)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(result.success ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Configuration Card
struct ConfigurationCard: View {
    let webhook: WebhookConfiguration
    let showSecretCopied: Bool
    let onCopySecret: () -> Void
    let onRegenerateSecret: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Configuration")
                .font(.headline)

            // URL
            VStack(alignment: .leading, spacing: 4) {
                Text("Endpoint URL")
                    .font(.caption)
                    .foregroundColor(.gray)

                Text(webhook.url)
                    .font(.body.monospaced())
                    .foregroundColor(.white)
            }

            Divider().background(Color.white.opacity(0.1))

            // Secret
            VStack(alignment: .leading, spacing: 8) {
                Text("Signing Secret")
                    .font(.caption)
                    .foregroundColor(.gray)

                HStack {
                    Text(webhook.maskedSecret)
                        .font(.body.monospaced())
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: onCopySecret) {
                        Image(systemName: showSecretCopied ? "checkmark" : "doc.on.doc")
                            .foregroundColor(showSecretCopied ? .green : .orange)
                    }

                    Button(action: onRegenerateSecret) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.orange)
                    }
                }
            }

            Divider().background(Color.white.opacity(0.1))

            // Settings
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Retry Enabled")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(webhook.retryEnabled ? "Yes" : "No")
                        .font(.body)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Max Retries")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(webhook.maxRetries)")
                        .font(.body)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Created")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(webhook.createdAt.relativeFormatted)
                        .font(.body)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Events Card
struct EventsCard: View {
    let events: [WebhookEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Subscribed Events")
                    .font(.headline)

                Spacer()

                Text("\(events.count) events")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(events) { event in
                    HStack {
                        Image(systemName: event.icon)
                            .font(.caption)
                            .foregroundColor(.orange)

                        Text(event.displayName)
                            .font(.caption)
                            .foregroundColor(.white)

                        Spacer()
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Statistics Card
struct StatisticsCard: View {
    let webhookId: String
    @State private var statistics: WebhookStatistics?
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.headline)

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if let stats = statistics {
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text("\(stats.totalDeliveries)")
                            .font(.title2.bold())
                        Text("Total")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 4) {
                        Text("\(stats.successfulDeliveries)")
                            .font(.title2.bold())
                            .foregroundColor(.green)
                        Text("Success")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 4) {
                        Text("\(stats.failedDeliveries)")
                            .font(.title2.bold())
                            .foregroundColor(.red)
                        Text("Failed")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 4) {
                        Text(stats.successRateFormatted)
                            .font(.title2.bold())
                            .foregroundColor(.blue)
                        Text("Rate")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                }

                if let lastDelivery = stats.lastDelivery {
                    Divider().background(Color.white.opacity(0.1))

                    HStack {
                        Text("Last delivery:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(lastDelivery.timestamp.timeAgo)
                            .font(.caption)
                        Spacer()
                        Text("Avg response: \(stats.averageDurationFormatted)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            } else {
                Text("No statistics available")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding()
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .onAppear {
            loadStatistics()
        }
    }

    private func loadStatistics() {
        Task {
            do {
                let stats = try await WebhookService.shared.getStatistics(for: webhookId)
                await MainActor.run {
                    self.statistics = stats
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Webhook Edit View
struct WebhookEditView: View {
    enum Mode {
        case add
        case edit(WebhookConfiguration)
    }

    let mode: Mode
    let onSave: (WebhookConfiguration) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var url: String = ""
    @State private var selectedEvents: Set<WebhookEvent> = []
    @State private var isActive: Bool = true
    @State private var retryEnabled: Bool = true
    @State private var maxRetries: Int = 3

    @State private var urlValidationError: String?
    @State private var isValidatingURL = false
    @State private var showValidationAlert = false

    private var isEditMode: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var existingWebhook: WebhookConfiguration? {
        if case .edit(let webhook) = mode { return webhook }
        return nil
    }

    var body: some View {
        Form {
            // Basic Info Section
            Section("Basic Information") {
                TextField("Webhook Name", text: $name)
                    .textContentType(.name)

                VStack(alignment: .leading, spacing: 8) {
                    TextField("Endpoint URL", text: $url)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .onChange(of: url) { _, newValue in
                            urlValidationError = newValue.webhookURLValidationError
                        }

                    if let error = urlValidationError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    Button(action: validateURL) {
                        HStack {
                            if isValidatingURL {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark.circle")
                            }
                            Text("Validate URL")
                        }
                        .font(.caption)
                    }
                    .disabled(url.isEmpty || isValidatingURL)
                }
            }

            // Events Section
            Section("Subscribe to Events") {
                ForEach(WebhookEventCategory.allCases) { category in
                    DisclosureGroup {
                        ForEach(category.events) { event in
                            EventToggleRow(
                                event: event,
                                isSelected: selectedEvents.contains(event),
                                onToggle: {
                                    if selectedEvents.contains(event) {
                                        selectedEvents.remove(event)
                                    } else {
                                        selectedEvents.insert(event)
                                    }
                                }
                            )
                        }
                    } label: {
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundColor(.orange)
                            Text(category.rawValue)
                            Spacer()
                            Text("\(selectedEvents.filter { $0.category == category }.count)/\(category.events.count)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }

                // Quick select buttons
                HStack {
                    Button("Select All") {
                        selectedEvents = Set(WebhookEvent.allCases)
                    }
                    .font(.caption)

                    Spacer()

                    Button("Clear All") {
                        selectedEvents.removeAll()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
                .padding(.vertical, 4)
            }

            // Settings Section
            Section("Settings") {
                Toggle("Active", isOn: $isActive)

                Toggle("Retry on Failure", isOn: $retryEnabled)

                if retryEnabled {
                    Stepper("Max Retries: \(maxRetries)", value: $maxRetries, in: 1...5)
                }
            }

            // Info Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Webhook Signature", systemImage: "lock.shield")
                        .font(.subheadline)

                    Text("A unique signing secret will be generated for this webhook. Use it to verify that webhook payloads are authentic.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(isEditMode ? "Edit Webhook" : "Add Webhook")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveWebhook()
                }
                .disabled(!isValid)
            }
        }
        .alert("URL Validation", isPresented: $showValidationAlert) {
            Button("OK") {}
        } message: {
            Text(urlValidationError ?? "URL is valid and reachable")
        }
        .onAppear {
            loadExistingData()
        }
    }

    private var isValid: Bool {
        !name.trimmed.isEmpty &&
        urlValidationError == nil &&
        !url.isEmpty &&
        !selectedEvents.isEmpty
    }

    private func loadExistingData() {
        if let webhook = existingWebhook {
            name = webhook.name
            url = webhook.url
            selectedEvents = Set(webhook.events)
            isActive = webhook.isActive
            retryEnabled = webhook.retryEnabled
            maxRetries = webhook.maxRetries
        }
    }

    private func validateURL() {
        isValidatingURL = true

        Task {
            let (isValid, error) = await WebhookService.shared.validateURL(url)
            await MainActor.run {
                isValidatingURL = false
                urlValidationError = error
                showValidationAlert = true

                if isValid {
                    HapticFeedback.success()
                } else {
                    HapticFeedback.error()
                }
            }
        }
    }

    private func saveWebhook() {
        let webhook = WebhookConfiguration(
            id: existingWebhook?.id ?? UUID().uuidString,
            name: name.trimmed,
            url: url.trimmed,
            events: Array(selectedEvents),
            isActive: isActive,
            secret: existingWebhook?.secret ?? "",
            createdAt: existingWebhook?.createdAt ?? Date(),
            retryEnabled: retryEnabled,
            maxRetries: maxRetries
        )

        onSave(webhook)
        dismiss()
    }
}

// MARK: - Event Toggle Row
struct EventToggleRow: View {
    let event: WebhookEvent
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .orange : .gray)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.displayName)
                        .font(.body)
                        .foregroundColor(.white)

                    Text(event.description)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Delivery History View
struct DeliveryHistoryView: View {
    let webhookId: String
    let webhookName: String

    @StateObject private var webhookService = WebhookService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var deliveries: [WebhookDelivery] = []
    @State private var isLoading = true
    @State private var selectedDelivery: WebhookDelivery?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                ProgressView("Loading history...")
            } else if deliveries.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)

                    Text("No Delivery History")
                        .font(.headline)

                    Text("Deliveries will appear here once webhooks are triggered.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(deliveries) { delivery in
                            DeliveryRow(delivery: delivery)
                                .onTapGesture {
                                    selectedDelivery = delivery
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Delivery History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(item: $selectedDelivery) { delivery in
            NavigationStack {
                DeliveryDetailView(delivery: delivery)
            }
        }
        .onAppear {
            loadHistory()
        }
    }

    private func loadHistory() {
        Task {
            do {
                let history = try await webhookService.getDeliveryHistory(for: webhookId)
                await MainActor.run {
                    self.deliveries = history
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Delivery Row
struct DeliveryRow: View {
    let delivery: WebhookDelivery

    var body: some View {
        HStack(spacing: 12) {
            // Status Icon
            Image(systemName: delivery.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundColor(delivery.success ? .green : .red)

            VStack(alignment: .leading, spacing: 4) {
                Text(delivery.event.displayName)
                    .font(.headline)

                HStack(spacing: 8) {
                    if let statusCode = delivery.statusCode {
                        Text("HTTP \(statusCode)")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(delivery.success ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                            .foregroundColor(delivery.success ? .green : .red)
                            .cornerRadius(4)
                    }

                    Text(delivery.durationFormatted)
                        .font(.caption)
                        .foregroundColor(.gray)

                    if delivery.retryCount > 0 {
                        Text("Retry \(delivery.retryCount)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(delivery.timestamp.timeAgo)
                    .font(.caption)
                    .foregroundColor(.gray)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Delivery Detail View
struct DeliveryDetailView: View {
    let delivery: WebhookDelivery
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Status Header
                HStack {
                    Image(systemName: delivery.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(delivery.success ? .green : .red)

                    VStack(alignment: .leading) {
                        Text(delivery.success ? "Delivered Successfully" : "Delivery Failed")
                            .font(.headline)

                        Text(delivery.timestamp, style: .date) + Text(" at ") + Text(delivery.timestamp, style: .time)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(delivery.success ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                .cornerRadius(12)

                // Details
                VStack(alignment: .leading, spacing: 16) {
                    WebhookDetailRow(label: "Event", value: delivery.event.displayName)
                    WebhookDetailRow(label: "Status Code", value: delivery.statusCodeDisplay)
                    WebhookDetailRow(label: "Duration", value: delivery.durationFormatted)

                    if delivery.retryCount > 0 {
                        WebhookDetailRow(label: "Retry Count", value: "\(delivery.retryCount)")
                    }

                    if let error = delivery.errorMessage {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Error")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(error)
                                .font(.body)
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)

                // Payload
                VStack(alignment: .leading, spacing: 8) {
                    Text("Request Payload")
                        .font(.headline)

                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(formatJSON(delivery.payload))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)

                // Response
                if let response = delivery.response {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Response")
                            .font(.headline)

                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(formatJSON(response))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding()
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Delivery Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func formatJSON(_ string: String) -> String {
        guard let data = string.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let formatted = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
              let result = String(data: formatted, encoding: .utf8) else {
            return string
        }
        return result
    }
}

// MARK: - Webhook Detail Row
struct WebhookDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.body)
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        WebhookSettingsView()
    }
}

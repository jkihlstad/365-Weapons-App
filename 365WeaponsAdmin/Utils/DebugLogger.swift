//
//  DebugLogger.swift
//  365WeaponsAdmin
//
//  Debug logging utility for troubleshooting
//

import Foundation
import SwiftUI

// MARK: - Debug Logger
@MainActor
class DebugLogger: ObservableObject {
    static let shared = DebugLogger()

    @Published var logs: [DebugLog] = []
    @Published var isEnabled: Bool = true

    private init() {}

    func log(_ message: String, category: DebugCategory = .general, level: DebugLevel = .info) {
        guard isEnabled else { return }

        let log = DebugLog(
            timestamp: Date(),
            category: category,
            level: level,
            message: message
        )

        logs.append(log)

        // Also print to console
        print("[\(level.rawValue.uppercased())] [\(category.rawValue)] \(message)")

        // Keep only last 500 logs
        if logs.count > 500 {
            logs.removeFirst(logs.count - 500)
        }
    }

    func error(_ message: String, category: DebugCategory = .general) {
        log(message, category: category, level: .error)
    }

    func warning(_ message: String, category: DebugCategory = .general) {
        log(message, category: category, level: .warning)
    }

    func success(_ message: String, category: DebugCategory = .general) {
        log(message, category: category, level: .success)
    }

    func clear() {
        logs.removeAll()
    }
}

// MARK: - Debug Log Entry
struct DebugLog: Identifiable {
    let id = UUID()
    let timestamp: Date
    let category: DebugCategory
    let level: DebugLevel
    let message: String

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
}

// MARK: - Debug Category
enum DebugCategory: String, CaseIterable {
    case general = "General"
    case openRouter = "OpenRouter"
    case openAI = "OpenAI"
    case orchestrator = "Orchestrator"
    case convex = "Convex"
    case clerk = "Clerk"
    case chat = "Chat"
    case network = "Network"
}

// MARK: - Debug Level
enum DebugLevel: String {
    case info = "info"
    case warning = "warning"
    case error = "error"
    case success = "success"

    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .success: return .green
        }
    }

    var icon: String {
        switch self {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .success: return "checkmark.circle"
        }
    }
}

// MARK: - Debug Console View
struct DebugConsoleView: View {
    @StateObject private var logger = DebugLogger.shared
    @State private var selectedCategory: DebugCategory? = nil
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    var filteredLogs: [DebugLog] {
        var logs = logger.logs

        if let category = selectedCategory {
            logs = logs.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            logs = logs.filter { $0.message.localizedCaseInsensitiveContains(searchText) }
        }

        return logs.reversed()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        DebugFilterChip(title: "All", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }

                        ForEach(DebugCategory.allCases, id: \.self) { category in
                            DebugFilterChip(title: category.rawValue, isSelected: selectedCategory == category) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                .background(Color(.systemGray6))

                // Logs list
                if filteredLogs.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No logs yet")
                            .foregroundColor(.gray)
                        Text("Interact with the app to see debug logs")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredLogs) { log in
                        LogEntryView(log: log)
                    }
                    .listStyle(.plain)
                }
            }
            .searchable(text: $searchText, prompt: "Search logs...")
            .navigationTitle("Debug Console")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            logger.clear()
                        } label: {
                            Label("Clear Logs", systemImage: "trash")
                        }

                        Toggle("Logging Enabled", isOn: $logger.isEnabled)

                        Button {
                            testAPIConnection()
                        } label: {
                            Label("Test API Connection", systemImage: "network")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    private func testAPIConnection() {
        Task {
            logger.log("Starting API connection test...", category: .network)

            // Test OpenRouter
            logger.log("Testing OpenRouter API...", category: .openRouter)
            do {
                let response = try await OpenRouterClient.shared.chat(
                    messages: [ChatCompletionMessage(role: "user", content: "Say 'API test successful' in exactly those words.")],
                    maxTokens: 50
                )
                logger.success("OpenRouter response: \(response)", category: .openRouter)
            } catch {
                logger.error("OpenRouter failed: \(error.localizedDescription)", category: .openRouter)
            }
        }
    }
}

// MARK: - Log Entry View
struct LogEntryView: View {
    let log: DebugLog

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: log.level.icon)
                .foregroundColor(log.level.color)
                .font(.system(size: 14))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(log.category.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(log.level.color)

                    Spacer()

                    Text(log.formattedTimestamp)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                Text(log.message)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.primary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Debug Filter Chip
struct DebugFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.orange : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

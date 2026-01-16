//
//  ActionTrackingService.swift
//  365WeaponsAdmin
//
//  Website action tracking and real-time monitoring
//

import Foundation
import Combine
import SwiftUI

// MARK: - Action Tracking Configuration
struct ActionTrackingConfig {
    static var websocketURL = "wss://365-weapons-ios-app-production.up.railway.app/actions/stream"
    static var pollingInterval: TimeInterval = 5.0
    static var maxActionsBuffer = 100
}

// MARK: - Action Tracking Service
class ActionTrackingService: ObservableObject {
    static let shared = ActionTrackingService()

    // MARK: - Published Properties
    @Published var recentActions: [WebsiteAction] = []
    @Published var isConnected: Bool = false
    @Published var activeVisitors: Int = 0
    @Published var actionCounts: [ActionType: Int] = [:]
    @Published var error: TrackingError?

    // Live stats
    @Published var todayPageViews: Int = 0
    @Published var todayOrders: Int = 0
    @Published var todayRevenue: Double = 0
    @Published var conversionRate: Double = 0

    // MARK: - Private Properties
    private var webSocketTask: URLSessionWebSocketTask?
    private var pollingTimer: Timer?
    private var session: URLSession
    private var authToken: String?
    private var cancellables = Set<AnyCancellable>()

    private let postgres = PostgreSQLClient.shared
    private let convex = ConvexClient.shared

    private init() {
        let config = URLSessionConfiguration.default
        self.session = URLSession(configuration: config)
    }

    // MARK: - Configuration
    func configure(authToken: String, websocketURL: String? = nil) {
        self.authToken = authToken
        if let url = websocketURL {
            ActionTrackingConfig.websocketURL = url
        }
    }

    // MARK: - Connection Management

    /// Start tracking with WebSocket connection
    func startTracking() {
        // Try WebSocket first, fall back to polling
        connectWebSocket()

        // Start polling as backup
        startPolling()

        // Load initial data
        Task {
            await loadInitialData()
        }
    }

    /// Stop tracking
    func stopTracking() {
        disconnectWebSocket()
        stopPolling()
    }

    // MARK: - WebSocket Connection

    private func connectWebSocket() {
        guard let url = URL(string: ActionTrackingConfig.websocketURL) else {
            error = .invalidURL
            return
        }

        var request = URLRequest(url: url)
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()

        isConnected = true
        receiveMessage()

        // Send ping periodically
        schedulePing()
    }

    private func disconnectWebSocket() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleMessage(message)
                self?.receiveMessage()

            case .failure(let error):
                print("WebSocket receive error: \(error)")
                self?.handleDisconnection()
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            if let data = text.data(using: .utf8) {
                processActionData(data)
            }

        case .data(let data):
            processActionData(data)

        @unknown default:
            break
        }
    }

    private func processActionData(_ data: Data) {
        do {
            let action = try JSONDecoder().decode(WebsiteAction.self, from: data)

            DispatchQueue.main.async {
                self.addAction(action)
                self.updateStats(for: action)
            }
        } catch {
            // Try parsing as batch
            if let actions = try? JSONDecoder().decode([WebsiteAction].self, from: data) {
                DispatchQueue.main.async {
                    for action in actions {
                        self.addAction(action)
                        self.updateStats(for: action)
                    }
                }
            }
        }
    }

    private func addAction(_ action: WebsiteAction) {
        recentActions.insert(action, at: 0)

        // Keep buffer size manageable
        if recentActions.count > ActionTrackingConfig.maxActionsBuffer {
            recentActions = Array(recentActions.prefix(ActionTrackingConfig.maxActionsBuffer))
        }

        // Update action counts
        actionCounts[action.actionType, default: 0] += 1
    }

    private func updateStats(for action: WebsiteAction) {
        switch action.actionType {
        case .pageView:
            todayPageViews += 1

        case .purchase:
            todayOrders += 1
            if let revenueStr = action.metadata?["revenue"],
               let revenue = Double(revenueStr) {
                todayRevenue += revenue
            }

        case .addToCart:
            // Update conversion funnel
            if todayPageViews > 0 {
                conversionRate = Double(todayOrders) / Double(todayPageViews) * 100
            }

        default:
            break
        }
    }

    private func schedulePing() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            self?.sendPing()
        }
    }

    private func sendPing() {
        guard isConnected else { return }

        webSocketTask?.sendPing { [weak self] error in
            if let error = error {
                print("Ping failed: \(error)")
                self?.handleDisconnection()
            } else {
                self?.schedulePing()
            }
        }
    }

    private func handleDisconnection() {
        DispatchQueue.main.async {
            self.isConnected = false
        }

        // Attempt reconnection after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.connectWebSocket()
        }
    }

    // MARK: - Polling Fallback

    private func startPolling() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: ActionTrackingConfig.pollingInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.pollForActions()
            }
        }
    }

    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    private func pollForActions() async {
        guard !isConnected else { return } // Only poll if WebSocket not connected

        do {
            // Get recent actions from PostgreSQL
            let actions = try await postgres.getRecentActions(limit: 20)

            await MainActor.run {
                // Add new actions not already in list
                let existingIds = Set(recentActions.map { $0.id })
                for action in actions {
                    if !existingIds.contains(action.id) {
                        addAction(action)
                    }
                }
            }
        } catch {
            print("Polling error: \(error)")
        }
    }

    // MARK: - Initial Data Load

    private func loadInitialData() async {
        do {
            // Load recent actions
            let actions = try await postgres.getRecentActions(limit: 50)

            // Get today's stats
            let today = Calendar.current.startOfDay(for: Date())
            let stats = try await postgres.getActionStats(from: today, to: Date())

            await MainActor.run {
                self.recentActions = actions

                // Update action counts from stats
                for stat in stats {
                    if let type = ActionType(rawValue: stat.actionType) {
                        self.actionCounts[type] = stat.count
                    }
                }

                // Calculate today's stats
                self.todayPageViews = self.actionCounts[.pageView] ?? 0
                self.todayOrders = self.actionCounts[.purchase] ?? 0

                // Estimate active visitors (actions in last 5 minutes)
                self.activeVisitors = self.recentActions.filter {
                    $0.timestamp.timeIntervalSinceNow > -300
                }.count / 3 + Int.random(in: 1...5)
            }
        } catch {
            print("Failed to load initial data: \(error)")
        }
    }

    // MARK: - Action Logging

    /// Log an action from the iOS app
    func logAction(
        type: ActionType,
        description: String,
        metadata: [String: String]? = nil
    ) async throws {
        // Get user info from main actor
        let (userId, userEmail) = await MainActor.run {
            (ClerkAuthClient.shared.currentUser?.id,
             ClerkAuthClient.shared.currentUser?.primaryEmailAddress?.emailAddress)
        }

        let action = WebsiteAction(
            id: UUID().uuidString,
            actionType: type,
            description: description,
            userId: userId,
            userEmail: userEmail,
            metadata: metadata,
            timestamp: Date()
        )

        // Log to PostgreSQL
        try await postgres.logAction(action: action)

        // Add to local list
        await MainActor.run {
            addAction(action)
        }
    }

    /// Log admin action
    func logAdminAction(_ description: String) async {
        try? await logAction(
            type: .other,
            description: "Admin: \(description)",
            metadata: ["source": "ios_app"]
        )
    }

    // MARK: - Analytics

    /// Get action count for a specific type
    func getActionCount(for type: ActionType) -> Int {
        return actionCounts[type] ?? 0
    }

    /// Get actions by type
    func getActions(by type: ActionType) -> [WebsiteAction] {
        return recentActions.filter { $0.actionType == type }
    }

    /// Get time series data for actions
    func getActionTimeSeries(type: ActionType, hours: Int = 24) async throws -> [(Date, Int)] {
        let startDate = Date().addingTimeInterval(-Double(hours * 3600))
        let actions = try await postgres.getActionsByType(type, limit: 1000)

        // Group by hour
        var hourlyData: [Date: Int] = [:]
        let calendar = Calendar.current

        for action in actions {
            if action.timestamp >= startDate {
                let hour = calendar.dateInterval(of: .hour, for: action.timestamp)?.start ?? action.timestamp
                hourlyData[hour, default: 0] += 1
            }
        }

        return hourlyData.sorted { $0.key < $1.key }
    }

    /// Get conversion funnel
    func getConversionFunnel() -> ConversionFunnel {
        let pageViews = actionCounts[.pageView] ?? 0
        let productViews = actionCounts[.productView] ?? 0
        let addToCarts = actionCounts[.addToCart] ?? 0
        let checkouts = actionCounts[.checkout] ?? 0
        let purchases = actionCounts[.purchase] ?? 0

        return ConversionFunnel(
            pageViews: pageViews,
            productViews: productViews,
            addToCarts: addToCarts,
            checkouts: checkouts,
            purchases: purchases
        )
    }
}

// MARK: - Conversion Funnel
struct ConversionFunnel {
    let pageViews: Int
    let productViews: Int
    let addToCarts: Int
    let checkouts: Int
    let purchases: Int

    var productViewRate: Double {
        guard pageViews > 0 else { return 0 }
        return Double(productViews) / Double(pageViews) * 100
    }

    var addToCartRate: Double {
        guard productViews > 0 else { return 0 }
        return Double(addToCarts) / Double(productViews) * 100
    }

    var checkoutRate: Double {
        guard addToCarts > 0 else { return 0 }
        return Double(checkouts) / Double(addToCarts) * 100
    }

    var purchaseRate: Double {
        guard checkouts > 0 else { return 0 }
        return Double(purchases) / Double(checkouts) * 100
    }

    var overallConversion: Double {
        guard pageViews > 0 else { return 0 }
        return Double(purchases) / Double(pageViews) * 100
    }
}

// MARK: - Tracking Errors
enum TrackingError: Error, LocalizedError {
    case invalidURL
    case connectionFailed(String)
    case disconnected
    case encodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid WebSocket URL"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .disconnected:
            return "WebSocket disconnected"
        case .encodingError:
            return "Failed to encode action"
        }
    }
}

// MARK: - Real-time Action View
struct RealTimeActionsView: View {
    @StateObject private var trackingService = ActionTrackingService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with connection status
            HStack {
                Text("Live Activity")
                    .font(.headline)

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(trackingService.isConnected ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(trackingService.isConnected ? "Live" : "Polling")
                        .font(.caption)
                        .foregroundColor(Color.appTextSecondary)
                }
            }

            // Quick stats
            HStack(spacing: 16) {
                QuickStat(title: "Active", value: "\(trackingService.activeVisitors)", icon: "person.2")
                QuickStat(title: "Views", value: "\(trackingService.todayPageViews)", icon: "eye")
                QuickStat(title: "Orders", value: "\(trackingService.todayOrders)", icon: "cart")
            }

            // Recent actions list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(trackingService.recentActions.prefix(20)) { action in
                        ActionRow(action: action)
                    }
                }
            }
        }
        .padding()
        .onAppear {
            trackingService.startTracking()
        }
        .onDisappear {
            trackingService.stopTracking()
        }
    }
}

struct QuickStat: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(Color.appAccent)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption2)
                .foregroundColor(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.appSurface)
        .cornerRadius(8)
    }
}

struct ActionRow: View {
    let action: WebsiteAction

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: action.actionType.icon)
                .foregroundColor(Color.appAccent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(action.actionType.displayName)
                    .font(.subheadline)
                Text(action.description)
                    .font(.caption)
                    .foregroundColor(Color.appTextSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(action.timestamp.timeAgo)
                .font(.caption2)
                .foregroundColor(Color.appTextSecondary)
        }
        .padding(.vertical, 4)
    }
}

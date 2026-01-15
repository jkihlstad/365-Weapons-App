//
//  OfflineManager.swift
//  365WeaponsAdmin
//
//  Singleton service managing offline state with network reachability monitoring
//  Uses NWPathMonitor for network status and manages pending actions queue
//

import Foundation
import Network
import Combine

// MARK: - Offline Manager
/// Singleton service that manages offline state, network monitoring, and pending actions
@MainActor
final class OfflineManager: ObservableObject {
    // MARK: - Singleton
    static let shared = OfflineManager()

    // MARK: - Published Properties
    @Published private(set) var isOnline: Bool = true
    @Published private(set) var connectionType: ConnectionType = .unknown
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var pendingActions: [PendingAction] = []
    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var syncEvents: [SyncEvent] = []

    // MARK: - Private Properties
    private let monitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "com.365weapons.networkmonitor", qos: .utility)
    private let pendingActionsKey = "offline_pending_actions"
    private let lastSyncKey = "offline_last_sync"
    private let maxSyncEvents = 100
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties
    var pendingActionsCount: Int {
        pendingActions.count
    }

    var hasPendingActions: Bool {
        !pendingActions.isEmpty
    }

    var canSync: Bool {
        isOnline && hasPendingActions && !isSyncing
    }

    var formattedLastSyncDate: String {
        guard let date = lastSyncDate else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Initialization
    private init() {
        monitor = NWPathMonitor()
        loadPersistedData()
        startMonitoring()
    }

    deinit {
        monitor.cancel()
    }

    // MARK: - Network Monitoring

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handleNetworkPathUpdate(path)
            }
        }
        monitor.start(queue: monitorQueue)
    }

    private func handleNetworkPathUpdate(_ path: NWPath) {
        let wasOnline = isOnline
        isOnline = path.status == .satisfied

        // Update connection type
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else if path.status == .satisfied {
            connectionType = .other
        } else {
            connectionType = .none
        }

        // Log network state changes
        if wasOnline != isOnline {
            let event = SyncEvent(
                type: isOnline ? .networkOnline : .networkOffline,
                details: "Connection type: \(connectionType.displayName)"
            )
            addSyncEvent(event)

            // Auto-sync when coming back online
            if isOnline && hasPendingActions {
                Task {
                    await syncPendingActions()
                }
            }
        }
    }

    // MARK: - Pending Actions Management

    /// Queue an action to be executed when online
    /// - Parameters:
    ///   - type: The type of action
    ///   - payload: The action payload (Codable)
    func queueAction<T: Codable>(type: PendingActionType, payload: T) async throws {
        let encoder = JSONEncoder()
        let payloadData = try encoder.encode(payload)

        let action = PendingAction(
            type: type,
            payload: payloadData
        )

        pendingActions.append(action)
        savePendingActions()

        let event = SyncEvent(
            type: .actionQueued,
            details: "\(type.displayName) queued"
        )
        addSyncEvent(event)

        // If online, immediately try to sync
        if isOnline {
            await syncPendingActions()
        }
    }

    /// Remove a specific pending action
    /// - Parameter id: The action ID to remove
    func removeAction(id: UUID) {
        pendingActions.removeAll { $0.id == id }
        savePendingActions()
    }

    /// Clear all pending actions
    func clearAllPendingActions() {
        pendingActions.removeAll()
        savePendingActions()

        let event = SyncEvent(
            type: .cacheCleared,
            details: "All pending actions cleared"
        )
        addSyncEvent(event)
    }

    // MARK: - Sync Operations

    /// Attempt to sync all pending actions
    func syncPendingActions() async {
        guard isOnline && !isSyncing && hasPendingActions else { return }

        isSyncing = true

        let startEvent = SyncEvent(
            type: .syncStarted,
            details: "\(pendingActions.count) actions to sync"
        )
        addSyncEvent(startEvent)

        var successCount = 0
        var failCount = 0
        var actionsToRemove: [UUID] = []
        var actionsToRetry: [PendingAction] = []

        for action in pendingActions {
            do {
                try await executeAction(action)
                actionsToRemove.append(action.id)
                successCount += 1

                let successEvent = SyncEvent(
                    type: .actionExecuted,
                    details: action.type.displayName
                )
                addSyncEvent(successEvent)
            } catch {
                failCount += 1

                var mutableAction = action
                mutableAction.incrementRetry()

                if mutableAction.canRetry {
                    actionsToRetry.append(mutableAction)
                } else {
                    actionsToRemove.append(action.id)
                }

                let failEvent = SyncEvent(
                    type: .actionFailed,
                    details: action.type.displayName,
                    success: false,
                    errorMessage: error.localizedDescription
                )
                addSyncEvent(failEvent)
            }
        }

        // Update pending actions
        pendingActions.removeAll { actionsToRemove.contains($0.id) }
        for action in actionsToRetry {
            if let index = pendingActions.firstIndex(where: { $0.id == action.id }) {
                pendingActions[index] = action
            }
        }

        savePendingActions()
        lastSyncDate = Date()
        saveLastSyncDate()

        let completedEvent = SyncEvent(
            type: .syncCompleted,
            details: "Success: \(successCount), Failed: \(failCount)"
        )
        addSyncEvent(completedEvent)

        isSyncing = false
    }

    /// Force a manual sync attempt
    func forceSync() async {
        guard isOnline else { return }
        await syncPendingActions()
    }

    // MARK: - Action Execution

    private func executeAction(_ action: PendingAction) async throws {
        let decoder = JSONDecoder()
        let convex = ConvexClient.shared

        switch action.type {
        case .updateOrderStatus:
            let payload = try decoder.decode(UpdateOrderStatusPayload.self, from: action.payload)
            _ = try await convex.updateOrderStatus(orderId: payload.orderId, status: payload.newStatus)

        case .createProduct:
            let payload = try decoder.decode(CreateProductPayload.self, from: action.payload)
            let request = CreateProductRequest(
                title: payload.title,
                description: payload.description,
                price: payload.price,
                priceRange: payload.priceRange,
                category: payload.category,
                image: payload.image,
                inStock: payload.inStock,
                hasOptions: payload.hasOptions
            )
            _ = try await convex.createProduct(request)

        case .updateProduct:
            let payload = try decoder.decode(UpdateProductPayload.self, from: action.payload)
            _ = try await convex.updateProduct(id: payload.productId, updates: payload.updates)

        default:
            // For now, other action types will be handled as they are implemented
            throw OfflineError.unsupportedAction(action.type)
        }
    }

    // MARK: - Persistence

    private func loadPersistedData() {
        // Load pending actions
        if let data = UserDefaults.standard.data(forKey: pendingActionsKey),
           let actions = try? JSONDecoder().decode([PendingAction].self, from: data) {
            pendingActions = actions
        }

        // Load last sync date
        if let timestamp = UserDefaults.standard.object(forKey: lastSyncKey) as? Double {
            lastSyncDate = Date(timeIntervalSince1970: timestamp)
        }
    }

    private func savePendingActions() {
        if let data = try? JSONEncoder().encode(pendingActions) {
            UserDefaults.standard.set(data, forKey: pendingActionsKey)
        }
    }

    private func saveLastSyncDate() {
        if let date = lastSyncDate {
            UserDefaults.standard.set(date.timeIntervalSince1970, forKey: lastSyncKey)
        }
    }

    // MARK: - Sync Events Management

    private func addSyncEvent(_ event: SyncEvent) {
        syncEvents.insert(event, at: 0)

        // Trim old events
        if syncEvents.count > maxSyncEvents {
            syncEvents = Array(syncEvents.prefix(maxSyncEvents))
        }
    }

    func clearSyncEvents() {
        syncEvents.removeAll()
    }

    // MARK: - Utility Methods

    /// Check if a specific action type is pending
    func hasPendingAction(ofType type: PendingActionType) -> Bool {
        pendingActions.contains { $0.type == type }
    }

    /// Get pending actions of a specific type
    func getPendingActions(ofType type: PendingActionType) -> [PendingAction] {
        pendingActions.filter { $0.type == type }
    }

    /// Get the retry count for a specific action
    func getRetryCount(for actionId: UUID) -> Int? {
        pendingActions.first { $0.id == actionId }?.retryCount
    }
}

// MARK: - Connection Type
enum ConnectionType: String, CaseIterable {
    case wifi = "WiFi"
    case cellular = "Cellular"
    case ethernet = "Ethernet"
    case other = "Other"
    case none = "None"
    case unknown = "Unknown"

    var displayName: String {
        rawValue
    }

    var icon: String {
        switch self {
        case .wifi: return "wifi"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .ethernet: return "cable.connector"
        case .other: return "network"
        case .none: return "wifi.slash"
        case .unknown: return "questionmark.circle"
        }
    }

    var isConnected: Bool {
        switch self {
        case .wifi, .cellular, .ethernet, .other:
            return true
        case .none, .unknown:
            return false
        }
    }
}

// MARK: - Offline Error
enum OfflineError: Error, LocalizedError {
    case notOnline
    case syncInProgress
    case unsupportedAction(PendingActionType)
    case payloadDecodingError(String)
    case actionFailed(String)
    case maxRetriesExceeded

    var errorDescription: String? {
        switch self {
        case .notOnline:
            return "Device is offline"
        case .syncInProgress:
            return "Sync already in progress"
        case .unsupportedAction(let type):
            return "Unsupported action type: \(type.displayName)"
        case .payloadDecodingError(let message):
            return "Failed to decode action payload: \(message)"
        case .actionFailed(let message):
            return "Action failed: \(message)"
        case .maxRetriesExceeded:
            return "Maximum retry attempts exceeded"
        }
    }
}

// MARK: - Offline Manager Extensions

extension OfflineManager {
    /// Check if we should use cached data
    /// - Returns: True if offline or network is slow
    func shouldUseCachedData() -> Bool {
        return !isOnline
    }

    /// Get a summary of the current offline state
    func getStatusSummary() -> OfflineStatusSummary {
        OfflineStatusSummary(
            isOnline: isOnline,
            connectionType: connectionType,
            pendingActionsCount: pendingActionsCount,
            lastSyncDate: lastSyncDate,
            isSyncing: isSyncing
        )
    }
}

// MARK: - Offline Status Summary
struct OfflineStatusSummary {
    let isOnline: Bool
    let connectionType: ConnectionType
    let pendingActionsCount: Int
    let lastSyncDate: Date?
    let isSyncing: Bool

    var statusText: String {
        if !isOnline {
            return "Offline"
        } else if isSyncing {
            return "Syncing..."
        } else if pendingActionsCount > 0 {
            return "\(pendingActionsCount) pending"
        } else {
            return "Online"
        }
    }

    var statusIcon: String {
        if !isOnline {
            return "wifi.slash"
        } else if isSyncing {
            return "arrow.triangle.2.circlepath"
        } else if pendingActionsCount > 0 {
            return "clock.badge.exclamationmark"
        } else {
            return "checkmark.circle.fill"
        }
    }

    var statusColor: String {
        if !isOnline {
            return "red"
        } else if isSyncing {
            return "blue"
        } else if pendingActionsCount > 0 {
            return "orange"
        } else {
            return "green"
        }
    }
}

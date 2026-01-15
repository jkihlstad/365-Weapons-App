//
//  OfflineIndicator.swift
//  365WeaponsAdmin
//
//  Subtle banner showing offline status with pending sync count and manual sync button
//

import SwiftUI

// MARK: - Offline Indicator
/// A subtle banner that shows when the device is offline with pending sync information
struct OfflineIndicator: View {
    @ObservedObject var offlineManager: OfflineManager

    @State private var isExpanded: Bool = false
    @State private var isSyncing: Bool = false

    private var statusColor: Color {
        if !offlineManager.isOnline {
            return .red
        } else if offlineManager.isSyncing {
            return .blue
        } else if offlineManager.hasPendingActions {
            return .orange
        } else {
            return .green
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main indicator bar
            HStack(spacing: 12) {
                // Status icon
                statusIcon

                // Status text
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle)
                        .font(.subheadline.weight(.medium))

                    if !offlineManager.isOnline || offlineManager.hasPendingActions {
                        Text(statusSubtitle)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                // Sync button or expand button
                if offlineManager.isOnline && offlineManager.hasPendingActions {
                    Button(action: syncNow) {
                        if isSyncing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Sync")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                    .disabled(isSyncing)
                }

                // Expand button
                if offlineManager.hasPendingActions {
                    Button(action: { withAnimation { isExpanded.toggle() } }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(statusColor.opacity(0.15))

            // Expanded details
            if isExpanded && offlineManager.hasPendingActions {
                expandedDetails
            }
        }
        .animation(.easeInOut(duration: 0.2), value: offlineManager.isOnline)
        .animation(.easeInOut(duration: 0.2), value: offlineManager.hasPendingActions)
    }

    // MARK: - Status Icon
    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.2))
                .frame(width: 36, height: 36)

            if offlineManager.isSyncing {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(statusColor)
                    .rotationEffect(.degrees(isSyncing ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isSyncing)
            } else {
                Image(systemName: offlineManager.isOnline ? (offlineManager.hasPendingActions ? "clock.badge.exclamationmark" : "checkmark.circle.fill") : "wifi.slash")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(statusColor)
            }
        }
    }

    // MARK: - Status Text
    private var statusTitle: String {
        if !offlineManager.isOnline {
            return "You're Offline"
        } else if offlineManager.isSyncing {
            return "Syncing..."
        } else if offlineManager.hasPendingActions {
            return "Pending Changes"
        } else {
            return "Connected"
        }
    }

    private var statusSubtitle: String {
        if !offlineManager.isOnline {
            return "Changes will sync when reconnected"
        } else if offlineManager.hasPendingActions {
            return "\(offlineManager.pendingActionsCount) action\(offlineManager.pendingActionsCount == 1 ? "" : "s") waiting to sync"
        } else {
            return ""
        }
    }

    // MARK: - Expanded Details
    private var expandedDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .background(Color.white.opacity(0.1))

            // Pending actions list
            ForEach(offlineManager.pendingActions.prefix(5)) { action in
                HStack(spacing: 12) {
                    Image(systemName: action.type.icon)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(action.type.displayName)
                            .font(.caption.weight(.medium))

                        Text(formatDate(action.timestamp))
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    if action.retryCount > 0 {
                        Text("Retry \(action.retryCount)")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
            }

            if offlineManager.pendingActionsCount > 5 {
                Text("+ \(offlineManager.pendingActionsCount - 5) more actions")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            // Last sync info
            if let lastSync = offlineManager.lastSyncDate {
                HStack {
                    Text("Last synced:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(offlineManager.formattedLastSyncDate)
                        .font(.caption.weight(.medium))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.02))
    }

    // MARK: - Actions
    private func syncNow() {
        isSyncing = true
        Task {
            await offlineManager.syncPendingActions()
            isSyncing = false
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Compact Offline Indicator
/// A smaller version of the offline indicator for use in navigation bars or headers
struct CompactOfflineIndicator: View {
    @ObservedObject var offlineManager: OfflineManager

    @State private var showPopover = false

    var body: some View {
        Button(action: { showPopover.toggle() }) {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                if !offlineManager.isOnline || offlineManager.hasPendingActions {
                    Text(statusText)
                        .font(.caption.weight(.medium))
                        .foregroundColor(statusColor)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(statusColor.opacity(0.15))
            .cornerRadius(12)
        }
        .popover(isPresented: $showPopover) {
            OfflineIndicator(offlineManager: offlineManager)
                .frame(minWidth: 300)
        }
    }

    private var statusColor: Color {
        if !offlineManager.isOnline {
            return .red
        } else if offlineManager.hasPendingActions {
            return .orange
        } else {
            return .green
        }
    }

    private var statusText: String {
        if !offlineManager.isOnline {
            return "Offline"
        } else if offlineManager.hasPendingActions {
            return "\(offlineManager.pendingActionsCount) pending"
        } else {
            return ""
        }
    }
}

// MARK: - Offline Banner Modifier
/// A view modifier that adds an offline indicator banner at the top of a view
struct OfflineBannerModifier: ViewModifier {
    @ObservedObject var offlineManager: OfflineManager
    var showOnlyWhenOfflineOrPending: Bool = true

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            if shouldShowBanner {
                OfflineIndicator(offlineManager: offlineManager)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            content
        }
        .animation(.easeInOut(duration: 0.3), value: shouldShowBanner)
    }

    private var shouldShowBanner: Bool {
        if showOnlyWhenOfflineOrPending {
            return !offlineManager.isOnline || offlineManager.hasPendingActions
        }
        return true
    }
}

extension View {
    /// Adds an offline indicator banner at the top of the view
    func offlineBanner(offlineManager: OfflineManager = OfflineManager.shared, showOnlyWhenNeeded: Bool = true) -> some View {
        modifier(OfflineBannerModifier(offlineManager: offlineManager, showOnlyWhenOfflineOrPending: showOnlyWhenNeeded))
    }
}

// MARK: - Cached Data Indicator
/// Shows when data is being served from cache
struct CachedDataIndicator: View {
    let isUsingCachedData: Bool
    let cacheAge: String?

    var body: some View {
        if isUsingCachedData {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption)

                Text("Cached data")
                    .font(.caption)

                if let age = cacheAge {
                    Text("(\(age))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .foregroundColor(.orange)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.15))
            .cornerRadius(12)
        }
    }
}

// MARK: - Sync Status Badge
/// A small badge showing sync status
struct SyncStatusBadge: View {
    let status: SyncStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.caption2)

            Text(status.displayName)
                .font(.caption2.weight(.medium))
        }
        .foregroundColor(statusColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.15))
        .cornerRadius(8)
    }

    private var statusColor: Color {
        switch status {
        case .synced: return .green
        case .pending: return .orange
        case .failed: return .red
        case .syncing: return .blue
        }
    }
}

// MARK: - Preview
#Preview("Offline Indicator") {
    VStack {
        OfflineIndicator(offlineManager: OfflineManager.shared)

        Spacer()

        CompactOfflineIndicator(offlineManager: OfflineManager.shared)

        Spacer()

        CachedDataIndicator(isUsingCachedData: true, cacheAge: "5 min ago")

        Spacer()

        HStack {
            SyncStatusBadge(status: .synced)
            SyncStatusBadge(status: .pending)
            SyncStatusBadge(status: .failed)
            SyncStatusBadge(status: .syncing)
        }
    }
    .padding()
    .background(Color.black.ignoresSafeArea())
}

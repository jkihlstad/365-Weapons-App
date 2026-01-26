//
//  MessagingView.swift
//  365WeaponsAdmin
//
//  Main messaging tab showing all user submissions
//

import SwiftUI

struct MessagingView: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @StateObject private var viewModel = MessagingViewModel()
    @State private var selectedSubmission: UnifiedSubmission?
    @State private var showFilters = false
    @State private var showNotificationSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Stats header
                statsHeader

                // Type filter chips
                typeFilterBar

                // Main content
                if viewModel.isLoading && viewModel.submissions.isEmpty {
                    ProgressView("Loading submissions...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.filteredSubmissions.isEmpty {
                    emptyState
                } else {
                    submissionsList
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $viewModel.searchText, prompt: "Search submissions...")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // New only toggle
                    Button {
                        viewModel.showOnlyNew.toggle()
                    } label: {
                        Image(systemName: viewModel.showOnlyNew ? "bell.badge.fill" : "bell.badge")
                            .foregroundColor(viewModel.showOnlyNew ? Color.appAccent : Color.appTextSecondary)
                    }

                    // Sort menu
                    Menu {
                        ForEach(MessagingViewModel.SortOrder.allCases, id: \.self) { order in
                            Button {
                                viewModel.sortOrder = order
                            } label: {
                                HStack {
                                    Text(order.rawValue)
                                    if viewModel.sortOrder == order {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }

                        Divider()

                        Button {
                            showNotificationSettings = true
                        } label: {
                            Label("Notification Settings", systemImage: "gearshape")
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
            .refreshable {
                await viewModel.loadData()
            }
            .task {
                await viewModel.loadData()
            }
            .sheet(item: $selectedSubmission) { submission in
                SubmissionDetailView(submission: submission)
            }
            .sheet(isPresented: $showNotificationSettings) {
                NotificationsSettingsView()
            }
        }
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                StatChip(
                    title: "Total",
                    value: "\(viewModel.totalCount)",
                    icon: "tray.full",
                    color: .gray
                )

                StatChip(
                    title: "New",
                    value: "\(viewModel.newCount)",
                    icon: "bell.badge",
                    color: Color.appAccent
                )

                ForEach(SubmissionType.allCases) { type in
                    StatChip(
                        title: type.rawValue.components(separatedBy: " ").first ?? type.rawValue,
                        value: "\(viewModel.countByType[type] ?? 0)",
                        icon: type.icon,
                        color: colorForType(type)
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color.appSurface)
    }

    // MARK: - Type Filter Bar

    private var typeFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All button
                MessagingFilterChip(
                    title: "All",
                    isSelected: viewModel.selectedTypes.count == SubmissionType.allCases.count,
                    color: .gray
                ) {
                    viewModel.selectAllTypes()
                }

                ForEach(SubmissionType.allCases) { type in
                    MessagingFilterChip(
                        title: type.rawValue,
                        isSelected: viewModel.selectedTypes.contains(type),
                        color: colorForType(type)
                    ) {
                        viewModel.toggleType(type)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Submissions List

    private var submissionsList: some View {
        List {
            ForEach(viewModel.filteredSubmissions) { submission in
                SubmissionRow(submission: submission)
                    .listRowBackground(Color.appSurface)
                    .listRowSeparatorTint(Color.appBorder)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedSubmission = submission
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "No Submissions",
            systemImage: "tray",
            description: Text(viewModel.showOnlyNew ? "No new submissions" : "No submissions match your filters")
        )
    }

    // MARK: - Helper

    private func colorForType(_ type: SubmissionType) -> Color {
        switch type {
        case .inquiry: return .blue
        case .vendorSignup: return .purple
        case .contact: return Color.appAccent
        case .newsletter: return .green
        }
    }
}

// MARK: - Stat Chip

struct StatChip: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(value)
                    .font(.headline.bold())
            }
            .foregroundColor(color)

            Text(title)
                .font(.caption2)
                .foregroundColor(Color.appTextSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.15))
        .cornerRadius(12)
    }
}

// MARK: - Messaging Filter Chip

struct MessagingFilterChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundColor(isSelected ? Color.appTextPrimary : color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color : color.opacity(0.15))
                .cornerRadius(16)
        }
    }
}

// MARK: - Submission Row

struct SubmissionRow: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    let submission: UnifiedSubmission

    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            ZStack {
                Circle()
                    .fill(colorForType(submission.type).opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: submission.type.icon)
                    .font(.system(size: 18))
                    .foregroundColor(colorForType(submission.type))
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(submission.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    if submission.isNew {
                        Text("NEW")
                            .font(.caption2.bold())
                            .foregroundColor(Color.appTextPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.appAccent)
                            .cornerRadius(4)
                    }

                    Spacer()

                    Text(submission.createdAt.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundColor(Color.appTextSecondary)
                }

                if let subject = submission.subject {
                    Text(subject)
                        .font(.caption)
                        .foregroundColor(Color.appTextPrimary.opacity(0.8))
                        .lineLimit(1)
                }

                HStack {
                    Text(submission.email)
                        .font(.caption)
                        .foregroundColor(Color.appTextSecondary)
                        .lineLimit(1)

                    Spacer()

                    SubmissionStatusBadge(status: submission.status, type: submission.type)
                }
            }

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Color.appTextSecondary)
        }
        .padding(.vertical, 8)
    }

    private func colorForType(_ type: SubmissionType) -> Color {
        switch type {
        case .inquiry: return .blue
        case .vendorSignup: return .purple
        case .contact: return Color.appAccent
        case .newsletter: return .green
        }
    }
}

// MARK: - Submission Status Badge

struct SubmissionStatusBadge: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    let status: String
    let type: SubmissionType

    var body: some View {
        Text(status)
            .font(.caption2.weight(.medium))
            .foregroundColor(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusColor.opacity(0.15))
            .cornerRadius(8)
    }

    private var statusColor: Color {
        let lowercased = status.lowercased()
        if lowercased.contains("new") || lowercased.contains("pending") {
            return Color.appAccent
        } else if lowercased.contains("active") || lowercased.contains("completed") || lowercased.contains("paid") {
            return Color.appSuccess
        } else if lowercased.contains("inactive") || lowercased.contains("cancelled") || lowercased.contains("unsubscribed") {
            return Color.appDanger
        } else {
            return .blue
        }
    }
}

// MARK: - Preview

#Preview {
    MessagingView()
}

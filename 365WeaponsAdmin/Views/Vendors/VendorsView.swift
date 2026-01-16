//
//  VendorsView.swift
//  365WeaponsAdmin
//
//  Vendors/Partners management view
//

import SwiftUI

struct VendorsView: View {
    @StateObject private var viewModel = VendorsViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Status filter bar
                statusFilterBar

                // Vendors list
                if viewModel.isLoading && viewModel.vendors.isEmpty {
                    ProgressView("Loading vendors...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.filteredVendors.isEmpty {
                    ContentUnavailableView(
                        "No Vendors",
                        systemImage: "person.2.slash",
                        description: Text(viewModel.searchText.isEmpty ? "No vendors found" : "No vendors matching '\(viewModel.searchText)'")
                    )
                } else {
                    vendorsList
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Vendors")
            .searchable(text: $viewModel.searchText, prompt: "Search vendors...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: viewModel.refresh) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .refreshable {
                await viewModel.loadVendors()
            }
            .sheet(item: $viewModel.selectedVendor) { vendor in
                VendorDetailView(vendor: vendor, viewModel: viewModel)
            }
            .alert("Error", isPresented: .constant(viewModel.hasError)) {
                Button("OK") { viewModel.clearError() }
                if viewModel.error?.isRetryable ?? false {
                    Button("Retry") { viewModel.retry() }
                }
            } message: {
                Text(viewModel.error?.userMessage ?? "An unknown error occurred")
            }
        }
        .task {
            await viewModel.loadVendors()
        }
    }

    // MARK: - Status Filter Bar
    private var statusFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "All",
                    count: viewModel.vendors.count,
                    isSelected: viewModel.selectedFilter == .all,
                    action: { viewModel.filterByStatus(.all) }
                )

                FilterChip(
                    title: "Active",
                    count: viewModel.activeCount,
                    isSelected: viewModel.selectedFilter == .active,
                    color: .green,
                    action: { viewModel.filterByStatus(.active) }
                )

                FilterChip(
                    title: "Inactive",
                    count: viewModel.inactiveCount,
                    isSelected: viewModel.selectedFilter == .inactive,
                    color: .red,
                    action: { viewModel.filterByStatus(.inactive) }
                )

                FilterChip(
                    title: "Pending",
                    count: viewModel.pendingCount,
                    isSelected: viewModel.selectedFilter == .pending,
                    color: .yellow,
                    action: { viewModel.filterByStatus(.pending) }
                )
            }
            .padding()
        }
        .background(Color.white.opacity(0.05))
    }

    // MARK: - Vendors List
    private var vendorsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.filteredVendors, id: \.id) { vendor in
                    VendorCard(vendor: vendor)
                        .onTapGesture {
                            viewModel.selectVendor(vendor)
                        }
                }
            }
            .padding()
        }
    }
}

// MARK: - Vendor Card
struct VendorCard: View {
    let vendor: PartnerStore

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vendor.storeName)
                        .font(.headline)
                    Text(vendor.storeCode)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(4)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Circle()
                        .fill(vendor.active ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text(vendor.active ? "Active" : "Inactive")
                        .font(.caption2)
                        .foregroundColor(vendor.active ? .green : .red)
                }
            }

            Divider()
                .background(Color.white.opacity(0.1))

            // Details
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label(vendor.storeContactName, systemImage: "person")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)

                    Label(vendor.storeEmail, systemImage: "envelope")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(vendor.formattedCommission)
                        .font(.title3.weight(.bold))
                        .foregroundColor(.orange)

                    Text("Commission")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

// MARK: - Vendor Detail View
struct VendorDetailView: View {
    let vendor: PartnerStore
    @ObservedObject var viewModel: VendorsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Vendor header
                    vendorHeader

                    // Stats section
                    if let details = viewModel.vendorDetails {
                        statsSection(stats: details.stats)
                    }

                    // Contact info
                    contactSection

                    // Commission settings
                    commissionSection

                    // Payout settings
                    payoutSection

                    // Recent orders
                    if let details = viewModel.vendorDetails, !details.recentOrders.isEmpty {
                        recentOrdersSection(orders: details.recentOrders)
                    }

                    // Recent commissions
                    if let details = viewModel.vendorDetails, !details.commissions.isEmpty {
                        recentCommissionsSection(commissions: details.commissions)
                    }
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(vendor.storeName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            await viewModel.loadVendorDetails(vendorId: vendor.id)
        }
    }

    private var vendorHeader: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vendor.storeName)
                        .font(.title2.weight(.bold))
                    HStack(spacing: 8) {
                        Text(vendor.storeCode)
                            .font(.subheadline)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(6)

                        if !vendor.onboardingComplete {
                            Text("Pending")
                                .font(.caption)
                                .foregroundColor(.yellow)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.yellow.opacity(0.2))
                                .cornerRadius(6)
                        }
                    }
                }

                Spacer()

                VStack {
                    Circle()
                        .fill(vendor.active ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    Text(vendor.active ? "Active" : "Inactive")
                        .font(.caption)
                        .foregroundColor(vendor.active ? .green : .red)
                }
            }

            Text("Member since \(vendor.createdAt.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private func statsSection(stats: VendorStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                VendorStatCard(title: "Total Orders", value: "\(stats.totalOrders)", icon: "list.clipboard")
                VendorStatCard(title: "Revenue", value: stats.formattedRevenue, icon: "dollarsign.circle", color: .green)
                VendorStatCard(title: "Commission Earned", value: stats.formattedCommissionTotal, icon: "banknote", color: .orange)
                VendorStatCard(title: "Pending Payout", value: stats.formattedCommissionPending, icon: "clock", color: .blue)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Contact Information")
                .font(.headline)

            InfoRow(label: "Contact Name", value: vendor.storeContactName)
            InfoRow(label: "Email", value: vendor.storeEmail)
            InfoRow(label: "Phone", value: vendor.storePhone)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private var commissionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Commission Settings")
                .font(.headline)

            InfoRow(label: "Commission Type", value: vendor.commissionType.rawValue.capitalized)
            InfoRow(label: "Commission Rate", value: vendor.formattedCommission)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private var payoutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Payout Settings")
                .font(.headline)

            InfoRow(label: "Payout Method", value: vendor.payoutMethod.capitalized)
            InfoRow(label: "PayPal Email", value: vendor.paypalEmail)
            InfoRow(label: "Hold Period", value: "\(vendor.payoutHoldDays) days")
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private func recentOrdersSection(orders: [Order]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Orders")
                .font(.headline)

            ForEach(orders.prefix(5), id: \.id) { order in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("#\(order.orderNumber)")
                            .font(.subheadline.weight(.medium))
                        Text(order.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(order.formattedTotal)
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.green)
                        StatusBadge(orderStatus: order.status)
                    }
                }
                .padding(.vertical, 4)

                if order.id != orders.prefix(5).last?.id {
                    Divider().background(Color.white.opacity(0.1))
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private func recentCommissionsSection(commissions: [Commission]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Commissions")
                .font(.headline)

            ForEach(commissions.prefix(5), id: \.id) { commission in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Order #\(commission.orderNumber)")
                            .font(.subheadline.weight(.medium))
                        Text(commission.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(commission.formattedAmount)
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.orange)
                        Text(commission.status.displayName)
                            .font(.caption)
                            .foregroundColor(commissionStatusColor(commission.status))
                    }
                }
                .padding(.vertical, 4)

                if commission.id != commissions.prefix(5).last?.id {
                    Divider().background(Color.white.opacity(0.1))
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private func commissionStatusColor(_ status: CommissionStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .eligible: return .blue
        case .approved: return .purple
        case .paid: return .green
        case .voided: return .red
        }
    }
}

// MARK: - Vendor Stat Card
struct VendorStatCard: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Preview
#Preview {
    VendorsView()
}

//
//  PaymentHistoryView.swift
//  365WeaponsAdmin
//
//  Full payment history with filtering and search
//

import SwiftUI

struct PaymentHistoryView: View {
    @ObservedObject var viewModel: PaymentsViewModel
    @ObservedObject private var appearanceManager = AppearanceManager.shared

    @State private var showTransactionDetail: Transaction?
    @State private var showRefundConfirmation = false
    @State private var transactionToRefund: Transaction?

    var body: some View {
        VStack(spacing: 0) {
            // Filter Bar
            filterBar

            // Transactions List
            if viewModel.filteredTransactions.isEmpty {
                emptyState
            } else {
                transactionsList
            }
        }
        .background(appearanceManager.isDarkMode ? Color.black.ignoresSafeArea() : Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Transaction History")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.searchText, prompt: "Search transactions...")
        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.applyFilters()
        }
        .sheet(item: $showTransactionDetail) { transaction in
            TransactionDetailView(transaction: transaction, viewModel: viewModel)
        }
        .alert("Refund Payment", isPresented: $showRefundConfirmation) {
            Button("Cancel", role: .cancel) {
                transactionToRefund = nil
            }
            Button("Refund", role: .destructive) {
                if let transaction = transactionToRefund {
                    Task {
                        _ = await viewModel.refundTransaction(transaction)
                    }
                }
            }
        } message: {
            if let transaction = transactionToRefund {
                Text("Are you sure you want to refund \(transaction.formattedAmount)?")
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Date Range
                Menu {
                    ForEach(PaymentsViewModel.DateRange.allCases, id: \.self) { range in
                        Button {
                            viewModel.dateRange = range
                            viewModel.applyFilters()
                        } label: {
                            HStack {
                                Text(range.rawValue)
                                if viewModel.dateRange == range {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    FilterChipLabel(
                        title: viewModel.dateRange.rawValue,
                        icon: "calendar",
                        isActive: viewModel.dateRange != .all
                    )
                }

                // Status Filter
                Menu {
                    Button {
                        viewModel.selectedStatus = nil
                        viewModel.applyFilters()
                    } label: {
                        HStack {
                            Text("All Statuses")
                            if viewModel.selectedStatus == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    Divider()

                    ForEach([PaymentStatus.completed, .pending, .refunded, .failed], id: \.self) { status in
                        Button {
                            viewModel.selectedStatus = status
                            viewModel.applyFilters()
                        } label: {
                            HStack {
                                Image(systemName: status.icon)
                                Text(status.displayName)
                                if viewModel.selectedStatus == status {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    FilterChipLabel(
                        title: viewModel.selectedStatus?.displayName ?? "All Status",
                        icon: "line.3.horizontal.decrease.circle",
                        isActive: viewModel.selectedStatus != nil
                    )
                }

                // Clear Filters
                if viewModel.selectedStatus != nil || viewModel.dateRange != .all {
                    Button {
                        viewModel.selectedStatus = nil
                        viewModel.dateRange = .all
                        viewModel.applyFilters()
                    } label: {
                        Text("Clear")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(appearanceManager.isDarkMode ? Color.white.opacity(0.05) : Color.white)
    }

    // MARK: - Transactions List

    private var transactionsList: some View {
        List {
            ForEach(viewModel.filteredTransactions) { transaction in
                TransactionRow(transaction: transaction)
                    .listRowBackground(appearanceManager.isDarkMode ? Color.white.opacity(0.05) : Color.white)
                    .listRowSeparatorTint(Color.gray.opacity(0.2))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showTransactionDetail = transaction
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if transaction.status == .completed {
                            Button {
                                transactionToRefund = transaction
                                showRefundConfirmation = true
                            } label: {
                                Label("Refund", systemImage: "arrow.uturn.backward")
                            }
                            .tint(.red)
                        }

                        Button {
                            showTransactionDetail = transaction
                        } label: {
                            Label("Details", systemImage: "info.circle")
                        }
                        .tint(.blue)
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.gray)

            Text("No Transactions Found")
                .font(.headline)
                .foregroundColor(appearanceManager.isDarkMode ? .white : .primary)

            Text("Try adjusting your filters or search term")
                .font(.subheadline)
                .foregroundColor(.gray)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Filter Chip Label

struct FilterChipLabel: View {
    let title: String
    let icon: String
    let isActive: Bool

    @ObservedObject private var appearanceManager = AppearanceManager.shared

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(title)
                .font(.caption)
            Image(systemName: "chevron.down")
                .font(.caption2)
        }
        .foregroundColor(isActive ? .white : (appearanceManager.isDarkMode ? .white : .primary))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isActive ? Color.orange : (appearanceManager.isDarkMode ? Color.white.opacity(0.1) : Color(UIColor.secondarySystemBackground)))
        .cornerRadius(20)
    }
}

// MARK: - Transaction Detail View

struct TransactionDetailView: View {
    let transaction: Transaction
    @ObservedObject var viewModel: PaymentsViewModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var appearanceManager = AppearanceManager.shared

    @State private var showRefundConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Amount Header
                    amountHeader

                    // Status Card
                    statusCard

                    // Payment Details
                    paymentDetailsCard

                    // Customer Info
                    if transaction.customerName != nil || transaction.customerEmail != nil {
                        customerCard
                    }

                    // Timeline
                    timelineCard

                    // Actions
                    actionsCard
                }
                .padding()
            }
            .background(appearanceManager.isDarkMode ? Color.black.ignoresSafeArea() : Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Transaction Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Refund Payment", isPresented: $showRefundConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Refund", role: .destructive) {
                    Task {
                        _ = await viewModel.refundTransaction(transaction)
                        dismiss()
                    }
                }
            } message: {
                Text("Are you sure you want to refund \(transaction.formattedAmount) to \(transaction.customerName ?? "the customer")?")
            }
        }
    }

    // MARK: - Amount Header

    private var amountHeader: some View {
        VStack(spacing: 8) {
            Text(transaction.formattedAmount)
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(transaction.status == .refunded ? .red : (appearanceManager.isDarkMode ? .white : .primary))

            if transaction.status == .refunded {
                Text("REFUNDED")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Status Card

    private var statusCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(transaction.status.color.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: transaction.status.icon)
                    .font(.title2)
                    .foregroundColor(transaction.status.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Status")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(transaction.status.displayName)
                    .font(.headline)
                    .foregroundColor(transaction.status.color)
            }

            Spacer()
        }
        .padding()
        .background(appearanceManager.isDarkMode ? Color.white.opacity(0.05) : Color.white)
        .cornerRadius(12)
    }

    // MARK: - Payment Details Card

    private var paymentDetailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Payment Details")
                .font(.headline)
                .foregroundColor(appearanceManager.isDarkMode ? .white : .primary)

            DetailInfoRow(label: "Method", value: methodDisplay)

            if let cardBrand = transaction.cardBrand, let last4 = transaction.cardLast4 {
                DetailInfoRow(label: "Card", value: "\(cardBrand.displayName) •••• \(last4)")
            }

            if let description = transaction.description {
                DetailInfoRow(label: "Description", value: description)
            }

            DetailInfoRow(label: "Transaction ID", value: transaction.id, isMonospaced: true)
        }
        .padding()
        .background(appearanceManager.isDarkMode ? Color.white.opacity(0.05) : Color.white)
        .cornerRadius(12)
    }

    private var methodDisplay: String {
        switch transaction.method {
        case "tap_to_pay": return "Tap to Pay"
        case "manual_card": return "Manual Card Entry"
        case "card_on_file": return "Card on File"
        case "invoice": return "Invoice"
        default: return transaction.method.capitalized
        }
    }

    // MARK: - Customer Card

    private var customerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Customer")
                .font(.headline)
                .foregroundColor(appearanceManager.isDarkMode ? .white : .primary)

            if let name = transaction.customerName {
                DetailInfoRow(label: "Name", value: name)
            }

            if let email = transaction.customerEmail {
                DetailInfoRow(label: "Email", value: email)
            }
        }
        .padding()
        .background(appearanceManager.isDarkMode ? Color.white.opacity(0.05) : Color.white)
        .cornerRadius(12)
    }

    // MARK: - Timeline Card

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Timeline")
                .font(.headline)
                .foregroundColor(appearanceManager.isDarkMode ? .white : .primary)

            TimelineItem(
                icon: "plus.circle",
                title: "Created",
                date: transaction.createdAt,
                color: .blue
            )

            if let completedAt = transaction.completedAt {
                TimelineItem(
                    icon: "checkmark.circle",
                    title: "Completed",
                    date: completedAt,
                    color: .green
                )
            }

            if let refundedAt = transaction.refundedAt {
                TimelineItem(
                    icon: "arrow.uturn.backward.circle",
                    title: "Refunded",
                    date: refundedAt,
                    color: .red
                )
            }
        }
        .padding()
        .background(appearanceManager.isDarkMode ? Color.white.opacity(0.05) : Color.white)
        .cornerRadius(12)
    }

    // MARK: - Actions Card

    private var actionsCard: some View {
        VStack(spacing: 12) {
            // Refund Button
            if transaction.status == .completed {
                Button {
                    showRefundConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Refund Payment")
                    }
                    .foregroundColor(.red)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                }
            }

            // Send Receipt Button
            if let email = transaction.customerEmail, !email.isEmpty {
                Button {
                    // TODO: Send receipt
                } label: {
                    HStack {
                        Image(systemName: "envelope")
                        Text("Send Receipt")
                    }
                    .foregroundColor(.blue)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
            }

            // Copy Transaction ID
            Button {
                UIPasteboard.general.string = transaction.id
            } label: {
                HStack {
                    Image(systemName: "doc.on.doc")
                    Text("Copy Transaction ID")
                }
                .foregroundColor(.orange)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Detail Info Row

struct DetailInfoRow: View {
    let label: String
    let value: String
    var isMonospaced: Bool = false

    @ObservedObject private var appearanceManager = AppearanceManager.shared

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.gray)

            Spacer()

            if isMonospaced {
                Text(value)
                    .font(.caption.monospaced())
                    .foregroundColor(appearanceManager.isDarkMode ? .white : .primary)
            } else {
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(appearanceManager.isDarkMode ? .white : .primary)
            }
        }
    }
}

// MARK: - Timeline Item

struct TimelineItem: View {
    let icon: String
    let title: String
    let date: Date
    let color: Color

    @ObservedObject private var appearanceManager = AppearanceManager.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(appearanceManager.isDarkMode ? .white : .primary)
                Text(date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    PaymentHistoryView(viewModel: PaymentsViewModel())
}

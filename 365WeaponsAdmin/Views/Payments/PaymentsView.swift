//
//  PaymentsView.swift
//  365WeaponsAdmin
//
//  Main payments tab for accepting and managing payments
//

import SwiftUI

struct PaymentsView: View {
    @StateObject private var viewModel = PaymentsViewModel()
    @ObservedObject private var appearanceManager = AppearanceManager.shared

    @State private var selectedPaymentMethod: PaymentMethod?
    @State private var showPaymentSheet = false
    @State private var showTransactionDetail: Transaction?
    @State private var showRefundConfirmation = false
    @State private var transactionToRefund: Transaction?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Stats Cards
                    statsSection

                    // Quick Actions
                    quickActionsSection

                    // Payment Methods
                    paymentMethodsSection

                    // Recent Transactions
                    recentTransactionsSection
                }
                .padding()
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Payments")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.loadData()
            }
            .task {
                await viewModel.loadData()
            }
            .sheet(item: $selectedPaymentMethod) { method in
                PaymentMethodSheet(method: method, viewModel: viewModel)
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
                    Text("Are you sure you want to refund \(transaction.formattedAmount) to \(transaction.customerName ?? "the customer")?")
                }
            }
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                PaymentStatCard(
                    title: "Today",
                    amount: viewModel.todayTotal,
                    icon: "clock",
                    color: .green
                )

                PaymentStatCard(
                    title: "This Week",
                    amount: viewModel.weekTotal,
                    icon: "calendar",
                    color: .blue
                )

                PaymentStatCard(
                    title: "This Month",
                    amount: viewModel.monthTotal,
                    icon: "calendar.badge.clock",
                    color: .purple
                )

                PaymentStatCard(
                    title: "Transactions",
                    count: viewModel.transactionCount,
                    icon: "arrow.left.arrow.right",
                    color: Color.appAccent
                )
            }
        }
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(Color.appTextPrimary)

            HStack(spacing: 12) {
                QuickActionButton(
                    title: "New Payment",
                    icon: "plus.circle.fill",
                    color: .green
                ) {
                    selectedPaymentMethod = .tapToPay
                }

                QuickActionButton(
                    title: "Send Invoice",
                    icon: "doc.text.fill",
                    color: .blue
                ) {
                    selectedPaymentMethod = .invoice
                }

                QuickActionButton(
                    title: "History",
                    icon: "clock.arrow.circlepath",
                    color: .purple
                ) {
                    // TODO: Navigate to full history view
                }
            }
        }
    }

    // MARK: - Payment Methods Section

    private var paymentMethodsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accept Payment")
                .font(.headline)
                .foregroundColor(Color.appTextPrimary)

            VStack(spacing: 8) {
                ForEach(PaymentMethod.allCases) { method in
                    PaymentMethodRow(method: method, isAvailable: method == .tapToPay ? viewModel.isTapToPayAvailable : true) {
                        selectedPaymentMethod = method
                    }
                }
            }
        }
    }

    // MARK: - Recent Transactions Section

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Transactions")
                    .font(.headline)
                    .foregroundColor(Color.appTextPrimary)

                Spacer()

                NavigationLink(destination: PaymentHistoryView(viewModel: viewModel)) {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundColor(Color.appAccent)
                }
            }

            if viewModel.transactions.isEmpty {
                EmptyTransactionsView()
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.transactions.prefix(5)) { transaction in
                        TransactionRow(transaction: transaction)
                            .onTapGesture {
                                showTransactionDetail = transaction
                            }
                    }
                }
            }
        }
    }
}

// MARK: - Payment Stat Card

struct PaymentStatCard: View {
    let title: String
    var amount: Double? = nil
    var count: Int? = nil
    let icon: String
    let color: Color

    @ObservedObject private var appearanceManager = AppearanceManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }

            if let amount = amount {
                Text(formatCurrency(amount))
                    .font(.title2.bold())
                    .foregroundColor(Color.appTextPrimary)
            } else if let count = count {
                Text("\(count)")
                    .font(.title2.bold())
                    .foregroundColor(Color.appTextPrimary)
            }

            Text(title)
                .font(.caption)
                .foregroundColor(Color.appTextSecondary)
        }
        .padding()
        .frame(width: 140)
        .background(Color.appSurface)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

// MARK: - Quick Action Button

struct PayQuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    @ObservedObject private var appearanceManager = AppearanceManager.shared

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
                    .foregroundColor(Color.appTextPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.appSurface)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 5)
        }
    }
}

// MARK: - Payment Method Row

struct PaymentMethodRow: View {
    let method: PaymentMethod
    let isAvailable: Bool
    let action: () -> Void

    @ObservedObject private var appearanceManager = AppearanceManager.shared

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isAvailable ? Color.appAccent.opacity(0.2) : Color.appTextSecondary.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: method.icon)
                        .font(.title3)
                        .foregroundColor(isAvailable ? Color.appAccent : Color.appTextSecondary)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(method.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Color.appTextPrimary)

                        if !isAvailable {
                            Text("Unavailable")
                                .font(.caption2)
                                .foregroundColor(Color.appTextPrimary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.appTextSecondary)
                                .cornerRadius(4)
                        }
                    }

                    Text(method.description)
                        .font(.caption)
                        .foregroundColor(Color.appTextSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color.appTextSecondary)
            }
            .padding()
            .background(Color.appSurface)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 5)
        }
        .disabled(!isAvailable)
    }
}

// MARK: - Transaction Row

struct TransactionRow: View {
    let transaction: Transaction

    @ObservedObject private var appearanceManager = AppearanceManager.shared

    var body: some View {
        HStack(spacing: 12) {
            // Status Icon
            ZStack {
                Circle()
                    .fill(transaction.status.color.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: transaction.status.icon)
                    .foregroundColor(transaction.status.color)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(transaction.customerName ?? "Customer")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Color.appTextPrimary)

                    Spacer()

                    Text(transaction.formattedAmount)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(transaction.status == .refunded ? Color.appDanger : Color.appTextPrimary)
                }

                HStack {
                    if let description = transaction.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(Color.appTextSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(transaction.createdAt.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundColor(Color.appTextSecondary)
                }

                if transaction.cardLast4 != nil {
                    Text(transaction.cardDisplay)
                        .font(.caption)
                        .foregroundColor(Color.appTextSecondary)
                }
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

// MARK: - Empty Transactions View

struct EmptyTransactionsView: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "creditcard.trianglebadge.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(Color.appTextSecondary)

            Text("No Transactions Yet")
                .font(.headline)
                .foregroundColor(Color.appTextPrimary)

            Text("Accept your first payment to see it here")
                .font(.subheadline)
                .foregroundColor(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.appSurface)
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    PaymentsView()
}

//
//  OrdersView.swift
//  365WeaponsAdmin
//
//  Orders management view
//

import SwiftUI

struct OrdersView: View {
    @StateObject private var viewModel = OrdersViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Status filter
                statusFilterBar

                // Orders list
                if viewModel.isLoading && viewModel.orders.isEmpty {
                    ProgressView("Loading orders...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.filteredOrders.isEmpty {
                    ContentUnavailableView(
                        "No Orders",
                        systemImage: "list.clipboard",
                        description: Text(viewModel.selectedStatus != nil ? "No \(viewModel.selectedStatus!.displayName.lowercased()) orders" : "No orders found")
                    )
                } else {
                    ordersList
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Orders")
            .searchable(text: $viewModel.searchText, prompt: "Search orders...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: viewModel.refresh) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .refreshable {
                await viewModel.loadOrders()
            }
            .sheet(item: $viewModel.selectedOrder) { order in
                OrderDetailView(order: order, viewModel: viewModel)
            }
            .alert("Error", isPresented: .constant(viewModel.hasError)) {
                Button("OK") { viewModel.clearError() }
                if viewModel.error?.isRetryable ?? false {
                    Button("Retry") { viewModel.retry() }
                }
            } message: {
                Text(viewModel.error?.userFriendlyMessage ?? "An unknown error occurred")
            }
        }
        .task {
            await viewModel.loadOrders()
        }
    }

    // MARK: - Status Filter Bar
    private var statusFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "All",
                    count: viewModel.orders.count,
                    isSelected: viewModel.selectedStatus == nil,
                    action: { viewModel.filterByStatus(nil) }
                )

                ForEach(OrderStatus.allCases, id: \.self) { status in
                    FilterChip(
                        title: status.displayName,
                        count: viewModel.orderCountByStatus[status] ?? 0,
                        isSelected: viewModel.selectedStatus == status,
                        color: statusColor(for: status),
                        action: { viewModel.filterByStatus(status) }
                    )
                }
            }
            .padding()
        }
        .background(Color.white.opacity(0.05))
    }

    // MARK: - Orders List
    private var ordersList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.filteredOrders) { order in
                    OrderCard(order: order)
                        .onTapGesture {
                            viewModel.selectOrder(order)
                        }
                }
            }
            .padding()
        }
    }

    private func statusColor(for status: OrderStatus) -> Color {
        switch status {
        case .awaitingPayment: return .orange
        case .awaitingShipment: return .blue
        case .inProgress: return .purple
        case .completed: return .green
        case .cancelled: return .red
        }
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    var color: Color = .orange
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)

                if count > 0 {
                    Text("\(count)")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.3) : Color.white.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color.white.opacity(0.1))
            .foregroundColor(isSelected ? .white : .gray)
            .cornerRadius(20)
        }
    }
}

// MARK: - Order Card
struct OrderCard: View {
    let order: Order

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("#\(order.orderNumber)")
                        .font(.headline)
                    Text(order.createdAt, style: .date)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                StatusBadge(orderStatus: order.status)
            }

            Divider()
                .background(Color.white.opacity(0.1))

            // Details
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label(order.customerEmail, systemImage: "envelope")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)

                    if let serviceType = order.serviceType {
                        Label(serviceType.displayName, systemImage: serviceType.icon)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(order.formattedTotal)
                        .font(.title3.weight(.bold))
                        .foregroundColor(.green)

                    Text(order.placedBy == .partner ? "Partner Order" : "Direct Order")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(order.placedBy == .partner ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2))
                        .foregroundColor(order.placedBy == .partner ? .orange : .blue)
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

// MARK: - Order Detail View
struct OrderDetailView: View {
    let order: Order
    @ObservedObject var viewModel: OrdersViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStatus: OrderStatus

    init(order: Order, viewModel: OrdersViewModel) {
        self.order = order
        self.viewModel = viewModel
        self._selectedStatus = State(initialValue: order.status)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Order header
                    orderHeader

                    // Status update
                    statusSection

                    // Customer info
                    customerSection

                    // Order details
                    orderDetailsSection

                    // Address info
                    if let address = order.billingAddress {
                        addressSection(address: address, title: "Billing Address")
                    }

                    if let returnAddress = order.returnShippingAddressSnapshot {
                        addressSection(address: returnAddress, title: "Return Address")
                    }
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Order #\(order.orderNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var orderHeader: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Order Total")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(order.formattedTotal)
                        .font(.largeTitle.weight(.bold))
                        .foregroundColor(.green)
                }

                Spacer()

                StatusBadge(orderStatus: order.status)
            }

            if let paidAt = order.paidAt {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Paid on \(paidAt, style: .date)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Update Status")
                .font(.headline)

            Picker("Status", selection: $selectedStatus) {
                ForEach(OrderStatus.allCases, id: \.self) { status in
                    Text(status.displayName).tag(status)
                }
            }
            .pickerStyle(.segmented)

            if selectedStatus != order.status {
                Button(action: updateStatus) {
                    Text("Save Status")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private var customerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Customer Information")
                .font(.headline)

            InfoRow(label: "Email", value: order.customerEmail)

            if let customer = order.endCustomerInfo {
                if let name = customer.name {
                    InfoRow(label: "Name", value: name)
                }
                if let phone = customer.phone {
                    InfoRow(label: "Phone", value: phone)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private var orderDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Order Details")
                .font(.headline)

            if let serviceType = order.serviceType {
                InfoRow(label: "Service Type", value: serviceType.displayName)
            }

            InfoRow(label: "Placed By", value: order.placedBy == .partner ? "Partner" : "Customer")

            if let partnerCode = order.partnerCodeUsed {
                InfoRow(label: "Partner Code", value: partnerCode)
            }

            InfoRow(label: "Created", value: order.createdAt.formatted())

            if let totals = order.totals {
                Divider().background(Color.white.opacity(0.1))

                if let subtotal = totals.subtotal as Int? {
                    InfoRow(label: "Subtotal", value: String(format: "$%.2f", Double(subtotal) / 100.0))
                }
                if let discount = totals.discountAmount, discount > 0 {
                    InfoRow(label: "Discount", value: String(format: "-$%.2f", Double(discount) / 100.0), valueColor: .green)
                }
                if let tax = totals.tax {
                    InfoRow(label: "Tax", value: String(format: "$%.2f", Double(tax) / 100.0))
                }
                if let shipping = totals.shipping {
                    InfoRow(label: "Shipping", value: String(format: "$%.2f", Double(shipping) / 100.0))
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private func addressSection(address: Address, title: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            Text(address.formatted)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private func updateStatus() {
        Task {
            await viewModel.updateOrderStatus(orderId: order.id, status: selectedStatus)
            dismiss()
        }
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = .white

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(valueColor)
        }
    }
}

// MARK: - Preview
#Preview {
    OrdersView()
}

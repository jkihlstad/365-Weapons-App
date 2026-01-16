//
//  OrdersView.swift
//  365WeaponsAdmin
//
//  Orders management view
//

import SwiftUI

struct OrdersView: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @StateObject private var viewModel = OrdersViewModel()
    @State private var showBulkStatusPicker = false
    @State private var showExportSheet = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // Status filter
                    statusFilterBar

                    // Selection bar (when in selection mode)
                    if viewModel.isSelectionMode {
                        selectionBar
                    }

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

                // Floating bulk action bar
                if viewModel.hasSelection {
                    bulkActionBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background(appearanceManager.isDarkMode ? Color.appBackground.ignoresSafeArea() : Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Orders")
            .searchable(text: $viewModel.searchText, prompt: "Search orders...")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: viewModel.toggleSelectionMode) {
                        Image(systemName: viewModel.isSelectionMode ? "xmark.circle.fill" : "checkmark.circle")
                    }
                }
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
            .sheet(isPresented: $showBulkStatusPicker) {
                BulkStatusPickerSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showExportSheet) {
                ExportSheet(csv: viewModel.exportSelectedToCSV())
            }
            .alert("Delete Orders", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.bulkDelete()
                    }
                }
            } message: {
                Text("Are you sure you want to delete \(viewModel.selectedOrdersCount) orders? This action cannot be undone.")
            }
            .alert("Error", isPresented: .constant(viewModel.hasError)) {
                Button("OK") { viewModel.clearError() }
                if viewModel.error?.isRetryable ?? false {
                    Button("Retry") { viewModel.retry() }
                }
            } message: {
                Text(viewModel.error?.userFriendlyMessage ?? "An unknown error occurred")
            }
            .alert(item: $viewModel.bulkOperationResult) { result in
                Alert(
                    title: Text(result.isSuccess ? "Success" : "Partial Success"),
                    message: Text(result.message),
                    dismissButton: .default(Text("OK")) {
                        viewModel.clearBulkResult()
                    }
                )
            }
            .overlay {
                if viewModel.isBulkOperationInProgress {
                    Color.appBackground.opacity(0.5)
                        .ignoresSafeArea()
                    ProgressView("Processing...")
                        .padding()
                        .background(appearanceManager.isDarkMode ? Color.appSurface2 : Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                }
            }
        }
        .task {
            await viewModel.loadOrders()
        }
    }

    // MARK: - Selection Bar
    private var selectionBar: some View {
        HStack {
            Button(action: {
                if viewModel.allFilteredSelected {
                    viewModel.clearSelection()
                } else {
                    viewModel.selectAll()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.allFilteredSelected ? "checkmark.circle.fill" : "circle")
                    Text(viewModel.allFilteredSelected ? "Deselect All" : "Select All")
                        .font(.subheadline)
                }
            }

            Spacer()

            if viewModel.hasSelection {
                Text("\(viewModel.selectedOrdersCount) selected")
                    .font(.subheadline)
                    .foregroundColor(appearanceManager.isDarkMode ? Color.appAccent : .red)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(appearanceManager.isDarkMode ? Color.appAccent.opacity(0.1) : Color.red.opacity(0.1))
    }

    // MARK: - Bulk Action Bar
    private var bulkActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 16) {
                // Update Status
                Button(action: { showBulkStatusPicker = true }) {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.title3)
                        Text("Status")
                            .font(.caption2)
                    }
                }

                // Export
                Button(action: { showExportSheet = true }) {
                    VStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                        Text("Export")
                            .font(.caption2)
                    }
                }

                // Delete
                Button(action: { showDeleteConfirmation = true }) {
                    VStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.title3)
                        Text("Delete")
                            .font(.caption2)
                    }
                }
                .foregroundColor(.red)

                Spacer()

                // Selection count
                Text("\(viewModel.selectedOrdersCount)")
                    .font(.title2.weight(.bold))
                    .foregroundColor(appearanceManager.isDarkMode ? Color.appAccent : .red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(appearanceManager.isDarkMode ? Color.appAccent.opacity(0.2) : Color.red.opacity(0.15))
                    .cornerRadius(8)
            }
            .padding()
            .background(appearanceManager.isDarkMode ? Color.appBackground.opacity(0.95) : Color(UIColor.systemBackground).opacity(0.95))
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
        .background(appearanceManager.isDarkMode ? Color.appSurface : Color.white)
    }

    // MARK: - Orders List
    private var ordersList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.filteredOrders) { order in
                    HStack(spacing: 12) {
                        // Selection checkbox (only in selection mode)
                        if viewModel.isSelectionMode {
                            Button(action: { viewModel.toggleSelection(orderId: order.id) }) {
                                Image(systemName: viewModel.isSelected(orderId: order.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundColor(viewModel.isSelected(orderId: order.id) ? (appearanceManager.isDarkMode ? Color.appAccent : .red) : Color.appTextSecondary)
                            }
                        }

                        OrderCard(order: order)
                            .onTapGesture {
                                if viewModel.isSelectionMode {
                                    viewModel.toggleSelection(orderId: order.id)
                                } else {
                                    viewModel.selectOrder(order)
                                }
                            }
                            .onLongPressGesture {
                                if !viewModel.isSelectionMode {
                                    viewModel.toggleSelectionMode()
                                    viewModel.toggleSelection(orderId: order.id)
                                }
                            }
                    }
                }
            }
            .padding()
            .padding(.bottom, viewModel.hasSelection ? 80 : 0) // Make room for bulk action bar
        }
    }

    private func statusColor(for status: OrderStatus) -> Color {
        switch status {
        case .pending: return .yellow
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
    @ObservedObject private var appearanceManager = AppearanceManager.shared
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
                        .background(isSelected ? Color.appTextPrimary.opacity(0.3) : (appearanceManager.isDarkMode ? Color.appSurface2 : Color(UIColor.secondarySystemBackground)))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : (appearanceManager.isDarkMode ? Color.appSurface2 : Color(UIColor.secondarySystemBackground)))
            .foregroundColor(isSelected ? Color.appTextPrimary : Color.appTextSecondary)
            .cornerRadius(20)
        }
    }
}

// MARK: - Order Card
struct OrderCard: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared
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
                        .foregroundColor(Color.appTextSecondary)
                }

                Spacer()

                StatusBadge(orderStatus: order.status)
            }

            Divider()
                .background(appearanceManager.isDarkMode ? Color.appSurface2 : Color(UIColor.secondarySystemBackground))

            // Details
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label(order.customerEmail, systemImage: "envelope")
                        .font(.caption)
                        .foregroundColor(Color.appTextSecondary)
                        .lineLimit(1)

                    if let serviceType = order.serviceType {
                        Label(serviceType.displayName, systemImage: serviceType.icon)
                            .font(.caption)
                            .foregroundColor(appearanceManager.isDarkMode ? Color.appAccent : .red)
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
                        .background(order.placedBy == .partner ? (appearanceManager.isDarkMode ? Color.appAccent.opacity(0.2) : Color.red.opacity(0.15)) : Color.blue.opacity(0.2))
                        .foregroundColor(order.placedBy == .partner ? (appearanceManager.isDarkMode ? Color.appAccent : .red) : .blue)
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(appearanceManager.isDarkMode ? Color.appSurface : Color.white)
        .cornerRadius(16)
    }
}

// MARK: - Order Detail View
struct OrderDetailView: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared
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
            .background(appearanceManager.isDarkMode ? Color.appBackground.ignoresSafeArea() : Color(UIColor.systemGroupedBackground).ignoresSafeArea())
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
                        .foregroundColor(Color.appTextSecondary)
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
                        .foregroundColor(Color.appTextSecondary)
                }
            }
        }
        .padding()
        .background(appearanceManager.isDarkMode ? Color.appSurface : Color.white)
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
                        .background(appearanceManager.isDarkMode ? Color.appAccent : Color.red)
                        .foregroundColor(Color.appTextPrimary)
                        .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(appearanceManager.isDarkMode ? Color.appSurface : Color.white)
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
        .background(appearanceManager.isDarkMode ? Color.appSurface : Color.white)
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
                Divider().background(appearanceManager.isDarkMode ? Color.appSurface2 : Color(UIColor.secondarySystemBackground))

                InfoRow(label: "Subtotal", value: String(format: "$%.2f", totals.subtotal))
                if let discount = totals.discountAmount, discount > 0 {
                    InfoRow(label: "Discount", value: String(format: "-$%.2f", discount), valueColor: .green)
                }
                if let tax = totals.tax {
                    InfoRow(label: "Tax", value: String(format: "$%.2f", tax))
                }
                if let shipping = totals.shipping {
                    InfoRow(label: "Shipping", value: String(format: "$%.2f", shipping))
                }
            }
        }
        .padding()
        .background(appearanceManager.isDarkMode ? Color.appSurface : Color.white)
        .cornerRadius(16)
    }

    private func addressSection(address: Address, title: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            Text(address.formatted)
                .font(.subheadline)
                .foregroundColor(Color.appTextSecondary)
        }
        .padding()
        .background(appearanceManager.isDarkMode ? Color.appSurface : Color.white)
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
    var valueColor: Color = Color.appTextPrimary

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(Color.appTextSecondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(valueColor)
        }
    }
}

// MARK: - Bulk Status Picker Sheet
struct BulkStatusPickerSheet: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @ObservedObject var viewModel: OrdersViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Update \(viewModel.selectedOrdersCount) orders to:")
                    .font(.headline)
                    .padding()

                List {
                    ForEach(OrderStatus.allCases, id: \.self) { status in
                        Button(action: {
                            Task {
                                await viewModel.bulkUpdateStatus(to: status)
                                dismiss()
                            }
                        }) {
                            HStack {
                                Circle()
                                    .fill(statusColor(for: status))
                                    .frame(width: 12, height: 12)
                                Text(status.displayName)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(Color.appTextSecondary)
                            }
                        }
                        .foregroundColor(Color.appTextPrimary)
                    }
                }
                .listStyle(.plain)
            }
            .background(appearanceManager.isDarkMode ? Color.appBackground : Color(UIColor.systemBackground))
            .navigationTitle("Update Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func statusColor(for status: OrderStatus) -> Color {
        switch status {
        case .pending: return .yellow
        case .awaitingPayment: return .orange
        case .awaitingShipment: return .blue
        case .inProgress: return .purple
        case .completed: return .green
        case .cancelled: return .red
        }
    }
}

// MARK: - Export Sheet
struct ExportSheet: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    let csv: String
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "doc.text")
                    .font(.system(size: 60))
                    .foregroundColor(appearanceManager.isDarkMode ? Color.appAccent : .red)

                Text("Export Ready")
                    .font(.title2.weight(.bold))

                Text("Your orders have been exported to CSV format.")
                    .font(.subheadline)
                    .foregroundColor(Color.appTextSecondary)
                    .multilineTextAlignment(.center)

                // Preview
                ScrollView {
                    Text(csv)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(Color.appTextSecondary)
                        .padding()
                }
                .frame(maxHeight: 200)
                .background(appearanceManager.isDarkMode ? Color.appSurface : Color.white)
                .cornerRadius(12)

                Spacer()

                // Share button
                Button(action: {
                    showShareSheet = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(appearanceManager.isDarkMode ? Color.appAccent : Color.red)
                    .foregroundColor(Color.appTextPrimary)
                    .cornerRadius(12)
                }

                // Copy button
                Button(action: {
                    UIPasteboard.general.string = csv
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("Copy to Clipboard")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(appearanceManager.isDarkMode ? Color.appSurface2 : Color(UIColor.secondarySystemBackground))
                    .foregroundColor(appearanceManager.isDarkMode ? Color.appTextPrimary : .primary)
                    .cornerRadius(12)
                }
            }
            .padding()
            .background(appearanceManager.isDarkMode ? Color.appBackground : Color(UIColor.systemBackground))
            .navigationTitle("Export Orders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [csv])
            }
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview
#Preview {
    OrdersView()
}

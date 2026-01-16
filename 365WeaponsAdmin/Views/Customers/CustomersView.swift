//
//  CustomersView.swift
//  365WeaponsAdmin
//
//  Unified customers management view
//

import SwiftUI

struct CustomersView: View {
    @StateObject private var viewModel = CustomersViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Source filter bar
                sourceFilterBar

                // Stats summary
                if !viewModel.customers.isEmpty {
                    statsSummary
                }

                // Customers list
                if viewModel.isLoading && viewModel.customers.isEmpty {
                    ProgressView("Loading customers...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.filteredCustomers.isEmpty {
                    ContentUnavailableView(
                        "No Customers",
                        systemImage: "person.3.slash",
                        description: Text(viewModel.searchText.isEmpty ? "No customers found" : "No customers matching '\(viewModel.searchText)'")
                    )
                } else {
                    customersList
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Customers")
            .searchable(text: $viewModel.searchText, prompt: "Search by name, email, or phone...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: viewModel.refresh) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .refreshable {
                await viewModel.loadCustomers()
            }
            .sheet(item: $viewModel.selectedCustomer) { customer in
                CustomerDetailView(customer: customer, viewModel: viewModel)
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
            await viewModel.loadCustomers()
        }
    }

    // MARK: - Source Filter Bar
    private var sourceFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "All",
                    count: viewModel.customers.count,
                    isSelected: viewModel.selectedSource == nil,
                    action: { viewModel.filterBySource(nil) }
                )

                FilterChip(
                    title: "Orders",
                    count: viewModel.orderCustomersCount,
                    isSelected: viewModel.selectedSource == .order,
                    color: .green,
                    action: { viewModel.filterBySource(.order) }
                )

                FilterChip(
                    title: "Inquiries",
                    count: viewModel.inquiryCustomersCount,
                    isSelected: viewModel.selectedSource == .inquiry,
                    color: .blue,
                    action: { viewModel.filterBySource(.inquiry) }
                )

                FilterChip(
                    title: "Newsletter",
                    count: viewModel.newsletterCount,
                    isSelected: viewModel.selectedSource == .newsletter,
                    color: .purple,
                    action: { viewModel.filterBySource(.newsletter) }
                )

                FilterChip(
                    title: "Contact",
                    count: viewModel.contactCount,
                    isSelected: viewModel.selectedSource == .contact,
                    color: .orange,
                    action: { viewModel.filterBySource(.contact) }
                )
            }
            .padding()
        }
        .background(Color.white.opacity(0.05))
    }

    // MARK: - Stats Summary
    private var statsSummary: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Total Customers")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("\(viewModel.customers.count)")
                    .font(.title3.weight(.bold))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Total Revenue")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(viewModel.formattedTotalRevenue)
                    .font(.title3.weight(.bold))
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
    }

    // MARK: - Customers List
    private var customersList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.filteredCustomers) { customer in
                    CustomerCard(customer: customer)
                        .onTapGesture {
                            viewModel.selectCustomer(customer)
                        }
                }
            }
            .padding()
        }
    }
}

// MARK: - Customer Card
struct CustomerCard: View {
    let customer: Customer

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                // Avatar
                ZStack {
                    Circle()
                        .fill(sourceColor.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Text(customer.initials)
                        .font(.headline)
                        .foregroundColor(sourceColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(customer.name)
                        .font(.headline)
                    Text(customer.email)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    SourceBadge(source: customer.source)
                    if customer.orderCount > 0 {
                        Text("\(customer.orderCount) orders")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }

            if customer.orderCount > 0 || customer.phone != nil {
                Divider()
                    .background(Color.white.opacity(0.1))

                // Details
                HStack {
                    if let phone = customer.phone {
                        Label(phone, systemImage: "phone")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    if customer.totalSpent > 0 {
                        Text(customer.formattedTotalSpent)
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private var sourceColor: Color {
        switch customer.source {
        case .order: return .green
        case .inquiry: return .blue
        case .newsletter: return .purple
        case .contact: return .orange
        }
    }
}

// MARK: - Source Badge
struct SourceBadge: View {
    let source: CustomerSource

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: source.icon)
                .font(.caption2)
            Text(source.displayName)
                .font(.caption2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(sourceColor.opacity(0.2))
        .foregroundColor(sourceColor)
        .cornerRadius(6)
    }

    private var sourceColor: Color {
        switch source {
        case .order: return .green
        case .inquiry: return .blue
        case .newsletter: return .purple
        case .contact: return .orange
        }
    }
}

// MARK: - Customer Detail View
struct CustomerDetailView: View {
    let customer: Customer
    @ObservedObject var viewModel: CustomersViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Customer header
                    customerHeader

                    // Contact info
                    contactSection

                    // Stats
                    if customer.orderCount > 0 {
                        statsSection
                    }

                    // Order history
                    if !viewModel.customerOrders.isEmpty {
                        orderHistorySection
                    }

                    // Inquiries
                    if !viewModel.customerInquiries.isEmpty {
                        inquiriesSection
                    }
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Customer Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            await viewModel.loadCustomerDetails(customer: customer)
        }
    }

    private var customerHeader: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(sourceColor.opacity(0.2))
                    .frame(width: 80, height: 80)
                Text(customer.initials)
                    .font(.largeTitle)
                    .foregroundColor(sourceColor)
            }

            VStack(spacing: 4) {
                Text(customer.name)
                    .font(.title2.weight(.bold))
                Text(customer.email)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                SourceBadge(source: customer.source)
            }

            Text("Customer since \(customer.createdAt.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Contact Information")
                .font(.headline)

            InfoRow(label: "Email", value: customer.email)

            if let phone = customer.phone {
                InfoRow(label: "Phone", value: phone)
            }

            if let addresses = customer.addresses, !addresses.isEmpty,
               let firstAddress = addresses.first {
                InfoRow(label: "Address", value: firstAddress.formatted)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Purchase History")
                .font(.headline)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Orders")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(customer.orderCount)")
                        .font(.title2.weight(.bold))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total Spent")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(customer.formattedTotalSpent)
                        .font(.title2.weight(.bold))
                        .foregroundColor(.green)
                }
            }

            if customer.orderCount > 0 {
                HStack {
                    Text("Average Order")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(String(format: "$%.2f", customer.totalSpent / Double(customer.orderCount)))
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private var orderHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Order History")
                .font(.headline)

            ForEach(viewModel.customerOrders.prefix(10), id: \.id) { order in
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

                if order.id != viewModel.customerOrders.prefix(10).last?.id {
                    Divider().background(Color.white.opacity(0.1))
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private var inquiriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Service Inquiries")
                .font(.headline)

            ForEach(viewModel.customerInquiries.prefix(5), id: \.id) { inquiry in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(inquiry.productTitle)
                            .font(.subheadline.weight(.medium))
                        Text(inquiry.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        if let quote = inquiry.formattedQuote {
                            Text(quote)
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(.orange)
                        }
                        Text(inquiry.status.displayName)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }
                .padding(.vertical, 4)

                if inquiry.id != viewModel.customerInquiries.prefix(5).last?.id {
                    Divider().background(Color.white.opacity(0.1))
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private var sourceColor: Color {
        switch customer.source {
        case .order: return .green
        case .inquiry: return .blue
        case .newsletter: return .purple
        case .contact: return .orange
        }
    }
}

// MARK: - Preview
#Preview {
    CustomersView()
}

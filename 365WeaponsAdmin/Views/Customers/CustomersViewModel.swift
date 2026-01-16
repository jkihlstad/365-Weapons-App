//
//  CustomersViewModel.swift
//  365WeaponsAdmin
//
//  ViewModel for unified customer management
//

import Foundation
import Combine

@MainActor
class CustomersViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var customers: [Customer] = []
    @Published var filteredCustomers: [Customer] = []
    @Published var selectedCustomer: Customer?
    @Published var customerOrders: [Order] = []
    @Published var customerInquiries: [ServiceInquiry] = []
    @Published var isLoading = false
    @Published var searchText = ""
    @Published var selectedSource: CustomerSource?
    @Published var error: AppError?

    // MARK: - Dependencies
    private let convex = ConvexClient.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties
    var hasError: Bool {
        error != nil
    }

    var orderCustomersCount: Int {
        customers.filter { $0.source == .order }.count
    }

    var inquiryCustomersCount: Int {
        customers.filter { $0.source == .inquiry }.count
    }

    var newsletterCount: Int {
        customers.filter { $0.source == .newsletter }.count
    }

    var contactCount: Int {
        customers.filter { $0.source == .contact }.count
    }

    var totalRevenue: Double {
        customers.reduce(0) { $0 + $1.totalSpent }
    }

    var formattedTotalRevenue: String {
        String(format: "$%.2f", totalRevenue)
    }

    // MARK: - Initialization
    init() {
        setupBindings()
    }

    private func setupBindings() {
        Publishers.CombineLatest($searchText, $selectedSource)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] searchText, source in
                self?.applyFilters(searchText: searchText, source: source)
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Loading
    func loadCustomers() async {
        isLoading = true
        error = nil

        do {
            customers = try await aggregateCustomers()
            applyFilters(searchText: searchText, source: selectedSource)
        } catch {
            self.error = AppError.from(error)
        }

        isLoading = false
    }

    func loadCustomerDetails(customer: Customer) async {
        isLoading = true
        error = nil

        do {
            // Load customer orders
            let allOrders = try await convex.fetchOrders(limit: 500)
            customerOrders = allOrders.filter { $0.customerEmail.lowercased() == customer.email.lowercased() }

            // Load customer inquiries
            if let inquiries = try? await convex.fetchInquiries() {
                customerInquiries = inquiries.filter { $0.customerEmail.lowercased() == customer.email.lowercased() }
            }
        } catch {
            self.error = AppError.from(error)
        }

        isLoading = false
    }

    // MARK: - Customer Aggregation
    private func aggregateCustomers() async throws -> [Customer] {
        var customerMap: [String: Customer] = [:]

        // 1. Get customers from orders
        let orders = try await convex.fetchOrders(limit: 1000)
        for order in orders {
            let email = order.customerEmail.lowercased()
            if email.isEmpty || email == "unknown" { continue }

            let name = order.endCustomerInfo?.name ?? order.billingAddress?.contactName ?? email.components(separatedBy: "@").first ?? "Unknown"
            let phone = order.endCustomerInfo?.phone ?? order.billingAddress?.phone

            if let existing = customerMap[email] {
                let updatedCustomer = Customer(
                    id: existing.id,
                    name: existing.name.isEmpty ? name : existing.name,
                    email: email,
                    phone: existing.phone ?? phone,
                    source: existing.source,
                    orderCount: existing.orderCount + 1,
                    totalSpent: existing.totalSpent + (order.totals?.total ?? 0),
                    lastActivity: max(existing.lastActivity, order.createdAt),
                    addresses: existing.addresses,
                    createdAt: min(existing.createdAt, order.createdAt)
                )
                customerMap[email] = updatedCustomer
            } else {
                let customer = Customer(
                    id: "order_\(email)",
                    name: name,
                    email: email,
                    phone: phone,
                    source: .order,
                    orderCount: 1,
                    totalSpent: order.totals?.total ?? 0,
                    lastActivity: order.createdAt,
                    addresses: [order.billingAddress, order.returnShippingAddressSnapshot].compactMap { $0 },
                    createdAt: order.createdAt
                )
                customerMap[email] = customer
            }
        }

        // 2. Get customers from inquiries
        if let inquiries = try? await convex.fetchInquiries() {
            for inquiry in inquiries {
                let email = inquiry.customerEmail.lowercased()
                if email.isEmpty { continue }

                if customerMap[email] == nil {
                    let customer = Customer(
                        id: "inquiry_\(email)",
                        name: inquiry.customerName,
                        email: email,
                        phone: inquiry.customerPhone,
                        source: .inquiry,
                        orderCount: 0,
                        totalSpent: 0,
                        lastActivity: inquiry.createdAt,
                        addresses: nil,
                        createdAt: inquiry.createdAt
                    )
                    customerMap[email] = customer
                }
            }
        }

        // 3. Get newsletter subscribers
        if let subscribers = try? await convex.fetchNewsletterSubscribers() {
            for subscriber in subscribers {
                let email = subscriber.email.lowercased()
                if email.isEmpty { continue }

                if customerMap[email] == nil {
                    let customer = Customer(
                        id: "newsletter_\(email)",
                        name: subscriber.fullName.isEmpty ? email.components(separatedBy: "@").first ?? "Subscriber" : subscriber.fullName,
                        email: email,
                        phone: subscriber.phone,
                        source: .newsletter,
                        orderCount: 0,
                        totalSpent: 0,
                        lastActivity: subscriber.subscribedAt,
                        addresses: nil,
                        createdAt: subscriber.subscribedAt
                    )
                    customerMap[email] = customer
                }
            }
        }

        // 4. Get contact form submissions
        if let contacts = try? await convex.fetchContactSubmissions() {
            for contact in contacts {
                let email = contact.email.lowercased()
                if email.isEmpty { continue }

                if customerMap[email] == nil {
                    let customer = Customer(
                        id: "contact_\(email)",
                        name: contact.name,
                        email: email,
                        phone: contact.phone,
                        source: .contact,
                        orderCount: 0,
                        totalSpent: 0,
                        lastActivity: contact.createdAt,
                        addresses: nil,
                        createdAt: contact.createdAt
                    )
                    customerMap[email] = customer
                }
            }
        }

        return Array(customerMap.values).sorted { $0.lastActivity > $1.lastActivity }
    }

    // MARK: - Filtering
    private func applyFilters(searchText: String, source: CustomerSource?) {
        var result = customers

        // Apply search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                $0.email.lowercased().contains(query) ||
                ($0.phone?.contains(query) ?? false)
            }
        }

        // Apply source filter
        if let source = source {
            result = result.filter { $0.source == source }
        }

        filteredCustomers = result
    }

    func filterBySource(_ source: CustomerSource?) {
        selectedSource = source
    }

    // MARK: - Actions
    func selectCustomer(_ customer: Customer) {
        selectedCustomer = customer
    }

    func refresh() {
        Task {
            await loadCustomers()
        }
    }

    func clearError() {
        error = nil
    }

    func retry() {
        refresh()
    }
}

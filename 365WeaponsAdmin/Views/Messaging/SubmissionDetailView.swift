//
//  SubmissionDetailView.swift
//  365WeaponsAdmin
//
//  Detailed view for individual submissions with all submitted data
//

import SwiftUI

struct SubmissionDetailView: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    let submission: UnifiedSubmission
    @Environment(\.dismiss) private var dismiss
    @State private var showCustomerProfile = false
    @State private var showPhoneActions = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header card
                    headerCard

                    // Type-specific content
                    switch submission.type {
                    case .inquiry:
                        if let inquiry = submission.inquiry {
                            InquiryDetailContent(inquiry: inquiry)
                        }
                    case .vendorSignup:
                        if let vendor = submission.vendor {
                            VendorDetailContent(vendor: vendor)
                        }
                    case .contact:
                        if let contact = submission.contact {
                            ContactDetailContent(contact: contact)
                        }
                    case .newsletter:
                        if let newsletter = submission.newsletter {
                            NewsletterDetailContent(newsletter: newsletter)
                        }
                    }

                    // Quick actions
                    quickActions
                }
                .padding()
            }
            .background(appearanceManager.isDarkMode ? Color.black.ignoresSafeArea() : Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(submission.type.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showCustomerProfile = true
                        } label: {
                            Label("View Profile", systemImage: "person")
                        }

                        Button {
                            copyToClipboard(submission.email)
                        } label: {
                            Label("Copy Email", systemImage: "doc.on.doc")
                        }

                        if let phone = submission.phone {
                            Button {
                                copyToClipboard(phone)
                            } label: {
                                Label("Copy Phone", systemImage: "phone")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showCustomerProfile) {
                CustomerProfileSheet(email: submission.email, name: submission.name)
            }
            .confirmationDialog("Contact Options", isPresented: $showPhoneActions, titleVisibility: .visible) {
                if let phone = submission.phone {
                    Button("Call") {
                        if let url = URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: ""))") {
                            UIApplication.shared.open(url)
                        }
                    }
                    Button("Send Message") {
                        if let url = URL(string: "sms:\(phone.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: ""))") {
                            UIApplication.shared.open(url)
                        }
                    }
                    Button("Add to Contacts") {
                        if let url = URL(string: "contacts://") {
                            UIApplication.shared.open(url)
                        }
                    }
                    Button("Copy Phone Number") {
                        UIPasteboard.general.string = phone
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: 16) {
            // Icon and type
            ZStack {
                Circle()
                    .fill(colorForType.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: submission.type.icon)
                    .font(.system(size: 32))
                    .foregroundColor(colorForType)
            }

            // Name and status
            VStack(spacing: 8) {
                Text(submission.name)
                    .font(.title2.bold())

                HStack {
                    SubmissionStatusBadge(status: submission.status, type: submission.type)

                    if submission.isNew {
                        Text("NEW")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(appearanceManager.isDarkMode ? Color.orange : Color.red)
                            .cornerRadius(6)
                    }
                }

                Text("Submitted \(submission.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            // Contact info
            HStack(spacing: 20) {
                if !submission.email.isEmpty {
                    Button {
                        if let url = URL(string: "mailto:\(submission.email)") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        VStack {
                            Image(systemName: "envelope.fill")
                                .font(.title3)
                            Text("Email")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                    }
                }

                if let _ = submission.phone, !submission.phone!.isEmpty {
                    Button {
                        showPhoneActions = true
                    } label: {
                        VStack {
                            Image(systemName: "phone.fill")
                                .font(.title3)
                            Text("Call")
                                .font(.caption)
                        }
                        .foregroundColor(.green)
                    }
                }

                Button {
                    showCustomerProfile = true
                } label: {
                    VStack {
                        Image(systemName: "person.fill")
                            .font(.title3)
                        Text("Profile")
                            .font(.caption)
                    }
                    .foregroundColor(.purple)
                }
            }
            .padding(.top, 8)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(appearanceManager.isDarkMode ? Color.white.opacity(0.05) : Color.white)
        .cornerRadius(16)
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Quick Actions")

            HStack(spacing: 12) {
                SubmissionActionButton(
                    title: "View Profile",
                    icon: "person.circle",
                    color: .purple
                ) {
                    showCustomerProfile = true
                }

                SubmissionActionButton(
                    title: "Send Email",
                    icon: "envelope",
                    color: .blue
                ) {
                    if let url = URL(string: "mailto:\(submission.email)") {
                        UIApplication.shared.open(url)
                    }
                }

                if submission.phone != nil {
                    SubmissionActionButton(
                        title: "Call",
                        icon: "phone",
                        color: .green
                    ) {
                        showPhoneActions = true
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var colorForType: Color {
        switch submission.type {
        case .inquiry: return .blue
        case .vendorSignup: return .purple
        case .contact: return appearanceManager.isDarkMode ? .orange : .red
        case .newsletter: return .green
        }
    }

    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
    }
}

// MARK: - Inquiry Detail Content

struct InquiryDetailContent: View {
    let inquiry: ServiceInquiry

    var body: some View {
        VStack(spacing: 16) {
            // Contact Information
            DetailSection(title: "Contact Information") {
                DetailRow(label: "Name", value: inquiry.customerName)
                DetailRow(label: "Email", value: inquiry.customerEmail)
                if let phone = inquiry.customerPhone {
                    DetailRow(label: "Phone", value: phone)
                }
            }

            // Service Details
            DetailSection(title: "Service Details") {
                DetailRow(label: "Service Type", value: inquiry.serviceType)
                DetailRow(label: "Product", value: inquiry.productTitle)
                DetailRow(label: "Product Slug", value: inquiry.productSlug)
                DetailRow(label: "Status", value: inquiry.status.displayName)
                if let quote = inquiry.formattedQuote {
                    DetailRow(label: "Quoted Amount", value: quote)
                }
            }

            // Message
            if let message = inquiry.message, !message.isEmpty {
                DetailSection(title: "Message") {
                    Text(message)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            // Admin Notes
            if let notes = inquiry.adminNotes, !notes.isEmpty {
                DetailSection(title: "Admin Notes") {
                    Text(notes)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            // Timestamps
            DetailSection(title: "Timeline") {
                DetailRow(label: "Created", value: inquiry.createdAt.formatted(date: .abbreviated, time: .shortened))
                DetailRow(label: "Last Updated", value: inquiry.updatedAt.formatted(date: .abbreviated, time: .shortened))
            }
        }
    }
}

// MARK: - Vendor Detail Content

struct VendorDetailContent: View {
    let vendor: PartnerStore

    var body: some View {
        VStack(spacing: 16) {
            // Store Information
            DetailSection(title: "Store Information") {
                DetailRow(label: "Store Name", value: vendor.storeName)
                DetailRow(label: "Store Code", value: vendor.storeCode)
                DetailRow(label: "Status", value: vendor.active ? "Active" : "Inactive")
                DetailRow(label: "Onboarding", value: vendor.onboardingComplete ? "Complete" : "Pending")
            }

            // Contact Information
            DetailSection(title: "Contact Information") {
                DetailRow(label: "Contact Name", value: vendor.storeContactName)
                DetailRow(label: "Email", value: vendor.storeEmail)
                DetailRow(label: "Phone", value: vendor.storePhone)
            }

            // Commission Settings
            DetailSection(title: "Commission Settings") {
                DetailRow(label: "Commission Type", value: vendor.commissionType.rawValue.capitalized)
                DetailRow(label: "Commission Value", value: vendor.formattedCommission)
                DetailRow(label: "Payout Method", value: vendor.payoutMethod.capitalized)
                DetailRow(label: "PayPal Email", value: vendor.paypalEmail)
                DetailRow(label: "Payout Hold Days", value: "\(vendor.payoutHoldDays) days")
            }

            // Return Address
            if let address = vendor.storeReturnAddress {
                DetailSection(title: "Return Address") {
                    if let name = address.name ?? address.fullName {
                        DetailRow(label: "Name", value: name)
                    }
                    if let street = address.street ?? address.addressLine1 {
                        DetailRow(label: "Street", value: street)
                    }
                    if let line2 = address.addressLine2 {
                        DetailRow(label: "Suite/Apt", value: line2)
                    }
                    if let city = address.city {
                        DetailRow(label: "City", value: city)
                    }
                    if let state = address.state {
                        DetailRow(label: "State", value: state)
                    }
                    if let zip = address.zip ?? address.zipCode {
                        DetailRow(label: "ZIP Code", value: zip)
                    }
                }
            }

            // Timeline
            DetailSection(title: "Timeline") {
                DetailRow(label: "Signed Up", value: vendor.createdAt.formatted(date: .abbreviated, time: .shortened))
            }
        }
    }
}

// MARK: - Contact Detail Content

struct ContactDetailContent: View {
    let contact: ContactSubmission

    var body: some View {
        VStack(spacing: 16) {
            // Contact Information
            DetailSection(title: "Contact Information") {
                DetailRow(label: "Name", value: contact.name)
                DetailRow(label: "Email", value: contact.email)
                if let phone = contact.phone {
                    DetailRow(label: "Phone", value: phone)
                }
            }

            // Subject
            if let subject = contact.subject, !subject.isEmpty {
                DetailSection(title: "Subject") {
                    Text(subject)
                        .font(.body.weight(.medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            // Message
            DetailSection(title: "Message") {
                Text(contact.message)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Status
            DetailSection(title: "Status") {
                DetailRow(label: "Current Status", value: contact.status.displayName)
                if let respondedAt = contact.respondedAt {
                    DetailRow(label: "Responded", value: respondedAt.formatted(date: .abbreviated, time: .shortened))
                }
            }

            // Timeline
            DetailSection(title: "Timeline") {
                DetailRow(label: "Submitted", value: contact.createdAt.formatted(date: .abbreviated, time: .shortened))
            }
        }
    }
}

// MARK: - Newsletter Detail Content

struct NewsletterDetailContent: View {
    let newsletter: NewsletterSubscriber

    var body: some View {
        VStack(spacing: 16) {
            // Subscriber Information
            DetailSection(title: "Subscriber Information") {
                if let firstName = newsletter.firstName {
                    DetailRow(label: "First Name", value: firstName)
                }
                if let lastName = newsletter.lastName {
                    DetailRow(label: "Last Name", value: lastName)
                }
                DetailRow(label: "Email", value: newsletter.email)
                if let phone = newsletter.phone {
                    DetailRow(label: "Phone", value: phone)
                }
            }

            // Subscription Status
            DetailSection(title: "Subscription Status") {
                DetailRow(label: "Status", value: newsletter.isActive ? "Active" : "Unsubscribed")
                DetailRow(label: "Subscribed", value: newsletter.subscribedAt.formatted(date: .abbreviated, time: .shortened))
            }
        }
    }
}

// MARK: - Reusable Components

struct DetailSection<Content: View>: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)

            VStack(spacing: 8) {
                content
            }
            .padding()
            .background(appearanceManager.isDarkMode ? Color.white.opacity(0.05) : Color.white)
            .cornerRadius(12)
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.gray)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct SubmissionActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color.opacity(0.15))
            .cornerRadius(12)
        }
    }
}

// MARK: - Customer Profile Sheet

struct CustomerProfileSheet: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    let email: String
    let name: String
    @Environment(\.dismiss) private var dismiss
    @State private var orders: [Order] = []
    @State private var inquiries: [ServiceInquiry] = []
    @State private var isLoading = true

    private let convex = ConvexClient.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.purple.opacity(0.2))
                                .frame(width: 80, height: 80)

                            Text(initials)
                                .font(.title.bold())
                                .foregroundColor(.purple)
                        }

                        Text(name)
                            .font(.title2.bold())

                        Text(email)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding()

                    if isLoading {
                        ProgressView()
                            .padding()
                    } else {
                        // Orders section
                        if !orders.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Orders (\(orders.count))")
                                    .font(.headline)
                                    .padding(.horizontal)

                                ForEach(orders.prefix(5)) { order in
                                    OrderMiniCard(order: order)
                                }
                            }
                        }

                        // Inquiries section
                        if !inquiries.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Service Inquiries (\(inquiries.count))")
                                    .font(.headline)
                                    .padding(.horizontal)

                                ForEach(inquiries.prefix(5)) { inquiry in
                                    InquiryMiniCard(inquiry: inquiry)
                                }
                            }
                        }

                        if orders.isEmpty && inquiries.isEmpty {
                            ContentUnavailableView(
                                "No Activity",
                                systemImage: "person.crop.circle.badge.questionmark",
                                description: Text("No orders or inquiries found for this customer")
                            )
                        }
                    }
                }
                .padding()
            }
            .background(appearanceManager.isDarkMode ? Color.black.ignoresSafeArea() : Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Customer Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadCustomerData()
            }
        }
    }

    private var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private func loadCustomerData() async {
        isLoading = true
        do {
            async let ordersTask = convex.fetchOrdersByEmail(email: email)
            async let inquiriesTask = convex.fetchInquiriesByEmail(email: email)

            let (fetchedOrders, fetchedInquiries) = try await (ordersTask, inquiriesTask)
            orders = fetchedOrders
            inquiries = fetchedInquiries
        } catch {
            print("Error loading customer data: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Mini Cards

struct OrderMiniCard: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    let order: Order

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(order.orderNumber)
                    .font(.subheadline.weight(.medium))

                Text(order.serviceType?.displayName ?? "Order")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(order.totals?.total.formatted(.currency(code: "USD")) ?? "$0.00")
                    .font(.subheadline.weight(.medium))

                Text(order.status.displayName)
                    .font(.caption)
                    .foregroundColor(order.status == .completed ? .green : (appearanceManager.isDarkMode ? .orange : .red))
            }
        }
        .padding()
        .background(appearanceManager.isDarkMode ? Color.white.opacity(0.05) : Color.white)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct InquiryMiniCard: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    let inquiry: ServiceInquiry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(inquiry.serviceType)
                    .font(.subheadline.weight(.medium))

                Text(inquiry.productTitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let quote = inquiry.formattedQuote {
                    Text(quote)
                        .font(.subheadline.weight(.medium))
                }

                Text(inquiry.status.displayName)
                    .font(.caption)
                    .foregroundColor(inquiry.status == .completed ? .green : .blue)
            }
        }
        .padding()
        .background(appearanceManager.isDarkMode ? Color.white.opacity(0.05) : Color.white)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Preview

#Preview {
    SubmissionDetailView(submission: UnifiedSubmission(
        contact: ContactSubmission(
            id: "test",
            name: "John Doe",
            email: "john@example.com",
            phone: "555-1234",
            subject: "Question about services",
            message: "I'd like to learn more about your engraving services. What's the typical turnaround time?",
            status: .new,
            emailSentToAdmin: true,
            emailSentToCustomer: true,
            createdAt: Date()
        )
    ))
}

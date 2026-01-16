//
//  MessagingViewModel.swift
//  365WeaponsAdmin
//
//  ViewModel for the Messaging tab - handles all user submissions
//

import Foundation
import Combine

// MARK: - Unified Submission Model

enum SubmissionType: String, CaseIterable, Identifiable {
    case inquiry = "Service Inquiry"
    case vendorSignup = "Vendor Application"
    case contact = "Contact Form"
    case newsletter = "Newsletter Signup"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .inquiry: return "wrench.and.screwdriver"
        case .vendorSignup: return "storefront"
        case .contact: return "envelope"
        case .newsletter: return "newspaper"
        }
    }

    var color: String {
        switch self {
        case .inquiry: return "blue"
        case .vendorSignup: return "purple"
        case .contact: return "orange"
        case .newsletter: return "green"
        }
    }
}

struct UnifiedSubmission: Identifiable {
    let id: String
    let type: SubmissionType
    let name: String
    let email: String
    let phone: String?
    let subject: String?
    let message: String?
    let status: String
    let createdAt: Date
    let isNew: Bool

    // Original data for detail view
    let inquiry: ServiceInquiry?
    let vendor: PartnerStore?
    let contact: ContactSubmission?
    let newsletter: NewsletterSubscriber?

    init(inquiry: ServiceInquiry) {
        self.id = "inquiry_\(inquiry.id)"
        self.type = .inquiry
        self.name = inquiry.customerName
        self.email = inquiry.customerEmail
        self.phone = inquiry.customerPhone
        self.subject = inquiry.serviceType
        self.message = inquiry.message
        self.status = inquiry.status.displayName
        self.createdAt = inquiry.createdAt
        self.isNew = inquiry.status == .new
        self.inquiry = inquiry
        self.vendor = nil
        self.contact = nil
        self.newsletter = nil
    }

    init(vendor: PartnerStore) {
        self.id = "vendor_\(vendor.id)"
        self.type = .vendorSignup
        self.name = vendor.storeContactName
        self.email = vendor.storeEmail
        self.phone = vendor.storePhone
        self.subject = vendor.storeName
        self.message = "Commission: \(vendor.formattedCommission)"
        self.status = vendor.onboardingComplete ? (vendor.active ? "Active" : "Inactive") : "Pending Onboarding"
        self.createdAt = vendor.createdAt
        self.isNew = !vendor.onboardingComplete
        self.inquiry = nil
        self.vendor = vendor
        self.contact = nil
        self.newsletter = nil
    }

    init(contact: ContactSubmission) {
        self.id = "contact_\(contact.id)"
        self.type = .contact
        self.name = contact.name
        self.email = contact.email
        self.phone = contact.phone
        self.subject = contact.subject
        self.message = contact.message
        self.status = contact.status.displayName
        self.createdAt = contact.createdAt
        self.isNew = contact.status == .new
        self.inquiry = nil
        self.vendor = nil
        self.contact = contact
        self.newsletter = nil
    }

    init(newsletter: NewsletterSubscriber) {
        self.id = "newsletter_\(newsletter.id)"
        self.type = .newsletter
        self.name = newsletter.fullName.isEmpty ? "Subscriber" : newsletter.fullName
        self.email = newsletter.email
        self.phone = newsletter.phone
        self.subject = nil
        self.message = nil
        self.status = newsletter.isActive ? "Active" : "Unsubscribed"
        self.createdAt = newsletter.subscribedAt
        self.isNew = Calendar.current.isDateInToday(newsletter.subscribedAt)
        self.inquiry = nil
        self.vendor = nil
        self.contact = nil
        self.newsletter = newsletter
    }
}

// MARK: - Messaging ViewModel

@MainActor
class MessagingViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var submissions: [UnifiedSubmission] = []
    @Published var filteredSubmissions: [UnifiedSubmission] = []
    @Published var isLoading = false
    @Published var error: Error?

    // Filter state
    @Published var selectedTypes: Set<SubmissionType> = Set(SubmissionType.allCases)
    @Published var searchText = ""
    @Published var showOnlyNew = false
    @Published var sortOrder: SortOrder = .newest

    // Stats
    @Published var totalCount = 0
    @Published var newCount = 0
    @Published var countByType: [SubmissionType: Int] = [:]

    enum SortOrder: String, CaseIterable {
        case newest = "Newest First"
        case oldest = "Oldest First"
        case name = "By Name"
    }

    // MARK: - Dependencies
    private let convex = ConvexClient.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init() {
        setupFilters()
    }

    private func setupFilters() {
        // Debounce search and combine with filter changes
        Publishers.CombineLatest4(
            $searchText.debounce(for: .milliseconds(300), scheduler: DispatchQueue.main),
            $selectedTypes,
            $showOnlyNew,
            $sortOrder
        )
        .sink { [weak self] searchText, types, showNew, sort in
            self?.applyFilters(searchText: searchText, types: types, showNew: showNew, sort: sort)
        }
        .store(in: &cancellables)
    }

    // MARK: - Data Loading

    func loadData() async {
        isLoading = true
        error = nil

        do {
            // Load all data in parallel
            async let inquiriesTask = convex.fetchInquiries()
            async let partnersTask = convex.fetchPartners()
            async let contactsTask = convex.fetchContactSubmissions()
            async let newsletterTask = convex.fetchNewsletterSubscribers()

            let (inquiries, partners, contacts, newsletters) = try await (
                inquiriesTask,
                partnersTask,
                contactsTask,
                newsletterTask
            )

            // Convert to unified submissions
            var allSubmissions: [UnifiedSubmission] = []

            allSubmissions.append(contentsOf: inquiries.map { UnifiedSubmission(inquiry: $0) })
            allSubmissions.append(contentsOf: partners.map { UnifiedSubmission(vendor: $0) })
            allSubmissions.append(contentsOf: contacts.map { UnifiedSubmission(contact: $0) })
            allSubmissions.append(contentsOf: newsletters.map { UnifiedSubmission(newsletter: $0) })

            submissions = allSubmissions

            // Calculate stats
            totalCount = submissions.count
            newCount = submissions.filter { $0.isNew }.count
            countByType = Dictionary(grouping: submissions, by: { $0.type }).mapValues { $0.count }

            // Apply initial filters
            applyFilters(searchText: searchText, types: selectedTypes, showNew: showOnlyNew, sort: sortOrder)

        } catch {
            self.error = error
        }

        isLoading = false
    }

    func refresh() {
        Task {
            await loadData()
        }
    }

    // MARK: - Filtering

    private func applyFilters(searchText: String, types: Set<SubmissionType>, showNew: Bool, sort: SortOrder) {
        var result = submissions

        // Filter by type
        result = result.filter { types.contains($0.type) }

        // Filter by new status
        if showNew {
            result = result.filter { $0.isNew }
        }

        // Filter by search text
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                $0.email.lowercased().contains(query) ||
                ($0.subject?.lowercased().contains(query) ?? false) ||
                ($0.message?.lowercased().contains(query) ?? false)
            }
        }

        // Sort
        switch sort {
        case .newest:
            result.sort { $0.createdAt > $1.createdAt }
        case .oldest:
            result.sort { $0.createdAt < $1.createdAt }
        case .name:
            result.sort { $0.name.lowercased() < $1.name.lowercased() }
        }

        filteredSubmissions = result
    }

    func toggleType(_ type: SubmissionType) {
        if selectedTypes.contains(type) {
            selectedTypes.remove(type)
        } else {
            selectedTypes.insert(type)
        }
    }

    func selectAllTypes() {
        selectedTypes = Set(SubmissionType.allCases)
    }

    func clearAllTypes() {
        selectedTypes = []
    }
}

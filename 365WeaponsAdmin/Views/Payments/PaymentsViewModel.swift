//
//  PaymentsViewModel.swift
//  365WeaponsAdmin
//
//  ViewModel for payment processing and history
//

import Foundation
import SwiftUI

// MARK: - Payment Method

enum PaymentMethod: String, CaseIterable, Identifiable {
    case tapToPay = "tap_to_pay"
    case manualCard = "manual_card"
    case cardOnFile = "card_on_file"
    case invoice = "invoice"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tapToPay: return "Tap to Pay"
        case .manualCard: return "Manual Entry"
        case .cardOnFile: return "Card on File"
        case .invoice: return "Send Invoice"
        }
    }

    var icon: String {
        switch self {
        case .tapToPay: return "wave.3.right"
        case .manualCard: return "creditcard"
        case .cardOnFile: return "wallet.pass"
        case .invoice: return "doc.text"
        }
    }

    var description: String {
        switch self {
        case .tapToPay: return "Accept contactless payments"
        case .manualCard: return "Enter card details manually"
        case .cardOnFile: return "Charge saved payment method"
        case .invoice: return "Email invoice to customer"
        }
    }
}

// MARK: - Payment Status

enum PaymentStatus: String, Codable {
    case pending = "pending"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
    case refunded = "refunded"
    case cancelled = "cancelled"

    var displayName: String {
        rawValue.capitalized
    }

    var color: Color {
        switch self {
        case .pending: return .orange
        case .processing: return .blue
        case .completed: return .green
        case .failed: return .red
        case .refunded: return .purple
        case .cancelled: return .gray
        }
    }

    var icon: String {
        switch self {
        case .pending: return "clock"
        case .processing: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .refunded: return "arrow.uturn.backward.circle"
        case .cancelled: return "minus.circle"
        }
    }
}

// MARK: - Card Brand

enum CardBrand: String, Codable {
    case visa = "visa"
    case mastercard = "mastercard"
    case amex = "amex"
    case discover = "discover"
    case unknown = "unknown"

    var displayName: String {
        switch self {
        case .visa: return "Visa"
        case .mastercard: return "Mastercard"
        case .amex: return "American Express"
        case .discover: return "Discover"
        case .unknown: return "Card"
        }
    }

    var icon: String {
        // Using SF Symbols for now, could use custom brand icons
        "creditcard.fill"
    }

    static func detect(from number: String) -> CardBrand {
        let cleaned = number.replacingOccurrences(of: " ", with: "")
        if cleaned.hasPrefix("4") {
            return .visa
        } else if cleaned.hasPrefix("5") || cleaned.hasPrefix("2") {
            return .mastercard
        } else if cleaned.hasPrefix("34") || cleaned.hasPrefix("37") {
            return .amex
        } else if cleaned.hasPrefix("6") {
            return .discover
        }
        return .unknown
    }
}

// MARK: - Transaction Model

struct Transaction: Identifiable, Codable {
    let id: String
    let amount: Double
    let currency: String
    let status: PaymentStatus
    let method: String
    let cardBrand: CardBrand?
    let cardLast4: String?
    let customerName: String?
    let customerEmail: String?
    let description: String?
    let createdAt: Date
    let completedAt: Date?
    let refundedAt: Date?
    let metadata: [String: String]?

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
    }

    var formattedDate: String {
        createdAt.formatted(date: .abbreviated, time: .shortened)
    }

    var cardDisplay: String {
        if let brand = cardBrand, let last4 = cardLast4 {
            return "\(brand.displayName) •••• \(last4)"
        }
        return "Card"
    }
}

// MARK: - Payments ViewModel

@MainActor
class PaymentsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var transactions: [Transaction] = []
    @Published var filteredTransactions: [Transaction] = []
    @Published var isLoading = false
    @Published var error: Error?

    // Payment form state
    @Published var paymentAmount: String = ""
    @Published var paymentDescription: String = ""
    @Published var customerName: String = ""
    @Published var customerEmail: String = ""

    // Card entry state
    @Published var cardNumber: String = ""
    @Published var expiryDate: String = ""
    @Published var cvv: String = ""
    @Published var cardholderName: String = ""
    @Published var zipCode: String = ""

    // Tap to Pay state
    @Published var isTapToPayAvailable = false
    @Published var isTapToPayActive = false
    @Published var tapToPayStatus: String = "Ready"

    // Filter state
    @Published var searchText: String = ""
    @Published var selectedStatus: PaymentStatus?
    @Published var dateRange: DateRange = .all

    // Stats
    @Published var todayTotal: Double = 0
    @Published var weekTotal: Double = 0
    @Published var monthTotal: Double = 0
    @Published var transactionCount: Int = 0

    enum DateRange: String, CaseIterable {
        case today = "Today"
        case week = "This Week"
        case month = "This Month"
        case all = "All Time"
    }

    // MARK: - Computed Properties

    var parsedAmount: Double? {
        let cleaned = paymentAmount.replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
        return Double(cleaned)
    }

    var isPaymentFormValid: Bool {
        guard let amount = parsedAmount, amount > 0 else { return false }
        return true
    }

    var isCardFormValid: Bool {
        guard isPaymentFormValid else { return false }
        let cleanedCard = cardNumber.replacingOccurrences(of: " ", with: "")
        let cleanedExpiry = expiryDate.replacingOccurrences(of: "/", with: "")

        return cleanedCard.count >= 15 &&
               cleanedExpiry.count == 4 &&
               cvv.count >= 3 &&
               !cardholderName.isEmpty
    }

    var detectedCardBrand: CardBrand {
        CardBrand.detect(from: cardNumber)
    }

    // MARK: - Initialization

    init() {
        checkTapToPayAvailability()
        loadMockData()
    }

    // MARK: - Data Loading

    func loadData() async {
        isLoading = true
        error = nil

        // TODO: Replace with actual API call
        try? await Task.sleep(nanoseconds: 500_000_000)

        loadMockData()
        calculateStats()
        applyFilters()

        isLoading = false
    }

    private func loadMockData() {
        // Mock transactions for UI development
        transactions = [
            Transaction(
                id: "txn_001",
                amount: 425.00,
                currency: "USD",
                status: .completed,
                method: "tap_to_pay",
                cardBrand: .visa,
                cardLast4: "4242",
                customerName: "John Smith",
                customerEmail: "john@example.com",
                description: "Glock 19 Slide Work",
                createdAt: Date().addingTimeInterval(-3600),
                completedAt: Date().addingTimeInterval(-3500),
                refundedAt: nil,
                metadata: nil
            ),
            Transaction(
                id: "txn_002",
                amount: 89.99,
                currency: "USD",
                status: .completed,
                method: "manual_card",
                cardBrand: .mastercard,
                cardLast4: "5555",
                customerName: "Jane Doe",
                customerEmail: "jane@example.com",
                description: "Cleaning Kit",
                createdAt: Date().addingTimeInterval(-86400),
                completedAt: Date().addingTimeInterval(-86300),
                refundedAt: nil,
                metadata: nil
            ),
            Transaction(
                id: "txn_003",
                amount: 1250.00,
                currency: "USD",
                status: .pending,
                method: "invoice",
                cardBrand: nil,
                cardLast4: nil,
                customerName: "Mike Johnson",
                customerEmail: "mike@example.com",
                description: "Custom Cerakote Job",
                createdAt: Date().addingTimeInterval(-172800),
                completedAt: nil,
                refundedAt: nil,
                metadata: nil
            ),
            Transaction(
                id: "txn_004",
                amount: 75.00,
                currency: "USD",
                status: .refunded,
                method: "tap_to_pay",
                cardBrand: .amex,
                cardLast4: "1234",
                customerName: "Sarah Wilson",
                customerEmail: "sarah@example.com",
                description: "Accessory - Refunded",
                createdAt: Date().addingTimeInterval(-259200),
                completedAt: Date().addingTimeInterval(-259100),
                refundedAt: Date().addingTimeInterval(-172800),
                metadata: nil
            ),
            Transaction(
                id: "txn_005",
                amount: 650.00,
                currency: "USD",
                status: .completed,
                method: "card_on_file",
                cardBrand: .discover,
                cardLast4: "9876",
                customerName: "Bob Brown",
                customerEmail: "bob@example.com",
                description: "Barrel Threading Service",
                createdAt: Date().addingTimeInterval(-345600),
                completedAt: Date().addingTimeInterval(-345500),
                refundedAt: nil,
                metadata: nil
            )
        ]
    }

    private func calculateStats() {
        let now = Date()
        let calendar = Calendar.current

        let todayStart = calendar.startOfDay(for: now)
        let weekStart = calendar.date(byAdding: .day, value: -7, to: now)!
        let monthStart = calendar.date(byAdding: .month, value: -1, to: now)!

        let completedTransactions = transactions.filter { $0.status == .completed }

        todayTotal = completedTransactions
            .filter { $0.createdAt >= todayStart }
            .reduce(0) { $0 + $1.amount }

        weekTotal = completedTransactions
            .filter { $0.createdAt >= weekStart }
            .reduce(0) { $0 + $1.amount }

        monthTotal = completedTransactions
            .filter { $0.createdAt >= monthStart }
            .reduce(0) { $0 + $1.amount }

        transactionCount = transactions.count
    }

    // MARK: - Filtering

    func applyFilters() {
        var result = transactions

        // Filter by status
        if let status = selectedStatus {
            result = result.filter { $0.status == status }
        }

        // Filter by date range
        let now = Date()
        let calendar = Calendar.current

        switch dateRange {
        case .today:
            let start = calendar.startOfDay(for: now)
            result = result.filter { $0.createdAt >= start }
        case .week:
            let start = calendar.date(byAdding: .day, value: -7, to: now)!
            result = result.filter { $0.createdAt >= start }
        case .month:
            let start = calendar.date(byAdding: .month, value: -1, to: now)!
            result = result.filter { $0.createdAt >= start }
        case .all:
            break
        }

        // Filter by search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.customerName?.lowercased().contains(query) == true ||
                $0.customerEmail?.lowercased().contains(query) == true ||
                $0.description?.lowercased().contains(query) == true ||
                $0.cardLast4?.contains(query) == true
            }
        }

        filteredTransactions = result
    }

    // MARK: - Tap to Pay

    func checkTapToPayAvailability() {
        // TODO: Check actual device capability
        // For now, simulate availability on newer devices
        #if targetEnvironment(simulator)
        isTapToPayAvailable = true // Allow testing in simulator
        #else
        // Check for NFC capability and iOS 16.4+
        if #available(iOS 16.4, *) {
            isTapToPayAvailable = true
        } else {
            isTapToPayAvailable = false
        }
        #endif
    }

    func startTapToPay() async -> Bool {
        guard isTapToPayAvailable else { return false }
        guard let amount = parsedAmount, amount > 0 else { return false }

        isTapToPayActive = true
        tapToPayStatus = "Waiting for card..."

        // TODO: Implement actual Tap to Pay SDK integration
        // This is a mock implementation

        // Simulate waiting for tap
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        tapToPayStatus = "Processing..."

        // Simulate processing
        try? await Task.sleep(nanoseconds: 1_500_000_000)

        // Mock success
        let newTransaction = Transaction(
            id: "txn_\(UUID().uuidString.prefix(8))",
            amount: amount,
            currency: "USD",
            status: .completed,
            method: "tap_to_pay",
            cardBrand: .visa,
            cardLast4: "4242",
            customerName: customerName.isEmpty ? nil : customerName,
            customerEmail: customerEmail.isEmpty ? nil : customerEmail,
            description: paymentDescription.isEmpty ? nil : paymentDescription,
            createdAt: Date(),
            completedAt: Date(),
            refundedAt: nil,
            metadata: nil
        )

        transactions.insert(newTransaction, at: 0)
        calculateStats()
        applyFilters()

        isTapToPayActive = false
        tapToPayStatus = "Payment Complete!"

        // Reset form
        clearPaymentForm()

        return true
    }

    func cancelTapToPay() {
        isTapToPayActive = false
        tapToPayStatus = "Cancelled"
    }

    // MARK: - Manual Card Payment

    func processManualCardPayment() async -> Bool {
        guard isCardFormValid else { return false }
        guard let amount = parsedAmount else { return false }

        isLoading = true

        // TODO: Implement actual payment processing
        // This is a mock implementation

        try? await Task.sleep(nanoseconds: 2_000_000_000)

        let cleanedCard = cardNumber.replacingOccurrences(of: " ", with: "")
        let last4 = String(cleanedCard.suffix(4))

        let newTransaction = Transaction(
            id: "txn_\(UUID().uuidString.prefix(8))",
            amount: amount,
            currency: "USD",
            status: .completed,
            method: "manual_card",
            cardBrand: detectedCardBrand,
            cardLast4: last4,
            customerName: cardholderName,
            customerEmail: customerEmail.isEmpty ? nil : customerEmail,
            description: paymentDescription.isEmpty ? nil : paymentDescription,
            createdAt: Date(),
            completedAt: Date(),
            refundedAt: nil,
            metadata: nil
        )

        transactions.insert(newTransaction, at: 0)
        calculateStats()
        applyFilters()

        isLoading = false

        // Reset forms
        clearPaymentForm()
        clearCardForm()

        return true
    }

    // MARK: - Invoice

    func sendInvoice() async -> Bool {
        guard isPaymentFormValid else { return false }
        guard !customerEmail.isEmpty else { return false }
        guard let amount = parsedAmount else { return false }

        isLoading = true

        // TODO: Implement actual invoice sending
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        let newTransaction = Transaction(
            id: "txn_\(UUID().uuidString.prefix(8))",
            amount: amount,
            currency: "USD",
            status: .pending,
            method: "invoice",
            cardBrand: nil,
            cardLast4: nil,
            customerName: customerName.isEmpty ? nil : customerName,
            customerEmail: customerEmail,
            description: paymentDescription.isEmpty ? nil : paymentDescription,
            createdAt: Date(),
            completedAt: nil,
            refundedAt: nil,
            metadata: nil
        )

        transactions.insert(newTransaction, at: 0)
        calculateStats()
        applyFilters()

        isLoading = false
        clearPaymentForm()

        return true
    }

    // MARK: - Refund

    func refundTransaction(_ transaction: Transaction) async -> Bool {
        guard transaction.status == .completed else { return false }

        isLoading = true

        // TODO: Implement actual refund processing
        try? await Task.sleep(nanoseconds: 1_500_000_000)

        if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
            let updated = Transaction(
                id: transaction.id,
                amount: transaction.amount,
                currency: transaction.currency,
                status: .refunded,
                method: transaction.method,
                cardBrand: transaction.cardBrand,
                cardLast4: transaction.cardLast4,
                customerName: transaction.customerName,
                customerEmail: transaction.customerEmail,
                description: transaction.description,
                createdAt: transaction.createdAt,
                completedAt: transaction.completedAt,
                refundedAt: Date(),
                metadata: transaction.metadata
            )
            transactions[index] = updated
        }

        calculateStats()
        applyFilters()
        isLoading = false

        return true
    }

    // MARK: - Form Helpers

    func clearPaymentForm() {
        paymentAmount = ""
        paymentDescription = ""
        customerName = ""
        customerEmail = ""
    }

    func clearCardForm() {
        cardNumber = ""
        expiryDate = ""
        cvv = ""
        cardholderName = ""
        zipCode = ""
    }

    func formatCardNumber(_ number: String) -> String {
        let cleaned = number.replacingOccurrences(of: " ", with: "")
        var formatted = ""
        for (index, char) in cleaned.enumerated() {
            if index > 0 && index % 4 == 0 {
                formatted += " "
            }
            formatted += String(char)
        }
        return String(formatted.prefix(19)) // Max 16 digits + 3 spaces
    }

    func formatExpiryDate(_ date: String) -> String {
        let cleaned = date.replacingOccurrences(of: "/", with: "")
        if cleaned.count >= 2 {
            let month = String(cleaned.prefix(2))
            let year = String(cleaned.dropFirst(2).prefix(2))
            return year.isEmpty ? month : "\(month)/\(year)"
        }
        return cleaned
    }
}

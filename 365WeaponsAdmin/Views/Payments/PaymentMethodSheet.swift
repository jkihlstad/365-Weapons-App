//
//  PaymentMethodSheet.swift
//  365WeaponsAdmin
//
//  Sheet views for different payment methods
//

import SwiftUI

struct PaymentMethodSheet: View {
    let method: PaymentMethod
    @ObservedObject var viewModel: PaymentsViewModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var appearanceManager = AppearanceManager.shared

    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Group {
                switch method {
                case .tapToPay:
                    TapToPayView(viewModel: viewModel, onComplete: handleComplete)
                case .manualCard:
                    ManualCardEntryView(viewModel: viewModel, onComplete: handleComplete)
                case .cardOnFile:
                    CardOnFileView(viewModel: viewModel, onComplete: handleComplete)
                case .invoice:
                    SendInvoiceView(viewModel: viewModel, onComplete: handleComplete)
                }
            }
            .navigationTitle(method.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Payment Successful", isPresented: $showSuccess) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("The payment has been processed successfully.")
            }
            .alert("Payment Failed", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func handleComplete(success: Bool, error: String?) {
        if success {
            showSuccess = true
        } else {
            errorMessage = error ?? "An unknown error occurred"
            showError = true
        }
    }
}

// MARK: - Tap to Pay View

struct TapToPayView: View {
    @ObservedObject var viewModel: PaymentsViewModel
    let onComplete: (Bool, String?) -> Void

    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @State private var isProcessing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Amount Entry
                PaymentAmountSection(viewModel: viewModel)

                // Customer Info (Optional)
                CustomerInfoSection(viewModel: viewModel, emailRequired: false)

                // Tap to Pay Visual
                if isProcessing {
                    TapToPayActiveView(viewModel: viewModel)
                } else {
                    TapToPayReadyView()
                }

                Spacer(minLength: 20)

                // Action Button
                if isProcessing {
                    Button("Cancel") {
                        viewModel.cancelTapToPay()
                        isProcessing = false
                    }
                    .foregroundColor(.red)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                } else {
                    Button {
                        startTapToPay()
                    } label: {
                        HStack {
                            Image(systemName: "wave.3.right")
                            Text("Start Tap to Pay")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(viewModel.isPaymentFormValid ? Color.orange : Color.gray)
                        .cornerRadius(12)
                    }
                    .disabled(!viewModel.isPaymentFormValid)
                }
            }
            .padding()
        }
        .background(appearanceManager.isDarkMode ? Color.black.ignoresSafeArea() : Color(UIColor.systemGroupedBackground).ignoresSafeArea())
    }

    private func startTapToPay() {
        isProcessing = true
        Task {
            let success = await viewModel.startTapToPay()
            isProcessing = false
            onComplete(success, success ? nil : "Payment was not completed")
        }
    }
}

// MARK: - Tap to Pay Ready View

struct TapToPayReadyView: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.orange.opacity(0.3), lineWidth: 4)
                    .frame(width: 120, height: 120)

                Circle()
                    .stroke(Color.orange.opacity(0.2), lineWidth: 2)
                    .frame(width: 150, height: 150)

                Image(systemName: "wave.3.right")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
            }
            .padding()

            Text("Ready for Tap to Pay")
                .font(.headline)
                .foregroundColor(appearanceManager.isDarkMode ? .white : .primary)

            Text("Enter amount and tap 'Start' to begin accepting payment")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(appearanceManager.isDarkMode ? Color.white.opacity(0.05) : Color.white)
        .cornerRadius(16)
    }
}

// MARK: - Tap to Pay Active View

struct TapToPayActiveView: View {
    @ObservedObject var viewModel: PaymentsViewModel
    @ObservedObject private var appearanceManager = AppearanceManager.shared

    @State private var animationAmount: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Animated rings
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.orange.opacity(0.3 - Double(i) * 0.1), lineWidth: 2)
                        .frame(width: 120 + CGFloat(i) * 40, height: 120 + CGFloat(i) * 40)
                        .scaleEffect(animationAmount)
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.2),
                            value: animationAmount
                        )
                }

                Image(systemName: "creditcard.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
            }
            .onAppear {
                animationAmount = 1.2
            }

            Text(viewModel.tapToPayStatus)
                .font(.headline)
                .foregroundColor(appearanceManager.isDarkMode ? .white : .primary)

            if let amount = viewModel.parsedAmount {
                Text(formatCurrency(amount))
                    .font(.title.bold())
                    .foregroundColor(.orange)
            }

            Text("Hold card near device")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(appearanceManager.isDarkMode ? Color.white.opacity(0.05) : Color.white)
        .cornerRadius(16)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

// MARK: - Manual Card Entry View

struct ManualCardEntryView: View {
    @ObservedObject var viewModel: PaymentsViewModel
    let onComplete: (Bool, String?) -> Void

    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @FocusState private var focusedField: CardField?

    enum CardField {
        case number, expiry, cvv, name, zip
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Amount Entry
                PaymentAmountSection(viewModel: viewModel)

                // Card Entry
                VStack(alignment: .leading, spacing: 16) {
                    Text("Card Information")
                        .font(.headline)
                        .foregroundColor(appearanceManager.isDarkMode ? .white : .primary)

                    // Card Number
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Card Number")
                            .font(.caption)
                            .foregroundColor(.gray)

                        HStack {
                            TextField("1234 5678 9012 3456", text: $viewModel.cardNumber)
                                .keyboardType(.numberPad)
                                .focused($focusedField, equals: .number)
                                .onChange(of: viewModel.cardNumber) { _, newValue in
                                    viewModel.cardNumber = viewModel.formatCardNumber(newValue)
                                }

                            Image(systemName: viewModel.detectedCardBrand.icon)
                                .foregroundColor(viewModel.cardNumber.isEmpty ? .gray : .orange)
                        }
                        .padding()
                        .background(appearanceManager.isDarkMode ? Color.white.opacity(0.1) : Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                    }

                    // Expiry and CVV
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Expiry")
                                .font(.caption)
                                .foregroundColor(.gray)

                            TextField("MM/YY", text: $viewModel.expiryDate)
                                .keyboardType(.numberPad)
                                .focused($focusedField, equals: .expiry)
                                .onChange(of: viewModel.expiryDate) { _, newValue in
                                    viewModel.expiryDate = viewModel.formatExpiryDate(newValue)
                                }
                                .padding()
                                .background(appearanceManager.isDarkMode ? Color.white.opacity(0.1) : Color(UIColor.secondarySystemBackground))
                                .cornerRadius(10)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("CVV")
                                .font(.caption)
                                .foregroundColor(.gray)

                            SecureField("123", text: $viewModel.cvv)
                                .keyboardType(.numberPad)
                                .focused($focusedField, equals: .cvv)
                                .onChange(of: viewModel.cvv) { _, newValue in
                                    viewModel.cvv = String(newValue.prefix(4))
                                }
                                .padding()
                                .background(appearanceManager.isDarkMode ? Color.white.opacity(0.1) : Color(UIColor.secondarySystemBackground))
                                .cornerRadius(10)
                        }
                    }

                    // Cardholder Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cardholder Name")
                            .font(.caption)
                            .foregroundColor(.gray)

                        TextField("John Smith", text: $viewModel.cardholderName)
                            .textContentType(.name)
                            .focused($focusedField, equals: .name)
                            .padding()
                            .background(appearanceManager.isDarkMode ? Color.white.opacity(0.1) : Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                    }

                    // ZIP Code
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ZIP Code")
                            .font(.caption)
                            .foregroundColor(.gray)

                        TextField("12345", text: $viewModel.zipCode)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .zip)
                            .onChange(of: viewModel.zipCode) { _, newValue in
                                viewModel.zipCode = String(newValue.prefix(5))
                            }
                            .padding()
                            .background(appearanceManager.isDarkMode ? Color.white.opacity(0.1) : Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                    }
                }
                .padding()
                .background(appearanceManager.isDarkMode ? Color.white.opacity(0.05) : Color.white)
                .cornerRadius(12)

                // Customer Info
                CustomerInfoSection(viewModel: viewModel, emailRequired: false)

                Spacer(minLength: 20)

                // Process Button
                Button {
                    processPayment()
                } label: {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "creditcard")
                            Text("Process Payment")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(viewModel.isCardFormValid ? Color.orange : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(!viewModel.isCardFormValid || viewModel.isLoading)

                // Security Note
                HStack {
                    Image(systemName: "lock.shield")
                        .foregroundColor(.green)
                    Text("Payments are processed securely")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding()
        }
        .background(appearanceManager.isDarkMode ? Color.black.ignoresSafeArea() : Color(UIColor.systemGroupedBackground).ignoresSafeArea())
    }

    private func processPayment() {
        focusedField = nil
        Task {
            let success = await viewModel.processManualCardPayment()
            onComplete(success, success ? nil : "Payment processing failed")
        }
    }
}

// MARK: - Card on File View

struct CardOnFileView: View {
    @ObservedObject var viewModel: PaymentsViewModel
    let onComplete: (Bool, String?) -> Void

    @ObservedObject private var appearanceManager = AppearanceManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Amount Entry
                PaymentAmountSection(viewModel: viewModel)

                // Saved Cards (Mock)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Saved Payment Methods")
                        .font(.headline)
                        .foregroundColor(appearanceManager.isDarkMode ? .white : .primary)

                    // Mock saved cards
                    SavedCardRow(brand: .visa, last4: "4242", isSelected: true)
                    SavedCardRow(brand: .mastercard, last4: "5555", isSelected: false)
                }

                // Customer Search
                CustomerInfoSection(viewModel: viewModel, emailRequired: true)

                Spacer(minLength: 20)

                // Charge Button
                Button {
                    // TODO: Implement
                    onComplete(false, "Card on file not yet implemented")
                } label: {
                    HStack {
                        Image(systemName: "creditcard.fill")
                        Text("Charge Card on File")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange)
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .background(appearanceManager.isDarkMode ? Color.black.ignoresSafeArea() : Color(UIColor.systemGroupedBackground).ignoresSafeArea())
    }
}

// MARK: - Saved Card Row

struct SavedCardRow: View {
    let brand: CardBrand
    let last4: String
    let isSelected: Bool

    @ObservedObject private var appearanceManager = AppearanceManager.shared

    var body: some View {
        HStack {
            Image(systemName: brand.icon)
                .foregroundColor(.orange)

            Text("\(brand.displayName) •••• \(last4)")
                .foregroundColor(appearanceManager.isDarkMode ? .white : .primary)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(appearanceManager.isDarkMode ? Color.white.opacity(0.05) : Color.white)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Send Invoice View

struct SendInvoiceView: View {
    @ObservedObject var viewModel: PaymentsViewModel
    let onComplete: (Bool, String?) -> Void

    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @State private var dueDate = Date().addingTimeInterval(7 * 24 * 60 * 60) // 7 days from now
    @State private var includeShipping = false
    @State private var notes = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Amount Entry
                PaymentAmountSection(viewModel: viewModel)

                // Customer Info (Required)
                CustomerInfoSection(viewModel: viewModel, emailRequired: true)

                // Invoice Details
                VStack(alignment: .leading, spacing: 16) {
                    Text("Invoice Details")
                        .font(.headline)
                        .foregroundColor(appearanceManager.isDarkMode ? .white : .primary)

                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.caption)
                            .foregroundColor(.gray)

                        TextField("Invoice for...", text: $viewModel.paymentDescription)
                            .padding()
                            .background(appearanceManager.isDarkMode ? Color.white.opacity(0.1) : Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                    }

                    // Due Date
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                        .tint(.orange)

                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Additional Notes")
                            .font(.caption)
                            .foregroundColor(.gray)

                        TextEditor(text: $notes)
                            .frame(minHeight: 80)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                            .background(appearanceManager.isDarkMode ? Color.white.opacity(0.1) : Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                    }
                }
                .padding()
                .background(appearanceManager.isDarkMode ? Color.white.opacity(0.05) : Color.white)
                .cornerRadius(12)

                Spacer(minLength: 20)

                // Send Button
                Button {
                    sendInvoice()
                } label: {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                            Text("Send Invoice")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(canSendInvoice ? Color.orange : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(!canSendInvoice || viewModel.isLoading)
            }
            .padding()
        }
        .background(appearanceManager.isDarkMode ? Color.black.ignoresSafeArea() : Color(UIColor.systemGroupedBackground).ignoresSafeArea())
    }

    private var canSendInvoice: Bool {
        viewModel.isPaymentFormValid && !viewModel.customerEmail.isEmpty
    }

    private func sendInvoice() {
        Task {
            let success = await viewModel.sendInvoice()
            onComplete(success, success ? nil : "Failed to send invoice")
        }
    }
}

// MARK: - Payment Amount Section

struct PaymentAmountSection: View {
    @ObservedObject var viewModel: PaymentsViewModel
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Amount")
                .font(.headline)
                .foregroundColor(appearanceManager.isDarkMode ? .white : .primary)

            HStack {
                Text("$")
                    .font(.largeTitle.bold())
                    .foregroundColor(.gray)

                TextField("0.00", text: $viewModel.paymentAmount)
                    .font(.largeTitle.bold())
                    .keyboardType(.decimalPad)
                    .focused($isFocused)
                    .foregroundColor(appearanceManager.isDarkMode ? .white : .primary)
            }
            .padding()
            .background(appearanceManager.isDarkMode ? Color.white.opacity(0.05) : Color.white)
            .cornerRadius(12)

            // Quick amounts
            HStack(spacing: 8) {
                ForEach([25, 50, 100, 250], id: \.self) { amount in
                    Button {
                        viewModel.paymentAmount = "\(amount).00"
                    } label: {
                        Text("$\(amount)")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(8)
                    }
                }
            }
        }
    }
}

// MARK: - Customer Info Section

struct CustomerInfoSection: View {
    @ObservedObject var viewModel: PaymentsViewModel
    let emailRequired: Bool

    @ObservedObject private var appearanceManager = AppearanceManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Customer Information")
                .font(.headline)
                .foregroundColor(appearanceManager.isDarkMode ? .white : .primary)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Name")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("(Optional)")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.7))
                }

                TextField("Customer name", text: $viewModel.customerName)
                    .textContentType(.name)
                    .padding()
                    .background(appearanceManager.isDarkMode ? Color.white.opacity(0.1) : Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Email")
                        .font(.caption)
                        .foregroundColor(.gray)
                    if emailRequired {
                        Text("*")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else {
                        Text("(Optional)")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                }

                TextField("customer@email.com", text: $viewModel.customerEmail)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(appearanceManager.isDarkMode ? Color.white.opacity(0.1) : Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Description")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("(Optional)")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.7))
                }

                TextField("Payment for...", text: $viewModel.paymentDescription)
                    .padding()
                    .background(appearanceManager.isDarkMode ? Color.white.opacity(0.1) : Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
            }
        }
        .padding()
        .background(appearanceManager.isDarkMode ? Color.white.opacity(0.05) : Color.white)
        .cornerRadius(12)
    }
}

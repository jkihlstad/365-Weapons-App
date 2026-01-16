//
//  CodesView.swift
//  365WeaponsAdmin
//
//  Discount codes management view
//

import SwiftUI

struct CodesView: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @StateObject private var viewModel = CodesViewModel()
    @State private var selectedCode: EnrichedDiscountCode?
    @State private var showCreateSheet = false
    @State private var codeToDelete: EnrichedDiscountCode?
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Stats header
                statsHeader

                // Filter bar
                filterBar

                // Main content
                if viewModel.isLoading && viewModel.codes.isEmpty {
                    ProgressView("Loading codes...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.filteredCodes.isEmpty {
                    emptyState
                } else {
                    codesList
                }
            }
            .background(appearanceManager.isDarkMode ? Color.black.ignoresSafeArea() : Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Discount Codes")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $viewModel.searchText, prompt: "Search codes...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(appearanceManager.isDarkMode ? .orange : .red)
                    }
                }
            }
            .refreshable {
                await viewModel.loadData()
            }
            .task {
                await viewModel.loadData()
            }
            .sheet(item: $selectedCode) { code in
                CodeDetailView(code: code, viewModel: viewModel)
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateCodeView(viewModel: viewModel)
            }
            .alert("Delete Code", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let code = codeToDelete {
                        Task {
                            try? await viewModel.deleteCode(code)
                        }
                    }
                }
            } message: {
                if let code = codeToDelete {
                    Text("Are you sure you want to delete the code \"\(code.code)\"? This action cannot be undone.")
                }
            }
        }
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                CodeStatChip(
                    title: "Total",
                    value: "\(viewModel.totalCodes)",
                    icon: "tag",
                    color: .gray
                )

                CodeStatChip(
                    title: "Active",
                    value: "\(viewModel.activeCodes)",
                    icon: "checkmark.circle",
                    color: .green
                )

                CodeStatChip(
                    title: "Uses",
                    value: "\(viewModel.totalUsage)",
                    icon: "arrow.up.right",
                    color: .blue
                )
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(appearanceManager.isDarkMode ? Color.white.opacity(0.05) : Color.white)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Active only toggle
                FilterToggleChip(
                    title: "Active Only",
                    isSelected: viewModel.showActiveOnly,
                    color: .green
                ) {
                    viewModel.showActiveOnly.toggle()
                }

                // Partner filter
                Menu {
                    Button("All Partners") {
                        viewModel.selectedPartnerFilter = nil
                    }
                    Divider()
                    ForEach(viewModel.partners) { partner in
                        Button(partner.storeName) {
                            viewModel.selectedPartnerFilter = partner.id
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "storefront")
                        Text(viewModel.selectedPartnerFilter != nil ?
                             (viewModel.partners.first { $0.id == viewModel.selectedPartnerFilter }?.storeName ?? "Partner") :
                             "All Partners")
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .font(.caption.weight(.medium))
                    .foregroundColor(viewModel.selectedPartnerFilter != nil ? .white : .purple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(viewModel.selectedPartnerFilter != nil ? Color.purple : Color.purple.opacity(0.15))
                    .cornerRadius(16)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Codes List

    private var codesList: some View {
        List {
            ForEach(viewModel.filteredCodes) { code in
                CodeRow(code: code)
                    .listRowBackground(appearanceManager.isDarkMode ? Color.white.opacity(0.05) : Color.white)
                    .listRowSeparatorTint(appearanceManager.isDarkMode ? Color.white.opacity(0.1) : Color(UIColor.separator))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedCode = code
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            codeToDelete = code
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            Task {
                                try? await viewModel.toggleCodeActive(code)
                            }
                        } label: {
                            Label(code.active ? "Disable" : "Enable",
                                  systemImage: code.active ? "xmark.circle" : "checkmark.circle")
                        }
                        .tint(code.active ? (appearanceManager.isDarkMode ? .orange : .red) : .green)
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "No Discount Codes",
            systemImage: "tag.slash",
            description: Text(viewModel.showActiveOnly ? "No active codes found" : "Create your first discount code")
        )
    }
}

// MARK: - Code Stat Chip

struct CodeStatChip: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(value)
                    .font(.headline.bold())
            }
            .foregroundColor(color)

            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.15))
        .cornerRadius(12)
    }
}

// MARK: - Filter Toggle Chip

struct FilterToggleChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color : color.opacity(0.15))
                .cornerRadius(16)
        }
    }
}

// MARK: - Code Row

struct CodeRow: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    let code: EnrichedDiscountCode

    var body: some View {
        HStack(spacing: 12) {
            // Code badge
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(code.active ? Color.pink.opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(width: 60, height: 44)

                Text(code.code)
                    .font(.caption.bold().monospaced())
                    .foregroundColor(code.active ? .pink : .gray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            // Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(code.partnerName ?? "Unknown Partner")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    if !code.active {
                        Text("INACTIVE")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray)
                            .cornerRadius(4)
                    }

                    Spacer()
                }

                HStack {
                    Text(code.formattedDiscount)
                        .font(.caption)
                        .foregroundColor(.green)

                    if let productName = code.productName {
                        Text("on \(productName)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Text("\(code.usageCount) uses")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                if let commission = code.formattedCommission {
                    HStack {
                        Image(systemName: "dollarsign.circle")
                            .font(.caption2)
                        Text(commission)
                            .font(.caption)
                    }
                    .foregroundColor(appearanceManager.isDarkMode ? .orange : .red)
                }
            }

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Create Code View

struct CreateCodeView: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CodesViewModel

    // Form fields
    @State private var code = ""
    @State private var selectedPartnerId: String?
    @State private var discountType: DiscountType = .percentage
    @State private var discountValue = ""
    @State private var maxUsage = ""
    @State private var expiresAt: Date?
    @State private var hasExpiration = false
    @State private var productRestriction: ProductRestriction = .allProducts
    @State private var commissionEnabled = false
    @State private var commissionType: DiscountType = .percentage
    @State private var commissionValue = ""

    @State private var isCreating = false
    @State private var errorMessage: String?

    private let exampleOrderTotal: Double = 100.0

    var body: some View {
        NavigationStack {
            Form {
                // Code Section
                Section {
                    TextField("Code", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                } header: {
                    Text("Code *")
                } footer: {
                    Text("Enter a unique code (e.g., PARTNER10)")
                }

                // Partner Section
                Section {
                    Picker("Partner Store *", selection: $selectedPartnerId) {
                        Text("Select a partner...").tag(nil as String?)
                        ForEach(viewModel.partners) { partner in
                            Text(partner.storeName).tag(partner.id as String?)
                        }
                    }
                }

                // Discount Section
                Section {
                    Picker("Discount Type *", selection: $discountType) {
                        ForEach(DiscountType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }

                    HStack {
                        Text(discountType == .percentage ? "Percentage" : "Amount")
                        Spacer()
                        TextField("Value", text: $discountValue)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text(discountType == .percentage ? "%" : "$")
                    }
                } header: {
                    Text("Discount *")
                } footer: {
                    discountExampleText
                }

                // Limits Section
                Section {
                    HStack {
                        Text("Max Usage")
                        Spacer()
                        TextField("Unlimited", text: $maxUsage)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }

                    Toggle("Set Expiration", isOn: $hasExpiration)

                    if hasExpiration {
                        DatePicker("Expires", selection: Binding(
                            get: { expiresAt ?? Date().addingTimeInterval(86400 * 30) },
                            set: { expiresAt = $0 }
                        ), displayedComponents: .date)
                    }
                } header: {
                    Text("Limits (optional)")
                }

                // Product Restriction Section
                Section {
                    Picker("Restrict to Product", selection: $productRestriction) {
                        Text("All Products").tag(ProductRestriction.allProducts)
                        Text("Custom (Invoice Only)").tag(ProductRestriction.custom)
                        ForEach(viewModel.products) { product in
                            Text(product.title).tag(ProductRestriction.specific(productId: product.id, productName: product.title))
                        }
                    }
                } footer: {
                    Text("\"All Products\" applies to any product. \"Custom\" is for invoice-only use.")
                }

                // Commission Section
                Section {
                    Toggle("Enable Commission", isOn: $commissionEnabled)

                    if commissionEnabled {
                        Picker("Commission Type", selection: $commissionType) {
                            ForEach(DiscountType.allCases, id: \.self) { type in
                                Text(type == .percentage ? "Percentage of Order" : "Fixed Amount").tag(type)
                            }
                        }

                        HStack {
                            Text(commissionType == .percentage ? "Percentage" : "Amount")
                            Spacer()
                            TextField("Value", text: $commissionValue)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Text(commissionType == .percentage ? "%" : "$")
                        }
                    }
                } header: {
                    Text("Commission")
                } footer: {
                    if commissionEnabled {
                        commissionExampleText
                    } else {
                        Text("Partner earns commission when this code is used")
                    }
                }

                // Error message
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(appearanceManager.isDarkMode ? Color.black.ignoresSafeArea() : Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Create Discount Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createCode()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isFormValid || isCreating)
                }
            }
        }
    }

    // MARK: - Example Calculations

    private var discountExampleText: some View {
        Group {
            if let value = Double(discountValue), value > 0 {
                let discountAmount = discountType == .percentage ?
                    exampleOrderTotal * (value / 100) :
                    min(value, exampleOrderTotal)
                let afterDiscount = exampleOrderTotal - discountAmount

                Text("Discount Example: On a $\(String(format: "%.2f", exampleOrderTotal)) order, customer saves: $\(String(format: "%.2f", discountAmount)) (pays $\(String(format: "%.2f", afterDiscount)))")
                    .foregroundColor(.green)
            } else {
                Text("Enter a value to see the discount example")
            }
        }
    }

    private var commissionExampleText: some View {
        Group {
            if let discountVal = Double(discountValue), discountVal > 0,
               let commissionVal = Double(commissionValue), commissionVal > 0 {
                let discountAmount = discountType == .percentage ?
                    exampleOrderTotal * (discountVal / 100) :
                    min(discountVal, exampleOrderTotal)
                let afterDiscount = exampleOrderTotal - discountAmount
                let commissionAmount = commissionType == .percentage ?
                    afterDiscount * (commissionVal / 100) :
                    commissionVal

                Text("Commission Example: On a $\(String(format: "%.2f", exampleOrderTotal)) order, the partner would earn: $\(String(format: "%.2f", commissionAmount))")
                    .foregroundColor(appearanceManager.isDarkMode ? .orange : .red)
            } else {
                Text("Enter discount and commission values to see the example")
            }
        }
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        !code.trimmingCharacters(in: .whitespaces).isEmpty &&
        selectedPartnerId != nil &&
        Double(discountValue) != nil &&
        Double(discountValue)! > 0 &&
        (!commissionEnabled || (Double(commissionValue) != nil && Double(commissionValue)! > 0))
    }

    // MARK: - Create Code

    private func createCode() {
        guard let partnerId = selectedPartnerId,
              let discountVal = Double(discountValue) else { return }

        isCreating = true
        errorMessage = nil

        Task {
            do {
                try await viewModel.createCode(
                    code: code.uppercased().trimmingCharacters(in: .whitespaces),
                    partnerStoreId: partnerId,
                    discountType: discountType,
                    discountValue: discountType == .percentage ? discountVal : discountVal,
                    maxUsage: Int(maxUsage),
                    expiresAt: hasExpiration ? expiresAt : nil,
                    productRestriction: productRestriction,
                    commissionEnabled: commissionEnabled,
                    commissionType: commissionEnabled ? commissionType : nil,
                    commissionValue: commissionEnabled ? Double(commissionValue) : nil
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isCreating = false
        }
    }
}

// MARK: - Preview

#Preview {
    CodesView()
}

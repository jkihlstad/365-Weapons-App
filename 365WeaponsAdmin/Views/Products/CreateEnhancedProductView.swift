//
//  CreateEnhancedProductView.swift
//  365WeaponsAdmin
//
//  Multi-step form for creating products with variants, add-ons, and media
//

import SwiftUI
import PhotosUI

// MARK: - Form Steps
enum ProductFormStep: Int, CaseIterable {
    case basicInfo = 0
    case pricing = 1
    case media = 2
    case variants = 3
    case addOns = 4
    case review = 5

    var title: String {
        switch self {
        case .basicInfo: return "Basic Info"
        case .pricing: return "Pricing"
        case .media: return "Media"
        case .variants: return "Variants"
        case .addOns: return "Add-ons"
        case .review: return "Review"
        }
    }

    var icon: String {
        switch self {
        case .basicInfo: return "info.circle"
        case .pricing: return "dollarsign.circle"
        case .media: return "photo.stack"
        case .variants: return "list.bullet"
        case .addOns: return "plus.circle"
        case .review: return "checkmark.circle"
        }
    }
}

// MARK: - Create Enhanced Product View
struct CreateEnhancedProductView: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @Environment(\.dismiss) private var dismiss
    @StateObject private var draft = EnhancedProductDraft()
    @State private var currentStep: ProductFormStep = .basicInfo
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false

    private let convex = ConvexClient.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                StepProgressView(currentStep: currentStep)
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Form content
                TabView(selection: $currentStep) {
                    BasicInfoStepView(draft: draft)
                        .tag(ProductFormStep.basicInfo)

                    PricingStepView(draft: draft)
                        .tag(ProductFormStep.pricing)

                    MediaStepView(draft: draft)
                        .tag(ProductFormStep.media)

                    VariantsStepView(draft: draft)
                        .tag(ProductFormStep.variants)

                    AddOnsStepView(draft: draft)
                        .tag(ProductFormStep.addOns)

                    ReviewStepView(draft: draft)
                        .tag(ProductFormStep.review)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Navigation buttons
                NavigationButtonsView(
                    currentStep: $currentStep,
                    isSubmitting: isSubmitting,
                    canSubmit: draft.isValid,
                    onSubmit: submitProduct
                )
                .padding()
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Create Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("Product created successfully!")
            }
        }
    }

    private func submitProduct() {
        isSubmitting = true

        Task {
            do {
                _ = try await convex.createEnhancedProduct(draft)
                await MainActor.run {
                    isSubmitting = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Step Progress View
struct StepProgressView: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    let currentStep: ProductFormStep

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ProductFormStep.allCases, id: \.rawValue) { step in
                VStack(spacing: 4) {
                    Circle()
                        .fill(step.rawValue <= currentStep.rawValue ? (Color.appAccent) : Color.appTextPrimary.opacity(0.3))
                        .frame(width: 8, height: 8)

                    if step == currentStep {
                        Text(step.title)
                            .font(.caption2)
                            .foregroundColor(Color.appAccent)
                    }
                }
                .frame(maxWidth: .infinity)

                if step.rawValue < ProductFormStep.allCases.count - 1 {
                    Rectangle()
                        .fill(step.rawValue < currentStep.rawValue ? (Color.appAccent) : Color.appTextPrimary.opacity(0.3))
                        .frame(height: 2)
                        .frame(maxWidth: 20)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Navigation Buttons View
struct NavigationButtonsView: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @Binding var currentStep: ProductFormStep
    let isSubmitting: Bool
    let canSubmit: Bool
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Back button
            if currentStep.rawValue > 0 {
                Button {
                    withAnimation {
                        if let previous = ProductFormStep(rawValue: currentStep.rawValue - 1) {
                            currentStep = previous
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(Color.appTextPrimary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.appSurface)
                    .cornerRadius(10)
                }
            }

            Spacer()

            // Next/Submit button
            if currentStep == .review {
                Button {
                    onSubmit()
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .tint(Color.appBackground)
                        } else {
                            Text("Create Product")
                            Image(systemName: "checkmark")
                        }
                    }
                    .foregroundColor(Color.appBackground)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(canSubmit ? (Color.appAccent) : Color.gray)
                    .cornerRadius(10)
                }
                .disabled(!canSubmit || isSubmitting)
            } else {
                Button {
                    withAnimation {
                        if let next = ProductFormStep(rawValue: currentStep.rawValue + 1) {
                            currentStep = next
                        }
                    }
                } label: {
                    HStack {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(Color.appBackground)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.appAccent)
                    .cornerRadius(10)
                }
            }
        }
    }
}

// MARK: - Step 1: Basic Info
struct BasicInfoStepView: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @ObservedObject var draft: EnhancedProductDraft

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Basic Information")
                    .font(.title2.bold())
                    .foregroundColor(Color.appTextPrimary)

                // Title
                FormField(label: "Product Title", required: true) {
                    TextField("Enter product title", text: $draft.title)
                        .textFieldStyle(DarkTextFieldStyle())
                }

                // Description
                FormField(label: "Description") {
                    TextEditor(text: $draft.description)
                        .frame(minHeight: 100)
                        .scrollContentBackground(.hidden)
                        .background(Color.appSurface2)
                        .cornerRadius(10)
                        .foregroundColor(Color.appTextPrimary)
                }

                // Category
                FormField(label: "Category", required: true) {
                    Picker("Category", selection: $draft.category) {
                        ForEach(ProductCategory.allCases) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.displayName)
                            }
                            .tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.appAccent)
                    .padding()
                    .background(Color.appSurface2)
                    .cornerRadius(10)
                }

                // Page Placement
                FormField(label: "Page Placement", required: true) {
                    VStack(spacing: 8) {
                        ForEach(PagePlacement.allCases) { placement in
                            Button {
                                draft.pagePlacement = placement
                            } label: {
                                HStack {
                                    Image(systemName: placement.icon)
                                        .frame(width: 24)
                                    Text(placement.displayName)
                                        .font(.subheadline)
                                    Spacer()
                                    if draft.pagePlacement == placement {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color.appAccent)
                                    }
                                }
                                .foregroundColor(draft.pagePlacement == placement ? (Color.appAccent) : .white)
                                .padding()
                                .background(draft.pagePlacement == placement ? Color.appAccent.opacity(0.2) : Color.appSurface2)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(draft.pagePlacement == placement ? (Color.appAccent) : Color.clear, lineWidth: 1)
                                )
                            }
                        }
                    }
                }

                // Slug
                FormField(label: "URL Slug") {
                    TextField("Auto-generated from title", text: $draft.slug)
                        .textFieldStyle(DarkTextFieldStyle())
                        .autocapitalization(.none)

                    if draft.slug.isEmpty && !draft.title.isEmpty {
                        Text("Will use: \(draft.autoSlug)")
                            .font(.caption)
                            .foregroundColor(Color.appTextSecondary)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Step 2: Pricing
struct PricingStepView: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @ObservedObject var draft: EnhancedProductDraft
    @State private var priceText: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Pricing")
                    .font(.title2.bold())
                    .foregroundColor(Color.appTextPrimary)

                // Base Price
                FormField(label: "Base Price", required: true) {
                    HStack {
                        Text("$")
                            .foregroundColor(Color.appTextSecondary)
                        TextField("0.00", text: $priceText)
                            .keyboardType(.decimalPad)
                            .foregroundColor(Color.appTextPrimary)
                            .onChange(of: priceText) { _, newValue in
                                draft.basePrice = Double(newValue) ?? 0
                            }
                    }
                    .padding()
                    .background(Color.appSurface2)
                    .cornerRadius(10)
                }

                // Price Range (optional override)
                FormField(label: "Price Range Display (optional)") {
                    TextField("e.g., $425.00 - $750.00", text: $draft.priceRange)
                        .textFieldStyle(DarkTextFieldStyle())

                    Text("Leave empty to auto-calculate from variants")
                        .font(.caption)
                        .foregroundColor(Color.appTextSecondary)
                }

                Divider()
                    .background(Color.appTextPrimary.opacity(0.3))

                // Stock status
                Toggle("In Stock", isOn: $draft.inStock)
                    .tint(Color.appAccent)
                    .foregroundColor(Color.appTextPrimary)

                // Has Options
                Toggle("Has Customization Options", isOn: $draft.hasOptions)
                    .tint(Color.appAccent)
                    .foregroundColor(Color.appTextPrimary)

                // Include Shipping Label
                Toggle("Include Pre-paid Shipping Label", isOn: $draft.includeShippingLabel)
                    .tint(Color.appAccent)
                    .foregroundColor(Color.appTextPrimary)

                // Price preview
                if draft.basePrice > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Price Preview")
                            .font(.subheadline)
                            .foregroundColor(Color.appTextSecondary)

                        Text(draft.formattedPriceRange)
                            .font(.title.bold())
                            .foregroundColor(Color.appAccent)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appSurface)
                    .cornerRadius(10)
                }
            }
            .padding()
        }
        .onAppear {
            if draft.basePrice > 0 {
                priceText = String(format: "%.2f", draft.basePrice)
            }
        }
    }
}

// MARK: - Step 3: Media
struct MediaStepView: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @ObservedObject var draft: EnhancedProductDraft
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isUploading = false
    @State private var newVideoUrl = ""

    private let convex = ConvexClient.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Media")
                    .font(.title2.bold())
                    .foregroundColor(Color.appTextPrimary)

                // Images section
                FormField(label: "Product Images", required: true) {
                    VStack(spacing: 12) {
                        // Image grid
                        if !draft.images.isEmpty {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                                ForEach(Array(draft.images.enumerated()), id: \.element.id) { index, item in
                                    ImageThumbnailView(
                                        item: item,
                                        isPrimary: index == draft.primaryImageIndex,
                                        onSetPrimary: {
                                            draft.primaryImageIndex = index
                                        },
                                        onDelete: {
                                            draft.images.remove(at: index)
                                            if draft.primaryImageIndex >= draft.images.count {
                                                draft.primaryImageIndex = max(0, draft.images.count - 1)
                                            }
                                        }
                                    )
                                }
                            }
                        }

                        // Add images button
                        PhotosPicker(
                            selection: $selectedItems,
                            maxSelectionCount: 10,
                            matching: .images
                        ) {
                            HStack {
                                Image(systemName: "photo.badge.plus")
                                Text(draft.images.isEmpty ? "Add Images" : "Add More Images")
                            }
                            .foregroundColor(Color.appAccent)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.appSurface2)
                            .cornerRadius(10)
                        }
                        .onChange(of: selectedItems) { _, newItems in
                            Task {
                                await loadImages(from: newItems)
                            }
                        }

                        if isUploading {
                            HStack {
                                ProgressView()
                                    .tint(Color.appAccent)
                                Text("Uploading images...")
                                    .foregroundColor(Color.appTextSecondary)
                            }
                        }
                    }
                }

                Divider()
                    .background(Color.appTextPrimary.opacity(0.3))

                // Videos section
                FormField(label: "Video URLs (optional)") {
                    VStack(spacing: 8) {
                        ForEach(Array(draft.videos.enumerated()), id: \.offset) { index, url in
                            HStack {
                                Image(systemName: "play.circle")
                                    .foregroundColor(Color.appTextSecondary)
                                Text(url)
                                    .foregroundColor(Color.appTextPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Button {
                                    draft.videos.remove(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(8)
                            .background(Color.appSurface)
                            .cornerRadius(8)
                        }

                        HStack {
                            TextField("Enter video URL", text: $newVideoUrl)
                                .textFieldStyle(DarkTextFieldStyle())
                                .autocapitalization(.none)

                            Button {
                                if !newVideoUrl.isEmpty {
                                    draft.videos.append(newVideoUrl)
                                    newVideoUrl = ""
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(Color.appAccent)
                                    .font(.title2)
                            }
                            .disabled(newVideoUrl.isEmpty)
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func loadImages(from items: [PhotosPickerItem]) async {
        await MainActor.run { isUploading = true }

        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                // Add to draft with local image first
                let mediaItem = MediaItem(localImage: uiImage)
                await MainActor.run {
                    draft.images.append(mediaItem)
                }

                // Upload to Convex
                do {
                    let url = try await convex.uploadImage(uiImage)
                    if let index = draft.images.firstIndex(where: { $0.id == mediaItem.id }) {
                        await MainActor.run {
                            draft.images[index].uploadedUrl = url
                        }
                    }
                } catch {
                    print("Failed to upload image: \(error)")
                }
            }
        }

        await MainActor.run {
            isUploading = false
            selectedItems = []
        }
    }
}

// MARK: - Image Thumbnail View
struct ImageThumbnailView: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    let item: MediaItem
    let isPrimary: Bool
    let onSetPrimary: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let localImage = item.localImage {
                    Image(uiImage: localImage)
                        .resizable()
                        .scaledToFill()
                } else if let url = item.uploadedUrl, let imageUrl = URL(string: url) {
                    AsyncImage(url: imageUrl) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.gray
                    }
                } else {
                    Color.gray
                }
            }
            .frame(width: 80, height: 80)
            .clipped()
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isPrimary ? (Color.appAccent) : Color.clear, lineWidth: 3)
            )

            // Primary badge
            if isPrimary {
                Text("Primary")
                    .font(.caption2)
                    .foregroundColor(Color.appBackground)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.appAccent)
                    .cornerRadius(4)
                    .offset(x: 4, y: -4)
            }

            // Upload status
            if item.isUploading {
                ProgressView()
                    .tint(.white)
                    .frame(width: 80, height: 80)
                    .background(Color.appBackground.opacity(0.5))
                    .cornerRadius(8)
            }
        }
        .contextMenu {
            if !isPrimary {
                Button {
                    onSetPrimary()
                } label: {
                    Label("Set as Primary", systemImage: "star")
                }
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Step 4: Variants
struct VariantsStepView: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @ObservedObject var draft: EnhancedProductDraft

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Product Variants")
                    .font(.title2.bold())
                    .foregroundColor(Color.appTextPrimary)

                Text("Add variant groups like 'Slide Type' or 'Finish' with options that affect pricing.")
                    .font(.subheadline)
                    .foregroundColor(Color.appTextSecondary)

                // Existing variants
                ForEach(Array(draft.variants.enumerated()), id: \.element.id) { index, variant in
                    VariantEditorView(
                        variant: Binding(
                            get: { variant },
                            set: { draft.variants[index] = $0 }
                        ),
                        onDelete: {
                            draft.variants.remove(at: index)
                        }
                    )
                }

                // Add variant button
                Button {
                    let newVariant = ProductVariant(
                        name: "",
                        options: [ProductVariantOption(label: "", priceModifier: 0)]
                    )
                    draft.variants.append(newVariant)
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add Variant Group")
                    }
                    .foregroundColor(Color.appAccent)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.appSurface2)
                    .cornerRadius(10)
                }

                if draft.variants.isEmpty {
                    Text("No variants added. Products without variants will have a single fixed price.")
                        .font(.caption)
                        .foregroundColor(Color.appTextSecondary)
                        .padding()
                }
            }
            .padding()
        }
    }
}

// MARK: - Variant Editor View
struct VariantEditorView: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @Binding var variant: ProductVariant
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                TextField("Variant Name (e.g., Slide Type)", text: $variant.name)
                    .font(.headline)
                    .foregroundColor(Color.appTextPrimary)

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }

            Divider()
                .background(Color.appSurface)

            // Options
            ForEach(Array(variant.options.enumerated()), id: \.element.id) { optIndex, option in
                HStack(spacing: 12) {
                    TextField("Option label", text: Binding(
                        get: { option.label },
                        set: { variant.options[optIndex].label = $0 }
                    ))
                    .foregroundColor(Color.appTextPrimary)

                    HStack {
                        Text("$")
                            .foregroundColor(Color.appTextSecondary)
                        TextField("0", value: Binding(
                            get: { option.priceModifier },
                            set: { variant.options[optIndex].priceModifier = $0 }
                        ), format: .number)
                        .keyboardType(.decimalPad)
                        .foregroundColor(option.priceModifier >= 0 ? .green : .red)
                        .frame(width: 60)
                    }

                    Button {
                        variant.options.remove(at: optIndex)
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundColor(.red)
                    }
                }
                .padding(8)
                .background(Color.appSurface)
                .cornerRadius(8)
            }

            // Add option button
            Button {
                variant.options.append(ProductVariantOption(label: "", priceModifier: 0))
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Option")
                }
                .font(.caption)
                .foregroundColor(Color.appAccent)
            }
        }
        .padding()
        .background(Color.appSurface2)
        .cornerRadius(12)
    }
}

// MARK: - Step 5: Add-Ons
struct AddOnsStepView: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @ObservedObject var draft: EnhancedProductDraft

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Product Add-Ons")
                    .font(.title2.bold())
                    .foregroundColor(Color.appTextPrimary)

                Text("Add optional extras customers can add to their order.")
                    .font(.subheadline)
                    .foregroundColor(Color.appTextSecondary)

                // Existing add-ons
                ForEach(Array(draft.addOns.enumerated()), id: \.element.id) { index, addOn in
                    AddOnEditorView(
                        addOn: Binding(
                            get: { addOn },
                            set: { draft.addOns[index] = $0 }
                        ),
                        onDelete: {
                            draft.addOns.remove(at: index)
                        }
                    )
                }

                // Add button
                Button {
                    let newAddOn = ProductAddOn(name: "", price: 0, description: nil)
                    draft.addOns.append(newAddOn)
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add Add-On")
                    }
                    .foregroundColor(Color.appAccent)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.appSurface2)
                    .cornerRadius(10)
                }

                if draft.addOns.isEmpty {
                    Text("No add-ons added. Skip this step if your product doesn't need optional extras.")
                        .font(.caption)
                        .foregroundColor(Color.appTextSecondary)
                        .padding()
                }
            }
            .padding()
        }
    }
}

// MARK: - Add-On Editor View
struct AddOnEditorView: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @Binding var addOn: ProductAddOn
    let onDelete: () -> Void
    @State private var priceText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Add-on Name", text: $addOn.name)
                    .foregroundColor(Color.appTextPrimary)

                HStack {
                    Text("+$")
                        .foregroundColor(Color.appTextSecondary)
                    TextField("0", text: $priceText)
                        .keyboardType(.decimalPad)
                        .foregroundColor(.green)
                        .frame(width: 60)
                        .onChange(of: priceText) { _, newValue in
                            addOn.price = Double(newValue) ?? 0
                        }
                }

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }

            TextField("Description (optional)", text: Binding(
                get: { addOn.description ?? "" },
                set: { addOn.description = $0.isEmpty ? nil : $0 }
            ))
            .font(.caption)
            .foregroundColor(Color.appTextSecondary)
        }
        .padding()
        .background(Color.appSurface2)
        .cornerRadius(12)
        .onAppear {
            if addOn.price > 0 {
                priceText = String(format: "%.2f", addOn.price)
            }
        }
    }
}

// MARK: - Step 6: Review
struct ReviewStepView: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @ObservedObject var draft: EnhancedProductDraft

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Review Product")
                    .font(.title2.bold())
                    .foregroundColor(Color.appTextPrimary)

                // Validation errors
                if !draft.validationErrors.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("Please fix the following:")
                                .foregroundColor(.red)
                        }

                        ForEach(draft.validationErrors, id: \.self) { error in
                            Text("- \(error)")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(10)
                }

                // Preview card
                VStack(alignment: .leading, spacing: 16) {
                    // Image preview
                    if let firstImage = draft.images.first {
                        Group {
                            if let localImage = firstImage.localImage {
                                Image(uiImage: localImage)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Color.gray
                            }
                        }
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .cornerRadius(12)
                    }

                    // Title & Price
                    HStack {
                        VStack(alignment: .leading) {
                            Text(draft.title.isEmpty ? "Product Title" : draft.title)
                                .font(.headline)
                                .foregroundColor(Color.appTextPrimary)

                            Text(draft.category.displayName)
                                .font(.caption)
                                .foregroundColor(Color.appTextSecondary)
                        }

                        Spacer()

                        Text(draft.formattedPriceRange)
                            .font(.title3.bold())
                            .foregroundColor(Color.appAccent)
                    }

                    // Description
                    if !draft.description.isEmpty {
                        Text(draft.description)
                            .font(.subheadline)
                            .foregroundColor(Color.appTextSecondary)
                            .lineLimit(3)
                    }

                    Divider()
                        .background(Color.appSurface)

                    // Stats
                    HStack(spacing: 20) {
                        StatItem(label: "Images", value: "\(draft.images.count)")
                        StatItem(label: "Videos", value: "\(draft.videos.count)")
                        StatItem(label: "Variants", value: "\(draft.variants.count)")
                        StatItem(label: "Add-ons", value: "\(draft.addOns.count)")
                    }

                    // Page placement
                    HStack {
                        Image(systemName: draft.pagePlacement.icon)
                        Text(draft.pagePlacement.displayName)
                    }
                    .font(.caption)
                    .foregroundColor(Color.appAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.appAccent.opacity(0.2))
                    .cornerRadius(8)
                }
                .padding()
                .background(Color.appSurface2)
                .cornerRadius(16)
            }
            .padding()
        }
    }
}

// MARK: - Stat Item
struct StatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack {
            Text(value)
                .font(.headline)
                .foregroundColor(Color.appTextPrimary)
            Text(label)
                .font(.caption2)
                .foregroundColor(Color.appTextSecondary)
        }
    }
}

// MARK: - Form Field
struct FormField<Content: View>: View {
    let label: String
    var required: Bool = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(Color.appTextSecondary)
                if required {
                    Text("*")
                        .foregroundColor(.red)
                }
            }
            content
        }
    }
}

// MARK: - Dark Text Field Style
struct DarkTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.appSurface2)
            .cornerRadius(10)
            .foregroundColor(Color.appTextPrimary)
    }
}

// MARK: - Preview
#Preview {
    CreateEnhancedProductView()
}

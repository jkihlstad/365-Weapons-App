//
//  ProductsView.swift
//  365WeaponsAdmin
//
//  Products management view with creation functionality
//

import SwiftUI
import Kingfisher

struct ProductsView: View {
    @StateObject private var viewModel = ProductsViewModel()
    @State private var showCreateProduct = false
    @State private var showEnhancedCreate = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category filter
                categoryFilterBar

                // Products content
                if viewModel.isLoading && viewModel.products.isEmpty {
                    ProgressView("Loading products...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.filteredProducts.isEmpty {
                    ContentUnavailableView(
                        "No Products",
                        systemImage: "cube.box",
                        description: Text(viewModel.selectedCategory != nil ? "No products in \(viewModel.selectedCategory!)" : "No products found")
                    )
                } else {
                    switch viewModel.displayMode {
                    case .grid:
                        productsGrid
                    case .list:
                        productsList
                    }
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Products")
            .searchable(text: $viewModel.searchText, prompt: "Search products...")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: viewModel.toggleDisplayMode) {
                        Image(systemName: viewModel.displayMode.icon)
                    }

                    Menu {
                        Button {
                            showEnhancedCreate = true
                        } label: {
                            Label("Full Product (Recommended)", systemImage: "cube.box.fill")
                        }

                        Button {
                            showCreateProduct = true
                        } label: {
                            Label("Quick Product", systemImage: "bolt")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }

                    Button(action: viewModel.refresh) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .refreshable {
                await viewModel.loadProducts()
            }
            .sheet(isPresented: $showCreateProduct) {
                CreateProductView(viewModel: viewModel)
            }
            .fullScreenCover(isPresented: $showEnhancedCreate) {
                CreateEnhancedProductView()
                    .onDisappear {
                        viewModel.refresh()
                    }
            }
            .sheet(item: $viewModel.selectedProduct) { product in
                ProductDetailView(product: product, viewModel: viewModel)
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
            await viewModel.loadProducts()
        }
    }

    // MARK: - Category Filter Bar
    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "All",
                    count: viewModel.products.count,
                    isSelected: viewModel.selectedCategory == nil,
                    action: { viewModel.filterByCategory(nil) }
                )

                ForEach(viewModel.categories, id: \.self) { category in
                    FilterChip(
                        title: category,
                        count: viewModel.productCountByCategory[category] ?? 0,
                        isSelected: viewModel.selectedCategory == category,
                        color: .purple,
                        action: { viewModel.filterByCategory(category) }
                    )
                }
            }
            .padding()
        }
        .background(Color.white.opacity(0.05))
    }

    // MARK: - Products Grid
    private var productsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(viewModel.filteredProducts) { product in
                    ProductGridCard(product: product)
                        .onTapGesture {
                            viewModel.selectProduct(product)
                        }
                }
            }
            .padding()
        }
    }

    // MARK: - Products List
    private var productsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.filteredProducts) { product in
                    ProductListCard(product: product)
                        .onTapGesture {
                            viewModel.selectProduct(product)
                        }
                }
            }
            .padding()
        }
    }
}

// MARK: - Product Grid Card
struct ProductGridCard: View {
    let product: Product

    /// Construct full image URL from relative path
    private var imageURL: URL? {
        let baseURL = "https://365weapons.com"
        let imagePath = product.image
        // Handle relative paths
        if imagePath.starts(with: "/") {
            return URL(string: baseURL + imagePath)
        } else if imagePath.starts(with: "http") {
            return URL(string: imagePath)
        }
        return URL(string: baseURL + "/" + imagePath)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Product image - fixed square size
            GeometryReader { geometry in
                ZStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))

                    if let url = imageURL {
                        KFImage(url)
                            .placeholder {
                                ProgressView()
                            }
                            .retry(maxCount: 2, interval: .seconds(2))
                            .cacheMemoryOnly(false)
                            .fade(duration: 0.25)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.width)
                            .clipped()
                    } else {
                        Image(systemName: "cube.box.fill")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.width)
                .cornerRadius(12)
            }
            .aspectRatio(1, contentMode: .fit)

            // Product info - fixed height for uniformity
            VStack(alignment: .leading, spacing: 4) {
                Text(product.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .frame(height: 40, alignment: .topLeading)

                Text(product.category)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)

                HStack {
                    Text(product.formattedPrice)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.green)

                    Spacer()

                    Circle()
                        .fill(product.inStock ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                }
            }
            .frame(height: 80)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

// MARK: - Product List Card
struct ProductListCard: View {
    let product: Product

    /// Construct full image URL from relative path
    private var imageURL: URL? {
        let baseURL = "https://365weapons.com"
        let imagePath = product.image
        if imagePath.starts(with: "/") {
            return URL(string: baseURL + imagePath)
        } else if imagePath.starts(with: "http") {
            return URL(string: imagePath)
        }
        return URL(string: baseURL + "/" + imagePath)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Product image - fixed 60x60 size
            ZStack {
                Rectangle()
                    .fill(Color.white.opacity(0.1))

                if let url = imageURL {
                    KFImage(url)
                        .placeholder {
                            ProgressView()
                                .scaleEffect(0.5)
                        }
                        .retry(maxCount: 2, interval: .seconds(2))
                        .cacheMemoryOnly(false)
                        .fade(duration: 0.25)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipped()
                } else {
                    Image(systemName: "cube.box.fill")
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 60, height: 60)
            .clipped()
            .cornerRadius(8)

            // Product info
            VStack(alignment: .leading, spacing: 4) {
                Text(product.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                Text(product.category)
                    .font(.caption)
                    .foregroundColor(.gray)

                HStack {
                    Text(product.inStock ? "In Stock" : "Out of Stock")
                        .font(.caption2)
                        .foregroundColor(product.inStock ? .green : .red)

                    if product.hasOptions ?? false {
                        Text("Has Options")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }

            Spacer()

            Text(product.formattedPrice)
                .font(.headline)
                .foregroundColor(.green)
        }
        .padding()
        .frame(height: 80)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Create Product View
struct CreateProductView: View {
    @ObservedObject var viewModel: ProductsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var price = ""
    @State private var priceRange = ""
    @State private var category = ""
    @State private var newCategory = ""
    @State private var inStock = true
    @State private var hasOptions = false
    @State private var isCreating = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Product Information") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Pricing") {
                    TextField("Price", text: $price)
                        .keyboardType(.decimalPad)
                    TextField("Price Range (optional)", text: $priceRange)
                        .foregroundColor(.gray)
                }

                Section("Category") {
                    Picker("Category", selection: $category) {
                        Text("Select category").tag("")
                        ForEach(viewModel.categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                        Text("New category...").tag("__new__")
                    }

                    if category == "__new__" {
                        TextField("New Category Name", text: $newCategory)
                    }
                }

                Section("Status") {
                    Toggle("In Stock", isOn: $inStock)
                    Toggle("Has Options", isOn: $hasOptions)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Create Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createProduct()
                    }
                    .disabled(title.isEmpty || price.isEmpty || (category.isEmpty && newCategory.isEmpty))
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func createProduct() {
        guard let priceValue = Double(price) else {
            errorMessage = "Please enter a valid price"
            showError = true
            return
        }

        let finalCategory = category == "__new__" ? newCategory : category

        let request = CreateProductRequest(
            title: title,
            description: description.isEmpty ? nil : description,
            price: priceValue,
            priceRange: priceRange.isEmpty ? nil : priceRange,
            category: finalCategory,
            image: "/images/products/default.jpg",
            inStock: inStock,
            hasOptions: hasOptions
        )

        isCreating = true

        Task {
            do {
                _ = try await viewModel.createProduct(request)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isCreating = false
        }
    }
}

// MARK: - Product Detail View
struct ProductDetailView: View {
    let product: Product
    @ObservedObject var viewModel: ProductsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var editedTitle: String
    @State private var editedDescription: String
    @State private var editedPrice: String
    @State private var editedInStock: Bool

    /// Construct full image URL from relative path
    private var imageURL: URL? {
        let baseURL = "https://365weapons.com"
        let imagePath = product.image
        if imagePath.starts(with: "/") {
            return URL(string: baseURL + imagePath)
        } else if imagePath.starts(with: "http") {
            return URL(string: imagePath)
        }
        return URL(string: baseURL + "/" + imagePath)
    }

    init(product: Product, viewModel: ProductsViewModel) {
        self.product = product
        self.viewModel = viewModel
        self._editedTitle = State(initialValue: product.title)
        self._editedDescription = State(initialValue: product.description ?? "")
        self._editedPrice = State(initialValue: String(product.price))
        self._editedInStock = State(initialValue: product.inStock)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Product image
                    ZStack {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))

                        if let url = imageURL {
                            KFImage(url)
                                .placeholder {
                                    ProgressView()
                                }
                                .retry(maxCount: 2, interval: .seconds(2))
                                .cacheMemoryOnly(false)
                                .fade(duration: 0.25)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Image(systemName: "cube.box.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                        }
                    }
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipped()
                    .cornerRadius(16)

                    // Product info
                    VStack(alignment: .leading, spacing: 16) {
                        if isEditing {
                            editableFields
                        } else {
                            staticFields
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)

                    // Actions
                    if isEditing {
                        Button(action: saveChanges) {
                            Text("Save Changes")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }

                    // Quick actions
                    if !isEditing {
                        VStack(spacing: 12) {
                            Button(action: toggleStock) {
                                HStack {
                                    Image(systemName: product.inStock ? "xmark.circle" : "checkmark.circle")
                                    Text(product.inStock ? "Mark Out of Stock" : "Mark In Stock")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .foregroundColor(product.inStock ? .red : .green)
                                .cornerRadius(12)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(isEditing ? "Edit Product" : "Product Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isEditing ? "Cancel" : "Done") {
                        if isEditing {
                            isEditing = false
                            resetEditFields()
                        } else {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if !isEditing {
                        Button("Edit") {
                            isEditing = true
                        }
                    }
                }
            }
        }
    }

    private var staticFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.title)
                    .font(.title2.weight(.bold))

                Text(product.category)
                    .font(.subheadline)
                    .foregroundColor(.orange)
            }

            HStack {
                Text(product.formattedPrice)
                    .font(.title.weight(.bold))
                    .foregroundColor(.green)

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(product.inStock ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(product.inStock ? "In Stock" : "Out of Stock")
                        .font(.subheadline)
                        .foregroundColor(product.inStock ? .green : .red)
                }
            }

            if let description = product.description, !description.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Description")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(description)
                        .font(.body)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Details")
                    .font(.caption)
                    .foregroundColor(.gray)

                InfoRow(label: "ID", value: product.id)
                InfoRow(label: "Created", value: product.createdAt.formatted())
                InfoRow(label: "Has Options", value: product.hasOptions ?? false ? "Yes" : "No")
            }
        }
    }

    private var editableFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Title")
                    .font(.caption)
                    .foregroundColor(.gray)
                TextField("Title", text: $editedTitle)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Price")
                    .font(.caption)
                    .foregroundColor(.gray)
                TextField("Price", text: $editedPrice)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Description")
                    .font(.caption)
                    .foregroundColor(.gray)
                TextField("Description", text: $editedDescription, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
            }

            Toggle("In Stock", isOn: $editedInStock)
        }
    }

    private func resetEditFields() {
        editedTitle = product.title
        editedDescription = product.description ?? ""
        editedPrice = String(product.price)
        editedInStock = product.inStock
    }

    private func saveChanges() {
        Task {
            var updates: [String: Any] = [:]

            if editedTitle != product.title {
                updates["title"] = editedTitle
            }
            if editedDescription != (product.description ?? "") {
                updates["description"] = editedDescription
            }
            if let newPrice = Double(editedPrice), newPrice != product.price {
                updates["price"] = newPrice
            }
            if editedInStock != product.inStock {
                updates["inStock"] = editedInStock
            }

            if !updates.isEmpty {
                _ = try? await viewModel.updateProduct(id: product.id, updates: updates)
            }

            isEditing = false
            dismiss()
        }
    }

    private func toggleStock() {
        Task {
            _ = try? await viewModel.updateProduct(id: product.id, updates: ["inStock": !product.inStock])
            dismiss()
        }
    }
}

// MARK: - Preview
#Preview {
    ProductsView()
}

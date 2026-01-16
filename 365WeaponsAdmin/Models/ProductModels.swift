//
//  ProductModels.swift
//  365WeaponsAdmin
//
//  Data models for enhanced product creation with variants, add-ons, and media
//

import Foundation
import SwiftUI

// MARK: - Product Variant Option

/// A single option within a product variant (e.g., "Standard Slide" option in "Slide Type" variant)
struct ProductVariantOption: Codable, Identifiable, Hashable {
    let id: UUID
    var label: String
    var priceModifier: Double

    init(id: UUID = UUID(), label: String = "", priceModifier: Double = 0) {
        self.id = id
        self.label = label
        self.priceModifier = priceModifier
    }

    // Custom coding for Convex compatibility (uses String IDs)
    enum CodingKeys: String, CodingKey {
        case id, label, priceModifier
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let idString = try container.decode(String.self, forKey: .id)
        self.id = UUID(uuidString: idString) ?? UUID()
        self.label = try container.decode(String.self, forKey: .label)
        self.priceModifier = try container.decode(Double.self, forKey: .priceModifier)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id.uuidString, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encode(priceModifier, forKey: .priceModifier)
    }
}

// MARK: - Product Variant

/// A product variant group (e.g., "Slide Type" with options like "Standard", "Ported", etc.)
struct ProductVariant: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var options: [ProductVariantOption]

    init(id: UUID = UUID(), name: String = "", options: [ProductVariantOption] = []) {
        self.id = id
        self.name = name
        self.options = options
    }

    // Custom coding for Convex compatibility (uses String IDs)
    enum CodingKeys: String, CodingKey {
        case id, name, options
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let idString = try container.decode(String.self, forKey: .id)
        self.id = UUID(uuidString: idString) ?? UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.options = try container.decode([ProductVariantOption].self, forKey: .options)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id.uuidString, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(options, forKey: .options)
    }
}

// MARK: - Product Add-On

/// An optional add-on for a product (e.g., "Polished Slide" for +$50)
struct ProductAddOn: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var price: Double
    var description: String?

    init(id: UUID = UUID(), name: String = "", price: Double = 0, description: String? = nil) {
        self.id = id
        self.name = name
        self.price = price
        self.description = description
    }

    // Custom coding for Convex compatibility (uses String IDs)
    enum CodingKeys: String, CodingKey {
        case id, name, price, description
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let idString = try container.decode(String.self, forKey: .id)
        self.id = UUID(uuidString: idString) ?? UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.price = try container.decode(Double.self, forKey: .price)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id.uuidString, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(price, forKey: .price)
        try container.encodeIfPresent(description, forKey: .description)
    }
}

// MARK: - Design Reference

/// Reference image and instructions for custom designs
struct DesignReference: Codable, Hashable {
    var imageUrl: String?
    var instructions: String?

    init(imageUrl: String? = nil, instructions: String? = nil) {
        self.imageUrl = imageUrl
        self.instructions = instructions
    }

    var isEmpty: Bool {
        return (imageUrl == nil || imageUrl?.isEmpty == true) &&
               (instructions == nil || instructions?.isEmpty == true)
    }
}

// MARK: - Page Placement

/// Where the product should appear on the website
enum PagePlacement: String, Codable, CaseIterable, Identifiable {
    case products = "products"
    case services = "services"
    case both = "both"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .products: return "Products Page"
        case .services: return "Services Page"
        case .both: return "Both Pages"
        }
    }

    var icon: String {
        switch self {
        case .products: return "cube.box"
        case .services: return "wrench.and.screwdriver"
        case .both: return "square.grid.2x2"
        }
    }

    var description: String {
        switch self {
        case .products: return "Show only on the Products page"
        case .services: return "Show only on the Services page"
        case .both: return "Show on both Products and Services pages"
        }
    }
}

// MARK: - Product Category

/// Categories for products
enum ProductCategory: String, Codable, CaseIterable, Identifiable {
    case services = "Services"
    case glockServices = "Glock Services"
    case parts = "Parts"
    case accessories = "Accessories"
    case other = "Other"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .services: return "wrench.and.screwdriver"
        case .glockServices: return "target"
        case .parts: return "gear"
        case .accessories: return "bag"
        case .other: return "ellipsis.circle"
        }
    }
}

// MARK: - Media Item

/// Represents an uploaded or pending media item
struct MediaItem: Identifiable, Hashable {
    let id: UUID
    var localImage: UIImage?
    var uploadedUrl: String?
    var isUploading: Bool = false
    var uploadProgress: Double = 0

    init(id: UUID = UUID(), localImage: UIImage? = nil, uploadedUrl: String? = nil) {
        self.id = id
        self.localImage = localImage
        self.uploadedUrl = uploadedUrl
    }

    var isUploaded: Bool {
        return uploadedUrl != nil
    }

    static func == (lhs: MediaItem, rhs: MediaItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Enhanced Product Draft

/// Model for creating/editing an enhanced product
class EnhancedProductDraft: ObservableObject {
    // Basic Info
    @Published var title: String = ""
    @Published var description: String = ""
    @Published var category: ProductCategory = .services
    @Published var pagePlacement: PagePlacement = .products
    @Published var slug: String = ""

    // Pricing
    @Published var basePrice: Double = 0
    @Published var priceRange: String = ""
    @Published var inStock: Bool = true
    @Published var hasOptions: Bool = false
    @Published var includeShippingLabel: Bool = false

    // Media
    @Published var images: [MediaItem] = []
    @Published var videos: [String] = []
    @Published var primaryImageIndex: Int = 0

    // Variants & Add-ons
    @Published var variants: [ProductVariant] = []
    @Published var addOns: [ProductAddOn] = []

    // Design Reference
    @Published var designReference: DesignReference = DesignReference()

    // Computed slug from title
    var autoSlug: String {
        title.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)
    }

    // Primary image URL
    var primaryImageUrl: String? {
        guard !images.isEmpty, primaryImageIndex < images.count else { return nil }
        return images[primaryImageIndex].uploadedUrl
    }

    // All uploaded image URLs
    var uploadedImageUrls: [String] {
        images.compactMap { $0.uploadedUrl }
    }

    // Formatted price range
    var formattedPriceRange: String {
        if !priceRange.isEmpty {
            return priceRange
        }

        if variants.isEmpty && addOns.isEmpty {
            return String(format: "$%.2f", basePrice)
        }

        // Calculate max possible price
        var maxPrice = basePrice

        // Add highest price modifier from each variant
        for variant in variants {
            if let maxModifier = variant.options.map({ $0.priceModifier }).max(), maxModifier > 0 {
                maxPrice += maxModifier
            }
        }

        // Add all add-ons
        for addOn in addOns {
            maxPrice += addOn.price
        }

        if maxPrice > basePrice {
            return String(format: "$%.2f - $%.2f", basePrice, maxPrice)
        }

        return String(format: "$%.2f+", basePrice)
    }

    // Validation
    var isValid: Bool {
        return !title.isEmpty &&
               basePrice > 0 &&
               !images.isEmpty &&
               images.first?.uploadedUrl != nil
    }

    var validationErrors: [String] {
        var errors: [String] = []

        if title.isEmpty {
            errors.append("Title is required")
        }
        if basePrice <= 0 {
            errors.append("Price must be greater than 0")
        }
        if images.isEmpty || images.first?.uploadedUrl == nil {
            errors.append("At least one image is required")
        }

        // Validate variants
        for (index, variant) in variants.enumerated() {
            if variant.name.isEmpty {
                errors.append("Variant \(index + 1) needs a name")
            }
            if variant.options.isEmpty {
                errors.append("Variant '\(variant.name)' needs at least one option")
            }
            for (optIndex, option) in variant.options.enumerated() {
                if option.label.isEmpty {
                    errors.append("Option \(optIndex + 1) in '\(variant.name)' needs a label")
                }
            }
        }

        // Validate add-ons
        for (index, addOn) in addOns.enumerated() {
            if addOn.name.isEmpty {
                errors.append("Add-on \(index + 1) needs a name")
            }
        }

        return errors
    }

    // Reset to defaults
    func reset() {
        title = ""
        description = ""
        category = .services
        pagePlacement = .products
        slug = ""
        basePrice = 0
        priceRange = ""
        inStock = true
        hasOptions = false
        includeShippingLabel = false
        images = []
        videos = []
        primaryImageIndex = 0
        variants = []
        addOns = []
        designReference = DesignReference()
    }
}

// MARK: - Convex Product Response Extensions

extension Product {
    /// Enhanced product fields (optional, may not exist on older products)
    var enhancedImages: [String]? {
        // This would require updating the Product model in DataModels.swift
        // For now, return nil as the base Product doesn't have this field
        return nil
    }
}

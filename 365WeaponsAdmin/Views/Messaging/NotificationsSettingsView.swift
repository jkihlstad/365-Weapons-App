//
//  NotificationsSettingsView.swift
//  365WeaponsAdmin
//
//  Notification settings with toggles for all website actions
//

import SwiftUI

// MARK: - Notification Category

enum NotificationCategory: String, CaseIterable, Identifiable {
    case submissions = "Submissions"
    case orders = "Orders & Payments"
    case vendors = "Vendor Activity"
    case inventory = "Inventory"
    case users = "User Activity"
    case marketing = "Marketing"
    case system = "System"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .submissions: return "envelope.badge"
        case .orders: return "creditcard"
        case .vendors: return "storefront"
        case .inventory: return "shippingbox"
        case .users: return "person.2"
        case .marketing: return "megaphone"
        case .system: return "gear"
        }
    }

    var color: Color {
        switch self {
        case .submissions: return .blue
        case .orders: return .green
        case .vendors: return .purple
        case .inventory: return .orange
        case .users: return .cyan
        case .marketing: return .pink
        case .system: return .gray
        }
    }
}

// MARK: - Notification Setting

struct NotificationSetting: Identifiable {
    let id = UUID()
    let key: String
    let title: String
    let description: String
    let category: NotificationCategory
    var isEnabled: Bool
}

// MARK: - Notifications Settings View

struct NotificationsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = NotificationsSettingsViewModel()
    @State private var hasChanges = false

    var body: some View {
        NavigationStack {
            List {
                // Master toggle
                Section {
                    Toggle(isOn: $viewModel.allNotificationsEnabled) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "bell.badge.fill")
                                    .foregroundColor(.orange)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("All Notifications")
                                    .font(.headline)
                                Text("Master toggle for all notifications")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .tint(.orange)
                    .onChange(of: viewModel.allNotificationsEnabled) { _, newValue in
                        viewModel.toggleAllNotifications(enabled: newValue)
                        hasChanges = true
                    }
                }
                .listRowBackground(Color.white.opacity(0.05))

                // Category sections
                ForEach(NotificationCategory.allCases) { category in
                    Section {
                        // Category header with bulk toggle
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundColor(category.color)
                                .frame(width: 24)

                            Text(category.rawValue)
                                .font(.subheadline.weight(.semibold))

                            Spacer()

                            Button {
                                viewModel.toggleCategory(category)
                                hasChanges = true
                            } label: {
                                Text(viewModel.isCategoryEnabled(category) ? "Disable All" : "Enable All")
                                    .font(.caption)
                                    .foregroundColor(category.color)
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.08))

                        // Individual toggles
                        ForEach($viewModel.settings.filter { $0.wrappedValue.category == category }) { $setting in
                            Toggle(isOn: $setting.isEnabled) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(setting.title)
                                        .font(.subheadline)
                                    Text(setting.description)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .tint(category.color)
                            .disabled(!viewModel.allNotificationsEnabled)
                            .onChange(of: setting.isEnabled) { _, _ in
                                hasChanges = true
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                }

                // Delivery preferences
                Section {
                    HStack {
                        Image(systemName: "iphone")
                            .foregroundColor(.blue)
                            .frame(width: 24)

                        Text("Delivery Method")
                            .font(.subheadline.weight(.semibold))
                    }
                    .listRowBackground(Color.white.opacity(0.08))

                    Toggle(isOn: $viewModel.pushNotifications) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Push Notifications")
                                .font(.subheadline)
                            Text("Receive alerts on your device")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .tint(.blue)
                    .listRowBackground(Color.white.opacity(0.05))

                    Toggle(isOn: $viewModel.emailNotifications) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Email Notifications")
                                .font(.subheadline)
                            Text("Receive alerts via email")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .tint(.blue)
                    .listRowBackground(Color.white.opacity(0.05))

                    Toggle(isOn: $viewModel.inAppBadges) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("In-App Badges")
                                .font(.subheadline)
                            Text("Show badge counts in the app")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .tint(.blue)
                    .listRowBackground(Color.white.opacity(0.05))
                } header: {
                    Text("Delivery Preferences")
                }

                // Quiet hours
                Section {
                    Toggle(isOn: $viewModel.quietHoursEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quiet Hours")
                                .font(.subheadline)
                            Text("Silence notifications during set hours")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .tint(.purple)
                    .listRowBackground(Color.white.opacity(0.05))

                    if viewModel.quietHoursEnabled {
                        DatePicker("Start Time", selection: $viewModel.quietHoursStart, displayedComponents: .hourAndMinute)
                            .listRowBackground(Color.white.opacity(0.05))

                        DatePicker("End Time", selection: $viewModel.quietHoursEnd, displayedComponents: .hourAndMinute)
                            .listRowBackground(Color.white.opacity(0.05))
                    }
                } header: {
                    Text("Do Not Disturb")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        viewModel.saveSettings()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!hasChanges)
                }
            }
        }
    }
}

// MARK: - Notifications Settings ViewModel

@MainActor
class NotificationsSettingsViewModel: ObservableObject {
    @Published var allNotificationsEnabled = true
    @Published var settings: [NotificationSetting] = []

    // Delivery preferences
    @Published var pushNotifications = true
    @Published var emailNotifications = true
    @Published var inAppBadges = true

    // Quiet hours
    @Published var quietHoursEnabled = false
    @Published var quietHoursStart = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    @Published var quietHoursEnd = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()

    init() {
        loadSettings()
    }

    private func loadSettings() {
        // Load from UserDefaults or create defaults
        settings = createDefaultSettings()

        // Load saved preferences
        let defaults = UserDefaults.standard
        allNotificationsEnabled = defaults.object(forKey: "notifications.master") as? Bool ?? true
        pushNotifications = defaults.object(forKey: "notifications.push") as? Bool ?? true
        emailNotifications = defaults.object(forKey: "notifications.email") as? Bool ?? true
        inAppBadges = defaults.object(forKey: "notifications.badges") as? Bool ?? true
        quietHoursEnabled = defaults.object(forKey: "notifications.quietHours") as? Bool ?? false

        // Load individual settings
        for i in 0..<settings.count {
            if let saved = defaults.object(forKey: "notifications.\(settings[i].key)") as? Bool {
                settings[i].isEnabled = saved
            }
        }
    }

    private func createDefaultSettings() -> [NotificationSetting] {
        return [
            // Submissions
            NotificationSetting(key: "submission.inquiry.new", title: "New Service Inquiry", description: "When a customer submits a service inquiry", category: .submissions, isEnabled: true),
            NotificationSetting(key: "submission.inquiry.updated", title: "Inquiry Status Updated", description: "When an inquiry status changes", category: .submissions, isEnabled: true),
            NotificationSetting(key: "submission.contact.new", title: "New Contact Form", description: "When someone submits a contact form", category: .submissions, isEnabled: true),
            NotificationSetting(key: "submission.contact.replied", title: "Contact Form Replied", description: "When a contact form is marked as replied", category: .submissions, isEnabled: false),
            NotificationSetting(key: "submission.newsletter.new", title: "New Newsletter Signup", description: "When someone subscribes to newsletter", category: .submissions, isEnabled: true),
            NotificationSetting(key: "submission.newsletter.unsubscribe", title: "Newsletter Unsubscribe", description: "When someone unsubscribes", category: .submissions, isEnabled: false),
            NotificationSetting(key: "submission.discount.new", title: "New Discount Code Request", description: "When a discount code is requested", category: .submissions, isEnabled: true),
            NotificationSetting(key: "submission.discount.used", title: "Discount Code Used", description: "When a discount code is redeemed", category: .submissions, isEnabled: true),

            // Orders & Payments
            NotificationSetting(key: "order.new", title: "New Order", description: "When a new order is placed", category: .orders, isEnabled: true),
            NotificationSetting(key: "order.paid", title: "Payment Received", description: "When payment is confirmed", category: .orders, isEnabled: true),
            NotificationSetting(key: "order.shipped", title: "Order Shipped", description: "When an order is marked as shipped", category: .orders, isEnabled: false),
            NotificationSetting(key: "order.delivered", title: "Order Delivered", description: "When an order is delivered", category: .orders, isEnabled: false),
            NotificationSetting(key: "order.cancelled", title: "Order Cancelled", description: "When an order is cancelled", category: .orders, isEnabled: true),
            NotificationSetting(key: "order.refund.requested", title: "Refund Requested", description: "When a customer requests a refund", category: .orders, isEnabled: true),
            NotificationSetting(key: "order.refund.processed", title: "Refund Processed", description: "When a refund is completed", category: .orders, isEnabled: true),
            NotificationSetting(key: "order.failed", title: "Payment Failed", description: "When a payment fails", category: .orders, isEnabled: true),

            // Vendors
            NotificationSetting(key: "vendor.signup.new", title: "New Vendor Application", description: "When a vendor applies to join", category: .vendors, isEnabled: true),
            NotificationSetting(key: "vendor.onboarding.complete", title: "Vendor Onboarding Complete", description: "When a vendor completes onboarding", category: .vendors, isEnabled: true),
            NotificationSetting(key: "vendor.activated", title: "Vendor Activated", description: "When a vendor is activated", category: .vendors, isEnabled: true),
            NotificationSetting(key: "vendor.deactivated", title: "Vendor Deactivated", description: "When a vendor is deactivated", category: .vendors, isEnabled: true),
            NotificationSetting(key: "vendor.commission.changed", title: "Commission Rate Changed", description: "When a vendor's commission changes", category: .vendors, isEnabled: false),
            NotificationSetting(key: "vendor.product.added", title: "Vendor Product Added", description: "When a vendor adds a new product", category: .vendors, isEnabled: true),
            NotificationSetting(key: "vendor.product.updated", title: "Vendor Product Updated", description: "When a vendor updates a product", category: .vendors, isEnabled: false),
            NotificationSetting(key: "vendor.payout.requested", title: "Payout Requested", description: "When a vendor requests payout", category: .vendors, isEnabled: true),
            NotificationSetting(key: "vendor.payout.sent", title: "Payout Sent", description: "When a payout is processed", category: .vendors, isEnabled: true),

            // Inventory
            NotificationSetting(key: "inventory.low", title: "Low Stock Alert", description: "When product stock is low", category: .inventory, isEnabled: true),
            NotificationSetting(key: "inventory.outofstock", title: "Out of Stock", description: "When a product goes out of stock", category: .inventory, isEnabled: true),
            NotificationSetting(key: "inventory.restock", title: "Product Restocked", description: "When stock is replenished", category: .inventory, isEnabled: false),
            NotificationSetting(key: "inventory.product.created", title: "Product Created", description: "When a new product is added", category: .inventory, isEnabled: true),
            NotificationSetting(key: "inventory.product.deleted", title: "Product Deleted", description: "When a product is removed", category: .inventory, isEnabled: true),
            NotificationSetting(key: "inventory.price.changed", title: "Price Changed", description: "When product price is updated", category: .inventory, isEnabled: false),

            // Users
            NotificationSetting(key: "user.signup", title: "New User Signup", description: "When a new user registers", category: .users, isEnabled: true),
            NotificationSetting(key: "user.verified", title: "User Email Verified", description: "When a user verifies email", category: .users, isEnabled: false),
            NotificationSetting(key: "user.profile.updated", title: "Profile Updated", description: "When a user updates profile", category: .users, isEnabled: false),
            NotificationSetting(key: "user.deleted", title: "Account Deleted", description: "When a user deletes account", category: .users, isEnabled: true),
            NotificationSetting(key: "user.review.submitted", title: "New Review", description: "When a user submits a review", category: .users, isEnabled: true),
            NotificationSetting(key: "user.wishlist.added", title: "Wishlist Item Added", description: "When a user adds to wishlist", category: .users, isEnabled: false),
            NotificationSetting(key: "user.cart.abandoned", title: "Cart Abandoned", description: "When a cart is abandoned", category: .users, isEnabled: true),

            // Marketing
            NotificationSetting(key: "marketing.campaign.started", title: "Campaign Started", description: "When a marketing campaign begins", category: .marketing, isEnabled: true),
            NotificationSetting(key: "marketing.campaign.ended", title: "Campaign Ended", description: "When a marketing campaign ends", category: .marketing, isEnabled: true),
            NotificationSetting(key: "marketing.promo.created", title: "Promotion Created", description: "When a new promotion is created", category: .marketing, isEnabled: true),
            NotificationSetting(key: "marketing.promo.expired", title: "Promotion Expired", description: "When a promotion expires", category: .marketing, isEnabled: false),
            NotificationSetting(key: "marketing.email.sent", title: "Email Blast Sent", description: "When a mass email is sent", category: .marketing, isEnabled: false),
            NotificationSetting(key: "marketing.social.posted", title: "Social Media Posted", description: "When content is posted to social", category: .marketing, isEnabled: false),

            // System
            NotificationSetting(key: "system.error", title: "System Error", description: "When a system error occurs", category: .system, isEnabled: true),
            NotificationSetting(key: "system.backup.complete", title: "Backup Complete", description: "When system backup finishes", category: .system, isEnabled: false),
            NotificationSetting(key: "system.update.available", title: "Update Available", description: "When an app update is available", category: .system, isEnabled: true),
            NotificationSetting(key: "system.maintenance", title: "Maintenance Scheduled", description: "When maintenance is planned", category: .system, isEnabled: true),
            NotificationSetting(key: "system.security.alert", title: "Security Alert", description: "When a security issue is detected", category: .system, isEnabled: true),
            NotificationSetting(key: "system.api.limit", title: "API Rate Limit", description: "When API rate limit is approached", category: .system, isEnabled: true),
        ]
    }

    func toggleAllNotifications(enabled: Bool) {
        for i in 0..<settings.count {
            settings[i].isEnabled = enabled
        }
    }

    func toggleCategory(_ category: NotificationCategory) {
        let categorySettings = settings.enumerated().filter { $0.element.category == category }
        let allEnabled = categorySettings.allSatisfy { $0.element.isEnabled }

        for (index, _) in categorySettings {
            settings[index].isEnabled = !allEnabled
        }
    }

    func isCategoryEnabled(_ category: NotificationCategory) -> Bool {
        let categorySettings = settings.filter { $0.category == category }
        return categorySettings.allSatisfy { $0.isEnabled }
    }

    func saveSettings() {
        let defaults = UserDefaults.standard

        defaults.set(allNotificationsEnabled, forKey: "notifications.master")
        defaults.set(pushNotifications, forKey: "notifications.push")
        defaults.set(emailNotifications, forKey: "notifications.email")
        defaults.set(inAppBadges, forKey: "notifications.badges")
        defaults.set(quietHoursEnabled, forKey: "notifications.quietHours")

        for setting in settings {
            defaults.set(setting.isEnabled, forKey: "notifications.\(setting.key)")
        }
    }
}

// MARK: - Preview

#Preview {
    NotificationsSettingsView()
}

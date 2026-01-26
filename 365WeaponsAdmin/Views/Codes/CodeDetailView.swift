//
//  CodeDetailView.swift
//  365WeaponsAdmin
//
//  Detail view for viewing and managing a discount code
//

import SwiftUI
import MessageUI

struct CodeDetailView: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @Environment(\.dismiss) private var dismiss
    let code: EnrichedDiscountCode
    @ObservedObject var viewModel: CodesViewModel

    @State private var showShareSheet = false
    @State private var showEmailComposer = false
    @State private var emailRecipient = ""
    @State private var showEmailInput = false

    private let exampleOrderTotal: Double = 100.0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Card
                    headerCard

                    // Discount Details
                    discountDetailsCard

                    // Commission Details
                    if code.commissionEnabled == true {
                        commissionDetailsCard
                    }

                    // Usage Stats
                    usageStatsCard

                    // Product Restriction
                    productRestrictionCard

                    // Quick Actions
                    quickActionsCard

                    // Code Info
                    codeInfoCard
                }
                .padding()
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Code Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            Task {
                                try? await viewModel.toggleCodeActive(code)
                                dismiss()
                            }
                        } label: {
                            Label(code.active ? "Deactivate" : "Activate",
                                  systemImage: code.active ? "xmark.circle" : "checkmark.circle")
                        }

                        Button {
                            showShareSheet = true
                        } label: {
                            Label("Share Code", systemImage: "square.and.arrow.up")
                        }

                        Button(role: .destructive) {
                            Task {
                                try? await viewModel.deleteCode(code)
                                dismiss()
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                CodeShareSheet(items: [shareText])
            }
            .alert("Send Code via Email", isPresented: $showEmailInput) {
                TextField("Email address", text: $emailRecipient)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                Button("Cancel", role: .cancel) {}
                Button("Send") {
                    sendEmail()
                }
            } message: {
                Text("Enter the recipient's email address")
            }
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: 16) {
            // Code badge
            Text(code.code)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundColor(.pink)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.pink.opacity(0.15))
                .cornerRadius(12)

            // Status
            HStack(spacing: 12) {
                StatusPill(
                    text: code.active ? "Active" : "Inactive",
                    color: code.active ? .green : .gray
                )

                if let partnerName = code.partnerName {
                    StatusPill(text: partnerName, color: .purple)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.appSurface)
        .cornerRadius(16)
    }

    // MARK: - Discount Details Card

    private var discountDetailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderLabel(title: "Discount", icon: "tag.fill", color: .green)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Type")
                        .font(.caption)
                        .foregroundColor(Color.appTextSecondary)
                    Text(code.discountType.displayName)
                        .font(.subheadline.weight(.medium))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Value")
                        .font(.caption)
                        .foregroundColor(Color.appTextSecondary)
                    Text(code.formattedDiscount)
                        .font(.title3.weight(.bold))
                        .foregroundColor(.green)
                }
            }

            Divider()

            // Example calculation
            let discountAmount = code.discountAmount(for: exampleOrderTotal)
            let afterDiscount = exampleOrderTotal - discountAmount

            VStack(alignment: .leading, spacing: 4) {
                Text("Example on $\(String(format: "%.2f", exampleOrderTotal)) order:")
                    .font(.caption)
                    .foregroundColor(Color.appTextSecondary)
                Text("Customer saves $\(String(format: "%.2f", discountAmount)) (pays $\(String(format: "%.2f", afterDiscount)))")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
        }
        .padding(16)
        .background(Color.appSurface)
        .cornerRadius(12)
    }

    // MARK: - Commission Details Card

    private var commissionDetailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderLabel(title: "Commission", icon: "dollarsign.circle.fill", color: Color.appAccent)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Type")
                        .font(.caption)
                        .foregroundColor(Color.appTextSecondary)
                    Text(code.commissionType?.displayName ?? "N/A")
                        .font(.subheadline.weight(.medium))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Value")
                        .font(.caption)
                        .foregroundColor(Color.appTextSecondary)
                    Text(code.formattedCommission ?? "N/A")
                        .font(.title3.weight(.bold))
                        .foregroundColor(Color.appAccent)
                }
            }

            Divider()

            // Example calculation
            let commissionAmount = code.commissionAmount(for: exampleOrderTotal)

            VStack(alignment: .leading, spacing: 4) {
                Text("Example on $\(String(format: "%.2f", exampleOrderTotal)) order:")
                    .font(.caption)
                    .foregroundColor(Color.appTextSecondary)
                Text("Partner earns $\(String(format: "%.2f", commissionAmount))")
                    .font(.subheadline)
                    .foregroundColor(Color.appAccent)
            }
        }
        .padding(16)
        .background(Color.appSurface)
        .cornerRadius(12)
    }

    // MARK: - Usage Stats Card

    private var usageStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderLabel(title: "Usage", icon: "chart.bar.fill", color: .blue)

            HStack(spacing: 20) {
                UsageStatItem(
                    title: "Times Used",
                    value: "\(code.usageCount)",
                    color: .blue
                )

                Divider()
                    .frame(height: 40)

                UsageStatItem(
                    title: "Max Usage",
                    value: code.maxUsage != nil ? "\(code.maxUsage!)" : "Unlimited",
                    color: .purple
                )

                if let maxUsage = code.maxUsage {
                    Divider()
                        .frame(height: 40)

                    UsageStatItem(
                        title: "Remaining",
                        value: "\(max(0, maxUsage - code.usageCount))",
                        color: .green
                    )
                }
            }
        }
        .padding(16)
        .background(Color.appSurface)
        .cornerRadius(12)
    }

    // MARK: - Product Restriction Card

    private var productRestrictionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderLabel(title: "Product Restriction", icon: "cube.box.fill", color: .cyan)

            HStack {
                Image(systemName: productIcon)
                    .font(.title2)
                    .foregroundColor(.cyan)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(productRestrictionText)
                        .font(.subheadline.weight(.medium))
                    Text(productRestrictionDescription)
                        .font(.caption)
                        .foregroundColor(Color.appTextSecondary)
                }

                Spacer()
            }
        }
        .padding(16)
        .background(Color.appSurface)
        .cornerRadius(12)
    }

    private var productIcon: String {
        if code.isCustomProduct == true {
            return "doc.text"
        } else if code.productId != nil {
            return "cube"
        }
        return "square.grid.2x2"
    }

    private var productRestrictionText: String {
        if code.isCustomProduct == true {
            return "Custom (Invoice Only)"
        } else if let productName = code.productName {
            return productName
        }
        return "All Products"
    }

    private var productRestrictionDescription: String {
        if code.isCustomProduct == true {
            return "This code can only be used on custom invoices"
        } else if code.productId != nil {
            return "This code is restricted to a specific product"
        }
        return "This code can be used on any product"
    }

    // MARK: - Quick Actions Card

    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderLabel(title: "Quick Actions", icon: "bolt.fill", color: .yellow)

            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Copy",
                    icon: "doc.on.doc",
                    color: .blue
                ) {
                    UIPasteboard.general.string = code.code
                }

                QuickActionButton(
                    title: "Share",
                    icon: "square.and.arrow.up",
                    color: .green
                ) {
                    showShareSheet = true
                }

                QuickActionButton(
                    title: "Email",
                    icon: "envelope",
                    color: Color.appAccent
                ) {
                    showEmailInput = true
                }
            }
        }
        .padding(16)
        .background(Color.appSurface)
        .cornerRadius(12)
    }

    // MARK: - Code Info Card

    private var codeInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderLabel(title: "Information", icon: "info.circle.fill", color: .gray)

            CodeInfoRow(label: "Created", value: code.createdAt.formatted(date: .abbreviated, time: .shortened))

            if let expiresAt = code.expiresAt {
                CodeInfoRow(label: "Expires", value: expiresAt.formatted(date: .abbreviated, time: .omitted))
            } else {
                CodeInfoRow(label: "Expires", value: "Never")
            }

            if let stripeCouponId = code.stripeCouponId {
                CodeInfoRow(label: "Stripe ID", value: stripeCouponId)
            }

            CodeInfoRow(label: "Code ID", value: String(code.id.prefix(20)) + "...")
        }
        .padding(16)
        .background(Color.appSurface)
        .cornerRadius(12)
    }

    // MARK: - Helpers

    private var shareText: String {
        var text = "Use code \(code.code) for \(code.formattedDiscount)"
        if let productName = code.productName {
            text += " on \(productName)"
        }
        text += " at 365 Weapons!"
        return text
    }

    private func sendEmail() {
        guard !emailRecipient.isEmpty else { return }

        let subject = "Your Discount Code from 365 Weapons"
        let body = """
        Hi,

        Here's your exclusive discount code: \(code.code)

        \(code.formattedDiscount) off your order!

        Visit 365weapons.com to use your code.

        Thank you for your business!
        365 Weapons Team
        """

        if let url = URL(string: "mailto:\(emailRecipient)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Supporting Views

struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(12)
    }
}

struct SectionHeaderLabel: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
                .font(.headline)
        }
    }
}

struct UsageStatItem: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct QuickActionButton: View {
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

struct CodeInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(Color.appTextSecondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(Color.appTextPrimary)
        }
    }
}

// MARK: - Share Sheet

struct CodeShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    CodeDetailView(
        code: EnrichedDiscountCode(
            id: "test",
            code: "TEST20",
            partnerStoreId: "partner_1",
            discountType: .percentage,
            discountValue: 20,
            usageCount: 15,
            maxUsage: 100,
            active: true,
            expiresAt: Date().addingTimeInterval(86400 * 30),
            createdAt: Date().addingTimeInterval(-86400 * 10),
            stripeCouponId: nil,
            productId: nil,
            isCustomProduct: nil,
            commissionEnabled: true,
            commissionType: .percentage,
            commissionValue: 10,
            partnerName: "Test Partner",
            productName: nil
        ),
        viewModel: CodesViewModel()
    )
}

//
//  ContentView.swift
//  365WeaponsAdmin
//
//  Main content view with scrollable tab navigation
//

import SwiftUI
import Clerk

struct ContentView: View {
    @EnvironmentObject var orchestrator: OrchestrationAgent
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var configManager: ConfigurationManager
    @Environment(\.clerk) private var clerk

    @State private var showAuthSheet = false
    @State private var selectedTab: Tab = .dashboard

    // Lazy view state - only create views when first accessed
    @State private var dashboardView: DashboardView?
    @State private var ordersView: OrdersView?
    @State private var productsView: ProductsView?
    @State private var vendorsView: VendorsView?
    @State private var customersView: CustomersView?
    @State private var messagingView: MessagingView?
    @State private var codesView: CodesView?
    @State private var paymentsView: PaymentsView?
    @State private var chatView: AIChatView?
    @State private var settingsView: SettingsView?

    enum Tab: String, CaseIterable {
        case dashboard = "Dashboard"
        case orders = "Orders"
        case products = "Products"
        case messaging = "Messages"
        case codes = "Codes"
        case payments = "Pay"
        case chat = "AI Chat"
        case vendors = "Vendors"
        case customers = "Customers"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .dashboard: return "square.grid.2x2"
            case .orders: return "list.clipboard"
            case .products: return "cube.box"
            case .messaging: return "envelope.badge"
            case .codes: return "tag"
            case .payments: return "dollarsign.circle"
            case .vendors: return "person.2"
            case .customers: return "person.3"
            case .chat: return "bubble.left.and.bubble.right"
            case .settings: return "gearshape"
            }
        }
    }

    /// Check if Clerk authentication is configured
    private var isClerkConfigured: Bool {
        configManager.clerkPublishableKey != nil && !configManager.clerkPublishableKey!.isEmpty
    }

    var body: some View {
        Group {
            // Skip Clerk auth if not configured - go directly to main content
            if !isClerkConfigured || clerk.user != nil {
                mainContent
                    .toolbar {
                        if isClerkConfigured, clerk.user != nil {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                UserButton()
                            }
                        }
                    }
            } else {
                LoginView()
                    .onAppear {
                        showAuthSheet = true
                    }
            }
        }
        .sheet(isPresented: $showAuthSheet) {
            if isClerkConfigured {
                AuthView()
            }
        }
    }

    private var mainContent: some View {
        ZStack {
            // Main content area - use ZStack with opacity for tab switching
            // This preserves view state instead of recreating views
            ZStack {
                // Dashboard
                NavigationStack {
                    getDashboardView()
                }
                .opacity(selectedTab == .dashboard ? 1 : 0)
                .zIndex(selectedTab == .dashboard ? 1 : 0)

                // Orders
                NavigationStack {
                    getOrdersView()
                }
                .opacity(selectedTab == .orders ? 1 : 0)
                .zIndex(selectedTab == .orders ? 1 : 0)

                // Products
                NavigationStack {
                    getProductsView()
                }
                .opacity(selectedTab == .products ? 1 : 0)
                .zIndex(selectedTab == .products ? 1 : 0)

                // Messaging
                NavigationStack {
                    getMessagingView()
                }
                .opacity(selectedTab == .messaging ? 1 : 0)
                .zIndex(selectedTab == .messaging ? 1 : 0)

                // Codes
                NavigationStack {
                    getCodesView()
                }
                .opacity(selectedTab == .codes ? 1 : 0)
                .zIndex(selectedTab == .codes ? 1 : 0)

                // Payments
                NavigationStack {
                    getPaymentsView()
                }
                .opacity(selectedTab == .payments ? 1 : 0)
                .zIndex(selectedTab == .payments ? 1 : 0)

                // Vendors
                NavigationStack {
                    getVendorsView()
                }
                .opacity(selectedTab == .vendors ? 1 : 0)
                .zIndex(selectedTab == .vendors ? 1 : 0)

                // Customers
                NavigationStack {
                    getCustomersView()
                }
                .opacity(selectedTab == .customers ? 1 : 0)
                .zIndex(selectedTab == .customers ? 1 : 0)

                // Chat (no NavigationStack needed)
                getChatView()
                    .opacity(selectedTab == .chat ? 1 : 0)
                    .zIndex(selectedTab == .chat ? 1 : 0)

                // Settings
                NavigationStack {
                    getSettingsView()
                }
                .opacity(selectedTab == .settings ? 1 : 0)
                .zIndex(selectedTab == .settings ? 1 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Scrollable Tab Bar
            VStack {
                Spacer()
                ScrollableTabBar(selectedTab: $selectedTab)
            }
        }
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - Lazy View Getters

    @ViewBuilder
    private func getDashboardView() -> some View {
        if let view = dashboardView {
            view
        } else {
            DashboardView()
                .onAppear { dashboardView = DashboardView() }
        }
    }

    @ViewBuilder
    private func getOrdersView() -> some View {
        if let view = ordersView {
            view
        } else {
            OrdersView()
                .onAppear { ordersView = OrdersView() }
        }
    }

    @ViewBuilder
    private func getProductsView() -> some View {
        if let view = productsView {
            view
        } else {
            ProductsView()
                .onAppear { productsView = ProductsView() }
        }
    }

    @ViewBuilder
    private func getMessagingView() -> some View {
        if let view = messagingView {
            view
        } else {
            MessagingView()
                .onAppear { messagingView = MessagingView() }
        }
    }

    @ViewBuilder
    private func getCodesView() -> some View {
        if let view = codesView {
            view
        } else {
            CodesView()
                .onAppear { codesView = CodesView() }
        }
    }

    @ViewBuilder
    private func getPaymentsView() -> some View {
        if let view = paymentsView {
            view
        } else {
            PaymentsView()
                .onAppear { paymentsView = PaymentsView() }
        }
    }

    @ViewBuilder
    private func getVendorsView() -> some View {
        if let view = vendorsView {
            view
        } else {
            VendorsView()
                .onAppear { vendorsView = VendorsView() }
        }
    }

    @ViewBuilder
    private func getCustomersView() -> some View {
        if let view = customersView {
            view
        } else {
            CustomersView()
                .onAppear { customersView = CustomersView() }
        }
    }

    @ViewBuilder
    private func getChatView() -> some View {
        if let view = chatView {
            view
        } else {
            AIChatView()
                .onAppear { chatView = AIChatView() }
        }
    }

    @ViewBuilder
    private func getSettingsView() -> some View {
        if let view = settingsView {
            view
        } else {
            SettingsView()
                .onAppear { settingsView = SettingsView() }
        }
    }
}

// MARK: - Scrollable Tab Bar
struct ScrollableTabBar: View {
    @Binding var selectedTab: ContentView.Tab
    @ObservedObject private var appearanceManager = AppearanceManager.shared

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(ContentView.Tab.allCases, id: \.self) { tab in
                        tabButton(for: tab)
                            .id(tab)
                    }
                }
                .padding(.horizontal, 8)
            }
            .padding(.top, 8)
            .padding(.bottom, 16)
            .background(
                // Solid background with top border
                VStack(spacing: 0) {
                    // Top border
                    Rectangle()
                        .fill(Color.appBorder)
                        .frame(height: 1)

                    // Solid background
                    Rectangle()
                        .fill(Color.appSurface)
                }
            )
            .shadow(color: Color.appTextPrimary.opacity(0.1), radius: 8, x: 0, y: -4)
            .onChange(of: selectedTab) { _, newTab in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(newTab, anchor: .center)
                }
            }
        }
    }

    private func tabButton(for tab: ContentView.Tab) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20))
                    .symbolEffect(.bounce, value: selectedTab == tab)
                Text(tab.rawValue)
                    .font(.caption2)
            }
            .foregroundColor(selectedTab == tab ? Color.appTextPrimary : Color.appTextSecondary)
            .frame(width: 68)
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Login View (Welcome Screen)
struct LoginView: View {
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.appBackground, Color.appSurface],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Logo and title
                VStack(spacing: 16) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.appAccent, Color.appDanger],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("365 Weapons")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(Color.appTextPrimary)

                    Text("Admin Dashboard")
                        .font(.title3)
                        .foregroundColor(Color.appTextSecondary)
                }

                // Loading indicator
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.appAccent))
                        .scaleEffect(1.5)

                    Text("Loading authentication...")
                        .font(.subheadline)
                        .foregroundColor(Color.appTextSecondary)
                }

                Spacer()

                // Admin access note
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.shield")
                        .foregroundColor(Color.appAccent)
                    Text("Admin access required")
                        .font(.caption)
                        .foregroundColor(Color.appTextSecondary)
                }
                .padding(.bottom, 40)
            }
            .padding()
        }
    }
}

// MARK: - Custom Text Field
struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Color.appTextSecondary)
                .frame(width: 24)

            TextField(placeholder, text: $text)
                .foregroundColor(Color.appTextPrimary)
        }
        .padding()
        .background(Color.appSurface2)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.appSurface2, lineWidth: 1)
        )
    }
}

// MARK: - Custom Secure Field
struct CustomSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @State private var showPassword = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Color.appTextSecondary)
                .frame(width: 24)

            if showPassword {
                TextField(placeholder, text: $text)
                    .foregroundColor(Color.appTextPrimary)
            } else {
                SecureField(placeholder, text: $text)
                    .foregroundColor(Color.appTextPrimary)
            }

            Button(action: { showPassword.toggle() }) {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .foregroundColor(Color.appTextSecondary)
            }
        }
        .padding()
        .background(Color.appSurface2)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.appSurface2, lineWidth: 1)
        )
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .environmentObject(OrchestrationAgent.shared)
        .environmentObject(AppState.shared)
}

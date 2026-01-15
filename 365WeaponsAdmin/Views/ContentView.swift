//
//  ContentView.swift
//  365WeaponsAdmin
//
//  Main content view with tab navigation
//

import SwiftUI
import Clerk

struct ContentView: View {
    @EnvironmentObject var orchestrator: OrchestrationAgent
    @EnvironmentObject var appState: AppState
    @Environment(\.clerk) private var clerk

    @State private var showAuthSheet = false
    @State private var selectedTab: Tab = .dashboard
    @State private var showSettings = false

    enum Tab: String, CaseIterable {
        case dashboard = "Dashboard"
        case orders = "Orders"
        case products = "Products"
        case chat = "AI Chat"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .dashboard: return "square.grid.2x2"
            case .orders: return "list.clipboard"
            case .products: return "cube.box"
            case .chat: return "bubble.left.and.bubble.right"
            case .settings: return "gearshape"
            }
        }
    }

    var body: some View {
        Group {
            if let user = clerk.user {
                mainContent
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            UserButton()
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
            AuthView()
        }
        .preferredColorScheme(.dark)
    }

    private var mainContent: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label(Tab.dashboard.rawValue, systemImage: Tab.dashboard.icon)
                }
                .tag(Tab.dashboard)

            OrdersView()
                .tabItem {
                    Label(Tab.orders.rawValue, systemImage: Tab.orders.icon)
                }
                .tag(Tab.orders)

            ProductsView()
                .tabItem {
                    Label(Tab.products.rawValue, systemImage: Tab.products.icon)
                }
                .tag(Tab.products)

            AIChatView()
                .tabItem {
                    Label(Tab.chat.rawValue, systemImage: Tab.chat.icon)
                }
                .tag(Tab.chat)

            SettingsView()
                .tabItem {
                    Label(Tab.settings.rawValue, systemImage: Tab.settings.icon)
                }
                .tag(Tab.settings)
        }
        .tint(.orange)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

// MARK: - Login View (Welcome Screen)
struct LoginView: View {
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.black, Color(red: 0.1, green: 0.1, blue: 0.15)],
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
                                colors: [.orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("365 Weapons")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Admin Dashboard")
                        .font(.title3)
                        .foregroundColor(.gray)
                }

                // Loading indicator
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                        .scaleEffect(1.5)

                    Text("Loading authentication...")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                Spacer()

                // Admin access note
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.shield")
                        .foregroundColor(.orange)
                    Text("Admin access required")
                        .font(.caption)
                        .foregroundColor(.gray)
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
                .foregroundColor(.gray)
                .frame(width: 24)

            TextField(placeholder, text: $text)
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
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
                .foregroundColor(.gray)
                .frame(width: 24)

            if showPassword {
                TextField(placeholder, text: $text)
                    .foregroundColor(.white)
            } else {
                SecureField(placeholder, text: $text)
                    .foregroundColor(.white)
            }

            Button(action: { showPassword.toggle() }) {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .environmentObject(OrchestrationAgent.shared)
        .environmentObject(AppState.shared)
}

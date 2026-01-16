//
//  DefaultKeys.example.swift
//  365WeaponsAdmin
//
//  TEMPLATE - Copy this file to DefaultKeys.swift and fill in your keys
//  DefaultKeys.swift is gitignored to keep your keys secure
//

import Foundation

/// Default API keys for the app
/// These are pre-configured and stored securely in Keychain on first launch
struct DefaultKeys {
    // Get from: https://openrouter.ai/keys
    static let openRouterAPIKey = "sk-or-your-key-here"

    // Get from: https://platform.openai.com/api-keys
    static let openAIAPIKey = "sk-your-key-here"

    // Generate with: openssl rand -hex 32
    static let backendAuthToken = "your-backend-auth-token"

    // Your Convex deployment URL
    static let convexDeploymentURL = "https://your-project.convex.cloud"

    // Optional: Clerk publishable key for authentication
    // Get from: https://dashboard.clerk.com
    static let clerkPublishableKey = ""
}

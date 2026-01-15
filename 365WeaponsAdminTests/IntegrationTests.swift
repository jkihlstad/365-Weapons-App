//
//  IntegrationTests.swift
//  365WeaponsAdminTests
//
//  Integration tests - simplified to match actual implementation
//

import XCTest
@testable import _65WeaponsAdmin

final class IntegrationTests: XCTestCase {

    // MARK: - Agent Integration Tests

    func test_dashboardAgent_canHandleRevenueQuery() {
        let agent = DashboardAgent()
        let input = AgentInput(message: "What is our revenue?")
        XCTAssertTrue(agent.canHandle(input: input))
    }

    func test_productsAgent_canHandleProductQuery() {
        let agent = ProductsAgent()
        let input = AgentInput(message: "Show me all products")
        XCTAssertTrue(agent.canHandle(input: input))
    }

    func test_chatAgent_canHandleHelpQuery() {
        let agent = ChatAgent()
        let input = AgentInput(message: "Help me understand the dashboard")
        XCTAssertTrue(agent.canHandle(input: input))
    }

    // MARK: - Agent Routing Tests

    func test_agentRouting_revenueQuery_goesToDashboard() {
        let dashboardAgent = DashboardAgent()
        let productsAgent = ProductsAgent()

        let input = AgentInput(message: "What is our total revenue this month?")

        XCTAssertTrue(dashboardAgent.canHandle(input: input))
        XCTAssertFalse(productsAgent.canHandle(input: input))
    }

    func test_agentRouting_productQuery_goesToProducts() {
        let dashboardAgent = DashboardAgent()
        let productsAgent = ProductsAgent()

        let input = AgentInput(message: "List all products in the catalog")

        XCTAssertFalse(dashboardAgent.canHandle(input: input))
        XCTAssertTrue(productsAgent.canHandle(input: input))
    }

    // MARK: - Model Tests

    func test_dashboardStats_creation() {
        let stats = DashboardStats(
            totalRevenue: 25000.0,
            totalOrders: 150,
            totalProducts: 45,
            totalPartners: 12,
            pendingOrders: 8,
            pendingInquiries: 3,
            eligibleCommissions: 1250.0,
            revenueGrowth: 15.5,
            orderGrowth: 8.3
        )

        XCTAssertEqual(stats.totalRevenue, 25000.0)
        XCTAssertEqual(stats.totalOrders, 150)
        XCTAssertEqual(stats.totalProducts, 45)
        XCTAssertEqual(stats.pendingOrders, 8)
    }

    func test_agentOutput_creation() {
        let output = AgentOutput(
            response: "Total revenue is $25,000",
            agentName: "dashboard",
            toolsUsed: ["fetchStats"],
            confidence: 0.95
        )

        XCTAssertEqual(output.response, "Total revenue is $25,000")
        XCTAssertEqual(output.agentName, "dashboard")
        XCTAssertEqual(output.toolsUsed.count, 1)
        XCTAssertEqual(output.confidence, 0.95)
    }

    func test_agentInput_creation() {
        let input = AgentInput(
            message: "Show me the dashboard",
            context: ["userId": "123"],
            metadata: ["source": "test"]
        )

        XCTAssertEqual(input.message, "Show me the dashboard")
        XCTAssertEqual(input.context["userId"] as? String, "123")
        XCTAssertEqual(input.metadata["source"], "test")
    }

    // MARK: - Error Type Tests

    func test_convexError_types() {
        XCTAssertNotNil(ConvexError.invalidResponse.errorDescription)
        XCTAssertNotNil(ConvexError.noData.errorDescription)
        XCTAssertNotNil(ConvexError.queryError(message: "test").errorDescription)
    }

    func test_openRouterError_types() {
        XCTAssertNotNil(OpenRouterError.notConfigured.errorDescription)
        XCTAssertNotNil(OpenRouterError.invalidResponse.errorDescription)
    }

    // MARK: - Client Singleton Tests

    func test_convexClient_isSingleton() {
        let client1 = ConvexClient.shared
        let client2 = ConvexClient.shared
        XCTAssertTrue(client1 === client2)
    }

    func test_openRouterClient_isSingleton() {
        let client1 = OpenRouterClient.shared
        let client2 = OpenRouterClient.shared
        XCTAssertTrue(client1 === client2)
    }

    func test_openAIClient_isSingleton() {
        let client1 = OpenAIClient.shared
        let client2 = OpenAIClient.shared
        XCTAssertTrue(client1 === client2)
    }

    // MARK: - Config Tests

    func test_convexConfig_endpoints() {
        XCTAssertFalse(ConvexConfig.deploymentURL.isEmpty)
        XCTAssertTrue(ConvexConfig.httpEndpoint.contains("/api"))
    }

    func test_openAIConfig_values() {
        XCTAssertEqual(OpenAIConfig.whisperModel, "whisper-1")
        XCTAssertFalse(OpenAIConfig.availableVoices.isEmpty)
    }

    func test_lanceDBConfig_values() {
        XCTAssertEqual(LanceDBConfig.embeddingDimension, 1536)
        XCTAssertFalse(LanceDBConfig.embeddingModel.isEmpty)
    }
}

//
//  AgentTests.swift
//  365WeaponsAdminTests
//
//  Tests for agents - simplified to match actual implementation
//

import XCTest
@testable import _65WeaponsAdmin

final class AgentTests: XCTestCase {

    // MARK: - Dashboard Agent Tests

    func test_dashboardAgent_initialization_hasCorrectName() {
        let agent = DashboardAgent()
        XCTAssertEqual(agent.name, "dashboard")
    }

    func test_dashboardAgent_initialization_isNotProcessing() {
        let agent = DashboardAgent()
        XCTAssertFalse(agent.isProcessing)
    }

    func test_dashboardAgent_canHandle_revenueQuery_returnsTrue() {
        let agent = DashboardAgent()
        let input = AgentInput(message: "What is our revenue this month?")
        XCTAssertTrue(agent.canHandle(input: input))
    }

    func test_dashboardAgent_canHandle_salesQuery_returnsTrue() {
        let agent = DashboardAgent()
        let input = AgentInput(message: "Show me sales data")
        XCTAssertTrue(agent.canHandle(input: input))
    }

    func test_dashboardAgent_canHandle_ordersQuery_returnsTrue() {
        let agent = DashboardAgent()
        let input = AgentInput(message: "How many orders today?")
        XCTAssertTrue(agent.canHandle(input: input))
    }

    func test_dashboardAgent_canHandle_statsQuery_returnsTrue() {
        let agent = DashboardAgent()
        let input = AgentInput(message: "Show me statistics")
        XCTAssertTrue(agent.canHandle(input: input))
    }

    func test_dashboardAgent_canHandle_weatherQuery_returnsFalse() {
        let agent = DashboardAgent()
        let input = AgentInput(message: "What's the weather like?")
        XCTAssertFalse(agent.canHandle(input: input))
    }

    func test_dashboardAgent_canHandle_emptyMessage_returnsFalse() {
        let agent = DashboardAgent()
        let input = AgentInput(message: "")
        XCTAssertFalse(agent.canHandle(input: input))
    }

    // MARK: - Products Agent Tests

    func test_productsAgent_initialization_hasCorrectName() {
        let agent = ProductsAgent()
        XCTAssertEqual(agent.name, "products")
    }

    func test_productsAgent_initialization_isNotProcessing() {
        let agent = ProductsAgent()
        XCTAssertFalse(agent.isProcessing)
    }

    func test_productsAgent_canHandle_listProductsQuery_returnsTrue() {
        let agent = ProductsAgent()
        let input = AgentInput(message: "Show me all products")
        XCTAssertTrue(agent.canHandle(input: input))
    }

    func test_productsAgent_canHandle_stockQuery_returnsTrue() {
        let agent = ProductsAgent()
        let input = AgentInput(message: "What's in stock?")
        XCTAssertTrue(agent.canHandle(input: input))
    }

    func test_productsAgent_canHandle_inventoryQuery_returnsTrue() {
        let agent = ProductsAgent()
        let input = AgentInput(message: "Check inventory levels")
        XCTAssertTrue(agent.canHandle(input: input))
    }

    func test_productsAgent_canHandle_orderQuery_returnsFalse() {
        let agent = ProductsAgent()
        let input = AgentInput(message: "Show me recent orders")
        XCTAssertFalse(agent.canHandle(input: input))
    }

    // MARK: - Chat Agent Tests

    func test_chatAgent_initialization_hasCorrectName() {
        let agent = ChatAgent()
        XCTAssertEqual(agent.name, "chat")
    }

    func test_chatAgent_initialization_isNotProcessing() {
        let agent = ChatAgent()
        XCTAssertFalse(agent.isProcessing)
    }

    func test_chatAgent_initialization_isNotListening() {
        let agent = ChatAgent()
        XCTAssertFalse(agent.isListening)
    }

    func test_chatAgent_initialization_isNotSpeaking() {
        let agent = ChatAgent()
        XCTAssertFalse(agent.isSpeaking)
    }

    func test_chatAgent_initialization_hasEmptyHistory() {
        let agent = ChatAgent()
        XCTAssertTrue(agent.conversationHistory.isEmpty)
    }

    func test_chatAgent_canHandle_helpQuery_returnsTrue() {
        let agent = ChatAgent()
        let input = AgentInput(message: "Help me understand the dashboard")
        XCTAssertTrue(agent.canHandle(input: input))
    }

    func test_chatAgent_canHandle_howToQuery_returnsTrue() {
        let agent = ChatAgent()
        let input = AgentInput(message: "How do I create an order?")
        XCTAssertTrue(agent.canHandle(input: input))
    }

    func test_chatAgent_clearHistory_removesAllMessages() {
        let agent = ChatAgent()
        agent.conversationHistory.append(ChatCompletionMessage(role: "user", content: "Test"))
        agent.conversationHistory.append(ChatCompletionMessage(role: "assistant", content: "Response"))

        XCTAssertEqual(agent.conversationHistory.count, 2)

        agent.clearHistory()

        XCTAssertTrue(agent.conversationHistory.isEmpty)
    }

    // MARK: - Agent Input Tests

    func test_agentInput_creation_setsMessage() {
        let input = AgentInput(message: "Test message")
        XCTAssertEqual(input.message, "Test message")
    }

    func test_agentInput_creation_withContext_setsContext() {
        let input = AgentInput(
            message: "Test",
            context: ["userId": "123", "sessionId": "abc"]
        )
        XCTAssertEqual(input.context["userId"] as? String, "123")
        XCTAssertEqual(input.context["sessionId"] as? String, "abc")
    }

    func test_agentInput_creation_withMetadata_setsMetadata() {
        let input = AgentInput(
            message: "Test",
            metadata: ["source": "test", "priority": "high"]
        )
        XCTAssertEqual(input.metadata["source"], "test")
        XCTAssertEqual(input.metadata["priority"], "high")
    }

    // MARK: - Agent Output Tests

    func test_agentOutput_creation_setsResponse() {
        let output = AgentOutput(response: "Test response", agentName: "test_agent")
        XCTAssertEqual(output.response, "Test response")
    }

    func test_agentOutput_creation_setsAgentName() {
        let output = AgentOutput(response: "Response", agentName: "dashboard_agent")
        XCTAssertEqual(output.agentName, "dashboard_agent")
    }

    func test_agentOutput_creation_withToolsUsed_setsTools() {
        let output = AgentOutput(
            response: "Response",
            agentName: "test",
            toolsUsed: ["fetchOrders", "calculateRevenue"]
        )
        XCTAssertEqual(output.toolsUsed.count, 2)
        XCTAssertTrue(output.toolsUsed.contains("fetchOrders"))
    }

    func test_agentOutput_creation_withConfidence_setsConfidence() {
        let output = AgentOutput(
            response: "High confidence response",
            agentName: "test",
            confidence: 0.95
        )
        XCTAssertEqual(output.confidence, 0.95)
    }

    func test_agentOutput_creation_withSuggestedActions_setsActions() {
        let actions = [
            SuggestedAction(title: "View", action: "view", icon: "eye"),
            SuggestedAction(title: "Edit", action: "edit", icon: "pencil")
        ]
        let output = AgentOutput(
            response: "Response",
            agentName: "test",
            suggestedActions: actions
        )
        XCTAssertEqual(output.suggestedActions.count, 2)
    }

    // MARK: - Suggested Action Tests

    func test_suggestedAction_creation_setsTitle() {
        let action = SuggestedAction(title: "View Orders", action: "navigate_orders", icon: "list.clipboard")
        XCTAssertEqual(action.title, "View Orders")
    }

    func test_suggestedAction_creation_setsAction() {
        let action = SuggestedAction(title: "View Orders", action: "navigate_orders", icon: "list.clipboard")
        XCTAssertEqual(action.action, "navigate_orders")
    }

    func test_suggestedAction_creation_setsIcon() {
        let action = SuggestedAction(title: "View Orders", action: "navigate_orders", icon: "list.clipboard")
        XCTAssertEqual(action.icon, "list.clipboard")
    }

    func test_suggestedAction_creation_generatesUniqueId() {
        let action1 = SuggestedAction(title: "Action 1", action: "action1", icon: "icon1")
        let action2 = SuggestedAction(title: "Action 2", action: "action2", icon: "icon2")
        XCTAssertNotEqual(action1.id, action2.id)
    }

    // MARK: - Agent Routing Tests

    func test_intentClassification_revenueQuery_routesToDashboard() {
        let dashboardAgent = DashboardAgent()
        let productsAgent = ProductsAgent()
        let input = AgentInput(message: "What is our total revenue?")

        XCTAssertTrue(dashboardAgent.canHandle(input: input))
        XCTAssertFalse(productsAgent.canHandle(input: input))
    }

    func test_intentClassification_productQuery_routesToProducts() {
        let dashboardAgent = DashboardAgent()
        let productsAgent = ProductsAgent()
        let input = AgentInput(message: "List all products in the catalog")

        XCTAssertFalse(dashboardAgent.canHandle(input: input))
        XCTAssertTrue(productsAgent.canHandle(input: input))
    }

    // MARK: - Case Insensitivity Tests

    func test_dashboardAgent_canHandle_caseInsensitive() {
        let agent = DashboardAgent()
        let input = AgentInput(message: "SHOW ME REVENUE")
        XCTAssertTrue(agent.canHandle(input: input))
    }

    func test_productsAgent_canHandle_caseInsensitive() {
        let agent = ProductsAgent()
        let input = AgentInput(message: "Show Me All PRODUCTS")
        XCTAssertTrue(agent.canHandle(input: input))
    }

    // MARK: - Edge Cases

    func test_agent_canHandle_whitespaceOnly_returnsFalse() {
        let dashboardAgent = DashboardAgent()
        let productsAgent = ProductsAgent()
        let input = AgentInput(message: "   ")

        XCTAssertFalse(dashboardAgent.canHandle(input: input))
        XCTAssertFalse(productsAgent.canHandle(input: input))
    }
}

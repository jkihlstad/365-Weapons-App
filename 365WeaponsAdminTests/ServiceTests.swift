//
//  ServiceTests.swift
//  365WeaponsAdminTests
//
//  Tests for services - simplified to match actual implementation
//

import XCTest
@testable import _65WeaponsAdmin

final class ServiceTests: XCTestCase {

    // MARK: - LangGraph Service Tests

    func test_langGraphService_singleton_returnsSameInstance() {
        let service1 = LangGraphService.shared
        let service2 = LangGraphService.shared
        XCTAssertTrue(service1 === service2)
    }

    func test_langGraphService_initialState_isNotProcessing() {
        let service = LangGraphService.shared
        XCTAssertFalse(service.isProcessing)
    }

    func test_langGraphService_initialState_currentStateIsNotComplete() {
        let service = LangGraphService.shared
        XCTAssertFalse(service.currentState.isComplete)
    }

    // MARK: - GraphState Tests

    func test_graphState_initialization_hasDefaultValues() {
        let state = GraphState()

        XCTAssertTrue(state.messages.isEmpty)
        XCTAssertNil(state.currentAgent)
        XCTAssertTrue(state.toolCalls.isEmpty)
        XCTAssertNil(state.result)
        XCTAssertNil(state.error)
        XCTAssertFalse(state.isComplete)
    }

    // MARK: - AgentMessage Tests

    func test_agentMessage_creation() {
        let message = AgentMessage(role: "user", content: "Hello")

        XCTAssertEqual(message.role, "user")
        XCTAssertEqual(message.content, "Hello")
        XCTAssertNil(message.agentName)
    }

    func test_agentMessage_withAgentName() {
        let message = AgentMessage(role: "assistant", content: "Response", agentName: "dashboard")

        XCTAssertEqual(message.agentName, "dashboard")
    }

    // MARK: - ToolCallStatus Tests

    func test_toolCallStatus_cases() {
        XCTAssertEqual(ToolCallStatus.pending.rawValue, "pending")
        XCTAssertEqual(ToolCallStatus.running.rawValue, "running")
        XCTAssertEqual(ToolCallStatus.completed.rawValue, "completed")
        XCTAssertEqual(ToolCallStatus.failed.rawValue, "failed")
    }

    // MARK: - LangGraphConfig Tests

    func test_langGraphConfig_defaultValues() {
        XCTAssertFalse(LangGraphConfig.serverEndpoint.isEmpty)
        XCTAssertGreaterThan(LangGraphConfig.defaultTimeout, 0)
    }

    // MARK: - AnyCodable Tests

    func test_anyCodable_withString() {
        let codable = AnyCodable("test")
        XCTAssertEqual(codable.value as? String, "test")
    }

    func test_anyCodable_withInt() {
        let codable = AnyCodable(42)
        XCTAssertEqual(codable.value as? Int, 42)
    }

    func test_anyCodable_withDouble() {
        let codable = AnyCodable(3.14)
        XCTAssertEqual(codable.value as? Double, 3.14)
    }

    func test_anyCodable_withBool() {
        let codable = AnyCodable(true)
        XCTAssertEqual(codable.value as? Bool, true)
    }

    // MARK: - LangGraphError Tests

    func test_langGraphError_types() {
        XCTAssertNotNil(LangGraphError.notConfigured.errorDescription)
        XCTAssertNotNil(LangGraphError.executionFailed("test").errorDescription)
        XCTAssertNotNil(LangGraphError.timeout.errorDescription)
    }

    // MARK: - CacheService Tests

    func test_cacheService_singleton_returnsSameInstance() {
        let service1 = CacheService.shared
        let service2 = CacheService.shared
        XCTAssertTrue(service1 === service2)
    }

    // MARK: - OfflineManager Tests

    func test_offlineManager_singleton_returnsSameInstance() {
        let manager1 = OfflineManager.shared
        let manager2 = OfflineManager.shared
        XCTAssertTrue(manager1 === manager2)
    }

    // MARK: - CacheKeys Tests

    func test_cacheKeys_areNotEmpty() {
        XCTAssertFalse(CacheKeys.dashboardStats.isEmpty)
        XCTAssertFalse(CacheKeys.recentOrders.isEmpty)
        XCTAssertFalse(CacheKeys.allProducts.isEmpty)
    }

    // MARK: - CachedDataType Tests

    func test_cachedDataType_hasDefaultExpiration() {
        XCTAssertGreaterThan(CachedDataType.dashboard.defaultExpiration, 0)
        XCTAssertGreaterThan(CachedDataType.orders.defaultExpiration, 0)
        XCTAssertGreaterThan(CachedDataType.products.defaultExpiration, 0)
    }
}

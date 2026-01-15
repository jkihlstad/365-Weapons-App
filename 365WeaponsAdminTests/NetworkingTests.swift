//
//  NetworkingTests.swift
//  365WeaponsAdminTests
//
//  Tests for networking clients - simplified to match actual implementation
//

import XCTest
@testable import _65WeaponsAdmin

final class NetworkingTests: XCTestCase {

    // MARK: - Convex Client Tests

    func test_convexClient_singleton_returnsSameInstance() {
        let client1 = ConvexClient.shared
        let client2 = ConvexClient.shared
        XCTAssertTrue(client1 === client2)
    }

    func test_convexClient_initialState_isNotConnected() {
        let client = ConvexClient.shared
        XCTAssertFalse(client.isConnected)
    }

    // MARK: - Convex Config Tests

    func test_convexConfig_deploymentURL_isCorrect() {
        XCTAssertEqual(ConvexConfig.deploymentURL, "https://clear-pony-963.convex.cloud")
    }

    func test_convexConfig_httpEndpoint_usesDeploymentURL() {
        XCTAssertEqual(ConvexConfig.httpEndpoint, "https://clear-pony-963.convex.cloud/api")
    }

    // MARK: - Convex Error Tests

    func test_convexError_invalidResponse_hasCorrectDescription() {
        XCTAssertEqual(ConvexError.invalidResponse.errorDescription, "Invalid response from server")
    }

    func test_convexError_noData_hasCorrectDescription() {
        XCTAssertEqual(ConvexError.noData.errorDescription, "No data received")
    }

    func test_convexError_queryError_includesMessage() {
        let error = ConvexError.queryError(message: "Field not found")
        XCTAssertEqual(error.errorDescription, "Query error: Field not found")
    }

    func test_convexError_serverError_includesStatusCodeAndMessage() {
        let error = ConvexError.serverError(statusCode: 500, message: "Internal server error")
        XCTAssertEqual(error.errorDescription, "Server error (500): Internal server error")
    }

    // MARK: - OpenRouter Client Tests

    func test_openRouterClient_singleton_returnsSameInstance() {
        let client1 = OpenRouterClient.shared
        let client2 = OpenRouterClient.shared
        XCTAssertTrue(client1 === client2)
    }

    // MARK: - OpenRouter Error Tests

    func test_openRouterError_notConfigured_hasCorrectDescription() {
        XCTAssertEqual(OpenRouterError.notConfigured.errorDescription, "OpenRouter API key not configured")
    }

    func test_openRouterError_invalidResponse_hasCorrectDescription() {
        XCTAssertEqual(OpenRouterError.invalidResponse.errorDescription, "Invalid response from OpenRouter")
    }

    func test_openRouterError_apiError_includesCodeAndMessage() {
        let error = OpenRouterError.apiError(code: 401, message: "Unauthorized")
        XCTAssertEqual(error.errorDescription, "API Error (401): Unauthorized")
    }

    // MARK: - ChatCompletionMessage Tests

    func test_chatCompletionMessage_creation_setsProperties() {
        let message = ChatCompletionMessage(role: "user", content: "Hello")
        XCTAssertEqual(message.role, "user")
        XCTAssertEqual(message.content, "Hello")
    }

    func test_chatCompletionMessage_equality_sameValues_areEqual() {
        let message1 = ChatCompletionMessage(role: "user", content: "Hello")
        let message2 = ChatCompletionMessage(role: "user", content: "Hello")
        XCTAssertEqual(message1, message2)
    }

    func test_chatCompletionMessage_equality_differentRole_areNotEqual() {
        let message1 = ChatCompletionMessage(role: "user", content: "Hello")
        let message2 = ChatCompletionMessage(role: "assistant", content: "Hello")
        XCTAssertNotEqual(message1, message2)
    }

    func test_chatCompletionMessage_jsonEncoding_encodesCorrectly() throws {
        let message = ChatCompletionMessage(role: "user", content: "Test message")
        let data = try JSONEncoder().encode(message)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: String]
        XCTAssertEqual(json?["role"], "user")
        XCTAssertEqual(json?["content"], "Test message")
    }

    // MARK: - OpenAI Client Tests

    func test_openAIClient_singleton_returnsSameInstance() {
        let client1 = OpenAIClient.shared
        let client2 = OpenAIClient.shared
        XCTAssertTrue(client1 === client2)
    }

    // MARK: - OpenAI Config Tests

    func test_openAIConfig_baseURL_isCorrect() {
        XCTAssertEqual(OpenAIConfig.baseURL, "https://api.openai.com/v1")
    }

    func test_openAIConfig_whisperModel_isCorrect() {
        XCTAssertEqual(OpenAIConfig.whisperModel, "whisper-1")
    }

    func test_openAIConfig_defaultVoice_isAlloy() {
        XCTAssertEqual(OpenAIConfig.defaultVoice, "alloy")
    }

    // MARK: - OpenAI Error Tests

    func test_openAIError_notConfigured_hasCorrectDescription() {
        XCTAssertEqual(OpenAIError.notConfigured.errorDescription, "OpenAI API key not configured")
    }

    func test_openAIError_invalidResponse_hasCorrectDescription() {
        XCTAssertEqual(OpenAIError.invalidResponse.errorDescription, "Invalid response from OpenAI")
    }

    func test_openAIError_recordingFailed_includesMessage() {
        let error = OpenAIError.recordingFailed("Microphone permission denied")
        XCTAssertEqual(error.errorDescription, "Recording failed: Microphone permission denied")
    }

    // MARK: - PostgreSQL Client Tests

    func test_postgreSQLClient_singleton_returnsSameInstance() {
        let client1 = PostgreSQLClient.shared
        let client2 = PostgreSQLClient.shared
        XCTAssertTrue(client1 === client2)
    }

    func test_postgreSQLClient_initialState_isNotConnected() {
        let client = PostgreSQLClient.shared
        XCTAssertFalse(client.isConnected)
    }

    // MARK: - PostgreSQL Error Tests

    func test_postgreSQLError_notConnected_hasCorrectDescription() {
        XCTAssertEqual(PostgreSQLError.notConnected.errorDescription, "Not connected to PostgreSQL")
    }

    func test_postgreSQLError_invalidResponse_hasCorrectDescription() {
        XCTAssertEqual(PostgreSQLError.invalidResponse.errorDescription, "Invalid response from database")
    }

    func test_postgreSQLError_queryError_includesMessage() {
        let error = PostgreSQLError.queryError(message: "Syntax error")
        XCTAssertEqual(error.errorDescription, "Query error: Syntax error")
    }

    // MARK: - LanceDB Client Tests

    func test_lanceDBClient_singleton_returnsSameInstance() {
        let client1 = LanceDBClient.shared
        let client2 = LanceDBClient.shared
        XCTAssertTrue(client1 === client2)
    }

    func test_lanceDBClient_initialState_isNotConnected() {
        let client = LanceDBClient.shared
        XCTAssertFalse(client.isConnected)
    }

    // MARK: - LanceDB Config Tests

    func test_lanceDBConfig_embeddingModel_isCorrect() {
        XCTAssertEqual(LanceDBConfig.embeddingModel, "text-embedding-3-small")
    }

    func test_lanceDBConfig_embeddingDimension_is1536() {
        XCTAssertEqual(LanceDBConfig.embeddingDimension, 1536)
    }

    // MARK: - LanceDB Error Tests

    func test_lanceDBError_notConfigured_hasCorrectDescription() {
        XCTAssertEqual(LanceDBError.notConfigured.errorDescription, "LanceDB not configured")
    }

    func test_lanceDBError_embeddingFailed_includesMessage() {
        let error = LanceDBError.embeddingFailed("API timeout")
        XCTAssertEqual(error.errorDescription, "Embedding generation failed: API timeout")
    }

    // MARK: - Clerk Auth Tests

    @MainActor
    func test_clerkAuthClient_singleton_returnsSameInstance() {
        let client1 = ClerkAuthClient.shared
        let client2 = ClerkAuthClient.shared
        XCTAssertTrue(client1 === client2)
    }

    @MainActor
    func test_clerkAuthClient_shared_exists() {
        // Note: Clerk SDK authentication state depends on external factors
        // (keychain, previous sessions, etc.) so we only test that the singleton exists
        let client = ClerkAuthClient.shared
        XCTAssertNotNil(client)
    }

    // MARK: - AdminConfig Tests

    func test_adminConfig_adminEmails_containsExpectedEmails() {
        XCTAssertTrue(AdminConfig.adminEmails.contains("jkihlstad@gmail.com"))
        XCTAssertTrue(AdminConfig.adminEmails.contains("my365weapons@gmail.com"))
    }

    func test_adminConfig_isAdminEmail_validEmail_returnsTrue() {
        XCTAssertTrue(AdminConfig.isAdminEmail("jkihlstad@gmail.com"))
    }

    func test_adminConfig_isAdminEmail_invalidEmail_returnsFalse() {
        XCTAssertFalse(AdminConfig.isAdminEmail("random@example.com"))
    }

    // MARK: - Auth Error Tests

    func test_authError_notAdmin_hasCorrectDescription() {
        XCTAssertTrue(AuthError.notAdmin.errorDescription?.contains("admin") ?? false)
    }

    func test_authError_sessionExpired_hasCorrectDescription() {
        XCTAssertTrue(AuthError.sessionExpired.errorDescription?.contains("expired") ?? false)
    }

    // MARK: - JSON Parsing Tests

    func test_convexQueryResult_parsing_validJSON() throws {
        let json = """
        {
            "value": [
                {
                    "_id": "prod1",
                    "title": "Product 1",
                    "price": 99.99,
                    "category": "Services",
                    "image": "/img1.jpg",
                    "inStock": true,
                    "createdAt": 1704067200000
                }
            ],
            "errorMessage": null
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        let result = try decoder.decode(ConvexQueryResult<[Product]>.self, from: data)

        XCTAssertEqual(result.value?.count, 1)
        XCTAssertEqual(result.value?.first?.title, "Product 1")
    }

    func test_convexQueryResult_parsing_errorResponse() throws {
        let json = """
        {
            "value": null,
            "errorMessage": "Function not found"
        }
        """

        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(ConvexQueryResult<[Product]>.self, from: data)

        XCTAssertNil(result.value)
        XCTAssertEqual(result.errorMessage, "Function not found")
    }

    func test_convexQueryResult_parsing_emptyArray() throws {
        let json = """
        {
            "value": [],
            "errorMessage": null
        }
        """

        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(ConvexQueryResult<[Product]>.self, from: data)

        XCTAssertNotNil(result.value)
        XCTAssertTrue(result.value!.isEmpty)
    }
}

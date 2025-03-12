import XCTest
import OpenAI
@testable import swift_ai_localize

// A very simple mock for testing
class SimpleMockOpenAI: ChatCompletionProtocol, @unchecked Sendable {
    var responses: [String: String] = [:]
    var responseFormat: ResponseFormat = .plain
    
    enum ResponseFormat {
        case plain
        case withBoundaries
        case withTranslationPrefix
    }
    
    func chats(query: ChatQuery) async throws -> ChatResult {
        let content = String(describing: query.messages.last?.content)
        
        // Determine which key to use based on the content
        let key: String
        if content.contains("Hello") {
            key = "Hello"
        } else if content.contains("Multiple  spaces") {
            key = "  Multiple  spaces  "
        } else if content.contains("%@") {
            key = "%@ items remaining"
        } else {
            key = "unknown"
        }
        
        var response = responses[key] ?? "MOCK_\(key)"
        
        // Format the response based on the specified format
        switch responseFormat {
        case .plain:
            // Leave as is
            break
        case .withBoundaries:
            response = "❮\(response)❯"
        case .withTranslationPrefix:
            response = "Translation: \(response)"
        }
        
        // Ensure the response is properly escaped for JSON
        let escapedResponse = response.replacingOccurrences(of: "\"", with: "\\\"")
                                     .replacingOccurrences(of: "\n", with: "\\n")
        
        let jsonString = """
        {
            "id": "mock-chat-\(UUID().uuidString)",
            "object": "chat.completion",
            "created": \(Int(Date().timeIntervalSince1970)),
            "model": "mock-model",
            "choices": [
                {
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": "\(escapedResponse)"
                    },
                    "finish_reason": "stop"
                }
            ]
        }
        """
        
        return try JSONDecoder().decode(ChatResult.self, from: jsonString.data(using: .utf8)!)
    }
}

final class TranslationServiceTests: XCTestCase {
    var mockOpenAI: SimpleMockOpenAI!
    var translationService: TranslationService!
    
    override func setUp() {
        mockOpenAI = SimpleMockOpenAI()
        mockOpenAI.responses = [
            "Hello": "MOCK_Hello",
            "  Multiple  spaces  ": "  Múltiples  espacios  ",
            "%@ items remaining": "%@ elementos restantes"
        ]
        translationService = TranslationService(openAI: mockOpenAI, model: "gpt-4o", apiKey: "mock-token")
    }
    
    override func tearDown() {
        mockOpenAI = nil
        translationService = nil
    }
    
    func testBasicTranslation() async throws {
        let translatedText = try await translationService.translate(
            text: "Hello",
            from: "en",
            to: "es"
        )
        
        XCTAssertEqual(translatedText, "MOCK_Hello")
    }
    
    func testWhitespacePreservation() async throws {
        // Make sure we're using the plain response format
        mockOpenAI.responseFormat = .plain
        
        // Verify the mock response has the correct whitespace
        XCTAssertEqual(mockOpenAI.responses["  Multiple  spaces  "], "  Múltiples  espacios  ")
        
        let translatedText = try await translationService.translate(
            text: "  Multiple  spaces  ",
            from: "en",
            to: "es"
        )
        
        // The whitespace should be preserved exactly
        XCTAssertEqual(translatedText, "  Múltiples  espacios  ")
    }
    
    func testFormatSpecifierPreservation() async throws {
        let translatedText = try await translationService.translate(
            text: "%@ items remaining",
            from: "en",
            to: "es"
        )
        
        XCTAssertEqual(translatedText, "%@ elementos restantes")
    }
    
    // New tests for text boundary handling
    
    func testTranslationWithBoundaryMarkers() async throws {
        // Set the mock to return responses with boundary markers
        mockOpenAI.responseFormat = .withBoundaries
        
        let translatedText = try await translationService.translate(
            text: "Hello",
            from: "en",
            to: "es"
        )
        
        // The boundary markers should be removed
        XCTAssertEqual(translatedText, "MOCK_Hello")
    }
    
    func testTranslationWithTranslationPrefix() async throws {
        // Set the mock to return responses with a "Translation:" prefix
        mockOpenAI.responseFormat = .withTranslationPrefix
        
        let translatedText = try await translationService.translate(
            text: "Hello",
            from: "en",
            to: "es"
        )
        
        // The prefix should be removed
        XCTAssertEqual(translatedText, "MOCK_Hello")
    }
    
    func testWhitespacePreservationWithBoundaries() async throws {
        // Set the mock to return responses with boundary markers
        mockOpenAI.responseFormat = .withBoundaries
        
        let translatedText = try await translationService.translate(
            text: "  Multiple  spaces  ",
            from: "en",
            to: "es"
        )
        
        // The boundary markers should be removed but whitespace preserved
        XCTAssertEqual(translatedText, "  Múltiples  espacios  ")
    }
} 
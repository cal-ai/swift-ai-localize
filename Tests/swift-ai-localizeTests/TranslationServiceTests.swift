import XCTest
import OpenAI
@testable import swift_ai_localize

// A very simple mock for testing
class SimpleMockOpenAI: ChatCompletionProtocol, @unchecked Sendable {
    var responses: [String: String] = [:]
    
    func chats(query: ChatQuery) async throws -> ChatResult {
        let content = String(describing: query.messages.last?.content)
        let key = content.contains("Hello") ? "Hello" : 
                 content.contains("Multiple  spaces") ? "  Multiple  spaces  " : 
                 content.contains("%@") ? "%@ items remaining" : "unknown"
        
        let response = responses[key] ?? "MOCK_\(key)"
        
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
                        "content": "\(response)"
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
        let translatedText = try await translationService.translate(
            text: "  Multiple  spaces  ",
            from: "en",
            to: "es"
        )
        
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
} 
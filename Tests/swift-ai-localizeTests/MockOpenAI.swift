import Foundation
@preconcurrency import OpenAI
@testable import swift_ai_localize

extension ChatQuery: @unchecked Sendable {}
extension ChatResult: @unchecked Sendable {}

final class MockOpenAI: ChatCompletionProtocol, @unchecked Sendable {
    var delayMilliseconds: UInt64 = 0
    var shouldFailRandomly = false
    var failureRate = 0.0
    var mockResponses: [String: String] = [:]
    private var requestLog: [(text: String, timestamp: Date)] = []
    
    var requestHistory: [(text: String, timestamp: Date)] {
        return requestLog
    }
    
    func chats(query: ChatQuery) async throws -> ChatResult {
        // Log the request
        let content = String(describing: query.messages.last?.content)
        requestLog.append((
            text: content,
            timestamp: Date()
        ))
        
        // Simulate network delay
        if delayMilliseconds > 0 {
            try await Task.sleep(nanoseconds: delayMilliseconds * 1_000_000)
        }
        
        // Simulate random failures
        if shouldFailRandomly && Double.random(in: 0...1) < failureRate {
            throw NSError(domain: "MockOpenAI", code: 500, userInfo: [NSLocalizedDescriptionKey: "Random failure"])
        }
        
        // Extract text between markers
        let text = extractTextBetweenMarkers(from: content)
        
        // Generate mock translation
        let translatedText = generateMockTranslation(for: text)
        
        // Create JSON response
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
                        "content": "\(translatedText)"
                    },
                    "finish_reason": "stop"
                }
            ]
        }
        """
        
        guard let jsonData = jsonString.data(using: String.Encoding.utf8) else {
            throw NSError(domain: "MockOpenAI", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to encode response"])
        }
        
        return try JSONDecoder().decode(ChatResult.self, from: jsonData)
    }
    
    private func extractTextBetweenMarkers(from text: String) -> String {
        let pattern = "❮(.+?)❯"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            // If no markers found, try to extract the text directly
            if let content = text.components(separatedBy: "Text to translate").last {
                return content.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return text
        }
        return String(text[range])
    }
    
    private func generateMockTranslation(for text: String) -> String {
        // Check if we have a predefined mock response
        if let mockResponse = mockResponses[text] {
            return mockResponse
        }
        
        // Split the text into words while preserving format specifiers and whitespace
        let pattern = "(%(?:@|d|f|[0-9]+\\$[@df])|\\s+|[^\\s%]+)"
        let regex = try! NSRegularExpression(pattern: pattern)
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        
        var result = ""
        for match in matches {
            if let range = Range(match.range, in: text) {
                let part = String(text[range])
                if part.hasPrefix("%") {
                    // Preserve format specifiers
                    result += part
                } else if part.trimmingCharacters(in: .whitespaces).isEmpty {
                    // Preserve whitespace
                    result += part
                } else {
                    // Mock translate words
                    result += "MOCK_" + part
                }
            }
        }
        
        return result
    }
    
    func clearRequestLog() {
        requestLog.removeAll()
    }
} 
import Foundation
@preconcurrency import OpenAI

protocol ChatCompletionProtocol: Sendable {
    func chats(query: ChatQuery) async throws -> ChatResult
}

extension OpenAI: @unchecked Sendable {}
extension OpenAI: ChatCompletionProtocol {}

final class TranslationService: @unchecked Sendable {
    private let openAI: ChatCompletionProtocol
    private let modelName: String
    private let apiToken: String
    
    init(apiKey: String, model: String = "gpt-4o") {
        self.openAI = OpenAI(apiToken: apiKey)
        self.modelName = model
        self.apiToken = apiKey
    }
    
    init(openAI: ChatCompletionProtocol, model: String = "gpt-4o", apiKey: String) {
        self.openAI = openAI
        self.modelName = model
        self.apiToken = apiKey
    }
    
    func translate(text: String, from sourceLanguage: String, to targetLanguage: String, context: String? = nil) async throws -> String {
        let prompt = buildTranslationPrompt(text: text, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage, context: context)
        
        let systemMessage = ChatQuery.ChatCompletionMessageParam(role: .system, content: "You are a professional translator with expertise in localization.")!
        let userMessage = ChatQuery.ChatCompletionMessageParam(role: .user, content: prompt)!
        
        let query = ChatQuery(
            messages: [systemMessage, userMessage],
            model: modelName,
            temperature: 0.7
        )
        
        let response = try await openAI.chats(query: query)
        
        guard let translatedContent = response.choices.first?.message.content else {
            throw TranslationError.noResponseContent
        }
        
        // Convert the content to a string and clean it
        let translatedText = String(describing: translatedContent)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        // Clean the translated text
        let cleanedText = cleanTranslatedText(translatedText)
        return cleanedText
    }
    
    private func cleanTranslatedText(_ text: String) -> String {
        var cleanedText = text
        
        // Check if the text is wrapped in string("...") format
        let stringPattern = #"^string\("(.+)"\)$"#
        
        if let regex = try? NSRegularExpression(pattern: stringPattern, options: []) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range) {
                if let matchRange = Range(match.range(at: 1), in: text) {
                    // Extract the content inside string("...")
                    cleanedText = String(text[matchRange])
                }
            }
        }
        
        // Handle escaped apostrophes
        cleanedText = cleanedText.replacingOccurrences(of: #"\'"#, with: "'")
        
        // Handle escaped quotes
        cleanedText = cleanedText.replacingOccurrences(of: #"\""#, with: "\"")
        
        // Remove surrounding quotes if they exist
        if cleanedText.hasPrefix("\"") && cleanedText.hasSuffix("\"") {
            let startIndex = cleanedText.index(after: cleanedText.startIndex)
            let endIndex = cleanedText.index(before: cleanedText.endIndex)
            cleanedText = String(cleanedText[startIndex..<endIndex])
        }
        
        return cleanedText
    }
    
    private func buildTranslationPrompt(text: String, sourceLanguage: String, targetLanguage: String, context: String?) -> String {
        var prompt = """
        Translate the following text from \(sourceLanguage) to \(targetLanguage).
        
        IMPORTANT RULES:
        1. Preserve ALL whitespace exactly as in the original text, including:
           - Leading spaces
           - Trailing spaces
           - Multiple consecutive spaces
           - Newlines
        2. Keep ALL format specifiers exactly as they appear (e.g. %@, %lld, %1$@, etc.)
        3. Do not add or remove any whitespace
        4. Provide ONLY the translated text, no quotes or explanations
        
        Text to translate (❮ and ❯ show text boundaries):
        ❮\(text)❯
        """
        
        if let context = context, !context.isEmpty {
            prompt += "\n\nContext or notes for translation: \(context)"
        }
        
        return prompt
    }
    
    func batchTranslate(tasks: [TranslationTask], sourceLanguage: String, batchSize: Int = 50) async throws -> [String: String] {
        var results = [String: String]()
        let batches = stride(from: 0, to: tasks.count, by: batchSize).map {
            Array(tasks[($0)..<min($0 + batchSize, tasks.count)])
        }
        
        // Create a nonisolated copy of self
        let openAI = self.openAI
        let modelName = self.modelName
        let apiToken = self.apiToken
        
        for batch in batches {
            try await withThrowingTaskGroup(of: (String, String).self) { group in
                for task in batch {
                    let taskCopy = task
                    let sourceLangCopy = sourceLanguage
                    
                    group.addTask {
                        // Create a new instance for each task to avoid data races
                        let service = TranslationService(openAI: openAI, model: modelName, apiKey: apiToken)
                        let translatedText = try await service.translate(
                            text: taskCopy.sourceText,
                            from: sourceLangCopy,
                            to: taskCopy.targetLanguage,
                            context: taskCopy.comment
                        )
                        return (taskCopy.key, translatedText)
                    }
                }
                
                // Collect results from the task group
                for try await (key, translation) in group {
                    results[key] = translation
                }
                
                // Add a small delay between batches to avoid rate limiting
                if batch != batches.last {
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second between batches
                }
            }
        }
        
        return results
    }
}

enum TranslationError: Error {
    case noResponseContent
    case apiError(String)
} 
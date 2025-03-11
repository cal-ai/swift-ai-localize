import XCTest
@testable import swift_ai_localize

final class IntegrationTests: XCTestCase {
    var tempFileURL: URL!
    var mockOpenAI: MockOpenAI!
    var translationService: TranslationService!
    var localizationService: LocalizationService!
    
    override func setUp() async throws {
        // Create a temporary file with test data
        let tempDir = FileManager.default.temporaryDirectory
        tempFileURL = tempDir.appendingPathComponent("integration_test.xcstrings")
        
        let testData = createTestLocalizationData()
        try testData.write(to: tempFileURL, atomically: true, encoding: .utf8)
        
        // Set up services
        mockOpenAI = MockOpenAI()
        mockOpenAI.mockResponses = [
            "Simple text": "MOCK_Simple",
            "%@ items remaining": "%@ elementos restantes",
            "  Multiple  spaces  ": "  Múltiples  espacios  "
        ]
        translationService = TranslationService(openAI: mockOpenAI, model: "gpt-4o", apiKey: "mock-token")
        localizationService = try LocalizationService(filePath: tempFileURL.path)
    }
    
    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempFileURL)
        mockOpenAI = nil
        translationService = nil
        localizationService = nil
        try await super.tearDown()
    }
    
    private func createTestLocalizationData() -> String {
        return """
        {
            "version": "1.0",
            "sourceLanguage": "en",
            "strings": {
                "Simple": {
                    "localizations": {
                        "en": {
                            "stringUnit": {
                                "state": "translated",
                                "value": "Simple text"
                            }
                        }
                    }
                },
                "Format": {
                    "localizations": {
                        "en": {
                            "stringUnit": {
                                "state": "translated",
                                "value": "%@ items remaining"
                            }
                        }
                    }
                },
                "Whitespace": {
                    "localizations": {
                        "en": {
                            "stringUnit": {
                                "state": "translated",
                                "value": "  Multiple  spaces  "
                            }
                        }
                    }
                },
                "Empty": {}
            }
        }
        """
    }
    
    func testBasicFunctionality() async throws {
        // 1. Test language detection
        let sourceLanguage = localizationService.getSourceLanguage()
        XCTAssertEqual(sourceLanguage, "en")
        
        // 2. Find strings needing translation
        let targetLanguage = "es"
        let tasks = localizationService.findStringsNeedingTranslation(targetLanguages: [targetLanguage])
        
        // Should find 4 strings × 1 language = 4 tasks
        XCTAssertEqual(tasks.count, 4)
        
        // 3. Translate a single string
        let task = tasks.first!
        let translatedText = try await translationService.translate(
            text: task.sourceText,
            from: sourceLanguage,
            to: task.targetLanguage
        )
        
        // 4. Update the file with a single translation
        let translations = [task.key: [task.targetLanguage: translatedText]]
        try localizationService.updateTranslations(translations: translations)
        
        // 5. Verify the translation was applied
        let updatedTasks = localizationService.findStringsNeedingTranslation(targetLanguages: [targetLanguage])
        XCTAssertEqual(updatedTasks.count, tasks.count - 1)
        
        // 6. Verify file structure integrity
        XCTAssertNoThrow(try JSONDecoder().decode(LocalizableStrings.self, from: Data(contentsOf: tempFileURL)))
    }
} 
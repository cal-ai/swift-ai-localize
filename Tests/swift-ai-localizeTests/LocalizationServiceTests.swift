import XCTest
@testable import swift_ai_localize

@available(macOS 13.0, *)
final class LocalizationServiceTests: XCTestCase {
    var tempFileURL: URL!
    var localizationService: LocalizationService!
    
    override func setUp() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        tempFileURL = tempDir.appendingPathComponent("test.xcstrings")
        
        let testData = createTestLocalizationData()
        try testData.write(to: tempFileURL, atomically: true, encoding: .utf8)
        
        localizationService = try LocalizationService(filePath: tempFileURL.path)
    }
    
    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempFileURL)
        localizationService = nil
        try await super.tearDown()
    }
    
    private func createTestLocalizationData() -> String {
        return """
        {
            "version": "1.0",
            "sourceLanguage": "en",
            "strings": {
                "Hello": {
                    "comment": "Greeting",
                    "localizations": {
                        "en": {
                            "stringUnit": {
                                "state": "translated",
                                "value": "Hello"
                            }
                        },
                        "es": {
                            "stringUnit": {
                                "state": "needs_review",
                                "value": "Hola"
                            }
                        },
                        "fr": {
                            "stringUnit": {
                                "state": "translated",
                                "value": "Bonjour"
                            }
                        }
                    }
                },
                "Goodbye": {
                    "localizations": {
                        "en": {
                            "stringUnit": {
                                "state": "translated",
                                "value": "Goodbye"
                            }
                        }
                    }
                },
                "Empty": {
                    "localizations": {}
                },
                "NoLocalizations": {}
            }
        }
        """
    }
    
    func testLanguageDetection() async throws {
        // Test source language detection
        let sourceLanguage = localizationService.getSourceLanguage()
        XCTAssertEqual(sourceLanguage, "en")
        
        // Test target languages detection
        let targetLanguages = localizationService.getTargetLanguages()
        XCTAssertEqual(Set(targetLanguages), Set(["es", "fr"]))
    }
    
    func testFindStringsNeedingTranslation() async throws {
        // Test with specific languages
        let tasks = localizationService.findStringsNeedingTranslation(targetLanguages: ["es", "fr"])
        
        // Should find:
        // 1. "Goodbye" needs both es and fr translations
        // 2. "Empty" needs both es and fr translations
        // 3. "NoLocalizations" needs both es and fr translations
        // 4. "Hello" needs es translation (needs_review state)
        let expectedCount = 7 // (2 languages × 3 missing entries) + 1 needs_review
        XCTAssertEqual(tasks.count, expectedCount)
        
        // Verify specific cases
        let tasksByKey = Dictionary(grouping: tasks, by: { $0.key })
        
        // Check "Hello" tasks
        XCTAssertEqual(tasksByKey["Hello"]?.count, 1)
        XCTAssertEqual(tasksByKey["Hello"]?.first?.targetLanguage, "es")
        
        // Check "Goodbye" tasks
        XCTAssertEqual(tasksByKey["Goodbye"]?.count, 2)
        XCTAssertTrue(tasksByKey["Goodbye"]?.contains(where: { $0.targetLanguage == "es" }) ?? false)
        XCTAssertTrue(tasksByKey["Goodbye"]?.contains(where: { $0.targetLanguage == "fr" }) ?? false)
    }
    
    func testUpdateTranslations() async throws {
        // Prepare test translations
        let translations = [
            "Hello": ["es": "Hola updated"],
            "Goodbye": ["es": "Adiós", "fr": "Au revoir"],
            "Empty": ["es": "Vacío", "fr": "Vide"],
            "NoLocalizations": ["es": "Sin localizaciones", "fr": "Sans localisations"]
        ]
        
        // Update translations
        try localizationService.updateTranslations(translations: translations)
        
        // Verify the file was updated correctly
        let updatedService = try LocalizationService(filePath: tempFileURL.path)
        let tasks = updatedService.findStringsNeedingTranslation(targetLanguages: ["es", "fr"])
        
        // All strings should be translated now
        XCTAssertEqual(tasks.count, 0)
        
        // Verify file structure is intact
        XCTAssertNoThrow(try JSONDecoder().decode(LocalizableStrings.self, from: Data(contentsOf: tempFileURL)))
    }
    
    func testConcurrentUpdates() async throws {
        let updates = [
            ["Hello": ["es": "Hola1"]],
            ["Hello": ["es": "Hola2"]],
            ["Hello": ["es": "Hola3"]]
        ]
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for update in updates {
                let localService = try LocalizationService(filePath: tempFileURL.path)
                group.addTask {
                    try localService.updateTranslations(translations: update)
                }
            }
            try await group.waitForAll()
        }
        
        // Verify that one of the updates was applied
        let tasks = localizationService.findStringsNeedingTranslation(targetLanguages: ["es"])
        XCTAssertEqual(tasks.count, 4) // All strings except "Hello" should need translation
    }
} 
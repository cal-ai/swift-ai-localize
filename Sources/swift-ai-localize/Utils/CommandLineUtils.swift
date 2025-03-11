import Foundation
import ArgumentParser
import OpenAI

struct LocalizationTool: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "localize",
        abstract: "A tool for managing localization files",
        subcommands: [TranslateCommand.self, InfoCommand.self]
    )
}

struct TranslateCommand: ParsableCommand, Decodable {
    static let configuration = CommandConfiguration(
        commandName: "translate",
        abstract: "Translate an xcstrings file to specified languages"
    )
    
    @Argument(help: "Path to the xcstrings file")
    var filePath: String
    
    @Option(name: .shortAndLong, help: "Target languages (comma-separated)")
    var languages: String?
    
    @Option(name: .shortAndLong, help: "OpenAI API key")
    var apiKey: String?
    
    @Option(name: .shortAndLong, help: "OpenAI model to use")
    var model: String = "gpt-4"
    
    @Option(name: .shortAndLong, help: "Batch size for parallel processing")
    var batchSize: Int = 5
    
    @Flag(name: .shortAndLong, help: "Enable verbose output")
    var verbose: Bool = false
    
    mutating func run() async throws {
        // Get API key from environment if not provided
        let apiKey = self.apiKey ?? ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
        guard let apiKey = apiKey else {
            throw ValidationError("OpenAI API key must be provided via --api-key or OPENAI_API_KEY environment variable")
        }
        
        // Validate file exists
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw ValidationError("File not found: \(filePath)")
        }
        
        do {
            let localizationService = try LocalizationService(filePath: filePath)
            
            let sourceLanguage = localizationService.getSourceLanguage()
            print("Source language: \(sourceLanguage)")
            
            let availableLanguages = localizationService.getTargetLanguages()
            print("Available target languages: \(availableLanguages.joined(separator: ", "))")
            
            // Get target languages from argument or use all available languages
            let languages = self.languages?.split(separator: ",").map(String.init)
                ?? availableLanguages
            
            print("Selected target languages: \(languages.joined(separator: ", "))")
            
            let tasks = localizationService.findStringsNeedingTranslation(targetLanguages: languages)
            print("Found \(tasks.count) strings needing translation")
            
            if tasks.isEmpty {
                print("No strings need translation")
                return
            }
            
            // Group tasks by target language for parallel processing
            let tasksByLanguage = Dictionary(grouping: tasks) { $0.targetLanguage }
            var allTranslations = [String: [String: String]]()
            
            // Process translations by language
            try await withThrowingTaskGroup(of: (String, [String: String]).self) { group in
                for (language, languageTasks) in tasksByLanguage {
                    let isVerbose = verbose
                    let batchSizeValue = batchSize
                    let taskService = TranslationService(apiKey: apiKey, model: model)
                    
                    group.addTask {
                        if isVerbose {
                            print("Starting translation for \(language)...")
                        }
                        
                        let translations = try await taskService.batchTranslate(
                            tasks: languageTasks,
                            sourceLanguage: sourceLanguage,
                            batchSize: batchSizeValue
                        )
                        
                        if isVerbose {
                            print("Completed \(translations.count) translations for \(language)")
                        }
                        
                        return (language, translations)
                    }
                }
                
                for try await (language, translations) in group {
                    for (key, translation) in translations {
                        if allTranslations[key] == nil {
                            allTranslations[key] = [:]
                        }
                        allTranslations[key]?[language] = translation
                    }
                }
            }
            
            // Update the localization file
            try localizationService.updateTranslations(translations: allTranslations)
            print("Successfully updated \(filePath) with \(tasks.count) translations")
        } catch {
            print("Error: \(error)")
            throw error
        }
    }
}

struct InfoCommand: ParsableCommand, Decodable {
    static let configuration = CommandConfiguration(
        commandName: "info",
        abstract: "Show information about an xcstrings file"
    )
    
    @Argument(help: "Path to the xcstrings file")
    var file: String
    
    mutating func run() async throws {
        do {
            let localizationService = try LocalizationService(filePath: file)
            let sourceLanguage = localizationService.getSourceLanguage()
            let targetLanguages = localizationService.getTargetLanguages()
            
            print("Source language: \(sourceLanguage)")
            print("Target languages: \(targetLanguages.joined(separator: ", "))")
            
            let allLanguages = [sourceLanguage] + targetLanguages
            var totalStrings = 0
            var translatedStrings = [String: Int]()
            
            for language in allLanguages {
                let tasks = localizationService.findStringsNeedingTranslation(targetLanguages: [language])
                let translated = tasks.isEmpty ? 1 : 0
                translatedStrings[language] = translated
                totalStrings = max(totalStrings, 1)
            }
            
            print("\nTranslation status:")
            for language in allLanguages {
                let translated = translatedStrings[language] ?? 0
                let percentage = Double(translated) / Double(totalStrings) * 100
                print("\(language): \(translated)/\(totalStrings) (\(Int(percentage))%)")
            }
        } catch {
            print("Error: \(error)")
            throw error
        }
    }
} 
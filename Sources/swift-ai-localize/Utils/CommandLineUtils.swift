import Foundation
import ArgumentParser
import OpenAI

struct LocalizationTool: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swift-ai-localize",
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
    var model: String = "gpt-4o"
    
    @Option(name: .shortAndLong, help: "Batch size for parallel processing")
    var batchSize: Int = 5
    
    @Flag(name: .shortAndLong, help: "Enable verbose output")
    var verbose: Bool = false
    
    mutating func run() throws {
        // Get API key from environment if not provided
        let apiKey = self.apiKey ?? ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
        guard let apiKey = apiKey else {
            throw ValidationError("OpenAI API key must be provided via --api-key or OPENAI_API_KEY environment variable")
        }
        
        // Validate file exists
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw ValidationError("File not found: \(filePath)")
        }
        
        // Capture values before creating the Task to avoid capturing mutating self
        let filePathCopy = filePath
        let languagesCopy = languages
        let modelCopy = model
        let batchSizeCopy = batchSize
        let verboseCopy = verbose
        
        // Create a task group to handle the async work
        let semaphore = DispatchSemaphore(value: 0)
        var asyncError: Error?
        let errorQueue = DispatchQueue(label: "com.swift-ai-localize.error-queue")
        
        Task {
            do {
                let localizationService = try LocalizationService(filePath: filePathCopy)
                
                let sourceLanguage = localizationService.getSourceLanguage()
                print("Source language: \(sourceLanguage)")
                
                let availableLanguages = localizationService.getTargetLanguages()
                print("Available target languages: \(availableLanguages.joined(separator: ", "))")
                
                // Get target languages from argument or use all available languages
                let languages = languagesCopy?.split(separator: ",").map(String.init)
                    ?? availableLanguages
                
                print("Selected target languages: \(languages.joined(separator: ", "))")
                
                let tasks = localizationService.findStringsNeedingTranslation(targetLanguages: languages)
                print("Found \(tasks.count) strings needing translation")
                
                if tasks.isEmpty {
                    print("No strings need translation")
                    semaphore.signal()
                    return
                }
                
                // Group tasks by target language for parallel processing
                let tasksByLanguage = Dictionary(grouping: tasks) { $0.targetLanguage }
                var allTranslations = [String: [String: String]]()
                
                // Process translations by language
                try await withThrowingTaskGroup(of: (String, [String: String]).self) { group in
                    for (language, languageTasks) in tasksByLanguage {
                        let isVerbose = verboseCopy
                        let batchSizeValue = batchSizeCopy
                        let taskService = TranslationService(apiKey: apiKey, model: modelCopy)
                        
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
                print("Successfully updated \(filePathCopy) with \(tasks.count) translations")
                
            } catch {
                errorQueue.sync {
                    asyncError = error
                }
                print("Error: \(error)")
            }
            
            semaphore.signal()
        }
        
        // Wait for the async task to complete
        semaphore.wait()
        
        // If there was an error in the async task, throw it
        if let error = asyncError {
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
    
    mutating func run() throws {
        print("Analyzing file: \(file)")
        
        do {
            let localizationService = try LocalizationService(filePath: file)
            let sourceLanguage = localizationService.getSourceLanguage()
            let targetLanguages = localizationService.getTargetLanguages()
            
            print("Source language: \(sourceLanguage)")
            print("Target languages: \(targetLanguages.joined(separator: ", "))")
            
            // Count total strings in the file
            let allStrings = localizationService.getAllStrings()
            print("Total strings in file: \(allStrings.count)")
            
            // Count strings needing translation for each language
            for language in targetLanguages {
                let tasks = localizationService.findStringsNeedingTranslation(targetLanguages: [language])
                let needsTranslation = tasks.count
                let translated = allStrings.count - needsTranslation
                let percentage = Double(translated) / Double(allStrings.count) * 100
                
                print("\(language): \(translated)/\(allStrings.count) strings translated (\(Int(percentage))%)")
            }
        } catch {
            print("Error analyzing file: \(error)")
            throw error
        }
    }
} 
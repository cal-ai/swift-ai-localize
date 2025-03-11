import Foundation

class LocalizationService {
    private let fileURL: URL
    private var localizableStrings: LocalizableStrings
    
    init(filePath: String) throws {
        self.fileURL = URL(fileURLWithPath: filePath)
        
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        self.localizableStrings = try decoder.decode(LocalizableStrings.self, from: data)
    }
    
    func getSourceLanguage() -> String {
        return localizableStrings.sourceLanguage
    }
    
    func getTargetLanguages() -> [String] {
        var languages = Set<String>()
        
        for (_, entry) in localizableStrings.strings {
            // Skip entries without localizations
            guard let localizations = entry.localizations else {
                continue
            }
            
            for language in localizations.keys {
                if language != localizableStrings.sourceLanguage {
                    languages.insert(language)
                }
            }
        }
        
        return Array(languages).sorted()
    }
    
    func findStringsNeedingTranslation(targetLanguages: [String]? = nil) -> [TranslationTask] {
        var tasks = [TranslationTask]()
        let languages = targetLanguages ?? getTargetLanguages()
        
        for (key, entry) in localizableStrings.strings {
            // Handle empty entries (no localizations)
            if entry.localizations == nil || entry.localizations?.isEmpty == true {
                // Create tasks for all target languages
                for language in languages {
                    tasks.append(TranslationTask(
                        key: key,
                        sourceText: key, // Use the key itself as the source text
                        targetLanguage: language,
                        comment: entry.comment
                    ))
                }
                continue
            }
            
            // Get the source text
            guard let localizations = entry.localizations,
                  let sourceLocalization = localizations[localizableStrings.sourceLanguage],
                  let sourceText = sourceLocalization.stringUnit.value as String? else {
                // If there's no source language localization but there are other localizations,
                // use the key itself as the source text
                if let localizations = entry.localizations, !localizations.isEmpty {
                    for language in languages {
                        if language == localizableStrings.sourceLanguage {
                            continue
                        }
                        
                        if shouldTranslate(key: key, language: language) {
                            tasks.append(TranslationTask(
                                key: key,
                                sourceText: key, // Use the key itself as the source text
                                targetLanguage: language,
                                comment: entry.comment
                            ))
                        }
                    }
                }
                continue
            }
            
            for language in languages {
                if language == localizableStrings.sourceLanguage {
                    continue
                }
                
                let needsTranslation = shouldTranslate(key: key, language: language)
                
                if needsTranslation {
                    tasks.append(TranslationTask(
                        key: key,
                        sourceText: sourceText,
                        targetLanguage: language,
                        comment: entry.comment
                    ))
                }
            }
        }
        
        return tasks
    }
    
    private func shouldTranslate(key: String, language: String) -> Bool {
        guard let entry = localizableStrings.strings[key] else {
            return false
        }
        
        // If there are no localizations, it needs translation
        if entry.localizations == nil || entry.localizations?.isEmpty == true {
            return true
        }
        
        guard let localizations = entry.localizations else {
            return false
        }
        
        // Check if the language localization exists
        guard let localization = localizations[language] else {
            return true // Missing localization
        }
        
        // Check if the string unit exists and has a value
        guard let state = localization.stringUnit.state else {
            return true // No state, needs translation
        }
        
        // Check the state
        return state == TranslationState.needsReview.rawValue || state == TranslationState.new.rawValue
    }
    
    func updateTranslations(translations: [String: [String: String]]) throws {
        for (key, languageTranslations) in translations {
            guard var entry = localizableStrings.strings[key] else {
                continue
            }
            
            // Initialize localizations if it's nil
            if entry.localizations == nil {
                entry.localizations = [:]
            }
            
            for (language, translation) in languageTranslations {
                if entry.localizations?[language] == nil {
                    // Create new localization
                    entry.localizations?[language] = Localization(
                        stringUnit: StringUnit(state: TranslationState.translated.rawValue, value: translation),
                        variations: nil,
                        extractionState: nil
                    )
                } else {
                    // Update existing localization
                    entry.localizations?[language]?.stringUnit.value = translation
                    entry.localizations?[language]?.stringUnit.state = TranslationState.translated.rawValue
                }
            }
            
            localizableStrings.strings[key] = entry
        }
        
        // Save the updated file
        try saveToFile()
    }
    
    private func saveToFile() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(localizableStrings)
        try data.write(to: fileURL)
    }
} 
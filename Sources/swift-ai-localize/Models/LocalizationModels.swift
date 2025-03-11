import Foundation

// Models representing the structure of Localizable.xcstrings files

struct LocalizableStrings: Codable {
    var sourceLanguage: String
    var strings: [String: StringEntry]
    var version: String
}

struct StringEntry: Codable {
    var comment: String?
    var extractionState: String?
    var localizations: [String: Localization]?
    
    // Custom decoding to handle empty entries
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        comment = try container.decodeIfPresent(String.self, forKey: .comment)
        extractionState = try container.decodeIfPresent(String.self, forKey: .extractionState)
        localizations = try container.decodeIfPresent([String: Localization].self, forKey: .localizations)
    }
    
    enum CodingKeys: String, CodingKey {
        case comment
        case extractionState
        case localizations
    }
}

struct Localization: Codable {
    var stringUnit: StringUnit
    var variations: [String: StringUnit]?
    var extractionState: String?
    
    enum CodingKeys: String, CodingKey {
        case stringUnit
        case variations
        case extractionState
    }
}

struct StringUnit: Codable {
    var state: String?
    var value: String
    
    enum CodingKeys: String, CodingKey {
        case state
        case value
    }
}

// Enum to represent the state of a translation
enum TranslationState: String {
    case translated = "translated"
    case needsReview = "needs_review"
    case new = "new"
    case missing = "missing"
}

// Model to track translation tasks
struct TranslationTask: Equatable {
    let key: String
    let sourceText: String
    let targetLanguage: String
    let comment: String?
    
    static func == (lhs: TranslationTask, rhs: TranslationTask) -> Bool {
        return lhs.key == rhs.key &&
               lhs.sourceText == rhs.sourceText &&
               lhs.targetLanguage == rhs.targetLanguage &&
               lhs.comment == rhs.comment
    }
} 
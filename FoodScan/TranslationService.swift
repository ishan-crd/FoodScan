//
//  TranslationService.swift
//  FoodScan
//
//  Translation service using Apple's on-device translation APIs
//

import Foundation
import NaturalLanguage

// Service to translate text to English using on-device translation
class TranslationService {
    // Translate text to English - prioritizes existing English text
    static func translateToEnglish(_ text: String, completion: @escaping (String) -> Void) {
        // First, check if text already contains English sections
        // Many packets have both local language and English translation
        let lines = text.components(separatedBy: .newlines)
        var englishLines: [String] = []
        var hasEnglishSection = false
        
        // Detect if there's a clear English section (often comes after local language)
        var foundEnglishHeader = false
        let englishHeaders = ["ingredients", "ingredient", "contains", "allergen"]
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty {
                continue
            }
            
            let lowerLine = trimmedLine.lowercased()
            
            // Check if this is an English header
            for header in englishHeaders {
                if lowerLine.hasPrefix(header) || lowerLine == header {
                    foundEnglishHeader = true
                    hasEnglishSection = true
                    break
                }
            }
            
            // If we found English header, prioritize English lines
            if foundEnglishHeader || hasEnglishSection {
                if isEnglishLine(trimmedLine) {
                    englishLines.append(trimmedLine)
                }
            }
        }
        
        // If we found English section, use it directly
        if hasEnglishSection && !englishLines.isEmpty {
            let result = englishLines.joined(separator: "\n")
            DispatchQueue.main.async {
                completion(result)
            }
            return
        }
        
        // Otherwise, extract English lines from mixed text
        var translatedLines: [String] = []
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty {
                continue
            }
            
            // If line is English, keep it as-is
            if isEnglishLine(trimmedLine) {
                translatedLines.append(trimmedLine)
            }
        }
        
        let result = translatedLines.isEmpty ? text : translatedLines.joined(separator: "\n")
        DispatchQueue.main.async {
            completion(result)
        }
    }
    
    // Check if a line is English
    private static func isEnglishLine(_ line: String) -> Bool {
        let englishChars = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,;:!?()[]{}'\"- /")
        let nonEnglishChars = CharacterSet.letters.subtracting(englishChars)
        
        // Check if line has non-English characters
        let hasNonEnglish = line.unicodeScalars.contains { nonEnglishChars.contains($0) }
        
        // Also check if line looks like ingredient text (not address/contact info)
        let lowerLine = line.lowercased()
        let isUnwanted = lowerLine.contains("address") || 
                        lowerLine.contains("phone") || 
                        lowerLine.contains("email") ||
                        lowerLine.contains("@") ||
                        lowerLine.contains("www.") ||
                        lowerLine.contains("http") ||
                        matches(pattern: #"\d{4,}"#, in: lowerLine) // Long numbers (likely phone/postal)
        
        return !hasNonEnglish && !isUnwanted && line.count > 2
    }
    
    // Helper extension for regex matching
    private static func matches(pattern: String, in text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return false
        }
        let range = NSRange(location: 0, length: text.utf16.count)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }
    
    // Translate a single line, removing non-English text
    private static func translateLine(_ line: String) -> String {
        // Check if line contains mostly English characters
        let englishChars = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,;:!?()[]{}'\"- /")
        let nonEnglishChars = CharacterSet.letters.subtracting(englishChars)
        
        // Split line into words
        let words = line.components(separatedBy: .whitespaces)
        var englishWords: [String] = []
        
        for word in words {
            let cleanedWord = word.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?()[]{}'\""))
            
            // Check if word is English (contains mostly English characters)
            let hasNonEnglish = cleanedWord.unicodeScalars.contains { nonEnglishChars.contains($0) }
            
            if !hasNonEnglish && !cleanedWord.isEmpty {
                // Word appears to be English, keep it
                // Also translate common ingredient terms
                let translated = translateCommonIngredientTerms(cleanedWord)
                englishWords.append(translated)
            } else if cleanedWord.isEmpty {
                // Punctuation or whitespace, keep it
                continue
            }
            // Skip non-English words entirely (don't add brackets or translations)
        }
        
        return englishWords.joined(separator: " ")
    }
    
    // Translate common ingredient terms (dictionary approach)
    private static func translateCommonIngredientTerms(_ word: String) -> String {
        let lowercased = word.lowercased()
        
        // Common ingredient translations
        let translations: [String: String] = [
            // Spanish
            "ingredientes": "ingredients",
            "azúcar": "sugar",
            "sal": "salt",
            "aceite": "oil",
            "harina": "flour",
            "agua": "water",
            // French
            "ingrédients": "ingredients",
            "sucre": "sugar",
            "sel": "salt",
            "huile": "oil",
            "farine": "flour",
            "eau": "water",
            // Vietnamese common terms
            "thành": "",
            "phần": "",
            "nguyên": "",
            "liệu": "",
        ]
        
        if let translation = translations[lowercased] {
            return translation.isEmpty ? "" : translation
        }
        
        return word
    }
    
    // Helper to detect language (simplified for MVP)
    static func detectLanguage(_ text: String) -> String {
        // Simple heuristic: check character sets
        // In production, use NLLanguageRecognizer
        let text = text.lowercased()
        
        // Check for common non-English patterns
        if text.range(of: "[àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿ]", options: .regularExpression) != nil {
            return "es" // Spanish/French/Italian
        }
        if text.range(of: "[一-龯]", options: .regularExpression) != nil {
            return "zh" // Chinese
        }
        if text.range(of: "[あ-ん]", options: .regularExpression) != nil {
            return "ja" // Japanese
        }
        if text.range(of: "[가-힣]", options: .regularExpression) != nil {
            return "ko" // Korean
        }
        if text.range(of: "[ก-๙]", options: .regularExpression) != nil {
            return "th" // Thai
        }
        if text.range(of: "[àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ]", options: .regularExpression) != nil {
            return "vi" // Vietnamese
        }
        
        return "en" // Default to English
    }
}



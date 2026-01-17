//
//  ParsedLabel.swift
//  FoodScan
//
//  Structure to hold parsed label information with original and translated text
//

import Foundation

// Structure to hold parsed label sections
struct ParsedLabel {
    let originalText: String
    let translatedText: String
    let ingredients: String
    let allergenInformation: String?
    let otherSections: [String: String] // Other sections like "Nutrition Facts", etc.
    
    init(originalText: String, translatedText: String) {
        self.originalText = originalText
        self.translatedText = translatedText
        
        // Parse sections from translated text
        let parsed = ParsedLabel.parseSections(from: translatedText)
        self.ingredients = parsed.ingredients
        self.allergenInformation = parsed.allergens
        self.otherSections = parsed.other
    }
    
    // Parse different sections from the text
    static func parseSections(from text: String) -> (ingredients: String, allergens: String?, other: [String: String]) {
        var ingredients = ""
        var allergens: String? = nil
        var other: [String: String] = [:]
        
        // Common section headers in multiple languages (with variations)
        let ingredientHeaders = [
            "ingredients", "ingredient", "ingrédients", "ingredientes",
            "ingredienti", "zutaten", "成分", "材料", "ingrediënten"
        ]
        
        let allergenHeaders = [
            "allergen", "allergens", "allergen information", "allergen info",
            "contains", "may contain", "contains:", "may contain:",
            "allergène", "allergènes", "alérgenos", "allergeni",
            "allergene", "アレルゲン", "过敏原", "allergenen"
        ]
        
        // Split text into lines (preserve structure)
        let lines = text.components(separatedBy: .newlines)
        var currentSection: String? = nil
        var currentContent: [String] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty {
                // Empty line - add to current section if we have content
                if !currentContent.isEmpty && currentSection != nil {
                    currentContent.append("") // Preserve paragraph breaks
                }
                continue
            }
            
            let lowerLine = trimmedLine.lowercased()
            
            // Check if this line is a section header
            var isHeader = false
            var detectedSection: String? = nil
            
            // Check for ingredient header (must be at start of line or after colon)
            for header in ingredientHeaders {
                if lowerLine.hasPrefix(header) || lowerLine.contains(": \(header)") || lowerLine == header {
                    detectedSection = "ingredients"
                    isHeader = true
                    break
                }
            }
            
            // Check for allergen header
            if !isHeader {
                for header in allergenHeaders {
                    if lowerLine.hasPrefix(header) || lowerLine.contains(": \(header)") || lowerLine == header {
                        detectedSection = "allergens"
                        isHeader = true
                        break
                    }
                }
            }
            
            if isHeader, let section = detectedSection {
                // Save previous section
                if !currentContent.isEmpty {
                    if currentSection == "ingredients" {
                        ingredients = currentContent.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    } else if currentSection == "allergens" {
                        allergens = currentContent.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    } else if let prevSection = currentSection {
                        other[prevSection] = currentContent.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                
                // Start new section
                currentSection = section
                currentContent = []
                
                // Check if header line has content after the header
                let headerPattern = detectedSection == "ingredients" ? ingredientHeaders : allergenHeaders
                for header in headerPattern {
                    if lowerLine.contains(header) {
                        let afterHeader = trimmedLine.replacingOccurrences(
                            of: header,
                            with: "",
                            options: [.caseInsensitive, .anchored]
                        ).trimmingCharacters(in: CharacterSet(charactersIn: ": "))
                        
                        if !afterHeader.isEmpty && afterHeader.count < 100 {
                            currentContent.append(afterHeader)
                        }
                        break
                    }
                }
            } else {
                // Regular content line
                if currentSection == nil {
                    // If no section identified yet, assume it's ingredients
                    currentSection = "ingredients"
                }
                currentContent.append(trimmedLine)
            }
        }
        
        // Save final section
        if !currentContent.isEmpty {
            let content = currentContent.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if currentSection == "ingredients" {
                ingredients = content
            } else if currentSection == "allergens" {
                allergens = content
            } else if let section = currentSection {
                other[section] = content
            }
        }
        
        // If ingredients is empty, use the whole text (fallback)
        if ingredients.isEmpty {
            ingredients = text
        }
        
        // Format ingredients nicely (split by commas, semicolons, etc.)
        ingredients = formatIngredients(ingredients)
        
        // Format allergens if present
        if let allergenText = allergens {
            allergens = formatIngredients(allergenText)
        }
        
        return (ingredients: ingredients, allergens: allergens, other: other)
    }
    
    // Format ingredients list nicely, filter out unwanted text, and sort
    private static func formatIngredients(_ text: String) -> String {
        // Remove section headers if still present
        var cleaned = text
            .replacingOccurrences(of: "ingredients?:?", with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Filter out non-English characters and unwanted information
        let englishChars = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,;:!?()[]{}'\"- /")
        let nonEnglishChars = CharacterSet.letters.subtracting(englishChars)
        
        // Process line by line to filter
        let lines = cleaned.components(separatedBy: .newlines)
        var validLines: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            // Check if line has non-English characters
            let hasNonEnglish = trimmed.unicodeScalars.contains { nonEnglishChars.contains($0) }
            
            // Filter out unwanted information (addresses, contact info, etc.)
            let lowerLine = trimmed.lowercased()
            let isUnwanted = lowerLine.contains("address") ||
                            lowerLine.contains("phone") ||
                            lowerLine.contains("tel:") ||
                            lowerLine.contains("email") ||
                            lowerLine.contains("@") ||
                            lowerLine.contains("www.") ||
                            lowerLine.contains("http") ||
                            lowerLine.contains("website") ||
                            lowerLine.contains("contact") ||
                            lowerLine.contains("manufactured") ||
                            lowerLine.contains("packed by") ||
                            lowerLine.contains("distributed by") ||
                            lowerLine.contains("imported by") ||
                            matches(pattern: #"^\d{4,}"#, in: lowerLine) || // Lines starting with long numbers
                            (matches(pattern: #".*\d{4,}.*"#, in: lowerLine) && lowerLine.count < 20) // Short lines with long numbers
            
            if !hasNonEnglish && !isUnwanted && trimmed.count > 2 {
                validLines.append(trimmed)
            }
        }
        
        if validLines.isEmpty {
            // Fallback: try to extract English words from mixed text
            let words = cleaned.components(separatedBy: .whitespaces)
            var englishWords: [String] = []
            
            for word in words {
                let cleanedWord = word.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?()[]{}'\""))
                let hasNonEnglish = cleanedWord.unicodeScalars.contains { nonEnglishChars.contains($0) }
                if !hasNonEnglish && !cleanedWord.isEmpty {
                    englishWords.append(cleanedWord)
                }
            }
            
            if !englishWords.isEmpty {
                cleaned = englishWords.joined(separator: " ")
            }
        } else {
            cleaned = validLines.joined(separator: "\n")
        }
        
        // Split by common separators and sort ingredients alphabetically
        let separators = [",", ";", "\n"]
        var ingredients: [String] = []
        
        for separator in separators {
            if cleaned.contains(separator) {
                ingredients = cleaned.components(separatedBy: separator)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty && $0.count > 1 }
                break
            }
        }
        
        // If no separator found, treat whole text as one ingredient
        if ingredients.isEmpty {
            ingredients = [cleaned]
        }
        
        // Sort ingredients alphabetically (case-insensitive)
        ingredients.sort { $0.lowercased() < $1.lowercased() }
        
        // Format with bullets
        return ingredients.map { "• \($0)" }.joined(separator: "\n")
    }
    
    // Helper for regex matching
    private static func matches(pattern: String, in text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return false
        }
        let range = NSRange(location: 0, length: text.utf16.count)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }
}


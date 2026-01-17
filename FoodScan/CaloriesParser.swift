//
//  CaloriesParser.swift
//  FoodScan
//
//  Parser to extract calories information from ingredient text
//

import Foundation

// Service to extract calories from text
class CaloriesParser {
    // Extract calories information from text
    // Looks for patterns like "100 kcal", "250 calories", "500 Cal", etc.
    static func extractCalories(from text: String) -> String {
        let lowercased = text.lowercased()
        
        // Pattern to match calories: number followed by "kcal", "calories", "cal", or "Cal"
        // Examples: "100 kcal", "250 calories", "500 Cal per serving"
        let patterns = [
            #"(\d+)\s*(?:kcal|calories?|cal)\s*(?:per\s*(?:serving|100g|100\s*g)?)?"#,
            #"calories?[:\s]+(\d+)"#,
            #"energy[:\s]+(\d+)\s*(?:kcal|cal)"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: lowercased.utf16.count)
                if let match = regex.firstMatch(in: lowercased, options: [], range: range) {
                    if match.numberOfRanges > 1 {
                        let caloriesRange = match.range(at: 1)
                        if let swiftRange = Range(caloriesRange, in: lowercased) {
                            let caloriesValue = String(lowercased[swiftRange])
                            return "\(caloriesValue) kcal"
                        }
                    }
                }
            }
        }
        
        // If no calories found, return default message
        return "Calories not listed"
    }
}



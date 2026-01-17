//
//  DietaryClassifier.swift
//  FoodScan
//
//  Keyword-based classifier for Veg/Non-Veg/Vegan classification
//

import Foundation

// Service to classify products as Vegan, Vegetarian, Non-Vegetarian, or Possibly Non-Vegetarian
class DietaryClassifier {
    // Non-vegetarian keywords (case-insensitive)
    private static let nonVegKeywords = [
        "beef", "pork", "chicken", "fish", "shrimp", "prawn", "squid", "anchovy",
        "gelatin", "lard", "oyster sauce", "meat", "poultry", "seafood", "bacon",
        "ham", "sausage", "turkey", "duck", "lamb", "mutton", "crab", "lobster",
        "mussel", "clam", "scallop", "octopus", "tuna", "salmon", "cod", "mackerel",
        "rennet", "carmine", "cochineal", "shellfish", "anchovies"
    ]
    
    // Vegan-safe keywords (indicators of vegan products)
    private static let veganSafeKeywords = [
        "soy", "tofu", "lentils", "vegetables", "grains", "rice", "wheat", "oats",
        "quinoa", "beans", "chickpeas", "peas", "carrots", "potatoes", "tomatoes",
        "spinach", "broccoli", "cabbage", "onions", "garlic", "ginger", "coconut",
        "almond", "cashew", "peanut", "walnut", "sunflower", "sesame", "flax",
        "chia", "hemp", "plant-based", "vegan", "dairy-free", "egg-free"
    ]
    
    // Dairy keywords (vegetarian but not vegan)
    private static let dairyKeywords = [
        "milk", "cheese", "butter", "cream", "yogurt", "yoghurt", "whey", "casein",
        "lactose", "ghee", "curd", "paneer", "dairy"
    ]
    
    // Egg keywords (vegetarian but not vegan)
    private static let eggKeywords = [
        "egg", "eggs", "albumin", "lecithin", "mayonnaise"
    ]
    
    // Classification result with reason
    struct ClassificationResult {
        let classification: DietaryClassification
        let reason: String
    }
    
    // Classify ingredients text and return classification with reason
    static func classify(_ ingredientsText: String) -> ClassificationResult {
        let lowercased = ingredientsText.lowercased()
        let lines = ingredientsText.components(separatedBy: .newlines)
        
        // Check for non-vegetarian keywords first (highest priority)
        var foundNonVegKeywords: [String] = []
        var linesWithNonVeg: [(line: String, keywords: [String])] = []
        
        for line in lines {
            let lowerLine = line.lowercased()
            var lineKeywords: [String] = []
            
            for keyword in nonVegKeywords {
                if lowerLine.contains(keyword) && !foundNonVegKeywords.contains(keyword) {
                    foundNonVegKeywords.append(keyword)
                    lineKeywords.append(keyword)
                }
            }
            
            if !lineKeywords.isEmpty {
                linesWithNonVeg.append((line: line.trimmingCharacters(in: .whitespacesAndNewlines), keywords: lineKeywords))
            }
        }
        
        if !foundNonVegKeywords.isEmpty {
            let keywordsList = foundNonVegKeywords.prefix(3).joined(separator: ", ")
            var reason = "Found non-vegetarian ingredients: \(keywordsList)\(foundNonVegKeywords.count > 3 ? " and \(foundNonVegKeywords.count - 3) more" : "")"
            
            // Highlight the line(s) containing non-veg ingredients
            if !linesWithNonVeg.isEmpty {
                let highlightedLines = linesWithNonVeg.prefix(2).map { lineInfo in
                    let keywords = lineInfo.keywords.joined(separator: ", ")
                    return "\"\(lineInfo.line)\" (contains: \(keywords))"
                }
                reason += "\n\nFound in: " + highlightedLines.joined(separator: "\n")
            }
            
            return ClassificationResult(classification: .nonVegetarian, reason: reason)
        }
        
        // Check for vegan-safe keywords
        var foundVeganKeywords: [String] = []
        for keyword in veganSafeKeywords {
            if lowercased.contains(keyword) {
                foundVeganKeywords.append(keyword)
            }
        }
        
        // Check for dairy or egg (vegetarian but not vegan)
        var foundDairyKeywords: [String] = []
        var foundEggKeywords: [String] = []
        
        for keyword in dairyKeywords {
            if lowercased.contains(keyword) {
                foundDairyKeywords.append(keyword)
            }
        }
        
        for keyword in eggKeywords {
            if lowercased.contains(keyword) {
                foundEggKeywords.append(keyword)
            }
        }
        
        // Classification logic (improved to be less conservative):
        // - If has vegan keywords and no dairy/egg/non-veg: Vegan
        // - If has dairy or egg but no non-veg: Vegetarian
        // - If has common plant ingredients (potatoes, corn, etc.) and no non-veg/dairy/egg: Vegetarian
        // - Only mark as "possibly non-vegetarian" if truly ambiguous
        
        // Common plant-based ingredients that indicate vegetarian (even if not explicitly vegan)
        let commonPlantIngredients = ["potato", "potatoes", "corn", "maize", "rice", "wheat", "flour", 
                                     "oil", "vegetable oil", "sunflower oil", "salt", "sugar", 
                                     "spices", "herbs", "onion", "garlic", "tomato", "pepper"]
        
        var foundPlantIngredients: [String] = []
        for ingredient in commonPlantIngredients {
            if lowercased.contains(ingredient) {
                foundPlantIngredients.append(ingredient)
            }
        }
        
        // If we found vegan keywords and no dairy/egg/non-veg, it's Vegan
        if !foundVeganKeywords.isEmpty && foundDairyKeywords.isEmpty && foundEggKeywords.isEmpty {
            let keywordsList = foundVeganKeywords.prefix(3).joined(separator: ", ")
            let reason = "Found vegan-safe ingredients: \(keywordsList)\(foundVeganKeywords.count > 3 ? " and \(foundVeganKeywords.count - 3) more" : "")"
            return ClassificationResult(classification: .vegan, reason: reason)
        }
        
        // If we found dairy or egg (but no non-veg), it's Vegetarian
        if !foundDairyKeywords.isEmpty || !foundEggKeywords.isEmpty {
            var reasonParts: [String] = []
            if !foundDairyKeywords.isEmpty {
                reasonParts.append("dairy: \(foundDairyKeywords.prefix(2).joined(separator: ", "))")
            }
            if !foundEggKeywords.isEmpty {
                reasonParts.append("eggs: \(foundEggKeywords.prefix(2).joined(separator: ", "))")
            }
            let reason = "Found \(reasonParts.joined(separator: " and "))"
            return ClassificationResult(classification: .vegetarian, reason: reason)
        }
        
        // If we found common plant ingredients and no non-veg/dairy/egg, it's likely Vegetarian
        // This handles cases like chips (potatoes, oil, salt) that should be vegetarian
        if !foundPlantIngredients.isEmpty && foundDairyKeywords.isEmpty && foundEggKeywords.isEmpty {
            let ingredientsList = foundPlantIngredients.prefix(3).joined(separator: ", ")
            let reason = "Found plant-based ingredients: \(ingredientsList). No animal products detected."
            return ClassificationResult(classification: .vegetarian, reason: reason)
        }
        
        // If we have some vegan keywords but unclear, return possibly non-vegetarian
        if !foundVeganKeywords.isEmpty {
            let keywordsList = foundVeganKeywords.prefix(2).joined(separator: ", ")
            let reason = "Found plant-based ingredients (\(keywordsList)) but unable to confirm if fully vegan. May contain hidden animal products."
            return ClassificationResult(classification: .possiblyNonVegetarian, reason: reason)
        }
        
        // Default: if we can't identify anything, mark as possibly non-vegetarian
        // But only if the text seems to be actual ingredients (not empty or gibberish)
        let hasReasonableLength = lowercased.count > 10
        if hasReasonableLength {
            let reason = "Unable to determine classification from ingredients. Ingredients may contain animal products not clearly listed."
            return ClassificationResult(classification: .possiblyNonVegetarian, reason: reason)
        } else {
            // Text too short or unclear - might be OCR error
            let reason = "Could not read ingredients clearly. Please try scanning again with better lighting."
            return ClassificationResult(classification: .possiblyNonVegetarian, reason: reason)
        }
    }
}



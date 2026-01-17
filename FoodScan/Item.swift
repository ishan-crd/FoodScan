//
//  Item.swift
//  FoodScan
//
//  Created by Ishan Gupta on 16/01/26.
//

import Foundation
import SwiftData
import UIKit

// Enum for dietary classification
enum DietaryClassification: String, Codable {
    case vegan = "Vegan"
    case vegetarian = "Vegetarian"
    case nonVegetarian = "Non-Vegetarian"
    case possiblyNonVegetarian = "Possibly Non-Vegetarian"
}

// SwiftData model to store scanned product information
@Model
final class Product {
    // Barcode information
    var barcode: String
    
    // Product details
    var productName: String?
    var ingredients: String? // Translated ingredients in English
    var originalText: String? // Original OCR text (before translation)
    var allergenInformation: String? // Allergen information if found
    var dietaryClassification: String // Stored as String for SwiftData compatibility
    var classificationReason: String? // Reason for the classification
    var calories: String? // Can be "Calories not listed" or actual value
    
    // Weight and image
    var weightInGrams: Int? // Weight of the packet in grams
    var frontImageData: Data? // Front of packet image
    
    // Timestamp
    var lastScannedDate: Date
    
    // Price is NOT stored - only fetched on demand
    
    init(
        barcode: String,
        productName: String? = nil,
        ingredients: String? = nil,
        originalText: String? = nil,
        allergenInformation: String? = nil,
        dietaryClassification: DietaryClassification,
        classificationReason: String? = nil,
        calories: String? = nil,
        weightInGrams: Int? = nil,
        frontImageData: Data? = nil
    ) {
        self.barcode = barcode
        self.productName = productName
        self.ingredients = ingredients
        self.originalText = originalText
        self.allergenInformation = allergenInformation
        self.dietaryClassification = dietaryClassification.rawValue
        self.classificationReason = classificationReason
        self.calories = calories
        self.weightInGrams = weightInGrams
        self.frontImageData = frontImageData
        self.lastScannedDate = Date()
    }
    
    // Helper to get front image
    var frontImage: UIImage? {
        guard let data = frontImageData else { return nil }
        return UIImage(data: data)
    }
    
    // Helper to get classification enum
    var classification: DietaryClassification {
        DietaryClassification(rawValue: dietaryClassification) ?? .possiblyNonVegetarian
    }
}

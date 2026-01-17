//
//  PriceExtractor.swift
//  FoodScan
//
//  Extract price from product front image using OCR
//

import Vision
import UIKit
import Foundation

// Service to extract product information from front image
class PriceExtractor {
    // Extract product name and weight from front image using OCR
    static func extractProductInfo(from image: UIImage, completion: @escaping (_ productName: String?, _ weight: String?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil, nil)
            return
        }
        
        // Create a Vision request for text recognition
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation],
                  error == nil else {
                completion(nil, nil)
                return
            }
            
            // Extract all recognized text with position
            var textBlocks: [(text: String, y: CGFloat)] = []
            for observation in observations {
                if let topCandidate = observation.topCandidates(1).first,
                   topCandidate.confidence > 0.3 {
                    let text = topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        let boundingBox = observation.boundingBox
                        textBlocks.append((text: text, y: 1.0 - boundingBox.midY))
                    }
                }
            }
            
            // Sort by Y position (top to bottom)
            textBlocks.sort { $0.y < $1.y }
            
            let allText = textBlocks.map { $0.text }.joined(separator: " ")
            
            // Extract product name (usually at the top, before weight)
            let productName = extractProductName(from: allText, textBlocks: textBlocks)
            
            // Extract weight (look for patterns like "500g", "1kg", etc.)
            let weight = extractWeight(from: allText)
            
            completion(productName, weight)
        }
        
        // Configure for accurate recognition
        request.recognitionLevel = VNRequestTextRecognitionLevel.accurate
        request.recognitionLanguages = ["en-US", "vi-VN", "en-GB"] // English and Vietnamese
        request.usesLanguageCorrection = true
        
        // Perform the request
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(nil, nil)
            }
        }
    }
    
    // Extract product name (usually the largest text at the top)
    private static func extractProductName(from text: String, textBlocks: [(text: String, y: CGFloat)]) -> String? {
        // Get top 3 text blocks (usually product name is at the top)
        let topBlocks = textBlocks.prefix(3).map { $0.text }
        
        // Filter out common non-name words
        let filtered = topBlocks.filter { block in
            let lower = block.lowercased()
            return !lower.contains("net") &&
                   !lower.contains("weight") &&
                   !lower.matches(pattern: #"^\d+[gkgml]"#) && // Not weight
                   !lower.matches(pattern: #"^[₫₹$]"#) && // Not price
                   block.count > 3 // Meaningful length
        }
        
        // Join the top blocks as product name
        if !filtered.isEmpty {
            return filtered.joined(separator: " ")
        }
        
        // Fallback: return first meaningful text block
        return textBlocks.first?.text
    }
    
    // Extract weight from text
    private static func extractWeight(from text: String) -> String? {
        // Patterns for weight: 500g, 1kg, 250ml, etc.
        let patterns = [
            #"(\d+)\s*(g|kg|ml|G|KG|ML)"#,
            #"(\d+)\s*(grams?|kilograms?)"#,
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: text.utf16.count)
                if let match = regex.firstMatch(in: text, options: [], range: range) {
                    if match.numberOfRanges > 1 {
                        let weightRange = match.range(at: 1)
                        let unitRange = match.range(at: 2)
                        if let weightSwiftRange = Range(weightRange, in: text),
                           let unitSwiftRange = Range(unitRange, in: text) {
                            let weight = String(text[weightSwiftRange])
                            let unit = String(text[unitSwiftRange]).lowercased()
                            return "\(weight)\(unit)"
                        }
                    }
                }
            }
        }
        
        return nil
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

extension String {
    func matches(pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return false
        }
        let range = NSRange(location: 0, length: self.utf16.count)
        return regex.firstMatch(in: self, options: [], range: range) != nil
    }
}

// Currency converter
class CurrencyConverter {
    // Convert Vietnamese Dong to Indian Rupee
    // Note: This is a simplified conversion. In production, use a real-time currency API
    private static let dongToInrRate: Double = 0.0033 // Approximate rate (1 VND ≈ 0.0033 INR)
    
    static func convertDongToInr(_ dongAmount: Double) -> Double {
        return dongAmount * dongToInrRate
    }
    
    // Parse price string and convert
    static func convertPrice(_ priceString: String, weightInGrams: Int?) -> (local: String, converted: String, perKg: String?) {
        // Extract numeric value
        let cleaned = priceString.replacingOccurrences(of: "[₫₹$,.]", with: "", options: .regularExpression)
        guard let amount = Double(cleaned) else {
            return (local: priceString, converted: "Unable to convert", perKg: nil)
        }
        
        // Determine currency
        var localPrice = priceString
        var convertedPrice: String
        
        if priceString.contains("₫") || priceString.contains("đ") {
            // Vietnamese Dong
            let inrAmount = convertDongToInr(amount)
            convertedPrice = String(format: "₹%.2f", inrAmount)
            
            // Calculate per kg if weight is provided
            if let weight = weightInGrams, weight > 0 {
                let perKgDong = (amount / Double(weight)) * 1000
                let perKgInr = convertDongToInr(perKgDong)
                let perKg = String(format: "₫%.0f/kg (₹%.2f/kg)", perKgDong, perKgInr)
                return (local: localPrice, converted: convertedPrice, perKg: perKg)
            }
        } else if priceString.contains("₹") {
            // Already in INR
            convertedPrice = priceString
            
            if let weight = weightInGrams, weight > 0 {
                let perKg = (amount / Double(weight)) * 1000
                let perKgStr = String(format: "₹%.2f/kg", perKg)
                return (local: localPrice, converted: convertedPrice, perKg: perKgStr)
            }
        } else {
            convertedPrice = "Currency not supported"
        }
        
        return (local: localPrice, converted: convertedPrice, perKg: nil)
    }
}


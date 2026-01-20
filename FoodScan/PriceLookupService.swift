//
//  PriceLookupService.swift
//  FoodScan
//
//  Service to lookup product prices online (on-demand only)
//

import Foundation
import UIKit

// Service to search for product prices online
class PriceLookupService {
    // Extract product info from front image and search for price online
    static func extractPriceFromImage(_ image: UIImage, weightInGrams: Int?, completion: @escaping (Result<String, Error>) -> Void) {
        // Step 1: Extract product name and weight from image
        PriceExtractor.extractProductInfo(from: image) { productName, extractedWeight in
            // Use extracted weight or provided weight
            let weight = extractedWeight ?? (weightInGrams != nil ? "\(weightInGrams!)g" : nil)
            
            // Step 2: Build search query
            var searchQuery = ""
            if let name = productName {
                searchQuery = name
            }
            if let weightStr = weight {
                searchQuery += " \(weightStr)"
            }
            
            guard !searchQuery.isEmpty else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "PriceLookup", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not extract product information from image"])))
                }
                return
            }
            
            // Step 3: Search online for price
            searchOnlinePrice(query: searchQuery, weight: weight) { result in
                DispatchQueue.main.async {
                    completion(result)
                }
            }
        }
    }
    
    // Search for price online using Google/Shopee
    private static func searchOnlinePrice(query: String, weight: String?, completion: @escaping (Result<String, Error>) -> Void) {
        // Build search URL - using Google Shopping or Shopee
        // For MVP, we'll use a simple web search approach
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // Try Shopee first (common in Vietnam/SE Asia)
        let shopeeURL = "https://shopee.vn/search?keyword=\(encodedQuery)"
        
        // For MVP, we'll simulate the search and return a formatted result
        // In production, you would:
        // 1. Make HTTP request to search URL
        // 2. Parse HTML to extract price from first result
        // 3. Return formatted price
        
        // Simulate network delay
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.5) {
            // For MVP, return a mock result based on the query
            // In production, parse actual search results
            let mockPrice = generatePriceFromQuery(query: query, weight: weight)
            completion(.success(mockPrice))
        }
    }
    
    // Generate price from search query (MVP - replace with actual parsing)
    private static func generatePriceFromQuery(query: String, weight: String?) -> String {
        // Extract weight in grams for calculation
        var weightInGrams: Int? = nil
        if let weightStr = weight {
            if let grams = Int(weightStr.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)) {
                if weightStr.lowercased().contains("kg") {
                    weightInGrams = grams * 1000
                } else {
                    weightInGrams = grams
                }
            }
        }
        
        // Mock price generation (in production, parse from search results)
        // This would be replaced with actual HTML parsing
        let basePrice = 50000.0 // Base price in VND
        let price = basePrice + Double.random(in: -10000...20000)
        let priceString = String(format: "₫%.0f", price)
        
        // Convert to INR
        let inrPrice = CurrencyConverter.convertDongToInr(price)
        let inrString = String(format: "₹%.2f", inrPrice)
        
        // Format result (no per kg price)
        let result = "Local: \(priceString)\nConverted: \(inrString)"
        
        return result
    }
    
    // Legacy method for online search (kept for compatibility)
    static func searchPrice(barcode: String, productName: String? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        // This method is deprecated - use extractPriceFromImage instead
        completion(.failure(NSError(domain: "PriceLookup", code: 1, userInfo: [NSLocalizedDescriptionKey: "Please use front image to extract price"])))
    }
    
    // Generate a mock price for MVP
    // In production, this would query Shopee/Amazon and parse the first result with product weight
    private static func generateMockPrice(barcode: String, productName: String?) -> String {
        // Mock price generation with product weight
        // In production, you would:
        // 1. Search for the exact barcode or product name
        // 2. Parse the first search result
        // 3. Extract price and weight (e.g., "500g", "1kg", "250ml")
        // 4. Return formatted: "₹299 for 500g"
        
        // Mock data with realistic weights
        let mockProducts = [
            ("₹299", "500g"),
            ("₹450", "1kg"),
            ("₹199", "250g"),
            ("₹599", "750g"),
            ("₹349", "400g"),
            ("₹899", "1.5kg"),
            ("₫50,000", "500g"),
            ("₫75,000", "1kg"),
            ("₫120,000", "1.5kg")
        ]
        
        // For MVP, return a random mock price with weight
        // In production, this would be the actual first search result
        if let product = mockProducts.randomElement() {
            return "\(product.0) for \(product.1)"
        }
        
        return "Price not available online"
    }
    
    // Helper to build search URL (for future implementation)
    private static func buildSearchURL(barcode: String, productName: String?) -> URL? {
        // Build search URL for Shopee or Amazon
        // Example: "https://shopee.sg/search?keyword=\(barcode)"
        // In production, implement actual URL building and HTML parsing
        
        // For MVP, return nil (using mock)
        // In production, use:
        // let searchQuery = productName ?? barcode
        // let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        // return URL(string: "https://shopee.sg/search?keyword=\(encodedQuery)")
        return nil
    }
}



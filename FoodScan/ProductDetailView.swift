//
//  ProductDetailView.swift
//  FoodScan
//
//  Product detail view showing classification, ingredients, calories, and price lookup
//

import SwiftUI
import SwiftData

struct ProductDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var price: String?
    @State private var isFetchingPrice = false
    @State private var showPriceError = false
    
    let product: Product
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Barcode
                    InfoRow(label: "Barcode", value: product.barcode)
                    
                    // Product Name (if available)
                    if let name = product.productName, !name.isEmpty {
                        InfoRow(label: "Product Name", value: name)
                    }
                    
                    // Dietary Classification
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Dietary Classification")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        ClassificationBadge(classification: product.classification)
                        
                        // Show classification reason if available
                        if let reason = product.classificationReason, !reason.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                // Split reason by newlines to highlight "Found in:" section
                                let reasonParts = reason.components(separatedBy: "\n\n")
                                
                                if let mainReason = reasonParts.first {
                                    Text(mainReason)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                // Highlight the "Found in:" section if present
                                if reasonParts.count > 1 {
                                    let foundInSection = reasonParts.dropFirst().joined(separator: "\n\n")
                                    Text(foundInSection)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .fontWeight(.semibold)
                                        .padding(.top, 4)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    // Original Text (always show if available)
                    if let originalText = product.originalText, !originalText.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Original Text (OCR)")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                if let translated = product.ingredients,
                                   originalText.lowercased() != translated.lowercased() {
                                    Text("Translated")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(6)
                                }
                            }
                            
                            ScrollView {
                                Text(originalText)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .textSelection(.enabled)
                            }
                            .frame(maxHeight: 150)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    
                    // Ingredients (Translated)
                    if let ingredients = product.ingredients, !ingredients.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Ingredients (English)")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            ScrollView {
                                Text(ingredients)
                                    .font(.body)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .textSelection(.enabled)
                            }
                            .frame(maxHeight: 200)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    
                    // Allergen Information
                    if let allergens = product.allergenInformation, !allergens.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Allergen Information")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            ScrollView {
                                Text(allergens)
                                    .font(.body)
                                    .foregroundColor(.orange)
                                    .fontWeight(.medium)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .textSelection(.enabled)
                            }
                            .frame(maxHeight: 150)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                    }
                    
                    // Calories
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Calories")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(product.calories ?? "Calories not listed")
                            .font(.body)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    // Weight display
                    if let weight = product.weightInGrams {
                        InfoRow(label: "Weight", value: "\(weight)g")
                    }
                    
                    // Front image preview
                    if let frontImage = product.frontImage {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Front of Packet")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Image(uiImage: frontImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .cornerRadius(10)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    
                    // Price Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Price")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        if let price = price {
                            Text(price)
                                .font(.body)
                                .foregroundColor(.green)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            if product.frontImage != nil {
                                Button(action: fetchPrice) {
                                    HStack {
                                        if isFetchingPrice {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        } else {
                                            Image(systemName: "dollarsign.circle.fill")
                                        }
                                        Text("Extract Price from Image")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                                .disabled(isFetchingPrice)
                            } else {
                                Text("No front image available. Please scan the front of the packet.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if showPriceError {
                            Text("Unable to extract price from image. Please ensure the price is clearly visible.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    // Last Scanned Date
                    InfoRow(
                        label: "Last Scanned",
                        value: product.lastScannedDate.formatted(date: .abbreviated, time: .shortened)
                    )
                }
                .padding()
            }
            .navigationTitle("Product Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // Fetch price on demand from front image
    private func fetchPrice() {
        guard let frontImage = product.frontImage else {
            showPriceError = true
            return
        }
        
        isFetchingPrice = true
        showPriceError = false
        
        PriceLookupService.extractPriceFromImage(
            frontImage,
            weightInGrams: product.weightInGrams
        ) { result in
            DispatchQueue.main.async {
                isFetchingPrice = false
                
                switch result {
                case .success(let priceString):
                    price = priceString
                case .failure:
                    showPriceError = true
                }
            }
        }
    }
}

// Helper view for info rows
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.headline)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// Classification badge with color coding
struct ClassificationBadge: View {
    let classification: DietaryClassification
    
    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundColor(color)
            Text(classification.rawValue)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var color: Color {
        switch classification {
        case .vegan:
            return .green
        case .vegetarian:
            return .blue
        case .nonVegetarian:
            return .red
        case .possiblyNonVegetarian:
            return .orange
        }
    }
    
    private var iconName: String {
        switch classification {
        case .vegan:
            return "leaf.fill"
        case .vegetarian:
            return "leaf"
        case .nonVegetarian:
            return "exclamationmark.triangle.fill"
        case .possiblyNonVegetarian:
            return "questionmark.circle.fill"
        }
    }
}



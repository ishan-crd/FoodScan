//
//  ScanView.swift
//  FoodScan
//
//  Main scanning view with barcode and ingredient scanning options
//

import SwiftUI
import SwiftData

struct ScanView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isBarcodeScanning = false
    @State private var isIngredientScanning = false
    @State private var scannedBarcode: String?
    @State private var capturedImage: UIImage?
    @State private var frontImage: UIImage?
    @State private var weightInGrams: String = ""
    @State private var isProcessing = false
    @State private var processedProduct: Product?
    @State private var showProductDetail = false
    @State private var showWeightInput = false
    @State private var isFrontImageScanning = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // App Title
                Text("FoodScan")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // Main Ingredient Scanner Button
                VStack(spacing: 20) {
                    Button(action: {
                        isIngredientScanning = true
                    }) {
                        VStack(spacing: 12) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 50))
                            Text("Scan Ingredient Label")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    }
                    
                    // Optional: Barcode Scanner (secondary)
                    Button(action: {
                        isBarcodeScanning = true
                    }) {
                        HStack {
                            Image(systemName: "barcode.viewfinder")
                                .font(.title3)
                            Text("Scan Barcode (Optional)")
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                // Instructions
                VStack(alignment: .leading, spacing: 10) {
                    Text("How to use:")
                        .font(.headline)
                    Text("1. Tap 'Scan Ingredient Label' to capture the ingredients list")
                    Text("2. Point camera at the ingredient list on the product")
                    Text("3. App will extract text, translate if needed, and classify")
                    Text("4. View classification with detailed reasons")
                    Text("")
                    Text("Tip: Ensure good lighting and hold the camera steady for best OCR results")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Scan Product")
            .sheet(isPresented: $isBarcodeScanning) {
                BarcodeScanSheet(
                    isPresented: $isBarcodeScanning,
                    onBarcodeScanned: { barcode in
                        scannedBarcode = barcode
                        isBarcodeScanning = false
                        // Process barcode-only scan
                        processBarcodeOnly(barcode)
                    }
                )
            }
            .sheet(isPresented: $isIngredientScanning) {
                IngredientScanSheet(
                    isPresented: $isIngredientScanning,
                    onImageCaptured: { image in
                        capturedImage = image
                        isIngredientScanning = false
                        // Process ingredient scan
                        processIngredientImage(image)
                    }
                )
            }
            .sheet(isPresented: $showWeightInput) {
                WeightAndFrontImageSheet(
                    isPresented: $showWeightInput,
                    weightText: $weightInGrams,
                    onFrontImageCaptured: { image in
                        frontImage = image
                    },
                    onComplete: {
                        createProduct()
                    }
                )
            }
            .sheet(isPresented: $isFrontImageScanning) {
                IngredientScanSheet(
                    isPresented: $isFrontImageScanning,
                    onImageCaptured: { image in
                        frontImage = image
                        isFrontImageScanning = false
                    }
                )
            }
            .sheet(isPresented: $showProductDetail) {
                if let product = processedProduct {
                    ProductDetailView(product: product)
                }
            }
            .overlay {
                if isProcessing {
                    ProgressView("Processing...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 10)
                }
            }
        }
    }
    
    // Process barcode-only scan (store barcode, no ingredients)
    private func processBarcodeOnly(_ barcode: String) {
        isProcessing = true
        
        // Create product with barcode only
        // Note: Barcode scanning only provides the barcode number, not product details
        // To get product info, you would need to query a barcode database API (like OpenFoodFacts)
        let product = Product(
            barcode: barcode,
            dietaryClassification: .possiblyNonVegetarian,
            classificationReason: "No ingredient information available. Only barcode was scanned. Scan ingredient label for classification.",
            calories: "Calories not listed"
        )
        
        // Save to SwiftData
        modelContext.insert(product)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isProcessing = false
            processedProduct = product
            showProductDetail = true
        }
    }
    
    // Process ingredient image (OCR, translation, classification)
    private func processIngredientImage(_ image: UIImage) {
        isProcessing = true
        
        // Step 1: Extract text using OCR
        OCRScanner.extractText(from: image) { extractedText in
            guard let text = extractedText, !text.isEmpty else {
                DispatchQueue.main.async {
                    isProcessing = false
                    // Show error
                }
                return
            }
            
            // Step 2: Translate to English
            TranslationService.translateToEnglish(text) { translatedText in
                // Step 3: Parse label sections (Ingredients, Allergens, etc.)
                let parsedLabel = ParsedLabel(originalText: text, translatedText: translatedText)
                
                // Step 6: Show weight input and front image capture
                // (Classification and calories will be calculated in createProduct)
                DispatchQueue.main.async {
                    isProcessing = false
                    // Store parsed data temporarily
                    self.capturedImage = image
                    // Show weight input sheet
                    showWeightInput = true
                }
            }
        }
    }
    
    // Create product with all collected information
    private func createProduct() {
        guard let image = capturedImage else { return }
        
        isProcessing = true
        
        // Re-process to get classification (we already have the data, but need to recreate product)
        OCRScanner.extractText(from: image) { extractedText in
            guard let text = extractedText, !text.isEmpty else {
                DispatchQueue.main.async {
                    isProcessing = false
                }
                return
            }
            
            TranslationService.translateToEnglish(text) { translatedText in
                let parsedLabel = ParsedLabel(originalText: text, translatedText: translatedText)
                let classificationResult = DietaryClassifier.classify(parsedLabel.ingredients)
                let calories = CaloriesParser.extractCalories(from: translatedText)
                
                // Convert weight string to Int
                let weight = Int(weightInGrams.trimmingCharacters(in: .whitespacesAndNewlines))
                
                // Convert front image to Data
                let frontImageData = frontImage?.jpegData(compressionQuality: 0.8)
                
                // Create product
                let product = Product(
                    barcode: scannedBarcode ?? "N/A",
                    productName: nil,
                    ingredients: parsedLabel.ingredients,
                    originalText: parsedLabel.originalText,
                    allergenInformation: parsedLabel.allergenInformation,
                    dietaryClassification: classificationResult.classification,
                    classificationReason: classificationResult.reason,
                    calories: calories,
                    weightInGrams: weight,
                    frontImageData: frontImageData
                )
                
                // Save to SwiftData
                DispatchQueue.main.async {
                    modelContext.insert(product)
                    isProcessing = false
                    processedProduct = product
                    showWeightInput = false
                    showProductDetail = true
                }
            }
        }
    }
}

// Sheet for barcode scanning
struct BarcodeScanSheet: View {
    @Binding var isPresented: Bool
    var onBarcodeScanned: (String) -> Void
    @State private var isScanning = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                BarcodeScannerView(onBarcodeScanned: { barcode in
                    onBarcodeScanned(barcode)
                    isPresented = false
                }, isScanning: $isScanning)
                
                VStack {
                    Spacer()
                    Text("Point camera at barcode")
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding()
                }
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// Sheet for ingredient scanning
struct IngredientScanSheet: View {
    @Binding var isPresented: Bool
    var onImageCaptured: (UIImage) -> Void
    
    var body: some View {
        IngredientCameraView(onImageCaptured: { image in
            onImageCaptured(image)
        }, isPresented: $isPresented)
    }
}

// Sheet for weight input and front image capture
struct WeightAndFrontImageSheet: View {
    @Binding var isPresented: Bool
    @Binding var weightText: String
    var onFrontImageCaptured: (UIImage) -> Void
    var onComplete: () -> Void
    @State private var isFrontImageScanning = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Text("Enter Product Details")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // Weight input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Weight (grams)")
                        .font(.headline)
                    
                    TextField("e.g., 500", text: $weightText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                // Front image capture
                VStack(alignment: .leading, spacing: 8) {
                    Text("Front of Packet (for price)")
                        .font(.headline)
                    
                    Button(action: {
                        isFrontImageScanning = true
                    }) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Capture Front Image")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                Spacer()
                
                // Complete button
                Button(action: {
                    onComplete()
                }) {
                    Text("Done")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding()
            .navigationTitle("Product Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $isFrontImageScanning) {
                IngredientScanSheet(
                    isPresented: $isFrontImageScanning,
                    onImageCaptured: { image in
                        onFrontImageCaptured(image)
                        isFrontImageScanning = false
                    }
                )
            }
        }
    }
}



//
//  OCRScanner.swift
//  FoodScan
//
//  OCR scanner using Vision framework to extract text from ingredient labels
//

import Vision
import UIKit
import SwiftUI

// Service to perform OCR on images
class OCRScanner {
    // Extract text from a UIImage using Vision OCR with improved accuracy
    static func extractText(from image: UIImage, completion: @escaping (String?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }
        
        // Create a Vision request for text recognition
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation],
                  error == nil else {
                completion(nil)
                return
            }
            
            // Extract text with confidence scores, position, and line grouping
            var textBlocks: [(text: String, y: CGFloat, x: CGFloat)] = []
            
            for observation in observations {
                // Get top candidate with highest confidence
                if let topCandidate = observation.topCandidates(1).first,
                   topCandidate.confidence > 0.5 { // Only accept high-confidence text
                    let text = topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        // Get bounding box to sort by position
                        let boundingBox = observation.boundingBox
                        textBlocks.append((
                            text: text,
                            y: 1.0 - boundingBox.midY, // Invert Y for top-to-bottom
                            x: boundingBox.midX
                        ))
                    }
                }
            }
            
            // Sort by Y position (top to bottom), then by X (left to right) for same line
            textBlocks.sort { 
                if abs($0.y - $1.y) < 0.02 { // Same line (within 2% tolerance)
                    return $0.x < $1.x // Sort left to right
                }
                return $0.y < $1.y // Sort top to bottom
            }
            
            // Group into lines and join properly
            var lines: [String] = []
            var currentLine: [String] = []
            var lastY: CGFloat = -1
            
            for block in textBlocks {
                if abs(block.y - lastY) > 0.02 { // New line
                    if !currentLine.isEmpty {
                        lines.append(currentLine.joined(separator: " "))
                        currentLine = []
                    }
                    lastY = block.y
                }
                currentLine.append(block.text)
            }
            
            // Add last line
            if !currentLine.isEmpty {
                lines.append(currentLine.joined(separator: " "))
            }
            
            // Join lines with newlines to preserve structure
            var fullText = lines.joined(separator: "\n")
            
            // Clean up common OCR errors
            fullText = cleanOCRText(fullText)
            
            completion(fullText.isEmpty ? nil : fullText)
        }
        
        // Configure for accurate recognition (slower but more accurate)
        request.recognitionLevel = .accurate
        // Prioritize common languages for ingredient labels
        request.recognitionLanguages = ["en-US", "en-GB", "es", "fr", "de", "it", "pt", "zh-Hans", "ja", "ko", "vi", "th", "hi"]
        request.usesLanguageCorrection = true // Enable language correction
        
        // Perform the request
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(nil)
            }
        }
    }
    
    // Clean common OCR errors
    private static func cleanOCRText(_ text: String) -> String {
        var cleaned = text
        
        // Remove excessive whitespace
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // Fix common ingredient list formatting
        cleaned = cleaned.replacingOccurrences(of: ",\\s*,", with: ",", options: .regularExpression) // Double commas
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// SwiftUI view wrapper for camera to capture ingredient labels
struct IngredientCameraView: UIViewControllerRepresentable {
    var onImageCaptured: (UIImage) -> Void
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onImageCaptured: onImageCaptured, isPresented: $isPresented)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var onImageCaptured: (UIImage) -> Void
        @Binding var isPresented: Bool
        
        init(onImageCaptured: @escaping (UIImage) -> Void, isPresented: Binding<Bool>) {
            self.onImageCaptured = onImageCaptured
            self._isPresented = isPresented
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImageCaptured(image)
            }
            isPresented = false
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            isPresented = false
        }
    }
}



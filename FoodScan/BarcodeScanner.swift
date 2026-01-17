//
//  BarcodeScanner.swift
//  FoodScan
//
//  Barcode scanner using AVFoundation to scan EAN/UPC barcodes
//

import AVFoundation
import SwiftUI

// Coordinator to handle AVCaptureMetadataOutputDelegate
class BarcodeScannerCoordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    var parent: BarcodeScannerView
    var onBarcodeScanned: (String) -> Void
    var captureSession: AVCaptureSession?
    
    init(parent: BarcodeScannerView, onBarcodeScanned: @escaping (String) -> Void) {
        self.parent = parent
        self.onBarcodeScanned = onBarcodeScanned
    }
    
    // Called when a barcode is detected
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // Find the first barcode object
        if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
           let barcodeString = metadataObject.stringValue {
            // Check if it's EAN/UPC format
            if metadataObject.type == .ean13 || metadataObject.type == .ean8 || metadataObject.type == .upce {
                // Stop scanning and return the barcode
                captureSession?.stopRunning()
                parent.stopScanning()
                onBarcodeScanned(barcodeString)
            }
        }
    }
}

// SwiftUI view wrapper for barcode scanning
struct BarcodeScannerView: UIViewControllerRepresentable {
    var onBarcodeScanned: (String) -> Void
    @Binding var isScanning: Bool
    
    func makeCoordinator() -> BarcodeScannerCoordinator {
        BarcodeScannerCoordinator(parent: self, onBarcodeScanned: onBarcodeScanned)
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        let captureSession = AVCaptureSession()
        
        // Get the back camera
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            return viewController
        }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return viewController
        }
        
        // Add input to session
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            return viewController
        }
        
        // Create metadata output for barcode detection
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            // Set delegate and metadata types (EAN/UPC)
            metadataOutput.setMetadataObjectsDelegate(context.coordinator, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean13, .ean8, .upce]
        } else {
            return viewController
        }
        
        // Create preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = viewController.view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        viewController.view.layer.addSublayer(previewLayer)
        
        // Store session in coordinator
        context.coordinator.captureSession = captureSession
        
        // Update preview layer frame when view appears
        DispatchQueue.main.async {
            previewLayer.frame = viewController.view.layer.bounds
        }
        
        // Start session on background queue
        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
        }
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Update preview layer frame if needed
        if let previewLayer = uiViewController.view.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiViewController.view.layer.bounds
        }
    }
    
    func stopScanning() {
        isScanning = false
    }
}


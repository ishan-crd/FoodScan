//
//  ContentView.swift
//  FoodScan
//
//  Main content view with tab navigation
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Scan Tab
            ScanView()
                .tabItem {
                    Label("Scan", systemImage: "barcode.viewfinder")
                }
                .tag(0)
            
            // History Tab
            ProductHistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(1)
        }
    }
}

// View to show scanned products history
struct ProductHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Product.lastScannedDate, order: .reverse) private var products: [Product]

    var body: some View {
        NavigationStack {
            if products.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "tray")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No scanned products yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Use the Scan tab to scan your first product")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                List {
                    ForEach(products) { product in
                        NavigationLink {
                            ProductDetailView(product: product)
                        } label: {
                            ProductRow(product: product)
                        }
                    }
                    .onDelete(perform: deleteProducts)
                }
                .navigationTitle("Scan History")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                }
            }
        }
    }

    private func deleteProducts(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(products[index])
            }
        }
    }
}

// Row view for product list
struct ProductRow: View {
    let product: Product
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.barcode)
                    .font(.headline)
                
                if let name = product.productName {
                    Text(name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Compact classification badge
                HStack(spacing: 4) {
                    Image(systemName: classificationIcon)
                        .font(.caption)
                        .foregroundColor(classificationColor)
                    Text(product.classification.rawValue)
                        .font(.caption)
                        .foregroundColor(classificationColor)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(classificationColor.opacity(0.1))
                .cornerRadius(6)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(product.lastScannedDate, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var classificationColor: Color {
        switch product.classification {
        case .vegan: return .green
        case .vegetarian: return .blue
        case .nonVegetarian: return .red
        case .possiblyNonVegetarian: return .orange
        }
    }
    
    private var classificationIcon: String {
        switch product.classification {
        case .vegan: return "leaf.fill"
        case .vegetarian: return "leaf"
        case .nonVegetarian: return "exclamationmark.triangle.fill"
        case .possiblyNonVegetarian: return "questionmark.circle.fill"
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Product.self, inMemory: true)
}

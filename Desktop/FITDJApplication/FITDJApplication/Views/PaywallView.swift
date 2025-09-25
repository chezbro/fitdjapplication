//
//  PaywallView.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import SwiftUI
import StoreKit
import Combine

// S-008: Paywall with subscription options
struct PaywallView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var subscriptionManager = SubscriptionManager()
    @State private var showingError = false
    @State private var selectedProduct: Product?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.yellow)
                        
                        Text("Unlock Premium")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Get unlimited access to all workouts, premium features, and exclusive content.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    
                    // Features list
                    VStack(spacing: 16) {
                        FeatureRow(
                            icon: "infinity",
                            title: "Unlimited Workouts",
                            description: "Access to all workout routines and new releases"
                        )
                        
                        FeatureRow(
                            icon: "music.note",
                            title: "Premium Music Integration",
                            description: "Advanced Spotify features and custom playlists"
                        )
                        
                        FeatureRow(
                            icon: "brain.head.profile",
                            title: "AI Trainer",
                            description: "Personalized workout guidance and motivation"
                        )
                        
                        FeatureRow(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Advanced Analytics",
                            description: "Detailed progress tracking and insights"
                        )
                        
                        FeatureRow(
                            icon: "bell.badge",
                            title: "Smart Reminders",
                            description: "Intelligent workout scheduling and notifications"
                        )
                    }
                    .padding(.horizontal)
                    
                    // Subscription options
                    if !subscriptionManager.products.isEmpty {
                        VStack(spacing: 16) {
                            Text("Choose Your Plan")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            ForEach(subscriptionManager.products, id: \.id) { product in
                                SubscriptionOptionView(
                                    product: product,
                                    isSelected: selectedProduct?.id == product.id
                                ) {
                                    selectedProduct = product
                                }
                            }
                        }
                        .padding(.horizontal)
                    } else if subscriptionManager.isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading subscription options...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 40)
                    }
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        if let product = selectedProduct {
                            Button(action: {
                                Task {
                                    let success = await subscriptionManager.purchase(product)
                                    if success {
                                        dismiss()
                                    }
                                }
                            }) {
                                HStack {
                                    if subscriptionManager.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Text("Start Premium")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(subscriptionManager.isLoading)
                        }
                        
                        Button(action: {
                            Task {
                                let success = await subscriptionManager.restorePurchases()
                                if success {
                                    dismiss()
                                }
                            }
                        }) {
                            Text("Restore Purchases")
                                .font(.subheadline)
                                .foregroundColor(.accentColor)
                        }
                        .disabled(subscriptionManager.isLoading)
                    }
                    .padding(.horizontal)
                    
                    // Terms and privacy
                    VStack(spacing: 8) {
                        Text("By subscribing, you agree to our Terms of Service and Privacy Policy. Subscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Text("7-day free trial • Cancel anytime")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.accentColor)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(subscriptionManager.errorMessage ?? "An error occurred")
            }
            .onChange(of: subscriptionManager.errorMessage) { _, errorMessage in
                showingError = errorMessage != nil
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct SubscriptionOptionView: View {
    let product: Product
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(getPlanTitle())
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Text(product.displayPrice)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                    }
                    
                    Text(getPlanDescription())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if isYearlyPlan() {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            Text("Best Value - Save 45%")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.yellow)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.yellow.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .padding()
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func getPlanTitle() -> String {
        if isYearlyPlan() {
            return "Annual Plan"
        } else {
            return "Monthly Plan"
        }
    }
    
    private func getPlanDescription() -> String {
        if isYearlyPlan() {
            return "Billed annually • $8.25/month"
        } else {
            return "Billed monthly • $14.99/month"
        }
    }
    
    private func isYearlyPlan() -> Bool {
        return product.id.contains("yearly")
    }
}

#Preview {
    PaywallView()
        .environmentObject(AuthenticationManager())
}

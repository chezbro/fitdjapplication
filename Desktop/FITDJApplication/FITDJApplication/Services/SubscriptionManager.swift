//
//  SubscriptionManager.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import Foundation
import Combine
import StoreKit

// F-009: Subscription Paywall functionality
@MainActor
class SubscriptionManager: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var products: [Product] = []
    
    private let userDefaults = UserDefaults.standard
    private let subscriptionKey = "subscriptionStatus"
    
    // Subscription product IDs
    private let monthlyProductID = "fitdj_monthly_premium"
    private let yearlyProductID = "fitdj_yearly_premium"
    
    init() {
        Task {
            await loadProducts()
        }
    }
    
    // Load available subscription products
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let productIDs = [monthlyProductID, yearlyProductID]
            products = try await Product.products(for: productIDs)
            isLoading = false
        } catch {
            print("Failed to load products: \(error)")
            errorMessage = "Failed to load subscription options"
            isLoading = false
        }
    }
    
    // Purchase subscription
    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await updateSubscriptionStatus(for: product)
                    isLoading = false
                    return true
                case .unverified(_, let error):
                    print("Unverified transaction: \(error)")
                    errorMessage = "Purchase verification failed"
                    isLoading = false
                    return false
                }
            case .userCancelled:
                isLoading = false
                return false
            case .pending:
                errorMessage = "Purchase is pending approval"
                isLoading = false
                return false
            @unknown default:
                errorMessage = "Unknown purchase result"
                isLoading = false
                return false
            }
        } catch {
            print("Purchase failed: \(error)")
            errorMessage = "Purchase failed. Please try again."
            isLoading = false
            return false
        }
    }
    
    // Update subscription status in user profile
    private func updateSubscriptionStatus(for product: Product) async {
        guard let userProfile = getCurrentUserProfile() else { return }
        
        var updatedProfile = userProfile
        updatedProfile.subscriptionStatus = .active
        updatedProfile.subscriptionStartDate = Date()
        
        // Set subscription end date based on product
        if product.id == monthlyProductID {
            updatedProfile.subscriptionEndDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())
        } else if product.id == yearlyProductID {
            updatedProfile.subscriptionEndDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())
        }
        
        saveUserProfile(updatedProfile)
    }
    
    // Update subscription status from transaction (for restore purchases)
    private func updateSubscriptionStatusFromTransaction(_ transaction: Transaction) async {
        guard let userProfile = getCurrentUserProfile() else { return }
        
        var updatedProfile = userProfile
        updatedProfile.subscriptionStatus = .active
        updatedProfile.subscriptionStartDate = transaction.purchaseDate
        updatedProfile.subscriptionEndDate = transaction.expirationDate
        
        saveUserProfile(updatedProfile)
    }
    
    // Check if user has active subscription or valid trial
    func hasAccess() -> Bool {
        guard let userProfile = getCurrentUserProfile() else { return false }
        
        switch userProfile.subscriptionStatus {
        case .active:
            // Check if subscription is still valid
            if let endDate = userProfile.subscriptionEndDate {
                return endDate > Date()
            }
            return false
            
        case .trial:
            // Check if trial is still valid
            if let endDate = userProfile.trialEndDate {
                return endDate > Date()
            }
            return false
            
        case .expired, .cancelled:
            return false
        }
    }
    
    // Get days remaining in trial
    func getTrialDaysRemaining() -> Int {
        guard let userProfile = getCurrentUserProfile(),
              userProfile.subscriptionStatus == .trial,
              let endDate = userProfile.trialEndDate else { return 0 }
        
        let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0
        return max(0, daysRemaining)
    }
    
    // Get subscription status info
    func getSubscriptionInfo() -> (status: SubscriptionStatus, daysRemaining: Int, isActive: Bool) {
        guard let userProfile = getCurrentUserProfile() else {
            return (.expired, 0, false)
        }
        
        let daysRemaining = getTrialDaysRemaining()
        let isActive = hasAccess()
        
        return (userProfile.subscriptionStatus, daysRemaining, isActive)
    }
    
    // Restore purchases
    func restorePurchases() async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            try await AppStore.sync()
            // Check for active subscriptions
            for await result in Transaction.currentEntitlements {
                switch result {
                case .verified(let transaction):
                    if transaction.productType == .autoRenewable {
                        // Update subscription status based on transaction
                        await updateSubscriptionStatusFromTransaction(transaction)
                        isLoading = false
                        return true
                    }
                case .unverified(_, let error):
                    print("Unverified restoration: \(error)")
                }
            }
            
            errorMessage = "No active subscriptions found"
            isLoading = false
            return false
        } catch {
            print("Restore failed: \(error)")
            errorMessage = "Failed to restore purchases"
            isLoading = false
            return false
        }
    }
    
    // Helper methods to interact with user profile
    private func getCurrentUserProfile() -> UserProfile? {
        guard let data = userDefaults.data(forKey: "userProfile"),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return nil
        }
        return profile
    }
    
    private func saveUserProfile(_ profile: UserProfile) {
        do {
            let data = try JSONEncoder().encode(profile)
            userDefaults.set(data, forKey: "userProfile")
        } catch {
            print("Failed to save user profile: \(error)")
        }
    }
}

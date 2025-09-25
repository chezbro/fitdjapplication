//
//  AuthenticationManager.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import Foundation
import AuthenticationServices
import SwiftUI
import Combine

// F-001: Sign In functionality
@MainActor
class AuthenticationManager: NSObject, ObservableObject {
    @Published var userProfile: UserProfile?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let userDefaults = UserDefaults.standard
    private let userProfileKey = "userProfile"
    
    override init() {
        super.init()
        loadUserProfile()
    }
    
    // Save user profile to UserDefaults
    func saveUserProfile(_ profile: UserProfile) {
        do {
            let data = try JSONEncoder().encode(profile)
            userDefaults.set(data, forKey: userProfileKey)
            self.userProfile = profile
            self.isAuthenticated = true
        } catch {
            print("Failed to save user profile: \(error)")
            errorMessage = "Failed to save profile"
        }
    }
    
    // Load user profile from UserDefaults
    private func loadUserProfile() {
        guard let data = userDefaults.data(forKey: userProfileKey),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return
        }
        
        self.userProfile = profile
        self.isAuthenticated = true
    }
    
    // Sign out
    func signOut() {
        userDefaults.removeObject(forKey: userProfileKey)
        userProfile = nil
        isAuthenticated = false
        errorMessage = nil
    }
    
    // Handle sign in with Apple result
    func handleSignInWithAppleResult(_ result: Result<ASAuthorization, Error>) {
        isLoading = false
        
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let userID = appleIDCredential.user
                let email = appleIDCredential.email
                let fullName = appleIDCredential.fullName
                
                // Create or update user profile
                let profile = UserProfile(
                    id: userID,
                    email: email,
                    fullName: fullName?.formatted()
                )
                
                saveUserProfile(profile)
                errorMessage = nil
            }
        case .failure(let error):
            print("Sign in with Apple failed: \(error)")
            errorMessage = "Sign in failed. Please try again."
        }
    }
}

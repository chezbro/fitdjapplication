//
//  SignInView.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import SwiftUI

// S-001: Splash / Sign In Screen
struct SignInView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showError = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // App Logo and Title
            VStack(spacing: 20) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("FITDJ")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Your Personal Trainer with Music")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Sign In Button (Temporary - for testing)
            VStack(spacing: 16) {
                Button(action: {
                    authManager.isLoading = true
                    // Simulate sign in for testing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        let testProfile = UserProfile(
                            id: "test-user-123",
                            email: "test@example.com",
                            fullName: "Test User"
                        )
                        authManager.saveUserProfile(testProfile)
                    }
                }) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                        Text("Sign In (Test Mode)")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                .disabled(authManager.isLoading)
                
                if authManager.isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Signing in...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let errorMessage = authManager.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .alert("Sign In Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(authManager.errorMessage ?? "An unknown error occurred")
        }
        .onChange(of: authManager.errorMessage) { _, errorMessage in
            showError = errorMessage != nil
        }
    }
}

#Preview {
    SignInView()
}

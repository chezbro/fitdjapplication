//
//  SpotifyConnectView.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import SwiftUI

// S-003: Spotify Connect - Connect Spotify Premium
struct SpotifyConnectView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var spotifyManager = SpotifyManager()
    @State private var showingSkipAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 40) {
                Spacer()
                
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "music.note")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                    
                    Text("Connect Your Music")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Connect your Spotify Premium account to enjoy personalized workout music that matches your exercise intensity.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Benefits
                VStack(spacing: 16) {
                    BenefitRow(
                        icon: "waveform",
                        title: "Dynamic Music",
                        description: "Music automatically adjusts to your workout intensity"
                    )
                    
                    BenefitRow(
                        icon: "speaker.wave.2",
                        title: "Smart Ducking",
                        description: "Music volume lowers when trainer speaks"
                    )
                    
                    BenefitRow(
                        icon: "heart.fill",
                        title: "Personalized Playlists",
                        description: "Music curated based on your preferences"
                    )
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 16) {
                    if spotifyManager.isConnected {
                        ConnectedStateView(spotifyManager: spotifyManager)
                    } else {
                        ConnectButtonView(spotifyManager: spotifyManager)
                    }
                    
                    Button("Skip for Now") {
                        showingSkipAlert = true
                    }
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
            .navigationTitle("Music Setup")
            .navigationBarTitleDisplayMode(.inline)
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SpotifyAuthCallback"))) { notification in
                if let url = notification.object as? URL {
                    spotifyManager.handleAuthCallback(url: url)
                }
            }
            .onChange(of: spotifyManager.isConnected) { _, isConnected in
                if isConnected {
                    updateUserProfileWithSpotifyConnection()
                }
            }
            .alert("Skip Spotify Connection?", isPresented: $showingSkipAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Skip") {
                    skipSpotifyConnection()
                }
            } message: {
                Text("You can always connect Spotify later in settings. Workouts will still work without music.")
            }
            .alert("Spotify Error", isPresented: .constant(spotifyManager.errorMessage != nil)) {
                Button("OK") {
                    spotifyManager.errorMessage = nil
                }
            } message: {
                if let errorMessage = spotifyManager.errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    private func skipSpotifyConnection() {
        // Update user profile to indicate Spotify was skipped
        guard var profile = authManager.userProfile else { return }
        profile.isSpotifyConnected = false
        profile.hasSkippedSpotify = true
        authManager.saveUserProfile(profile)
    }
    
    private func updateUserProfileWithSpotifyConnection() {
        // Update user profile to indicate Spotify is connected
        guard var profile = authManager.userProfile else { return }
        profile.isSpotifyConnected = true
        authManager.saveUserProfile(profile)
    }
}

// MARK: - Subviews

struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.green)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

struct ConnectButtonView: View {
    @ObservedObject var spotifyManager: SpotifyManager
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: {
                spotifyManager.connectToSpotify()
            }) {
                HStack(spacing: 12) {
                    if spotifyManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "music.note")
                            .font(.title2)
                    }
                    
                    Text(spotifyManager.isLoading ? "Connecting..." : "Connect Spotify Premium")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.green)
                .cornerRadius(12)
            }
            .disabled(spotifyManager.isLoading)
            
            Text("Powered by Spotify")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct ConnectedStateView: View {
    @ObservedObject var spotifyManager: SpotifyManager
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connected to Spotify")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let displayName = spotifyManager.userDisplayName {
                        Text("Welcome, \(displayName)!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            Button("Disconnect") {
                spotifyManager.disconnectFromSpotify()
            }
            .foregroundColor(.red)
            .font(.subheadline)
        }
    }
}

#Preview {
    SpotifyConnectView()
        .environmentObject(AuthenticationManager())
}

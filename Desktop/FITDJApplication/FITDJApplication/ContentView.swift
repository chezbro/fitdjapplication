//
//  ContentView.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var subscriptionManager = SubscriptionManager()
    @State private var showingPaywall = false
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                if needsOnboarding {
                    OnboardingView()
                        .environmentObject(authManager)
                } else if needsSpotifyConnect {
                    SpotifyConnectView()
                        .environmentObject(authManager)
                } else if needsSubscription {
                    PaywallView()
                        .environmentObject(authManager)
                        .environmentObject(subscriptionManager)
                } else {
                    WorkoutLibraryView()
                        .environmentObject(authManager)
                        .environmentObject(subscriptionManager)
                }
            } else {
                SignInView()
                    .environmentObject(authManager)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: needsOnboarding)
        .animation(.easeInOut(duration: 0.3), value: needsSpotifyConnect)
        .animation(.easeInOut(duration: 0.3), value: needsSubscription)
        .onReceive(subscriptionManager.$products) { _ in
            // Refresh subscription status when products load
        }
    }
    
    private var needsOnboarding: Bool {
        guard let profile = authManager.userProfile else { return false }
        return profile.goals.isEmpty || profile.availableEquipment.isEmpty
    }
    
    private var needsSpotifyConnect: Bool {
        guard let profile = authManager.userProfile else { return false }
        // Show Spotify connect if onboarding is complete but Spotify isn't connected
        // and user hasn't explicitly skipped it
        return !needsOnboarding && !profile.isSpotifyConnected && !profile.hasSkippedSpotify
    }
    
    private var needsSubscription: Bool {
        guard authManager.userProfile != nil else { return false }
        // Show paywall if onboarding and Spotify are complete but user doesn't have subscription access
        return !needsOnboarding && !needsSpotifyConnect && !subscriptionManager.hasAccess()
    }
}

#Preview {
    ContentView()
}

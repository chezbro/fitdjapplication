//
//  FITDJApplicationApp.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import SwiftUI
import UserNotifications

@main
struct FITDJApplicationApp: App {
    @StateObject private var notificationService = NotificationService()
    @StateObject private var streakService = StreakService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(notificationService)
                .environmentObject(streakService)
                .onOpenURL { url in
                    // Handle Spotify callback URL
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SpotifyAuthCallback"),
                        object: url
                    )
                }
                .onAppear {
                    // Request notification permission on app launch
                    Task {
                        _ = await notificationService.requestPermission()
                        notificationService.setupNotificationCategories()
                    }
                }
        }
    }
}

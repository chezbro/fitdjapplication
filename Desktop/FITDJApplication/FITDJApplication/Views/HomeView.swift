//
//  HomeView.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var streakService: StreakService
    @EnvironmentObject var notificationService: NotificationService
    @StateObject private var progressService = ProgressTrackingService()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Welcome header with streak
                    WelcomeHeaderView(
                        userProfile: authManager.userProfile,
                        streakService: streakService
                    )
                    
                    // Quick stats cards
                    QuickStatsView(
                        progressService: progressService,
                        streakService: streakService
                    )
                    
                    // Motivation section
                    MotivationView(streakService: streakService)
                    
                    // Quick actions
                    QuickActionsView()
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("FITDJ")
            .onAppear {
                progressService.loadProgressData()
            }
        }
    }
}

// MARK: - Welcome Header
struct WelcomeHeaderView: View {
    let userProfile: UserProfile?
    @ObservedObject var streakService: StreakService
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome back!")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Hello, \(userProfile?.fullName ?? "User")!")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Streak display
                VStack(spacing: 4) {
                    Text(streakService.getStreakEmoji())
                        .font(.system(size: 40))
                        .streakGlowAnimation()
                    
                    Text("\(streakService.currentStreak)")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("day streak")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Streak motivation
            Text(streakService.getStreakMotivation())
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

// MARK: - Quick Stats
struct QuickStatsView: View {
    let progressService: ProgressTrackingService
    @ObservedObject var streakService: StreakService
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
            StatCard(
                title: "Total Workouts",
                value: "\(progressService.totalWorkouts)",
                icon: "dumbbell.fill"
            )
            
            StatCard(
                title: "Current Streak",
                value: "\(streakService.currentStreak)",
                icon: "flame.fill"
            )
            
            StatCard(
                title: "This Week",
                value: "\(progressService.weeklyWorkouts)",
                icon: "calendar"
            )
            
            StatCard(
                title: "Total Time",
                value: "\(progressService.totalMinutes) min",
                icon: "clock.fill"
            )
        }
    }
}


// MARK: - Motivation View
struct MotivationView: View {
    @ObservedObject var streakService: StreakService
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Keep Going! 💪")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("You're building an amazing habit. Every workout counts!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Next milestone
            if let nextMilestone = streakService.streakMilestones.first(where: { !$0.isUnlocked }) {
                HStack {
                    Text("Next milestone:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(nextMilestone.days) days")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.accentColor.opacity(0.1), Color.accentColor.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
    }
}

// MARK: - Quick Actions
struct QuickActionsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 16) {
                QuickActionButton(
                    title: "Start Workout",
                    icon: "play.circle.fill",
                    color: .green
                ) {
                    HapticService.shared.workoutStart()
                }
                
                QuickActionButton(
                    title: "View Library",
                    icon: "list.bullet",
                    color: .blue
                ) {
                    HapticService.shared.buttonTap()
                }
                
                QuickActionButton(
                    title: "Settings",
                    icon: "gear",
                    color: .gray
                ) {
                    HapticService.shared.buttonTap()
                }
            }
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthenticationManager())
        .environmentObject(StreakService())
        .environmentObject(NotificationService())
}

//
//  SettingsView.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import SwiftUI
import StoreKit

// S-009: Settings screen to manage Spotify, subscription, and progress
struct SettingsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var streakService: StreakService
    @StateObject private var spotifyManager = SpotifyManager()
    @StateObject private var progressService = ProgressTrackingService()
    
    @State private var showingSpotifyConnect = false
    @State private var showingSubscriptionManagement = false
    @State private var showingProgressDetails = false
    @State private var showingSignOutAlert = false
    @State private var showingReminderSettings = false
    
    var body: some View {
        NavigationView {
            List {
                // User Profile Section
                Section {
                    UserProfileSection(userProfile: authManager.userProfile)
                }
                
                // Spotify Section
                Section("Music") {
                    SpotifySection(
                        spotifyManager: spotifyManager,
                        onConnect: {
                            showingSpotifyConnect = true
                        },
                        onDisconnect: {
                            spotifyManager.disconnectFromSpotify()
                        }
                    )
                }
                
                // Subscription Section
                Section("Subscription") {
                    SubscriptionSection(
                        subscriptionManager: subscriptionManager,
                        onManage: {
                            showingSubscriptionManagement = true
                        }
                    )
                }
                
                // Progress Section
                Section("Progress") {
                    ProgressSection(
                        progressService: progressService,
                        onViewDetails: {
                            showingProgressDetails = true
                        }
                    )
                }
                
                // Streak Section
                Section("Streak") {
                    StreakSection(
                        streakService: streakService,
                        onViewMilestones: {
                            showingProgressDetails = true
                        }
                    )
                }
                
                // Notifications Section
                Section("Notifications") {
                    NotificationSection(
                        notificationService: notificationService,
                        onReminderSettings: {
                            showingReminderSettings = true
                        }
                    )
                }
                
                // App Settings Section
                Section("App Settings") {
                    AppSettingsSection()
                }
                
                // Support Section
                Section("Support") {
                    SupportSection()
                }
                
                // Sign Out Section
                Section {
                    SignOutSection(
                        onSignOut: {
                            showingSignOutAlert = true
                        }
                    )
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                progressService.loadProgressData()
            }
            .sheet(isPresented: $showingSpotifyConnect) {
                SpotifyConnectView()
                    .environmentObject(authManager)
            }
            .sheet(isPresented: $showingSubscriptionManagement) {
                SubscriptionManagementView()
                    .environmentObject(subscriptionManager)
            }
            .sheet(isPresented: $showingProgressDetails) {
                ProgressDetailsView()
                    .environmentObject(progressService)
            }
            .sheet(isPresented: $showingReminderSettings) {
                ReminderSettingsView()
                    .environmentObject(notificationService)
            }
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authManager.signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
}

// MARK: - User Profile Section
struct UserProfileSection: View {
    let userProfile: UserProfile?
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(userProfile?.fullName ?? "User")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if let email = userProfile?.email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text("Member since \(userProfile?.dateCreated.formatted(date: .abbreviated, time: .omitted) ?? "Unknown")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Spotify Section
struct SpotifySection: View {
    @ObservedObject var spotifyManager: SpotifyManager
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "music.note")
                .foregroundColor(.green)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                if spotifyManager.isConnected {
                    Text("Connected to Spotify")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    if let displayName = spotifyManager.userDisplayName {
                        Text("Account: \(displayName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Connect Spotify")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Text("Play your music during workouts")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if spotifyManager.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else if spotifyManager.isConnected {
                Button("Disconnect") {
                    onDisconnect()
                }
                .font(.caption)
                .foregroundColor(.red)
            } else {
                Button("Connect") {
                    onConnect()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
        
        if let errorMessage = spotifyManager.errorMessage {
            Text(errorMessage)
                .font(.caption)
                .foregroundColor(.red)
                .padding(.top, 4)
        }
    }
}

// MARK: - Subscription Section
struct SubscriptionSection: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    let onManage: () -> Void
    
    var body: some View {
        let (status, daysRemaining, _) = subscriptionManager.getSubscriptionInfo()
        
        HStack {
            Image(systemName: statusIcon(for: status))
                .foregroundColor(statusColor(for: status))
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(subscriptionTitle(for: status))
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(subscriptionDescription(for: status, daysRemaining: daysRemaining))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Manage") {
                onManage()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
    
    private func statusIcon(for status: SubscriptionStatus) -> String {
        switch status {
        case .trial:
            return "clock.fill"
        case .active:
            return "crown.fill"
        case .expired, .cancelled:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private func statusColor(for status: SubscriptionStatus) -> Color {
        switch status {
        case .trial:
            return .blue
        case .active:
            return .green
        case .expired, .cancelled:
            return .orange
        }
    }
    
    private func subscriptionTitle(for status: SubscriptionStatus) -> String {
        switch status {
        case .trial:
            return "Free Trial"
        case .active:
            return "Premium Active"
        case .expired:
            return "Subscription Expired"
        case .cancelled:
            return "Subscription Cancelled"
        }
    }
    
    private func subscriptionDescription(for status: SubscriptionStatus, daysRemaining: Int) -> String {
        switch status {
        case .trial:
            return "\(daysRemaining) days remaining"
        case .active:
            return "Unlimited workouts"
        case .expired:
            return "Upgrade to continue"
        case .cancelled:
            return "Reactivate subscription"
        }
    }
}

// MARK: - Progress Section
struct ProgressSection: View {
    @ObservedObject var progressService: ProgressTrackingService
    let onViewDetails: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .foregroundColor(.blue)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Workout Progress")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text("\(progressService.totalWorkouts) workouts completed")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("View Details") {
                onViewDetails()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
        
        // Quick stats
        HStack(spacing: 20) {
            StatItem(
                title: "This Week",
                value: "\(progressService.weeklyWorkouts)",
                icon: "calendar"
            )
            
            StatItem(
                title: "Current Streak",
                value: "\(progressService.currentStreak)",
                icon: "flame.fill"
            )
            
            StatItem(
                title: "Total Time",
                value: "\(progressService.totalMinutes) min",
                icon: "clock.fill"
            )
        }
        .padding(.top, 8)
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .font(.caption)
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - App Settings Section
struct AppSettingsSection: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    @AppStorage("autoPlayMusic") private var autoPlayMusic = true
    
    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(
                title: "Push Notifications",
                subtitle: "Workout reminders and updates",
                icon: "bell.fill",
                iconColor: .orange
            ) {
                Toggle("", isOn: $notificationsEnabled)
                    .labelsHidden()
            }
            
            SettingsRow(
                title: "Dark Mode",
                subtitle: "Always use dark theme",
                icon: "moon.fill",
                iconColor: .purple
            ) {
                Toggle("", isOn: $darkModeEnabled)
                    .labelsHidden()
            }
            
            SettingsRow(
                title: "Auto-play Music",
                subtitle: "Start music automatically",
                icon: "play.circle.fill",
                iconColor: .green
            ) {
                Toggle("", isOn: $autoPlayMusic)
                    .labelsHidden()
            }
        }
    }
}

// MARK: - Support Section
struct SupportSection: View {
    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(
                title: "Help Center",
                subtitle: "Get help with the app",
                icon: "questionmark.circle.fill",
                iconColor: .blue
            ) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            
            SettingsRow(
                title: "Contact Support",
                subtitle: "Send us a message",
                icon: "envelope.fill",
                iconColor: .green
            ) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            
            SettingsRow(
                title: "Rate App",
                subtitle: "Share your feedback",
                icon: "star.fill",
                iconColor: .yellow
            ) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            
            SettingsRow(
                title: "Privacy Policy",
                subtitle: "How we protect your data",
                icon: "hand.raised.fill",
                iconColor: .red
            ) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            
            SettingsRow(
                title: "Terms of Service",
                subtitle: "App usage terms",
                icon: "doc.text.fill",
                iconColor: .gray
            ) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
    }
}

// MARK: - Sign Out Section
struct SignOutSection: View {
    let onSignOut: () -> Void
    
    var body: some View {
        Button(action: onSignOut) {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .foregroundColor(.red)
                    .font(.title2)
                
                Text("Sign Out")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.red)
                
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Settings Row Component
struct SettingsRow<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let content: () -> Content
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.title2)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            content()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Subscription Management View
struct SubscriptionManagementView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Current subscription status
                SubscriptionStatusCard(subscriptionManager: subscriptionManager)
                
                // Available plans
                if !subscriptionManager.products.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Available Plans")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        ForEach(subscriptionManager.products, id: \.id) { product in
                            SubscriptionPlanCard(
                                product: product,
                                onPurchase: {
                                    Task {
                                        await subscriptionManager.purchase(product)
                                    }
                                }
                            )
                        }
                    }
                }
                
                // Restore purchases
                Button("Restore Purchases") {
                    Task {
                        await subscriptionManager.restorePurchases()
                    }
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SubscriptionStatusCard: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    
    var body: some View {
        let (status, daysRemaining, _) = subscriptionManager.getSubscriptionInfo()
        
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: status == .active ? "crown.fill" : "clock.fill")
                    .foregroundColor(status == .active ? .yellow : .blue)
                
                Text(status == .active ? "Premium Active" : "Free Trial")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Text(statusDescription(for: status, daysRemaining: daysRemaining))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func statusDescription(for status: SubscriptionStatus, daysRemaining: Int) -> String {
        switch status {
        case .trial:
            return "\(daysRemaining) days remaining in your free trial"
        case .active:
            return "You have unlimited access to all workouts"
        case .expired:
            return "Your subscription has expired. Upgrade to continue."
        case .cancelled:
            return "Your subscription was cancelled. Reactivate to continue."
        }
    }
}

struct SubscriptionPlanCard: View {
    let product: Product
    let onPurchase: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(product.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(product.displayPrice)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.accentColor)
            }
            
            Text(product.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button("Subscribe") {
                onPurchase()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

// MARK: - Progress Details View
struct ProgressDetailsView: View {
    @EnvironmentObject var progressService: ProgressTrackingService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Overall stats
                    ProgressStatsCard(progressService: progressService)
                    
                    // Weekly progress
                    WeeklyProgressCard(progressService: progressService)
                    
                    // Recent workouts
                    RecentWorkoutsCard(progressService: progressService)
                }
                .padding()
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ProgressStatsCard: View {
    @ObservedObject var progressService: ProgressTrackingService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Overall Progress")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                ProgressStat(
                    title: "Total Workouts",
                    value: "\(progressService.totalWorkouts)",
                    icon: "dumbbell.fill"
                )
                
                ProgressStat(
                    title: "Total Time",
                    value: "\(progressService.totalMinutes) min",
                    icon: "clock.fill"
                )
                
                ProgressStat(
                    title: "Current Streak",
                    value: "\(progressService.currentStreak)",
                    icon: "flame.fill"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ProgressStat: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .font(.title2)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct WeeklyProgressCard: View {
    @ObservedObject var progressService: ProgressTrackingService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("\(progressService.weeklyWorkouts) workouts completed")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Simple progress bar
            ProgressView(value: Double(progressService.weeklyWorkouts), total: 7.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct RecentWorkoutsCard: View {
    @ObservedObject var progressService: ProgressTrackingService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Workouts")
                .font(.headline)
                .fontWeight(.semibold)
            
            if progressService.recentWorkouts.isEmpty {
                Text("No workouts completed yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(Array(progressService.recentWorkouts.prefix(3)), id: \.id) { workout in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(workout.workoutName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(workout.completedAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("\(Int(workout.duration / 60)) min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Streak Section
struct StreakSection: View {
    @ObservedObject var streakService: StreakService
    let onViewMilestones: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "flame.fill")
                .foregroundColor(.orange)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Streak")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text("\(streakService.currentStreak) days")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(streakService.getStreakEmoji())
                    .font(.title2)
                
                Text(streakService.getStreakMotivation())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.vertical, 4)
        
        // Streak milestones preview
        if !streakService.streakMilestones.isEmpty {
            HStack(spacing: 12) {
                ForEach(streakService.streakMilestones.prefix(3), id: \.id) { milestone in
                    VStack(spacing: 4) {
                        Text(milestone.emoji)
                            .font(.title3)
                            .opacity(milestone.isUnlocked ? 1.0 : 0.3)
                        
                        Text("\(milestone.days)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .opacity(milestone.isUnlocked ? 1.0 : 0.3)
                    }
                }
                
                Spacer()
                
                Button("View All") {
                    onViewMilestones()
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Notification Section
struct NotificationSection: View {
    @ObservedObject var notificationService: NotificationService
    let onReminderSettings: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "bell.fill")
                .foregroundColor(.blue)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Workout Reminders")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(notificationService.isAuthorized ? "Enabled" : "Not authorized")
                    .font(.subheadline)
                    .foregroundColor(notificationService.isAuthorized ? .green : .orange)
            }
            
            Spacer()
            
            Button("Settings") {
                onReminderSettings()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
        
        if notificationService.isAuthorized {
            HStack {
                Text("Reminder time: \(notificationService.reminderTime.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Toggle("", isOn: $notificationService.isReminderEnabled)
                    .labelsHidden()
            }
            .padding(.top, 4)
        }
    }
}

// MARK: - Reminder Settings View
struct ReminderSettingsView: View {
    @EnvironmentObject var notificationService: NotificationService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if !notificationService.isAuthorized {
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text("Notifications Not Enabled")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Enable notifications to receive workout reminders and stay motivated!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Enable Notifications") {
                            Task {
                                await notificationService.requestPermission()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    VStack(alignment: .leading, spacing: 20) {
                        // Reminder time picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reminder Time")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            DatePicker("", selection: $notificationService.reminderTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel)
                                .onChange(of: notificationService.reminderTime) { _, newTime in
                                    notificationService.updateReminderTime(newTime)
                                }
                        }
                        
                        // Reminder toggle
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Daily Reminders")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Text("Get reminded to work out every day")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $notificationService.isReminderEnabled)
                                .labelsHidden()
                                .onChange(of: notificationService.isReminderEnabled) { _, enabled in
                                    notificationService.toggleReminder(enabled)
                                }
                        }
                        
                        // Additional notification options
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Additional Notifications")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Button("Schedule Motivational Messages") {
                                notificationService.scheduleMotivationalMessage()
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                            
                            Button("Schedule Streak Reminders") {
                                notificationService.scheduleStreakReminder()
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle("Reminder Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthenticationManager())
        .environmentObject(SubscriptionManager())
        .environmentObject(NotificationService())
        .environmentObject(StreakService())
}

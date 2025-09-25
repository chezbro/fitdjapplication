//
//  WorkoutLibraryView.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import SwiftUI

struct WorkoutLibraryView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @StateObject private var workoutService = WorkoutDataService()
    @State private var selectedDifficulty: WorkoutDifficulty?
    @State private var selectedMuscleGroup: MuscleGroup?
    @State private var showingFilters = false
    @State private var showingUserMenu = false
    @State private var showingPaywall = false
    @State private var selectedWorkout: Workout?
    @State private var showingWorkoutDetail = false
    @State private var showingSettings = false
    @State private var showingProgress = false
    
    var filteredWorkouts: [Workout] {
        var workouts = workoutService.workouts
        
        // Filter by user's available equipment
        if let profile = authManager.userProfile {
            workouts = workouts.filter { workout in
                workout.requiredEquipment.allSatisfy { required in
                    profile.availableEquipment.contains(required)
                }
            }
        }
        
        // Apply difficulty filter
        if let difficulty = selectedDifficulty {
            workouts = workouts.filter { $0.difficulty == difficulty }
        }
        
        // Apply muscle group filter
        if let muscleGroup = selectedMuscleGroup {
            workouts = workouts.filter { workout in
                workout.targetMuscleGroups.contains(muscleGroup)
            }
        }
        
        return workouts
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Workout Library")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            if let profile = authManager.userProfile {
                                Text("Hello, \(profile.fullName ?? "User")!")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 16) {
                            Button(action: { showingFilters.toggle() }) {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .font(.title2)
                                    .foregroundColor(.primary)
                            }
                            
                            Button(action: { showingUserMenu.toggle() }) {
                                Image(systemName: "person.circle")
                                    .font(.title2)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Subscription status banner
                    SubscriptionStatusBanner(
                        subscriptionManager: subscriptionManager,
                        onUpgrade: {
                            showingPaywall = true
                        }
                    )
                    
                    // Quick stats
                    HStack(spacing: 20) {
                        StatCard(
                            title: "Available",
                            value: "\(filteredWorkouts.count)",
                            icon: "dumbbell.fill"
                        )
                        
                        StatCard(
                            title: "This Week",
                            value: "0",
                            icon: "calendar"
                        )
                        
                        StatCard(
                            title: "Streak",
                            value: "0",
                            icon: "flame.fill"
                        )
                    }
                    .padding(.horizontal)
                }
                .background(Color(.systemBackground))
                
                // Filters (if showing)
                if showingFilters {
                    FilterView(
                        selectedDifficulty: $selectedDifficulty,
                        selectedMuscleGroup: $selectedMuscleGroup
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                
                // Workout List
                if workoutService.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading workouts...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if workoutService.errorMessage != nil {
                    ErrorView(
                        message: workoutService.errorMessage ?? "Workouts unavailable, try again later.",
                        onRetry: {
                            workoutService.refreshWorkouts()
                        }
                    )
                } else if filteredWorkouts.isEmpty {
                    EmptyStateView(
                        title: "No Workouts Found",
                        message: "Try adjusting your filters or equipment preferences.",
                        actionTitle: "Clear Filters",
                        action: {
                            selectedDifficulty = nil
                            selectedMuscleGroup = nil
                        }
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredWorkouts) { workout in
                                Button(action: {
                                    if subscriptionManager.hasAccess() {
                                        selectedWorkout = workout
                                        showingWorkoutDetail = true
                                    } else {
                                        showingPaywall = true
                                    }
                                }) {
                                    WorkoutCard(workout: workout)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
                
                Spacer()
            }
            .navigationBarHidden(true)
            .onAppear {
                if workoutService.workouts.isEmpty {
                    workoutService.loadWorkouts()
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
                    .environmentObject(authManager)
                    .environmentObject(subscriptionManager)
            }
            .sheet(isPresented: $showingWorkoutDetail) {
                if let workout = selectedWorkout {
                    WorkoutDetailView(workout: workout)
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(authManager)
                    .environmentObject(subscriptionManager)
                    .environmentObject(NotificationService())
                    .environmentObject(StreakService())
            }
            .sheet(isPresented: $showingProgress) {
                ProgressDetailsView()
                    .environmentObject(ProgressTrackingService())
            }
            .overlay(
                // User Menu Dropdown
                VStack {
                    if showingUserMenu {
                        UserMenuView(
                            userProfile: authManager.userProfile,
                            authManager: authManager,
                            subscriptionManager: subscriptionManager,
                            showingSettings: $showingSettings,
                            showingProgress: $showingProgress,
                            onSignOut: {
                                authManager.signOut()
                                showingUserMenu = false
                            },
                            onDismiss: {
                                showingUserMenu = false
                            }
                        )
                        .transition(.opacity.combined(with: .scale))
                        .zIndex(1)
                    }
                    Spacer()
                }
                .animation(.easeInOut(duration: 0.2), value: showingUserMenu)
            )
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct FilterView: View {
    @Binding var selectedDifficulty: WorkoutDifficulty?
    @Binding var selectedMuscleGroup: MuscleGroup?
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Filters")
                    .font(.headline)
                Spacer()
                Button("Clear All") {
                    selectedDifficulty = nil
                    selectedMuscleGroup = nil
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
            
            // Difficulty Filter
            VStack(alignment: .leading, spacing: 8) {
                Text("Difficulty")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    ForEach(WorkoutDifficulty.allCases, id: \.self) { difficulty in
                        FilterChip(
                            title: difficulty.rawValue,
                            isSelected: selectedDifficulty == difficulty,
                            color: difficulty.color
                        ) {
                            selectedDifficulty = selectedDifficulty == difficulty ? nil : difficulty
                        }
                    }
                }
            }
            
            // Muscle Group Filter
            VStack(alignment: .leading, spacing: 8) {
                Text("Target Area")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(MuscleGroup.allCases, id: \.self) { muscleGroup in
                        FilterChip(
                            title: muscleGroup.rawValue,
                            isSelected: selectedMuscleGroup == muscleGroup,
                            color: "blue"
                        ) {
                            selectedMuscleGroup = selectedMuscleGroup == muscleGroup ? nil : muscleGroup
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let color: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

struct WorkoutCard: View {
    let workout: Workout
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.leading)
                    
                    Text(workout.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    DifficultyBadge(difficulty: workout.difficulty)
                    Text("\(workout.duration) min")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
            
            // Stats
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("\(workout.estimatedCalories) cal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("\(workout.exercises.count) exercises")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "dumbbell.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text(workout.requiredEquipment.first?.rawValue ?? "No Equipment")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Target muscle groups
            if !workout.targetMuscleGroups.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(workout.targetMuscleGroups, id: \.self) { muscleGroup in
                            Text(muscleGroup.rawValue)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.2))
                                .foregroundColor(.accentColor)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct DifficultyBadge: View {
    let difficulty: WorkoutDifficulty
    
    var body: some View {
        Text(difficulty.rawValue)
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(difficultyColor.opacity(0.2))
            .foregroundColor(difficultyColor)
            .cornerRadius(8)
    }
    
    private var difficultyColor: Color {
        switch difficulty {
        case .beginner:
            return .green
        case .intermediate:
            return .orange
        case .advanced:
            return .red
        }
    }
}

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("Oops!")
                .font(.headline)
                .fontWeight(.bold)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Try Again", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(actionTitle, action: action)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct UserMenuView: View {
    let userProfile: UserProfile?
    let authManager: AuthenticationManager
    let subscriptionManager: SubscriptionManager
    @Binding var showingSettings: Bool
    @Binding var showingProgress: Bool
    let onSignOut: () -> Void
    let onDismiss: () -> Void
    @State private var showingSignOutAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // User info header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(userProfile?.fullName ?? "User")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if let email = userProfile?.email {
                            Text(email)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .background(Color(.systemGray6))
            
            Divider()
            
            // Menu options
            VStack(spacing: 0) {
                MenuButton(
                    title: "Settings",
                    icon: "gear",
                    action: {
                        showingSettings = true
                        onDismiss()
                    }
                )
                
                MenuButton(
                    title: "Progress",
                    icon: "chart.line.uptrend.xyaxis",
                    action: {
                        showingProgress = true
                        onDismiss()
                    }
                )
                
                MenuButton(
                    title: "Help & Support",
                    icon: "questionmark.circle",
                    action: {
                        // TODO: Navigate to help
                        onDismiss()
                    }
                )
                
                Divider()
                
                MenuButton(
                    title: "Sign Out",
                    icon: "rectangle.portrait.and.arrow.right",
                    isDestructive: true,
                    action: {
                        showingSignOutAlert = true
                    }
                )
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .frame(width: 280)
        .padding(.top, 60)
        .padding(.trailing, 16)
        .alert("Sign Out", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive, action: onSignOut)
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .onTapGesture {
            // Dismiss when tapping outside
        }
    }
}

struct MenuButton: View {
    let title: String
    let icon: String
    let isDestructive: Bool
    let action: () -> Void
    
    init(title: String, icon: String, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isDestructive = isDestructive
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(isDestructive ? .red : .primary)
                    .frame(width: 20)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(isDestructive ? .red : .primary)
                
                Spacer()
            }
            .padding()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SubscriptionStatusBanner: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    let onUpgrade: () -> Void
    
    var body: some View {
        let (status, daysRemaining, isActive) = subscriptionManager.getSubscriptionInfo()
        
        if !isActive {
            // Show upgrade banner for expired subscriptions
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Subscription Expired")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Upgrade to continue unlimited workouts")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Upgrade") {
                    onUpgrade()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(12)
            .padding(.horizontal)
        } else if status == .trial && daysRemaining <= 3 {
            // Show trial ending soon banner
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trial Ending Soon")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("\(daysRemaining) days left in your free trial")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Upgrade Now") {
                    onUpgrade()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding()
            .background(Color.accentColor.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(12)
            .padding(.horizontal)
        } else if status == .active {
            // Show premium badge
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundColor(.yellow)
                
                Text("Premium Active")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button("Manage") {
                    // TODO: Navigate to subscription management
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

#Preview {
    WorkoutLibraryView()
        .environmentObject(AuthenticationManager())
        .environmentObject(SubscriptionManager())
}

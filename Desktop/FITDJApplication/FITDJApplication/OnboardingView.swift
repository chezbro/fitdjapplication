//
//  OnboardingView.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import SwiftUI

// S-002: Onboarding - Choose goals, equipment, music preference
struct OnboardingView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var selectedGoals: Set<WorkoutGoal> = []
    @State private var selectedEquipment: Set<Equipment> = []
    @State private var selectedMusicPreference: MusicPreference = .highEnergy
    @State private var currentStep = 0
    
    private let totalSteps = 3
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Progress indicator
                ProgressView(value: Double(currentStep + 1), total: Double(totalSteps))
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .padding(.horizontal)
                
                // Step content
                TabView(selection: $currentStep) {
                    // Step 1: Goals
                    goalsStep
                        .tag(0)
                    
                    // Step 2: Equipment
                    equipmentStep
                        .tag(1)
                    
                    // Step 3: Music Preference
                    musicPreferenceStep
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
                
                // Navigation buttons
                HStack {
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation {
                                currentStep -= 1
                            }
                        }
                        .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    Button(currentStep == totalSteps - 1 ? "Complete" : "Next") {
                        if currentStep == totalSteps - 1 {
                            completeOnboarding()
                        } else {
                            withAnimation {
                                currentStep += 1
                            }
                        }
                    }
                    .foregroundColor(.white)
                    .frame(width: 120, height: 44)
                    .background(Color.blue)
                    .cornerRadius(8)
                    .disabled(currentStep == totalSteps - 1 && selectedGoals.isEmpty)
                }
                .padding(.horizontal, 40)
            }
            .padding()
            .navigationTitle("Welcome to FITDJ!")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - Step Views
    
    private var goalsStep: some View {
        VStack(spacing: 20) {
            Text("What are your fitness goals?")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text("Select all that apply")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(WorkoutGoal.allCases, id: \.self) { goal in
                    GoalCard(
                        goal: goal,
                        isSelected: selectedGoals.contains(goal)
                    ) {
                        if selectedGoals.contains(goal) {
                            selectedGoals.remove(goal)
                        } else {
                            selectedGoals.insert(goal)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var equipmentStep: some View {
        VStack(spacing: 20) {
            Text("What equipment do you have?")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text("Select all that apply")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(Equipment.allCases, id: \.self) { equipment in
                    EquipmentCard(
                        equipment: equipment,
                        isSelected: selectedEquipment.contains(equipment)
                    ) {
                        if selectedEquipment.contains(equipment) {
                            selectedEquipment.remove(equipment)
                        } else {
                            selectedEquipment.insert(equipment)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var musicPreferenceStep: some View {
        VStack(spacing: 30) {
            Text("What music gets you pumped?")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 16) {
                ForEach(MusicPreference.allCases, id: \.self) { preference in
                    MusicPreferenceCard(
                        preference: preference,
                        isSelected: selectedMusicPreference == preference
                    ) {
                        selectedMusicPreference = preference
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Actions
    
    private func completeOnboarding() {
        guard var profile = authManager.userProfile else { return }
        
        // Update profile with onboarding selections
        profile.goals = Array(selectedGoals)
        profile.availableEquipment = Array(selectedEquipment)
        profile.musicPreference = selectedMusicPreference
        
        // Save updated profile
        authManager.saveUserProfile(profile)
    }
}

// MARK: - Card Views

struct GoalCard: View {
    let goal: WorkoutGoal
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: goalIcon(for: goal))
                    .font(.title)
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(goal.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func goalIcon(for goal: WorkoutGoal) -> String {
        switch goal {
        case .weightLoss: return "figure.walk"
        case .muscleGain: return "figure.strengthtraining.traditional"
        case .endurance: return "figure.run"
        case .flexibility: return "figure.yoga"
        case .generalFitness: return "figure.mixed.cardio"
        }
    }
}

struct EquipmentCard: View {
    let equipment: Equipment
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: equipmentIcon(for: equipment))
                    .font(.title)
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(equipment.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func equipmentIcon(for equipment: Equipment) -> String {
        switch equipment {
        case .none: return "figure.walk"
        case .dumbbells: return "dumbbell.fill"
        case .resistanceBands: return "figure.flexibility"
        case .yogaMat: return "figure.yoga"
        case .kettlebells: return "figure.strengthtraining.traditional"
        case .pullUpBar: return "figure.climbing"
        case .fullGym: return "building.2.fill"
        }
    }
}

struct MusicPreferenceCard: View {
    let preference: MusicPreference
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: musicIcon(for: preference))
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(preference.rawValue)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(musicDescription(for: preference))
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func musicIcon(for preference: MusicPreference) -> String {
        switch preference {
        case .highEnergy: return "bolt.fill"
        case .mixed: return "music.note.list"
        case .calm: return "leaf.fill"
        }
    }
    
    private func musicDescription(for preference: MusicPreference) -> String {
        switch preference {
        case .highEnergy: return "Upbeat tracks to power through workouts"
        case .mixed: return "Variety of genres to keep things interesting"
        case .calm: return "Relaxing music for mindful movement"
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AuthenticationManager())
}

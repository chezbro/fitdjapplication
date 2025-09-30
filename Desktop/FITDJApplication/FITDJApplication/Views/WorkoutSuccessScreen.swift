//
//  WorkoutSuccessScreen.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import SwiftUI

struct WorkoutSuccessScreen: View {
    let workout: Workout
    let onReturnToLibrary: () -> Void
    
    var body: some View {
        ZStack {
            // Dark background for workout focus
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Success animation and message
                VStack(spacing: 30) {
                    // Animated checkmark
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 100))
                        .foregroundColor(.green)
                        .scaleEffect(1.0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: true)
                    
                    // Success message
                    VStack(spacing: 15) {
                        Text("Workout Complete!")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("You crushed it! Great job finishing \(workout.title)")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        // Workout stats
                        VStack(spacing: 10) {
                            Text("\(workout.exercises.count) exercises completed")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text("Duration: \(workout.duration) minutes")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.top, 10)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.1))
                )
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 20) {
                    // Return to library button
                    Button(action: onReturnToLibrary) {
                        Text("Return to Workout Library")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue)
                            )
                    }
                    
                    // Optional: Add a "Share Achievement" button
                    Button(action: {
                        // TODO: Implement share functionality
                        print("Share achievement tapped")
                    }) {
                        Text("Share Achievement")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 30)
        }
    }
}

#Preview {
    let sampleWorkout = Workout(
        id: "sample",
        title: "Quick Start Full Body",
        description: "Perfect for beginners!",
        duration: 15,
        difficulty: .beginner,
        requiredEquipment: [.none],
        exercises: [
            Exercise(
                id: "jumping-jacks",
                name: "Jumping Jacks",
                description: "Full body cardio exercise",
                duration: 30,
                restDuration: 10,
                muscleGroups: [.cardio, .fullBody],
                equipment: [.none],
                instructions: ["Stand with feet together", "Jump up spreading legs", "Raise arms overhead", "Return to starting position"]
            ),
            Exercise(
                id: "push-ups",
                name: "Push-ups",
                description: "Upper body strength exercise",
                duration: 20,
                restDuration: 15,
                muscleGroups: [.chest, .arms],
                equipment: [.none],
                instructions: ["Start in plank position", "Lower body to ground", "Push back up to starting position"]
            )
        ],
        targetMuscleGroups: [.fullBody, .cardio],
        estimatedCalories: 120
    )
    
    WorkoutSuccessScreen(
        workout: sampleWorkout,
        onReturnToLibrary: {}
    )
}

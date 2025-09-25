//
//  WorkoutDetailView.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import SwiftUI
import AVKit
import UIKit

struct WorkoutDetailView: View {
    let workout: Workout
    @Environment(\.presentationMode) var presentationMode
    @State private var showingWorkoutPlayer = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        // Share button
                        Button(action: {
                            // TODO: Implement share functionality
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    Text(workout.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(workout.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Preview Video Section
                if let previewVideoURL = workout.previewVideoURL {
                    PreviewVideoView(videoURL: previewVideoURL)
                        .padding(.horizontal)
                } else {
                    // Placeholder for video preview
                    PreviewVideoPlaceholder()
                        .padding(.horizontal)
                }
                
                // Workout Info Cards
                HStack(spacing: 12) {
                    InfoCard(
                        title: "Duration",
                        value: "\(workout.duration) min",
                        icon: "clock.fill"
                    )
                    
                    InfoCard(
                        title: "Difficulty",
                        value: workout.difficulty.rawValue,
                        icon: "chart.bar.fill"
                    )
                    
                    InfoCard(
                        title: "Calories",
                        value: "\(workout.estimatedCalories)",
                        icon: "flame.fill"
                    )
                }
                .padding(.horizontal)
                
                // Equipment Required
                VStack(alignment: .leading, spacing: 8) {
                    Text("Equipment Required")
                        .font(.headline)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    HStack(spacing: 8) {
                        ForEach(workout.requiredEquipment, id: \.self) { equipment in
                            Text(equipment.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.2))
                                .foregroundColor(.accentColor)
                                .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Target Muscle Groups
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target Areas")
                        .font(.headline)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    HStack(spacing: 8) {
                        ForEach(workout.targetMuscleGroups, id: \.self) { muscleGroup in
                            Text(muscleGroup.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Exercise List
                VStack(alignment: .leading, spacing: 12) {
                    Text("Exercises (\(workout.exercises.count))")
                        .font(.headline)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    ForEach(workout.exercises) { exercise in
                        ExerciseRow(exercise: exercise)
                    }
                }
                
                // Start Workout Button
                Button(action: {
                    showingWorkoutPlayer = true
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Workout")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showingWorkoutPlayer) {
            WorkoutPlayerView(workout: workout)
        }
    }
}

struct InfoCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

struct ExerciseRow: View {
    let exercise: Exercise
    
    var body: some View {
        HStack(spacing: 12) {
            // Exercise icon placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.systemGray5))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "figure.strengthtraining.traditional")
                        .foregroundColor(.secondary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(exercise.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("\(exercise.duration)s")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                    
                    if exercise.restDuration > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "pause.circle")
                                .font(.caption2)
                            Text("\(exercise.restDuration)s rest")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

// Preview Video Components
struct PreviewVideoView: View {
    let videoURL: String
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview")
                .font(.headline)
                .fontWeight(.bold)
            
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.systemGray5))
                    .aspectRatio(16/9, contentMode: .fit)
                
                if let player = player {
                    VideoPlayer(player: player)
                        .aspectRatio(16/9, contentMode: .fit)
                        .cornerRadius(12)
                        .onAppear {
                            player.play()
                            isPlaying = true
                        }
                        .onDisappear {
                            player.pause()
                            isPlaying = false
                        }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "play.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.accentColor)
                        
                        Text("Loading preview...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Play/Pause overlay
                Button(action: {
                    guard let player = player else { return }
                    if isPlaying {
                        player.pause()
                    } else {
                        player.play()
                    }
                    isPlaying.toggle()
                }) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                }
            }
        }
        .onAppear {
            setupPlayer()
        }
    }
    
    private func setupPlayer() {
        // For demo purposes, we'll create a placeholder
        // In a real app, you'd load the actual video URL
        guard let url = URL(string: videoURL) else { return }
        player = AVPlayer(url: url)
    }
}

struct PreviewVideoPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview")
                .font(.headline)
                .fontWeight(.bold)
            
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.systemGray5))
                    .aspectRatio(16/9, contentMode: .fit)
                
                VStack(spacing: 12) {
                    Image(systemName: "video.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.accentColor)
                    
                    Text("Preview video coming soon")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

#Preview {
    let sampleWorkout = Workout(
        id: "sample",
        title: "Quick Start Full Body",
        description: "Perfect for beginners! A 15-minute full-body workout that gets your heart pumping.",
        duration: 15,
        difficulty: WorkoutDifficulty.beginner,
        requiredEquipment: [Equipment.none],
        exercises: [
            Exercise(
                id: "jumping-jacks",
                name: "Jumping Jacks",
                description: "Full body cardio exercise",
                duration: 30,
                restDuration: 10,
                muscleGroups: [MuscleGroup.cardio, MuscleGroup.fullBody],
                equipment: [Equipment.none],
                instructions: ["Stand with feet together", "Jump up spreading legs", "Raise arms overhead", "Return to starting position"]
            )
        ],
        targetMuscleGroups: [MuscleGroup.fullBody, MuscleGroup.cardio],
        estimatedCalories: 120
    )
    
    WorkoutDetailView(workout: sampleWorkout)
}

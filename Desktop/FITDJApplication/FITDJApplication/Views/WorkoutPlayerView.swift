//
//  WorkoutPlayerView.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import SwiftUI
import AVKit
import Combine

// S-006: Workout Player - Play workout with timers, exercise videos, trainer voice, and Spotify music
struct WorkoutPlayerView: View {
    let workout: Workout
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var voiceManager = VoiceManager()
    @StateObject private var spotifyManager = SpotifyManager()
    @StateObject private var musicManager: WorkoutMusicManager
    @StateObject private var cueManager: WorkoutCueManager
    @State private var showingExitAlert = false
    @State private var showingWorkoutComplete = false
    @State private var currentIntensity: WorkoutIntensity = .normal
    @State private var workoutStartTime: Date?
    @State private var completedExercises: Int = 0
    
    // Timer for exercise countdown
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    init(workout: Workout) {
        self.workout = workout
        let spotifyManager = SpotifyManager()
        self._musicManager = StateObject(wrappedValue: WorkoutMusicManager(spotifyManager: spotifyManager))
        self._spotifyManager = StateObject(wrappedValue: spotifyManager)
        let voiceManager = VoiceManager()
        self._voiceManager = StateObject(wrappedValue: voiceManager)
        self._cueManager = StateObject(wrappedValue: WorkoutCueManager(voiceManager: voiceManager))
    }
    
    var currentExercise: Exercise? {
        return cueManager.currentExercise
    }
    
    var progress: Double {
        guard !workout.exercises.isEmpty else { return 0 }
        return Double(cueManager.currentExerciseIndex) / Double(workout.exercises.count)
    }
    
    var timeRemaining: Int {
        return cueManager.timeRemainingInCurrentExercise
    }
    
    var isPlaying: Bool {
        return cueManager.isActive && !musicManager.isPaused
    }
    
    var isPaused: Bool {
        return cueManager.isPaused
    }
    
    var body: some View {
        ZStack {
            // Dark background for workout focus
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header with progress and exit
                HStack {
                    Button(action: {
                        print("❌ Exit button tapped")
                        DispatchQueue.main.async {
                            showingExitAlert = true
                            print("❌ showingExitAlert = \(showingExitAlert)")
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Text("Exercise \(cueManager.currentExerciseIndex + 1) of \(workout.exercises.count)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .white))
                            .frame(width: 120)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        if isPaused {
                            resumeWorkout()
                        } else {
                            pauseWorkout()
                        }
                    }) {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                Spacer()
                
                // Exercise video area
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(16/9, contentMode: .fit)
                        .overlay(
                            VStack {
                                if let exercise = currentExercise {
                                    Image(systemName: "figure.strengthtraining.traditional")
                                        .font(.system(size: 80))
                                        .foregroundColor(.white.opacity(0.6))
                                    
                                    Text(exercise.name)
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                    
                                    Text(exercise.description)
                                        .font(.body)
                                        .foregroundColor(.white.opacity(0.8))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                } else {
                                    Text("Workout Complete!")
                                        .font(.largeTitle)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                            }
                        )
                    
                    // Timer overlay
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("\(timeRemaining)")
                                .font(.system(size: 60, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(15)
                            Spacer()
                        }
                        .padding(.bottom, 20)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Controls
                VStack(spacing: 20) {
                    // Exercise instructions
                    if let exercise = currentExercise {
                        Text(exercise.instructions.first ?? "Follow the video demonstration")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Control buttons
                    HStack(spacing: 40) {
                        Button(action: {
                            adjustIntensity(easier: true)
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.green)
                                
                                Text("Easier")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        }
                        
                        Button(action: {
                            if isPaused {
                                resumeWorkout()
                            } else {
                                pauseWorkout()
                            }
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: isPaused ? "play.circle.fill" : "pause.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white)
                                
                                Text(isPaused ? "Resume" : "Pause")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        }
                        
                        Button(action: {
                            adjustIntensity(easier: false)
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.red)
                                
                                Text("Harder")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .swipeToGoBack {
            showingExitAlert = true
        }
        .onReceive(timer) { _ in
            // Timer is handled by WorkoutCueManager
            if timeRemaining <= 0 && cueManager.isActive {
                completedExercises += 1
                cueManager.nextExercise()
            }
            
            // Check if workout is complete
            if !cueManager.isActive && workoutStartTime != nil && !showingWorkoutComplete {
                showingWorkoutComplete = true
            }
        }
        .onAppear {
            startWorkout()
        }
        .onDisappear {
            stopWorkout()
        }
        .alert("Exit Workout", isPresented: $showingExitAlert) {
            Button("Continue Workout", role: .cancel) { 
                print("✅ Continue Workout button tapped")
                showingExitAlert = false
            }
            Button("Exit Workout", role: .destructive) {
                print("❌ Exit Workout button tapped")
                showingExitAlert = false
                DispatchQueue.main.async {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to exit? Your progress will be saved.")
        }
        .sheet(isPresented: $showingWorkoutComplete) {
            WorkoutCompleteView(
                workout: workout,
                duration: -(workoutStartTime?.timeIntervalSinceNow ?? 0),
                exercisesCompleted: completedExercises,
                intensity: currentIntensity,
                onReturnToLibrary: {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
    
    private func startWorkout() {
        print("🏃 Starting workout: \(workout.title)")
        
        // Record workout start time
        workoutStartTime = Date()
        completedExercises = 0
        
        // Ensure services are properly initialized before starting
        // Add a small delay to allow services to fully initialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Start the workout with cue manager
            self.cueManager.startWorkout(self.workout)
            
            // Start music with user preference (defaulting to high energy for now)
            // This will gracefully handle Spotify not being connected
            self.musicManager.startWorkoutMusic(for: self.workout, userPreference: .highEnergy)
            
            print("✅ Workout started successfully")
        }
    }
    
    private func pauseWorkout() {
        print("⏸️ Pausing workout")
        cueManager.pauseWorkout()
        musicManager.pauseMusic()
        print("⏸️ Pause state: \(cueManager.isPaused)")
    }
    
    private func resumeWorkout() {
        print("▶️ Resuming workout")
        cueManager.resumeWorkout()
        musicManager.resumeMusic()
        print("▶️ Pause state: \(cueManager.isPaused)")
    }
    
    private func stopWorkout() {
        cueManager.stopWorkout()
        musicManager.stopMusic()
    }
    
    private func adjustIntensity(easier: Bool) {
        // Adjust workout intensity
        cueManager.adjustIntensity(easier: easier)
        musicManager.adjustIntensity(easier: easier, currentWorkout: workout)
        
        // Update current intensity state
        if easier {
            currentIntensity = currentIntensity.decrease()
        } else {
            currentIntensity = currentIntensity.increase()
        }
    }
}

#Preview {
    let sampleWorkout = Workout(
        id: "sample",
        title: "Quick Start Full Body",
        description: "Perfect for beginners! A 15-minute full-body workout that gets your heart pumping.",
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
    
    WorkoutPlayerView(workout: sampleWorkout)
}

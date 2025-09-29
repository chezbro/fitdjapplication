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
    @State private var workoutHasActuallyStarted: Bool = false
    @State private var isInDescriptionPhase: Bool = true
    
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
            // Only process workout logic if we're not in description phase
            guard !isInDescriptionPhase else {
                print("🏃 Still in description phase, skipping workout logic")
                return
            }
            
            // Timer is handled by WorkoutCueManager
            if timeRemaining <= 0 && cueManager.isActive && workoutHasActuallyStarted {
                completedExercises += 1
                cueManager.nextExercise()
            }
            
            // Debug logging to understand what's happening
            if workoutHasActuallyStarted {
                print("🏃 Workout state: active=\(cueManager.isActive), exercise=\(cueManager.currentExerciseIndex)/\(workout.exercises.count), completed=\(completedExercises)")
            }
            
            // Check if workout is complete - only if we've completed all exercises
            if workoutHasActuallyStarted && 
               completedExercises >= workout.exercises.count && 
               !showingWorkoutComplete {
                print("🏃 Workout completed! Exercises: \(completedExercises)/\(workout.exercises.count)")
                showingWorkoutComplete = true
            }
            
            // Debug: Log completion check conditions
            if workoutHasActuallyStarted && completedExercises > 0 {
                print("🏃 Completion check: started=\(workoutHasActuallyStarted), completed=\(completedExercises)/\(workout.exercises.count), showing=\(showingWorkoutComplete)")
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
        .sheet(isPresented: Binding(
            get: { showingWorkoutComplete && workoutHasActuallyStarted && !isInDescriptionPhase },
            set: { showingWorkoutComplete = $0 }
        )) {
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
        
        // Reset all workout state
        completedExercises = 0
        workoutHasActuallyStarted = false
        showingWorkoutComplete = false
        isInDescriptionPhase = true
        
        // Ensure services are properly initialized before starting
        // Add a small delay to allow services to fully initialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Start with exercise description first
            self.startWorkoutWithDescription()
        }
    }
    
    private func startWorkoutWithDescription() {
        print("🏃 Starting workout with exercise description")
        
        // Get the first exercise for description
        guard let firstExercise = workout.exercises.first else {
            print("❌ No exercises found in workout")
            return
        }
        
        // Create a comprehensive workout and exercise description
        let workoutDuration = workout.duration
        let exerciseCount = workout.exercises.count
        let difficulty = workout.difficulty.rawValue.capitalized
        
        let exerciseDescription = VoiceCue(
            id: "workout-start-description",
            text: "Welcome to \(workout.title)! This is a \(difficulty) level workout that will take about \(workoutDuration) minutes. We'll be doing \(exerciseCount) exercises, starting with \(firstExercise.name). \(firstExercise.instructions.first ?? "Follow the demonstration"). Get ready to begin!",
            timing: 0,
            type: .instruction
        )
        
        print("🏃 Describing workout: \(workout.title) with \(exerciseCount) exercises")
        cueManager.voiceManager.speakCue(exerciseDescription)
        
        // Start the actual workout after description completes
        // Use a timer to check when voice finishes
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.startActualWorkout()
        }
    }
    
    private func startActualWorkout() {
        print("🏃 Starting actual workout after description")
        
        // Add a brief transition cue before starting the actual workout
        let transitionCue = VoiceCue(
            id: "workout-transition",
            text: "Let's get started!",
            timing: 0,
            type: .motivation
        )
        cueManager.voiceManager.speakCue(transitionCue)
        
        // Start the actual workout after the transition cue completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // End description phase
            self.isInDescriptionPhase = false
            
            // Record the actual workout start time now
            self.workoutStartTime = Date()
            self.workoutHasActuallyStarted = true
            print("🏃 Workout timer started at: \(self.workoutStartTime!)")
            
            // Now start the workout with cue manager (this will start the first exercise)
            self.cueManager.startWorkout(self.workout)
            
            // Start music with user preference after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.musicManager.startWorkoutMusic(for: self.workout, userPreference: .highEnergy)
                print("🎵 Music started after exercise description and transition")
            }
        }
        
        print("✅ Workout started successfully")
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

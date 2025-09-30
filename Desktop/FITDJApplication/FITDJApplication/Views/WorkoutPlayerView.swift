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
    @State private var workoutHasActuallyStarted: Bool = false
    @State private var isInDescriptionPhase: Bool = true
    @State private var voiceCompletionObserver: NSObjectProtocol?
    @State private var showingVolumeControls: Bool = false
    @AppStorage("voiceVolume") private var storedVoiceVolume: Double = 1.0
    @AppStorage("musicVolume") private var storedMusicVolume: Double = 1.0
    
    // Timer for exercise countdown
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    init(workout: Workout) {
        self.workout = workout
        
        // Initialize services in proper order to avoid conflicts
        let voiceManager = VoiceManager()
        self._voiceManager = StateObject(wrappedValue: voiceManager)
        
        let spotifyManager = SpotifyManager()
        self._spotifyManager = StateObject(wrappedValue: spotifyManager)
        
        // Initialize music manager after voice manager to avoid audio session conflicts
        self._musicManager = StateObject(wrappedValue: WorkoutMusicManager(spotifyManager: spotifyManager))
        
        // Initialize cue manager last, after all dependencies are ready
        let cueManager = WorkoutCueManager(voiceManager: voiceManager)
        self._cueManager = StateObject(wrappedValue: cueManager)
    }
    
    var currentExercise: Exercise? {
        let exercise = cueManager.currentExercise
        if exercise == nil {
            print("🏃 WorkoutPlayerView: currentExercise is nil - isActive: \(cueManager.isActive), index: \(cueManager.currentExerciseIndex), completed: \(cueManager.completedExercises)")
        }
        return exercise
    }
    
    var progress: Double {
        guard !workout.exercises.isEmpty else { return 0 }
        // Show full progress when on the last exercise (currentExerciseIndex is 0-based)
        if cueManager.currentExerciseIndex >= workout.exercises.count - 1 {
            return 1.0
        }
        return Double(cueManager.currentExerciseIndex + 1) / Double(workout.exercises.count)
    }
    
    var timeRemaining: Int {
        // Don't show countdown when waiting for user ready
        if cueManager.isWaitingForUserReady {
            return 0
        }
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
            
            // Show different screens based on state
            if cueManager.isWorkoutComplete {
                // Show workout success screen when workout is complete
                WorkoutSuccessScreen(
                    workout: workout,
                    onReturnToLibrary: {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            } else if cueManager.isInRestPeriod {
                // Show rest screen during rest periods
                RestScreen(
                    restDuration: currentExercise?.restDuration ?? 0,
                    nextExerciseName: getNextExerciseName() ?? "Next Exercise",
                    timeRemaining: timeRemaining,
                    onReady: {
                        // Rest screen doesn't need manual ready action
                    }
                )
            } else if isInDescriptionPhase {
                // Show description phase screen
                DescriptionPhaseScreen()
            } else if cueManager.isWaitingForUserReady {
                // Show waiting for ready screen
                if let exercise = currentExercise {
                    WaitingForReadyScreen(
                        exerciseName: exercise.name,
                        exerciseInstructions: exercise.instructions.first ?? "Follow the demonstration",
                        onReady: {
                            cueManager.startExerciseWhenReady()
                        }
                    )
                } else {
                    DescriptionPhaseScreen()
                }
            } else if cueManager.isActive && !cueManager.isWaitingForUserReady && !cueManager.isInRestPeriod {
                // Show main workout screen only when actively exercising (timer running, not waiting for ready)
                VStack(spacing: 20) {
                // Header with progress and exit - only show when not in description phase
                if !isInDescriptionPhase {
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
                        
                        // Volume control button
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingVolumeControls.toggle()
                            }
                        }) {
                            Image(systemName: showingVolumeControls ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                        
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
                }
                
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
                                    if isInDescriptionPhase {
                                        Text("Getting Your Groove On...")
                                            .font(.largeTitle)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    } else {
                                        Text("Let's Do This! 💪")
                                            .font(.largeTitle)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        )
                    
                    // Timer overlay - only show when not in description phase
                    if !isInDescriptionPhase {
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
                }
                .padding(.horizontal)
                
                // Volume Controls Overlay
                if showingVolumeControls {
                    VStack(spacing: 16) {
                        HStack {
                            Text("Volume Controls")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showingVolumeControls = false
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        
                        // Voice Volume Control
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                                
                                Text("Trainer Voice")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Text("\(Int(storedVoiceVolume * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Slider(value: $storedVoiceVolume, in: 0.0...1.0, step: 0.1)
                                .accentColor(.blue)
                                .onChange(of: storedVoiceVolume) { _, newValue in
                                    voiceManager.voiceVolume = Float(newValue)
                                }
                        }
                        
                        // Music Volume Control
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "music.note")
                                    .foregroundColor(.green)
                                    .font(.title3)
                                
                                Text("Spotify Music")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Text("\(Int(storedMusicVolume * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Slider(value: $storedMusicVolume, in: 0.0...1.0, step: 0.1)
                                .accentColor(.green)
                                .onChange(of: storedMusicVolume) { _, newValue in
                                    musicManager.setUserMusicVolume(Float(newValue))
                                }
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Spacer()
                
                // Controls - only show when not in description phase
                if !isInDescriptionPhase {
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
            } else {
                // Fallback screen - should not normally be shown
                VStack {
                    Spacer()
                    Text("Preparing workout...")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                }
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
            
            // Only process workout logic if workout has actually started
            guard workoutHasActuallyStarted else {
                print("🏃 Workout hasn't actually started yet, skipping workout logic")
                return
            }
            
            // Timer is handled by WorkoutCueManager through cue completion
            // The WorkoutCueManager will automatically handle exercise completion when the timer expires
            // No need to manually call nextExercise() here as it's handled by cue completion logic
            
            // Debug logging to understand what's happening
            print("🏃 Workout state: active=\(cueManager.isActive), exercise=\(cueManager.currentExerciseIndex)/\(workout.exercises.count), completed=\(cueManager.completedExercises)")
            
            // Check if workout is complete - only if we've completed all exercises
            // AND we're not in description phase AND workout has actually started
            // AND we have a valid workout with exercises
            if cueManager.completedExercises >= workout.exercises.count && 
               !showingWorkoutComplete &&
               cueManager.isActive &&
               workout.exercises.count > 0 {
                print("🏃 Workout completed! Exercises: \(cueManager.completedExercises)/\(workout.exercises.count)")
                showingWorkoutComplete = true
            }
            
            // Debug: Log completion check conditions
            if cueManager.completedExercises > 0 {
                print("🏃 Completion check: started=\(workoutHasActuallyStarted), completed=\(cueManager.completedExercises)/\(workout.exercises.count), showing=\(showingWorkoutComplete)")
            }
        }
        .onAppear {
            // Connect music manager to cue manager for synchronization
            cueManager.setMusicManager(musicManager)
            
            startWorkout()
            
            // Initialize volume values from stored preferences
            voiceManager.voiceVolume = Float(storedVoiceVolume)
            musicManager.userMusicVolume = Float(storedMusicVolume)
        }
        .onDisappear {
            stopWorkout()
            // Clean up notification observers
            if let observer = voiceCompletionObserver {
                NotificationCenter.default.removeObserver(observer)
                voiceCompletionObserver = nil
            }
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
            get: { 
                showingWorkoutComplete && 
                workoutHasActuallyStarted && 
                !isInDescriptionPhase &&
                cueManager.completedExercises >= workout.exercises.count &&
                workout.exercises.count > 0
            },
            set: { showingWorkoutComplete = $0 }
        )) {
            WorkoutCompleteView(
                workout: workout,
                duration: -(workoutStartTime?.timeIntervalSinceNow ?? 0),
                exercisesCompleted: cueManager.completedExercises,
                intensity: currentIntensity,
                onReturnToLibrary: {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
    
    private func startWorkout() {
        print("🏃 Starting workout: \(workout.title)")
        
        // Validate workout data before starting
        guard !workout.exercises.isEmpty else {
            print("❌ Cannot start workout: No exercises found")
            return
        }
        
        // Reset all workout state
        workoutHasActuallyStarted = false
        showingWorkoutComplete = false
        isInDescriptionPhase = true
        
        // Ensure services are properly initialized before starting
        // Add a small delay to allow services to fully initialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
        
        // Start music earlier - during the description phase
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.musicManager.startWorkoutMusic(for: self.workout, userPreference: .highEnergy)
            print("🎵 Music started during workout description")
        }
        
        // Set up voice completion listener to wait for actual voice finish
        setupVoiceCompletionListener()
        
        cueManager.voiceManager.speakCue(exerciseDescription)
    }
    
    private func setupVoiceCompletionListener() {
        // Clean up any existing observer first
        if let observer = voiceCompletionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // Listen for voice completion to start the actual workout
        voiceCompletionObserver = NotificationCenter.default.addObserver(
            forName: .voiceManagerSpeaking,
            object: nil,
            queue: .main
        ) { notification in
            // Check if voice has finished speaking (notification object is false)
            if let isSpeaking = notification.object as? Bool, !isSpeaking {
                // Only proceed if we're still in description phase and this is the workout description
                if isInDescriptionPhase {
                    print("🏃 Voice description completed, starting actual workout")
                    startActualWorkout()
                }
            }
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
        // Wait for the transition cue to finish speaking
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // End description phase
            self.isInDescriptionPhase = false
            
            // Record the actual workout start time now
            self.workoutStartTime = Date()
            self.workoutHasActuallyStarted = true
            print("🏃 Workout timer started at: \(self.workoutStartTime!)")
            
            // Now start the workout with cue manager (this will start the first exercise)
            self.cueManager.startWorkout(self.workout)
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
    
    private func getNextExerciseName() -> String? {
        guard cueManager.currentExerciseIndex + 1 < workout.exercises.count else { return nil }
        return workout.exercises[cueManager.currentExerciseIndex + 1].name
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

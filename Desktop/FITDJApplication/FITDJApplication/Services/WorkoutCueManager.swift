//
//  WorkoutCueManager.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import Foundation
import Combine

// F-005: Manages workout voice cues and timing
@MainActor
class WorkoutCueManager: ObservableObject {
    @Published var currentCue: VoiceCue?
    @Published var isActive = false
    @Published var isPaused = false
    @Published var timeRemainingInCurrentExercise = 0
    
    private let voiceManager: VoiceManager
    private var workout: Workout?
    var currentExerciseIndex = 0
    private var exerciseStartTime: Date?
    private var timer: Timer?
    private var scheduledCues: [VoiceCue] = []
    
    init(voiceManager: VoiceManager) {
        self.voiceManager = voiceManager
    }
    
    // MARK: - Public Methods
    
    func startWorkout(_ workout: Workout) {
        print("🏃 WorkoutCueManager: Starting workout: \(workout.title)")
        self.workout = workout
        self.currentExerciseIndex = 0
        self.isActive = true
        
        // Ensure we have a valid workout with exercises
        guard !workout.exercises.isEmpty else {
            print("❌ WorkoutCueManager: No exercises found in workout")
            return
        }
        
        print("🏃 WorkoutCueManager: Starting first exercise")
        startCurrentExercise()
    }
    
    func pauseWorkout() {
        print("⏸️ WorkoutCueManager: Pausing workout")
        timer?.invalidate()
        timer = nil
        isPaused = true
        voiceManager.pauseSpeaking()
        print("⏸️ WorkoutCueManager: isPaused = \(isPaused)")
        print("⏸️ WorkoutCueManager: exerciseStartTime = \(exerciseStartTime?.description ?? "nil")")
    }
    
    func resumeWorkout() {
        print("▶️ WorkoutCueManager: Resuming workout")
        guard let exercise = getCurrentExercise() else { 
            print("❌ WorkoutCueManager: No current exercise")
            return 
        }
        
        // Calculate how much time has actually elapsed (excluding pause time)
        let elapsedTime = exerciseStartTime?.timeIntervalSinceNow ?? 0
        let remainingTime = Double(exercise.duration) + elapsedTime
        
        print("▶️ WorkoutCueManager: Elapsed: \(elapsedTime), Remaining: \(remainingTime)")
        print("▶️ WorkoutCueManager: exerciseStartTime = \(exerciseStartTime?.description ?? "nil")")
        
        if remainingTime > 0 {
            isPaused = false
            // Restart the timer when resuming
            startCueTimer()
            voiceManager.resumeSpeaking()
            print("▶️ WorkoutCueManager: isPaused = \(isPaused)")
        } else {
            print("❌ WorkoutCueManager: No time remaining, not resuming")
        }
    }
    
    func stopWorkout() {
        timer?.invalidate()
        timer = nil
        voiceManager.stopSpeaking()
        isActive = false
        workout = nil
        currentExerciseIndex = 0
        scheduledCues.removeAll()
    }
    
    func nextExercise() {
        guard let workout = workout else { return }
        
        if currentExerciseIndex < workout.exercises.count - 1 {
            currentExerciseIndex += 1
            startCurrentExercise()
        } else {
            // Workout complete
            speakWorkoutComplete()
            stopWorkout()
        }
    }
    
    func adjustIntensity(easier: Bool) {
        guard let exercise = getCurrentExercise() else { return }
        
        // Adjust exercise duration based on intensity
        let adjustmentFactor: Double = easier ? 0.8 : 1.2
        let adjustedDuration = Int(Double(exercise.duration) * adjustmentFactor)
        
        // Generate new cues for adjusted duration
        scheduleCuesForExercise(exercise, duration: adjustedDuration)
    }
    
    // MARK: - Private Methods
    
    private func startCurrentExercise() {
        guard let exercise = getCurrentExercise() else { return }
        
        exerciseStartTime = Date()
        timeRemainingInCurrentExercise = exercise.duration
        scheduleCuesForCurrentExercise()
        
        // Speak exercise start cue
        let startCue = VoiceCue(
            id: "exercise-start-\(exercise.id)",
            text: "Now let's do \(exercise.name). \(exercise.instructions.first ?? "Follow the demonstration")",
            timing: 0,
            type: .instruction
        )
        print("🏃 Starting exercise: \(exercise.name)")
        voiceManager.speakCue(startCue)
    }
    
    private func scheduleCuesForCurrentExercise() {
        guard let exercise = getCurrentExercise() else { return }
        scheduleCuesForExercise(exercise, duration: exercise.duration)
    }
    
    private func scheduleCuesForExercise(_ exercise: Exercise, duration: Int) {
        scheduledCues.removeAll()
        
        // Generate cues based on exercise duration
        let cues = generateCuesForExercise(exercise, duration: duration)
        scheduledCues = cues
        
        // Start timer for cue scheduling
        startCueTimer()
    }
    
    private func generateCuesForExercise(_ exercise: Exercise, duration: Int) -> [VoiceCue] {
        var cues: [VoiceCue] = []
        
        // Halfway point motivation
        if duration > 10 {
            let halfwayCue = VoiceCue(
                id: "halfway-\(exercise.id)",
                text: "You're halfway through \(exercise.name). Keep it up!",
                timing: duration / 2,
                type: .motivation
            )
            cues.append(halfwayCue)
        }
        
        // Countdown cues
        let countdownTimes = [10, 5, 3, 2, 1]
        for time in countdownTimes {
            if time < duration {
                let countdownCue = VoiceCue(
                    id: "countdown-\(exercise.id)-\(time)",
                    text: "\(time) seconds left",
                    timing: duration - time,
                    type: .countdown
                )
                cues.append(countdownCue)
            }
        }
        
        // Exercise completion cue
        let completionCue = VoiceCue(
            id: "complete-\(exercise.id)",
            text: "Great job! Time for a \(exercise.restDuration) second rest.",
            timing: duration,
            type: .transition
        )
        cues.append(completionCue)
        
        return cues.sorted { $0.timing < $1.timing }
    }
    
    private func startCueTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateTimeRemaining()
                self?.checkForScheduledCues()
            }
        }
    }
    
    private func updateTimeRemaining() {
        guard let exercise = getCurrentExercise(),
              let startTime = exerciseStartTime else { 
            timeRemainingInCurrentExercise = 0
            return 
        }
        
        let elapsed = Int(-startTime.timeIntervalSinceNow)
        timeRemainingInCurrentExercise = max(0, exercise.duration - elapsed)
    }
    
    private func checkForScheduledCues() {
        guard let exerciseStartTime = exerciseStartTime else { return }
        
        let elapsedTime = Int(-exerciseStartTime.timeIntervalSinceNow)
        
        // Find cues that should be spoken now
        let cuesToSpeak = scheduledCues.filter { cue in
            cue.timing <= elapsedTime && !voiceManager.isSpeaking
        }
        
        for cue in cuesToSpeak {
            voiceManager.speakCue(cue)
            scheduledCues.removeAll { $0.id == cue.id }
        }
    }
    
    private func getCurrentExercise() -> Exercise? {
        guard let workout = workout,
              currentExerciseIndex < workout.exercises.count else { return nil }
        return workout.exercises[currentExerciseIndex]
    }
    
    private func speakWorkoutComplete() {
        let completionCue = VoiceCue(
            id: "workout-complete",
            text: "Amazing work! You've completed your workout. Great job staying consistent!",
            timing: 0,
            type: .motivation
        )
        voiceManager.speakCue(completionCue)
    }
    
    // MARK: - Computed Properties
    
    var currentExercise: Exercise? {
        return getCurrentExercise()
    }
    
    
}

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
    @Published var completedExercises = 0
    @Published var isWaitingForUserReady = false
    @Published var isInRestPeriod = false
    @Published var isWorkoutComplete = false
    
    let voiceManager: VoiceManager
    private var workout: Workout?
    var currentExerciseIndex = 0
    private var exerciseStartTime: Date?
    private var timer: Timer?
    private var scheduledCues: [VoiceCue] = []
    private var musicManager: WorkoutMusicManager?
    
    init(voiceManager: VoiceManager) {
        self.voiceManager = voiceManager
    }
    
    func setMusicManager(_ musicManager: WorkoutMusicManager) {
        self.musicManager = musicManager
    }
    
    // MARK: - Public Methods
    
    func startWorkout(_ workout: Workout) {
        print("🏃 WorkoutCueManager: Starting workout: \(workout.title)")
        self.workout = workout
        self.currentExerciseIndex = 0
        self.completedExercises = 0
        self.isActive = true
        self.isWorkoutComplete = false
        
        // Ensure we have a valid workout with exercises
        guard !workout.exercises.isEmpty else {
            print("❌ WorkoutCueManager: No exercises found in workout")
            return
        }
        
        print("🏃 WorkoutCueManager: Starting first exercise")
        startCurrentExercise()
    }
    
    func startWorkoutWithMusic(_ workout: Workout) {
        print("🏃 WorkoutCueManager: Starting workout with music: \(workout.title)")
        self.workout = workout
        self.currentExerciseIndex = 0
        self.completedExercises = 0
        self.isActive = true
        
        // Ensure we have a valid workout with exercises
        guard !workout.exercises.isEmpty else {
            print("❌ WorkoutCueManager: No exercises found in workout")
            return
        }
        
        print("🏃 WorkoutCueManager: Starting first exercise with music")
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
        
        // Mark current exercise as completed
        completedExercises += 1
        print("🏃 Exercise completed: \(completedExercises)/\(workout.exercises.count)")
        
        // Check if this was the last exercise
        if currentExerciseIndex >= workout.exercises.count - 1 {
            // This was the final exercise - workout is complete
            print("🏃 Final exercise completed - workout is done!")
            isWorkoutComplete = true
            speakWorkoutComplete()
            stopWorkout()
        } else {
            // There are more exercises - start rest period before next exercise
            startRestPeriod()
        }
    }
    
    private func startRestPeriod() {
        guard let currentExercise = getCurrentExercise() else { return }
        let restDuration = currentExercise.restDuration
        
        print("🏃 Starting \(restDuration) second rest period")
        
        // Set rest state
        isInRestPeriod = true
        isWaitingForUserReady = false
        
        // Stop the current exercise timer
        timer?.invalidate()
        timer = nil
        
        // Sync music with rest phase
        musicManager?.syncMusicWithExercisePhase(phase: .rest)
        
        // Speak rest period cue
        let restCue = VoiceCue(
            id: "rest-\(currentExercise.id)",
            text: "Great job! Take \(restDuration) seconds to catch your breath and prepare for the next exercise.",
            timing: 0,
            type: .rest
        )
        voiceManager.speakCue(restCue)
        
        // Start rest timer
        timeRemainingInCurrentExercise = restDuration
        exerciseStartTime = Date()
        
        // Schedule rest period countdown and next exercise preparation
        scheduleRestPeriodCues(restDuration: restDuration)
        startCueTimer()
    }
    
    private func scheduleRestPeriodCues(restDuration: Int) {
        scheduledCues.removeAll()
        
        // Add countdown cues for rest period (only if rest is long enough)
        if restDuration > 10 {
            let restCountdownTimes = [10, 5, 3]
            for time in restCountdownTimes {
                if time < restDuration {
                    let countdownCue = VoiceCue(
                        id: "rest-countdown-\(time)",
                        text: "\(time) seconds until next exercise",
                        timing: restDuration - time,
                        type: .countdown
                    )
                    scheduledCues.append(countdownCue)
                }
            }
        }
        
        // Add preparation cue for next exercise
        if let nextExercise = getNextExercise() {
            let preparationCue = VoiceCue(
                id: "next-exercise-prep",
                text: "Get ready for \(nextExercise.name). \(nextExercise.instructions.first ?? "Follow the demonstration").",
                timing: max(1, restDuration - 2), // 2 seconds before rest ends
                type: .transition
            )
            scheduledCues.append(preparationCue)
        }
        
        // Add rest completion cue
        let restCompleteCue = VoiceCue(
            id: "rest-complete",
            text: "Rest complete. Let's continue!",
            timing: restDuration,
            type: .transition
        )
        scheduledCues.append(restCompleteCue)
        
        scheduledCues.sort { $0.timing < $1.timing }
    }
    
    private func getNextExercise() -> Exercise? {
        guard let workout = workout,
              currentExerciseIndex + 1 < workout.exercises.count else { return nil }
        return workout.exercises[currentExerciseIndex + 1]
    }
    
    private func startNextExerciseAfterRest() {
        guard let workout = workout else { return }
        
        // Clear rest state
        isInRestPeriod = false
        
        currentExerciseIndex += 1
        startCurrentExercise()
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
        
        // DON'T start timer yet - wait for "let's begin"
        timeRemainingInCurrentExercise = exercise.duration
        isWaitingForUserReady = true // Start as true immediately to show waiting screen
        isInRestPeriod = false
        
        // Sync music with exercise phase
        musicManager?.syncMusicWithExercisePhase(phase: .preparation)
        
        // Create exercise description without starting timer
        let exerciseDescription = createExerciseDescription(for: exercise)
        print("🏃 Starting exercise: \(exercise.name)")
        voiceManager.speakCue(exerciseDescription)
        
        // The waiting screen will show immediately and stay until user taps "I'm Ready"
    }
    
    private func startExerciseTimer() {
        guard let exercise = getCurrentExercise() else { return }
        
        print("🏃 Starting exercise timer for: \(exercise.name)")
        exerciseStartTime = Date()
        scheduleCuesForCurrentExercise()
        
        // Sync music to exercise phase when timer actually starts
        musicManager?.syncMusicWithExercisePhase(phase: .exercise)
        
        // Start the actual timer
        startCueTimer()
    }
    
    private func createExerciseDescription(for exercise: Exercise) -> VoiceCue {
        // Create a comprehensive exercise description with setup time
        let description = "Next up is \(exercise.name). \(exercise.instructions.first ?? "Follow the demonstration"). Get into position and take a deep breath. When you're ready, tap the button to begin."
        
        return VoiceCue(
            id: "exercise-start-\(exercise.id)",
            text: description,
            timing: 0,
            type: .exercise_description
        )
    }
    
    // Public method to start the exercise when user is ready
    func startExerciseWhenReady() {
        guard let exercise = getCurrentExercise() else { return }
        
        // Clear waiting state
        isWaitingForUserReady = false
        
        // Speak "let's begin" cue
        let beginCue = VoiceCue(
            id: "exercise-begin-\(exercise.id)",
            text: "Let's begin!",
            timing: 0,
            type: .instruction
        )
        voiceManager.speakCue(beginCue)
        
        // Start the exercise timer after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startExerciseTimer()
        }
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
        
        // Intelligent motivation timing - only speak when it adds value
        if duration > 15 {
            // For longer exercises, add motivation at 1/3 and 2/3 points
            let thirdPoint = duration / 3
            let twoThirdsPoint = (duration * 2) / 3
            
            let firstMotivationCue = VoiceCue(
                id: "motivation-\(exercise.id)-1",
                text: "You're doing great! Keep that form strong.",
                timing: thirdPoint,
                type: .motivation
            )
            cues.append(firstMotivationCue)
            
            let secondMotivationCue = VoiceCue(
                id: "motivation-\(exercise.id)-2",
                text: "Almost there! You've got this!",
                timing: twoThirdsPoint,
                type: .motivation
            )
            cues.append(secondMotivationCue)
        } else if duration > 8 {
            // For medium exercises, just one motivation point
            let halfwayCue = VoiceCue(
                id: "halfway-\(exercise.id)",
                text: "Halfway through! Stay strong!",
                timing: duration / 2,
                type: .motivation
            )
            cues.append(halfwayCue)
        }
        // For short exercises (< 8 seconds), no motivation cues to avoid interrupting flow
        
        // Smart countdown cues - only for exercises longer than 5 seconds
        if duration > 5 {
            let countdownTimes = [10, 5, 3]
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
        }
        
        // Exercise completion cue with rest information
        let completionCue = VoiceCue(
            id: "complete-\(exercise.id)",
            text: "Excellent work! Take \(exercise.restDuration) seconds to catch your breath.",
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
                guard let self = self else { return }
                
                // Don't update timer if we're waiting for user ready
                if !self.isWaitingForUserReady {
                    self.updateTimeRemaining()
                    self.checkForScheduledCues()
                }
            }
        }
    }
    
    private func updateTimeRemaining() {
        guard let startTime = exerciseStartTime else { 
            timeRemainingInCurrentExercise = 0
            return 
        }
        
        let elapsed = Int(-startTime.timeIntervalSinceNow)
        
        if isInRestPeriod {
            // During rest period, calculate based on rest duration
            guard let currentExercise = getCurrentExercise() else {
                timeRemainingInCurrentExercise = 0
                return
            }
            timeRemainingInCurrentExercise = max(0, currentExercise.restDuration - elapsed)
        } else if let exercise = getCurrentExercise() {
            // During exercise, calculate based on exercise duration
            timeRemainingInCurrentExercise = max(0, exercise.duration - elapsed)
        } else {
            timeRemainingInCurrentExercise = 0
        }
    }
    
    private func checkForScheduledCues() {
        guard let exerciseStartTime = exerciseStartTime else { return }
        
        let elapsedTime = Int(-exerciseStartTime.timeIntervalSinceNow)
        
        // Find cues that should be spoken now, but avoid duplicates
        let cuesToSpeak = scheduledCues.filter { cue in
            cue.timing <= elapsedTime && !voiceManager.isSpeaking
        }
        
        for cue in cuesToSpeak {
            // Remove the cue from scheduled cues BEFORE speaking to prevent duplicates
            scheduledCues.removeAll { $0.id == cue.id }
            
                // Only speak if voice manager is not currently speaking
                if !voiceManager.isSpeaking {
                    voiceManager.speakCue(cue)
                    
                    // Check if this is the exercise completion cue
                    if cue.id.hasPrefix("complete-") && !isInRestPeriod {
                        // Exercise just completed, start rest period after a brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                            self?.nextExercise()
                        }
                    }
                    // Check if this is the rest completion cue
                    else if cue.id == "rest-complete" {
                        // Start the next exercise after a brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                            self?.startNextExerciseAfterRest()
                        }
                    }
                }
        }
    }
    
    private func getCurrentExercise() -> Exercise? {
        guard let workout = workout,
              currentExerciseIndex < workout.exercises.count else { 
            print("❌ WorkoutCueManager: getCurrentExercise returning nil - workout: \(workout != nil), index: \(currentExerciseIndex), count: \(workout?.exercises.count ?? 0)")
            return nil 
        }
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

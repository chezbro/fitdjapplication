//
//  ExerciseDBWorkoutBuilder.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import Foundation
import Combine

// MARK: - Workout Builder Service

class ExerciseDBWorkoutBuilder: ObservableObject {
    static let shared = ExerciseDBWorkoutBuilder()
    
    private let exerciseDBService = ExerciseDBService.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var generatedWorkouts: [Workout] = []
    @Published var isGenerating = false
    @Published var errorMessage: String?
    
    private init() {
        // Listen for ExerciseDB service updates
        exerciseDBService.$cachedExercises
            .sink { [weak self] exercises in
                if !exercises.isEmpty {
                    self?.generateWorkoutsFromExerciseDB()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func generateWorkoutsFromExerciseDB() {
        guard !exerciseDBService.cachedExercises.isEmpty else {
            return
        }
        
        isGenerating = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let workouts = self.createWorkoutsFromExerciseDB()
            
            DispatchQueue.main.async {
                self.generatedWorkouts = workouts
                self.isGenerating = false
            }
        }
    }
    
    func createCustomWorkout(
        name: String,
        description: String,
        duration: Int,
        difficulty: WorkoutDifficulty,
        targetMuscleGroups: [MuscleGroup],
        equipment: [Equipment]
    ) -> Workout? {
        let exercises = selectExercisesForWorkout(
            targetMuscleGroups: targetMuscleGroups,
            equipment: equipment,
            difficulty: difficulty,
            targetDuration: duration
        )
        
        guard !exercises.isEmpty else {
            return nil
        }
        
        let estimatedCalories = calculateEstimatedCalories(exercises: exercises, duration: duration)
        
        return Workout(
            id: UUID().uuidString,
            title: name,
            description: description,
            duration: duration,
            difficulty: difficulty,
            requiredEquipment: equipment,
            exercises: exercises,
            targetMuscleGroups: targetMuscleGroups,
            estimatedCalories: estimatedCalories
        )
    }
    
    // MARK: - Private Methods
    
    private func createWorkoutsFromExerciseDB() -> [Workout] {
        var workouts: [Workout] = []
        
        // Create workouts for different muscle groups
        workouts.append(contentsOf: createMuscleGroupWorkouts())
        
        // Create equipment-specific workouts
        workouts.append(contentsOf: createEquipmentWorkouts())
        
        // Create difficulty-based workouts
        workouts.append(contentsOf: createDifficultyWorkouts())
        
        // Create specialized workouts
        workouts.append(contentsOf: createSpecializedWorkouts())
        
        return workouts
    }
    
    private func createMuscleGroupWorkouts() -> [Workout] {
        var workouts: [Workout] = []
        
        let muscleGroups: [MuscleGroup] = [.chest, .back, .shoulders, .arms, .legs, .core]
        
        for muscleGroup in muscleGroups {
            // Beginner workout
            if let workout = createMuscleGroupWorkout(
                muscleGroup: muscleGroup,
                difficulty: .beginner,
                duration: 30
            ) {
                workouts.append(workout)
            }
            
            // Intermediate workout
            if let workout = createMuscleGroupWorkout(
                muscleGroup: muscleGroup,
                difficulty: .intermediate,
                duration: 45
            ) {
                workouts.append(workout)
            }
            
            // Advanced workout
            if let workout = createMuscleGroupWorkout(
                muscleGroup: muscleGroup,
                difficulty: .advanced,
                duration: 60
            ) {
                workouts.append(workout)
            }
        }
        
        return workouts
    }
    
    private func createMuscleGroupWorkout(
        muscleGroup: MuscleGroup,
        difficulty: WorkoutDifficulty,
        duration: Int
    ) -> Workout? {
        let exercises = selectExercisesForMuscleGroup(
            muscleGroup: muscleGroup,
            difficulty: difficulty,
            targetDuration: duration
        )
        
        guard !exercises.isEmpty else { return nil }
        
        let equipment = exercises.flatMap { $0.equipment }.removingDuplicates()
        let estimatedCalories = calculateEstimatedCalories(exercises: exercises, duration: duration)
        
        return Workout(
            id: "exercisedb-\(muscleGroup.rawValue.lowercased())-\(difficulty.rawValue.lowercased())",
            title: "\(muscleGroup.rawValue) \(difficulty.rawValue) Workout",
            description: "Comprehensive \(muscleGroup.rawValue.lowercased()) workout using ExerciseDB exercises. Perfect for \(difficulty.rawValue.lowercased()) fitness levels.",
            duration: duration,
            difficulty: difficulty,
            requiredEquipment: equipment,
            exercises: exercises,
            targetMuscleGroups: [muscleGroup],
            estimatedCalories: estimatedCalories
        )
    }
    
    private func createEquipmentWorkouts() -> [Workout] {
        var workouts: [Workout] = []
        
        let equipmentTypes: [Equipment] = [.none, .dumbbells, .kettlebells, .resistanceBands, .yogaMat]
        
        for equipment in equipmentTypes {
            // Create workouts for different difficulties
            for difficulty in WorkoutDifficulty.allCases {
                if let workout = createEquipmentWorkout(
                    equipment: equipment,
                    difficulty: difficulty,
                    duration: difficulty == .beginner ? 30 : difficulty == .intermediate ? 45 : 60
                ) {
                    workouts.append(workout)
                }
            }
        }
        
        return workouts
    }
    
    private func createEquipmentWorkout(
        equipment: Equipment,
        difficulty: WorkoutDifficulty,
        duration: Int
    ) -> Workout? {
        let exercises = selectExercisesForEquipment(
            equipment: equipment,
            difficulty: difficulty,
            targetDuration: duration
        )
        
        guard !exercises.isEmpty else { return nil }
        
        let muscleGroups = exercises.flatMap { $0.muscleGroups }.removingDuplicates()
        let estimatedCalories = calculateEstimatedCalories(exercises: exercises, duration: duration)
        
        let equipmentName = equipment == .none ? "Bodyweight" : equipment.rawValue
        
        return Workout(
            id: "exercisedb-\(equipment.rawValue.lowercased())-\(difficulty.rawValue.lowercased())",
            title: "\(equipmentName) \(difficulty.rawValue) Workout",
            description: "Complete \(equipmentName.lowercased()) workout using ExerciseDB exercises. No gym required!",
            duration: duration,
            difficulty: difficulty,
            requiredEquipment: [equipment],
            exercises: exercises,
            targetMuscleGroups: muscleGroups,
            estimatedCalories: estimatedCalories
        )
    }
    
    private func createDifficultyWorkouts() -> [Workout] {
        var workouts: [Workout] = []
        
        // Full body workouts for each difficulty
        for difficulty in WorkoutDifficulty.allCases {
            if let workout = createFullBodyWorkout(difficulty: difficulty) {
                workouts.append(workout)
            }
        }
        
        return workouts
    }
    
    private func createFullBodyWorkout(difficulty: WorkoutDifficulty) -> Workout? {
        let duration = difficulty == .beginner ? 35 : difficulty == .intermediate ? 50 : 70
        let exercises = selectFullBodyExercises(difficulty: difficulty, targetDuration: duration)
        
        guard !exercises.isEmpty else { return nil }
        
        let equipment = exercises.flatMap { $0.equipment }.removingDuplicates()
        let muscleGroups = exercises.flatMap { $0.muscleGroups }.removingDuplicates()
        let estimatedCalories = calculateEstimatedCalories(exercises: exercises, duration: duration)
        
        return Workout(
            id: "exercisedb-fullbody-\(difficulty.rawValue.lowercased())",
            title: "Full Body \(difficulty.rawValue) Workout",
            description: "Complete full body workout targeting all major muscle groups. Perfect for \(difficulty.rawValue.lowercased()) fitness levels.",
            duration: duration,
            difficulty: difficulty,
            requiredEquipment: equipment,
            exercises: exercises,
            targetMuscleGroups: [.fullBody],
            estimatedCalories: estimatedCalories
        )
    }
    
    private func createSpecializedWorkouts() -> [Workout] {
        var workouts: [Workout] = []
        
        // HIIT Workout
        if let hiitWorkout = createHIITWorkout() {
            workouts.append(hiitWorkout)
        }
        
        // Strength Training Workout
        if let strengthWorkout = createStrengthWorkout() {
            workouts.append(strengthWorkout)
        }
        
        // Cardio Workout
        if let cardioWorkout = createCardioWorkout() {
            workouts.append(cardioWorkout)
        }
        
        // Flexibility Workout
        if let flexibilityWorkout = createFlexibilityWorkout() {
            workouts.append(flexibilityWorkout)
        }
        
        return workouts
    }
    
    private func createHIITWorkout() -> Workout? {
        let exercises = exerciseDBService.cachedExercises
            .filter { exercise in
                exercise.exerciseType.lowercased().contains("cardio") ||
                exercise.bodyParts.contains { $0.lowercased() == "cardio" } ||
                exercise.name.lowercased().contains("jump") ||
                exercise.name.lowercased().contains("burpee") ||
                exercise.name.lowercased().contains("sprint")
            }
            .prefix(8)
            .map { $0.toAppExercise() }
        
        guard !exercises.isEmpty else { return nil }
        
        return Workout(
            id: "exercisedb-hiit-advanced",
            title: "HIIT Power Blast",
            description: "High-intensity interval training workout using ExerciseDB exercises. Maximum calorie burn in minimal time!",
            duration: 30,
            difficulty: .advanced,
            requiredEquipment: [.none],
            exercises: Array(exercises),
            targetMuscleGroups: [.fullBody, .cardio],
            estimatedCalories: 400
        )
    }
    
    private func createStrengthWorkout() -> Workout? {
        let exercises = exerciseDBService.cachedExercises
            .filter { exercise in
                exercise.exerciseType.lowercased().contains("weight") ||
                exercise.equipments.contains { $0.lowercased().contains("dumbbell") || $0.lowercased().contains("barbell") }
            }
            .prefix(8)
            .map { $0.toAppExercise() }
        
        guard !exercises.isEmpty else { return nil }
        
        let equipment = exercises.flatMap { $0.equipment }.removingDuplicates()
        
        return Workout(
            id: "exercisedb-strength-intermediate",
            title: "Strength Builder",
            description: "Build muscle and strength with this comprehensive workout using ExerciseDB exercises.",
            duration: 55,
            difficulty: .intermediate,
            requiredEquipment: equipment,
            exercises: Array(exercises),
            targetMuscleGroups: [.chest, .back, .legs, .arms, .shoulders],
            estimatedCalories: 450
        )
    }
    
    private func createCardioWorkout() -> Workout? {
        let exercises = exerciseDBService.cachedExercises
            .filter { exercise in
                exercise.exerciseType.lowercased().contains("cardio") ||
                exercise.bodyParts.contains { $0.lowercased() == "cardio" } ||
                exercise.name.lowercased().contains("jump") ||
                exercise.name.lowercased().contains("run") ||
                exercise.name.lowercased().contains("step")
            }
            .prefix(8)
            .map { $0.toAppExercise() }
        
        guard !exercises.isEmpty else { return nil }
        
        return Workout(
            id: "exercisedb-cardio-intermediate",
            title: "Cardio Blast",
            description: "Get your heart pumping with this high-energy cardio session using ExerciseDB exercises.",
            duration: 40,
            difficulty: .intermediate,
            requiredEquipment: [.none],
            exercises: Array(exercises),
            targetMuscleGroups: [.cardio, .fullBody],
            estimatedCalories: 350
        )
    }
    
    private func createFlexibilityWorkout() -> Workout? {
        let exercises = exerciseDBService.cachedExercises
            .filter { exercise in
                exercise.exerciseType.lowercased().contains("stretch") ||
                exercise.name.lowercased().contains("stretch") ||
                exercise.name.lowercased().contains("yoga") ||
                exercise.name.lowercased().contains("flexibility")
            }
            .prefix(8)
            .map { $0.toAppExercise() }
        
        guard !exercises.isEmpty else { return nil }
        
        return Workout(
            id: "exercisedb-flexibility-beginner",
            title: "Flexibility Flow",
            description: "Improve flexibility and mobility with this relaxing workout using ExerciseDB exercises.",
            duration: 35,
            difficulty: .beginner,
            requiredEquipment: [.yogaMat],
            exercises: Array(exercises),
            targetMuscleGroups: [.flexibility, .fullBody],
            estimatedCalories: 120
        )
    }
    
    // MARK: - Exercise Selection Methods
    
    private func selectExercisesForWorkout(
        targetMuscleGroups: [MuscleGroup],
        equipment: [Equipment],
        difficulty: WorkoutDifficulty,
        targetDuration: Int
    ) -> [Exercise] {
        let availableExercises = exerciseDBService.cachedExercises
            .filter { exercise in
                let exerciseEquipment = exercise.toAppExercise().equipment
                let hasRequiredEquipment = equipment.isEmpty || equipment.contains { eq in
                    exerciseEquipment.contains(eq)
                }
                
                let exerciseMuscleGroups = exercise.toAppExercise().muscleGroups
                let targetsMuscleGroup = targetMuscleGroups.isEmpty || targetMuscleGroups.contains { mg in
                    exerciseMuscleGroups.contains(mg)
                }
                
                return hasRequiredEquipment && targetsMuscleGroup
            }
        
        // Select exercises based on difficulty and duration
        let exerciseCount = min(8, max(4, targetDuration / 8)) // 4-8 exercises based on duration
        let selectedExercises = Array(availableExercises.shuffled().prefix(exerciseCount))
        
        return selectedExercises.map { $0.toAppExercise() }
    }
    
    private func selectExercisesForMuscleGroup(
        muscleGroup: MuscleGroup,
        difficulty: WorkoutDifficulty,
        targetDuration: Int
    ) -> [Exercise] {
        let muscleGroupString = muscleGroup.rawValue.lowercased()
        
        let availableExercises = exerciseDBService.cachedExercises
            .filter { exercise in
                exercise.bodyParts.contains { $0.lowercased() == muscleGroupString } ||
                exercise.targetMuscles.contains { $0.lowercased().contains(muscleGroupString) }
            }
        
        let exerciseCount = min(8, max(4, targetDuration / 8))
        let selectedExercises = Array(availableExercises.shuffled().prefix(exerciseCount))
        
        return selectedExercises.map { $0.toAppExercise() }
    }
    
    private func selectExercisesForEquipment(
        equipment: Equipment,
        difficulty: WorkoutDifficulty,
        targetDuration: Int
    ) -> [Exercise] {
        let equipmentString = equipment.rawValue.lowercased()
        
        let availableExercises = exerciseDBService.cachedExercises
            .filter { exercise in
                if equipment == .none {
                    return exercise.equipments.contains { $0.lowercased() == "body weight" || $0.lowercased() == "bodyweight" }
                } else {
                    return exercise.equipments.contains { $0.lowercased().contains(equipmentString) }
                }
            }
        
        let exerciseCount = min(8, max(4, targetDuration / 8))
        let selectedExercises = Array(availableExercises.shuffled().prefix(exerciseCount))
        
        return selectedExercises.map { $0.toAppExercise() }
    }
    
    private func selectFullBodyExercises(
        difficulty: WorkoutDifficulty,
        targetDuration: Int
    ) -> [Exercise] {
        let muscleGroups: [MuscleGroup] = [.chest, .back, .shoulders, .arms, .legs, .core]
        var selectedExercises: [Exercise] = []
        
        // Select 1-2 exercises per muscle group
        for muscleGroup in muscleGroups {
            let exercises = selectExercisesForMuscleGroup(
                muscleGroup: muscleGroup,
                difficulty: difficulty,
                targetDuration: 10 // Short duration for individual selection
            )
            
            if let exercise = exercises.randomElement() {
                selectedExercises.append(exercise)
            }
        }
        
        return selectedExercises
    }
    
    private func calculateEstimatedCalories(exercises: [Exercise], duration: Int) -> Int {
        // Rough estimation: 8-12 calories per minute for moderate intensity
        let baseCaloriesPerMinute = 10
        let intensityMultiplier = exercises.contains { $0.muscleGroups.contains(.cardio) } ? 1.2 : 1.0
        return Int(Double(duration * baseCaloriesPerMinute) * intensityMultiplier)
    }
}

// MARK: - Array Extension

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

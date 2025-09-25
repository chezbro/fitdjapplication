//
//  WorkoutDataService.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import Foundation
import Combine

class WorkoutDataService: ObservableObject {
    @Published var workouts: [Workout] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init() {
        loadWorkouts()
    }
    
    func loadWorkouts() {
        isLoading = true
        errorMessage = nil
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.workouts = self.getSampleWorkouts()
            self.isLoading = false
        }
    }
    
    func refreshWorkouts() {
        loadWorkouts()
    }
    
    private func getSampleWorkouts() -> [Workout] {
        return [
            // Beginner Workouts
            Workout(
                id: "beginner-full-body-1",
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
                        id: "bodyweight-squats",
                        name: "Bodyweight Squats",
                        description: "Lower body strength exercise",
                        duration: 30,
                        restDuration: 10,
                        muscleGroups: [.legs],
                        equipment: [.none],
                        instructions: ["Stand with feet shoulder-width apart", "Lower down as if sitting in a chair", "Keep chest up and knees behind toes", "Return to standing position"]
                    ),
                    Exercise(
                        id: "push-ups",
                        name: "Push-ups",
                        description: "Upper body strength exercise",
                        duration: 30,
                        restDuration: 10,
                        muscleGroups: [.chest, .arms, .core],
                        equipment: [.none],
                        instructions: ["Start in plank position", "Lower chest to ground", "Push back up to starting position", "Keep body straight throughout"]
                    )
                ],
                targetMuscleGroups: [.fullBody, .cardio],
                estimatedCalories: 120
            ),
            
            Workout(
                id: "beginner-core-1",
                title: "Core Strengthener",
                description: "Build a strong core with this 12-minute beginner-friendly workout.",
                duration: 12,
                difficulty: .beginner,
                requiredEquipment: [.yogaMat],
                exercises: [
                    Exercise(
                        id: "plank",
                        name: "Plank",
                        description: "Core stability exercise",
                        duration: 30,
                        restDuration: 15,
                        muscleGroups: [.core],
                        equipment: [.yogaMat],
                        instructions: ["Start in push-up position", "Hold body straight", "Engage core muscles", "Breathe normally"]
                    ),
                    Exercise(
                        id: "mountain-climbers",
                        name: "Mountain Climbers",
                        description: "Dynamic core and cardio exercise",
                        duration: 30,
                        restDuration: 15,
                        muscleGroups: [.core, .cardio],
                        equipment: [.yogaMat],
                        instructions: ["Start in plank position", "Bring knee to chest", "Quickly switch legs", "Maintain plank position"]
                    )
                ],
                targetMuscleGroups: [.core],
                estimatedCalories: 80
            ),
            
            // Intermediate Workouts
            Workout(
                id: "intermediate-hiit-1",
                title: "HIIT Power Blast",
                description: "High-intensity interval training for maximum calorie burn in 20 minutes.",
                duration: 20,
                difficulty: .intermediate,
                requiredEquipment: [.none],
                exercises: [
                    Exercise(
                        id: "burpees",
                        name: "Burpees",
                        description: "Full body high-intensity exercise",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.fullBody, .cardio],
                        equipment: [.none],
                        instructions: ["Start standing", "Drop to push-up position", "Do a push-up", "Jump feet to hands", "Jump up with arms overhead"]
                    ),
                    Exercise(
                        id: "high-knees",
                        name: "High Knees",
                        description: "Cardio and leg exercise",
                        duration: 30,
                        restDuration: 15,
                        muscleGroups: [.legs, .cardio],
                        equipment: [.none],
                        instructions: ["Run in place", "Bring knees up high", "Pump arms naturally", "Stay on balls of feet"]
                    )
                ],
                targetMuscleGroups: [.fullBody, .cardio],
                estimatedCalories: 200
            ),
            
            Workout(
                id: "intermediate-strength-1",
                title: "Strength Builder",
                description: "Build muscle and strength with this 25-minute intermediate workout.",
                duration: 25,
                difficulty: .intermediate,
                requiredEquipment: [.dumbbells],
                exercises: [
                    Exercise(
                        id: "dumbbell-squats",
                        name: "Dumbbell Squats",
                        description: "Weighted lower body exercise",
                        duration: 45,
                        restDuration: 20,
                        muscleGroups: [.legs],
                        equipment: [.dumbbells],
                        instructions: ["Hold dumbbells at shoulders", "Stand with feet shoulder-width apart", "Lower down as if sitting", "Drive through heels to stand"]
                    ),
                    Exercise(
                        id: "dumbbell-press",
                        name: "Dumbbell Press",
                        description: "Upper body strength exercise",
                        duration: 45,
                        restDuration: 20,
                        muscleGroups: [.chest, .shoulders, .arms],
                        equipment: [.dumbbells],
                        instructions: ["Lie on back with dumbbells", "Press weights up over chest", "Lower with control", "Keep core engaged"]
                    )
                ],
                targetMuscleGroups: [.chest, .legs, .arms],
                estimatedCalories: 180
            ),
            
            // Advanced Workouts
            Workout(
                id: "advanced-challenge-1",
                title: "Ultimate Challenge",
                description: "For advanced users only! A 30-minute high-intensity workout that will push your limits.",
                duration: 30,
                difficulty: .advanced,
                requiredEquipment: [.dumbbells, .kettlebells],
                exercises: [
                    Exercise(
                        id: "kettlebell-swings",
                        name: "Kettlebell Swings",
                        description: "Explosive full body exercise",
                        duration: 60,
                        restDuration: 30,
                        muscleGroups: [.fullBody, .core],
                        equipment: [.kettlebells],
                        instructions: ["Stand with feet shoulder-width apart", "Hold kettlebell with both hands", "Hinge at hips and swing back", "Drive hips forward to swing up"]
                    ),
                    Exercise(
                        id: "dumbbell-thrusters",
                        name: "Dumbbell Thrusters",
                        description: "Combined squat and press",
                        duration: 60,
                        restDuration: 30,
                        muscleGroups: [.fullBody],
                        equipment: [.dumbbells],
                        instructions: ["Hold dumbbells at shoulders", "Squat down", "Drive up and press weights overhead", "Lower weights and repeat"]
                    )
                ],
                targetMuscleGroups: [.fullBody],
                estimatedCalories: 350
            ),
            
            // Equipment-specific workouts
            Workout(
                id: "yoga-flow-1",
                title: "Morning Yoga Flow",
                description: "Start your day with this calming 18-minute yoga sequence.",
                duration: 18,
                difficulty: .beginner,
                requiredEquipment: [.yogaMat],
                exercises: [
                    Exercise(
                        id: "downward-dog",
                        name: "Downward Dog",
                        description: "Full body stretch and strength",
                        duration: 60,
                        restDuration: 10,
                        muscleGroups: [.fullBody, .flexibility],
                        equipment: [.yogaMat],
                        instructions: ["Start on hands and knees", "Tuck toes and lift hips", "Straighten legs as much as possible", "Hold position and breathe"]
                    ),
                    Exercise(
                        id: "warrior-pose",
                        name: "Warrior I",
                        description: "Strength and balance pose",
                        duration: 45,
                        restDuration: 10,
                        muscleGroups: [.legs, .core],
                        equipment: [.yogaMat],
                        instructions: ["Step one foot forward", "Bend front knee over ankle", "Raise arms overhead", "Hold and breathe deeply"]
                    )
                ],
                targetMuscleGroups: [.fullBody, .flexibility],
                estimatedCalories: 60
            ),
            
            Workout(
                id: "resistance-band-1",
                title: "Resistance Band Power",
                description: "Build strength anywhere with this 22-minute resistance band workout.",
                duration: 22,
                difficulty: .intermediate,
                requiredEquipment: [.resistanceBands],
                exercises: [
                    Exercise(
                        id: "band-pull-aparts",
                        name: "Band Pull-aparts",
                        description: "Upper back and shoulder exercise",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.back, .shoulders],
                        equipment: [.resistanceBands],
                        instructions: ["Hold band with both hands", "Start with arms extended", "Pull band apart", "Squeeze shoulder blades together"]
                    ),
                    Exercise(
                        id: "band-squats",
                        name: "Band Squats",
                        description: "Resistance squat variation",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.legs],
                        equipment: [.resistanceBands],
                        instructions: ["Stand on band with feet shoulder-width apart", "Hold handles at shoulders", "Squat down", "Drive up through heels"]
                    )
                ],
                targetMuscleGroups: [.legs, .back, .shoulders],
                estimatedCalories: 160
            ),
            
            Workout(
                id: "cardio-blast-1",
                title: "Cardio Blast",
                description: "Get your heart pumping with this 16-minute high-energy cardio session.",
                duration: 16,
                difficulty: .intermediate,
                requiredEquipment: [.none],
                exercises: [
                    Exercise(
                        id: "jump-squats",
                        name: "Jump Squats",
                        description: "Explosive lower body exercise",
                        duration: 30,
                        restDuration: 10,
                        muscleGroups: [.legs, .cardio],
                        equipment: [.none],
                        instructions: ["Start in squat position", "Jump up explosively", "Land softly in squat", "Immediately jump again"]
                    ),
                    Exercise(
                        id: "lunge-jumps",
                        name: "Lunge Jumps",
                        description: "Dynamic leg exercise",
                        duration: 30,
                        restDuration: 10,
                        muscleGroups: [.legs, .cardio],
                        equipment: [.none],
                        instructions: ["Start in lunge position", "Jump up and switch legs", "Land in opposite lunge", "Continue alternating"]
                    )
                ],
                targetMuscleGroups: [.legs, .cardio],
                estimatedCalories: 140
            )
        ]
    }
    
    func getWorkouts(for equipment: [Equipment]) -> [Workout] {
        return workouts.filter { workout in
            workout.requiredEquipment.allSatisfy { required in
                equipment.contains(required)
            }
        }
    }
    
    func getWorkouts(for difficulty: WorkoutDifficulty) -> [Workout] {
        return workouts.filter { $0.difficulty == difficulty }
    }
    
    func getWorkouts(for muscleGroup: MuscleGroup) -> [Workout] {
        return workouts.filter { workout in
            workout.targetMuscleGroups.contains(muscleGroup)
        }
    }
}

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
    
    private let exerciseDBService = ExerciseDBService.shared
    private let workoutBuilder = ExerciseDBWorkoutBuilder.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupExerciseDBIntegration()
        loadWorkouts()
    }
    
    private func setupExerciseDBIntegration() {
        // Listen for ExerciseDB workouts
        workoutBuilder.$generatedWorkouts
            .sink { [weak self] exerciseDBWorkouts in
                self?.updateWorkoutsWithExerciseDB()
            }
            .store(in: &cancellables)
        
        // Initialize ExerciseDB service
        Task {
            await exerciseDBService.fetchAndCacheExercises()
        }
    }
    
    func loadWorkouts() {
        isLoading = true
        errorMessage = nil
        
        // Load sample workouts first
        let sampleWorkouts = getSampleWorkouts()
        
        // Combine with ExerciseDB workouts if available
        let exerciseDBWorkouts = workoutBuilder.generatedWorkouts
        let allWorkouts = sampleWorkouts + exerciseDBWorkouts
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.workouts = allWorkouts
            self.isLoading = false
        }
    }
    
    private func updateWorkoutsWithExerciseDB() {
        let sampleWorkouts = getSampleWorkouts()
        let exerciseDBWorkouts = workoutBuilder.generatedWorkouts
        let allWorkouts = sampleWorkouts + exerciseDBWorkouts
        
        DispatchQueue.main.async {
            self.workouts = allWorkouts
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
                description: "Perfect for beginners! A comprehensive 35-minute full-body workout that builds strength and endurance.",
                duration: 35,
                difficulty: .beginner,
                requiredEquipment: [.none],
                exercises: [
                    Exercise(
                        id: "jumping-jacks",
                        name: "Jumping Jacks",
                        description: "Full body cardio exercise",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.cardio, .fullBody],
                        equipment: [.none],
                        instructions: ["Stand with feet together", "Jump up spreading legs", "Raise arms overhead", "Return to starting position"],
                        tips: ["Keep knees slightly bent on landing", "Maintain steady breathing"]
                    ),
                    Exercise(
                        id: "bodyweight-squats",
                        name: "Bodyweight Squats",
                        description: "Lower body strength exercise",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.legs],
                        equipment: [.none],
                        instructions: ["Stand with feet shoulder-width apart", "Lower down as if sitting in a chair", "Keep chest up and knees behind toes", "Return to standing position"],
                        tips: ["Keep weight on heels", "Don't let knees cave inward"]
                    ),
                    Exercise(
                        id: "push-ups",
                        name: "Push-ups",
                        description: "Upper body strength exercise",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.chest, .arms, .core],
                        equipment: [.none],
                        instructions: ["Start in plank position", "Lower chest to ground", "Push back up to starting position", "Keep body straight throughout"],
                        tips: ["Modify on knees if needed", "Keep core engaged throughout"]
                    ),
                    Exercise(
                        id: "lunges",
                        name: "Alternating Lunges",
                        description: "Lower body strength and balance exercise",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.legs],
                        equipment: [.none],
                        instructions: ["Step forward with right leg", "Lower until both knees at 90 degrees", "Push back to starting position", "Alternate legs"],
                        tips: ["Keep front knee over ankle", "Don't let back knee touch ground"]
                    ),
                    Exercise(
                        id: "plank",
                        name: "Plank Hold",
                        description: "Core stability exercise",
                        duration: 30,
                        restDuration: 15,
                        muscleGroups: [.core],
                        equipment: [.none],
                        instructions: ["Start in push-up position", "Hold body straight", "Engage core muscles", "Breathe normally"],
                        tips: ["Keep hips level", "Don't let hips sag or pike up"]
                    ),
                    Exercise(
                        id: "mountain-climbers",
                        name: "Mountain Climbers",
                        description: "Dynamic core and cardio exercise",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.core, .cardio],
                        equipment: [.none],
                        instructions: ["Start in plank position", "Bring knee to chest", "Quickly switch legs", "Maintain plank position"],
                        tips: ["Keep core tight", "Maintain steady pace"]
                    ),
                    Exercise(
                        id: "tricep-dips",
                        name: "Tricep Dips",
                        description: "Upper body strength exercise",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.arms],
                        equipment: [.none],
                        instructions: ["Sit on edge of chair or step", "Place hands beside hips", "Lower body by bending elbows", "Push back up to starting position"],
                        tips: ["Keep elbows close to body", "Don't go too low if it hurts shoulders"]
                    ),
                    Exercise(
                        id: "wall-sit",
                        name: "Wall Sit",
                        description: "Isometric leg strength exercise",
                        duration: 30,
                        restDuration: 15,
                        muscleGroups: [.legs],
                        equipment: [.none],
                        instructions: ["Lean back against wall", "Slide down until knees at 90 degrees", "Hold position", "Keep back flat against wall"],
                        tips: ["Distribute weight evenly", "Breathe normally while holding"]
                    )
                ],
                targetMuscleGroups: [.fullBody, .cardio],
                estimatedCalories: 280
            ),
            
            Workout(
                id: "beginner-core-1",
                title: "Core Strengthener",
                description: "Build a strong core with this comprehensive 30-minute beginner-friendly workout.",
                duration: 30,
                difficulty: .beginner,
                requiredEquipment: [.yogaMat],
                exercises: [
                    Exercise(
                        id: "plank",
                        name: "Plank Hold",
                        description: "Core stability exercise",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.core],
                        equipment: [.yogaMat],
                        instructions: ["Start in push-up position", "Hold body straight", "Engage core muscles", "Breathe normally"],
                        tips: ["Keep hips level", "Don't let hips sag or pike up"]
                    ),
                    Exercise(
                        id: "mountain-climbers",
                        name: "Mountain Climbers",
                        description: "Dynamic core and cardio exercise",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.core, .cardio],
                        equipment: [.yogaMat],
                        instructions: ["Start in plank position", "Bring knee to chest", "Quickly switch legs", "Maintain plank position"],
                        tips: ["Keep core tight", "Maintain steady pace"]
                    ),
                    Exercise(
                        id: "dead-bug",
                        name: "Dead Bug",
                        description: "Core stability and coordination exercise",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.core],
                        equipment: [.yogaMat],
                        instructions: ["Lie on back with arms up", "Bend knees at 90 degrees", "Lower opposite arm and leg", "Return to start and alternate"],
                        tips: ["Keep lower back pressed to floor", "Move slowly and controlled"]
                    ),
                    Exercise(
                        id: "bird-dog",
                        name: "Bird Dog",
                        description: "Core stability and balance exercise",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.core, .back],
                        equipment: [.yogaMat],
                        instructions: ["Start on hands and knees", "Extend opposite arm and leg", "Hold briefly", "Return to start and alternate"],
                        tips: ["Keep hips level", "Don't let hips rotate"]
                    ),
                    Exercise(
                        id: "russian-twists",
                        name: "Russian Twists",
                        description: "Oblique and core strengthening exercise",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.core],
                        equipment: [.yogaMat],
                        instructions: ["Sit with knees bent", "Lean back slightly", "Rotate torso side to side", "Keep feet off ground for extra challenge"],
                        tips: ["Keep chest up", "Rotate from the core, not just arms"]
                    ),
                    Exercise(
                        id: "bicycle-crunches",
                        name: "Bicycle Crunches",
                        description: "Dynamic core and oblique exercise",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.core],
                        equipment: [.yogaMat],
                        instructions: ["Lie on back with hands behind head", "Bring knee to opposite elbow", "Switch sides in pedaling motion", "Keep lower back pressed down"],
                        tips: ["Don't pull on neck", "Focus on bringing elbow to knee"]
                    ),
                    Exercise(
                        id: "side-plank",
                        name: "Side Plank",
                        description: "Lateral core strength exercise",
                        duration: 30,
                        restDuration: 15,
                        muscleGroups: [.core],
                        equipment: [.yogaMat],
                        instructions: ["Lie on side with elbow under shoulder", "Lift hips up", "Hold straight line from head to feet", "Switch sides"],
                        tips: ["Keep body in straight line", "Don't let hips sag"]
                    )
                ],
                targetMuscleGroups: [.core],
                estimatedCalories: 180
            ),
            
            // Intermediate Workouts
            Workout(
                id: "intermediate-hiit-1",
                title: "HIIT Power Blast",
                description: "High-intensity interval training for maximum calorie burn in this comprehensive 45-minute session.",
                duration: 45,
                difficulty: .intermediate,
                requiredEquipment: [.none],
                exercises: [
                    Exercise(
                        id: "burpees",
                        name: "Burpees",
                        description: "Full body high-intensity exercise",
                        duration: 60,
                        restDuration: 20,
                        muscleGroups: [.fullBody, .cardio],
                        equipment: [.none],
                        instructions: ["Start standing", "Drop to push-up position", "Do a push-up", "Jump feet to hands", "Jump up with arms overhead"],
                        tips: ["Maintain steady pace", "Land softly on jumps"]
                    ),
                    Exercise(
                        id: "high-knees",
                        name: "High Knees",
                        description: "Cardio and leg exercise",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.legs, .cardio],
                        equipment: [.none],
                        instructions: ["Run in place", "Bring knees up high", "Pump arms naturally", "Stay on balls of feet"],
                        tips: ["Keep core engaged", "Maintain upright posture"]
                    ),
                    Exercise(
                        id: "jump-squats",
                        name: "Jump Squats",
                        description: "Explosive lower body exercise",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.legs, .cardio],
                        equipment: [.none],
                        instructions: ["Start in squat position", "Jump up explosively", "Land softly in squat", "Immediately jump again"],
                        tips: ["Land with knees slightly bent", "Use arms for momentum"]
                    ),
                    Exercise(
                        id: "mountain-climbers",
                        name: "Mountain Climbers",
                        description: "Dynamic core and cardio exercise",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.core, .cardio],
                        equipment: [.none],
                        instructions: ["Start in plank position", "Bring knee to chest", "Quickly switch legs", "Maintain plank position"],
                        tips: ["Keep core tight", "Maintain steady pace"]
                    ),
                    Exercise(
                        id: "jumping-lunges",
                        name: "Jumping Lunges",
                        description: "Dynamic leg exercise with plyometric element",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.legs, .cardio],
                        equipment: [.none],
                        instructions: ["Start in lunge position", "Jump up and switch legs", "Land in opposite lunge", "Continue alternating"],
                        tips: ["Land softly", "Keep knees behind toes"]
                    ),
                    Exercise(
                        id: "push-up-to-tuck-jump",
                        name: "Push-up to Tuck Jump",
                        description: "Combined upper body and explosive leg exercise",
                        duration: 60,
                        restDuration: 20,
                        muscleGroups: [.fullBody, .cardio],
                        equipment: [.none],
                        instructions: ["Do a push-up", "Jump feet to hands", "Jump up bringing knees to chest", "Land and repeat"],
                        tips: ["Maintain good push-up form", "Land softly on tuck jumps"]
                    ),
                    Exercise(
                        id: "lateral-bounds",
                        name: "Lateral Bounds",
                        description: "Lateral plyometric exercise",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.legs, .cardio],
                        equipment: [.none],
                        instructions: ["Stand on one leg", "Jump laterally to other leg", "Land softly and immediately jump back", "Keep core engaged"],
                        tips: ["Land with soft knees", "Maintain balance"]
                    ),
                    Exercise(
                        id: "sprint-in-place",
                        name: "Sprint in Place",
                        description: "High-intensity cardio exercise",
                        duration: 30,
                        restDuration: 15,
                        muscleGroups: [.legs, .cardio],
                        equipment: [.none],
                        instructions: ["Run in place as fast as possible", "Pump arms vigorously", "Stay on balls of feet", "Maintain high intensity"],
                        tips: ["Keep core tight", "Maintain good posture"]
                    )
                ],
                targetMuscleGroups: [.fullBody, .cardio],
                estimatedCalories: 450
            ),
            
            Workout(
                id: "intermediate-strength-1",
                title: "Strength Builder",
                description: "Build muscle and strength with this comprehensive 50-minute intermediate workout.",
                duration: 50,
                difficulty: .intermediate,
                requiredEquipment: [.dumbbells],
                exercises: [
                    Exercise(
                        id: "dumbbell-squats",
                        name: "Dumbbell Squats",
                        description: "Weighted lower body exercise",
                        duration: 60,
                        restDuration: 30,
                        muscleGroups: [.legs],
                        equipment: [.dumbbells],
                        instructions: ["Hold dumbbells at shoulders", "Stand with feet shoulder-width apart", "Lower down as if sitting", "Drive through heels to stand"],
                        tips: ["Keep chest up", "Don't let knees cave inward"]
                    ),
                    Exercise(
                        id: "dumbbell-press",
                        name: "Dumbbell Bench Press",
                        description: "Upper body strength exercise",
                        duration: 60,
                        restDuration: 30,
                        muscleGroups: [.chest, .shoulders, .arms],
                        equipment: [.dumbbells],
                        instructions: ["Lie on back with dumbbells", "Press weights up over chest", "Lower with control", "Keep core engaged"],
                        tips: ["Control the weight down", "Press up explosively"]
                    ),
                    Exercise(
                        id: "dumbbell-rows",
                        name: "Dumbbell Rows",
                        description: "Back and bicep strengthening exercise",
                        duration: 60,
                        restDuration: 30,
                        muscleGroups: [.back, .arms],
                        equipment: [.dumbbells],
                        instructions: ["Bend over with dumbbells", "Pull weights to chest", "Squeeze shoulder blades", "Lower with control"],
                        tips: ["Keep back straight", "Pull with elbows, not arms"]
                    ),
                    Exercise(
                        id: "dumbbell-lunges",
                        name: "Dumbbell Lunges",
                        description: "Weighted single-leg strength exercise",
                        duration: 60,
                        restDuration: 30,
                        muscleGroups: [.legs],
                        equipment: [.dumbbells],
                        instructions: ["Hold dumbbells at sides", "Step forward into lunge", "Lower back knee toward ground", "Push back to start"],
                        tips: ["Keep front knee over ankle", "Don't let back knee touch ground"]
                    ),
                    Exercise(
                        id: "dumbbell-shoulder-press",
                        name: "Dumbbell Shoulder Press",
                        description: "Shoulder and arm strengthening exercise",
                        duration: 60,
                        restDuration: 30,
                        muscleGroups: [.shoulders, .arms],
                        equipment: [.dumbbells],
                        instructions: ["Sit or stand with dumbbells at shoulders", "Press weights overhead", "Lower with control", "Keep core engaged"],
                        tips: ["Don't arch back", "Press straight up"]
                    ),
                    Exercise(
                        id: "dumbbell-deadlifts",
                        name: "Dumbbell Deadlifts",
                        description: "Posterior chain strengthening exercise",
                        duration: 60,
                        restDuration: 30,
                        muscleGroups: [.back, .legs],
                        equipment: [.dumbbells],
                        instructions: ["Stand with dumbbells at sides", "Hinge at hips to lower weights", "Keep back straight", "Drive hips forward to stand"],
                        tips: ["Keep weights close to body", "Don't round the back"]
                    ),
                    Exercise(
                        id: "dumbbell-bicep-curls",
                        name: "Dumbbell Bicep Curls",
                        description: "Bicep isolation exercise",
                        duration: 45,
                        restDuration: 30,
                        muscleGroups: [.arms],
                        equipment: [.dumbbells],
                        instructions: ["Stand with dumbbells at sides", "Curl weights up to shoulders", "Lower with control", "Keep elbows at sides"],
                        tips: ["Don't swing the weights", "Control the negative"]
                    ),
                    Exercise(
                        id: "dumbbell-tricep-extensions",
                        name: "Dumbbell Tricep Extensions",
                        description: "Tricep isolation exercise",
                        duration: 45,
                        restDuration: 30,
                        muscleGroups: [.arms],
                        equipment: [.dumbbells],
                        instructions: ["Hold dumbbell overhead", "Lower behind head", "Extend back up", "Keep elbows pointing forward"],
                        tips: ["Keep core engaged", "Don't let elbows flare out"]
                    )
                ],
                targetMuscleGroups: [.chest, .legs, .arms, .back, .shoulders],
                estimatedCalories: 380
            ),
            
            // Advanced Workouts
            Workout(
                id: "advanced-challenge-1",
                title: "Ultimate Challenge",
                description: "For advanced users only! A comprehensive 60-minute high-intensity workout that will push your limits.",
                duration: 60,
                difficulty: .advanced,
                requiredEquipment: [.dumbbells, .kettlebells],
                exercises: [
                    Exercise(
                        id: "kettlebell-swings",
                        name: "Kettlebell Swings",
                        description: "Explosive full body exercise",
                        duration: 90,
                        restDuration: 45,
                        muscleGroups: [.fullBody, .core],
                        equipment: [.kettlebells],
                        instructions: ["Stand with feet shoulder-width apart", "Hold kettlebell with both hands", "Hinge at hips and swing back", "Drive hips forward to swing up"],
                        tips: ["Keep core tight", "Use hip drive, not arms"]
                    ),
                    Exercise(
                        id: "dumbbell-thrusters",
                        name: "Dumbbell Thrusters",
                        description: "Combined squat and press",
                        duration: 90,
                        restDuration: 45,
                        muscleGroups: [.fullBody],
                        equipment: [.dumbbells],
                        instructions: ["Hold dumbbells at shoulders", "Squat down", "Drive up and press weights overhead", "Lower weights and repeat"],
                        tips: ["Keep core engaged", "Press straight up"]
                    ),
                    Exercise(
                        id: "kettlebell-goblet-squats",
                        name: "Kettlebell Goblet Squats",
                        description: "Weighted squat variation",
                        duration: 90,
                        restDuration: 45,
                        muscleGroups: [.legs, .core],
                        equipment: [.kettlebells],
                        instructions: ["Hold kettlebell at chest", "Squat down keeping chest up", "Drive through heels to stand", "Keep kettlebell close to body"],
                        tips: ["Keep chest up", "Don't let knees cave inward"]
                    ),
                    Exercise(
                        id: "dumbbell-man-makers",
                        name: "Dumbbell Man Makers",
                        description: "Complex full body exercise",
                        duration: 90,
                        restDuration: 45,
                        muscleGroups: [.fullBody],
                        equipment: [.dumbbells],
                        instructions: ["Start in plank with dumbbells", "Do a push-up", "Row one dumbbell to chest", "Row other dumbbell", "Jump feet to hands", "Stand and press weights overhead"],
                        tips: ["Maintain plank position", "Keep core tight throughout"]
                    ),
                    Exercise(
                        id: "kettlebell-turkish-get-ups",
                        name: "Kettlebell Turkish Get-ups",
                        description: "Complex full body movement",
                        duration: 120,
                        restDuration: 60,
                        muscleGroups: [.fullBody, .core],
                        equipment: [.kettlebells],
                        instructions: ["Lie on back holding kettlebell", "Roll to elbow", "Press to hand", "Bridge hips up", "Sweep leg back to kneeling", "Stand up", "Reverse the movement"],
                        tips: ["Keep eyes on kettlebell", "Move slowly and controlled"]
                    ),
                    Exercise(
                        id: "dumbbell-burpee-to-press",
                        name: "Dumbbell Burpee to Press",
                        description: "Advanced burpee variation",
                        duration: 90,
                        restDuration: 45,
                        muscleGroups: [.fullBody, .cardio],
                        equipment: [.dumbbells],
                        instructions: ["Hold dumbbells at sides", "Drop to push-up position", "Do push-up with dumbbells", "Jump feet to hands", "Stand and press weights overhead"],
                        tips: ["Maintain good form", "Control the movement"]
                    ),
                    Exercise(
                        id: "kettlebell-clean-and-press",
                        name: "Kettlebell Clean and Press",
                        description: "Explosive full body movement",
                        duration: 90,
                        restDuration: 45,
                        muscleGroups: [.fullBody],
                        equipment: [.kettlebells],
                        instructions: ["Start with kettlebell between legs", "Explosively pull to rack position", "Press overhead", "Lower with control", "Return to start"],
                        tips: ["Use hip drive", "Keep kettlebell close to body"]
                    ),
                    Exercise(
                        id: "dumbbell-renegade-rows",
                        name: "Dumbbell Renegade Rows",
                        description: "Core and back strengthening exercise",
                        duration: 90,
                        restDuration: 45,
                        muscleGroups: [.core, .back, .arms],
                        equipment: [.dumbbells],
                        instructions: ["Start in plank with dumbbells", "Row one dumbbell to chest", "Lower and row other", "Keep hips level", "Maintain plank position"],
                        tips: ["Don't let hips rotate", "Keep core tight"]
                    )
                ],
                targetMuscleGroups: [.fullBody],
                estimatedCalories: 650
            ),
            
            // Equipment-specific workouts
            Workout(
                id: "yoga-flow-1",
                title: "Morning Yoga Flow",
                description: "Start your day with this comprehensive 40-minute calming yoga sequence.",
                duration: 40,
                difficulty: .beginner,
                requiredEquipment: [.yogaMat],
                exercises: [
                    Exercise(
                        id: "childs-pose",
                        name: "Child's Pose",
                        description: "Restorative and calming pose",
                        duration: 60,
                        restDuration: 10,
                        muscleGroups: [.fullBody, .flexibility],
                        equipment: [.yogaMat],
                        instructions: ["Kneel on mat", "Sit back on heels", "Fold forward with arms extended", "Rest forehead on mat"],
                        tips: ["Breathe deeply", "Relax completely"]
                    ),
                    Exercise(
                        id: "cat-cow",
                        name: "Cat-Cow Stretch",
                        description: "Spinal mobility exercise",
                        duration: 60,
                        restDuration: 10,
                        muscleGroups: [.back, .core, .flexibility],
                        equipment: [.yogaMat],
                        instructions: ["Start on hands and knees", "Arch back and look up (cow)", "Round spine and look down (cat)", "Flow between poses"],
                        tips: ["Move with breath", "Keep movements smooth"]
                    ),
                    Exercise(
                        id: "downward-dog",
                        name: "Downward Dog",
                        description: "Full body stretch and strength",
                        duration: 90,
                        restDuration: 15,
                        muscleGroups: [.fullBody, .flexibility],
                        equipment: [.yogaMat],
                        instructions: ["Start on hands and knees", "Tuck toes and lift hips", "Straighten legs as much as possible", "Hold position and breathe"],
                        tips: ["Keep spine long", "Press through palms"]
                    ),
                    Exercise(
                        id: "warrior-pose",
                        name: "Warrior I",
                        description: "Strength and balance pose",
                        duration: 60,
                        restDuration: 15,
                        muscleGroups: [.legs, .core],
                        equipment: [.yogaMat],
                        instructions: ["Step one foot forward", "Bend front knee over ankle", "Raise arms overhead", "Hold and breathe deeply"],
                        tips: ["Keep back leg straight", "Square hips forward"]
                    ),
                    Exercise(
                        id: "warrior-ii",
                        name: "Warrior II",
                        description: "Hip opening and strength pose",
                        duration: 60,
                        restDuration: 15,
                        muscleGroups: [.legs, .core],
                        equipment: [.yogaMat],
                        instructions: ["From Warrior I, open hips to side", "Extend arms parallel to floor", "Look over front hand", "Hold and breathe"],
                        tips: ["Keep front knee over ankle", "Engage core"]
                    ),
                    Exercise(
                        id: "triangle-pose",
                        name: "Triangle Pose",
                        description: "Side stretch and balance pose",
                        duration: 60,
                        restDuration: 15,
                        muscleGroups: [.legs, .core, .flexibility],
                        equipment: [.yogaMat],
                        instructions: ["Stand with feet wide apart", "Turn front foot out", "Reach down to shin or floor", "Extend other arm up"],
                        tips: ["Keep both legs straight", "Don't collapse into pose"]
                    ),
                    Exercise(
                        id: "tree-pose",
                        name: "Tree Pose",
                        description: "Balance and focus pose",
                        duration: 60,
                        restDuration: 15,
                        muscleGroups: [.legs, .core],
                        equipment: [.yogaMat],
                        instructions: ["Stand on one leg", "Place other foot on inner thigh", "Bring hands to prayer position", "Hold and breathe"],
                        tips: ["Find a focal point", "Don't place foot on knee"]
                    ),
                    Exercise(
                        id: "bridge-pose",
                        name: "Bridge Pose",
                        description: "Back strengthening and hip opener",
                        duration: 60,
                        restDuration: 15,
                        muscleGroups: [.back, .legs, .core],
                        equipment: [.yogaMat],
                        instructions: ["Lie on back with knees bent", "Lift hips up", "Interlace fingers under body", "Hold and breathe"],
                        tips: ["Keep knees over ankles", "Engage glutes"]
                    ),
                    Exercise(
                        id: "corpse-pose",
                        name: "Corpse Pose",
                        description: "Final relaxation pose",
                        duration: 120,
                        restDuration: 0,
                        muscleGroups: [.fullBody, .flexibility],
                        equipment: [.yogaMat],
                        instructions: ["Lie flat on back", "Arms at sides, palms up", "Close eyes and relax", "Focus on breathing"],
                        tips: ["Let go of all tension", "Stay present"]
                    )
                ],
                targetMuscleGroups: [.fullBody, .flexibility],
                estimatedCalories: 120
            ),
            
            Workout(
                id: "resistance-band-1",
                title: "Resistance Band Power",
                description: "Build strength anywhere with this comprehensive 45-minute resistance band workout.",
                duration: 45,
                difficulty: .intermediate,
                requiredEquipment: [.resistanceBands],
                exercises: [
                    Exercise(
                        id: "band-pull-aparts",
                        name: "Band Pull-aparts",
                        description: "Upper back and shoulder exercise",
                        duration: 60,
                        restDuration: 20,
                        muscleGroups: [.back, .shoulders],
                        equipment: [.resistanceBands],
                        instructions: ["Hold band with both hands", "Start with arms extended", "Pull band apart", "Squeeze shoulder blades together"],
                        tips: ["Keep shoulders down", "Control the movement"]
                    ),
                    Exercise(
                        id: "band-squats",
                        name: "Band Squats",
                        description: "Resistance squat variation",
                        duration: 60,
                        restDuration: 20,
                        muscleGroups: [.legs],
                        equipment: [.resistanceBands],
                        instructions: ["Stand on band with feet shoulder-width apart", "Hold handles at shoulders", "Squat down", "Drive up through heels"],
                        tips: ["Keep chest up", "Don't let knees cave inward"]
                    ),
                    Exercise(
                        id: "band-chest-press",
                        name: "Band Chest Press",
                        description: "Chest and arm strengthening exercise",
                        duration: 60,
                        restDuration: 20,
                        muscleGroups: [.chest, .arms],
                        equipment: [.resistanceBands],
                        instructions: ["Anchor band behind you", "Hold handles at chest level", "Press forward", "Return with control"],
                        tips: ["Keep core engaged", "Press straight forward"]
                    ),
                    Exercise(
                        id: "band-rows",
                        name: "Band Rows",
                        description: "Back and bicep strengthening exercise",
                        duration: 60,
                        restDuration: 20,
                        muscleGroups: [.back, .arms],
                        equipment: [.resistanceBands],
                        instructions: ["Anchor band in front", "Pull handles to chest", "Squeeze shoulder blades", "Return with control"],
                        tips: ["Keep back straight", "Pull with elbows"]
                    ),
                    Exercise(
                        id: "band-lateral-raises",
                        name: "Band Lateral Raises",
                        description: "Shoulder strengthening exercise",
                        duration: 60,
                        restDuration: 20,
                        muscleGroups: [.shoulders],
                        equipment: [.resistanceBands],
                        instructions: ["Stand on band with feet together", "Hold handles at sides", "Raise arms to shoulder height", "Lower with control"],
                        tips: ["Keep slight bend in elbows", "Don't raise above shoulder height"]
                    ),
                    Exercise(
                        id: "band-bicep-curls",
                        name: "Band Bicep Curls",
                        description: "Bicep isolation exercise",
                        duration: 60,
                        restDuration: 20,
                        muscleGroups: [.arms],
                        equipment: [.resistanceBands],
                        instructions: ["Stand on band with feet shoulder-width apart", "Hold handles at sides", "Curl up to shoulders", "Lower with control"],
                        tips: ["Keep elbows at sides", "Control the negative"]
                    ),
                    Exercise(
                        id: "band-tricep-extensions",
                        name: "Band Tricep Extensions",
                        description: "Tricep isolation exercise",
                        duration: 60,
                        restDuration: 20,
                        muscleGroups: [.arms],
                        equipment: [.resistanceBands],
                        instructions: ["Anchor band overhead", "Hold handles behind head", "Extend arms up", "Lower with control"],
                        tips: ["Keep elbows pointing forward", "Don't let elbows flare out"]
                    ),
                    Exercise(
                        id: "band-woodchops",
                        name: "Band Woodchops",
                        description: "Core and rotational strength exercise",
                        duration: 60,
                        restDuration: 20,
                        muscleGroups: [.core, .shoulders],
                        equipment: [.resistanceBands],
                        instructions: ["Anchor band at shoulder height", "Hold handle with both hands", "Pull diagonally across body", "Return with control"],
                        tips: ["Rotate from core", "Keep arms straight"]
                    )
                ],
                targetMuscleGroups: [.legs, .back, .shoulders, .chest, .arms, .core],
                estimatedCalories: 320
            ),
            
            Workout(
                id: "cardio-blast-1",
                title: "Cardio Blast",
                description: "Get your heart pumping with this comprehensive 40-minute high-energy cardio session.",
                duration: 40,
                difficulty: .intermediate,
                requiredEquipment: [.none],
                exercises: [
                    Exercise(
                        id: "jump-squats",
                        name: "Jump Squats",
                        description: "Explosive lower body exercise",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.legs, .cardio],
                        equipment: [.none],
                        instructions: ["Start in squat position", "Jump up explosively", "Land softly in squat", "Immediately jump again"],
                        tips: ["Land with knees slightly bent", "Use arms for momentum"]
                    ),
                    Exercise(
                        id: "lunge-jumps",
                        name: "Lunge Jumps",
                        description: "Dynamic leg exercise",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.legs, .cardio],
                        equipment: [.none],
                        instructions: ["Start in lunge position", "Jump up and switch legs", "Land in opposite lunge", "Continue alternating"],
                        tips: ["Land softly", "Keep knees behind toes"]
                    ),
                    Exercise(
                        id: "high-knees",
                        name: "High Knees",
                        description: "Cardio and leg exercise",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.legs, .cardio],
                        equipment: [.none],
                        instructions: ["Run in place", "Bring knees up high", "Pump arms naturally", "Stay on balls of feet"],
                        tips: ["Keep core engaged", "Maintain upright posture"]
                    ),
                    Exercise(
                        id: "mountain-climbers",
                        name: "Mountain Climbers",
                        description: "Dynamic core and cardio exercise",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.core, .cardio],
                        equipment: [.none],
                        instructions: ["Start in plank position", "Bring knee to chest", "Quickly switch legs", "Maintain plank position"],
                        tips: ["Keep core tight", "Maintain steady pace"]
                    ),
                    Exercise(
                        id: "burpees",
                        name: "Burpees",
                        description: "Full body high-intensity exercise",
                        duration: 60,
                        restDuration: 20,
                        muscleGroups: [.fullBody, .cardio],
                        equipment: [.none],
                        instructions: ["Start standing", "Drop to push-up position", "Do a push-up", "Jump feet to hands", "Jump up with arms overhead"],
                        tips: ["Maintain steady pace", "Land softly on jumps"]
                    ),
                    Exercise(
                        id: "jumping-jacks",
                        name: "Jumping Jacks",
                        description: "Full body cardio exercise",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.cardio, .fullBody],
                        equipment: [.none],
                        instructions: ["Stand with feet together", "Jump up spreading legs", "Raise arms overhead", "Return to starting position"],
                        tips: ["Keep knees slightly bent on landing", "Maintain steady breathing"]
                    ),
                    Exercise(
                        id: "butt-kicks",
                        name: "Butt Kicks",
                        description: "Cardio and leg exercise",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.legs, .cardio],
                        equipment: [.none],
                        instructions: ["Run in place", "Kick heels to glutes", "Pump arms naturally", "Stay on balls of feet"],
                        tips: ["Keep core engaged", "Maintain good posture"]
                    ),
                    Exercise(
                        id: "lateral-shuffles",
                        name: "Lateral Shuffles",
                        description: "Lateral movement and cardio exercise",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.legs, .cardio],
                        equipment: [.none],
                        instructions: ["Start in athletic stance", "Shuffle sideways", "Keep knees bent", "Stay low and quick"],
                        tips: ["Keep weight on balls of feet", "Maintain athletic stance"]
                    )
                ],
                targetMuscleGroups: [.legs, .cardio, .fullBody],
                estimatedCalories: 350
            ),
            
            // Additional Beginner Workouts
            Workout(
                id: "beginner-upper-body-1",
                title: "Upper Body Foundation",
                description: "Build upper body strength with this comprehensive 35-minute beginner workout.",
                duration: 35,
                difficulty: .beginner,
                requiredEquipment: [.none],
                exercises: [
                    Exercise(
                        id: "wall-push-ups",
                        name: "Wall Push-ups",
                        description: "Beginner-friendly push-up variation",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.chest, .arms, .core],
                        equipment: [.none],
                        instructions: ["Stand facing wall", "Place hands on wall at chest height", "Lower chest to wall", "Push back to start"],
                        tips: ["Keep body straight", "Start close to wall for easier version"]
                    ),
                    Exercise(
                        id: "arm-circles",
                        name: "Arm Circles",
                        description: "Shoulder mobility and warm-up exercise",
                        duration: 30,
                        restDuration: 10,
                        muscleGroups: [.shoulders],
                        equipment: [.none],
                        instructions: ["Stand with arms extended", "Make small circles forward", "Reverse direction", "Keep movements controlled"],
                        tips: ["Start with small circles", "Gradually increase size"]
                    ),
                    Exercise(
                        id: "tricep-dips-chair",
                        name: "Chair Tricep Dips",
                        description: "Upper body strength exercise",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.arms],
                        equipment: [.none],
                        instructions: ["Sit on edge of chair", "Place hands beside hips", "Lower body by bending elbows", "Push back up"],
                        tips: ["Keep elbows close to body", "Don't go too low"]
                    ),
                    Exercise(
                        id: "shoulder-taps",
                        name: "Shoulder Taps",
                        description: "Core stability and shoulder exercise",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.core, .shoulders],
                        equipment: [.none],
                        instructions: ["Start in plank position", "Tap left shoulder with right hand", "Return to plank", "Alternate sides"],
                        tips: ["Keep hips level", "Don't let hips rotate"]
                    ),
                    Exercise(
                        id: "pike-push-ups",
                        name: "Pike Push-ups",
                        description: "Shoulder and upper body exercise",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.shoulders, .arms],
                        equipment: [.none],
                        instructions: ["Start in downward dog position", "Lower head toward hands", "Push back up", "Keep legs straight"],
                        tips: ["Keep core engaged", "Don't let hips sag"]
                    ),
                    Exercise(
                        id: "diamond-push-ups",
                        name: "Diamond Push-ups",
                        description: "Tricep-focused push-up variation",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.arms, .chest],
                        equipment: [.none],
                        instructions: ["Start in push-up position", "Place hands in diamond shape", "Lower chest to hands", "Push back up"],
                        tips: ["Keep elbows close to body", "Modify on knees if needed"]
                    ),
                    Exercise(
                        id: "superman",
                        name: "Superman",
                        description: "Back strengthening exercise",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.back],
                        equipment: [.none],
                        instructions: ["Lie face down", "Lift chest and legs off ground", "Hold briefly", "Lower with control"],
                        tips: ["Keep neck neutral", "Don't hyperextend"]
                    )
                ],
                targetMuscleGroups: [.chest, .arms, .shoulders, .back, .core],
                estimatedCalories: 200
            ),
            
            Workout(
                id: "beginner-lower-body-1",
                title: "Lower Body Power",
                description: "Strengthen your legs and glutes with this comprehensive 40-minute beginner workout.",
                duration: 40,
                difficulty: .beginner,
                requiredEquipment: [.none],
                exercises: [
                    Exercise(
                        id: "bodyweight-squats",
                        name: "Bodyweight Squats",
                        description: "Lower body strength exercise",
                        duration: 60,
                        restDuration: 20,
                        muscleGroups: [.legs],
                        equipment: [.none],
                        instructions: ["Stand with feet shoulder-width apart", "Lower down as if sitting in a chair", "Keep chest up and knees behind toes", "Return to standing position"],
                        tips: ["Keep weight on heels", "Don't let knees cave inward"]
                    ),
                    Exercise(
                        id: "lunges",
                        name: "Alternating Lunges",
                        description: "Lower body strength and balance exercise",
                        duration: 60,
                        restDuration: 20,
                        muscleGroups: [.legs],
                        equipment: [.none],
                        instructions: ["Step forward with right leg", "Lower until both knees at 90 degrees", "Push back to starting position", "Alternate legs"],
                        tips: ["Keep front knee over ankle", "Don't let back knee touch ground"]
                    ),
                    Exercise(
                        id: "wall-sit",
                        name: "Wall Sit",
                        description: "Isometric leg strength exercise",
                        duration: 45,
                        restDuration: 20,
                        muscleGroups: [.legs],
                        equipment: [.none],
                        instructions: ["Lean back against wall", "Slide down until knees at 90 degrees", "Hold position", "Keep back flat against wall"],
                        tips: ["Distribute weight evenly", "Breathe normally while holding"]
                    ),
                    Exercise(
                        id: "calf-raises",
                        name: "Calf Raises",
                        description: "Calf strengthening exercise",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.legs],
                        equipment: [.none],
                        instructions: ["Stand with feet hip-width apart", "Rise up on toes", "Lower with control", "Keep core engaged"],
                        tips: ["Control the movement", "Don't bounce"]
                    ),
                    Exercise(
                        id: "glute-bridges",
                        name: "Glute Bridges",
                        description: "Glute and hip strengthening exercise",
                        duration: 60,
                        restDuration: 20,
                        muscleGroups: [.legs],
                        equipment: [.none],
                        instructions: ["Lie on back with knees bent", "Lift hips up", "Squeeze glutes at top", "Lower with control"],
                        tips: ["Keep core engaged", "Don't arch back excessively"]
                    ),
                    Exercise(
                        id: "side-lying-leg-lifts",
                        name: "Side-lying Leg Lifts",
                        description: "Hip abductor strengthening exercise",
                        duration: 45,
                        restDuration: 15,
                        muscleGroups: [.legs],
                        equipment: [.none],
                        instructions: ["Lie on side", "Lift top leg up", "Lower with control", "Keep leg straight"],
                        tips: ["Keep hips stacked", "Don't let hips roll forward"]
                    ),
                    Exercise(
                        id: "step-ups",
                        name: "Step-ups",
                        description: "Functional leg strengthening exercise",
                        duration: 60,
                        restDuration: 20,
                        muscleGroups: [.legs],
                        equipment: [.none],
                        instructions: ["Step up onto step or platform", "Step down with control", "Alternate legs", "Keep core engaged"],
                        tips: ["Use a stable surface", "Control the descent"]
                    ),
                    Exercise(
                        id: "single-leg-deadlifts",
                        name: "Single-leg Deadlifts",
                        description: "Balance and posterior chain exercise",
                        duration: 45,
                        restDuration: 20,
                        muscleGroups: [.legs, .back],
                        equipment: [.none],
                        instructions: ["Stand on one leg", "Hinge at hip to lower torso", "Extend other leg back", "Return to start"],
                        tips: ["Keep back straight", "Don't let knee cave inward"]
                    )
                ],
                targetMuscleGroups: [.legs],
                estimatedCalories: 250
            ),
            
            // Additional Intermediate Workouts
            Workout(
                id: "intermediate-chest-back-1",
                title: "Chest & Back Power",
                description: "Build upper body strength with this comprehensive 50-minute chest and back workout.",
                duration: 50,
                difficulty: .intermediate,
                requiredEquipment: [.dumbbells],
                exercises: [
                    Exercise(
                        id: "dumbbell-bench-press",
                        name: "Dumbbell Bench Press",
                        description: "Chest and arm strengthening exercise",
                        duration: 60,
                        restDuration: 30,
                        muscleGroups: [.chest, .arms],
                        equipment: [.dumbbells],
                        instructions: ["Lie on back with dumbbells", "Press weights up over chest", "Lower with control", "Keep core engaged"],
                        tips: ["Control the weight down", "Press up explosively"]
                    ),
                    Exercise(
                        id: "dumbbell-rows",
                        name: "Dumbbell Rows",
                        description: "Back and bicep strengthening exercise",
                        duration: 60,
                        restDuration: 30,
                        muscleGroups: [.back, .arms],
                        equipment: [.dumbbells],
                        instructions: ["Bend over with dumbbells", "Pull weights to chest", "Squeeze shoulder blades", "Lower with control"],
                        tips: ["Keep back straight", "Pull with elbows, not arms"]
                    ),
                    Exercise(
                        id: "dumbbell-incline-press",
                        name: "Dumbbell Incline Press",
                        description: "Upper chest strengthening exercise",
                        duration: 60,
                        restDuration: 30,
                        muscleGroups: [.chest, .arms],
                        equipment: [.dumbbells],
                        instructions: ["Lie on inclined bench", "Press weights up over chest", "Lower with control", "Keep core engaged"],
                        tips: ["Control the weight down", "Press straight up"]
                    ),
                    Exercise(
                        id: "dumbbell-pullovers",
                        name: "Dumbbell Pullovers",
                        description: "Chest and lat stretching exercise",
                        duration: 60,
                        restDuration: 30,
                        muscleGroups: [.chest, .back],
                        equipment: [.dumbbells],
                        instructions: ["Lie on back holding dumbbell", "Lower weight behind head", "Pull back to chest", "Keep core engaged"],
                        tips: ["Keep slight bend in elbows", "Don't let weight go too far back"]
                    ),
                    Exercise(
                        id: "dumbbell-flyes",
                        name: "Dumbbell Flyes",
                        description: "Chest isolation exercise",
                        duration: 60,
                        restDuration: 30,
                        muscleGroups: [.chest],
                        equipment: [.dumbbells],
                        instructions: ["Lie on back with dumbbells", "Lower weights in arc motion", "Bring weights together over chest", "Control the movement"],
                        tips: ["Keep slight bend in elbows", "Don't let weights go too low"]
                    ),
                    Exercise(
                        id: "dumbbell-reverse-flyes",
                        name: "Dumbbell Reverse Flyes",
                        description: "Rear delt and upper back exercise",
                        duration: 60,
                        restDuration: 30,
                        muscleGroups: [.back, .shoulders],
                        equipment: [.dumbbells],
                        instructions: ["Bend over with dumbbells", "Raise weights out to sides", "Squeeze shoulder blades", "Lower with control"],
                        tips: ["Keep back straight", "Don't use momentum"]
                    ),
                    Exercise(
                        id: "dumbbell-shrugs",
                        name: "Dumbbell Shrugs",
                        description: "Trap strengthening exercise",
                        duration: 60,
                        restDuration: 30,
                        muscleGroups: [.back, .shoulders],
                        equipment: [.dumbbells],
                        instructions: ["Stand with dumbbells at sides", "Shrug shoulders up", "Hold briefly", "Lower with control"],
                        tips: ["Don't roll shoulders", "Keep arms straight"]
                    )
                ],
                targetMuscleGroups: [.chest, .back, .arms, .shoulders],
                estimatedCalories: 400
            ),
            
            Workout(
                id: "intermediate-legs-1",
                title: "Leg Day Destroyer",
                description: "Build powerful legs with this comprehensive 55-minute leg workout.",
                duration: 55,
                difficulty: .intermediate,
                requiredEquipment: [.dumbbells],
                exercises: [
                    Exercise(
                        id: "dumbbell-squats",
                        name: "Dumbbell Squats",
                        description: "Weighted lower body exercise",
                        duration: 90,
                        restDuration: 45,
                        muscleGroups: [.legs],
                        equipment: [.dumbbells],
                        instructions: ["Hold dumbbells at shoulders", "Stand with feet shoulder-width apart", "Lower down as if sitting", "Drive through heels to stand"],
                        tips: ["Keep chest up", "Don't let knees cave inward"]
                    ),
                    Exercise(
                        id: "dumbbell-lunges",
                        name: "Dumbbell Lunges",
                        description: "Weighted single-leg strength exercise",
                        duration: 90,
                        restDuration: 45,
                        muscleGroups: [.legs],
                        equipment: [.dumbbells],
                        instructions: ["Hold dumbbells at sides", "Step forward into lunge", "Lower back knee toward ground", "Push back to start"],
                        tips: ["Keep front knee over ankle", "Don't let back knee touch ground"]
                    ),
                    Exercise(
                        id: "dumbbell-deadlifts",
                        name: "Dumbbell Deadlifts",
                        description: "Posterior chain strengthening exercise",
                        duration: 90,
                        restDuration: 45,
                        muscleGroups: [.back, .legs],
                        equipment: [.dumbbells],
                        instructions: ["Stand with dumbbells at sides", "Hinge at hips to lower weights", "Keep back straight", "Drive hips forward to stand"],
                        tips: ["Keep weights close to body", "Don't round the back"]
                    ),
                    Exercise(
                        id: "dumbbell-bulgarian-split-squats",
                        name: "Bulgarian Split Squats",
                        description: "Single-leg strength exercise",
                        duration: 90,
                        restDuration: 45,
                        muscleGroups: [.legs],
                        equipment: [.dumbbells],
                        instructions: ["Place rear foot on bench", "Hold dumbbells at sides", "Lower into lunge", "Drive up through front heel"],
                        tips: ["Keep front knee over ankle", "Don't let knee cave inward"]
                    ),
                    Exercise(
                        id: "dumbbell-calf-raises",
                        name: "Dumbbell Calf Raises",
                        description: "Weighted calf strengthening exercise",
                        duration: 60,
                        restDuration: 30,
                        muscleGroups: [.legs],
                        equipment: [.dumbbells],
                        instructions: ["Hold dumbbells at sides", "Rise up on toes", "Lower with control", "Keep core engaged"],
                        tips: ["Control the movement", "Don't bounce"]
                    ),
                    Exercise(
                        id: "dumbbell-romanian-deadlifts",
                        name: "Romanian Deadlifts",
                        description: "Hamstring and glute exercise",
                        duration: 90,
                        restDuration: 45,
                        muscleGroups: [.legs, .back],
                        equipment: [.dumbbells],
                        instructions: ["Stand with dumbbells at sides", "Hinge at hips", "Lower weights along legs", "Drive hips forward to stand"],
                        tips: ["Keep back straight", "Feel stretch in hamstrings"]
                    ),
                    Exercise(
                        id: "dumbbell-step-ups",
                        name: "Dumbbell Step-ups",
                        description: "Functional leg strengthening exercise",
                        duration: 90,
                        restDuration: 45,
                        muscleGroups: [.legs],
                        equipment: [.dumbbells],
                        instructions: ["Hold dumbbells at sides", "Step up onto platform", "Step down with control", "Alternate legs"],
                        tips: ["Use a stable surface", "Control the descent"]
                    )
                ],
                targetMuscleGroups: [.legs, .back],
                estimatedCalories: 450
            ),
            
            // Additional Advanced Workouts
            Workout(
                id: "advanced-crossfit-1",
                title: "CrossFit Challenge",
                description: "Test your limits with this intense 60-minute CrossFit-style workout.",
                duration: 60,
                difficulty: .advanced,
                requiredEquipment: [.dumbbells, .kettlebells],
                exercises: [
                    Exercise(
                        id: "dumbbell-thrusters",
                        name: "Dumbbell Thrusters",
                        description: "Combined squat and press",
                        duration: 90,
                        restDuration: 30,
                        muscleGroups: [.fullBody],
                        equipment: [.dumbbells],
                        instructions: ["Hold dumbbells at shoulders", "Squat down", "Drive up and press weights overhead", "Lower weights and repeat"],
                        tips: ["Keep core engaged", "Press straight up"]
                    ),
                    Exercise(
                        id: "kettlebell-swings",
                        name: "Kettlebell Swings",
                        description: "Explosive full body exercise",
                        duration: 90,
                        restDuration: 30,
                        muscleGroups: [.fullBody, .core],
                        equipment: [.kettlebells],
                        instructions: ["Stand with feet shoulder-width apart", "Hold kettlebell with both hands", "Hinge at hips and swing back", "Drive hips forward to swing up"],
                        tips: ["Keep core tight", "Use hip drive, not arms"]
                    ),
                    Exercise(
                        id: "dumbbell-burpee-to-press",
                        name: "Dumbbell Burpee to Press",
                        description: "Advanced burpee variation",
                        duration: 90,
                        restDuration: 30,
                        muscleGroups: [.fullBody, .cardio],
                        equipment: [.dumbbells],
                        instructions: ["Hold dumbbells at sides", "Drop to push-up position", "Do push-up with dumbbells", "Jump feet to hands", "Stand and press weights overhead"],
                        tips: ["Maintain good form", "Control the movement"]
                    ),
                    Exercise(
                        id: "kettlebell-clean-and-press",
                        name: "Kettlebell Clean and Press",
                        description: "Explosive full body movement",
                        duration: 90,
                        restDuration: 30,
                        muscleGroups: [.fullBody],
                        equipment: [.kettlebells],
                        instructions: ["Start with kettlebell between legs", "Explosively pull to rack position", "Press overhead", "Lower with control", "Return to start"],
                        tips: ["Use hip drive", "Keep kettlebell close to body"]
                    ),
                    Exercise(
                        id: "dumbbell-man-makers",
                        name: "Dumbbell Man Makers",
                        description: "Complex full body exercise",
                        duration: 90,
                        restDuration: 30,
                        muscleGroups: [.fullBody],
                        equipment: [.dumbbells],
                        instructions: ["Start in plank with dumbbells", "Do a push-up", "Row one dumbbell to chest", "Row other dumbbell", "Jump feet to hands", "Stand and press weights overhead"],
                        tips: ["Maintain plank position", "Keep core tight throughout"]
                    ),
                    Exercise(
                        id: "kettlebell-turkish-get-ups",
                        name: "Kettlebell Turkish Get-ups",
                        description: "Complex full body movement",
                        duration: 120,
                        restDuration: 60,
                        muscleGroups: [.fullBody, .core],
                        equipment: [.kettlebells],
                        instructions: ["Lie on back holding kettlebell", "Roll to elbow", "Press to hand", "Bridge hips up", "Sweep leg back to kneeling", "Stand up", "Reverse the movement"],
                        tips: ["Keep eyes on kettlebell", "Move slowly and controlled"]
                    )
                ],
                targetMuscleGroups: [.fullBody],
                estimatedCalories: 700
            ),
            
            // Specialized Workouts
            Workout(
                id: "pilates-core-1",
                title: "Pilates Core Flow",
                description: "Strengthen your core with this comprehensive 45-minute Pilates workout.",
                duration: 45,
                difficulty: .intermediate,
                requiredEquipment: [.yogaMat],
                exercises: [
                    Exercise(
                        id: "pilates-hundred",
                        name: "Pilates Hundred",
                        description: "Core and breathing exercise",
                        duration: 60,
                        restDuration: 15,
                        muscleGroups: [.core],
                        equipment: [.yogaMat],
                        instructions: ["Lie on back with knees bent", "Lift head and shoulders", "Extend arms and pump them", "Breathe in for 5 pumps, out for 5"],
                        tips: ["Keep lower back pressed down", "Maintain steady breathing"]
                    ),
                    Exercise(
                        id: "pilates-roll-up",
                        name: "Pilates Roll-up",
                        description: "Spinal articulation exercise",
                        duration: 60,
                        restDuration: 15,
                        muscleGroups: [.core, .back],
                        equipment: [.yogaMat],
                        instructions: ["Lie on back with arms overhead", "Roll up vertebra by vertebra", "Reach for toes", "Roll back down slowly"],
                        tips: ["Keep legs straight", "Control the movement"]
                    ),
                    Exercise(
                        id: "pilates-single-leg-circles",
                        name: "Single Leg Circles",
                        description: "Hip mobility and core exercise",
                        duration: 60,
                        restDuration: 15,
                        muscleGroups: [.core, .legs],
                        equipment: [.yogaMat],
                        instructions: ["Lie on back with one leg up", "Make small circles with leg", "Reverse direction", "Keep other leg still"],
                        tips: ["Keep hips stable", "Don't let back arch"]
                    ),
                    Exercise(
                        id: "pilates-double-leg-stretch",
                        name: "Double Leg Stretch",
                        description: "Core coordination exercise",
                        duration: 60,
                        restDuration: 15,
                        muscleGroups: [.core],
                        equipment: [.yogaMat],
                        instructions: ["Lie on back with knees to chest", "Extend arms and legs", "Circle arms back to knees", "Keep head lifted"],
                        tips: ["Keep lower back pressed down", "Coordinate breath with movement"]
                    ),
                    Exercise(
                        id: "pilates-criss-cross",
                        name: "Criss Cross",
                        description: "Oblique strengthening exercise",
                        duration: 60,
                        restDuration: 15,
                        muscleGroups: [.core],
                        equipment: [.yogaMat],
                        instructions: ["Lie on back with hands behind head", "Bring knees to chest", "Rotate to bring elbow to opposite knee", "Switch sides"],
                        tips: ["Don't pull on neck", "Rotate from core"]
                    ),
                    Exercise(
                        id: "pilates-saw",
                        name: "Pilates Saw",
                        description: "Spinal rotation and stretch",
                        duration: 60,
                        restDuration: 15,
                        muscleGroups: [.core, .back],
                        equipment: [.yogaMat],
                        instructions: ["Sit with legs wide apart", "Rotate to reach opposite foot", "Saw motion with arm", "Return to center"],
                        tips: ["Keep spine long", "Rotate from waist"]
                    ),
                    Exercise(
                        id: "pilates-swan",
                        name: "Pilates Swan",
                        description: "Back extension exercise",
                        duration: 60,
                        restDuration: 15,
                        muscleGroups: [.back, .core],
                        equipment: [.yogaMat],
                        instructions: ["Lie face down with hands under shoulders", "Press up to extend spine", "Lower with control", "Keep legs together"],
                        tips: ["Don't hyperextend", "Keep neck neutral"]
                    )
                ],
                targetMuscleGroups: [.core, .back],
                estimatedCalories: 200
            ),
            
            Workout(
                id: "tabata-hiit-1",
                title: "Tabata HIIT Blast",
                description: "Maximum intensity in minimal time with this 30-minute Tabata workout.",
                duration: 30,
                difficulty: .advanced,
                requiredEquipment: [.none],
                exercises: [
                    Exercise(
                        id: "tabata-burpees",
                        name: "Tabata Burpees",
                        description: "20 seconds work, 10 seconds rest",
                        duration: 20,
                        restDuration: 10,
                        muscleGroups: [.fullBody, .cardio],
                        equipment: [.none],
                        instructions: ["Start standing", "Drop to push-up position", "Do a push-up", "Jump feet to hands", "Jump up with arms overhead"],
                        tips: ["Maintain maximum intensity", "Use full range of motion"]
                    ),
                    Exercise(
                        id: "tabata-mountain-climbers",
                        name: "Tabata Mountain Climbers",
                        description: "20 seconds work, 10 seconds rest",
                        duration: 20,
                        restDuration: 10,
                        muscleGroups: [.core, .cardio],
                        equipment: [.none],
                        instructions: ["Start in plank position", "Bring knee to chest", "Quickly switch legs", "Maintain plank position"],
                        tips: ["Keep core tight", "Maintain maximum pace"]
                    ),
                    Exercise(
                        id: "tabata-jump-squats",
                        name: "Tabata Jump Squats",
                        description: "20 seconds work, 10 seconds rest",
                        duration: 20,
                        restDuration: 10,
                        muscleGroups: [.legs, .cardio],
                        equipment: [.none],
                        instructions: ["Start in squat position", "Jump up explosively", "Land softly in squat", "Immediately jump again"],
                        tips: ["Land with knees slightly bent", "Use arms for momentum"]
                    ),
                    Exercise(
                        id: "tabata-high-knees",
                        name: "Tabata High Knees",
                        description: "20 seconds work, 10 seconds rest",
                        duration: 20,
                        restDuration: 10,
                        muscleGroups: [.legs, .cardio],
                        equipment: [.none],
                        instructions: ["Run in place", "Bring knees up high", "Pump arms naturally", "Stay on balls of feet"],
                        tips: ["Keep core engaged", "Maintain maximum intensity"]
                    ),
                    Exercise(
                        id: "tabata-push-ups",
                        name: "Tabata Push-ups",
                        description: "20 seconds work, 10 seconds rest",
                        duration: 20,
                        restDuration: 10,
                        muscleGroups: [.chest, .arms, .core],
                        equipment: [.none],
                        instructions: ["Start in plank position", "Lower chest to ground", "Push back up to starting position", "Keep body straight throughout"],
                        tips: ["Maintain good form", "Use full range of motion"]
                    ),
                    Exercise(
                        id: "tabata-lunge-jumps",
                        name: "Tabata Lunge Jumps",
                        description: "20 seconds work, 10 seconds rest",
                        duration: 20,
                        restDuration: 10,
                        muscleGroups: [.legs, .cardio],
                        equipment: [.none],
                        instructions: ["Start in lunge position", "Jump up and switch legs", "Land in opposite lunge", "Continue alternating"],
                        tips: ["Land softly", "Keep knees behind toes"]
                    ),
                    Exercise(
                        id: "tabata-plank",
                        name: "Tabata Plank",
                        description: "20 seconds work, 10 seconds rest",
                        duration: 20,
                        restDuration: 10,
                        muscleGroups: [.core],
                        equipment: [.none],
                        instructions: ["Start in push-up position", "Hold body straight", "Engage core muscles", "Breathe normally"],
                        tips: ["Keep hips level", "Don't let hips sag or pike up"]
                    ),
                    Exercise(
                        id: "tabata-jumping-jacks",
                        name: "Tabata Jumping Jacks",
                        description: "20 seconds work, 10 seconds rest",
                        duration: 20,
                        restDuration: 10,
                        muscleGroups: [.cardio, .fullBody],
                        equipment: [.none],
                        instructions: ["Stand with feet together", "Jump up spreading legs", "Raise arms overhead", "Return to starting position"],
                        tips: ["Keep knees slightly bent on landing", "Maintain steady breathing"]
                    )
                ],
                targetMuscleGroups: [.fullBody, .cardio],
                estimatedCalories: 400
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
    
    // MARK: - ExerciseDB Integration Methods
    
    func createCustomWorkout(
        name: String,
        description: String,
        duration: Int,
        difficulty: WorkoutDifficulty,
        targetMuscleGroups: [MuscleGroup],
        equipment: [Equipment]
    ) -> Workout? {
        return workoutBuilder.createCustomWorkout(
            name: name,
            description: description,
            duration: duration,
            difficulty: difficulty,
            targetMuscleGroups: targetMuscleGroups,
            equipment: equipment
        )
    }
    
    func searchExercises(query: String) -> [ExerciseDBExercise] {
        return exerciseDBService.searchExercises(query: query)
    }
    
    func getExercisesForMuscleGroup(_ muscleGroup: String) -> [ExerciseDBExercise] {
        return exerciseDBService.getExercisesForMuscleGroup(muscleGroup)
    }
    
    func getExercisesForEquipment(_ equipment: String) -> [ExerciseDBExercise] {
        return exerciseDBService.getExercisesForEquipment(equipment)
    }
    
    func refreshExerciseDBData() async {
        await exerciseDBService.fetchAndCacheExercises()
    }
    
    var exerciseDBCacheStatus: String {
        if exerciseDBService.cachedExercises.isEmpty {
            return "No cached exercises"
        } else {
            return "\(exerciseDBService.cachedExercises.count) exercises cached"
        }
    }
}

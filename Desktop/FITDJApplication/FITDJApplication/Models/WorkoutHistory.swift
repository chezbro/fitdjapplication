import Foundation

// MARK: - D-005: Workout History Data Model

struct WorkoutHistory: Codable, Identifiable {
    let id: String
    let workoutId: String
    let workoutName: String
    let completedAt: Date
    let duration: TimeInterval // Actual time taken
    let plannedDuration: TimeInterval // Planned workout duration
    let exercisesCompleted: Int
    let totalExercises: Int
    let intensity: WorkoutIntensity
    let caloriesBurned: Int? // Optional, can be estimated
    let notes: String? // Optional user notes
    
    init(
        workoutId: String,
        workoutName: String,
        duration: TimeInterval,
        plannedDuration: TimeInterval,
        exercisesCompleted: Int,
        totalExercises: Int,
        intensity: WorkoutIntensity,
        caloriesBurned: Int? = nil,
        notes: String? = nil
    ) {
        self.id = UUID().uuidString
        self.workoutId = workoutId
        self.workoutName = workoutName
        self.completedAt = Date()
        self.duration = duration
        self.plannedDuration = plannedDuration
        self.exercisesCompleted = exercisesCompleted
        self.totalExercises = totalExercises
        self.intensity = intensity
        self.caloriesBurned = caloriesBurned
        self.notes = notes
    }
}

// MARK: - Workout Statistics

struct WorkoutStats {
    let totalWorkouts: Int
    let totalDuration: TimeInterval
    let currentStreak: Int
    let longestStreak: Int
    let averageWorkoutDuration: TimeInterval
    let favoriteIntensity: WorkoutIntensity
    let lastWorkoutDate: Date?
    
    var formattedTotalDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = Int(totalDuration) % 3600 / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var formattedAverageDuration: String {
        let minutes = Int(averageWorkoutDuration) / 60
        return "\(minutes)m"
    }
}

// MARK: - Streak Calculation

extension WorkoutStats {
    static func calculateStreak(from history: [WorkoutHistory]) -> (current: Int, longest: Int) {
        guard !history.isEmpty else { return (0, 0) }
        
        let sortedHistory = history.sorted { $0.completedAt > $1.completedAt }
        let calendar = Calendar.current
        
        var currentStreak = 0
        var longestStreak = 0
        var tempStreak = 0
        var lastWorkoutDate: Date?
        
        for workout in sortedHistory {
            let workoutDate = calendar.startOfDay(for: workout.completedAt)
            
            if let lastDate = lastWorkoutDate {
                let daysBetween = calendar.dateComponents([.day], from: workoutDate, to: lastDate).day ?? 0
                
                if daysBetween == 1 {
                    // Consecutive day
                    tempStreak += 1
                } else if daysBetween == 0 {
                    // Same day, don't break streak
                    continue
                } else {
                    // Streak broken
                    longestStreak = max(longestStreak, tempStreak)
                    if currentStreak == 0 {
                        currentStreak = tempStreak
                    }
                    tempStreak = 1
                }
            } else {
                // First workout
                tempStreak = 1
                currentStreak = 1
            }
            
            lastWorkoutDate = workoutDate
        }
        
        longestStreak = max(longestStreak, tempStreak)
        if currentStreak == 0 {
            currentStreak = tempStreak
        }
        
        return (currentStreak, longestStreak)
    }
}

import Foundation
import Combine

// MARK: - F-008: Progress Tracking Service

@MainActor
class ProgressTrackingService: ObservableObject {
    @Published var workoutHistory: [WorkoutHistory] = []
    @Published var currentStats: WorkoutStats?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Computed properties for easy access
    var totalWorkouts: Int {
        currentStats?.totalWorkouts ?? 0
    }
    
    var totalMinutes: Int {
        Int((currentStats?.totalDuration ?? 0) / 60)
    }
    
    var weeklyWorkouts: Int {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        return workoutHistory.filter { $0.completedAt >= weekAgo }.count
    }
    
    @Published var currentStreak: Int = 0
    @Published var recentWorkouts: [WorkoutHistory] = []
    
    private let userDefaults = UserDefaults.standard
    private let workoutHistoryKey = "workoutHistory"
    
    init() {
        loadWorkoutHistory()
        updateStats()
    }
    
    // MARK: - Public Methods
    
    func saveWorkoutCompletion(_ history: WorkoutHistory) {
        workoutHistory.append(history)
        saveWorkoutHistory()
        updateStats()
        
        // Notify streak service of new workout
        NotificationCenter.default.post(
            name: NSNotification.Name("WorkoutCompleted"),
            object: history
        )
        
        print("📊 Workout completed: \(history.workoutName) - \(history.duration/60) minutes")
    }
    
    func getWorkoutHistory() -> [WorkoutHistory] {
        return workoutHistory
    }
    
    func getStats() -> WorkoutStats? {
        return currentStats
    }
    
    func clearHistory() {
        workoutHistory.removeAll()
        saveWorkoutHistory()
        updateStats()
    }
    
    func loadProgressData() {
        loadWorkoutHistory()
        updateStats()
    }
    
    // MARK: - Private Methods
    
    private func loadWorkoutHistory() {
        guard let data = userDefaults.data(forKey: workoutHistoryKey),
              let history = try? JSONDecoder().decode([WorkoutHistory].self, from: data) else {
            print("📊 No workout history found, starting fresh")
            return
        }
        
        workoutHistory = history
        print("📊 Loaded \(history.count) workout records")
    }
    
    private func saveWorkoutHistory() {
        do {
            let data = try JSONEncoder().encode(workoutHistory)
            userDefaults.set(data, forKey: workoutHistoryKey)
            print("📊 Saved \(workoutHistory.count) workout records")
        } catch {
            print("❌ Failed to save workout history: \(error.localizedDescription)")
            errorMessage = "Failed to save workout history"
        }
    }
    
    private func updateStats() {
        guard !workoutHistory.isEmpty else {
            currentStats = WorkoutStats(
                totalWorkouts: 0,
                totalDuration: 0,
                currentStreak: 0,
                longestStreak: 0,
                averageWorkoutDuration: 0,
                favoriteIntensity: .normal,
                lastWorkoutDate: nil
            )
            currentStreak = 0
            recentWorkouts = []
            return
        }
        
        let totalWorkouts = workoutHistory.count
        let totalDuration = workoutHistory.reduce(0) { $0 + $1.duration }
        let averageDuration = totalDuration / Double(totalWorkouts)
        
        let streakData = WorkoutStats.calculateStreak(from: workoutHistory)
        
        // Find favorite intensity
        let intensityCounts = Dictionary(grouping: workoutHistory, by: { $0.intensity })
        let favoriteIntensity = intensityCounts.max { $0.value.count < $1.value.count }?.key ?? .normal
        
        let lastWorkoutDate = workoutHistory.max { $0.completedAt < $1.completedAt }?.completedAt
        
        currentStats = WorkoutStats(
            totalWorkouts: totalWorkouts,
            totalDuration: totalDuration,
            currentStreak: streakData.current,
            longestStreak: streakData.longest,
            averageWorkoutDuration: averageDuration,
            favoriteIntensity: favoriteIntensity,
            lastWorkoutDate: lastWorkoutDate
        )
        
        // Update published properties
        currentStreak = streakData.current
        
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        recentWorkouts = workoutHistory.filter { $0.completedAt >= weekAgo }
        
        print("📊 Updated stats: \(totalWorkouts) workouts, \(streakData.current) day streak")
    }
}

// MARK: - Workout Completion Helper

extension ProgressTrackingService {
    func createWorkoutHistory(
        from workout: Workout,
        duration: TimeInterval,
        exercisesCompleted: Int,
        intensity: WorkoutIntensity
    ) -> WorkoutHistory {
        return WorkoutHistory(
            workoutId: workout.id,
            workoutName: workout.title,
            duration: duration,
            plannedDuration: TimeInterval(workout.duration * 60), // Convert minutes to seconds
            exercisesCompleted: exercisesCompleted,
            totalExercises: workout.exercises.count,
            intensity: intensity,
            caloriesBurned: estimateCaloriesBurned(duration: duration, intensity: intensity),
            notes: nil
        )
    }
    
    private func estimateCaloriesBurned(duration: TimeInterval, intensity: WorkoutIntensity) -> Int {
        // Rough estimation based on duration and intensity
        let baseCaloriesPerMinute: Double
        switch intensity {
        case .veryEasy: baseCaloriesPerMinute = 3.0
        case .easy: baseCaloriesPerMinute = 4.0
        case .normal: baseCaloriesPerMinute = 5.0
        case .hard: baseCaloriesPerMinute = 6.0
        case .veryHard: baseCaloriesPerMinute = 7.0
        }
        
        let minutes = duration / 60
        return Int(minutes * baseCaloriesPerMinute)
    }
}

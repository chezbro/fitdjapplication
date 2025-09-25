import SwiftUI

// MARK: - S-007: Workout Complete Screen

struct WorkoutCompleteView: View {
    let workout: Workout
    let duration: TimeInterval
    let exercisesCompleted: Int
    let intensity: WorkoutIntensity
    let onReturnToLibrary: () -> Void
    
    @StateObject private var progressService = ProgressTrackingService()
    @State private var showingShareSheet = false
    @State private var shareText = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.green)
                        
                        Text("Workout Complete!")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(workout.title)
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Stats Cards
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        StatCard(
                            title: "Duration",
                            value: formatDuration(duration),
                            icon: "clock.fill"
                        )
                        
                        StatCard(
                            title: "Exercises",
                            value: "\(exercisesCompleted)/\(workout.exercises.count)",
                            icon: "figure.strengthtraining.traditional"
                        )
                        
                        StatCard(
                            title: "Intensity",
                            value: intensity.displayName,
                            icon: "flame.fill"
                        )
                        
                        if let totalWorkouts = progressService.currentStats?.totalWorkouts {
                            StatCard(
                                title: "Total Workouts",
                                value: "\(totalWorkouts)",
                                icon: "chart.line.uptrend.xyaxis"
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Progress Section
                    if let stats = progressService.currentStats {
                        VStack(spacing: 20) {
                            Text("Your Progress")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            ProgressStatsView(stats: stats)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                    
                    // Action Buttons
                    VStack(spacing: 16) {
                        Button(action: {
                            shareWorkout()
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Achievement")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        
                        Button(action: onReturnToLibrary) {
                            HStack {
                                Image(systemName: "house.fill")
                                Text("Back to Workouts")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            saveWorkoutCompletion()
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [shareText])
        }
    }
    
    // MARK: - Private Methods
    
    private func saveWorkoutCompletion() {
        let history = progressService.createWorkoutHistory(
            from: workout,
            duration: duration,
            exercisesCompleted: exercisesCompleted,
            intensity: intensity
        )
        progressService.saveWorkoutCompletion(history)
    }
    
    private func shareWorkout() {
        let durationText = formatDuration(duration)
        let intensityText = intensity.displayName
        
        shareText = """
        🏋️‍♀️ Just completed a \(intensityText) workout: \(workout.title)!
        
        ⏱️ Duration: \(durationText)
        💪 Exercises: \(exercisesCompleted)/\(workout.exercises.count)
        
        Feeling strong and motivated! 💪
        
        #FITDJ #WorkoutComplete #Fitness
        """
        
        showingShareSheet = true
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Supporting Views

struct ProgressStatsView: View {
    let stats: WorkoutStats
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Current Streak")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(stats.currentStreak) days")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Longest Streak")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(stats.longestStreak) days")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                }
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Total Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(stats.formattedTotalDuration)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Avg Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(stats.formattedAverageDuration)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - WorkoutIntensity Extension

extension WorkoutIntensity {
    var displayName: String {
        switch self {
        case .veryEasy: return "Very Easy"
        case .easy: return "Easy"
        case .normal: return "Normal"
        case .hard: return "Hard"
        case .veryHard: return "Very Hard"
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
            )
        ],
        targetMuscleGroups: [.fullBody, .cardio],
        estimatedCalories: 120
    )
    
    WorkoutCompleteView(
        workout: sampleWorkout,
        duration: 1800, // 30 minutes
        exercisesCompleted: 8,
        intensity: .normal,
        onReturnToLibrary: {}
    )
}

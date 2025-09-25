//
//  StreakService.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - B-010: Streak Tracking Service

class StreakService: ObservableObject {
    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    @Published var streakStartDate: Date?
    @Published var lastWorkoutDate: Date?
    @Published var streakMilestones: [StreakMilestone] = []
    
    private let userDefaults = UserDefaults.standard
    private let streakKey = "streakData"
    private let milestonesKey = "streakMilestones"
    
    init() {
        loadStreakData()
        loadMilestones()
        
        // Listen for workout completions
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("WorkoutCompleted"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let history = notification.object as? WorkoutHistory,
               let strongSelf = self {
                Task { @MainActor in
                    strongSelf.updateStreak(for: history.completedAt)
                }
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    @MainActor
    func updateStreak(for workoutDate: Date) {
        let calendar = Calendar.current
        let workoutDay = calendar.startOfDay(for: workoutDate)
        
        // Check if this is a new day workout
        if let lastDate = lastWorkoutDate {
            let lastWorkoutDay = calendar.startOfDay(for: lastDate)
            let daysBetween = calendar.dateComponents([.day], from: lastWorkoutDay, to: workoutDay).day ?? 0
            
            if daysBetween == 1 {
                // Consecutive day - increment streak
                currentStreak += 1
            } else if daysBetween == 0 {
                // Same day - don't change streak
                return
            } else {
                // Streak broken - reset to 1
                currentStreak = 1
                streakStartDate = workoutDay
            }
        } else {
            // First workout
            currentStreak = 1
            streakStartDate = workoutDay
        }
        
        lastWorkoutDate = workoutDate
        longestStreak = max(longestStreak, currentStreak)
        
        checkForMilestones()
        saveStreakData()
        
        print("🔥 Streak updated: \(currentStreak) days (longest: \(longestStreak))")
    }
    
    func getStreakStatus() -> StreakStatus {
        guard let lastDate = lastWorkoutDate else {
            return .noWorkouts
        }
        
        let calendar = Calendar.current
        let daysSinceLastWorkout = calendar.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
        
        if daysSinceLastWorkout == 0 {
            return .active(currentStreak)
        } else if daysSinceLastWorkout == 1 {
            return .atRisk(currentStreak)
        } else {
            return .broken
        }
    }
    
    func getStreakMotivation() -> String {
        let status = getStreakStatus()
        
        switch status {
        case .noWorkouts:
            return "Start your fitness journey today! 🚀"
        case .active(let streak):
            if streak >= 7 {
                return "You're on fire! \(streak) days strong! 🔥"
            } else if streak >= 3 {
                return "Great momentum! Keep it up! 💪"
            } else {
                return "You're building a habit! Keep going! ⭐"
            }
        case .atRisk(let streak):
            return "Don't break your \(streak) day streak! You've got this! 🎯"
        case .broken:
            return "Time to start a new streak! Every day is a fresh start! 🌟"
        }
    }
    
    func getStreakEmoji() -> String {
        let streak = currentStreak
        
        switch streak {
        case 0: return "🌱"
        case 1...2: return "⭐"
        case 3...6: return "💪"
        case 7...13: return "🔥"
        case 14...29: return "🚀"
        case 30...99: return "🏆"
        default: return "👑"
        }
    }
    
    func resetStreak() {
        currentStreak = 0
        streakStartDate = nil
        saveStreakData()
        print("🔄 Streak reset")
    }
    
    // MARK: - Milestone System
    
    private func checkForMilestones() {
        let milestones = [
            StreakMilestone(days: 3, title: "Getting Started", description: "3 days in a row!", emoji: "⭐", isUnlocked: currentStreak >= 3),
            StreakMilestone(days: 7, title: "One Week Strong", description: "A full week of workouts!", emoji: "🔥", isUnlocked: currentStreak >= 7),
            StreakMilestone(days: 14, title: "Two Week Warrior", description: "Two weeks of consistency!", emoji: "💪", isUnlocked: currentStreak >= 14),
            StreakMilestone(days: 30, title: "Monthly Master", description: "A full month of dedication!", emoji: "🏆", isUnlocked: currentStreak >= 30),
            StreakMilestone(days: 60, title: "Two Month Titan", description: "Two months of commitment!", emoji: "🚀", isUnlocked: currentStreak >= 60),
            StreakMilestone(days: 100, title: "Century Champion", description: "100 days of excellence!", emoji: "👑", isUnlocked: currentStreak >= 100)
        ]
        
        streakMilestones = milestones
        saveMilestones()
    }
    
    private func loadMilestones() {
        guard let data = userDefaults.data(forKey: milestonesKey),
              let milestones = try? JSONDecoder().decode([StreakMilestone].self, from: data) else {
            checkForMilestones()
            return
        }
        streakMilestones = milestones
    }
    
    private func saveMilestones() {
        do {
            let data = try JSONEncoder().encode(streakMilestones)
            userDefaults.set(data, forKey: milestonesKey)
        } catch {
            print("❌ Failed to save milestones: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func loadStreakData() {
        guard let data = userDefaults.data(forKey: streakKey),
              let streakData = try? JSONDecoder().decode(StreakData.self, from: data) else {
            print("📊 No streak data found, starting fresh")
            return
        }
        
        currentStreak = streakData.currentStreak
        longestStreak = streakData.longestStreak
        streakStartDate = streakData.streakStartDate
        lastWorkoutDate = streakData.lastWorkoutDate
        
        print("📊 Loaded streak: \(currentStreak) days (longest: \(longestStreak))")
    }
    
    private func saveStreakData() {
        let streakData = StreakData(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            streakStartDate: streakStartDate,
            lastWorkoutDate: lastWorkoutDate
        )
        
        do {
            let data = try JSONEncoder().encode(streakData)
            userDefaults.set(data, forKey: streakKey)
            print("📊 Saved streak data")
        } catch {
            print("❌ Failed to save streak data: \(error)")
        }
    }
}

// MARK: - Supporting Types

struct StreakData: Codable {
    let currentStreak: Int
    let longestStreak: Int
    let streakStartDate: Date?
    let lastWorkoutDate: Date?
}

struct StreakMilestone: Codable, Identifiable {
    let id = UUID()
    let days: Int
    let title: String
    let description: String
    let emoji: String
    let isUnlocked: Bool
    
    enum CodingKeys: String, CodingKey {
        case days, title, description, emoji, isUnlocked
    }
}

enum StreakStatus {
    case noWorkouts
    case active(Int)
    case atRisk(Int)
    case broken
}

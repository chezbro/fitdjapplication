//
//  NotificationService.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import Foundation
import UserNotifications
import SwiftUI
import Combine

// MARK: - B-010: Push Reminders Service

@MainActor
class NotificationService: ObservableObject {
    @Published var isAuthorized = false
    @Published var reminderTime: Date = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
    @Published var isReminderEnabled = true
    
    private let center = UNUserNotificationCenter.current()
    
    init() {
        checkAuthorizationStatus()
    }
    
    // MARK: - Public Methods
    
    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            return granted
        } catch {
            print("❌ Failed to request notification permission: \(error)")
            return false
        }
    }
    
    func scheduleWorkoutReminder() {
        guard isAuthorized && isReminderEnabled else { return }
        
        // Remove existing reminders
        center.removePendingNotificationRequests(withIdentifiers: ["workout_reminder"])
        
        let content = UNMutableNotificationContent()
        content.title = "Time for Your Workout! 💪"
        content.body = "You're on a \(getCurrentStreak()) day streak! Don't break it now."
        content.sound = .default
        content.badge = 1
        
        // Schedule for the set reminder time
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: reminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "workout_reminder",
            content: content,
            trigger: trigger
        )
        
        let scheduledTime = reminderTime
        center.add(request) { error in
            if let error = error {
                print("❌ Failed to schedule reminder: \(error)")
            } else {
                print("✅ Workout reminder scheduled for \(scheduledTime)")
            }
        }
    }
    
    func scheduleStreakReminder() {
        guard isAuthorized else { return }
        
        // Schedule a reminder if user hasn't worked out in 2 days
        let content = UNMutableNotificationContent()
        content.title = "Don't Break Your Streak! 🔥"
        content.body = "You're on a \(getCurrentStreak()) day streak. Keep it going!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2 * 24 * 60 * 60, repeats: false)
        let request = UNNotificationRequest(
            identifier: "streak_reminder",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("❌ Failed to schedule streak reminder: \(error)")
            } else {
                print("✅ Streak reminder scheduled")
            }
        }
    }
    
    func scheduleMotivationalMessage() {
        guard isAuthorized else { return }
        
        let messages = [
            "Ready to crush your workout today? 💪",
            "Your future self will thank you! 🌟",
            "Every workout counts - you've got this! 🚀",
            "Time to show yourself what you're made of! ⚡",
            "Consistency is key - let's do this! 🎯"
        ]
        
        let randomMessage = messages.randomElement() ?? messages[0]
        
        let content = UNMutableNotificationContent()
        content.title = "FITDJ Motivation"
        content.body = randomMessage
        content.sound = .default
        
        // Schedule for random time between 6 AM and 10 PM
        let randomHour = Int.random(in: 6...22)
        let randomMinute = Int.random(in: 0...59)
        
        var components = DateComponents()
        components.hour = randomHour
        components.minute = randomMinute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "motivational_message",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("❌ Failed to schedule motivational message: \(error)")
            } else {
                print("✅ Motivational message scheduled")
            }
        }
    }
    
    func cancelAllReminders() {
        center.removeAllPendingNotificationRequests()
        print("✅ All reminders cancelled")
    }
    
    func updateReminderTime(_ newTime: Date) {
        reminderTime = newTime
        if isReminderEnabled {
            scheduleWorkoutReminder()
        }
    }
    
    func toggleReminder(_ enabled: Bool) {
        isReminderEnabled = enabled
        if enabled {
            scheduleWorkoutReminder()
        } else {
            center.removePendingNotificationRequests(withIdentifiers: ["workout_reminder"])
        }
    }
    
    // MARK: - Private Methods
    
    private func checkAuthorizationStatus() {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    private func getCurrentStreak() -> Int {
        // This would typically get the streak from ProgressTrackingService
        // For now, return a placeholder
        return 3
    }
}

// MARK: - Notification Categories

extension NotificationService {
    func setupNotificationCategories() {
        let workoutAction = UNNotificationAction(
            identifier: "START_WORKOUT",
            title: "Start Workout",
            options: [.foreground]
        )
        
        let laterAction = UNNotificationAction(
            identifier: "REMIND_LATER",
            title: "Remind Later",
            options: []
        )
        
        let workoutCategory = UNNotificationCategory(
            identifier: "WORKOUT_REMINDER",
            actions: [workoutAction, laterAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        center.setNotificationCategories([workoutCategory])
    }
}

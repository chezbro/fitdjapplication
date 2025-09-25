//
//  UserProfile.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import Foundation

// D-004: User profile with goals, equipment, and preferences
// D-006: Subscription status and trial dates
struct UserProfile: Codable, Identifiable {
    let id: String
    let email: String?
    let fullName: String?
    var goals: [WorkoutGoal]
    var availableEquipment: [Equipment]
    var musicPreference: MusicPreference
    var isSpotifyConnected: Bool
    var hasSkippedSpotify: Bool
    var dateCreated: Date
    var lastWorkoutDate: Date?
    
    // Subscription tracking
    var subscriptionStatus: SubscriptionStatus
    var trialStartDate: Date?
    var trialEndDate: Date?
    var subscriptionStartDate: Date?
    var subscriptionEndDate: Date?
    
    init(id: String, email: String? = nil, fullName: String? = nil) {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.goals = []
        self.availableEquipment = []
        self.musicPreference = .highEnergy
        self.isSpotifyConnected = false
        self.hasSkippedSpotify = false
        self.dateCreated = Date()
        self.lastWorkoutDate = nil
        
        // Initialize subscription with free trial
        self.subscriptionStatus = .trial
        self.trialStartDate = Date()
        self.trialEndDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())
        self.subscriptionStartDate = nil
        self.subscriptionEndDate = nil
    }
}

enum WorkoutGoal: String, CaseIterable, Codable {
    case weightLoss = "Weight Loss"
    case muscleGain = "Muscle Gain"
    case endurance = "Endurance"
    case flexibility = "Flexibility"
    case generalFitness = "General Fitness"
}

enum Equipment: String, CaseIterable, Codable {
    case none = "No Equipment"
    case dumbbells = "Dumbbells"
    case resistanceBands = "Resistance Bands"
    case yogaMat = "Yoga Mat"
    case kettlebells = "Kettlebells"
    case pullUpBar = "Pull-up Bar"
    case fullGym = "Full Gym Access"
}

enum MusicPreference: String, CaseIterable, Codable {
    case highEnergy = "High Energy"
    case mixed = "Mixed"
    case calm = "Calm"
}

enum SubscriptionStatus: String, CaseIterable, Codable {
    case trial = "Trial"
    case active = "Active"
    case expired = "Expired"
    case cancelled = "Cancelled"
    
    var hasAccess: Bool {
        switch self {
        case .trial, .active:
            return true
        case .expired, .cancelled:
            return false
        }
    }
}

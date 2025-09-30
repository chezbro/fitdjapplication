//
//  Workout.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import Foundation

// D-001: List of workouts with title, duration, equipment, difficulty
struct Workout: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let duration: Int // in minutes
    let difficulty: WorkoutDifficulty
    let requiredEquipment: [Equipment]
    let exercises: [Exercise]
    let targetMuscleGroups: [MuscleGroup]
    let estimatedCalories: Int
    let previewVideoURL: String?
    let thumbnailImageURL: String?
    
    init(id: String, title: String, description: String, duration: Int, difficulty: WorkoutDifficulty, requiredEquipment: [Equipment], exercises: [Exercise], targetMuscleGroups: [MuscleGroup], estimatedCalories: Int, previewVideoURL: String? = nil, thumbnailImageURL: String? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.duration = duration
        self.difficulty = difficulty
        self.requiredEquipment = requiredEquipment
        self.exercises = exercises
        self.targetMuscleGroups = targetMuscleGroups
        self.estimatedCalories = estimatedCalories
        self.previewVideoURL = previewVideoURL
        self.thumbnailImageURL = thumbnailImageURL
    }
}

enum WorkoutDifficulty: String, CaseIterable, Codable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    
    var color: String {
        switch self {
        case .beginner:
            return "green"
        case .intermediate:
            return "orange"
        case .advanced:
            return "red"
        }
    }
}

enum MuscleGroup: String, CaseIterable, Codable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case arms = "Arms"
    case legs = "Legs"
    case core = "Core"
    case fullBody = "Full Body"
    case cardio = "Cardio"
    case flexibility = "Flexibility"
}

// D-002: List of exercises with name, video, and tags
struct Exercise: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let duration: Int // in seconds
    let restDuration: Int // in seconds
    let videoURL: String?
    let imageURL: String?
    let muscleGroups: [MuscleGroup]
    let equipment: [Equipment]
    let instructions: [String]
    let tips: [String]
    
    init(id: String, name: String, description: String, duration: Int, restDuration: Int, videoURL: String? = nil, imageURL: String? = nil, muscleGroups: [MuscleGroup], equipment: [Equipment], instructions: [String], tips: [String] = []) {
        self.id = id
        self.name = name
        self.description = description
        self.duration = duration
        self.restDuration = restDuration
        self.videoURL = videoURL
        self.imageURL = imageURL
        self.muscleGroups = muscleGroups
        self.equipment = equipment
        self.instructions = instructions
        self.tips = tips
    }
}

// D-003: Voice cues (e.g., "10 seconds left")
struct VoiceCue: Codable {
    let id: String
    let text: String
    let timing: Int // seconds from start of exercise
    let type: VoiceCueType
    
    init(id: String, text: String, timing: Int, type: VoiceCueType) {
        self.id = id
        self.text = text
        self.timing = timing
        self.type = type
    }
}

enum VoiceCueType: String, CaseIterable, Codable {
    case instruction = "instruction"
    case countdown = "countdown"
    case motivation = "motivation"
    case rest = "rest"
    case transition = "transition"
    case exercise_description = "exercise_description"
}

enum WorkoutIntensity: String, CaseIterable, Codable {
    case veryEasy
    case easy
    case normal
    case hard
    case veryHard
    
    func increase() -> WorkoutIntensity {
        switch self {
        case .veryEasy: return .easy
        case .easy: return .normal
        case .normal: return .hard
        case .hard: return .veryHard
        case .veryHard: return .veryHard
        }
    }
    
    func decrease() -> WorkoutIntensity {
        switch self {
        case .veryEasy: return .veryEasy
        case .easy: return .veryEasy
        case .normal: return .easy
        case .hard: return .normal
        case .veryHard: return .hard
        }
    }
}


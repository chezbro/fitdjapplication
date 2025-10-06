//
//  ExerciseDBService.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import Foundation
import Combine

// MARK: - ExerciseDB API Models

struct ExerciseDBExercise: Codable, Identifiable {
    let exerciseId: String
    let name: String
    let imageUrl: String?
    let equipments: [String]
    let bodyParts: [String]
    let exerciseType: String
    let targetMuscles: [String]
    let secondaryMuscles: [String]
    let videoUrl: String?
    let keywords: [String]
    let overview: String
    let instructions: [String]
    let exerciseTips: [String]
    let variations: [String]
    let relatedExerciseIds: [String]
    
    var id: String { exerciseId }
}

struct ExerciseDBResponse: Codable {
    let exercises: [ExerciseDBExercise]
    let total: Int
    let page: Int
    let limit: Int
}

// MARK: - ExerciseDB Service

class ExerciseDBService: ObservableObject {
    static let shared = ExerciseDBService()
    
    private let baseURL = "https://v2.exercisedb.dev"
    private let session = URLSession.shared
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var cachedExercises: [ExerciseDBExercise] = []
    
    private let cacheKey = "ExerciseDB_CachedExercises"
    private let lastFetchKey = "ExerciseDB_LastFetch"
    private let cacheExpirationDays = 30 // Cache for 30 days
    
    private init() {
        loadCachedExercises()
    }
    
    // MARK: - Public Methods
    
    func fetchAndCacheExercises() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // Check if we need to fetch new data
            if shouldFetchNewData() {
                let exercises = try await fetchAllExercises()
                await MainActor.run {
                    self.cachedExercises = exercises
                    self.saveCachedExercises(exercises)
                    self.saveLastFetchDate()
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func getExercisesForMuscleGroup(_ muscleGroup: String) -> [ExerciseDBExercise] {
        return cachedExercises.filter { exercise in
            exercise.bodyParts.contains { $0.lowercased() == muscleGroup.lowercased() } ||
            exercise.targetMuscles.contains { $0.lowercased().contains(muscleGroup.lowercased()) }
        }
    }
    
    func getExercisesForEquipment(_ equipment: String) -> [ExerciseDBExercise] {
        return cachedExercises.filter { exercise in
            exercise.equipments.contains { $0.lowercased() == equipment.lowercased() }
        }
    }
    
    func searchExercises(query: String) -> [ExerciseDBExercise] {
        let lowercaseQuery = query.lowercased()
        return cachedExercises.filter { exercise in
            exercise.name.lowercased().contains(lowercaseQuery) ||
            exercise.keywords.contains { $0.lowercased().contains(lowercaseQuery) } ||
            exercise.bodyParts.contains { $0.lowercased().contains(lowercaseQuery) }
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchAllExercises() async throws -> [ExerciseDBExercise] {
        var allExercises: [ExerciseDBExercise] = []
        var page = 0
        let limit = 100 // Fetch 100 exercises per request
        
        while true {
            let exercises = try await fetchExercisesPage(page: page, limit: limit)
            allExercises.append(contentsOf: exercises)
            
            // If we got fewer exercises than the limit, we've reached the end
            if exercises.count < limit {
                break
            }
            
            page += 1
            
            // Safety check to prevent infinite loops
            if page > 50 { // Max 5000 exercises (50 pages * 100 per page)
                break
            }
        }
        
        return allExercises
    }
    
    private func fetchExercisesPage(page: Int, limit: Int) async throws -> [ExerciseDBExercise] {
        guard let url = URL(string: "\(baseURL)/exercises?page=\(page)&limit=\(limit)") else {
            throw ExerciseDBError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ExerciseDBError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ExerciseDBError.httpError(httpResponse.statusCode)
        }
        
        let exerciseResponse = try JSONDecoder().decode(ExerciseDBResponse.self, from: data)
        return exerciseResponse.exercises
    }
    
    private func shouldFetchNewData() -> Bool {
        guard let lastFetch = UserDefaults.standard.object(forKey: lastFetchKey) as? Date else {
            return true // Never fetched before
        }
        
        let daysSinceLastFetch = Calendar.current.dateComponents([.day], from: lastFetch, to: Date()).day ?? 0
        return daysSinceLastFetch >= cacheExpirationDays
    }
    
    private func saveLastFetchDate() {
        UserDefaults.standard.set(Date(), forKey: lastFetchKey)
    }
    
    private func loadCachedExercises() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else {
            return
        }
        
        do {
            cachedExercises = try JSONDecoder().decode([ExerciseDBExercise].self, from: data)
        } catch {
            print("Failed to load cached exercises: \(error)")
        }
    }
    
    private func saveCachedExercises(_ exercises: [ExerciseDBExercise]) {
        do {
            let data = try JSONEncoder().encode(exercises)
            UserDefaults.standard.set(data, forKey: cacheKey)
        } catch {
            print("Failed to save cached exercises: \(error)")
        }
    }
}

// MARK: - Error Types

enum ExerciseDBError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError:
            return "Failed to decode response"
        }
    }
}

// MARK: - ExerciseDB to App Exercise Conversion

extension ExerciseDBExercise {
    func toAppExercise() -> Exercise {
        // Map ExerciseDB equipment to app equipment
        let appEquipment = mapEquipmentToApp(equipments)
        
        // Map ExerciseDB body parts to app muscle groups
        let appMuscleGroups = mapBodyPartsToMuscleGroups(bodyParts)
        
        // Determine duration based on exercise type
        let duration = determineExerciseDuration(exerciseType)
        
        return Exercise(
            id: exerciseId,
            name: name,
            description: overview,
            duration: duration,
            restDuration: 30, // Default rest duration
            videoURL: videoUrl,
            imageURL: imageUrl,
            muscleGroups: appMuscleGroups,
            equipment: appEquipment,
            instructions: instructions,
            tips: exerciseTips
        )
    }
    
    private func mapEquipmentToApp(_ equipment: [String]) -> [Equipment] {
        var appEquipment: [Equipment] = []
        
        for eq in equipment {
            switch eq.lowercased() {
            case "body weight", "bodyweight":
                appEquipment.append(.none)
            case "dumbbell", "dumbbells":
                appEquipment.append(.dumbbells)
            case "barbell", "bench", "medicine ball":
                // Map these to fullGym since they require gym equipment
                appEquipment.append(.fullGym)
            case "kettlebell", "kettlebells":
                appEquipment.append(.kettlebells)
            case "resistance band", "resistance bands":
                appEquipment.append(.resistanceBands)
            case "yoga mat", "mat":
                appEquipment.append(.yogaMat)
            case "pull-up bar", "pullup bar":
                appEquipment.append(.pullUpBar)
            default:
                // For unknown equipment, default to none
                if !appEquipment.contains(.none) {
                    appEquipment.append(.none)
                }
            }
        }
        
        // If no equipment mapped, default to none
        if appEquipment.isEmpty {
            appEquipment.append(.none)
        }
        
        return appEquipment
    }
    
    private func mapBodyPartsToMuscleGroups(_ bodyParts: [String]) -> [MuscleGroup] {
        var muscleGroups: [MuscleGroup] = []
        
        for bodyPart in bodyParts {
            switch bodyPart.lowercased() {
            case "chest":
                muscleGroups.append(.chest)
            case "back":
                muscleGroups.append(.back)
            case "shoulders":
                muscleGroups.append(.shoulders)
            case "arms", "biceps", "triceps":
                muscleGroups.append(.arms)
            case "legs", "quadriceps", "hamstrings", "calves":
                muscleGroups.append(.legs)
            case "core", "abs", "abdominals":
                muscleGroups.append(.core)
            case "cardio":
                muscleGroups.append(.cardio)
            case "full body":
                muscleGroups.append(.fullBody)
            default:
                // For unknown body parts, try to match with existing groups
                if bodyPart.lowercased().contains("chest") {
                    muscleGroups.append(.chest)
                } else if bodyPart.lowercased().contains("back") {
                    muscleGroups.append(.back)
                } else if bodyPart.lowercased().contains("shoulder") {
                    muscleGroups.append(.shoulders)
                } else if bodyPart.lowercased().contains("arm") || bodyPart.lowercased().contains("bicep") || bodyPart.lowercased().contains("tricep") {
                    muscleGroups.append(.arms)
                } else if bodyPart.lowercased().contains("leg") || bodyPart.lowercased().contains("quad") || bodyPart.lowercased().contains("hamstring") || bodyPart.lowercased().contains("calf") {
                    muscleGroups.append(.legs)
                } else if bodyPart.lowercased().contains("core") || bodyPart.lowercased().contains("abs") {
                    muscleGroups.append(.core)
                }
            }
        }
        
        // Remove duplicates
        muscleGroups = Array(Set(muscleGroups))
        
        // If no muscle groups mapped, default to full body
        if muscleGroups.isEmpty {
            muscleGroups.append(.fullBody)
        }
        
        return muscleGroups
    }
    
    private func determineExerciseDuration(_ exerciseType: String) -> Int {
        switch exerciseType.lowercased() {
        case "weight_reps":
            return 60 // 1 minute for strength exercises
        case "cardio":
            return 45 // 45 seconds for cardio
        case "stretching":
            return 90 // 1.5 minutes for stretching
        case "bodyweight":
            return 45 // 45 seconds for bodyweight exercises
        default:
            return 60 // Default to 1 minute
        }
    }
}

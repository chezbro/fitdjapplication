//
//  ExerciseDBManagerView.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import SwiftUI

struct ExerciseDBManagerView: View {
    @StateObject private var exerciseDBService = ExerciseDBService.shared
    @StateObject private var workoutDataService = WorkoutDataService()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("ExerciseDB Integration")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Access 5,000+ exercises from ExerciseDB")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                // Cache Status
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: exerciseDBService.cachedExercises.isEmpty ? "exclamationmark.triangle" : "checkmark.circle.fill")
                            .foregroundColor(exerciseDBService.cachedExercises.isEmpty ? .orange : .green)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cache Status")
                                .font(.headline)
                            
                            Text(workoutDataService.exerciseDBCacheStatus)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    if !exerciseDBService.cachedExercises.isEmpty {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            
                            Text("Exercises are cached locally and will be used for 30 days")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                }
                
                // API Info Section
                VStack(spacing: 12) {
                    HStack {
                        Text("API Information")
                            .font(.headline)
                        
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ExerciseDB API is free and open:")
                            .font(.subheadline)
                        
                        Text("• No API key required")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• 5,000+ exercises available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• No rate limits for basic usage")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        Task {
                            await workoutDataService.refreshExerciseDBData()
                        }
                    }) {
                        HStack {
                            if exerciseDBService.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            
                            Text(exerciseDBService.cachedExercises.isEmpty ? "Fetch Exercises" : "Refresh Cache")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(exerciseDBService.isLoading)
                    
                    if !exerciseDBService.cachedExercises.isEmpty {
                        Button(action: {
                            workoutDataService.refreshWorkouts()
                        }) {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text("Generate Workouts")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                }
                
                // Error Message
                if let errorMessage = exerciseDBService.errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                // Footer
                VStack(spacing: 8) {
                    Text("ExerciseDB provides 5,000+ exercises with:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 20) {
                        VStack {
                            Image(systemName: "video.fill")
                                .foregroundColor(.blue)
                            Text("Videos")
                                .font(.caption2)
                        }
                        
                        VStack {
                            Image(systemName: "photo.fill")
                                .foregroundColor(.blue)
                            Text("Images")
                                .font(.caption2)
                        }
                        
                        VStack {
                            Image(systemName: "list.bullet")
                                .foregroundColor(.blue)
                            Text("Instructions")
                                .font(.caption2)
                        }
                        
                        VStack {
                            Image(systemName: "dumbbell")
                                .foregroundColor(.blue)
                            Text("Equipment")
                                .font(.caption2)
                        }
                    }
                }
                .padding()
            }
            .padding()
            .navigationTitle("ExerciseDB")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ExerciseDBManagerView()
}

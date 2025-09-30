//
//  RestScreen.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import SwiftUI

struct RestScreen: View {
    let restDuration: Int
    let nextExerciseName: String
    let timeRemaining: Int
    let onReady: () -> Void
    
    var body: some View {
        ZStack {
            // Rest-themed background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Rest icon and title
                VStack(spacing: 20) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                        .scaleEffect(1.0 + sin(Date().timeIntervalSince1970 * 2) * 0.1)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: Date().timeIntervalSince1970)
                    
                    Text("Rest Period")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Catch Your Breath")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Timer display
                VStack(spacing: 10) {
                    Text("\(timeRemaining)")
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.3), value: timeRemaining)
                    
                    Text("seconds remaining")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.green.opacity(0.3), lineWidth: 2)
                        )
                )
                
                // Next exercise preview
                VStack(spacing: 15) {
                    Text("Next Up:")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(nextExerciseName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
                
                Spacer()
                
                // Breathing guide
                VStack(spacing: 15) {
                    Text("Focus on Your Breathing")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.9))
                    
                    HStack(spacing: 20) {
                        // Inhale
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                            
                            Text("Inhale")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        // Hold
                        VStack(spacing: 8) {
                            Image(systemName: "pause.circle.fill")
                                .font(.title)
                                .foregroundColor(.orange)
                            
                            Text("Hold")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        // Exhale
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.title)
                                .foregroundColor(.red)
                            
                            Text("Exhale")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.05))
                )
                
                Spacer()
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 40)
        }
    }
}

#Preview {
    RestScreen(
        restDuration: 30,
        nextExerciseName: "Push-ups",
        timeRemaining: 25,
        onReady: {}
    )
}

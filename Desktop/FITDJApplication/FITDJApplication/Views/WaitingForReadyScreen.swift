//
//  WaitingForReadyScreen.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import SwiftUI

struct WaitingForReadyScreen: View {
    let exerciseName: String
    let exerciseInstructions: String
    let onReady: () -> Void
    
    var body: some View {
        ZStack {
            // Dark background for workout focus
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Header with progress and exit
                HStack {
                    Text("Exercise Preparation")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top)
                
                Spacer()
                
                // Exercise information
                VStack(spacing: 20) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 80))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(exerciseName)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text(exerciseInstructions)
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.1))
                )
                
                Spacer()
                
                // Ready button section
                VStack(spacing: 20) {
                    Text("Get into position and take a deep breath")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                    
                    Button(action: onReady) {
                        Text("I'm Ready!")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 50)
                            .padding(.vertical, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 30)
                                    .fill(Color.green)
                                    .shadow(color: .green.opacity(0.3), radius: 10, x: 0, y: 5)
                            )
                    }
                    .scaleEffect(1.0)
                    .animation(.easeInOut(duration: 0.1), value: true)
                }
                
                Spacer()
            }
            .padding(.horizontal, 30)
        }
    }
}

#Preview {
    WaitingForReadyScreen(
        exerciseName: "Push-ups",
        exerciseInstructions: "Start in plank position, lower body to ground, push back up",
        onReady: {}
    )
}

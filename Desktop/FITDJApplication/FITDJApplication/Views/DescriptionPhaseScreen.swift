//
//  DescriptionPhaseScreen.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import SwiftUI

struct DescriptionPhaseScreen: View {
    var body: some View {
        ZStack {
            // Dark background for workout focus
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Workout preparation message
                VStack(spacing: 20) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 80))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("Getting Your Groove On...")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Preparing your workout")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.1))
                )
                
                Spacer()
            }
            .padding(.horizontal, 30)
        }
    }
}

#Preview {
    DescriptionPhaseScreen()
}

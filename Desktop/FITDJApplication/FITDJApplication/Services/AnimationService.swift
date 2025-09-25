//
//  AnimationService.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import Foundation
import SwiftUI

// MARK: - B-010: Animation Service

struct AnimationService {
    
    // MARK: - Workout Animations
    
    static let workoutStart = Animation.easeInOut(duration: 0.8)
    static let workoutComplete = Animation.spring(response: 0.6, dampingFraction: 0.8)
    static let exerciseTransition = Animation.easeInOut(duration: 0.5)
    static let countdownPulse = Animation.easeInOut(duration: 0.3).repeatCount(3, autoreverses: true)
    
    // MARK: - UI Animations
    
    static let buttonPress = Animation.easeInOut(duration: 0.1)
    static let cardFlip = Animation.easeInOut(duration: 0.6)
    static let slideIn = Animation.easeOut(duration: 0.5)
    static let slideOut = Animation.easeIn(duration: 0.3)
    static let fadeIn = Animation.easeIn(duration: 0.4)
    static let fadeOut = Animation.easeOut(duration: 0.3)
    
    // MARK: - Progress Animations
    
    static let progressFill = Animation.easeInOut(duration: 1.0)
    static let streakGlow = Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)
    static let milestoneCelebration = Animation.spring(response: 0.5, dampingFraction: 0.6)
    
    // MARK: - Music Animations
    
    static let musicWave = Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)
    static let volumeSlider = Animation.easeInOut(duration: 0.2)
    static let trackChange = Animation.easeInOut(duration: 0.4)
    
    // MARK: - Notification Animations
    
    static let notificationSlide = Animation.easeOut(duration: 0.6)
    static let reminderPulse = Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)
}

// MARK: - Animation Modifiers

struct WorkoutStartAnimation: ViewModifier {
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.05 : 1.0)
            .opacity(isAnimating ? 1.0 : 0.8)
            .onAppear {
                withAnimation(AnimationService.workoutStart) {
                    isAnimating = true
                }
            }
    }
}

struct StreakGlowAnimation: ViewModifier {
    @State private var isGlowing = false
    
    func body(content: Content) -> some View {
        content
            .shadow(color: .orange, radius: isGlowing ? 10 : 0)
            .onAppear {
                withAnimation(AnimationService.streakGlow) {
                    isGlowing = true
                }
            }
    }
}

struct ProgressFillAnimation: ViewModifier {
    let progress: Double
    @State private var animatedProgress: Double = 0
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                withAnimation(AnimationService.progressFill) {
                    animatedProgress = progress
                }
            }
    }
}

struct MilestoneCelebrationAnimation: ViewModifier {
    @State private var isCelebrating = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isCelebrating ? 1.2 : 1.0)
            .rotationEffect(.degrees(isCelebrating ? 5 : 0))
            .onAppear {
                withAnimation(AnimationService.milestoneCelebration) {
                    isCelebrating = true
                }
            }
    }
}

struct MusicWaveAnimation: ViewModifier {
    @State private var isWaving = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(y: isWaving ? 1.2 : 1.0)
            .onAppear {
                withAnimation(AnimationService.musicWave) {
                    isWaving = true
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    func workoutStartAnimation() -> some View {
        modifier(WorkoutStartAnimation())
    }
    
    func streakGlowAnimation() -> some View {
        modifier(StreakGlowAnimation())
    }
    
    func progressFillAnimation(progress: Double) -> some View {
        modifier(ProgressFillAnimation(progress: progress))
    }
    
    func milestoneCelebrationAnimation() -> some View {
        modifier(MilestoneCelebrationAnimation())
    }
    
    func musicWaveAnimation() -> some View {
        modifier(MusicWaveAnimation())
    }
}

// MARK: - Custom Animations

struct BounceAnimation: ViewModifier {
    @State private var isBouncing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isBouncing ? 1.1 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    isBouncing = true
                }
            }
    }
}

struct ShakeAnimation: ViewModifier {
    @State private var isShaking = false
    
    func body(content: Content) -> some View {
        content
            .offset(x: isShaking ? -5 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.1).repeatCount(6, autoreverses: true)) {
                    isShaking = true
                }
            }
    }
}

struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.6 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

extension View {
    func bounceAnimation() -> some View {
        modifier(BounceAnimation())
    }
    
    func shakeAnimation() -> some View {
        modifier(ShakeAnimation())
    }
    
    func pulseAnimation() -> some View {
        modifier(PulseAnimation())
    }
}

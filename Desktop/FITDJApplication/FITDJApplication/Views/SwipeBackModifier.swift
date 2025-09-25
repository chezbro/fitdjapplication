//
//  SwipeBackModifier.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import SwiftUI

// Reusable modifier for swipe-to-go-back functionality
struct SwipeBackModifier: ViewModifier {
    let onDismiss: () -> Void
    @State private var dragOffset = CGSize.zero
    @State private var showBackIndicator = false
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .offset(x: dragOffset.width)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Only allow swipe right (positive width) to go back
                            if value.translation.width > 0 {
                                dragOffset = value.translation
                                showBackIndicator = value.translation.width > 50
                            }
                        }
                        .onEnded { value in
                            // If swipe is significant enough, go back
                            if value.translation.width > 100 {
                                onDismiss()
                            } else {
                                // Spring back to original position
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    dragOffset = .zero
                                }
                                showBackIndicator = false
                            }
                        }
                )
            
            // Visual indicator when swiping
            if showBackIndicator {
                VStack {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundColor(.white)
                            
                            Text("Back")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                        .padding(.trailing, 20)
                    }
                    Spacer()
                }
                .transition(.opacity.combined(with: .scale))
                .animation(.easeInOut(duration: 0.2), value: showBackIndicator)
            }
        }
    }
}

// Convenience extension for easy use
extension View {
    func swipeToGoBack(onDismiss: @escaping () -> Void) -> some View {
        self.modifier(SwipeBackModifier(onDismiss: onDismiss))
    }
}

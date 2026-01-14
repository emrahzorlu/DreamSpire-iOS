//
//  ModeToggleView.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//
//  Premium floating pill toggle with glassmorphism effect
//

import SwiftUI

struct ModeToggleView: View {
    @Binding var isAudioMode: Bool
    @State private var isPressed = false
    
    // Premium gradient colors
    private let activeGradient = LinearGradient(
        colors: [
            Color(red: 0.902, green: 0.475, blue: 0.976),
            Color(red: 0.698, green: 0.408, blue: 0.976),
            Color(red: 0.545, green: 0.361, blue: 0.965)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    private let glassBackground = Color.white.opacity(0.95)
    private let accentColor = Color(red: 0.545, green: 0.361, blue: 0.965)

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Glass background with subtle inner shadow
                RoundedRectangle(cornerRadius: 16)
                    .fill(glassBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white,
                                        accentColor.opacity(0.15)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.5
                            )
                    )
                
                // Animated sliding pill with glow
                RoundedRectangle(cornerRadius: 12)
                    .fill(activeGradient)
                    .frame(width: (geometry.size.width / 2) - 8, height: geometry.size.height - 10)
                    .shadow(color: accentColor.opacity(0.4), radius: 8, x: 0, y: 4)
                    .offset(x: isAudioMode ? geometry.size.width / 2 + 1 : 5)
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isAudioMode)

                // Icons and text layer
                HStack(spacing: 0) {
                    // Reading Mode
                    Button(action: { 
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            isAudioMode = false 
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "book.fill")
                                .font(.system(size: isAudioMode ? 15 : 17, weight: .semibold))
                                .scaleEffect(isAudioMode ? 1.0 : 1.15)
                            Text("mode_reading".localized)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(isAudioMode ? accentColor : .white)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    // Listening Mode
                    Button(action: { 
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            isAudioMode = true 
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "headphones")
                                .font(.system(size: isAudioMode ? 17 : 15, weight: .semibold))
                                .scaleEffect(isAudioMode ? 1.15 : 1.0)
                            Text("mode_listening".localized)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(isAudioMode ? .white : accentColor)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isAudioMode)
            }
        }
        .frame(height: 52)
        .shadow(color: accentColor.opacity(0.15), radius: 12, x: 0, y: 6)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        LinearGradient(
            colors: [
                Color(red: 0.953, green: 0.925, blue: 1.0),
                Color(red: 0.910, green: 0.871, blue: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        VStack(spacing: 24) {
            ModeToggleView(isAudioMode: .constant(false))
                .padding(.horizontal, 20)
            
            ModeToggleView(isAudioMode: .constant(true))
                .padding(.horizontal, 20)
            
            Spacer()
        }
        .padding(.top, 40)
    }
}
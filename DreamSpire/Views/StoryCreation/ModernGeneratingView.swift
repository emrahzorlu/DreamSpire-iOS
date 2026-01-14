//
//  ModernGeneratingView.swift
//  DreamSpire
//
//  Modern generating view with rotating rings and animated owl states
//

import SwiftUI

struct ModernGeneratingView: View {
    let storyTitle: String
    let onEnableNotifications: () -> Void
    let onContinueInBackground: () -> Void
    
    @State private var outerRotation: Double = 0
    @State private var innerRotation: Double = 0
    @State private var currentOwlIndex: Int = 0
    @State private var owlOpacity: Double = 1.0
    
    // Döngüsel owl states
    private let owlStates = ["owl_generating", "owl_eyes_closed", "owl_eyes_open", "owl_wink", "owl_excited", "owl_ok"]
    
    private let estimatedMinutes = 3 // Backend'den gelecek opsiyonel
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Çift halka + baykuş animasyonu
            ZStack {
                // Outer rotating ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.54, green: 0.71, blue: 0.96).opacity(0.3),
                                Color(red: 0.71, green: 0.65, blue: 0.85).opacity(0.3),
                                Color(red: 0.54, green: 0.71, blue: 0.96).opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(outerRotation))
                
                // Inner rotating ring (opposite direction)
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.71, green: 0.65, blue: 0.85).opacity(0.4),
                                Color(red: 0.54, green: 0.71, blue: 0.96).opacity(0.4),
                                Color(red: 0.71, green: 0.65, blue: 0.85).opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [8, 8])
                    )
                    .frame(width: 130, height: 130)
                    .rotationEffect(.degrees(innerRotation))
                
                // Animated owl in center
                Image(owlStates[currentOwlIndex])
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .opacity(owlOpacity)
            }
            .padding(.vertical, 40)
            
            // Story title
            Text(storyTitle)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            // Generating message
            Text("story_creating_magic".localized)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Estimated time
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 14, weight: .medium))
                Text(String(format: "estimated_time".localized, estimatedMinutes))
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.secondary.opacity(0.8))
            .padding(.top, 8)
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 16) {
                // Enable notifications button
                Button(action: onEnableNotifications) {
                    HStack(spacing: 10) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("notification_enable_and_continue".localized)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.54, green: 0.71, blue: 0.96),
                                Color(red: 0.71, green: 0.65, blue: 0.85)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                }
                
                // Continue in background button
                Button(action: onContinueInBackground) {
                    Text("continue_in_background".localized)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Animations
    
    private func startAnimations() {
        // Outer ring rotation (clockwise)
        withAnimation(
            .linear(duration: 8)
            .repeatForever(autoreverses: false)
        ) {
            outerRotation = 360
        }
        
        // Inner ring rotation (counter-clockwise)
        withAnimation(
            .linear(duration: 6)
            .repeatForever(autoreverses: false)
        ) {
            innerRotation = -360
        }
        
        // Owl state cycling (every 3 seconds)
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            // Fade out
            withAnimation(.easeOut(duration: 0.3)) {
                owlOpacity = 0
            }
            
            // Change owl after fade out
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                currentOwlIndex = (currentOwlIndex + 1) % owlStates.count
                
                // Fade in
                withAnimation(.easeIn(duration: 0.3)) {
                    owlOpacity = 1.0
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ModernGeneratingView(
        storyTitle: "Orman Maceraları",
        onEnableNotifications: {
            print("Enable notifications")
        },
        onContinueInBackground: {
            print("Continue in background")
        }
    )
}

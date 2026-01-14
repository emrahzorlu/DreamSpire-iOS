//
//  GuestUpgradeCard.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025.
//

import SwiftUI

/// Premium upgrade promotion card for guest users
struct GuestUpgradeCard: View {
    var onUpgrade: () -> Void
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        Button(action: onUpgrade) {
            ZStack {
                // Background Image
                Image("PremiumBannerBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 140)
                    .clipped()
                    .cornerRadius(16)
                
                // Gradient overlay
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.85),
                        Color.black.opacity(0.6),
                        Color.black.opacity(0.3),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 140)
                .cornerRadius(16)
                
                // Content
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        // Title
                        VStack(alignment: .leading, spacing: 2) {
                            Text("settings_premium_unlock".localized)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("settings_premium_benefits".localized)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(hex: "fbbf24"), Color(hex: "f59e0b")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                        
                        // Benefits row
                        HStack(spacing: 12) {
                            BenefitItem(icon: "waveform.circle.fill", text: "settings_benefit_audio".localized)
                            BenefitItem(icon: "photo.circle.fill", text: "settings_benefit_images".localized)
                        }
                        
                        Spacer(minLength: 0)
                        
                        // CTA
                        HStack(spacing: 6) {
                            Text("settings_upgrade_now".localized)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(hex: "f59e0b"))
                            
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "f59e0b"))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.white))
                        .scaleEffect(pulseScale)
                    }
                    .padding(16)
                    
                    Spacer()
                }
                .frame(height: 140)
            }
            .frame(height: 140)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.05
            }
        }
        .accessibilityLabel("Premium'a yükselt")
    }
}

// MARK: - Benefit Item

private struct BenefitItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "fbbf24"))
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

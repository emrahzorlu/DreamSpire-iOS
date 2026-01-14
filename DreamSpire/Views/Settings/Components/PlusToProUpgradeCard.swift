//
//  PlusToProUpgradeCard.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025.
//

import SwiftUI

/// Upgrade card for Plus tier users to upgrade to Pro
struct PlusToProUpgradeCard: View {
    var onUpgrade: () -> Void
    @State private var shimmerOffset: CGFloat = -1
    
    var body: some View {
        Button(action: onUpgrade) {
            HStack(spacing: 14) {
                // Illustrated story icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "8b5cf6"), Color(hex: "ec4899")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
                .shadow(color: Color(hex: "8b5cf6").opacity(0.4), radius: 8, x: 0, y: 4)
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("settings_pro_unlock".localized)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        
                        // PRO Badge
                        Text("PRO")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "8b5cf6"), Color(hex: "ec4899")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(4)
                    }
                    
                    Text("settings_pro_illustrated".localized)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "ec4899"))
            }
            .padding(14)
            .background(
                ZStack {
                    // Base gradient
                    LinearGradient(
                        colors: [
                            Color(hex: "8b5cf6").opacity(0.15),
                            Color(hex: "ec4899").opacity(0.1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    
                    // Shimmer effect
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .offset(x: shimmerOffset * 300)
                }
            )
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "8b5cf6").opacity(0.4), Color(hex: "ec4899").opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: false)) {
                shimmerOffset = 1
            }
        }
        .accessibilityLabel("Pro'ya yükselt - Görsel hikayeler")
    }
}

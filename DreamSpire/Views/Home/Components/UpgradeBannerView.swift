//
//  UpgradeBannerView.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025.
//

import SwiftUI

/// Premium upgrade banner for free users
struct UpgradeBannerView: View {
    let onTap: () -> Void
    @State private var gradientOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background Image
                Image("PremiumBannerBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(24)
                
                // Gradient overlay
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.8),
                        Color.black.opacity(0.6),
                        Color.black.opacity(0.3),
                        Color.clear,
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 200)
                .cornerRadius(24)
                
                VStack(alignment: .leading, spacing: 8) {
                    // Title with animated gradient
                    VStack(alignment: .leading, spacing: 1) {
                        Text("premium_banner_title_line1".localized)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)
                        
                        Text("premium_banner_title_line2".localized)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "fbbf24"),
                                        Color(hex: "f59e0b"),
                                        Color(hex: "ec4899")
                                    ],
                                    startPoint: .leading,
                                    endPoint: UnitPoint(x: 1.0 + gradientOffset, y: 0)
                                )
                            )
                            .shadow(color: Color(hex: "fbbf24").opacity(0.6), radius: 10, x: 0, y: 3)
                    }
                    
                    // Benefits
                    VStack(alignment: .leading, spacing: 6) {
                        BenefitRow(icon: "waveform.circle.fill", text: "premium_banner_benefit_audio".localized)
                        BenefitRow(icon: "photo.stack.fill", text: "premium_banner_benefit_illustration".localized)
                    }
                    .padding(.top, 4)
                    
                    Spacer()
                    
                    // CTA Button
                    Text("premium_banner_cta".localized)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "fbbf24"), Color(hex: "f59e0b")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .scaleEffect(pulseScale)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 200)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            // Gradient animation
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: true)) {
                gradientOffset = 0.5
            }
            // Pulse animation
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.05
            }
        }
        .accessibilityLabel("Premium'a yükselt")
        .accessibilityHint("Daha fazla özellik açmak için dokunun")
    }
}

// MARK: - Benefit Row

private struct BenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "fbbf24"))
            
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
    }
}

#if DEBUG
struct UpgradeBannerView_Previews: PreviewProvider {
    static var previews: some View {
        UpgradeBannerView(onTap: {})
            .padding()
            .background(Color.black)
    }
}
#endif

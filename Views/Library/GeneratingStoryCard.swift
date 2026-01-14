//
//  GeneratingStoryCard.swift
//  DreamSpire
//
//  Simple generating card with shimmer effect
//

import SwiftUI
import Shimmer

struct GeneratingStoryCard: View {
    let title: String
    
    @State private var pulseOpacity: Double = 1.0
    
    var body: some View {
        HStack(spacing: 14) {
            // Left: Book placeholder with shimmer
            bookPlaceholder
            
            // Right: Content area
            contentArea
        }
        .padding(12)
        .background(
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.45, green: 0.35, blue: 0.75),
                        Color(red: 0.55, green: 0.45, blue: 0.85)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.15),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .cornerRadius(16)
        .shadow(color: Color.purple.opacity(0.3), radius: 10, x: 0, y: 4)
        .onAppear {
            startPulseAnimation()
        }
    }
    
    // MARK: - Book Placeholder
    
    private var bookPlaceholder: some View {
        ZStack {
            // Base skeleton with strong shimmer
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.15))
                .frame(width: 125, height: 150)
            
            // Shimmer overlay - MUCH MORE VISIBLE
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.6),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 125, height: 150)
                .shimmering(
                    active: true,
                    duration: 1.2,
                    bounce: false,
                    delay: 0
                )
            
            // Book icon
            Image(systemName: "book.closed.fill")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.3))
        }
    }
    
    // MARK: - Helpers
    
    private var truncatedTitle: String {
        let words = title.split(separator: " ")
        if words.count > 8 {
            return words.prefix(8).joined(separator: " ") + "..."
        }
        return title
    }
    
    private var contentArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title
            VStack(alignment: .leading, spacing: 6) {
                Text(truncatedTitle)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Skeleton line
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 8)
                    .frame(maxWidth: .infinity)
            }
            
            Spacer(minLength: 8)
            
            // Generating message with pulse
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                Text("story_generating".localized)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.yellow.opacity(0.95))
            .opacity(pulseOpacity)
            
            // Stats skeletons
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 60, height: 20)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 50, height: 20)
            }
        }
        .shimmering(
            active: true,
            duration: 1.5,
            bounce: false,
            delay: 0.2
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Animation
    
    private func startPulseAnimation() {
        withAnimation(
            .easeInOut(duration: 1.5)
            .repeatForever(autoreverses: true)
        ) {
            pulseOpacity = 0.6
        }
    }
}

// MARK: - Preview

#Preview("Generating") {
    GeneratingStoryCard(title: "Orman Maceraları")
        .padding()
}

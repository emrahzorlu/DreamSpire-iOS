//
//  LoadingStoryCard.swift
//  DreamSpire
//
//  Modern hybrid loading card with shimmer + progress ring
//

import SwiftUI

struct LoadingStoryCard: View {
    let title: String
    let progress: Double // 0.0 - 1.0
    let statusMessage: String

    @State private var shimmerOffset: CGFloat = -300
    @State private var pulseAnimation = false
    @State private var rotationAngle: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            // Main card content
            HStack(spacing: 16) {
                // Left: Book placeholder with shimmer
                bookPlaceholder

                // Center: Progress ring
                progressRing

                // Right: Text placeholders with shimmer
                VStack(alignment: .leading, spacing: 8) {
                    titlePlaceholder
                    subtitlePlaceholder1
                    subtitlePlaceholder2
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)

            // Bottom status bar
            statusBar
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.91, green: 0.93, blue: 1.0),
                    Color(red: 0.96, green: 0.91, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Components

    private var bookPlaceholder: some View {
        ZStack {
            // Book shape
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.83, green: 0.85, blue: 1.0))
                .frame(width: 80, height: 115)

            // Shimmer overlay
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color(red: 0.91, green: 0.93, blue: 1.0).opacity(0.8),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 80, height: 115)
                .offset(x: shimmerOffset)
                .mask(
                    RoundedRectangle(cornerRadius: 12)
                        .frame(width: 80, height: 115)
                )
        }
    }

    private var progressRing: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 6)
                .frame(width: 70, height: 70)

            // Progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.54, green: 0.71, blue: 0.96),
                            Color(red: 0.71, green: 0.65, blue: 0.85)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 70, height: 70)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)

            // Progress percentage
            Text("\(Int(progress * 100))%")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(red: 0.54, green: 0.71, blue: 0.96))
        }
    }

    private var titlePlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.83, green: 0.85, blue: 1.0))
                .frame(height: 16)

            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color(red: 0.91, green: 0.93, blue: 1.0).opacity(0.8),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 16)
                .offset(x: shimmerOffset)
                .mask(
                    RoundedRectangle(cornerRadius: 6)
                        .frame(height: 16)
                )
        }
    }

    private var subtitlePlaceholder1: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.83, green: 0.85, blue: 1.0))
                .frame(width: 120, height: 12)
                .frame(maxWidth: .infinity, alignment: .leading)

            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color(red: 0.91, green: 0.93, blue: 1.0).opacity(0.8),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 120, height: 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(x: shimmerOffset)
                .mask(
                    RoundedRectangle(cornerRadius: 6)
                        .frame(width: 120, height: 12)
                )
        }
    }

    private var subtitlePlaceholder2: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.83, green: 0.85, blue: 1.0))
                .frame(width: 90, height: 12)
                .frame(maxWidth: .infinity, alignment: .leading)

            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color(red: 0.91, green: 0.93, blue: 1.0).opacity(0.8),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 90, height: 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(x: shimmerOffset)
                .mask(
                    RoundedRectangle(cornerRadius: 6)
                        .frame(width: 90, height: 12)
                )
        }
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            // Animated dots
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color(red: 0.54, green: 0.71, blue: 0.96))
                        .frame(width: 6, height: 6)
                        .opacity(pulseAnimation ? 0.3 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: pulseAnimation
                        )
                }
            }

            Text(statusMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(red: 0.54, green: 0.71, blue: 0.96))
                .opacity(pulseAnimation ? 0.6 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseAnimation)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.5))
    }

    // MARK: - Animations

    private func startAnimations() {
        // Shimmer animation - continuous sweep
        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
            shimmerOffset = 400
        }

        // Pulse animation for status
        pulseAnimation = true
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        LoadingStoryCard(
            title: "Orman Maceraları",
            progress: 0.35,
            statusMessage: "Hikaye oluşturuluyor..."
        )
        .padding()

        LoadingStoryCard(
            title: "Uzay Yolculuğu",
            progress: 0.65,
            statusMessage: "Ses dosyası oluşturuluyor..."
        )
        .padding()

        LoadingStoryCard(
            title: "Deniz Altı Keşif",
            progress: 0.85,
            statusMessage: "Son rötuşlar yapılıyor..."
        )
        .padding()
    }
    .background(Color.gray.opacity(0.1))
}

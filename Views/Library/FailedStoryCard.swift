//
//  FailedStoryCard.swift
//  DreamSpire
//
//  Failed story card matching UserStoryCard layout with red glass-morphism
//

import SwiftUI

struct FailedStoryCard: View {
    let job: GenerationJobState
    var isRetrying: Bool = false
    let onRetry: (() -> Void)?
    let onDismiss: (() -> Void)?

    @State private var pulseOpacity: Double = 0.6

    var body: some View {
        HStack(spacing: 14) {
            // Left: Error icon area (consistent with cover image size)
            errorIconArea
                .frame(width: 125, height: 150)
                .cornerRadius(12)
                .clipped()

            // Right: Story info & Wide Buttons
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    // Title
                    Text(job.storyTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Error Status
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 10))
                        Text("failed_story_creation_failed".localized)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.85))
                }
                .padding(.bottom, 8)

                Spacer(minLength: 4)

                // Wide Action Buttons
                VStack(spacing: 8) {
                    // Retry Button
                    if let onRetry = onRetry {
                        Button(action: onRetry) {
                            HStack(spacing: 8) {
                                if isRetrying {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                                Text("retry".localized)
                            }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40) // Fixed height for consistency
                            .background(
                                LinearGradient(
                                    colors: isRetrying 
                                        ? [Color.gray.opacity(0.5), Color.gray.opacity(0.3)]
                                        : [Color(red: 0.6, green: 0.4, blue: 1.0), Color(red: 0.9, green: 0.5, blue: 0.95)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: isRetrying ? .clear : Color.purple.opacity(0.3), radius: 5, x: 0, y: 3)
                        }
                        .disabled(isRetrying)
                    }

                    // Remove Button
                    if let onDismiss = onDismiss {
                        Button(action: onDismiss) {
                            Text("failed_story_remove".localized)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.12))
                                .cornerRadius(12)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    Color(red: 0.12, green: 0.05, blue: 0.1) // Slightly deeper base
                        .opacity(0.18)
                )
                .background(
                    // More visible red glow
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.red.opacity(0.08))
                        .blur(radius: 12)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.2),
                                    .red.opacity(0.2),
                                    .white.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 5)
        .onAppear {
            startPulseAnimation()
        }
    }

    // MARK: - Error Icon Area

    private var errorIconArea: some View {
        ZStack {
            // Frosted background for the icon square
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
            
            // The "Glow" effect behind the icon - intensified
            Circle()
                .fill(Color.red.opacity(0.2))
                .frame(width: 70, height: 70)
                .blur(radius: 18)
                .opacity(pulseOpacity)
            
            // Centered Triangle Exclamation
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.4, blue: 0.4),
                            Color(red: 1.0, green: 0.6, blue: 0.6).opacity(0.9)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .red.opacity(0.4), radius: 10, x: 0, y: 0)
                .opacity(pulseOpacity)
        }
    }

    // MARK: - Animations

    private func startPulseAnimation() {
        withAnimation(
            Animation
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
        ) {
            pulseOpacity = 1.0
        }
    }
}

// MARK: - Preview

#Preview("Failed Story - Content Safety") {
    FailedStoryCard(
        job: GenerationJobState(
            jobId: "test-job",
            storyTitle: "Orman Maceraları",
            userId: "test-user",
            progress: 0.5,
            status: "failed"
        ),
        onRetry: {},
        onDismiss: {}
    )
    .padding()
}

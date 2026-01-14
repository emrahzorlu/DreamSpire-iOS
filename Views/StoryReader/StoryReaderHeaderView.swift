//
//  StoryReaderHeaderView.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//

import SwiftUI

struct StoryReaderHeaderView: View {
    let story: Story
    let isFavorite: Bool
    let audioDurationMinutes: Int? // Optional: actual audio duration in minutes
    let onBack: () -> Void
    let onToggleFavorite: () -> Void

    // Computed property for displaying accurate duration
    private var displayMinutes: Int {
        // Use actual audio duration if available, otherwise use rounded minutes
        return audioDurationMinutes ?? story.roundedMinutes
    }

    // Convert age range to numeric format
    private func localizedAgeRange(_ ageRange: String) -> String {
        switch ageRange.lowercased() {
        case "toddler": return "age_range_0_3".localized
        case "preschool": return "age_range_4_6".localized
        case "young": return "age_range_7_9".localized
        case "middle": return "age_range_10_12".localized
        case "teen": return "age_range_13_plus".localized
        default: return ageRange.capitalized
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Navigation Bar
            HStack(spacing: 8) {
                // Back Button - compact
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 44)
                }

                // Title - Up to 3 lines support with better readability
                Text(story.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .minimumScaleFactor(0.8)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Actions - compact spacing
                HStack(spacing: 2) {
                    // Share Button
                    Button(action: {
                        DWLogger.shared.logUserAction("Share Story", details: story.title)
                        // TODO: Implement share
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                    
                    // Favorite Button
                    Button(action: onToggleFavorite) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 18))
                            .foregroundColor(isFavorite ? .pink : .white)
                            .frame(width: 44, height: 44)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            // Story Metadata
            HStack(spacing: 8) {
                if let ageRange = story.metadata?.ageRange {
                    Text(localizedAgeRange(ageRange))

                    Text("•")
                        .foregroundColor(.white.opacity(0.5))
                }

                if let tone = story.metadata?.tone {
                    Text(tone.capitalized)

                    Text("•")
                        .foregroundColor(.white.opacity(0.5))
                }

                Text("\(displayMinutes) \("minutes_abbreviation".localized)")
            }
            .font(.system(size: 13))
            .foregroundColor(.white.opacity(0.8))
            .padding(.bottom, 8)
        }
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.5), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LinearGradient.dwBackground
            .ignoresSafeArea()
        
        VStack {
            StoryReaderHeaderView(
                story: Story.mockStory,
                isFavorite: false,
                audioDurationMinutes: nil,
                onBack: {},
                onToggleFavorite: {}
            )
            Spacer()
        }
    }
}

//
//  StoryCardView.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025.
//

import SwiftUI
import SDWebImageSwiftUI

/// Card view for displaying a single story in horizontal lists
struct StoryCardView: View {
    let story: Story
    @State private var isLocked: Bool = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Image
            if let coverUrl = story.coverImageUrl, let url = URL(string: coverUrl) {
                WebImage(
                    url: url,
                    options: [.retryFailed, .scaleDownLargeImages],
                    context: nil,
                    content: { image in
                        image
                            .resizable()
                            .scaledToFill()
                    },
                    placeholder: {
                        StoryCardPlaceholder()
                    }
                )
                .frame(width: 140, height: 190)
                .clipped()
            } else {
                StoryPlaceholderView()
                    .frame(width: 140, height: 190)
            }

            // Gradient overlay
            LinearGradient(
                colors: [Color.black.opacity(0.6), Color.clear],
                startPoint: .bottom,
                endPoint: .center
            )
            .frame(width: 140, height: 190)

            // Lock overlay for inaccessible stories
            if isLocked {
                LockedStoryOverlay(tierColor: tierBadgeColor)
                    .frame(width: 140, height: 190)
            }

            // Tier Badge
            VStack {
                HStack {
                    Spacer()
                    TierBadgeView(tier: story.metadata?.tier ?? "")
                        .padding(8)
                }
                Spacer()
            }
            .frame(width: 140, height: 190)

            // Title overlay
            VStack(alignment: .leading, spacing: 6) {
                Spacer()
                Text(story.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
            }
            .padding(12)
        }
        .frame(width: 140, height: 190)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
        .onAppear {
            checkAccess()
        }
        .accessibilityLabel(story.title)
        .accessibilityAddTraits(.isButton)
    }

    private func checkAccess() {
        let userTier = SubscriptionService.shared.currentTier
        let storyTier = SubscriptionTier(rawValue: story.metadata?.tier ?? "free") ?? .free
        isLocked = !canAccessStory(userTier: userTier, storyTier: storyTier)
    }

    private func canAccessStory(userTier: SubscriptionTier, storyTier: SubscriptionTier) -> Bool {
        let tierHierarchy: [SubscriptionTier: Int] = [.free: 0, .plus: 1, .pro: 2]
        return (tierHierarchy[userTier] ?? 0) >= (tierHierarchy[storyTier] ?? 0)
    }

    private var tierBadgeColor: Color {
        let tier = SubscriptionTier(rawValue: story.metadata?.tier ?? "free") ?? .free
        switch tier {
        case .free: return Color.green.opacity(0.8)
        case .plus: return Color.orange.opacity(0.8)
        case .pro: return Color.purple.opacity(0.8)
        }
    }
}

// MARK: - Placeholder

private struct StoryCardPlaceholder: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 4) {
                Image(systemName: "book.fill")
                    .font(.system(size: 34))
                    .foregroundColor(.white.opacity(0.5))
                
                Text("loading_image".localized)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(width: 140, height: 190)
        .cornerRadius(12)
        .shimmering()
    }
}

// MARK: - Locked Overlay

private struct LockedStoryOverlay: View {
    let tierColor: Color
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
            
            VStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Circle().fill(tierColor))
            }
        }
    }
}

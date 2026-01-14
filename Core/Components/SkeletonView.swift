//
//  SkeletonView.swift
//  DreamSpire
//
//  Professional shimmer skeleton loading system
//  Using SwiftUI-Shimmer library for guaranteed smooth animations
//

import SwiftUI
import Shimmer

// MARK: - Shimmer Effect
// Using SwiftUI-Shimmer library - https://github.com/markiv/SwiftUI-Shimmer

// MARK: - Base Skeleton Components

struct SkeletonBox: View {
    var width: CGFloat? = nil
    var height: CGFloat
    var cornerRadius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.white.opacity(0.15))  // Increased visibility
            .frame(width: width, height: height)
            .shimmering(
                active: true,
                duration: 2.0,
                bounce: false,
                delay: 0
            )
    }
}

struct SkeletonCircle: View {
    var size: CGFloat

    var body: some View {
        Circle()
            .fill(Color.white.opacity(0.15))
            .frame(width: size, height: size)
            .shimmering(
                active: true,
                duration: 2.0,
                bounce: false,
                delay: 0
            )
    }
}

// MARK: - Story Card Skeletons

struct StoryCardSkeleton: View {
    var body: some View {
        HStack(spacing: 16) {
            SkeletonBox(width: 80, height: 80, cornerRadius: 12)

            VStack(alignment: .leading, spacing: 10) {
                SkeletonBox(width: 180, height: 18, cornerRadius: 6)
                SkeletonBox(width: 120, height: 14, cornerRadius: 4)

                HStack(spacing: 8) {
                    SkeletonBox(width: 60, height: 24, cornerRadius: 12)
                    SkeletonBox(width: 50, height: 24, cornerRadius: 12)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
        )
    }
}

struct StoryCardSkeletonVertical: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Main skeleton box - same size as StoryCardView
            SkeletonBox(height: 190, cornerRadius: 12)

            // Gradient overlay to match real card
            LinearGradient(
                colors: [Color.black.opacity(0.6), Color.clear],
                startPoint: .bottom,
                endPoint: .center
            )

            // Title skeleton at bottom
            VStack(alignment: .leading, spacing: 4) {
                Spacer()
                SkeletonBox(width: 100, height: 14, cornerRadius: 4)
                    .opacity(0.6)
            }
            .padding(12)
        }
        .frame(width: 140, height: 190)
        .cornerRadius(12)
    }
}

// MARK: - Character Card Skeleton

struct CharacterCardSkeleton: View {
    var body: some View {
        VStack(spacing: 12) {
            SkeletonCircle(size: 70)
            SkeletonBox(width: 80, height: 16, cornerRadius: 4)
            SkeletonBox(width: 60, height: 24, cornerRadius: 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

// MARK: - Template Card Skeleton

struct TemplateCardSkeleton: View {
    // Support both home (140x190) and gallery (flexible x 200) sizes
    var width: CGFloat? = nil
    var height: CGFloat = 200
    var cornerRadius: CGFloat = 12  // Match real card corner radius

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            SkeletonBox(height: height, cornerRadius: cornerRadius)

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.4)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {
                Spacer()
                SkeletonBox(width: 100, height: 14, cornerRadius: 4)
                SkeletonBox(width: 50, height: 10, cornerRadius: 4)
            }
            .padding(10)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Prewritten Story Card Skeleton

struct PrewrittenStoryCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonBox(height: 160, cornerRadius: 12)
            SkeletonBox(height: 16, cornerRadius: 4)
            SkeletonBox(width: 120, height: 12, cornerRadius: 4)
        }
        .padding(10)
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
    }
}

// MARK: - Home Section Skeleton

struct HomeSectionSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SkeletonBox(width: 150, height: 22, cornerRadius: 6)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        StoryCardSkeletonVertical()
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Utility Skeletons

struct InlineSkeleton: View {
    var width: CGFloat = 30
    var height: CGFloat = 16
    
    var body: some View {
        SkeletonBox(width: width, height: height, cornerRadius: 4)
    }
}

// MARK: - Container Views

struct SkeletonList<Content: View>: View {
    let count: Int
    let content: () -> Content
    
    init(count: Int = 5, @ViewBuilder content: @escaping () -> Content) {
        self.count = count
        self.content = content
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<count, id: \.self) { _ in
                content()
            }
        }
    }
}

struct SkeletonGrid<Content: View>: View {
    let columns: Int
    let count: Int
    let spacing: CGFloat
    let content: () -> Content
    
    init(columns: Int = 2, count: Int = 6, spacing: CGFloat = 16, @ViewBuilder content: @escaping () -> Content) {
        self.columns = columns
        self.count = count
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns),
            spacing: spacing
        ) {
            ForEach(0..<count, id: \.self) { _ in
                content()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color(red: 0.1, green: 0.1, blue: 0.2), Color(red: 0.15, green: 0.1, blue: 0.25)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        ScrollView {
            VStack(spacing: 24) {
                Text("Story Card Skeleton")
                    .foregroundColor(.white)
                StoryCardSkeleton()
                    .padding(.horizontal)
                
                Text("Character Card Skeleton")
                    .foregroundColor(.white)
                HStack(spacing: 16) {
                    CharacterCardSkeleton()
                    CharacterCardSkeleton()
                }
                .padding(.horizontal)
                
                Text("Template Card Skeleton")
                    .foregroundColor(.white)
                HStack(spacing: 16) {
                    TemplateCardSkeleton()
                    TemplateCardSkeleton()
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

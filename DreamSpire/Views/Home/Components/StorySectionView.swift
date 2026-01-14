//
//  StorySectionView.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025.
//

import SwiftUI

/// Horizontal scrolling section for displaying stories
struct StorySectionView: View {
    let title: String
    let stories: [Story]
    let seeAllAction: () -> Void
    let storyTapAction: (Story) -> Void

    var body: some View {
        VStack(spacing: 10) {
            // Section Header
            HStack {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: seeAllAction) {
                    HStack(spacing: 4) {
                        Text("home_see_all".localized)
                            .font(.system(size: 15, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
                .accessibilityLabel("Tümünü gör")
            }
            .padding(.horizontal, 20)
            
            // Horizontal Scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(stories.prefix(10)) { story in
                        StoryCardView(story: story)
                            .onTapGesture {
                                storyTapAction(story)
                            }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

#if DEBUG
struct StorySectionView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            LinearGradient.dwBackground
                .ignoresSafeArea()
            
            StorySectionView(
                title: "Popular Stories",
                stories: [],
                seeAllAction: {},
                storyTapAction: { _ in }
            )
        }
    }
}
#endif

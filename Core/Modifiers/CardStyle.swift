//
//  CardStyle.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025.
//

import SwiftUI

// MARK: - Glass Card Style

struct GlassCardStyle: ViewModifier {
    var cornerRadius: CGFloat = 20
    var opacity: Double = 0.15
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(opacity))
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(.ultraThinMaterial)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - Story Card Style

struct StoryCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.15, green: 0.1, blue: 0.25),
                                Color(red: 0.1, green: 0.08, blue: 0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Highlight Card Style

struct HighlightCardStyle: ViewModifier {
    var color: Color = Color.purple
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - View Extensions

extension View {
    /// Apply glass card styling
    func glassCard(cornerRadius: CGFloat = 20, opacity: Double = 0.15) -> some View {
        modifier(GlassCardStyle(cornerRadius: cornerRadius, opacity: opacity))
    }
    
    /// Apply story card styling
    func storyCard() -> some View {
        modifier(StoryCardStyle())
    }
    
    /// Apply highlight card styling
    func highlightCard(color: Color = .purple) -> some View {
        modifier(HighlightCardStyle(color: color))
    }
}

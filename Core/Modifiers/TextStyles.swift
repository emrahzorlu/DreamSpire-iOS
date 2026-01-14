//
//  TextStyles.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025.
//

import SwiftUI

// MARK: - Title Style

struct TitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundColor(.white)
    }
}

// MARK: - Headline Style

struct HeadlineStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
    }
}

// MARK: - Body Style

struct BodyStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .regular))
            .foregroundColor(.white.opacity(0.9))
    }
}

// MARK: - Caption Style

struct CaptionStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 13, weight: .regular))
            .foregroundColor(.white.opacity(0.7))
    }
}

// MARK: - View Extensions

extension View {
    /// Apply title text style
    func titleStyle() -> some View {
        modifier(TitleStyle())
    }
    
    /// Apply headline text style
    func headlineStyle() -> some View {
        modifier(HeadlineStyle())
    }
    
    /// Apply body text style
    func bodyStyle() -> some View {
        modifier(BodyStyle())
    }
    
    /// Apply caption text style
    func captionStyle() -> some View {
        modifier(CaptionStyle())
    }
}

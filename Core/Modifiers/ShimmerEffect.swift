//
//  ShimmerEffect.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025.
//

import SwiftUI

// MARK: - Shimmer Effect

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    var duration: Double = 1.5
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .clear,
                            .white.opacity(0.3),
                            .clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// MARK: - Loading Placeholder

struct LoadingPlaceholder: ViewModifier {
    var cornerRadius: CGFloat = 8
    
    func body(content: Content) -> some View {
        content
            .redacted(reason: .placeholder)
            .modifier(ShimmerEffect())
    }
}

// MARK: - View Extensions

extension View {
    /// Apply shimmer loading effect
    func shimmer(duration: Double = 1.5) -> some View {
        modifier(ShimmerEffect(duration: duration))
    }
    
    /// Apply loading placeholder with shimmer
    func loadingPlaceholder(cornerRadius: CGFloat = 8) -> some View {
        modifier(LoadingPlaceholder(cornerRadius: cornerRadius))
    }
}

//
//  View+Extensions.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//

import SwiftUI

extension View {
    // MARK: - Background Gradients
    
    /// Apply main app background gradient
    func dwBackgroundGradient() -> some View {
        self.background(
            LinearGradient.dwBackground
                .ignoresSafeArea()
        )
    }
    
    /// Apply card background with blur
    func dwCardBackground() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.dwCardLight)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                    )
            )
    }
    
    /// Apply glassmorphism effect
    func dwGlassCard(cornerRadius: CGFloat = 20) -> some View {
        self
            .background(
                ZStack {
                    // Simpler, faster background for better performance
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.white.opacity(0.12))
                    
                    // Blurred background (Material) - only if not in high-perf mode if needed
                    // but keeping it simple for now
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .opacity(0.8)
                    
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
    
    // MARK: - Shadows
    
    /// Apply soft shadow
    func dwShadow(radius: CGFloat = 10, opacity: Double = 0.1) -> some View {
        self.shadow(
            color: Color.black.opacity(opacity),
            radius: radius,
            x: 0,
            y: 4
        )
    }
    
    /// Apply glow effect
    func dwGlow(color: Color = .white, radius: CGFloat = 10) -> some View {
        self.shadow(color: color.opacity(0.5), radius: radius, x: 0, y: 0)
    }
    
    // MARK: - Animations
    
    /// Shimmer loading animation
    func dwShimmer() -> some View {
        self.overlay(
            GeometryReader { geometry in
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.0),
                        Color.white.opacity(0.3),
                        Color.white.opacity(0.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geometry.size.width * 2)
                .offset(x: -geometry.size.width)
            }
            .mask(self)
        )
    }
    
    /// Bounce animation on tap
    func dwBounce(scale: CGFloat = 0.95) -> some View {
        self.buttonStyle(BounceButtonStyle(scale: scale))
    }
    
    // MARK: - Conditional Modifiers
    
    @ViewBuilder
    func `if`<Transform: View>(
        _ condition: Bool,
        transform: (Self) -> Transform
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    // MARK: - Corner Radius
    
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

// MARK: - Bounce Button Style

struct BounceButtonStyle: ButtonStyle {
    let scale: CGFloat
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Rounded Corner Shape

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Keyboard Handling

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
    
    func dismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            hideKeyboard()
        }
    }
}

// MARK: - Loading Overlay

extension View {
    func dwLoadingOverlay(isLoading: Bool, message: String = "Yükleniyor...") -> some View {
        self.overlay(
            Group {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 20) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            
                            Text(message)
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        .padding(30)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.dwPurple.opacity(0.9))
                        )
                        .dwShadow(radius: 20, opacity: 0.3)
                    }
                }
            }
        )
    }
}

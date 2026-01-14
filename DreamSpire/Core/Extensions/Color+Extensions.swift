//
//  Color+Extensions.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//

import SwiftUI

extension Color {
    // MARK: - Brand Colors
    
    /// Primary Accent - Purple (main brand color for splash/animations)
    static let dwAccent = Color(hex: "9D5FEB")
    
    /// Secondary Accent - Pink (complementary brand color)
    static let dwSecondary = Color(hex: "E85FB8")
    
    /// Cyan color - #4DD9E8
    static let dwCyan = Color(hex: "4DD9E8")
    
    /// Light Blue - #5EC8F2
    static let dwLightBlue = Color(hex: "5EC8F2")
    
    /// Purple - #9D5FEB
    static let dwPurple = Color(hex: "9D5FEB")
    
    /// Deep Purple - #7B3FF2
    static let dwDeepPurple = Color(hex: "7B3FF2")
    
    /// Pink - #E85FB8
    static let dwPink = Color(hex: "E85FB8")
    
    /// Gradient Start (Cyan)
    static let dwGradientStart = Color(hex: "4DD9E8")
    
    /// Gradient End (Purple)
    static let dwGradientEnd = Color(hex: "9D5FEB")
    
    // MARK: - Design System Colors (from Figma)
    
    /// Sky Blue - #7DD3FC
    static let dwSkyBlue = Color(hex: "7DD3FC")
    
    /// Soft Blue - #A0B4FF
    static let dwSoftBlue = Color(hex: "A0B4FF")
    
    /// Lavender - #A78BFA
    static let dwLavender = Color(hex: "A78BFA")
    
    /// Violet - #9333EA
    static let dwViolet = Color(hex: "9333EA")
    
    /// Fuchsia - #C026D3
    static let dwFuchsia = Color(hex: "C026D3")
    
    // MARK: - UI Colors
    
    /// Card Background (Light with opacity)
    static let dwCardLight = Color.white.opacity(0.15)
    
    /// Card Background (Purple tint)
    static let dwCardPurple = Color(hex: "B48FFF").opacity(0.2)
    
    /// Card Background (Blue tint)
    static let dwCardBlue = Color(hex: "7DB8FF").opacity(0.2)
    
    /// Success Green
    static let dwSuccess = Color(hex: "4CAF50")
    
    /// Warning Orange
    static let dwWarning = Color(hex: "FF9800")
    
    /// Error Red
    static let dwError = Color(hex: "F44336")
    
    // MARK: - Tier Colors
    
    /// Free tier - Gray
    static let tierFree = Color.gray
    
    /// Plus tier - Blue
    static let tierPlus = Color(hex: "5EC8F2")
    
    /// Pro tier - Purple/Gold gradient
    static let tierPro = Color(hex: "9D5FEB")
    
    // MARK: - Text Colors
    
    /// Primary text (white with slight opacity)
    static let dwTextPrimary = Color.white.opacity(0.95)
    
    /// Secondary text (white with more opacity)
    static let dwTextSecondary = Color.white.opacity(0.6)
    
    /// Tertiary text (white with high opacity)
    static let dwTextTertiary = Color.white.opacity(0.4)
    
    // MARK: - Helper
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Gradient Presets

extension LinearGradient {
    /// Main app background gradient - 5 color gradient matching design
    /// Sky Blue → Soft Blue → Lavender → Violet → Fuchsia
    static let dwBackground = LinearGradient(
        colors: [
            Color.dwSkyBlue,    // #7DD3FC
            Color.dwSoftBlue,   // #A0B4FF
            Color.dwLavender,   // #A78BFA
            Color.dwViolet,     // #9333EA
            Color.dwFuchsia     // #C026D3
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Card gradient (Light Blue to Purple)
    static let dwCard = LinearGradient(
        colors: [Color.dwLightBlue.opacity(0.3), Color.dwPurple.opacity(0.3)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Button gradient (Purple to Pink)
    static let dwButton = LinearGradient(
        colors: [Color.dwPurple, Color.dwPink],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    /// Pro tier gradient (Purple to Gold)
    static let dwProTier = LinearGradient(
        colors: [Color(hex: "9D5FEB"), Color(hex: "FFD700")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Plus tier gradient (Blue shades)
    static let dwPlusTier = LinearGradient(
        colors: [Color(hex: "5EC8F2"), Color(hex: "4A90E2")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension AngularGradient {
    /// Shimmer effect for loading
    static let dwShimmer = AngularGradient(
        colors: [
            Color.white.opacity(0.3),
            Color.white.opacity(0.6),
            Color.white.opacity(0.3)
        ],
        center: .center,
        startAngle: .degrees(0),
        endAngle: .degrees(360)
    )
}

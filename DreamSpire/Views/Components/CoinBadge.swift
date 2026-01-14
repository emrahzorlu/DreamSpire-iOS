//
//  CoinBadge.swift
//  DreamSpire
//
//  Fixed coin badge component that handles 3-digit numbers properly
//  Solves overflow issue in "Uzunluk & Özellikler" screen
//

import SwiftUI

/// Coin badge with dynamic sizing based on digit count
/// Fixes 3-digit number overflow issue
struct CoinBadge: View {
    let amount: Int
    let size: BadgeSize
    
    enum BadgeSize {
        case small   // For inline display (e.g., feature lists)
        case medium  // For feature cards (default)
        case large   // For headers
        
        var iconSize: CGFloat {
            switch self {
            case .small: return 14
            case .medium: return 18
            case .large: return 22
            }
        }
        
        var baseFontSize: CGFloat {
            switch self {
            case .small: return 11
            case .medium: return 13
            case .large: return 15
            }
        }
        
        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6)
            case .medium: return EdgeInsets(top: 5, leading: 8, bottom: 5, trailing: 8)
            case .large: return EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
            }
        }
        
        var minWidth: CGFloat {
            switch self {
            case .small: return 40
            case .medium: return 50
            case .large: return 60
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 3) {
            CoinIconView(size: size.iconSize, showShadow: false)
            
            Text("\(amount)")
                .font(.system(size: dynamicFontSize, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.7) // ✅ KEY FIX: Auto-scale if needed
                .lineLimit(1)
        }
        .padding(size.padding)
        .frame(minWidth: size.minWidth)
        .background(
            Capsule()
                .fill(Color.purple.opacity(0.25))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.purple.opacity(0.4), lineWidth: 1)
        )
    }
    
    // ✅ DYNAMIC FONT SIZE based on digit count
    private var dynamicFontSize: CGFloat {
        let digitCount = String(amount).count
        
        switch (size, digitCount) {
        case (.small, 1...2):
            return size.baseFontSize
        case (.small, 3):
            return size.baseFontSize * 0.85 // 15% smaller for 3 digits
        case (.small, _):
            return size.baseFontSize * 0.75 // 25% smaller for 4+ digits
            
        case (.medium, 1...2):
            return size.baseFontSize
        case (.medium, 3):
            return size.baseFontSize * 0.9 // 10% smaller for 3 digits
        case (.medium, _):
            return size.baseFontSize * 0.8 // 20% smaller for 4+ digits
            
        case (.large, 1...2):
            return size.baseFontSize
        case (.large, 3):
            return size.baseFontSize * 0.95 // 5% smaller for 3 digits
        case (.large, _):
            return size.baseFontSize * 0.85 // 15% smaller for 4+ digits
        }
    }
}

// MARK: - Compact Coin Badge (For very tight spaces)

struct CompactCoinBadge: View {
    let amount: Int
    
    var body: some View {
        HStack(spacing: 2) {
            CoinIconView(size: 12, showShadow: false)
            
            Text("\(amount)")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.purple)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(Color.purple.opacity(0.15))
        )
    }
}

// MARK: - Preview

#Preview("Coin Badges") {
    ZStack {
        LinearGradient(
            colors: [Color.cyan, Color.purple, Color.pink],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        VStack(spacing: 30) {
            // Small badges (for inline use)
            VStack(alignment: .leading, spacing: 12) {
                Text("Small Size")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                HStack(spacing: 12) {
                    CoinBadge(amount: 5, size: .small)
                    CoinBadge(amount: 50, size: .small)
                    CoinBadge(amount: 100, size: .small) // ✅ 3 digits
                    CoinBadge(amount: 500, size: .small) // ✅ 3 digits
                }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            
            // Medium badges (for feature cards)
            VStack(alignment: .leading, spacing: 12) {
                Text("Medium Size (Default)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                HStack(spacing: 12) {
                    CoinBadge(amount: 10, size: .medium)
                    CoinBadge(amount: 100, size: .medium) // ✅ 3 digits
                    CoinBadge(amount: 150, size: .medium) // ✅ 3 digits
                    CoinBadge(amount: 265, size: .medium) // ✅ 3 digits (from screenshot)
                }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            
            // Large badges (for headers)
            VStack(alignment: .leading, spacing: 12) {
                Text("Large Size")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                HStack(spacing: 12) {
                    CoinBadge(amount: 15, size: .large)
                    CoinBadge(amount: 100, size: .large) // ✅ 3 digits
                    CoinBadge(amount: 265, size: .large) // ✅ 3 digits
                    CoinBadge(amount: 1000, size: .large) // ✅ 4 digits
                }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            
            // Compact badges
            VStack(alignment: .leading, spacing: 12) {
                Text("Compact (Ultra Tight Spaces)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                HStack(spacing: 8) {
                    CompactCoinBadge(amount: 5)
                    CompactCoinBadge(amount: 50)
                    CompactCoinBadge(amount: 100)
                    CompactCoinBadge(amount: 265)
                    CompactCoinBadge(amount: 500)
                }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
        }
        .padding()
    }
}

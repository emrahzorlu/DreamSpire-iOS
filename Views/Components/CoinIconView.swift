//
//  CoinIconView.swift
//  DreamSpire
//
//  Reusable coin icon component using custom asset
//  Updated: Improved visibility with shadow and larger sizes
//

import SwiftUI

struct CoinIconView: View {
    var size: CGFloat = 24
    var showShadow: Bool = true
    
    var body: some View {
        Image("CoinIcon")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(
                color: showShadow ? Color.purple.opacity(0.5) : .clear,
                radius: size * 0.15,
                x: 0,
                y: size * 0.05
            )
    }
}

#Preview {
    VStack(spacing: 30) {
        // Light background test
        HStack(spacing: 20) {
            CoinIconView(size: 20)
            CoinIconView(size: 28)
            CoinIconView(size: 36)
            CoinIconView(size: 48)
        }
        .padding()
        .background(Color.white.opacity(0.9))
        .cornerRadius(12)
        
        // Dark background test
        HStack(spacing: 20) {
            CoinIconView(size: 20)
            CoinIconView(size: 28)
            CoinIconView(size: 36)
            CoinIconView(size: 48)
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(12)
        
        // Gradient background test (like app)
        HStack(spacing: 20) {
            CoinIconView(size: 20)
            CoinIconView(size: 28)
            CoinIconView(size: 36)
            CoinIconView(size: 48)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.purple, Color.blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
    }
    .padding()
    .background(Color.gray.opacity(0.3))
}

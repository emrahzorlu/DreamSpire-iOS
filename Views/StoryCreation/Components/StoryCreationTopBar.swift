//
//  StoryCreationTopBar.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025.
//

import SwiftUI

/// Top navigation bar for story creation flow
struct StoryCreationTopBar: View {
    let onBack: () -> Void
    var showCoinBalance: Bool = true
    
    var body: some View {
        HStack {
            // Back button
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .accessibleButton("Geri", hint: "Önceki adıma dön")
            
            Spacer()
            
            // Coin balance
            if showCoinBalance {
                CompactCoinBalanceView()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

// MARK: - Preview

#if DEBUG
struct StoryCreationTopBar_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            LinearGradient(
                colors: [Color.purple, Color.pink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack {
                StoryCreationTopBar(onBack: {})
                Spacer()
            }
        }
    }
}
#endif

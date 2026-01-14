//
//  StatCard.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025-11-03
//

import SwiftUI

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.cyan)
            
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LinearGradient.dwBackground
            .ignoresSafeArea()
        
        HStack(spacing: 12) {
            StatCard(
                icon: "book.fill",
                value: "5",
                label: "Hikayede Kullanıldı"
            )
            
            StatCard(
                icon: "clock.fill",
                value: "3 gün önce",
                label: "Son Kullanım"
            )
        }
        .padding(.horizontal, 20)
    }
}

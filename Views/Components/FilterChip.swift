//
//  FilterChip.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025-11-03
//

import SwiftUI

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            isSelected
                            ? LinearGradient(
                                colors: [Color.cyan, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            : LinearGradient(
                                colors: [Color.white.opacity(0.15), Color.white.opacity(0.15)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            isSelected ? Color.clear : Color.white.opacity(0.2),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LinearGradient.dwBackground
            .ignoresSafeArea()
        
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                FilterChip(title: "Tümü", isSelected: true, action: {})
                FilterChip(title: "Macera", isSelected: false, action: {})
                FilterChip(title: "Fantastik", isSelected: false, action: {})
            }
            
            HStack(spacing: 12) {
                FilterChip(title: "Free", isSelected: false, action: {})
                FilterChip(title: "Plus", isSelected: true, action: {})
                FilterChip(title: "Pro", isSelected: false, action: {})
            }
        }
    }
}

//
//  GuestUserHeader.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025.
//

import SwiftUI

/// Guest user profile header with login prompt
struct GuestUserHeader: View {
    var onLoginTap: (() -> Void)? = nil
    
    var body: some View {
        Button(action: {
            onLoginTap?()
        }) {
            HStack(spacing: 16) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.545, green: 0.361, blue: 0.965).opacity(0.6), 
                                     Color(red: 0.902, green: 0.475, blue: 0.976).opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .overlay(Image(systemName: "person.fill").font(.title2).foregroundColor(.white))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("guest_user".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.caption)
                            .foregroundColor(Color(red: 0.545, green: 0.361, blue: 0.965))
                        Text("settings_tap_to_login".localized)
                            .font(.caption)
                            .foregroundColor(Color(red: 0.545, green: 0.361, blue: 0.965))
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.white.opacity(0.15), Color.white.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(red: 0.545, green: 0.361, blue: 0.965).opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Giriş yapmak için dokunun")
    }
}

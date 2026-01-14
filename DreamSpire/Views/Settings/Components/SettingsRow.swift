//
//  SettingsRow.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025.
//

import SwiftUI

/// Button row for settings menu items
struct SettingsButtonRow: View {
    let icon: String
    let color: Color
    let title: String
    var value: String? = nil
    var isLoading: Bool = false
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon Box
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color)
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .foregroundColor(.white)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white.opacity(0.6))
                } else if let value = value {
                    Text(value)
                        .foregroundColor(.white.opacity(0.6))
                        .font(.subheadline)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .accessibilityLabel(title)
    }
}

/// Toggle row for settings on/off options
struct SettingsToggleRow: View {
    let icon: String
    let color: Color
    let title: String
    @Binding var isOn: Bool
    var onChange: ((Bool) -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }

            Toggle(title, isOn: Binding(
                get: { isOn },
                set: { newValue in
                    if let onChange = onChange {
                        onChange(newValue)
                    } else {
                        isOn = newValue
                    }
                }
            ))
            .foregroundColor(.white)
        }
        .accessibilityLabel("\(title), \(isOn ? "açık" : "kapalı")")
    }
}

/// Locked characters row with upgrade prompt
struct LockedCharactersRow: View {
    var onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon with lock overlay
                ZStack(alignment: .bottomTrailing) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.purple)
                            .frame(width: 30, height: 30)
                        Image(systemName: "theatermasks.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    // Small lock badge
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.white)
                        .padding(2)
                        .background(Circle().fill(Color.orange))
                        .offset(x: 4, y: 4)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("settings_my_characters".localized)
                        .foregroundColor(.white)
                        .font(.body)
                    
                    Text("settings_characters_locked".localized)
                        .foregroundColor(.orange.opacity(0.9))
                        .font(.caption)
                }
                
                Spacer()
                
                // Upgrade badge
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.caption2)
                    Text("upgrade".localized)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color.orange, Color.pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                )
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .accessibilityLabel("Karakterlerim - Yükseltme gerekli")
    }
}

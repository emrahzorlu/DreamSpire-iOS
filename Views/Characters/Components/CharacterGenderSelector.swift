//
//  CharacterGenderSelector.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//

import SwiftUI

struct CharacterGenderSelector: View {
    @Binding var selectedGender: CharacterGender
    
    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("character_gender".localized)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach([CharacterGender.male, CharacterGender.female, CharacterGender.unspecified], id: \.self) { gender in
                    GenderButton(
                        gender: gender,
                        isSelected: selectedGender == gender,
                        action: { selectedGender = gender }
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
        )
    }
}

private struct GenderButton: View {
    let gender: CharacterGender
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(gender.icon)
                    .font(.system(size: 24))

                Text(gender.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue.opacity(0.3) : Color.white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue : Color.white.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

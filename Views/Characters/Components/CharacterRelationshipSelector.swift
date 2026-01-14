//
//  CharacterRelationshipSelector.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//

import SwiftUI

struct CharacterRelationshipSelector: View {
    @Binding var selectedRelationship: CharacterRelationship?
    
    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("character_relationship_title".localized)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)

            Text("character_relationship_hint".localized)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(CharacterRelationship.selectableCases, id: \.self) { relationship in
                    RelationshipButton(
                        relationship: relationship,
                        isSelected: selectedRelationship == relationship,
                        action: {
                            if selectedRelationship == relationship {
                                selectedRelationship = nil
                            } else {
                                selectedRelationship = relationship
                            }
                        }
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

private struct RelationshipButton: View {
    let relationship: CharacterRelationship
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(relationship.icon)
                    .font(.system(size: 24))

                Text(relationship.displayName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.purple.opacity(0.3) : Color.white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.purple : Color.white.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

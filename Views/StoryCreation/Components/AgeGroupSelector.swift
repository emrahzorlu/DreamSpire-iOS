//
//  AgeGroupSelector.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025.
//

import SwiftUI

/// Age group selection options
enum AgeGroup: String, CaseIterable, Identifiable {
    case preschool = "preschool"
    case earlyElementary = "early_elementary"
    case lateElementary = "late_elementary"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .preschool:
            return "age_preschool".localized
        case .earlyElementary:
            return "age_early_elementary".localized
        case .lateElementary:
            return "age_late_elementary".localized
        }
    }
    
    var ageRange: String {
        switch self {
        case .preschool:
            return "4-6"
        case .earlyElementary:
            return "7-9"
        case .lateElementary:
            return "10-12"
        }
    }
    
    var icon: String {
        switch self {
        case .preschool:
            return "🧒"
        case .earlyElementary:
            return "👦"
        case .lateElementary:
            return "🧑"
        }
    }
}

/// Age group selection component
struct AgeGroupSelector: View {
    @Binding var selectedAgeGroup: AgeGroup
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("age_group_title".localized)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                ForEach(AgeGroup.allCases) { ageGroup in
                    AgeGroupButton(
                        ageGroup: ageGroup,
                        isSelected: selectedAgeGroup == ageGroup
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedAgeGroup = ageGroup
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Age Group Button

private struct AgeGroupButton: View {
    let ageGroup: AgeGroup
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(ageGroup.icon)
                    .font(.system(size: 28))
                
                Text(ageGroup.ageRange)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Text(ageGroup.displayName)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.white.opacity(0.5) : Color.clear, lineWidth: 2)
            )
        }
        .accessibilityLabel("\(ageGroup.displayName), \(ageGroup.ageRange) yaş")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Preview

#if DEBUG
struct AgeGroupSelector_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            LinearGradient(
                colors: [Color.purple, Color.pink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            AgeGroupSelector(selectedAgeGroup: .constant(.earlyElementary))
                .padding()
        }
    }
}
#endif

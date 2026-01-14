//
//  StoryCreationProgressView.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025.
//

import SwiftUI

/// Progress indicator for story creation steps
struct StoryCreationProgressView: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        VStack(spacing: 8) {
            // Step label
            Text("step_\(currentStep)_of_\(totalSteps)".localized)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
            
            // Progress dots
            HStack(spacing: 8) {
                ForEach(1...totalSteps, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(step == currentStep ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3), value: currentStep)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Adım \(currentStep) / \(totalSteps)")
    }
}

// MARK: - Preview

#if DEBUG
struct StoryCreationProgressView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            LinearGradient(
                colors: [Color.purple, Color.pink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                StoryCreationProgressView(currentStep: 1, totalSteps: 4)
                StoryCreationProgressView(currentStep: 2, totalSteps: 4)
                StoryCreationProgressView(currentStep: 3, totalSteps: 4)
                StoryCreationProgressView(currentStep: 4, totalSteps: 4)
            }
        }
    }
}
#endif

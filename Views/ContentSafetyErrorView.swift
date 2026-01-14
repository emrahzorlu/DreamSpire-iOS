//
//  ContentSafetyErrorView.swift
//  DreamSpire
//
//  Created by Claude on 2024-12-23.
//  Beautiful, helpful error presentation for content safety violations
//

import SwiftUI

struct ContentSafetyErrorView: View {

    // MARK: - Properties

    let error: ContentSafetyError
    let onTryExample: (String) -> Void
    let onDismiss: () -> Void

    @Environment(\.colorScheme) var colorScheme

    // MARK: - Body

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 28) {
                    // Header Icon with Animation
                    headerIcon

                    // Title & Message
                    titleAndMessage

                    // Suggestion Box
                    if !error.suggestion.isEmpty {
                        suggestionBox(error.suggestion)
                    }

                    // Example Topics (Tappable)
                    if !error.examples.isEmpty {
                        exampleTopics
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .background(backgroundColor)
            .navigationTitle(LocalizedStringKey("content_safety_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onDismiss()
                    } label: {
                        Text(LocalizedStringKey("ok"))
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private var headerIcon: some View {
        ZStack {
            // Background circle with gradient
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.2),
                            Color.orange.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)

            // Icon
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 50, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.orange, Color.orange.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .padding(.top, 10)
    }

    private var titleAndMessage: some View {
        VStack(spacing: 12) {
            Text(error.title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)

            Text(error.message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
    }

    private func suggestionBox(_ suggestion: String) -> some View {
        HStack(spacing: 12) {
            // Lightbulb icon
            Image(systemName: "lightbulb.fill")
                .font(.title3)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.yellow, Color.orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey("suggestion"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(suggestion)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.yellow.opacity(colorScheme == .dark ? 0.15 : 0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }

    private var exampleTopics: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.headline)
                    .foregroundColor(.blue)

                Text(LocalizedStringKey("example_topics"))
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            // Example cards
            VStack(spacing: 12) {
                ForEach(Array(error.examples.enumerated()), id: \.offset) { index, example in
                    exampleCard(example, index: index)
                }
            }
        }
    }

    private func exampleCard(_ example: String, index: Int) -> some View {
        Button {
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()

            // Use example
            onTryExample(example)
        } label: {
            HStack(spacing: 12) {
                // Number badge
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Text("\(index + 1)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                }

                // Example text
                Text(example)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                // Arrow icon
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.blue.opacity(colorScheme == .dark ? 0.12 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Computed Properties

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(UIColor.systemBackground) : Color(UIColor.systemGroupedBackground)
    }
}

// MARK: - Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("Turkish Error") {
    let mockError = ContentSafetyError(
        from: ContentSafetyErrorResponse.ContentSafetyErrorDetail(
            title: "İçerik Uygun Değil",
            message: "Hikaye konusu çocuklar için uygun olmayan kelimeler içeriyor.",
            suggestion: "Lütfen daha dostça bir konu seçin. Örneğin: arkadaşlık, macera, hayvanlar, keşif...",
            examples: [
                "Bir sincabın orman maceraları",
                "Arkadaşlığın gücü",
                "Cesur bir kızın yolculuğu",
                "Denizin derinliklerinde bir macera"
            ],
            canRetry: true,
            reason: "inappropriate_keywords"
        )
    )

    return ContentSafetyErrorView(
        error: mockError,
        onTryExample: { example in
            print("Selected: \(example)")
        },
        onDismiss: {
            print("Dismissed")
        }
    )
}

#Preview("English Error") {
    let mockError = ContentSafetyError(
        from: ContentSafetyErrorResponse.ContentSafetyErrorDetail(
            title: "Content Not Appropriate",
            message: "The story topic contains words that aren't suitable for children.",
            suggestion: "Please choose a friendlier topic. For example: friendship, adventure, animals, discovery...",
            examples: [
                "A squirrel's forest adventure",
                "The power of friendship",
                "A brave girl's journey"
            ],
            canRetry: true,
            reason: "inappropriate_keywords"
        )
    )

    return ContentSafetyErrorView(
        error: mockError,
        onTryExample: { example in
            print("Selected: \(example)")
        },
        onDismiss: {
            print("Dismissed")
        }
    )
    .preferredColorScheme(.dark)
}

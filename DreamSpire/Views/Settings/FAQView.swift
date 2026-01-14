//
//  FAQView.swift
//  DreamSpire
//
//  Frequently Asked Questions screen
//

import SwiftUI

struct FAQView: View {
    @Environment(\.dismiss) var dismiss
    @State private var expandedQuestions: Set<Int> = []

    let faqCategories: [(title: String, questions: [(question: String, answer: String)])] = [
        (
            title: "faq_category_account".localized,
            questions: [
                ("faq_account_q1".localized, "faq_account_a1".localized),
                ("faq_account_q2".localized, "faq_account_a2".localized),
                ("faq_account_q3".localized, "faq_account_a3".localized)
            ]
        ),
        (
            title: "faq_category_stories".localized,
            questions: [
                ("faq_stories_q1".localized, "faq_stories_a1".localized),
                ("faq_stories_q2".localized, "faq_stories_a2".localized),
                ("faq_stories_q3".localized, "faq_stories_a3".localized),
                ("faq_stories_q4".localized, "faq_stories_a4".localized)
            ]
        ),
        (
            title: "faq_category_characters".localized,
            questions: [
                ("faq_characters_q1".localized, "faq_characters_a1".localized),
                ("faq_characters_q2".localized, "faq_characters_a2".localized),
                ("faq_characters_q3".localized, "faq_characters_a3".localized)
            ]
        ),
        (
            title: "faq_category_subscription".localized,
            questions: [
                ("faq_subscription_q1".localized, "faq_subscription_a1".localized),
                ("faq_subscription_q2".localized, "faq_subscription_a2".localized),
                ("faq_subscription_q3".localized, "faq_subscription_a3".localized),
                ("faq_subscription_q4".localized, "faq_subscription_a4".localized)
            ]
        ),
        (
            title: "faq_category_technical".localized,
            questions: [
                ("faq_technical_q1".localized, "faq_technical_a1".localized),
                ("faq_technical_q2".localized, "faq_technical_a2".localized),
                ("faq_technical_q3".localized, "faq_technical_a3".localized)
            ]
        ),
        (
            title: "faq_category_safety".localized,
            questions: [
                ("faq_safety_q1".localized, "faq_safety_a1".localized),
                ("faq_safety_q2".localized, "faq_safety_a2".localized),
                ("faq_safety_q3".localized, "faq_safety_a3".localized),
                ("faq_safety_q4".localized, "faq_safety_a4".localized)
            ]
        )
    ]

    var body: some View {
        ZStack {
            LinearGradient.dwBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    Text("faq_title".localized)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

                ScrollView {
                    VStack(spacing: 24) {
                        ForEach(Array(faqCategories.enumerated()), id: \.offset) { categoryIndex, category in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(category.title)
                                    .font(.title3.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal)

                                ForEach(Array(category.questions.enumerated()), id: \.offset) { questionIndex, item in
                                    let globalIndex = categoryIndex * 100 + questionIndex
                                    FAQItem(
                                        question: item.question,
                                        answer: item.answer,
                                        isExpanded: expandedQuestions.contains(globalIndex),
                                        onTap: {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                if expandedQuestions.contains(globalIndex) {
                                                    expandedQuestions.remove(globalIndex)
                                                } else {
                                                    expandedQuestions.insert(globalIndex)
                                                }
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
        }
    }
}

struct FAQItem: View {
    let question: String
    let answer: String
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack(alignment: .top, spacing: 12) {
                    Text(question)
                        .font(.body.weight(.medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding()
            }

            if isExpanded {
                Text(answer)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal)
                    .padding(.bottom)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            Color.white.opacity(0.15)
                .overlay(Color.white.opacity(0.05))
        )
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

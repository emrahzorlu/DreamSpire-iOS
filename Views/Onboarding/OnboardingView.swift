//
//  OnboardingView.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//

import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    
    var onComplete: (OnboardingResult) -> Void
    
    enum OnboardingResult {
        case guest
        case login
        case createAccount
    }
    
    private var pages: [OnboardingPage] {
        [
            OnboardingPage(
                emoji: "✨",
                title: "onboarding_page1_title".localized,
                description: "onboarding_page1_desc".localized,
                imageName: "sparkles"
            ),
            OnboardingPage(
                emoji: "👥",
                title: "onboarding_page2_title".localized,
                description: "onboarding_page2_desc".localized,
                imageName: "person.2.fill"
            ),
            OnboardingPage(
                emoji: "🎧",
                title: "onboarding_page3_title".localized,
                description: "onboarding_page3_desc".localized,
                imageName: "headphones"
            )
        ]
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient.dwBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    
                    Button(action: skipOnboarding) {
                        Text("onboarding_skip".localized)
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                    }
                }
                .padding(.top, 16)
                .padding(.horizontal, 20)
                
                // TabView for pages
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) {
                        index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Page indicator and button
                VStack(spacing: 24) {
                    // Custom page indicator
                    HStack(spacing: 12) {
                        ForEach(0..<pages.count, id: \.self) {
                            index in
                            Circle()
                                .fill(currentPage == index ? Color.white : Color.white.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .animation(.easeInOut(duration: 0.3), value: currentPage)
                        }
                    }
                    
                    // Continue/Get Started button
                    VStack(spacing: 16) {
                        DWButton(
                            title: currentPage == pages.count - 1 ? "onboarding_create_account".localized : "continue".localized,
                            style: .primary
                        ) {
                            if currentPage < pages.count - 1 {
                                withAnimation {
                                    currentPage += 1
                                }
                            } else {
                                // Request to show Create Account screen
                                onComplete(.createAccount)
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(Constants.UI.buttonCornerRadius)
                        
                        if currentPage == pages.count - 1 {
                            VStack(spacing: 12) {
                                Button(action: { onComplete(.login) }) {
                                    Text("onboarding_already_have_account".localized)
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.7))
                                        .underline()
                                }
                                
                                Button(action: { onComplete(.guest) }) {
                                    Text("onboarding_continue_guest".localized)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            DWLogger.shared.logViewAppear("OnboardingView")
            DWLogger.shared.info("Onboarding started", category: .ui)
        }
    }
    
    private func skipOnboarding() {
        DWLogger.shared.info("User skipped onboarding", category: .ui)
        DWLogger.shared.logUserAction("Skipped Onboarding")
        onComplete(.login)
    }
}

// MARK: - Onboarding Page Model

struct OnboardingPage {
    let emoji: String
    let title: String
    let description: String
    let imageName: String
}

// MARK: - Onboarding Page View

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Illustration/Icon
            VStack(spacing: 24) {
                // Large emoji or SF Symbol
                if page.emoji.isEmpty {
                    Image(systemName: page.imageName)
                        .font(.system(size: 120))
                        .foregroundColor(.white.opacity(0.9))
                } else {
                    Text(page.emoji)
                        .font(.system(size: 120))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 300)
            
            Spacer()
            
            // Content
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(page.description)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
                .frame(height: 60)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Preview

#Preview {
    OnboardingView { result in
        print("Onboarding completed with result: \(result)")
    }
}

//
//  EnchantedOnboardingView.swift
//  DreamSpire
//
//  Magical animated onboarding experience
//

import SwiftUI

struct EnchantedOnboardingView: View {
    @State private var currentPage = 0
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var feature1Opacity: Double = 0
    @State private var feature2Opacity: Double = 0
    @State private var feature3Opacity: Double = 0
    @State private var feature4Opacity: Double = 0
    @State private var particlesVisible = true
    @State private var glowIntensity: Double = 0
    
    var onComplete: (OnboardingResult) -> Void
    
    enum OnboardingResult {
        case guest
        case login
        case createAccount
    }
    
    private let pages: [OnboardingPageData] = [
        OnboardingPageData(
            imageName: "Onboarding1",
            titleKey: "onboarding_new_page1_title",
            subtitleKey: "onboarding_new_page1_subtitle",
            feature1Key: "onboarding_page1_feature1",
            feature1Icon: "sparkles",
            feature2Key: "onboarding_page1_feature2",
            feature2Icon: "book.fill",
            feature3Key: "onboarding_page1_feature3",
            feature3Icon: "wand.and.stars",
            accentColor: Color(red: 0.58, green: 0.4, blue: 0.8)
        ),
        OnboardingPageData(
            imageName: "Onboarding2",
            titleKey: "onboarding_new_page2_title",
            subtitleKey: "onboarding_new_page2_subtitle",
            feature1Key: "onboarding_page2_feature1",
            feature1Icon: "person.2.fill",
            feature2Key: "onboarding_page2_feature2",
            feature2Icon: "paintbrush.fill",
            feature3Key: "onboarding_page2_feature3",
            feature3Icon: "star.fill",
            accentColor: Color(red: 0.91, green: 0.43, blue: 0.64)
        ),
        OnboardingPageData(
            imageName: "Onboarding3",
            titleKey: "onboarding_new_page3_title",
            subtitleKey: "onboarding_new_page3_subtitle",
            feature1Key: "onboarding_page3_feature1",
            feature1Icon: "headphones",
            feature2Key: "onboarding_page3_feature2",
            feature2Icon: "text.book.closed.fill",
            feature3Key: "onboarding_page3_feature3",
            feature3Icon: "photo.stack",
            feature4Key: "onboarding_page3_feature4",
            feature4Icon: "sparkle.magnifyingglass",
            accentColor: Color(red: 0.24, green: 0.74, blue: 0.83)
        )
    ]
    
    var body: some View {
        ZStack {
            // Background images with smooth transitions
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    EnchantedPageView(
                        page: pages[index],
                        pageIndex: index,
                        currentPage: $currentPage
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .allowsHitTesting(false)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.8), value: currentPage)
            
            // Floating magical particles overlay
            if particlesVisible {
                MagicalParticlesView(accentColor: pages[currentPage].accentColor)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
            
            // UI Layer
            VStack(spacing: 0) {
                // Top bar - page indicator and skip button
                HStack(alignment: .top) {
                    // Page indicator on left
                    CustomPageIndicator(
                        currentPage: currentPage,
                        pageCount: pages.count,
                        accentColor: pages[currentPage].accentColor
                    )
                    .padding(.top, 10)

                    Spacer()

                    // Skip button on right
                    Button(action: skipOnboarding) {
                        Text("onboarding_skip".localized)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.3))
                                    .background(
                                        Capsule()
                                            .fill(.ultraThinMaterial)
                                    )
                            )
                            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    }
                }
                .padding(.top, 16)
                .padding(.horizontal, 20)


                Spacer()

                // Content area - bottom of screen above button
                VStack(alignment: .leading, spacing: 12) {
                    // Title with magical entrance (left-aligned)
                    Text(pages[currentPage].titleKey.localized)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
                        .shadow(color: pages[currentPage].accentColor.opacity(0.6), radius: 16, x: 0, y: 0)
                        .opacity(titleOpacity)

                    // Subtitle with delayed entrance
                    Text(pages[currentPage].subtitleKey.localized)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
                        .opacity(subtitleOpacity)

                    // Feature bullets (staggered animation) - no icons
                    VStack(alignment: .leading, spacing: 10) {
                        FeatureBulletView(
                            text: pages[currentPage].feature1Key.localized
                        )
                        .opacity(feature1Opacity)

                        FeatureBulletView(
                            text: pages[currentPage].feature2Key.localized
                        )
                        .opacity(feature2Opacity)

                        FeatureBulletView(
                            text: pages[currentPage].feature3Key.localized
                        )
                        .opacity(feature3Opacity)

                        if currentPage == pages.count - 1 {
                            FeatureBulletView(
                                text: pages[currentPage].feature4Key?.localized ?? ""
                            )
                            .opacity(feature4Opacity)
                        }
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 24)
                .padding(.trailing, 32)
                .padding(.bottom, 24)

                // Bottom section - just button
                VStack(spacing: 0) {

                    // Action button
                    Button(action: handleMainAction) {
                        HStack(spacing: 12) {
                            Text(currentPage == pages.count - 1 ? "onboarding_start_button".localized : "continue".localized)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color(red: 0.2, green: 0.15, blue: 0.35))

                            Image(systemName: currentPage == pages.count - 1 ? "arrow.right.circle.fill" : "arrow.right")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color(red: 0.2, green: 0.15, blue: 0.35))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(
                            ZStack {
                                // Gradient background
                                LinearGradient(
                                    colors: [.white, Color(white: 0.95)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )

                                // Glow effect
                                LinearGradient(
                                    colors: [pages[currentPage].accentColor.opacity(glowIntensity * 0.3), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: pages[currentPage].accentColor.opacity(0.4), radius: 20, y: 8)
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .onChange(of: currentPage) { oldValue, newValue in
            animatePageContent()
        }
        .onAppear {
            animatePageContent()
            startGlowAnimation()
            DWLogger.shared.logViewAppear("EnchantedOnboardingView")
        }
    }
    
    private func animatePageContent() {
        // Quick fade out
        withAnimation(.easeIn(duration: 0.2)) {
            titleOpacity = 0
            subtitleOpacity = 0
            feature1Opacity = 0
            feature2Opacity = 0
            feature3Opacity = 0
            feature4Opacity = 0
        }

        // Then fade in with staggered timing after fade out completes
        withAnimation(.easeOut(duration: 0.4).delay(0.25)) {
            titleOpacity = 1
        }

        withAnimation(.easeOut(duration: 0.4).delay(0.35)) {
            subtitleOpacity = 1
        }

        withAnimation(.easeOut(duration: 0.4).delay(0.45)) {
            feature1Opacity = 1
        }

        withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
            feature2Opacity = 1
        }

        withAnimation(.easeOut(duration: 0.4).delay(0.55)) {
            feature3Opacity = 1
        }

        withAnimation(.easeOut(duration: 0.4).delay(0.6)) {
            feature4Opacity = 1
        }
    }
    
    private func startGlowAnimation() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            glowIntensity = 1.0
        }
    }
    
    private func handleMainAction() {
        if currentPage < pages.count - 1 {
            withAnimation(.easeInOut(duration: 0.6)) {
                currentPage += 1
            }
        } else {
            // Request notification permission before finishing
            Task {
                _ = await NotificationManager.shared.requestPermission()
                // Last page goes to login
                await MainActor.run {
                    onComplete(.login)
                }
            }
        }
    }
    
    private func skipOnboarding() {
        DWLogger.shared.logUserAction("Skipped Onboarding")
        onComplete(.login)
    }
}

// MARK: - Enchanted Page View

struct EnchantedPageView: View {
    let page: OnboardingPageData
    let pageIndex: Int
    @Binding var currentPage: Int
    
    @State private var imageScale: CGFloat = 1.0
    @State private var imageOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.2, green: 0.25, blue: 0.45),
                        Color(red: 0.15, green: 0.2, blue: 0.35),
                        Color(red: 0.1, green: 0.15, blue: 0.25)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Background image - aligned to top
                VStack(spacing: 0) {
                    Image(page.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width)
                        .scaleEffect(imageScale)

                    Spacer(minLength: 0)
                }
                .ignoresSafeArea()

                // Dark overlay at bottom for button area
                VStack {
                    Spacer()

                    LinearGradient(
                        colors: [
                            .clear,
                            .black.opacity(0.3)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 200)
                }
                .ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startBreathingAnimation()
        }
    }
    
    private func startBreathingAnimation() {
        withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
            imageScale = 1.05
        }
    }
}

// MARK: - Magical Particles View

struct MagicalParticlesView: View {
    let accentColor: Color
    @State private var particles: [MagicalParticle] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(accentColor.opacity(particle.opacity))
                        .frame(width: particle.size, height: particle.size)
                        .position(particle.position)
                }
            }
            .drawingGroup() // GPU rendering for smoother animations
            .onAppear {
                generateParticles(in: geometry.size)
                startParticleAnimation(in: geometry.size)
            }
        }
    }
    
    private func generateParticles(in size: CGSize) {
        // Reduced from 30 to 15 for better performance
        particles = (0..<15).map { _ in
            MagicalParticle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height)
                ),
                size: CGFloat.random(in: 3...10),
                opacity: Double.random(in: 0.3...0.7),
                blur: 0 // Removed blur for performance
            )
        }
    }
    
    private func startParticleAnimation(in size: CGSize) {
        for index in particles.indices {
            let delay = Double.random(in: 0...2)
            let duration = Double.random(in: 4...8)
            
            withAnimation(
                .easeInOut(duration: duration)
                .repeatForever(autoreverses: true)
                .delay(delay)
            ) {
                particles[index].position.y -= CGFloat.random(in: 30...80)
                particles[index].opacity = Double.random(in: 0.2...0.5)
            }
        }
    }
}

struct MagicalParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    let size: CGFloat
    var opacity: Double
    let blur: CGFloat
}

// MARK: - Custom Page Indicator

struct CustomPageIndicator: View {
    let currentPage: Int
    let pageCount: Int
    let accentColor: Color

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                if index == currentPage {
                    // Active indicator - white capsule with shadow
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 36, height: 10)
                        .shadow(color: .white.opacity(0.5), radius: 6, x: 0, y: 0)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    // Inactive indicator - white circle with shadow
                    Circle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 10, height: 10)
                        .shadow(color: .white.opacity(0.3), radius: 4, x: 0, y: 0)
                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: currentPage)
    }
}

// MARK: - Page Data Model

struct OnboardingPageData {
    let imageName: String
    let titleKey: String
    let subtitleKey: String
    let feature1Key: String
    let feature1Icon: String
    let feature2Key: String
    let feature2Icon: String
    let feature3Key: String
    let feature3Icon: String
    let feature4Key: String?
    let feature4Icon: String?
    let accentColor: Color

    init(imageName: String, titleKey: String, subtitleKey: String,
         feature1Key: String, feature1Icon: String,
         feature2Key: String, feature2Icon: String,
         feature3Key: String, feature3Icon: String,
         feature4Key: String? = nil, feature4Icon: String? = nil,
         accentColor: Color) {
        self.imageName = imageName
        self.titleKey = titleKey
        self.subtitleKey = subtitleKey
        self.feature1Key = feature1Key
        self.feature1Icon = feature1Icon
        self.feature2Key = feature2Key
        self.feature2Icon = feature2Icon
        self.feature3Key = feature3Key
        self.feature3Icon = feature3Icon
        self.feature4Key = feature4Key
        self.feature4Icon = feature4Icon
        self.accentColor = accentColor
    }
}

// MARK: - Feature Bullet View

struct FeatureBulletView: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Simple bullet point
            Circle()
                .fill(Color.white)
                .frame(width: 6, height: 6)
                .padding(.top, 7)
            
            Text(text)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true) // Allow text to wrap to multiple lines
                .shadow(color: .black.opacity(0.5), radius: 6, y: 3)
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    EnchantedOnboardingView { result in
        print("Onboarding completed: \(result)")
    }
}

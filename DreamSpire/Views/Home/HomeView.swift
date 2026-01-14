//
//  HomeView.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//

import SwiftUI
import SDWebImageSwiftUI

struct HomeView: View {
    @State private var selectedTab: DWTab = .home
    @State private var showingProfile = false
    @State private var storyToOpen: Story?

    var onSignOut: () -> Void
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient.dwBackground
                .edgesIgnoringSafeArea(.all)

            // Tab content - Each view persists in memory
            TabView(selection: $selectedTab) {
                HomeContentView(
                    selectedTab: $selectedTab,
                    showingProfile: $showingProfile
                )
                .tag(DWTab.home)

                StoryCreationFlowView(presentedFromTab: true)
                    .tag(DWTab.create)

                UserLibraryView(
                    onLoginRequest: onSignOut,
                    onCreateStory: {
                        selectedTab = .create
                    }
                )
                .tag(DWTab.library)

                SettingsView(onSignOut: onSignOut)
                    .tag(DWTab.settings)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
            .ignoresSafeArea(.all, edges: .bottom)

            // Custom Tab Bar - floating overlay
            VStack {
                Spacer()
                DWTabBar(selectedTab: $selectedTab)
                    .padding(.bottom, 0)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(isPresented: $showingProfile) {
            ProfileView(onSignOut: onSignOut)
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToGenerateTab)) { _ in
            withAnimation {
                selectedTab = .create
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToLibrary)) { _ in
            withAnimation {
                selectedTab = .library
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToLibraryMyStories)) { _ in
            withAnimation {
                selectedTab = .library
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openStory)) { notification in
            // Handle opening a story from notification
            guard let storyId = notification.userInfo?["storyId"] as? String else { return }

            Task {
                // Try to fetch the story from repository (uses cache if available)
                do {
                    let story = try await StoryRepository.shared.getStory(id: storyId)
                    await MainActor.run {
                        storyToOpen = story
                        // Also navigate to library tab to show the story
                        withAnimation {
                            selectedTab = .library
                        }
                    }
                } catch {
                    DWLogger.shared.error("Failed to fetch story from notification", error: error, category: .story)
                }
            }
        }
        .fullScreenCover(item: $storyToOpen) { story in
            StoryReaderView(story: story)
        }
        .preferredColorScheme(.light)
    }
}

// MARK: - Home Content

struct HomeContentView: View {
    @Binding var selectedTab: DWTab
    @Binding var showingProfile: Bool
    // Track selected category for Prewritten Library (nil = not showing, "" = all, "animals" = filtered)
    @State private var selectedPrewrittenCategory: String? = nil
    @State private var showingPaywall = false
    @State private var showingTemplateGallery = false
    @State private var showingModernGenerating = false

    // BACKEND CONNECTION
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject var coinService: CoinService
    @EnvironmentObject var authManager: AuthManager
    
    private var welcomeMessage: String {
        if case .authenticated = authManager.userState {
            return String(format: "home_welcome".localized, viewModel.userName)
        } else {
            return "home_welcome_guest".localized
        }
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Header
                HomeHeaderView(
                    showingProfile: $showingProfile
                )
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                
                // Removed greeting "home_welcome" to create more space for action cards
                
                HomeQuickActionsView(
                    selectedTab: $selectedTab,
                    showingTemplateGallery: $showingTemplateGallery,
                    showingModernGenerating: $showingModernGenerating
                )
                .padding(.horizontal, 20)

                // Loading - Skeleton
                if viewModel.isLoading {
                    VStack(spacing: 24) {
                        HomeSectionSkeleton()
                        HomeSectionSkeleton()
                    }
                }
                // No Internet - Full Screen
                else if viewModel.error == "NO_INTERNET" {
                    NoInternetView(onRetry: {
                        viewModel.loadContent(forceRefresh: true)
                    })
                    .frame(maxWidth: .infinity)
                    .frame(height: UIScreen.main.bounds.height - 200) // Fill available space
                }
                // Other Errors
                else if let error = viewModel.error {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.yellow)
                        Text(error)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("retry".localized) {
                            Task { await viewModel.refreshContent() }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                    .frame(height: 200)
                }
                // Content
                else {
                    ZStack {
                        // Real content
                        VStack(spacing: 16) {
                            // Popüler Klasikler Section
                            if !viewModel.popularClassics.isEmpty {
                                StorySectionView(
                                    title: "home_popular_classics".localized,
                                    stories: viewModel.popularClassics,
                                    seeAllAction: {
                                        viewModel.seeAllTapped(section: "classics")
                                        // No filter for Popular Classics - show all stories
                                        selectedPrewrittenCategory = ""
                                    },
                                    storyTapAction: { story in
                                        viewModel.storyTapped(story)
                                    }
                                )
                            }

                            // Hikayelerim (Recent User Stories)
                            if !viewModel.recentStories.isEmpty {
                                StorySectionView(
                                    title: "home_my_stories".localized,
                                    stories: viewModel.recentStories,
                                    seeAllAction: {
                                        withAnimation {
                                            selectedTab = .library
                                        }
                                    },
                                    storyTapAction: { story in
                                        viewModel.storyTapped(story)
                                    }
                                )
                                .padding(.top, 4)
                            }

                            // Hızlı Hikayeler (Templates) Section
                            TemplateSectionView(
                                showingTemplateGallery: $showingTemplateGallery
                            )

                            // Hayvan Hikayeleri Section
                            if !viewModel.animalStories.isEmpty {
                                StorySectionView(
                                    title: "home_animal_stories".localized,
                                    stories: viewModel.animalStories,
                                    seeAllAction: {
                                        viewModel.seeAllTapped(section: "animals")
                                        selectedPrewrittenCategory = "animals"
                                    },
                                    storyTapAction: { story in
                                        viewModel.storyTapped(story)
                                    }
                                )
                            }

                            // Upgrade Banner (Free users only)
                            if viewModel.shouldShowUpgradePrompt {
                                UpgradeBannerView(onTap: {
                                    viewModel.upgradeTapped()
                                    showingPaywall = true
                                })
                                .padding(.horizontal, 20)
                            }

                            // Macera Hikayeleri Section
                            if !viewModel.adventureStories.isEmpty {
                                StorySectionView(
                                    title: "home_adventure_stories".localized,
                                    stories: viewModel.adventureStories,
                                    seeAllAction: {
                                        viewModel.seeAllTapped(section: "adventures")
                                        selectedPrewrittenCategory = "adventure"
                                    },
                                    storyTapAction: { story in
                                        viewModel.storyTapped(story)
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 100)
        }
        .fullScreenCover(isPresented: Binding(
            get: { selectedPrewrittenCategory != nil },
            set: { if !$0 { selectedPrewrittenCategory = nil } }
        )) {
            // PERFORMANCE OPTIMIZATION: Pass already-loaded stories from repository
            PrewrittenLibraryView(
                preloadedStories: StoryRepository.shared.stories,
                initialCategory: selectedPrewrittenCategory
            )
        }
        .fullScreenCover(isPresented: $showingTemplateGallery) {
            TemplateGalleryView()
        }
        .fullScreenCover(isPresented: $showingModernGenerating) {
            ModernGeneratingView(
                storyTitle: "Orman Maceraları",
                onEnableNotifications: {
                    showingModernGenerating = false
                    print("Notifications enabled")
                },
                onContinueInBackground: {
                    showingModernGenerating = false
                    print("Continue in background")
                }
            )
        }
        .fullScreenCover(isPresented: $showingPaywall) {
            PaywallView()
        }
        .fullScreenCover(isPresented: $viewModel.showingStoryReader) {
            if let story = viewModel.selectedStory {
                StoryReaderView(story: story)
            }
        }
        .fullScreenCover(isPresented: $viewModel.showingPaywallForStory) {
            PaywallView()
        }
        .task {
            await viewModel.loadContent()

            #if DEBUG
            // Print token for testing
            AuthManager.shared.printAuthTokenForTesting()
            #endif
        }
    }

}

// MARK: - Story Section View (Reusable)

struct StorySectionView: View {
    let title: String
    let stories: [Story]
    let seeAllAction: () -> Void
    let storyTapAction: (Story) -> Void

    var body: some View {
        VStack(spacing: 10) {
            // Section Header
            HStack {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: seeAllAction) {
                    HStack(spacing: 4) {
                        Text("home_see_all".localized)
                            .font(.system(size: 15, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 20)
            
            // Horizontal Scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(stories.prefix(10)) { story in
                        StoryCardView(story: story)
                            .onTapGesture {
                                storyTapAction(story)
                            }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Story Card

struct StoryCardView: View {
    let story: Story
    @State private var isLocked: Bool = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Image
            if let coverUrl = story.coverImageUrl, let url = URL(string: coverUrl) {
                WebImage(
                    url: url,
                    options: [.retryFailed, .scaleDownLargeImages],
                    context: nil,
                    content: { image in
                        image
                            .resizable()
                            .scaledToFill()
                    },
                    placeholder: {
                        // Match Library style: book icon + loading text
                        ZStack {
                            LinearGradient(
                                colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            
                            VStack(spacing: 4) {
                                Image(systemName: "book.fill")
                                    .font(.system(size: 34))
                                    .foregroundColor(.white.opacity(0.5))
                                
                                Text("loading_image".localized)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .frame(width: 140, height: 190)
                        .cornerRadius(12)
                        .shimmering()
                    }
                )
                .frame(width: 140, height: 190)
                .clipped()
            } else {
                // Common placeholder for all stories without cover
                StoryPlaceholderView()
                    .frame(width: 140, height: 190)
            }

            // Gradient overlay
            LinearGradient(
                colors: [Color.black.opacity(0.6), Color.clear],
                startPoint: .bottom,
                endPoint: .center
            )
            .frame(width: 140, height: 190)

            // Lock overlay for inaccessible stories
            if isLocked {
                ZStack {
                    // Dark overlay
                    Color.black.opacity(0.5)

                    // Lock icon
                    VStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(tierBadgeColor))
                    }
                }
                .frame(width: 140, height: 190)
            }

            // Tier Badge
            VStack {
                HStack {
                    Spacer()
                    TierBadgeView(tier: story.metadata?.tier ?? "")
                        .padding(8)
                }
                Spacer()
            }
            .frame(width: 140, height: 190)

            // Title overlay
            VStack(alignment: .leading, spacing: 6) {
                Spacer()

                // Title
                Text(story.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
            }
            .padding(12)
        }
        .frame(width: 140, height: 190)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
        .onAppear {
            checkAccess()
        }
    }

    private func checkAccess() {
        let userTier = SubscriptionService.shared.currentTier
        let storyTier = SubscriptionTier(rawValue: story.metadata?.tier ?? "free") ?? .free
        isLocked = !canAccessStory(userTier: userTier, storyTier: storyTier)
    }

    private func canAccessStory(userTier: SubscriptionTier, storyTier: SubscriptionTier) -> Bool {
        let tierHierarchy: [SubscriptionTier: Int] = [.free: 0, .plus: 1, .pro: 2]
        return (tierHierarchy[userTier] ?? 0) >= (tierHierarchy[storyTier] ?? 0)
    }

    private var tierBadgeColor: Color {
        let tier = SubscriptionTier(rawValue: story.metadata?.tier ?? "free") ?? .free
        switch tier {
        case .free: return Color.green.opacity(0.8)
        case .plus: return Color.orange.opacity(0.8)
        case .pro: return Color.purple.opacity(0.8)
        }
    }
}

// MARK: - Tier Badge

struct TierBadgeView: View {
    let tier: String

    var body: some View {
        Text(tierLabel)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tierBackground)
            .cornerRadius(8)
    }

    private var tierLabel: String {
        switch tier.lowercased() {
        case "free": return "tier_free".localized
        case "plus": return "tier_plus".localized
        case "pro": return "tier_pro".localized
        default: return "tier_free".localized
        }
    }

    private var tierBackground: Color {
        let subscriptionTier = SubscriptionTier(rawValue: tier.lowercased()) ?? .free
        switch subscriptionTier {
        case .free:
            return Color.green.opacity(0.8)
        case .plus:
            return Color.orange.opacity(0.8)
        case .pro:
            return Color.purple.opacity(0.8)
        }
    }
}

// MARK: - Template Section View

struct TemplateSectionView: View {
    @Binding var showingTemplateGallery: Bool
    @ObservedObject private var viewModel = TemplateViewModel.shared
    @State private var selectedTemplate: Template?
    
    var body: some View {
        VStack(spacing: 10) {
            // Section Header
            HStack {
                Text("home_quick_stories_emoji".localized)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: { showingTemplateGallery = true }) {
                    HStack(spacing: 4) {
                        Text("home_see_all".localized)
                            .font(.system(size: 15, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 20)
            
            // Horizontal Scroll
            ZStack {
                // Show skeleton on initial load
                if viewModel.isLoading {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<4, id: \.self) { _ in
                                TemplateCardSkeleton(width: 140, height: 190)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                // Show content
                else if !viewModel.templates.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.templates.prefix(8)) { template in
                                TemplateHomeCard(
                                    template: template,
                                    isLocked: !viewModel.canAccessTemplate(template),
                                    action: {
                                        if viewModel.canAccessTemplate(template) {
                                            selectedTemplate = template
                                        } else {
                                            // Show paywall
                                            DWLogger.shared.logUserAction("Locked Template Tapped", details: template.title)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                // Skeleton overlay during language change
                if viewModel.isRefreshing && !viewModel.templates.isEmpty {
                    ZStack {
                        // Background overlay
                        Color.black.opacity(0.7)

                        // Skeleton
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(0..<4, id: \.self) { _ in
                                    TemplateCardSkeleton(width: 140, height: 190)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
            }
        }
        .task {
            await viewModel.loadTemplates()
        }
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            // Reload templates when language changes
            Task {
                await viewModel.loadTemplates()
            }
        }
        .fullScreenCover(item: $selectedTemplate) { template in
            TemplateDetailView(template: template)
        }
    }
}

// MARK: - Template Home Card

struct TemplateHomeCard: View {
    let template: Template
    let isLocked: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Background Image
                if let imageUrl = template.previewImageUrl, let url = URL(string: imageUrl) {
                    WebImage(url: url) { image in
                        image.resizable()
                    } placeholder: {
                        // Match Library style: book icon + loading text
                        ZStack {
                            LinearGradient(
                                colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            
                            VStack(spacing: 4) {
                                Image(systemName: "book.fill")
                                    .font(.system(size: 34))
                                    .foregroundColor(.white.opacity(0.5))
                                
                                Text("loading_image".localized)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .frame(width: 140, height: 190)
                        .cornerRadius(16)
                        .shimmering()
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 140, height: 190)
                    .clipped()
                } else {
                    // Fallback gradient with emoji
                    ZStack {
                        LinearGradient(
                            colors: [Color.purple.opacity(0.4), Color.blue.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Text(template.emoji)
                            .font(.system(size: 50))
                    }
                }
                
                // Gradient overlay for text readability
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Spacer()
                    
                    // Title
                    Text(template.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .shadow(radius: 2)
                    
                    // Info
                    HStack(spacing: 6) {
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text("\(template.fixedParams.defaultMinutes) " + "minutes_short_text".localized)
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .foregroundColor(.white.opacity(0.9))
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Lock overlay
                if isLocked {
                    ZStack {
                        Color.black.opacity(0.6)
                        
                        VStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .frame(width: 140, height: 190)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Upgrade Banner

struct UpgradeBannerView: View {
    let onTap: () -> Void
    @State private var gradientOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background Image
                Image("PremiumBannerBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(24)
                
                // Gradient overlay (left dark → right transparent)
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.8),
                        Color.black.opacity(0.6),
                        Color.black.opacity(0.3),
                        Color.clear,
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 200)
                .cornerRadius(24)
                
                VStack(alignment: .leading, spacing: 8) {
                    // Title with animated gradient
                    VStack(alignment: .leading, spacing: 1) {
                        Text("premium_banner_title_line1".localized)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)
                        
                        Text("premium_banner_title_line2".localized)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "fbbf24"),
                                        Color(hex: "f59e0b"),
                                        Color(hex: "ec4899")
                                    ],
                                    startPoint: .leading,
                                    endPoint: UnitPoint(x: 1.0 + gradientOffset, y: 0)
                                )
                            )
                            .shadow(color: Color(hex: "fbbf24").opacity(0.6), radius: 10, x: 0, y: 3)
                    }
                    
                    // Benefits with SF Symbols
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "waveform.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "fbbf24"))
                            
                            Text("premium_banner_benefit_audio".localized)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                        }
                        
                        HStack(spacing: 8) {
                            Image(systemName: "photo.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "fbbf24"))
                            
                            Text("premium_banner_benefit_images".localized)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    
                    Spacer(minLength: 0)
                    
                    // CTA Button with breathing glow
                    HStack(spacing: 8) {
                        Text("premium_banner_cta".localized)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color(hex: "f59e0b"))
                        
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color(hex: "f59e0b"))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.white)
                    )
                    .shadow(color: Color(hex: "f59e0b").opacity(pulseScale > 1.04 ? 0.6 : 0.3), radius: pulseScale > 1.04 ? 16 : 8, x: 0, y: 0)
                }
                .padding(.leading, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, maxHeight: 200, alignment: .topLeading)
            }
            .frame(height: 200)
            .cornerRadius(24)
            .shadow(color: Color(hex: "f59e0b").opacity(0.5), radius: 20, x: 0, y: 8)
            .shadow(color: Color(hex: "fbbf24").opacity(0.3), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            // Gradient animation (slow color shift)
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                gradientOffset = 1.0
            }
            
            // Button pulse animation (subtle)
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.08
            }
        }
    }
}

// MARK: - Home Header

struct HomeHeaderView: View {
    @Binding var showingProfile: Bool
    @EnvironmentObject var coinService: CoinService

    var body: some View {
        HStack(alignment: .center) {
            // App Icon + Title
            HStack(spacing: 10) {
                // DreamSpire Icon with subtle glow
                ZStack {
                    // Subtle glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.purple.opacity(0.3),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 5,
                                endRadius: 20
                            )
                        )
                        .frame(width: 40, height: 40)

                    // Icon
                    Image("DreamSpireIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Text("DreamSpire")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: Color.purple.opacity(0.3), radius: 8, x: 0, y: 2)
            }

            Spacer()

            // Coin Balance
            CoinBalanceView()
        }
    }
}

// MARK: - Quick Actions

struct HomeQuickActionsView: View {
    @Binding var selectedTab: DWTab
    @Binding var showingTemplateGallery: Bool
    @Binding var showingModernGenerating: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Hikaye Oluştur - Purple/Pink gradient
            QuickActionCard(
                icon: "sparkles",
                title: "home_create_story".localized,
                subtitle: "home_create_your_story".localized,
                gradientColors: [
                    Color.purple.opacity(0.25),
                    Color.pink.opacity(0.2)
                ],
                action: {
                    withAnimation {
                        selectedTab = .create
                    }
                }
            )

            // Hızlı Hikayeler - Blue/Cyan gradient
            QuickActionCard(
                icon: "bolt.fill",
                title: "home_quick_stories".localized,
                subtitle: "home_from_templates".localized,
                gradientColors: [
                    Color.blue.opacity(0.25),
                    Color.cyan.opacity(0.2)
                ],
                action: { showingTemplateGallery = true }
            )
        }
        .padding(.top, 8)
    }
}

struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let gradientColors: [Color]
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 100)
            .padding(14)
            .background(
                ZStack {
                    // Base gradient with card-specific colors
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // Custom accent gradient
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
            )
            .shadow(color: Color.white.opacity(0.2), radius: 8, x: 0, y: 0)
            .shadow(color: gradientColors[0].opacity(0.3), radius: 12, x: 0, y: 0)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    HomeView(onSignOut: {})
        .environmentObject(CoinService.shared)
        .environmentObject(AuthManager.shared)
}

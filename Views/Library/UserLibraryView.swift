//
//  UserLibraryView.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025-11-02
//

import SwiftUI
import SDWebImageSwiftUI

struct UserLibraryView: View {
    @StateObject private var viewModel: LibraryViewModel
    @ObservedObject private var favoriteStore: FavoriteStore
    @ObservedObject private var jobManager: GenerationJobManager
    @Environment(\.dismiss) var dismiss
    @Namespace private var animation

    @State private var selectedStory: Story?
    @State private var showPrewrittenFilterSheet = false
    @State private var togglingIds: Set<String> = []
    @State private var retryingIds: Set<String> = []
    @State private var showPaywall = false

    var onLoginRequest: () -> Void
    var onCreateStory: (() -> Void)?
    var showCloseButton: Bool

    init(initialTab: LibraryTab = .myStories, onLoginRequest: @escaping () -> Void, onCreateStory: (() -> Void)? = nil, showCloseButton: Bool = false) {
        let vm = LibraryViewModel()
        vm.selectedTab = initialTab
        _viewModel = StateObject(wrappedValue: vm)
        _favoriteStore = ObservedObject(wrappedValue: FavoriteStore.shared)
        _jobManager = ObservedObject(wrappedValue: GenerationJobManager.shared)
        self.onLoginRequest = onLoginRequest
        self.onCreateStory = onCreateStory
        self.showCloseButton = showCloseButton
    }
    
    // MARK: - Computed Properties

    private var hasActivePrewrittenFilters: Bool {
        viewModel.selectedPrewrittenCategory != "filter_all".localized ||
        viewModel.selectedPrewrittenTier != nil ||
        viewModel.isPrewrittenIllustratedOnly
    }

    private var allFavoriteStories: [Story] {
        (viewModel.userStories + viewModel.prewrittenStories)
            .filter { favoriteStore.isFavorite($0.id) }
    }
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient.dwBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView

                // Tabs
                tabsView
                // Content - Smooth transition between tabs
                Group {
                    if viewModel.isLoading {
                        loadingView
                            .transition(.opacity)
                    } else if let error = viewModel.error {
                        errorView(message: error)
                            .transition(.opacity)
                    } else if viewModel.isRefreshing {
                        // Skeleton overlay during language change
                        loadingView
                            .background(
                                LinearGradient.dwBackground
                                    .opacity(0.95)
                            )
                            .transition(.opacity)
                    } else {
                        // Real content - conditional rendering per tab
                        contentView
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .transition(.asymmetric(
                                insertion: .opacity.animation(.spring(response: 0.4, dampingFraction: 0.85)),
                                removal: .opacity.animation(.easeOut(duration: 0.12))
                            ))
                            .id(viewModel.selectedTab)
                    }
                }
                .compositingGroup()
                .animation(.easeInOut(duration: 0.25), value: viewModel.isLoading)
                .animation(.easeInOut(duration: 0.25), value: viewModel.isRefreshing)
            }
        }
        .fullScreenCover(item: $selectedStory) { story in
            StoryReaderView(story: story)
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView()
        }
        .task {
            // Initial load only - runs once on first appear
            if favoriteStore.getFavoriteCount() == 0 {
                await favoriteStore.load()
            }
            await viewModel.loadLibrary()
            DWLogger.shared.info("Library initial load complete", category: .ui)
        }
        .onChange(of: viewModel.selectedTab) { _, newTab in
            // Tab switched - only load prewritten if switching to that tab and it's empty
            if newTab == .prewritten && viewModel.prewrittenStories.isEmpty {
                Task {
                    await viewModel.loadPrewrittenStories()
                }
            }
            DWLogger.shared.info("Tab switched to: \(newTab)", category: .ui)
        }

        .sheet(isPresented: $showPrewrittenFilterSheet) {
            LibraryPrewrittenFilterSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onReceive(NotificationCenter.default.publisher(for: .favoriteToggledFromPrewritten)) { _ in
            // Refresh FavoriteStore when favorite is toggled from PrewrittenLibraryView
            Task {
                await favoriteStore.load()
                DWLogger.shared.info("🔄 FavoriteStore refreshed after toggle from PrewrittenLibraryView", category: .ui)
            }
        }
        .withGlassDialogs()
        .withGlassAlerts()
        .preferredColorScheme(.light)
    }
    
    // MARK: - Favorites Methods

    private func toggleFavorite(_ storyId: String) async {
        guard !togglingIds.contains(storyId) else { return }

        let isFavorite = favoriteStore.isFavorite(storyId)

        await MainActor.run {
            togglingIds.insert(storyId)
        }
        defer {
            Task { @MainActor in
                togglingIds.remove(storyId)
            }
        }

        // If currently in favorites tab and removing from favorites, show smooth slide-out animation
        if viewModel.selectedTab == .favorites && isFavorite {
            // Haptic feedback for removal
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            // Delay slightly to show the heart animation first
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            
            // Animate the removal with slide effect
            await MainActor.run {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    _ = favoriteStore.favoriteIds.subtracting([storyId])
                }
            }
        }

        await favoriteStore.toggle(storyId)
        DWLogger.shared.logUserAction("Toggle Favorite from Library")
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("library_title".localized)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Filter button - only show for prewritten tab
                if viewModel.selectedTab == .prewritten {
                    Button(action: {
                        showPrewrittenFilterSheet = true
                    }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                            
                            if hasActivePrewrittenFilters {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 10, height: 10)
                                    .offset(x: 2, y: -2)
                            }
                        }
                    }
                }
                
                // Close button (only when opened from settings)
                if showCloseButton {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    // MARK: - Tabs
    
    private var tabsView: some View {
        HStack(spacing: 8) {
            ForEach(LibraryTab.allCases, id: \.self) { tab in
                tabItem(tab: tab)
            }
        }
        .padding(6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.1))
                .background(.ultraThinMaterial.opacity(0.5), in: Capsule())
        )
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private func tabItem(tab: LibraryTab) -> some View {
        let isSelected = viewModel.selectedTab == tab
        
        return Button(action: {
            // Haptic feedback
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
            
            withAnimation(.easeInOut(duration: 0.25)) {
                viewModel.selectedTab = tab
            }
            
            // Auto-load prewritten stories if needed
            if tab == .prewritten && viewModel.prewrittenStories.isEmpty {
                Task {
                    await viewModel.loadPrewrittenStories()
                }
            }
        }) {
            Text(tab.shortTitle)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.6, green: 0.4, blue: 1.0),
                                        Color(red: 0.9, green: 0.5, blue: 0.95)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color.purple.opacity(0.4), radius: 8, x: 0, y: 2)
                            .matchedGeometryEffect(id: "active_tab", in: animation)
                    }
                }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var contentView: some View {
        switch viewModel.selectedTab {
        case .myStories:
            if viewModel.isLoading {
                loadingView
            } else if viewModel.userStories.isEmpty && viewModel.generatingStories.isEmpty && jobManager.activeJobs.isEmpty {
                emptyStateView
            } else {
                storiesListView(stories: viewModel.userStories)
            }
            
        case .favorites:
            if viewModel.isLoading || favoriteStore.isLoading {
                loadingView
            } else if favoriteStore.getFavoriteCount() == 0 {
                emptyStateView
            } else {
                storiesListView(stories: allFavoriteStories)
            }
            
        case .prewritten:
            prewrittenTabView
        }
    }
    
    private func storiesListView(stories: [Story]) -> some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Fixed top spacer for consistent alignment
                    Color.clear.frame(height: 20)
                        .id("stories_list_top")

                    LazyVStack(spacing: 16) {
                        // Show generating jobs first (only if there are active jobs)
                        if viewModel.selectedTab == .myStories && !jobManager.activeJobs.filter({ $0.isActive }).isEmpty {
                            generatingJobsSection
                        }

                        // Show failed jobs second (if any exist)
                        if viewModel.selectedTab == .myStories && !jobManager.completedJobs.filter({ $0.status == "failed" }).isEmpty {
                            failedJobsSection
                        }

                        // Then show completed stories with smooth animation
                        ForEach(stories, id: \.id) { story in
                            storyCardFor(story: story)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .top)),
                                    removal: .opacity
                                        .combined(with: .move(edge: .leading))
                                        .combined(with: .scale(scale: 0.8))
                                ))
                        }
                    }
                    .animation(.spring(response: 0.5, dampingFraction: 0.75), value: stories.map { $0.id })
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
                }
            }
            .refreshable {
                // Pull-to-refresh only for myStories and favorites
                await viewModel.refreshLibrary()
                DWLogger.shared.logUserAction("Pull to Refresh - Library", details: viewModel.selectedTab.rawValue)
            }
            .tint(.white)
            .onChange(of: jobManager.activeJobs.count) { oldValue, newValue in
                // Yeni job eklendiğinde en üste scroll et
                if newValue > oldValue {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("stories_list_top", anchor: .top)
                    }
                }
            }
            .onChange(of: viewModel.selectedTab) { _, _ in
                // Tab değiştiğinde en üste scroll et
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("stories_list_top", anchor: .top)
                }
            }
            .onAppear {
                // İlk açılışta en üste scroll et
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    proxy.scrollTo("stories_list_top", anchor: .top)
                }
            }
        }
    }
    
    @ViewBuilder
    private var generatingJobsSection: some View {
        let activeJobs = jobManager.activeJobs.filter { $0.isActive }

        ForEach(activeJobs) { job in
            GeneratingStoryCard(
                title: job.storyTitle
            )
        }
    }

    @ViewBuilder
    private var failedJobsSection: some View {
        let failedJobs = jobManager.completedJobs.filter { $0.status == "failed" }

        ForEach(failedJobs) { job in
            FailedStoryCard(
                job: job,
                isRetrying: retryingIds.contains(job.id),
                onRetry: {
                    Task {
                        retryingIds.insert(job.id)
                        defer { retryingIds.remove(job.id) }
                        await jobManager.retryJob(jobId: job.id)
                    }
                },
                onDismiss: {
                    // Remove from job manager (persists automatically)
                    GenerationJobManager.shared.removeCompletedJob(jobId: job.id)
                }
            )
        }
    }
    
    @ViewBuilder
    private func storyCardFor(story: Story) -> some View {
        if story.type == .user {
            UserStoryCard(
                story: story,
                isFavorite: favoriteStore.isFavorite(story.id),
                isToggling: togglingIds.contains(story.id),
                onTap: {
                    selectedStory = story
                },
                onDelete: {
                    GlassDialogManager.shared.confirm(
                        title: "reader_delete".localized,
                        message: "reader_delete_confirm".localized,
                        confirmTitle: "delete".localized,
                        confirmAction: {
                            Task {
                                await viewModel.deleteStory(story)
                            }
                        },
                        isDestructive: true
                    )
                },
                onToggleFavorite: {
                    Task {
                        await toggleFavorite(story.id)
                    }
                }
            )
        } else {
            // Use UserStoryCard for prewritten stories in favorites tab for consistency
            UserStoryCard(
                story: story,
                isFavorite: favoriteStore.isFavorite(story.id),
                isToggling: togglingIds.contains(story.id),
                onTap: {
                    selectedStory = story
                },
                onDelete: {
                    // No delete for prewritten stories
                },
                onToggleFavorite: {
                    Task {
                        await toggleFavorite(story.id)
                    }
                }
            )
        }
    }
    
    // MARK: - Prewritten Tab
    
    @ViewBuilder
    private var prewrittenTabView: some View {
        if viewModel.isLoading {
            loadingView
        } else {
            VStack(spacing: 0) {
            // Active Filters
            if hasActivePrewrittenFilters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Results count
                        Text(String(format: "stories_count".localized, viewModel.filteredPrewritten.count))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                        
                        if viewModel.selectedPrewrittenCategory != "filter_all".localized {
                            ActiveFilterChip(
                                title: viewModel.selectedPrewrittenCategory,
                                icon: "folder",
                                onRemove: { viewModel.filterPrewrittenByCategory("filter_all".localized) }
                            )
                        }
                        
                        if let tier = viewModel.selectedPrewrittenTier {
                            ActiveFilterChip(
                                title: tier.displayName,
                                icon: "crown",
                                onRemove: { viewModel.filterPrewrittenByTier(nil) }
                            )
                        }

                        if viewModel.isPrewrittenIllustratedOnly {
                            ActiveFilterChip(
                                title: "filter_illustrated_only".localized,
                                icon: "photo.artframe",
                                onRemove: { viewModel.isPrewrittenIllustratedOnly = false }
                            )
                        }
                        
                        Button(action: {
                            viewModel.filterPrewrittenByCategory("filter_all".localized)
                            viewModel.filterPrewrittenByTier(nil)
                            viewModel.isPrewrittenIllustratedOnly = false
                        }) {
                            Text("filter".localized)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 12)
                .padding(.bottom, 8)
            } else {
                // Just show results count
                HStack {
                    Text(String(format: "stories_count".localized, viewModel.filteredPrewritten.count))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            
            // Stories Grid
            ScrollView(showsIndicators: false) {
                if viewModel.filteredPrewritten.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.5))

                        Text("empty_no_results".localized)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)

                        Text("empty_try_different".localized)
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.7))

                        Button(action: {
                            viewModel.filterPrewrittenByCategory("filter_all".localized)
                            viewModel.filterPrewrittenByTier(nil)
                        }) {
                            Text("filter".localized)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(10)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                    .padding(.bottom, 100)
                } else {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ],
                        spacing: 16
                    ) {
                        ForEach(Array(viewModel.filteredPrewritten.enumerated()), id: \.element.id) { index, story in
                            PrewrittenStoryCard(
                                story: story,
                                isLocked: !viewModel.canAccessPrewrittenStory(story),
                                isFavorite: favoriteStore.isFavorite(story.id),
                                isToggling: togglingIds.contains(story.id),
                                action: {
                                    if viewModel.canAccessPrewrittenStory(story) {
                                        selectedStory = story
                                    } else {
                                        // Show paywall
                                        DWLogger.shared.logUserAction("Paywall Triggered", details: "Prewritten Story")
                                        showPaywall = true
                                    }
                                },
                                onToggleFavorite: {
                                    Task {
                                        await toggleFavorite(story.id)
                                    }
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.9)),
                                removal: .opacity
                            ))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }
            }
        }
        }
    }
    
    // MARK: - Loading & Empty States

    private var loadingView: some View {
        ScrollView {
            if viewModel.selectedTab == .prewritten {
                // Grid skeleton for prewritten tab
                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ],
                    spacing: 16
                ) {
                    ForEach(0..<6, id: \.self) { _ in
                        PrewrittenStoryCardSkeleton()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 100)
            } else {
                // List skeleton for my stories and favorites
                VStack(spacing: 12) {
                    ForEach(0..<5, id: \.self) { _ in
                        StoryCardSkeleton()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 140, height: 140)
                
                Image(systemName: viewModel.selectedTab == .myStories ? "book.closed.fill" : "heart.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.white.opacity(0.8))
                    .symbolEffect(.bounce.up.byLayer, options: .repeat(3), value: viewModel.selectedTab)
            }
            .padding(.bottom, 8)
            
            VStack(spacing: 12) {
                Text(viewModel.selectedTab == .myStories ? "library_empty".localized : "library_empty_favorites".localized)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(viewModel.selectedTab == .myStories ? "library_empty_subtitle".localized : "library_empty_subtitle".localized)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 20)
            
            if viewModel.selectedTab == .myStories {
                Button(action: {
                    if showCloseButton {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onCreateStory?()
                        }
                    } else {
                        onCreateStory?()
                    }
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("library_start_creating".localized)
                    }
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "6B46C1"))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
                    )
                }
                .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
    
    private func guestPromptView(title: String, message: String) -> some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 140, height: 140)
                
                Image(systemName: "person.crop.circle.badge.questionmark.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.white.opacity(0.8))
                    .symbolEffect(.pulse, options: .repeating)
            }
            .padding(.bottom, 8)
            
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(message)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 20)
            
            Button(action: onLoginRequest) {
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("auth_sign_in".localized)
                }
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(hex: "6B46C1"))
                .padding(.horizontal, 40)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
                )
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
    
    // MARK: - Loading & Error
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.white.opacity(0.6))
            
            Text(message)
                .font(.system(size: 17))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Button("try_again".localized) {
                Task {
                    await viewModel.loadLibrary()
                }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.2))
            .cornerRadius(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? Color(red: 0.545, green: 0.361, blue: 0.965) : .white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.white : Color.white.opacity(0.2))
                )
        }
    }
}

// MARK: - User Story Card

struct UserStoryCard: View {
    let story: Story
    let isFavorite: Bool
    let isToggling: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    let onToggleFavorite: () -> Void

    @State private var isGeneratingPDF = false
    @State private var itemsToShare: [Any] = []
    @State private var showPDFShare = false
    @State private var showPaywallForPDF = false
    @State private var shareProgress: String = ""  // For showing progress to user
    // REMOVED: @State private var actualMinutes: Int? - now using story.roundedMinutes directly

    @ObservedObject private var subscriptionService = SubscriptionService.shared

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Cover Image with Badges - Larger and more prominent
                ZStack(alignment: .topTrailing) {
                    if let imageUrl = story.coverImageUrl, !imageUrl.isEmpty {
                        WebImage(url: URL(string: imageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 125, height: 150)  // Match prewritten card size
                                .cornerRadius(12)
                                .clipped()
                        } placeholder: {
                            placeholderImage
                        }
                        .onSuccess { image, data, cacheType in
                            // No log for perf
                        }
                        .onFailure { error in
                            // No log for perf
                        }
                    } else {
                        placeholderImage
                    }

                    // Feature Badges (top right) - Simpler
                    VStack(spacing: 4) {
                        if story.audioUrl != nil {
                            Text("🎧")
                                .font(.system(size: 12))
                                .padding(4)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                )
                        }

                        if story.isIllustrated {
                            Text("🎨")
                                .font(.system(size: 12))
                                .padding(4)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                )
                        }
                    }
                    .padding(6)
                }
                .frame(width: 125, height: 150)  // Explicit frame prevents layout shift
                .clipped()

                // Story Info - Enhanced typography and spacing
                VStack(alignment: .leading, spacing: 8) {
                    // Title - Up to 3 lines support
                    Text(story.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(3)
                        .minimumScaleFactor(0.95)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Genre Badge - Enhanced styling
                    HStack(spacing: 6) {
                        Image(systemName: genreIcon(for: story.category))
                            .font(.system(size: 11, weight: .semibold))
                        Text(localizedCategory(story.category))
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.6, green: 0.4, blue: 1.0).opacity(0.8),
                                        Color(red: 0.9, green: 0.5, blue: 0.95).opacity(0.8)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: Color.purple.opacity(0.3), radius: 4, x: 0, y: 2)
                    )
                    
                    Spacer()
                    
                    // Metadata Row
                    HStack {
                         // Duration - Uses roundedMinutes (prioritizes metadata.actualDuration, fallback to estimatedMinutes)
                        Label("\(story.roundedMinutes) " + "min_suffix".localized, systemImage: "clock")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))

                        Spacer()

                        // Share Button (PDF for Plus, PDF+Audio for Pro)
                        Button(action: handleShare) {
                            ZStack {
                                if isGeneratingPDF {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .tint(.white)
                                } else {
                                    if subscriptionService.currentTier == .free {
                                        // Locked state - show share icon dimmed with lock on top
                                        ZStack {
                                            // Background share icon (dimmed)
                                            Image(systemName: "square.and.arrow.up")
                                                .font(.system(size: 16))
                                                .foregroundColor(.white.opacity(0.15))

                                            // Lock badge on top with larger background
                                            ZStack {
                                                Circle()
                                                    .fill(Color.white.opacity(0.15))
                                                    .frame(width: 28, height: 28)

                                                Image(systemName: "lock.fill")
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundColor(Color(hex: "FFD700"))
                                            }
                                        }
                                    } else {
                                        // Unlocked state - clean share icon
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 16))
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                }
                            }
                            .frame(width: 32, height: 32)
                        }
                        .disabled(isGeneratingPDF)

                        // Favorite Button
                        Button(action: onToggleFavorite) {
                            ZStack {
                                if isToggling {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .tint(.white)
                                } else {
                                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                                        .font(.system(size: 18))
                                        .foregroundColor(isFavorite ? Color(hex: "FF6B6B") : .white.opacity(0.6))
                                        .symbolEffect(.bounce, value: isFavorite)
                                }
                            }
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                        }
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isFavorite)

                        // Delete Button (only for user stories)
                         if story.type == .user {
                            Button(action: onDelete) {
                                Image(systemName: "trash")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.6))
                                    .frame(width: 32, height: 32)
                            }
                        }
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.14)) // Increased from 0.08
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5) // Added stroke for better definition
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showPDFShare) {
            ShareSheet(items: itemsToShare) {
                showPDFShare = false
            }
        }
        .fullScreenCover(isPresented: $showPaywallForPDF) {
            PaywallView()
        }
        // REMOVED: Async audio duration loading
        // Now using story.roundedMinutes which reads from metadata.actualDuration
        // This was causing:
        // 1. Performance issues (network call per card to download audio header)
        // 2. Duration mismatch (ceil vs round calculation)
    }

    private func handleShare() {
        let currentTier = subscriptionService.currentTier

        // Check tier - Plus and above can share
        if currentTier == .free {
            DWLogger.shared.logUserAction("Share Blocked from Library", details: "Free tier user attempted share")
            showPaywallForPDF = true
            return
        }

        // Start generation process
        isGeneratingPDF = true
        shareProgress = ""

        let shareType = currentTier == .pro && story.audioUrl != nil ? "PDF + Audio" : "PDF Only"
        DWLogger.shared.info("📦 Starting share generation from library (\(shareType)) for story: \(story.title)", category: .general)

        Task {
            do {
                var itemsToShare: [Any] = []

                // 1️⃣ Generate PDF (Plus and Pro)
                await MainActor.run {
                    shareProgress = "Generating PDF..."
                }

                // IMPORTANT: If story is summary or pages are empty, fetch full story first
                var storyForPDF = story
                if story.isSummary || story.pages.isEmpty {
                    DWLogger.shared.info("📥 Story is summary, fetching full content for PDF...", category: .general)
                    let isPrewritten = (story.type == .prewritten)
                    storyForPDF = try await StoryPrefetchManager.shared.getFullStory(id: story.id, isPrewritten: isPrewritten)
                    DWLogger.shared.info("✅ Full story fetched: \(storyForPDF.pages.count) pages", category: .general)
                }

                let pdfData = try await PDFGenerator.shared.generatePDF(
                    for: storyForPDF,
                    includeCover: true,
                    includeIllustrations: storyForPDF.isIllustrated
                )
                itemsToShare.append(PDFActivityItem(pdfData: pdfData, fileName: "\(story.title).pdf"))
                DWLogger.shared.info("✅ PDF generated successfully (\(pdfData.count) bytes)", category: .general)

                // 2️⃣ Download and add audio (ONLY PRO users)
                if currentTier == .pro, let audioUrl = story.audioUrl {
                    await MainActor.run {
                        shareProgress = "Adding audio file..."
                    }

                    DWLogger.shared.info("🎵 PRO user - Downloading audio for share", category: .general)
                    do {
                        let audioData = try await downloadAudio(from: audioUrl)
                        itemsToShare.append(AudioActivityItem(audioData: audioData, fileName: "\(story.title).mp3"))
                        DWLogger.shared.info("✅ Audio added successfully (\(audioData.count) bytes)", category: .general)
                    } catch {
                        DWLogger.shared.warning("⚠️ Audio download failed, sharing PDF only: \(error.localizedDescription)", category: .general)
                        // Continue with PDF only - don't fail the entire share
                    }
                }

                // 3️⃣ Open share sheet
                await MainActor.run {
                    self.itemsToShare = itemsToShare
                    self.isGeneratingPDF = false
                    self.shareProgress = ""
                    self.showPDFShare = true

                    DWLogger.shared.info("✅ Share sheet opened with \(itemsToShare.count) item(s)", category: .general)
                    DWLogger.shared.logUserAction("Share from Library", details: "\(shareType) - \(story.title)")
                }
            } catch {
                await MainActor.run {
                    self.isGeneratingPDF = false
                    self.shareProgress = ""
                    DWLogger.shared.error("❌ Failed to generate share items from library", error: error, category: .general)

                    // Show user-friendly error
                    GlassAlertManager.shared.showAlert(
                        type: .error,
                        title: "share_error_title".localized,
                        message: "share_error_message".localized
                    )
                }
            }
        }
    }

    /// Downloads audio file from URL for sharing
    private func downloadAudio(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return data
    }

    // Localized category names
    private func localizedCategory(_ category: String) -> String {
        let lowercased = category.lowercased()

        if lowercased.contains("classic") || lowercased.contains("klasik") {
            return "category_classic".localized
        } else if lowercased.contains("macera") || lowercased.contains("adventure") {
            return "genre_adventure".localized
        } else if lowercased.contains("bilim") || lowercased.contains("science") {
            return "genre_science".localized
        } else if lowercased.contains("fantezi") || lowercased.contains("fantasy") {
            return "genre_fantasy".localized
        } else if lowercased.contains("hayvan") || lowercased.contains("animal") {
            return "genre_animals".localized
        } else if lowercased.contains("uzay") || lowercased.contains("space") {
            return "genre_space".localized
        } else if lowercased.contains("arkadaş") || lowercased.contains("friend") {
            return "genre_friendship".localized
        } else if lowercased.contains("aile") || lowercased.contains("family") {
            return "genre_family".localized
        } else if lowercased.contains("doğa") || lowercased.contains("nature") {
            return "genre_nature".localized
        } else if lowercased.contains("deniz") || lowercased.contains("ocean") || lowercased.contains("sea") {
            return "genre_ocean".localized
        } else if lowercased.contains("orman") || lowercased.contains("forest") {
            return "genre_forest".localized
        } else {
            // Fallback: capitalize first letter
            return category.prefix(1).uppercased() + category.dropFirst()
        }
    }

    // Genre icon mapper - adds visual variety
    private func genreIcon(for category: String) -> String {
        let lowercased = category.lowercased()

        if lowercased.contains("classic") || lowercased.contains("klasik") {
            return "book.closed.fill"
        } else if lowercased.contains("macera") || lowercased.contains("adventure") {
            return "map.fill"
        } else if lowercased.contains("bilim") || lowercased.contains("science") {
            return "flask.fill"
        } else if lowercased.contains("fantezi") || lowercased.contains("fantasy") {
            return "wand.and.stars"
        } else if lowercased.contains("hayvan") || lowercased.contains("animal") {
            return "pawprint.fill"
        } else if lowercased.contains("uzay") || lowercased.contains("space") {
            return "sparkles"
        } else if lowercased.contains("arkadaş") || lowercased.contains("friend") {
            return "heart.circle.fill"
        } else if lowercased.contains("aile") || lowercased.contains("family") {
            return "house.fill"
        } else if lowercased.contains("doğa") || lowercased.contains("nature") {
            return "leaf.fill"
        } else if lowercased.contains("deniz") || lowercased.contains("ocean") || lowercased.contains("sea") {
            return "drop.fill"
        } else if lowercased.contains("orman") || lowercased.contains("forest") {
            return "tree.fill"
        } else {
            return "book.fill"
        }
    }
    
    private var placeholderImage: some View {
        let hasImageUrl = story.coverImageUrl != nil

        return Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 125, height: 150)
            .cornerRadius(14)
            .overlay(
                VStack(spacing: 4) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 34))
                        .foregroundColor(.white.opacity(0.5))

                    // Show loading text only when we have a coverImageUrl (loading state)
                    if hasImageUrl {
                        Text("loading_image".localized)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            )
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
            .shimmering(active: hasImageUrl) // Shimmer ONLY when image URL exists (loading state)
    }
}

// MARK: - Library Prewritten Filter Sheet

struct LibraryPrewrittenFilterSheet: View {
    @ObservedObject var viewModel: LibraryViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Category Section
                        categorySection

                        // Illustrated Section (New)
                        illustratedSection
                        
                        // Tier Section
                        tierSection
                        
                        Spacer()
                            .frame(height: 20)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("filter_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("filter_clear".localized) {
                        viewModel.filterPrewrittenByCategory("filter_all".localized)
                        viewModel.filterPrewrittenByTier(nil)
                        viewModel.isPrewrittenIllustratedOnly = false
                    }
                    .foregroundColor(.orange)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("filter_apply".localized) {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Category Section
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "folder")
                    .font(.system(size: 18))
                    .foregroundColor(.purple)
                
                Text("filter_category".localized)
                    .font(.system(size: 18, weight: .semibold))
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(viewModel.prewrittenCategories, id: \.self) { category in
                    FilterOptionButton(
                        title: category,
                        icon: getCategoryIcon(category),
                        isSelected: viewModel.selectedPrewrittenCategory == category,
                        action: { viewModel.filterPrewrittenByCategory(category) }
                    )
                }
            }
        }
    }
    
    // MARK: - Illustrated Section
    
    private var illustratedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $viewModel.isPrewrittenIllustratedOnly) {
                HStack(spacing: 12) {
                    Image(systemName: "photo.artframe")
                        .font(.system(size: 18))
                        .foregroundColor(.pink)
                        .frame(width: 36, height: 36)
                        .background(Color.pink.opacity(0.15))
                        .cornerRadius(10)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("filter_illustrated_only".localized)
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text("filter_illustrated_desc".localized)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .pink))
            .padding(14)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(14)
        }
    }
    
    // MARK: - Tier Section
    
    private var tierSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "crown")
                    .font(.system(size: 18))
                    .foregroundColor(.orange)
                
                Text("filter_access_level".localized)
                    .font(.system(size: 18, weight: .semibold))
            }
            
            VStack(spacing: 12) {
                TierFilterOption(
                    title: "library_filter_all".localized,
                    subtitle: "library_filter_all_stories".localized,
                    icon: "square.grid.2x2",
                    color: .gray,
                    isSelected: viewModel.selectedPrewrittenTier == nil,
                    action: { viewModel.filterPrewrittenByTier(nil) }
                )
                
                TierFilterOption(
                    title: "library_filter_free".localized,
                    subtitle: "library_filter_free_desc".localized,
                    icon: "gift",
                    color: .green,
                    isSelected: viewModel.selectedPrewrittenTier == .free,
                    action: { viewModel.filterPrewrittenByTier(.free) }
                )
                
                TierFilterOption(
                    title: "library_filter_plus".localized,
                    subtitle: "library_filter_plus_desc".localized,
                    icon: "star",
                    color: .orange,
                    isSelected: viewModel.selectedPrewrittenTier == .plus,
                    action: { viewModel.filterPrewrittenByTier(.plus) }
                )
                
                TierFilterOption(
                    title: "library_filter_pro".localized,
                    subtitle: "library_filter_pro_desc".localized,
                    icon: "crown.fill",
                    color: .purple,
                    isSelected: viewModel.selectedPrewrittenTier == .pro,
                    action: { viewModel.filterPrewrittenByTier(.pro) }
                )
            }
        }
    }
    
    private func getCategoryIcon(_ category: String) -> String {
        // Use localized keys for comparison
        if category == "filter_all".localized { return "square.grid.2x2" }
        if category == "category_bedtime".localized { return "moon.stars" }
        if category == "category_adventure".localized { return "map" }
        if category == "category_family".localized { return "house.fill" }
        if category == "category_friendship".localized { return "heart.fill" }
        if category == "category_fantasy".localized { return "sparkles" }
        if category == "category_animals".localized { return "hare" }
        if category == "category_princess".localized { return "crown" }
        if category == "category_classic".localized { return "book.closed" }
        return "book"
    }
}

// MARK: - Preview

#Preview {
    UserLibraryView(onLoginRequest: {})
}

//
//  HomeViewModel.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//  Refactored with Repository Pattern for optimal performance
//

import Foundation
import Combine

@MainActor
class HomeViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var popularClassics: [Story] = []
    @Published var animalStories: [Story] = []
    @Published var adventureStories: [Story] = []
    @Published var originalStories: [Story] = []
    @Published var recentStories: [Story] = []
    @Published var isLoading = true
    @Published var isRefreshing = false  // For language change overlay
    @Published var error: String?

    // User info
    @Published var userName: String = "Elif"
    @Published var userProfileImage: String?

    // Subscription
    @Published var currentTier: SubscriptionTier = .free
    @Published var shouldShowUpgradePrompt = false

    // Navigation
    @Published var selectedStory: Story?
    @Published var showingStoryReader = false
    @Published var showingPaywallForStory = false

    // MARK: - Dependencies (Protocol-Based for Testing)

    private let storyRepository: StoryRepository
    private let userStoryRepository: UserStoryRepository
    private let subscriptionService: SubscriptionService
    private let authManager: AuthManager

    private var cancellables = Set<AnyCancellable>()
    private var loadContentTask: Task<Void, Error>?

    // MARK: - State Tracking

    private var hasLoadedContent = false

    // MARK: - Initialization
    
    /// Default initializer using shared instances
    convenience init() {
        self.init(
            storyRepository: StoryRepository.shared,
            userStoryRepository: UserStoryRepository.shared,
            subscriptionService: SubscriptionService.shared,
            authManager: AuthManager.shared
        )
    }
    
    /// Dependency injection initializer for testing
    init(
        storyRepository: StoryRepository,
        userStoryRepository: UserStoryRepository,
        subscriptionService: SubscriptionService,
        authManager: AuthManager
    ) {
        self.storyRepository = storyRepository
        self.userStoryRepository = userStoryRepository
        self.subscriptionService = subscriptionService
        self.authManager = authManager
        DWLogger.shared.info("HomeViewModel initialized", category: .ui)
        setupSubscriptions()
        loadUserInfo()
    }
    
    // MARK: - Setup
    
    private func setupSubscriptions() {
        // Listen to subscription changes
        subscriptionService.$currentTier
            .assign(to: &$currentTier)
        
        // Show upgrade prompt for free users
        subscriptionService.$currentTier
            .map { $0 == .free }
            .assign(to: &$shouldShowUpgradePrompt)
        
        // Listen for language changes to refresh content
        NotificationCenter.default.publisher(for: .languageChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                DWLogger.shared.info("🌍 Language changed, showing skeleton overlay while refreshing", category: .ui)

                // Show skeleton overlay (keeps cards visible underneath)
                self.isRefreshing = true

                // Mark as needs reload
                self.hasLoadedContent = false

                // Refresh user name with new locale
                self.userName = self.authManager.currentUserName ?? "user_name_default".localized

                // Force reload from API
                Task {
                    await self.loadContentForLanguageChange()
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadUserInfo() {
        userName = authManager.currentUserName ?? "user_name_default".localized
        DWLogger.shared.debug("User info loaded: \(userName)", category: .ui)
    }
    
    // MARK: - Load Content (Optimized with Repository)

    /// Load content specifically for language change (shows skeleton overlay)
    private func loadContentForLanguageChange() async {
        // Call loadContent and wait for the task to complete
        loadContent(forceRefresh: true)

        // Wait for the task to complete
        do {
            try await loadContentTask?.value
        } catch {
            // Task was cancelled or failed, that's okay
            DWLogger.shared.debug("Load content task finished with error (likely cancelled): \(error)", category: .ui)
        }

        // Hide skeleton overlay after content is loaded
        await MainActor.run {
            self.isRefreshing = false
        }
    }

    func loadContent(forceRefresh: Bool = false) {
        // Skip if already loaded (unless forcing refresh)
        if !forceRefresh && hasLoadedContent {
            DWLogger.shared.debug("✅ Home content already loaded, using cache", category: .ui)
            return
        }

        // Cancel any existing task
        loadContentTask?.cancel()
        
        // ⚡ IMMEDIATE UPDATE: Set loading state synchronously
        // This ensures the UI switches to skeleton immediately, 
        // preventing "flash of old content" during language changes
        self.isLoading = true
        self.error = nil

        loadContentTask = Task {
            // No need to set isLoading/error here anymore as it's done above


            do {
                // Load all content in parallel using repositories (with caching!)
                async let prewrittenTask: () = self.fetchAndFilterPrewrittenStories()
                async let recentsTask = self.loadRecentStories()
                async let subscriptionTask: () = self.loadSubscriptionInfo()

                // Wait for all tasks
                let (_, recents, _) = try await (prewrittenTask, recentsTask, subscriptionTask)

                // Set recent stories
                await MainActor.run {
                    self.recentStories = recents
                    DWLogger.shared.debug("✅ [HomeViewModel] Recent stories loaded: \(recents.count)", category: .ui)
                }

                // Log success
                DWLogger.shared.info("Home content loaded successfully (using cache when available)", category: .ui)

                // Mark as loaded
                await MainActor.run {
                    self.hasLoadedContent = true
                }

            } catch {
                if !(error is CancellationError) {
                    await MainActor.run {
                        self.error = "İçerik yüklenirken bir hata oluştu."
                    }
                    DWLogger.shared.error("Failed to load home content", error: error, category: .ui)
                }
            }

            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    // MARK: - Load Sections (Using Repository - Auto Cached!)

    private func fetchAndFilterPrewrittenStories() async throws {
        // Use PrewrittenService directly for tag-based fetching
        // Backend returns tier-sorted stories (FREE → PLUS → PRO)
        let prewrittenService = PrewrittenService.shared
        let language = LocalizationManager.shared.currentLanguage.rawValue

        // Request more stories to ensure tier mix (backend returns tier-sorted)
        // PERFORMANCE: Use summary=true for lightweight metadata
        async let classicsTask = prewrittenService.getStoriesByTag("classic", language: language, limit: 20, summary: true)
        async let animalsTask = prewrittenService.getStoriesByTag("animals", language: language, limit: 20, summary: true)
        async let adventuresTask = prewrittenService.getStoriesByTag("adventure", language: language, limit: 20, summary: true)

        let (classics, animals, adventures) = try await (classicsTask, animalsTask, adventuresTask)

        // DEBUG: Log what backend returned BEFORE shuffle
        DWLogger.shared.debug("📊 [DEBUG] Backend returned classics tiers: \(classics.prefix(5).map { $0.metadata?.tier ?? "unknown" })", category: .ui)
        DWLogger.shared.debug("📊 [DEBUG] Backend returned animals tiers: \(animals.prefix(5).map { $0.metadata?.tier ?? "unknown" })", category: .ui)

        // Apply smart shuffling: keep first 3 FREE, shuffle the rest
        await MainActor.run {
            self.popularClassics = smartShuffle(classics)
            self.animalStories = smartShuffle(animals)
            self.adventureStories = smartShuffle(adventures)

            // DEBUG: Log what we have AFTER shuffle
            DWLogger.shared.debug("📊 [DEBUG] After shuffle classics tiers: \(self.popularClassics.prefix(5).map { $0.metadata?.tier ?? "unknown" })", category: .ui)
            DWLogger.shared.debug("✅ [HomeViewModel] Tier-sorted stories loaded with smart shuffle: classics=\(self.popularClassics.count), animals=\(self.animalStories.count), adventures=\(self.adventureStories.count)", category: .ui)
        }
        
        // PERFORMANCE: Use StoryPrefetchManager for centralized prefetching
        // This makes tapping on a story nearly instant
        Task.detached(priority: .background) {
            await self.prefetchTopStories()
        }
    }
    
    /// Prefetch full story content for the first few visible stories in each section
    /// This runs in the background after summaries are displayed, so the user doesn't wait
    private func prefetchTopStories() async {
        let prefetchManager = StoryPrefetchManager.shared
        
        // Get first 2 stories from each visible section (these are most likely to be tapped)
        let topClassics = await MainActor.run { Array(self.popularClassics.prefix(2)) }
        let topAnimals = await MainActor.run { Array(self.animalStories.prefix(2)) }
        let topAdventures = await MainActor.run { Array(self.adventureStories.prefix(2)) }
        
        // Combine all story IDs
        let allStoryIds = (topClassics + topAnimals + topAdventures).map { $0.id }
        
        DWLogger.shared.info("🚀 [HomeViewModel] Queuing \(allStoryIds.count) stories for prefetch", category: .ui)
        
        // Request prefetch through the centralized manager (handles deduplication and concurrency)
        await MainActor.run {
            prefetchManager.requestPrefetch(storyIds: allStoryIds, isPrewritten: true)
        }
    }

    /// Smart shuffle: Keep first 2-3 FREE stories at top, shuffle the rest for variety
    private func smartShuffle(_ stories: [Story]) -> [Story] {
        guard stories.count > 3 else { return stories }

        // Separate FREE and premium stories
        let freeStories = stories.filter { ($0.metadata?.tier ?? "free") == "free" }
        let premiumStories = stories.filter { ($0.metadata?.tier ?? "free") != "free" }

        // Keep first 2-3 FREE at top
        let topFree = Array(freeStories.prefix(3))
        let remainingFree = Array(freeStories.dropFirst(3))

        // Shuffle remaining stories for variety
        let remaining = (remainingFree + premiumStories).shuffled()

        // Combine: [FREE, FREE, FREE, shuffled mix...]
        return topFree + remaining
    }

    private func loadRecentStories() async throws -> [Story] {
        guard authManager.currentUserId != nil else {
            DWLogger.shared.debug("⏭️ [HomeViewModel] No userId, skipping recent stories", category: .ui)
            return []
        }

        do {
            // Repository automatically handles caching!
            let recents = try await userStoryRepository.getRecentStories(forceRefresh: false)
            DWLogger.shared.debug("✅ [HomeViewModel] Recent stories loaded: \(recents.count)", category: .ui)
            return recents

        } catch {
            DWLogger.shared.error("Failed to load recent stories (non-critical)", error: error, category: .api)
            // Don't throw - it's okay if user has no stories
            return []
        }
    }
    
    // MARK: - Load Subscription Info
    
    private func loadSubscriptionInfo() async throws {
        // This will be handled by subscription service
        // Just a placeholder for batched requests
    }
    
    // MARK: - Actions
    
    func refreshContent() {
        DWLogger.shared.info("Refreshing home content (force refresh)", category: .ui)

        // Force refresh from repositories
        Task {
            do {
                async let storyRefresh: [Story] = storyRepository.refresh()
                async let userRefresh: [Story] = userStoryRepository.refresh()
                _ = try await (storyRefresh, userRefresh)

                // Reload content
                loadContent()
            } catch {
                DWLogger.shared.error("Failed to refresh content", error: error, category: .ui)
            }
        }
    }
    
    // MARK: - User Actions
    
    func storyTapped(_ story: Story) {
        DWLogger.shared.logUserAction("Story Tapped", details: story.title)
        DWLogger.shared.logAnalyticsEvent("story_opened", parameters: [
            "story_id": story.id,
            "story_type": story.type.rawValue,
            "category": story.category
        ])

        // Check tier access
        if canAccessStory(story) {
            selectedStory = story
            showingStoryReader = true
        } else {
            // User doesn't have access - trigger paywall
            DWLogger.shared.logUserAction("Paywall Triggered", details: "Story Access - \(story.title)")
            DWLogger.shared.logAnalyticsEvent("paywall_triggered", parameters: [
                "source": "home_story_tap",
                "story_id": story.id,
                "required_tier": story.metadata?.tier ?? "unknown",
                "current_tier": currentTier.rawValue
            ])
            selectedStory = story
            showingPaywallForStory = true
        }
    }

    private func canAccessStory(_ story: Story) -> Bool {
        let storyTier = SubscriptionTier(rawValue: story.metadata?.tier ?? "free") ?? .free
        let tierHierarchy: [SubscriptionTier: Int] = [.free: 0, .plus: 1, .pro: 2]
        return (tierHierarchy[currentTier] ?? 0) >= (tierHierarchy[storyTier] ?? 0)
    }
    
    func createStoryTapped() {
        DWLogger.shared.logUserAction("Create Story Tapped")
        
        // Check if user can create story
        let (allowed, reason) = subscriptionService.canCreateStory()
        if !allowed {
            error = reason
            DWLogger.shared.warning("Story creation blocked: \(reason ?? "Unknown")", category: .subscription)
        }
    }
    
    func quickStoriesTapped() {
        DWLogger.shared.logUserAction("Quick Stories Tapped")
        DWLogger.shared.logAnalyticsEvent("quick_stories_opened")
    }
    
    func upgradeTapped() {
        DWLogger.shared.logUserAction("Upgrade Banner Tapped")
        DWLogger.shared.logAnalyticsEvent("upgrade_prompt_tapped", parameters: [
            "source": "home_banner",
            "current_tier": currentTier.rawValue
        ])
    }
    
    func seeAllTapped(section: String) {
        DWLogger.shared.logUserAction("See All Tapped", details: section)
        DWLogger.shared.logAnalyticsEvent("see_all_tapped", parameters: ["section": section])
    }
}

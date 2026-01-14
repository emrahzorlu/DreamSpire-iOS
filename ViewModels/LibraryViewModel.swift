//
//  LibraryViewModel.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025-11-02
//

import Foundation
import Combine
import SwiftUI

@MainActor
class LibraryViewModel: ObservableObject {
    // MARK: - Singleton
    
    static let shared = LibraryViewModel()
    
    // MARK: - Published Properties

    @Published var userStories: [Story] = []
    @Published var generatingStories: [GeneratingStoryInfo] = []
    @Published var prewrittenStories: [Story] = []
    @Published var filteredPrewritten: [Story] = []
    @Published var selectedTab: LibraryTab = .myStories
    @Published var selectedPrewrittenCategory: String = "filter_all".localized
    @Published var selectedPrewrittenTier: SubscriptionTier? = nil
    @Published var isLoading = false // DÜZELTME: false ile başlasın
    @Published var isRefreshing = false  // For language change overlay
    @Published var error: String?
    @Published var deletingStoryIds: Set<String> = [] // Track stories being deleted

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Dependencies (Repository Pattern)

    private let storyRepository = StoryRepository.shared
    private let userStoryRepository = UserStoryRepository.shared
    private let subscriptionService = SubscriptionService.shared
    let authManager = AuthManager.shared
    
    // Simple tracking - no polling needed
    // Stories will auto-refresh when completed

    // Category filters using localization keys
    var prewrittenCategories: [String] {
        return [
            "filter_all".localized,
            "category_bedtime".localized,
            "category_adventure".localized,
            "category_family".localized,
            "category_friendship".localized,
            "category_fantasy".localized,
            "category_animals".localized,
            "category_princess".localized,
            "category_classic".localized
        ]
    }

    // Tag mapping for filtering
    var categoryToTagMapping: [String: String] {
        return [
            "category_animals".localized: "animals",
            "category_princess".localized: "princess",
            "category_classic".localized: "classic",
            "category_adventure".localized: "adventure",
            "category_friendship".localized: "friendship",
            "category_fantasy".localized: "fantasy",
            "category_bedtime".localized: "bedtime",
            "category_family".localized: "family"
        ]
    }
    
    // MARK: - Generation Tracking (Simplified)
    
    func addGeneratingStory(storyId: String, title: String) {
        // Simple add - no polling
        if !generatingStories.contains(where: { $0.storyId == storyId }) {
            let info = GeneratingStoryInfo(
                id: storyId,
                storyId: storyId,
                status: StoryGenerationStatus(
                    storyId: storyId,
                    step: .initializing,
                    progress: 0,
                    message: "story_generating".localized,
                    content: StoryGenerationStatus.ContentStatus(ready: false, title: title, pageCount: nil),
                    cover: nil,
                    audio: nil,
                    isGenerating: true,
                    error: nil
                ),
                startedAt: Date()
            )
            generatingStories.append(info)
        }
    }
    
    func removeGeneratingStory(storyId: String) {
        generatingStories.removeAll { $0.storyId == storyId }
    }
    
    // MARK: - State Tracking

    private var hasLoadedUserStories = false
    private var hasLoadedPrewritten = false

    // MARK: - Initialization

    init() {
        DWLogger.shared.info("LibraryViewModel initialized", category: .ui)
        setupSubscriptions()
    }

    private func setupSubscriptions() {
        // Listen for language changes
        NotificationCenter.default.publisher(for: .languageChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                DWLogger.shared.info("🌍 Language changed in Library, showing skeleton overlay", category: .ui)

                // Show skeleton overlay
                self.isRefreshing = true

                // Mark as needs reload to bypass cache checks
                self.hasLoadedUserStories = false
                self.hasLoadedPrewritten = false

                // Reset category filter to "All" in new language
                self.selectedPrewrittenCategory = "filter_all".localized
                self.selectedPrewrittenTier = nil
                self.isPrewrittenIllustratedOnly = false

                // Reload content (bypass the isLoading guard by calling repository directly)
                Task {
                    do {
                        // Load prewritten stories (most visible in library)
                        let prewritten = try await self.storyRepository.getStories(forceRefresh: true)
                        await MainActor.run {
                            self.prewrittenStories = prewritten
                            self.filterPrewritten()
                        }

                        // Load user stories if authenticated
                        if self.authManager.currentUserId != nil {
                            _ = try await self.userStoryRepository.getStories(forceRefresh: true)
                        }

                        DWLogger.shared.info("✅ Library refreshed after language change", category: .ui)
                    } catch {
                        DWLogger.shared.error("Failed to refresh library after language change", error: error, category: .ui)
                    }

                    // Hide skeleton overlay
                    await MainActor.run {
                        self.isRefreshing = false
                    }
                }
            }
            .store(in: &cancellables)

        // Listen for navigation to My Stories
        NotificationCenter.default.publisher(for: .navigateToLibraryMyStories)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                withAnimation {
                    self.selectedTab = .myStories
                }
                DWLogger.shared.info("📍 Library navigated to My Stories via notification", category: .ui)
            }
            .store(in: &cancellables)

        // Observe user stories from repository (SSOT)
        UserStoryRepository.shared.$stories
            .receive(on: RunLoop.main)
            .assign(to: &$userStories)
    }

    // MARK: - Load Library (Optimized with Repository)

    func loadLibrary(forceRefresh: Bool = false) async {
        // Guard to prevent multiple simultaneous loads
        guard !isLoading else {
            DWLogger.shared.debug("Load already in progress, skipping", category: .ui)
            return
        }

        // Check if we need to load (repository handles internal cache duration)
        // We only skip if NOT forcing refresh AND cache is valid
        if !forceRefresh && UserStoryRepository.shared.isCacheValid() && hasLoadedPrewritten {
            DWLogger.shared.debug("✅ Library already loaded and cache valid, skipping redundant load", category: .ui)
            return
        }

        // Only show loading if we don't have cached data
        let hasCachedData = !userStories.isEmpty || !prewrittenStories.isEmpty
        if !hasCachedData {
            isLoading = true
        }
        error = nil

        defer {
            isLoading = false
        }

        // Load prewritten and user stories in parallel (using repositories with caching!)
        async let prewrittenTask: () = loadPrewrittenStories(forceRefresh: forceRefresh)
        async let userStoriesTask: () = loadUserStories(forceRefresh: forceRefresh)

        let (_, _) = await (prewrittenTask, userStoriesTask)

        hasLoadedUserStories = true
        hasLoadedPrewritten = true

        DWLogger.shared.info("""
            Library load component finished (using cache when available):
            - User stories: \(userStories.count)
            - Prewritten: \(prewrittenStories.count)
            """, category: .story)
    }

    private func loadUserStories(forceRefresh: Bool = false) async {
        guard authManager.currentUserId != nil else {
            DWLogger.shared.warning("No currentUserId found, cannot load user library", category: .story)
            return
        }

        do {
            // Repository automatically handles caching and updates the @Published stories property
            // which we are now observing via setupSubscriptions()!
            _ = try await userStoryRepository.getStories(forceRefresh: forceRefresh)
            DWLogger.shared.debug("✅ [LibraryViewModel] User stories repository load call finished", category: .story)

        } catch {
            self.error = "Kütüphane yüklenemedi"
            DWLogger.shared.error("Failed to load user stories", error: error, category: .story)
        }
    }
    
    // MARK: - Delete Story

    func deleteStory(_ story: Story) async {
        // Prevent double deletion
        guard !deletingStoryIds.contains(story.id) else {
            DWLogger.shared.warning("Story already being deleted: \(story.id)", category: .story)
            return
        }
        
        DWLogger.shared.info("Deleting story: \(story.id)", category: .story)
        
        // Mark as deleting
        deletingStoryIds.insert(story.id)
        
        // Optimistic UI update with smooth animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            userStories.removeAll { $0.id == story.id }
        }

        do {
            try await StoryService.shared.deleteStory(id: story.id)

            // Remove from repository cache
            userStoryRepository.removeStory(story.id)

            DWLogger.shared.info("Story deleted successfully", category: .story)
            DWLogger.shared.logAnalyticsEvent("story_deleted", parameters: [
                "story_id": story.id,
                "story_type": story.type.rawValue
            ])

        } catch {
            // Restore story on error
            userStories.append(story)
            userStories.sort { $0.createdAt > $1.createdAt }
            
            self.error = "Hikaye silinemedi"
            DWLogger.shared.error("Failed to delete story", error: error, category: .story)
        }
        
        // Remove from deleting set
        deletingStoryIds.remove(story.id)
    }
    
    // MARK: - Refresh
    
    func refreshLibrary() async {
        DWLogger.shared.info("Refreshing library", category: .ui)
        DWLogger.shared.logUserAction("Pull to Refresh", details: "Library")

        await loadLibrary(forceRefresh: true)
    }

    // MARK: - Prewritten Stories (Using Repository)

    func loadPrewrittenStories(forceRefresh: Bool = false) async {
        DWLogger.shared.info("Loading prewritten stories for library", category: .story)

        do {
            // Repository automatically handles language and caching!
            prewrittenStories = try await storyRepository.getStories(forceRefresh: forceRefresh)
            filterPrewritten()

            DWLogger.shared.debug("✅ [LibraryViewModel] Prewritten stories loaded: \(prewrittenStories.count)", category: .story)
        } catch {
            DWLogger.shared.error("Failed to load prewritten stories", error: error, category: .story)
        }
    }

    @Published var isPrewrittenIllustratedOnly: Bool = false {
        didSet { filterPrewritten() }
    }

    // ...

    func filterPrewrittenByCategory(_ category: String) {
        selectedPrewrittenCategory = category
        filterPrewritten()
    }
    
    func filterPrewrittenByTier(_ tier: SubscriptionTier?) {
        selectedPrewrittenTier = tier
        filterPrewritten()
    }
    
    private func filterPrewritten() {
        var result = prewrittenStories

        // Filter by category
        if selectedPrewrittenCategory != "filter_all".localized {
            // Try to map localized category name to English tag
            if let tag = categoryToTagMapping[selectedPrewrittenCategory] {
                // Filter by tag (new system)
                result = result.filter { story in
                    story.tags?.contains(tag) ?? false
                }
            } else {
                // Fallback to category filtering (old system)
                // Backend might send English categories, so check both
                result = result.filter { story in
                    story.category.lowercased() == selectedPrewrittenCategory.lowercased() ||
                    story.category.localizedCaseInsensitiveContains(selectedPrewrittenCategory)
                }
            }
        }

        // Filter by tier (Strict Mode)
        if let tier = selectedPrewrittenTier {
            result = result.filter { story in
                let storyTier = SubscriptionTier(rawValue: story.metadata?.tier ?? "") ?? .free
                return storyTier == tier
            }
        }
        
        // Filter by Illustrated Only
        if isPrewrittenIllustratedOnly {
            result = result.filter { $0.isIllustrated }
        }

        filteredPrewritten = result
    }
    
    func canAccessStory(storyTier: SubscriptionTier, userTier: SubscriptionTier) -> Bool {
        let storyTierLevel = tierLevel(storyTier)
        let userTierLevel = tierLevel(userTier)
        return userTierLevel >= storyTierLevel
    }
    
    private func tierLevel(_ tier: SubscriptionTier) -> Int {
        switch tier {
        case .free: return 0
        case .plus: return 1
        case .pro: return 2
        }
    }
    
    func canAccessPrewrittenStory(_ story: Story) -> Bool {
        let currentTier = subscriptionService.currentTier
      let storyTier = SubscriptionTier(rawValue: story.metadata?.tier ?? "") ?? .free
        return canAccessStory(storyTier: storyTier, userTier: currentTier)
    }
    
    // MARK: - Tab Selection
    
    func selectTab(_ tab: LibraryTab) {
        selectedTab = tab
        DWLogger.shared.logUserAction("Library Tab Changed", details: tab.rawValue)
    }
    
    // MARK: - Sorting
    
    enum SortOption {
        case dateNewest
        case dateOldest
        case titleAZ
        case titleZA
    }
    
    func sortStories(by option: SortOption) {
        switch option {
        case .dateNewest:
            userStories.sort { $0.createdAt > $1.createdAt }
        case .dateOldest:
            userStories.sort { $0.createdAt < $1.createdAt }
        case .titleAZ:
            userStories.sort { $0.title < $1.title }
        case .titleZA:
            userStories.sort { $0.title > $1.title }
        }
        
        DWLogger.shared.logUserAction("Sort Stories", details: "\(option)")
    }
}

// MARK: - Library Tab

enum LibraryTab: String, CaseIterable {
    case myStories = "my_stories"
    case favorites = "favorites"
    case prewritten = "prewritten"
    
    var displayName: String {
        switch self {
        case .myStories: return "library_my_stories".localized
        case .favorites: return "library_favorites".localized
        case .prewritten: return "prewritten_title".localized
        }
    }
    
    /// Short title for tab bar (single line, no emojis)
    var shortTitle: String {
        switch self {
        case .myStories: return "library_tab_stories".localized
        case .favorites: return "library_tab_favorites".localized
        case .prewritten: return "library_tab_prewritten".localized
        }
    }
}

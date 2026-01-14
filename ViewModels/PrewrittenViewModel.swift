//
//  PrewrittenViewModel.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025-11-02.
//

import Foundation
import Combine

@MainActor
final class PrewrittenViewModel: ObservableObject {
    // MARK: - Singleton

    static let shared = PrewrittenViewModel()

    // MARK: - Published Properties

    @Published var stories: [Story] = []
    @Published var filteredStories: [Story] = []
    @Published var categories: [String] = []
    @Published var selectedCategory: String = "filter_all".localized

    @Published var popularClassics: [Story] = []
    @Published var dreamWeaverOriginals: [Story] = []
    @Published var featuredStories: [Story] = []

    @Published var searchText: String = ""
    @Published var selectedTier: SubscriptionTier?

    @Published var isLoading: Bool = true
    @Published var error: String?

    // MARK: - Dependencies (Repository Pattern)

    private let storyRepository = StoryRepository.shared
    private let subscriptionService = SubscriptionService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Constants

    // Category filters using localization keys
    var categoryFilters: [String] {
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

    // Tag mapping: Localized display name -> English API tag
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
    
    // MARK: - Language
    var prewrittenLanguage: String {
        return LocalizationManager.shared.currentLanguage.rawValue
    }
    
    // MARK: - Initialization
    private init() {
        setupSearchObserver()
        setupLanguageObserver()
        DWLogger.shared.info("PrewrittenViewModel initialized", category: .story)
    }
    
    private func setupLanguageObserver() {
        NotificationCenter.default.publisher(for: .languageChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.loadPrewrittenStories()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading (Using Repository - Auto Cached!)

    func loadPrewrittenStories() async {
        await loadStories(language: prewrittenLanguage)
    }

    func loadStories(language: String) async {
        isLoading = true
        error = nil

        do {
            // Backend now returns tier-sorted stories (FREE → PLUS → PRO)
            // Repository caching is safe - no need for force refresh
            let loadedStories = try await storyRepository.getStories(language: language, forceRefresh: false)

            // Apply smart shuffle for better UX: keep first few FREE at top
            stories = smartShuffleForLibrary(loadedStories)

            organizeStories()
            applyFilters()
            extractCategories()

            DWLogger.shared.debug("✅ [PrewrittenViewModel] Stories loaded with smart shuffle: \(stories.count)", category: .story)
        } catch {
            self.error = "Hikayeler yüklenemedi: \(error.localizedDescription)"
            DWLogger.shared.error("Failed to load prewritten stories", error: error, category: .story)
        }

        isLoading = false
    }

    func loadStory(id: String) async -> Story? {
        do {
            // Try repository first (with cache), then fallback to service
            return try await storyRepository.getStory(id: id)
        } catch {
            self.error = "Hikaye yüklenemedi: \(error.localizedDescription)"
            DWLogger.shared.error("Failed to load story", error: error, category: .story)
            return nil
        }
    }
    
    // MARK: - Organization

    /// Public helper for PrewrittenLibraryView to organize preloaded stories
    func organizeAndFilter() async {
        await MainActor.run {
            organizeStories()
            applyFilters()
            extractCategories()
        }
    }

    /// Smart shuffle for library: Keep first 4-5 FREE stories at top, shuffle rest
    /// This ensures users see accessible content immediately without scrolling
    private func smartShuffleForLibrary(_ stories: [Story]) -> [Story] {
        guard stories.count > 5 else { return stories }

        // Separate by tier
        let freeStories = stories.filter { ($0.metadata?.tier ?? "free") == "free" }
        let premiumStories = stories.filter { ($0.metadata?.tier ?? "free") != "free" }

        // DEBUG: Log tier distribution before shuffle
        DWLogger.shared.debug("📊 [Library] Before shuffle - FREE: \(freeStories.count), PREMIUM: \(premiumStories.count), Total: \(stories.count)", category: .story)
        DWLogger.shared.debug("📊 [Library] First 10 tiers: \(stories.prefix(10).map { $0.metadata?.tier ?? "unknown" })", category: .story)

        // Keep first 4-5 FREE at top for immediate access
        let topFree = Array(freeStories.prefix(5))
        let remainingFree = Array(freeStories.dropFirst(5))

        // Shuffle remaining stories for variety and discovery
        let remaining = (remainingFree + premiumStories).shuffled()

        let result = topFree + remaining

        // DEBUG: Log after shuffle
        DWLogger.shared.debug("📊 [Library] After shuffle - First 10 tiers: \(result.prefix(10).map { $0.metadata?.tier ?? "unknown" })", category: .story)

        // Result: [FREE, FREE, FREE, FREE, FREE, shuffled mix of all tiers...]
        return result
    }

    private func organizeStories() {
        // Popular Classics (e.g., fairy tales)
        popularClassics = stories.filter {
            $0.category.lowercased().contains("klasik") ||
            $0.category.lowercased().contains("classic") ||
            $0.category.lowercased().contains("masal")
        }

        // DreamSpire Originals
        dreamWeaverOriginals = stories.filter {
            $0.category.lowercased().contains("orijinal") ||
            $0.category.lowercased().contains("original")
        }

        // Featured stories (most viewed or highest rated)
        featuredStories = stories
            .sorted { ($0.views ?? 0) > ($1.views ?? 0) }
            .prefix(5)
            .map { $0 }
    }
    
    private func extractCategories() {
        let allCategories = Set(stories.map { $0.category })
        categories = Array(allCategories).sorted()
    }
    
    // MARK: - Filtering
    
    private func setupSearchObserver() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyFilters()
            }
            .store(in: &cancellables)
    }
    
    func filterByCategory(_ category: String) {
        selectedCategory = category
        applyFilters()
    }
    
    func filterByTier(_ tier: SubscriptionTier?) {
        selectedTier = tier
        applyFilters()
    }

    @Published var isIllustratedOnly: Bool = false {
        didSet { applyFilters() }
    }

    // ... (existing properties)

    // ...

    func applyFilters() {
        var result = stories

        // Filter by category/tag
        if selectedCategory != "filter_all".localized {
            // Try to map localized category name to English tag
            if let tag = categoryToTagMapping[selectedCategory] {
                // Filter by tag (new system)
                result = result.filter { story in
                    story.tags?.contains(tag) ?? false
                }
            } else {
                // Fallback to category filtering (old system)
                result = result.filter { story in
                    story.category.lowercased() == selectedCategory.lowercased() ||
                    story.category == selectedCategory
                }
            }
        }
        
        // Filter by tier (Strict Mode: Show ONLY stories of the selected tier)
        if let tier = selectedTier {
            result = result.filter { story in
                let storyTier = story.metadata?.tier ?? "free"
                return storyTier.lowercased() == tier.rawValue.lowercased()
            }
        }
        
        // Filter by Illustrated Only
        if isIllustratedOnly {
            result = result.filter { $0.isIllustrated }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                ($0.metadata?.genre?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        filteredStories = result
    }
    
    func selectCategory(_ category: String?) {
        selectedCategory = category ?? ""
        applyFilters()
    }
    
    func clearFilters() {
        selectedCategory = "filter_all".localized // Reset to localized 'All' instead of empty string for UI consistency
        selectedTier = nil
        isIllustratedOnly = false
        searchText = ""
        applyFilters()
    }
    
    // MARK: - Access Control
    
    func canAccessStory(_ story: Story) -> Bool {
        let currentTier = subscriptionService.currentTier
        return canAccessStory(story, currentTier: currentTier)
    }
    
    func canAccessStory(_ story: Story, currentTier: SubscriptionTier) -> Bool {
        // Define access rules based on story metadata
        let storyTier = SubscriptionTier(rawValue: story.metadata?.tier ?? "free") ?? .free
        
        switch storyTier {
        case .free:
            return true
        case .plus:
            return currentTier == .plus || currentTier == .pro
        case .pro:
            return currentTier == .pro
        }
    }
    
    func getAccessMessage(for story: Story, currentTier: SubscriptionTier) -> String? {
        if canAccessStory(story, currentTier: currentTier) {
            return nil
        }
        
        let storyTier = SubscriptionTier(rawValue: story.metadata?.tier ?? "free") ?? .free
        
        switch storyTier {
        case .plus:
            return "Bu hikayeyi okumak için Plus'a yükseltin"
        case .pro:
            return "Bu hikayeyi okumak için Pro'ya yükseltin"
        case .free:
            return nil
        }
    }
    
    // MARK: - Story Counts
    
    func getStoryCount(for tier: SubscriptionTier) -> Int {
        switch tier {
        case .free:
            return min(stories.count, 15)
        case .plus:
            return min(stories.count, 50)
        case .pro:
            return stories.count
        }
    }
    
    func getAccessibleStories(for tier: SubscriptionTier) -> [Story] {
        let limit = getStoryCount(for: tier)
        return Array(stories.prefix(limit))
    }
    
    // MARK: - Sorting
    
    func sortByPopularity() {
        filteredStories.sort { ($0.views ?? 0) > ($1.views ?? 0) }
    }
    
    func sortByDuration() {
        filteredStories.sort { $0.roundedMinutes < $1.roundedMinutes }
    }
    
    func sortByTitle() {
        filteredStories.sort { $0.title < $1.title }
    }
    
    func sortByAgeRange() {
        let ageOrder = ["toddler", "young", "middle", "preteen"]
        filteredStories.sort {
            let index1 = ageOrder.firstIndex(of: $0.metadata?.ageRange ?? "") ?? 999
            let index2 = ageOrder.firstIndex(of: $1.metadata?.ageRange ?? "") ?? 999
            return index1 < index2
        }
    }
}

// MARK: - Story Extension for Display

extension Story {
    var ageRangeDisplay: String {
        guard let ageRange = metadata?.ageRange else { return "Tüm yaşlar" }
        switch ageRange {
        case "toddler":
            return "0-3 yaş"
        case "young":
            return "4-6 yaş"
        case "middle":
            return "7-9 yaş"
        case "preteen":
            return "10-12 yaş"
        default:
            return ageRange
        }
    }
    
    var genreDisplay: String {
        return metadata?.genre?.capitalized ?? ""
    }
    
    var durationDisplay: String {
        return "\(estimatedMinutes) dk"
    }
    
    var tierBadge: String {
        let tier = SubscriptionTier(rawValue: metadata?.tier ?? "free") ?? .free
        return tier.icon
    }
}

//
//  StoryRepository.swift
//  DreamSpire
//
//  Professional data repository with intelligent caching
//  Modern iOS architecture pattern for optimal performance
//

import Foundation
import Combine

/// Centralized repository for prewritten stories with intelligent caching
@MainActor
final class StoryRepository: ObservableObject {

    // MARK: - Singleton

    static let shared = StoryRepository()

    // MARK: - Published Properties

    /// All cached stories (language-specific)
    @Published private(set) var stories: [Story] = []

    /// Current language code
    @Published private(set) var currentLanguage: String = "tr"

    /// Loading state
    @Published private(set) var isLoading = false

    /// Error state
    @Published private(set) var error: Error?

    // MARK: - Cache Management

    /// Memory cache: language -> stories
    private var cache: [String: [Story]] = [:]

    /// Cache timestamps: language -> Date
    private var cacheTimestamps: [String: Date] = [:]

    /// Cache duration (5 minutes)
    private let cacheDuration: TimeInterval = 5 * 60

    /// Active fetch tasks to prevent duplicate requests
    private var activeFetchTasks: [String: Task<[Story], Error>] = [:]

    // MARK: - Dependencies

    private let prewrittenService = PrewrittenService.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        DWLogger.shared.info("StoryRepository initialized", category: .story)
        setupLanguageObserver()

        // Set initial language
        self.currentLanguage = LocalizationManager.shared.currentLanguage.rawValue
    }

    // MARK: - Language Observer

    private func setupLanguageObserver() {
        NotificationCenter.default.publisher(for: .languageChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }

                let targetLang = LocalizationManager.shared.currentLanguage.rawValue

                if self.currentLanguage != targetLang {
                    DWLogger.shared.info("🌍 Repository detected language change: \(self.currentLanguage) → \(targetLang). Clearing cache.", category: .story)
                    
                    // CRITICAL: Clear all cache to ensure no stale language stories are kept
                    self.clearCache()
                    self.currentLanguage = targetLang
                    
                    // Load stories for new language (will fetch fresh since cache is cleared)
                    Task {
                        _ = try? await self.getStories(language: targetLang, forceRefresh: true)
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public API

    /// Get stories with intelligent caching
    /// - Parameters:
    ///   - language: Language code (default: current language)
    ///   - forceRefresh: Skip cache and fetch fresh data
    ///   - summary: Whether to fetch only metadata (faster)
    /// - Returns: Array of stories
    func getStories(language: String? = nil, forceRefresh: Bool = false, summary: Bool = true) async throws -> [Story] {
        let targetLanguage = language ?? currentLanguage

        // Check if cache is valid and not forcing refresh
        // For prewritten stories, we usually want to check if the cached stories are summaries or full
        if !forceRefresh, let cached = getCachedStories(for: targetLanguage) {
            // If we need summaries and have anything, or if we need full and have full
            let cachedIsSummary = cached.first?.isSummary ?? false
            if !summary || cachedIsSummary == summary {
                DWLogger.shared.debug("✅ Using cached stories for \(targetLanguage): \(cached.count) stories (summary: \(cachedIsSummary))", category: .story)

                self.stories = cached
                self.currentLanguage = targetLanguage
                return cached
            }
        }

        // Check if there's already an active fetch for this language
        if let existingTask = activeFetchTasks[targetLanguage] {
            DWLogger.shared.debug("⏳ Joining existing fetch task for \(targetLanguage)", category: .story)
            return try await existingTask.value
        }

        // Create new fetch task
        let fetchTask = Task<[Story], Error> {
            DWLogger.shared.info("🌐 Fetching stories from backend: \(targetLanguage) (summary: \(summary))", category: .story)

            self.isLoading = true
            self.error = nil

            do {
                let fetchedStories = try await prewrittenService.getPrewrittenStories(language: targetLanguage, summary: summary)

                // Update cache
                self.cache[targetLanguage] = fetchedStories
                self.cacheTimestamps[targetLanguage] = Date()

                // Update published properties
                self.stories = fetchedStories
                self.currentLanguage = targetLanguage
                self.isLoading = false

                DWLogger.shared.info("✅ Stories cached: \(fetchedStories.count) for \(targetLanguage)", category: .story)

                return fetchedStories

            } catch {
                self.error = error
                self.isLoading = false
                DWLogger.shared.error("❌ Failed to fetch stories", error: error, category: .story)
                throw error
            }
        }

        // Store active task
        activeFetchTasks[targetLanguage] = fetchTask

        defer {
            // Clean up task after completion
            activeFetchTasks.removeValue(forKey: targetLanguage)
        }

        return try await fetchTask.value
    }

    /// Get stories filtered by tag
    func getStoriesByTag(_ tag: String, language: String? = nil) async throws -> [Story] {
        let allStories = try await getStories(language: language, forceRefresh: false)
        return allStories.filter { $0.tags?.contains(tag) ?? false }
    }

    /// Get stories filtered by category
    func getStoriesByCategory(_ category: String, language: String? = nil) async throws -> [Story] {
        let allStories = try await getStories(language: language, forceRefresh: false)
        return allStories.filter { $0.category.lowercased() == category.lowercased() }
    }

    /// Get a single story by ID (from cache first, then backend)
    func getStory(id: String, language: String? = nil) async throws -> Story? {
        // Try cache first
        let allStories = try await getStories(language: language, forceRefresh: false)
        if let cached = allStories.first(where: { $0.id == id }) {
            DWLogger.shared.debug("✅ Story found in cache: \(id)", category: .story)
            return cached
        }

        // Fetch from backend
        DWLogger.shared.info("🌐 Fetching story from backend: \(id)", category: .story)
        return try await prewrittenService.getPrewrittenStory(id: id)
    }

    /// Force refresh - clears cache and fetches fresh data
    func refresh(language: String? = nil) async throws -> [Story] {
        let targetLanguage = language ?? currentLanguage

        DWLogger.shared.info("🔄 Force refreshing stories: \(targetLanguage)", category: .story)

        // Clear cache for this language
        cache.removeValue(forKey: targetLanguage)
        cacheTimestamps.removeValue(forKey: targetLanguage)

        return try await getStories(language: targetLanguage, forceRefresh: true)
    }

    /// Clear all cache
    func clearCache() {
        DWLogger.shared.info("🗑️ Clearing all story cache", category: .story)
        cache.removeAll()
        cacheTimestamps.removeAll()
        stories = []
    }

    /// Clear cache for specific language
    func clearCache(for language: String) {
        DWLogger.shared.info("🗑️ Clearing cache for language: \(language)", category: .story)
        cache.removeValue(forKey: language)
        cacheTimestamps.removeValue(forKey: language)

        if currentLanguage == language {
            stories = []
        }
    }

    // MARK: - Cache Helpers

    /// Get cached stories if still valid
    private func getCachedStories(for language: String) -> [Story]? {
        guard let cached = cache[language],
              let timestamp = cacheTimestamps[language] else {
            return nil
        }

        let age = Date().timeIntervalSince(timestamp)

        if age < cacheDuration {
            DWLogger.shared.debug("✅ Cache valid (age: \(Int(age))s / \(Int(cacheDuration))s)", category: .story)
            return cached
        } else {
            DWLogger.shared.debug("⏰ Cache expired (age: \(Int(age))s)", category: .story)
            return nil
        }
    }

    /// Check if cache is valid
    func isCacheValid(for language: String? = nil) -> Bool {
        let targetLanguage = language ?? currentLanguage
        return getCachedStories(for: targetLanguage) != nil
    }

    /// Get cache age in seconds
    func getCacheAge(for language: String? = nil) -> TimeInterval? {
        let targetLanguage = language ?? currentLanguage
        guard let timestamp = cacheTimestamps[targetLanguage] else {
            return nil
        }
        return Date().timeIntervalSince(timestamp)
    }
}

// MARK: - Computed Properties

extension StoryRepository {

    /// Popular classics (tag: "classic")
    var popularClassics: [Story] {
        stories.filter { $0.tags?.contains("classic") ?? false }
    }

    /// Animal stories (tag: "animals")
    var animalStories: [Story] {
        stories.filter { $0.tags?.contains("animals") ?? false }
    }

    /// Adventure stories (tag: "adventure")
    var adventureStories: [Story] {
        stories.filter { $0.tags?.contains("adventure") ?? false }
    }

    /// Featured stories (most viewed)
    var featuredStories: [Story] {
        stories
            .sorted { ($0.views ?? 0) > ($1.views ?? 0) }
            .prefix(5)
            .map { $0 }
    }

    /// All unique categories
    var categories: [String] {
        Array(Set(stories.map { $0.category })).sorted()
    }

    /// All unique tags
    var allTags: [String] {
        var tags = Set<String>()
        for story in stories {
            if let storyTags = story.tags {
                tags.formUnion(storyTags)
            }
        }
        return Array(tags).sorted()
    }
}

// MARK: - Statistics

extension StoryRepository {

    /// Total number of cached stories
    var totalCachedStories: Int {
        cache.values.reduce(0) { $0 + $1.count }
    }

    /// Number of cached languages
    var cachedLanguages: [String] {
        Array(cache.keys)
    }

    /// Cache statistics for debugging
    var cacheStats: String {
        """
        📊 Story Cache Stats:
        - Current Language: \(currentLanguage)
        - Current Stories: \(stories.count)
        - Cached Languages: \(cachedLanguages.joined(separator: ", "))
        - Total Cached: \(totalCachedStories) stories
        - Cache Age: \(getCacheAge().map { "\(Int($0))s" } ?? "N/A")
        """
    }
}

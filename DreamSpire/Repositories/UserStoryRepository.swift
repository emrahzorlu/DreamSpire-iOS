//
//  UserStoryRepository.swift
//  DreamSpire
//
//  Professional repository for user-generated stories with caching
//

import Foundation
import Combine

/// Centralized repository for user-generated stories with intelligent caching
@MainActor
final class UserStoryRepository: ObservableObject {

    // MARK: - Singleton

    static let shared = UserStoryRepository()

    // MARK: - Published Properties

    /// All cached user stories
    @Published private(set) var stories: [Story] = []

    /// Recent stories (last 5)
    @Published private(set) var recentStories: [Story] = []

    /// Loading state
    @Published private(set) var isLoading = false

    /// Error state
    @Published private(set) var error: Error?

    // MARK: - Cache Management

    /// Memory cache: userId -> stories
    private var cache: [String: [Story]] = [:]

    /// Cache timestamps: userId -> Date
    private var cacheTimestamps: [String: Date] = [:]

    /// Cache duration (3 minutes for user stories - shorter than prewritten)
    private let cacheDuration: TimeInterval = 3 * 60

    /// Active fetch tasks to prevent duplicate requests
    private var activeFetchTasks: [String: Task<[Story], Error>] = [:]

    // MARK: - Dependencies

    private let storyService = StoryService.shared
    private let authManager = AuthManager.shared

    // MARK: - Initialization

    private init() {
        DWLogger.shared.info("UserStoryRepository initialized", category: .story)
    }

    // MARK: - Public API

    /// Get user stories with intelligent caching
    /// - Parameters:
    ///   - userId: User ID (defaults to current user)
    ///   - forceRefresh: Skip cache and fetch fresh data
    ///   - summary: Whether to fetch only metadata (faster)
    /// - Returns: Array of user stories
    func getStories(userId: String? = nil, forceRefresh: Bool = false, summary: Bool = true) async throws -> [Story] {
        let targetUserId = userId ?? authManager.currentUserId ?? ""

        guard !targetUserId.isEmpty else {
            DWLogger.shared.warning("No userId provided", category: .story)
            return []
        }

        // Check if cache is valid and not forcing refresh
        if !forceRefresh, let cached = getCachedStories(for: targetUserId) {
            DWLogger.shared.debug("✅ Using cached user stories: \(cached.count) stories", category: .story)

            // Update published properties
            updatePublishedProperties(with: cached)

            return cached
        }

        // Check if there's already an active fetch for this user
        if let existingTask = activeFetchTasks[targetUserId] {
            DWLogger.shared.debug("⏳ Joining existing fetch task for user: \(targetUserId)", category: .story)
            return try await existingTask.value
        }

        // Create new fetch task
        let fetchTask = Task<[Story], Error> {
            DWLogger.shared.info("🌐 Fetching user stories from backend: \(targetUserId)", category: .story)

            self.isLoading = true
            self.error = nil

            do {
                let fetchedStories = try await storyService.getUserStories(userId: targetUserId, summary: summary)

                // Sort by date (newest first)
                let sortedStories = fetchedStories.sorted { $0.createdAt > $1.createdAt }

                // Update cache
                self.cache[targetUserId] = sortedStories
                self.cacheTimestamps[targetUserId] = Date()

                // Update published properties
                self.updatePublishedProperties(with: sortedStories)
                self.isLoading = false

                DWLogger.shared.info("✅ User stories cached: \(sortedStories.count)", category: .story)

                return sortedStories

            } catch {
                self.error = error
                self.isLoading = false
                DWLogger.shared.error("❌ Failed to fetch user stories", error: error, category: .story)
                throw error
            }
        }

        // Store active task
        activeFetchTasks[targetUserId] = fetchTask

        defer {
            // Clean up task after completion
            activeFetchTasks.removeValue(forKey: targetUserId)
        }

        return try await fetchTask.value
    }

    /// Get a single story, fetching details if only summary is available
    func getStory(id: String, forceRefresh: Bool = false) async throws -> Story {
        // Find in cache
        let allStories = stories
        if let existing = allStories.first(where: { $0.id == id }) {
            // If it's a full story and not forcing refresh, return it
            if !existing.isSummary && !forceRefresh {
                DWLogger.shared.debug("✅ Using full story from cache: \(id)", category: .story)
                return existing
            }
        }

        DWLogger.shared.info("🌐 Fetching full story details from backend: \(id)", category: .story)

        do {
            let fullStory = try await storyService.getStory(id: id)
            
            // Update in cache
            updateStory(fullStory)
            
            return fullStory
        } catch {
            DWLogger.shared.error("❌ Failed to fetch full story details", error: error, category: .story)
            throw error
        }
    }

    /// Get recent stories (last 5)
    func getRecentStories(userId: String? = nil, forceRefresh: Bool = false) async throws -> [Story] {
        let allStories = try await getStories(userId: userId, forceRefresh: forceRefresh)
        return Array(allStories.prefix(5))
    }

    /// Add a new story to cache (called after creation)
    func addStory(_ story: Story, userId: String? = nil) {
        let targetUserId = userId ?? authManager.currentUserId ?? ""

        guard !targetUserId.isEmpty else { return }

        // Add to cache
        if var cached = cache[targetUserId] {
            // Insert at beginning (newest first)
            cached.insert(story, at: 0)
            cache[targetUserId] = cached
        } else {
            cache[targetUserId] = [story]
        }

        // Update timestamp
        cacheTimestamps[targetUserId] = Date()

        // Update published properties
        if targetUserId == authManager.currentUserId {
            stories.insert(story, at: 0)
            recentStories = Array(stories.prefix(5))
        }

        DWLogger.shared.info("✅ Story added to cache: \(story.id)", category: .story)
    }

    /// Remove a story from cache (called after deletion)
    func removeStory(_ storyId: String, userId: String? = nil) {
        let targetUserId = userId ?? authManager.currentUserId ?? ""

        guard !targetUserId.isEmpty else { return }

        // Remove from cache
        if var cached = cache[targetUserId] {
            cached.removeAll { $0.id == storyId }
            cache[targetUserId] = cached
        }

        // Update published properties
        if targetUserId == authManager.currentUserId {
            stories.removeAll { $0.id == storyId }
            recentStories = Array(stories.prefix(5))
        }

        DWLogger.shared.info("✅ Story removed from cache: \(storyId)", category: .story)
    }

    /// Update a story in cache
    func updateStory(_ story: Story, userId: String? = nil) {
        let targetUserId = userId ?? authManager.currentUserId ?? ""

        guard !targetUserId.isEmpty else { return }

        // Update in cache
        if var cached = cache[targetUserId] {
            if let index = cached.firstIndex(where: { $0.id == story.id }) {
                cached[index] = story
                cache[targetUserId] = cached
            }
        }

        // Update published properties
        if targetUserId == authManager.currentUserId {
            if let index = stories.firstIndex(where: { $0.id == story.id }) {
                stories[index] = story
                recentStories = Array(stories.prefix(5))
            }
        }

        DWLogger.shared.info("✅ Story updated in cache: \(story.id)", category: .story)
    }

    /// Force refresh - clears cache and fetches fresh data
    func refresh(userId: String? = nil) async throws -> [Story] {
        let targetUserId = userId ?? authManager.currentUserId ?? ""

        guard !targetUserId.isEmpty else {
            return []
        }

        DWLogger.shared.info("🔄 Force refreshing user stories", category: .story)

        // Clear cache for this user
        cache.removeValue(forKey: targetUserId)
        cacheTimestamps.removeValue(forKey: targetUserId)

        return try await getStories(userId: targetUserId, forceRefresh: true)
    }

    /// Clear all cache
    func clearCache() {
        DWLogger.shared.info("🗑️ Clearing all user story cache", category: .story)
        cache.removeAll()
        cacheTimestamps.removeAll()
        stories = []
        recentStories = []
    }

    /// Clear cache for specific user
    func clearCache(for userId: String) {
        DWLogger.shared.info("🗑️ Clearing cache for user: \(userId)", category: .story)
        cache.removeValue(forKey: userId)
        cacheTimestamps.removeValue(forKey: userId)

        if userId == authManager.currentUserId {
            stories = []
            recentStories = []
        }
    }

    // MARK: - Private Helpers

    /// Get cached stories if still valid
    private func getCachedStories(for userId: String) -> [Story]? {
        guard let cached = cache[userId],
              let timestamp = cacheTimestamps[userId] else {
            return nil
        }

        let age = Date().timeIntervalSince(timestamp)

        if age < cacheDuration {
            DWLogger.shared.debug("✅ User cache valid (age: \(Int(age))s / \(Int(cacheDuration))s)", category: .story)
            return cached
        } else {
            DWLogger.shared.debug("⏰ User cache expired (age: \(Int(age))s)", category: .story)
            return nil
        }
    }

    /// Update published properties
    private func updatePublishedProperties(with stories: [Story]) {
        self.stories = stories
        self.recentStories = Array(stories.prefix(5))
    }

    /// Check if cache is valid
    func isCacheValid(for userId: String? = nil) -> Bool {
        let targetUserId = userId ?? authManager.currentUserId ?? ""
        return getCachedStories(for: targetUserId) != nil
    }

    /// Get cache age in seconds
    func getCacheAge(for userId: String? = nil) -> TimeInterval? {
        let targetUserId = userId ?? authManager.currentUserId ?? ""
        guard let timestamp = cacheTimestamps[targetUserId] else {
            return nil
        }
        return Date().timeIntervalSince(timestamp)
    }
}

// MARK: - Statistics

extension UserStoryRepository {

    /// Total number of cached stories across all users
    var totalCachedStories: Int {
        cache.values.reduce(0) { $0 + $1.count }
    }

    /// Number of cached users
    var cachedUserIds: [String] {
        Array(cache.keys)
    }

    /// Cache statistics for debugging
    var cacheStats: String {
        let currentUserId = authManager.currentUserId ?? "N/A"
        return """
        📊 User Story Cache Stats:
        - Current User: \(currentUserId)
        - Current Stories: \(stories.count)
        - Recent Stories: \(recentStories.count)
        - Cached Users: \(cachedUserIds.count)
        - Total Cached: \(totalCachedStories) stories
        - Cache Age: \(getCacheAge().map { "\(Int($0))s" } ?? "N/A")
        """
    }
}

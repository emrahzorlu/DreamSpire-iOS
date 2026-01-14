//
//  FavoritesRepository.swift
//  DreamSpire
//
//  Professional repository for user favorites with caching
//

import Foundation
import Combine

/// Centralized repository for user favorites with intelligent caching
@MainActor
final class FavoritesRepository: ObservableObject {

    // MARK: - Singleton

    static let shared = FavoritesRepository()

    // MARK: - Published Properties

    /// All cached favorite stories
    @Published private(set) var favorites: [Story] = []

    /// Loading state
    @Published private(set) var isLoading = false

    /// Error state
    @Published private(set) var error: Error?

    // MARK: - Cache Management

    /// Memory cache: userId -> favorites
    private var cache: [String: [Story]] = [:]

    /// Cache timestamps: userId -> Date
    private var cacheTimestamps: [String: Date] = [:]

    /// Cache duration (3 minutes - same as user stories)
    private let cacheDuration: TimeInterval = 3 * 60

    /// Active fetch task to prevent duplicate requests
    private var activeFetchTask: Task<[Story], Error>?

    // MARK: - Dependencies

    private let apiClient = APIClient.shared
    private let authManager = AuthManager.shared

    // MARK: - Initialization

    private init() {
        DWLogger.shared.info("FavoritesRepository initialized", category: .story)
    }

    // MARK: - Public API

    /// Get user favorites with intelligent caching
    /// - Parameter forceRefresh: Skip cache and fetch fresh data
    /// - Returns: Array of favorite stories
    func getFavorites(forceRefresh: Bool = false) async throws -> [Story] {
        guard let userId = authManager.currentUserId else {
            DWLogger.shared.warning("No userId for favorites", category: .story)
            return []
        }

        // Check if cache is valid and not forcing refresh
        if !forceRefresh, let cached = getCachedFavorites(for: userId) {
            DWLogger.shared.debug("✅ Using cached favorites: \(cached.count) stories", category: .story)

            // Update published properties
            favorites = cached

            return cached
        }

        // Check if there's already an active fetch
        if let existingTask = activeFetchTask {
            DWLogger.shared.debug("⏳ Joining existing fetch task for favorites", category: .story)
            return try await existingTask.value
        }

        // Create new fetch task
        let fetchTask = Task<[Story], Error> {
            DWLogger.shared.info("🌐 Fetching favorites from backend", category: .story)

            self.isLoading = true
            self.error = nil

            do {
                let fetchedFavorites = try await apiClient.getUserFavorites()

                // Update cache
                cache[userId] = fetchedFavorites
                cacheTimestamps[userId] = Date()

                // Update published properties
                favorites = fetchedFavorites

                self.isLoading = false

                DWLogger.shared.info("✅ Favorites fetched: \(fetchedFavorites.count) stories", category: .story)

                return fetchedFavorites

            } catch {
                self.error = error
                self.isLoading = false

                DWLogger.shared.error("Failed to fetch favorites", error: error, category: .story)
                throw error
            }
        }

        activeFetchTask = fetchTask

        do {
            let result = try await fetchTask.value
            activeFetchTask = nil
            return result
        } catch {
            activeFetchTask = nil
            throw error
        }
    }

    /// Force refresh favorites from backend
    func refresh() async throws -> [Story] {
        DWLogger.shared.info("🔄 Force refreshing favorites", category: .story)
        return try await getFavorites(forceRefresh: true)
    }

    /// Clear all cached favorites
    func clearCache() {
        cache.removeAll()
        cacheTimestamps.removeAll()
        favorites = []
        DWLogger.shared.info("🗑️ Favorites cache cleared", category: .story)
    }

    /// Invalidate cache when a favorite is added (so next load fetches fresh data)
    /// This keeps the current favorites array intact but marks cache as stale
    func invalidateCacheForFavoriteChange() {
        guard let userId = authManager.currentUserId else { return }
        // Set timestamp to past so cache is considered expired
        cacheTimestamps[userId] = Date.distantPast
        DWLogger.shared.debug("⚡ Favorites cache invalidated for next sync", category: .story)
    }

    /// Optimistic update: Add favorite to cache immediately
    func addFavoriteOptimistically(_ story: Story) {
        guard let userId = authManager.currentUserId else { return }

        // Add to cache immediately
        if var cachedFavorites = cache[userId] {
            // Avoid duplicates
            if !cachedFavorites.contains(where: { $0.id == story.id }) {
                cachedFavorites.insert(story, at: 0)
                cache[userId] = cachedFavorites
                favorites = cachedFavorites
                DWLogger.shared.debug("⚡ Optimistically added favorite: \(story.title)", category: .story)
            }
        } else {
            cache[userId] = [story]
            favorites = [story]
            cacheTimestamps[userId] = Date()
        }
    }

    /// Optimistic update: Remove favorite from cache immediately
    func removeFavoriteOptimistically(storyId: String) {
        guard let userId = authManager.currentUserId else { return }

        // Remove from cache immediately
        if var cachedFavorites = cache[userId] {
            cachedFavorites.removeAll { $0.id == storyId }
            cache[userId] = cachedFavorites
            favorites = cachedFavorites
            DWLogger.shared.debug("⚡ Optimistically removed favorite: \(storyId)", category: .story)
        }
    }

    // MARK: - Private Helpers

    /// Get cached favorites if valid
    private func getCachedFavorites(for userId: String) -> [Story]? {
        guard let cached = cache[userId],
              let timestamp = cacheTimestamps[userId],
              Date().timeIntervalSince(timestamp) < cacheDuration else {
            return nil
        }

        return cached
    }

    /// Check if cache is valid for user
    func isCacheValid(for userId: String? = nil) -> Bool {
        let targetUserId = userId ?? authManager.currentUserId ?? ""
        guard !targetUserId.isEmpty else { return false }

        return getCachedFavorites(for: targetUserId) != nil
    }
}

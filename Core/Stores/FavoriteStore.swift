//
//  FavoriteStore.swift
//  DreamSpire
//
//  Professional favorite management with SwiftUI observation
//  Optimized with extended cache duration for better performance
//

import Foundation

@MainActor
final class FavoriteStore: ObservableObject {
    @Published private(set) var favoriteIds: Set<String> = []
    @Published private(set) var isLoading = false

    static let shared = FavoriteStore()

    // Use FavoritesRepository for all data operations
    private let repository = FavoritesRepository.shared

    private init() {
        DWLogger.shared.info("✅ FavoriteStore initialized (using FavoritesRepository)", category: .story)
    }
    
    // MARK: - Public Methods

    func load() async {
        guard !isLoading else { return }

        await MainActor.run {
            isLoading = true
        }

        defer {
            Task { @MainActor in
                isLoading = false
            }
        }

        do {
            // Use repository (handles caching automatically)
            let favorites = try await repository.getFavorites()
            await MainActor.run {
                let newIds = Set(favorites.map { $0.id })
                if favoriteIds != newIds {
                    DWLogger.shared.debug("✅ Favorites updated: \(favoriteIds.count) → \(newIds.count)", category: .story)
                    favoriteIds = newIds
                } else {
                    DWLogger.shared.debug("✅ Favorites unchanged: \(favoriteIds.count)", category: .story)
                }
            }
        } catch {
            DWLogger.shared.error("❌ Failed to load favorites", error: error, category: .story)
        }
    }

    func forceRefresh() async {
        await MainActor.run {
            isLoading = true
        }

        defer {
            Task { @MainActor in
                isLoading = false
            }
        }

        do {
            // Force refresh from repository
            let favorites = try await repository.refresh()
            await MainActor.run {
                favoriteIds = Set(favorites.map { $0.id })
                DWLogger.shared.info("✅ Favorites force refreshed: \(favoriteIds.count)", category: .story)
            }
        } catch {
            DWLogger.shared.error("❌ Failed to refresh favorites", error: error, category: .story)
        }
    }
    
    func toggle(_ storyId: String) async -> Bool {
        guard !isLoading else {
            DWLogger.shared.warning("⚠️ Skipping toggle - already loading", category: .story)
            return favoriteIds.contains(storyId)
        }

        DWLogger.shared.debug("🟡 Toggle started for \(storyId)", category: .story)

        // Optimistic update locally
        let wasIn = favoriteIds.contains(storyId)
        let newIds = wasIn ? favoriteIds.subtracting([storyId]) : favoriteIds.union([storyId])

        await MainActor.run {
            favoriteIds = newIds
            DWLogger.shared.debug("🟡 Optimistic update: \(favoriteIds.count) favorites", category: .story)
        }

        // Backend call through FavoriteManager (keeps existing logic)
        do {
            let newState = try await FavoriteManager.shared.toggleFavorite(storyId: storyId)
            DWLogger.shared.debug("🟢 Backend returned: \(newState)", category: .story)

            // Update repository cache to stay in sync
            if newState {
                // Added to favorites - invalidate repository cache so next load fetches fresh data
                repository.invalidateCacheForFavoriteChange()
                DWLogger.shared.debug("✅ Favorite added - cache invalidated for next sync", category: .story)
            } else {
                // Removed from favorites - remove from repository cache
                repository.removeFavoriteOptimistically(storyId: storyId)
                DWLogger.shared.debug("✅ Favorite removed - repository updated", category: .story)
            }

            // Verify consistency between backend and our optimistic update
            let expectedState = !wasIn
            if newState != expectedState {
                DWLogger.shared.warning("⚠️ State mismatch detected, forcing refresh...", category: .story)
                await forceRefresh()
                return newState
            }

            DWLogger.shared.info("✅ Toggle successful - UI updated immediately", category: .story)
            return newState

        } catch {
            DWLogger.shared.error("❌ Toggle failed", error: error, category: .story)

            // Rollback on error
            await MainActor.run {
                favoriteIds = wasIn ? favoriteIds.union([storyId]) : favoriteIds.subtracting([storyId])
                DWLogger.shared.debug("🔄 Rolled back to: \(favoriteIds.count) favorites", category: .story)
            }

            return wasIn
        }
    }
    
    func isFavorite(_ storyId: String) -> Bool {
        return favoriteIds.contains(storyId)
    }
    
    func getFavoriteCount() -> Int {
        return favoriteIds.count
    }
}

// MARK: - Convenience Extensions

extension FavoriteStore {
    func refresh() async {
        await load()
    }
}

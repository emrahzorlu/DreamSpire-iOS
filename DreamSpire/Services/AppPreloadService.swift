//
//  AppPreloadService.swift
//  DreamSpire
//
//  Professional app preloading service
//  Loads critical data during app launch for instant UI rendering
//

import Foundation
import Combine

/// Service for preloading critical data during app launch
@MainActor
final class AppPreloadService: ObservableObject {

    // MARK: - Singleton

    static let shared = AppPreloadService()

    // MARK: - Properties

    /// Is currently preloading
    @Published private(set) var isPreloading = false

    /// Preload completion timestamp
    @Published private(set) var lastPreloadDate: Date?

    /// Has completed initial preload
    @Published private(set) var hasCompletedInitialPreload = false

    // MARK: - Dependencies

    private let storyRepository = StoryRepository.shared
    private let userStoryRepository = UserStoryRepository.shared
    private let characterRepository = CharacterRepository.shared
    private let favoritesRepository = FavoritesRepository.shared
    private let coinTransactionRepository = CoinTransactionRepository.shared
    private let coinService = CoinService.shared
    private let subscriptionService = SubscriptionService.shared

    // MARK: - Initialization

    private init() {
        DWLogger.shared.info("AppPreloadService initialized", category: .general)
    }

    // MARK: - Preload Methods

    /// Preload all critical data for instant app experience
    /// Call this during app launch (splash screen) or when user logs in
    func preloadAllData() async {
        guard !isPreloading else {
            DWLogger.shared.debug("Preload already in progress", category: .general)
            return
        }

        isPreloading = true
        defer { isPreloading = false }

        DWLogger.shared.info("🚀 Starting app data preload...", category: .general)
        let startTime = Date()

        do {
            // Preload all critical data in parallel for maximum speed
            async let storiesTask: Void = preloadStories()
            async let userStoriesTask: Void = preloadUserStories()
            async let charactersTask: Void = preloadCharacters()
            async let favoritesTask: Void = preloadFavorites()
            async let transactionsTask: Void = preloadTransactions()
            async let balanceTask: Void = preloadCoinBalance()
            async let subscriptionTask: Void = preloadSubscription()

            _ = try await (storiesTask, userStoriesTask, charactersTask, favoritesTask, transactionsTask, balanceTask, subscriptionTask)

            lastPreloadDate = Date()
            hasCompletedInitialPreload = true

            let duration = Date().timeIntervalSince(startTime)
            DWLogger.shared.info("✅ App data preload completed in \(String(format: "%.2f", duration))s", category: .general)

        } catch {
            DWLogger.shared.error("App data preload failed (non-critical)", error: error, category: .general)
            // Don't throw - preload failures shouldn't block app launch
        }
    }

    /// Preload only user-specific data (call after login)
    func preloadUserData() async {
        guard !isPreloading else {
            DWLogger.shared.debug("Preload already in progress", category: .general)
            return
        }

        isPreloading = true
        defer { isPreloading = false }

        DWLogger.shared.info("🔄 Preloading user data...", category: .general)

        do {
            async let userStoriesTask: Void = preloadUserStories()
            async let charactersTask: Void = preloadCharacters()
            async let favoritesTask: Void = preloadFavorites()
            async let transactionsTask: Void = preloadTransactions()
            async let balanceTask: Void = preloadCoinBalance()
            async let subscriptionTask: Void = preloadSubscription()

            _ = try await (userStoriesTask, charactersTask, favoritesTask, transactionsTask, balanceTask, subscriptionTask)

            DWLogger.shared.info("✅ User data preloaded successfully", category: .general)

        } catch {
            DWLogger.shared.error("User data preload failed", error: error, category: .general)
        }
    }

    // MARK: - Individual Preload Methods

    private func preloadStories() async throws {
        do {
            _ = try await storyRepository.getStories(forceRefresh: false)
            DWLogger.shared.debug("✅ Stories preloaded", category: .story)
        } catch {
            DWLogger.shared.error("Failed to preload stories", error: error, category: .story)
            throw error
        }
    }

    private func preloadUserStories() async throws {
        do {
            _ = try await userStoryRepository.getStories(forceRefresh: false)
            DWLogger.shared.debug("✅ User stories preloaded", category: .story)
        } catch {
            DWLogger.shared.error("Failed to preload user stories", error: error, category: .story)
            throw error
        }
    }

    private func preloadCharacters() async throws {
        do {
            _ = try await characterRepository.getCharacters(forceRefresh: false)
            DWLogger.shared.debug("✅ Characters preloaded", category: .general)
        } catch {
            DWLogger.shared.error("Failed to preload characters", error: error, category: .general)
            throw error
        }
    }

    private func preloadFavorites() async throws {
        do {
            _ = try await favoritesRepository.getFavorites(forceRefresh: false)
            DWLogger.shared.debug("✅ Favorites preloaded", category: .story)
        } catch {
            DWLogger.shared.error("Failed to preload favorites", error: error, category: .story)
            throw error
        }
    }

    private func preloadTransactions() async throws {
        do {
            _ = try await coinTransactionRepository.getTransactions(forceRefresh: false)
            DWLogger.shared.debug("✅ Transactions preloaded", category: .coin)
        } catch {
            DWLogger.shared.error("Failed to preload transactions", error: error, category: .coin)
            throw error
        }
    }

    private func preloadCoinBalance() async throws {
        do {
            try await coinService.fetchBalance()
            DWLogger.shared.debug("✅ Coin balance preloaded", category: .coin)
        } catch {
            DWLogger.shared.error("Failed to preload coin balance", error: error, category: .coin)
            throw error
        }
    }

    private func preloadSubscription() async throws {
        do {
            try await subscriptionService.loadSubscription()
            DWLogger.shared.debug("✅ Subscription preloaded", category: .general)
        } catch {
            DWLogger.shared.error("Failed to preload subscription", error: error, category: .general)
            throw error
        }
    }

    // MARK: - Clear Cache (on logout)

    /// Clear all cached data (call on logout)
    func clearAllCaches() {
        storyRepository.clearCache()
        userStoryRepository.clearCache()
        characterRepository.clearCache()
        favoritesRepository.clearCache()
        coinTransactionRepository.clearCache()
        coinService.clearCache()
        subscriptionService.clearCache()

        hasCompletedInitialPreload = false
        lastPreloadDate = nil

        DWLogger.shared.info("All caches cleared", category: .general)
    }
}

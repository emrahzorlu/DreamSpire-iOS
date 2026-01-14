//
//  BackgroundRefreshService.swift
//  DreamSpire
//
//  Professional background refresh service
//  Ensures data stays fresh without user interaction
//

import Foundation
import Combine
import UIKit

/// Service for managing background data refresh
@MainActor
final class BackgroundRefreshService: ObservableObject {

    // MARK: - Singleton

    static let shared = BackgroundRefreshService()

    // MARK: - Properties

    /// Last refresh timestamp
    @Published private(set) var lastRefreshDate: Date?

    /// Is currently refreshing
    @Published private(set) var isRefreshing = false

    /// Refresh interval (5 minutes)
    private let refreshInterval: TimeInterval = 5 * 60

    /// Repositories to refresh
    private let storyRepository = StoryRepository.shared
    private let userStoryRepository = UserStoryRepository.shared
    private let coinTransactionRepository = CoinTransactionRepository.shared

    // MARK: - Initialization

    private init() {
        DWLogger.shared.info("BackgroundRefreshService initialized", category: .general)
        setupBackgroundRefresh()
    }

    // MARK: - Setup

    private func setupBackgroundRefresh() {
        // Listen to app becoming active
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appBecameActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        DWLogger.shared.debug("Background refresh observer setup complete", category: .general)
    }

    // MARK: - App Lifecycle

    @objc private func appBecameActive() {
        Task {
            await refreshIfNeeded()
        }
    }

    // MARK: - Refresh Logic

    /// Refresh data if enough time has passed
    func refreshIfNeeded() async {
        guard !isRefreshing else {
            DWLogger.shared.debug("Refresh already in progress", category: .general)
            return
        }

        // Check if refresh is needed
        if let lastRefresh = lastRefreshDate {
            let timeSinceRefresh = Date().timeIntervalSince(lastRefresh)

            if timeSinceRefresh < refreshInterval {
                DWLogger.shared.debug(
                    "Refresh not needed yet (last: \(Int(timeSinceRefresh))s ago, interval: \(Int(refreshInterval))s)",
                    category: .general
                )
                return
            }
        }

        await performRefresh()
    }

    /// Force refresh regardless of timing
    func forceRefresh() async {
        await performRefresh()
    }

    // MARK: - Private Methods

    private func performRefresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        DWLogger.shared.info("🔄 Starting background refresh...", category: .general)

        do {
            // Refresh all repositories in parallel
            async let storiesTask: Void = refreshStories()
            async let userStoriesTask: Void = refreshUserStories()
            async let transactionsTask: Void = refreshTransactions()

            _ = try await (storiesTask, userStoriesTask, transactionsTask)

            lastRefreshDate = Date()

            DWLogger.shared.info("✅ Background refresh completed successfully", category: .general)

        } catch {
            DWLogger.shared.error("Background refresh failed", error: error, category: .general)
        }
    }

    private func refreshStories() async throws {
        do {
            _ = try await storyRepository.getStories(forceRefresh: true)
            DWLogger.shared.debug("✅ Stories refreshed", category: .story)
        } catch {
            DWLogger.shared.error("Failed to refresh stories", error: error, category: .story)
            throw error
        }
    }

    private func refreshUserStories() async throws {
        do {
            _ = try await userStoryRepository.getStories(forceRefresh: true)
            DWLogger.shared.debug("✅ User stories refreshed", category: .story)
        } catch {
            DWLogger.shared.error("Failed to refresh user stories", error: error, category: .story)
            throw error
        }
    }

    private func refreshTransactions() async throws {
        do {
            _ = try await coinTransactionRepository.getTransactions(forceRefresh: true)
            DWLogger.shared.debug("✅ Transactions refreshed", category: .coin)
        } catch {
            DWLogger.shared.error("Failed to refresh transactions", error: error, category: .coin)
            throw error
        }
    }

    // MARK: - Manual Refresh Triggers

    /// Call after user creates new story
    func triggerUserStoryRefresh() async {
        do {
            _ = try await userStoryRepository.getStories(forceRefresh: true)
            DWLogger.shared.info("User stories refreshed after creation", category: .story)
        } catch {
            DWLogger.shared.error("Failed to refresh user stories", error: error, category: .story)
        }
    }

    /// Call after transaction (coin purchase, story creation, etc.)
    func triggerTransactionRefresh() async {
        do {
            _ = try await coinTransactionRepository.getTransactions(forceRefresh: true)
            DWLogger.shared.info("Transactions refreshed after change", category: .coin)
        } catch {
            DWLogger.shared.error("Failed to refresh transactions", error: error, category: .coin)
        }
    }
}

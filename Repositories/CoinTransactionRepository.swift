//
//  CoinTransactionRepository.swift
//  DreamSpire
//
//  Professional repository pattern for coin transactions
//  Implements intelligent caching for optimal performance
//

import Foundation
import Combine

/// Centralized repository for coin transactions with intelligent caching
@MainActor
final class CoinTransactionRepository: ObservableObject {

    // MARK: - Singleton

    static let shared = CoinTransactionRepository()

    // MARK: - Published Properties

    /// All cached transactions
    @Published private(set) var transactions: [CoinTransaction] = []

    /// Loading state
    @Published private(set) var isLoading = false

    /// Error state
    @Published private(set) var error: Error?

    // MARK: - Cache Management

    /// Memory cache
    private var cache: [CoinTransaction] = []

    /// Cache timestamp
    private var cacheTimestamp: Date?

    /// Cache duration (2 minutes - transactions change frequently)
    private let cacheDuration: TimeInterval = 2 * 60

    /// Active fetch task to prevent duplicate requests
    private var activeFetchTask: Task<[CoinTransaction], Error>?

    // MARK: - Initialization

    private init() {
        DWLogger.shared.info("CoinTransactionRepository initialized", category: .coin)
    }

    // MARK: - Public API

    /// Get transactions with intelligent caching
    /// - Parameter forceRefresh: Skip cache and fetch fresh data
    /// - Returns: Array of transactions
    func getTransactions(forceRefresh: Bool = false) async throws -> [CoinTransaction] {
        // Check if cache is valid and not forcing refresh
        if !forceRefresh, let cached = getCachedTransactions() {
            DWLogger.shared.debug("✅ Using cached transactions: \(cached.count)", category: .coin)
            return cached
        }

        // Check if there's already an active fetch
        if let activeTask = activeFetchTask {
            DWLogger.shared.debug("⏳ Reusing active fetch task", category: .coin)
            return try await activeTask.value
        }

        // Create new fetch task
        let task = Task<[CoinTransaction], Error> {
            DWLogger.shared.info("📡 Fetching fresh transactions from API", category: .coin)
            isLoading = true
            defer { isLoading = false }

            do {
                let fetchedTransactions = try await APIClient.shared.getCoinTransactions()

                // Update cache
                await MainActor.run {
                    self.cache = fetchedTransactions
                    self.cacheTimestamp = Date()
                    self.transactions = fetchedTransactions
                }

                DWLogger.shared.info("✅ Fetched \(fetchedTransactions.count) transactions, cache updated", category: .coin)
                return fetchedTransactions

            } catch {
                await MainActor.run {
                    self.error = error
                }
                DWLogger.shared.error("Failed to fetch transactions", error: error, category: .coin)
                throw error
            }
        }

        activeFetchTask = task

        do {
            let result = try await task.value
            activeFetchTask = nil
            return result
        } catch {
            activeFetchTask = nil
            throw error
        }
    }

    /// Add a new transaction to cache (optimistic update)
    func addTransaction(_ transaction: CoinTransaction) {
        cache.insert(transaction, at: 0)
        transactions = cache
        DWLogger.shared.debug("Transaction added to cache: \(transaction.id)", category: .coin)
    }

    /// Clear cache
    func clearCache() {
        cache = []
        cacheTimestamp = nil
        transactions = []
        DWLogger.shared.info("Cache cleared", category: .coin)
    }

    // MARK: - Private Helpers

    private func getCachedTransactions() -> [CoinTransaction]? {
        guard let timestamp = cacheTimestamp else {
            return nil
        }

        let age = Date().timeIntervalSince(timestamp)

        if age > cacheDuration {
            DWLogger.shared.debug("Cache expired (age: \(Int(age))s)", category: .coin)
            return nil
        }

        if cache.isEmpty {
            return nil
        }

        DWLogger.shared.debug("Cache valid (age: \(Int(age))s, count: \(cache.count))", category: .coin)
        return cache
    }
}

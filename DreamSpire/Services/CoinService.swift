//
//  CoinService.swift
//  DreamSpire
//
//  Handles coin balance and purchase operations
//

import Foundation
import Combine
import SwiftUI
import StoreKit

// MARK: - API Response Models

struct CoinBalanceAPIResponse: Codable {
    let success: Bool
    let data: CoinData
}

struct CoinData: Codable {
    let balance: Int
    let monthlyAllocation: Int?
    let lifetimeEarned: Int?
    let lifetimeSpent: Int?
}

public struct PurchaseVerificationResponse: Codable {
    public let success: Bool
    public let coins: Int
}

// MARK: - View Models

struct CoinBalanceModel {
    var balance: Int
    var monthlyAllocation: Int
    var coinsUsedThisMonth: Int
    var daysUntilRefill: Int
}

class CoinService: ObservableObject {
    static let shared = CoinService()

    // MARK: - Published Properties
    @Published var currentBalance: Int = 0
    @Published var coinBalance: CoinBalanceModel? // View uyumluluğu için
    @Published var isLoading: Bool = false
    private var loadingCount: Int = 0

    private let apiClient = APIClient.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Cache Management
    private var cachedBalance: Int?
    private var cacheTimestamp: Date?
    private let cacheDuration: TimeInterval = 2 * 60 // 2 minutes for coin balance
    private var activeFetchTask: Task<Int, Error>?

    private init() {
        setupNotificationListeners()
    }

    // MARK: - Notification Listeners

    private func setupNotificationListeners() {
        // Listen to subscription changes - force reload coins from backend
        NotificationCenter.default
            .publisher(for: .subscriptionDidChange)
            .sink { [weak self] _ in
                DWLogger.shared.info("🔔 Subscription changed - FORCE reloading coin balance from backend", category: .general)
                Task { [weak self] in
                    // ✅ CRITICAL: Force refresh to get new subscription coins
                    try? await self?.getCurrentBalance(forceRefresh: true)
                }
            }
            .store(in: &cancellables)

        DWLogger.shared.info("✅ CoinService notification listeners setup complete", category: .general)
    }
    
    // MARK: - Loading Helpers
    
    @MainActor
    private func incrementLoading() {
        loadingCount += 1
        isLoading = loadingCount > 0
    }
    
    @MainActor
    private func decrementLoading() {
        loadingCount = max(0, loadingCount - 1)
        isLoading = loadingCount > 0
    }
    
    @MainActor
    private func resetLoading() {
        loadingCount = 0
        isLoading = false
    }
    
    // MARK: - Fetch Balance (View Compatibility)
    func fetchBalance() async throws {
        _ = try await getCurrentBalance()
    }
    
    // MARK: - Get Current Balance
    @discardableResult
    func getCurrentBalance(forceRefresh: Bool = false) async throws -> Int {
        // Check if cache is valid and not forcing refresh
        if !forceRefresh, let cached = getCachedBalance() {
            DWLogger.shared.debug("✅ Using cached coin balance: \(cached)", category: .coin)
            return cached
        }

        // Check if there's already an active fetch
        if let existingTask = activeFetchTask {
            DWLogger.shared.debug("⏳ Joining existing coin balance fetch task", category: .coin)
            return try await existingTask.value
        }

        // Create new fetch task
        let fetchTask = Task<Int, Error> {
            await incrementLoading()
            defer {
                Task { @MainActor in
                    self.decrementLoading()
                }
            }
            DWLogger.shared.info("🌐 Fetching coin balance from backend", category: .coin)

            do {
                let response: CoinBalanceAPIResponse = try await apiClient.makeRequest(
                    endpoint: "/api/coins/balance",
                    method: .get,
                    requiresAuth: true
                )

                await MainActor.run {
                    let oldBalance = self.currentBalance
                    self.currentBalance = response.data.balance

                    self.coinBalance = CoinBalanceModel(
                        balance: response.data.balance,
                        monthlyAllocation: response.data.monthlyAllocation ?? 0,
                        coinsUsedThisMonth: 0,
                        daysUntilRefill: 0
                    )

                    // Update cache
                    self.cachedBalance = response.data.balance
                    self.cacheTimestamp = Date()

                    // Post notification if balance changed
                    if oldBalance != response.data.balance {
                        NotificationCenter.default.post(name: .coinBalanceDidChange, object: nil)
                    }
                }

                DWLogger.shared.info("✅ Coin balance fetched: \(response.data.balance)", category: .coin)

                return response.data.balance

            } catch {
                // The defer block handles decrementing loadingCount, so no need to set isLoading here.
                // await MainActor.run { self.isLoading = false } // Removed as defer handles it
                DWLogger.shared.error("❌ Failed to get coin balance", error: error, category: .coin)
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

    // MARK: - Cache Helper

    private func getCachedBalance() -> Int? {
        guard let cached = cachedBalance,
              let timestamp = cacheTimestamp,
              Date().timeIntervalSince(timestamp) < cacheDuration else {
            return nil
        }

        return cached
    }

    /// Clear cached balance (call on logout or when balance changes)
    func clearCache() {
        cachedBalance = nil
        cacheTimestamp = nil
        activeFetchTask?.cancel()
        activeFetchTask = nil
        currentBalance = 0
        coinBalance = nil
        DWLogger.shared.info("🗑️ Coin balance cache cleared", category: .coin)
    }
    
    // MARK: - Purchase Coins (Legacy / Manual)
    func purchaseCoins(packageId: String, transactionId: String) async throws {
        // Legacy implementation
    }
    
    // MARK: - Verify Purchase (StoreKit 2 JWT)
    func verifyPurchase(signedTransaction: String) async throws -> PurchaseVerificationResponse {
        DWLogger.shared.info("🔐 Verifying coin purchase with backend (JWT)", category: .general)
        
        struct VerifyRequest: Codable {
            let signedTransaction: String
        }
        
        do {
            let request = VerifyRequest(signedTransaction: signedTransaction)
            
            let response: PurchaseVerificationResponse = try await apiClient.makeRequest(
                endpoint: "/api/coins/purchase/verify",
                method: .post,
                body: request,
                requiresAuth: true
            )
            
            DWLogger.shared.info("✅ Coin purchase verified: +\(response.coins) coins", category: .general)
            
            // Refresh coin balance from backend
            await refreshBalance()
            
            return response
            
        } catch {
            DWLogger.shared.error("❌ Coin purchase verification failed", error: error, category: .general)
            throw error
        }
    }
    
    // MARK: - Refresh Balance
    func refreshBalance() async {
        do {
            // Force refresh to bypass cache
            let balance = try await getCurrentBalance(forceRefresh: true)
            await MainActor.run {
                self.currentBalance = balance
            }
            DWLogger.shared.info("✅ Coin balance refreshed: \(balance)", category: .general)
        } catch {
            DWLogger.shared.error("❌ Failed to refresh coin balance", error: error, category: .general)
        }
    }

    // MARK: - Update Balance Immediately
    /// Updates the coin balance immediately without fetching from backend
    /// Use this when you receive the new balance from another API response (e.g., after story creation)
    @MainActor
    func updateBalance(_ newBalance: Int) {
        let oldBalance = self.currentBalance
        self.currentBalance = newBalance

        // Update cache
        self.cachedBalance = newBalance
        self.cacheTimestamp = Date()

        // Update coinBalance model if exists
        if var model = self.coinBalance {
            model.balance = newBalance
            self.coinBalance = model
        }

        // Post notification if balance changed
        if oldBalance != newBalance {
            NotificationCenter.default.post(name: .coinBalanceDidChange, object: nil)
            DWLogger.shared.info("💰 Coin balance updated locally: \(oldBalance) → \(newBalance)", category: .coin)
        }
    }
    
    // MARK: - Cost Calculation
    func calculateCostLocal(duration: StoryDuration, addons: StoryAddons) -> Int {
        var cost = 0
        
        // Base cost from duration model
        cost += duration.baseCost
        
        // Addons cost
        cost += addons.totalCost(duration: duration)
        
        return cost
    }
}

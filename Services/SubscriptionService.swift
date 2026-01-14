//
//  SubscriptionService.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//

import Foundation
import StoreKit

// MARK: - Response Models

struct CheckoutSessionResponse: Codable {
    let url: String
}

class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()
    private let apiClient = APIClient.shared

    @Published var currentTier: SubscriptionTier = .free {
        didSet {
            UserDefaults.standard.set(currentTier.rawValue, forKey: "currentTier")
            DWLogger.shared.info("💎 Subscription tier updated to: \(currentTier.rawValue)", category: .subscription)
        }
    }
    @Published var subscription: Subscription?
    @Published var isLoading = false
    private var loadingCount = 0

    // MARK: - Cache Management
    private var cachedSubscription: Subscription?
    private var cacheTimestamp: Date?
    private let cacheDuration: TimeInterval = 3 * 60 // 3 minutes for subscription
    private var activeFetchTask: Task<Subscription, Error>?

    private init() {
        // Load cached tier first
        if let tierString = UserDefaults.standard.string(forKey: "currentTier"),
           let tier = SubscriptionTier(rawValue: tierString) {
            self.currentTier = tier
        }
        
        DWLogger.shared.info("SubscriptionService initialized with tier: \(currentTier.rawValue)", category: .subscription)

        // Load subscription on init
        Task {
            await loadSubscription()
        }
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
    
    // MARK: - Verify Subscription (StoreKit 2 JWT)
    
    func verifySubscription(signedTransaction: String) async throws -> VerifySubscriptionResponse {
        DWLogger.shared.info("🔐 Verifying subscription with backend (JWT)", category: .subscription)
        
        struct VerifyRequest: Codable {
            let signedTransaction: String
        }
        
        do {
            let request = VerifyRequest(signedTransaction: signedTransaction)
            
            let response: VerifySubscriptionResponse = try await apiClient.makeRequest(
                endpoint: "/api/subscriptions/verify",
                method: .post,
                body: request,
                requiresAuth: true
            )
            
            DWLogger.shared.info("✅ Subscription verified: \(response.tier) tier", category: .subscription)
            
            // Refresh subscription status from backend
            await refreshSubscription()
            
            // Post notification for other views to update
            NotificationCenter.default.post(name: .subscriptionDidChange, object: nil)
            
            // Reload coin balance as well (subscriptions give coins)
            await CoinService.shared.refreshBalance()
            
            return response
            
        } catch {
            DWLogger.shared.error("❌ Subscription verification failed", error: error, category: .subscription)
            throw error
        }
    }
    
    // MARK: - Refresh Subscription
    func refreshSubscription() async {
        // Force refresh to bypass cache
        await loadSubscription(forceRefresh: true)
    }
    
    // MARK: - Load Subscription

    func loadSubscription(forceRefresh: Bool = false) async {
        // Check if cache is valid and not forcing refresh
        if !forceRefresh, let cached = getCachedSubscription() {
            DWLogger.shared.debug("✅ Using cached subscription: \(cached.tier)", category: .subscription)
            await MainActor.run {
                self.subscription = cached
                self.currentTier = cached.tier
            }
            return
        }

        // Check if there's already an active fetch
        if let existingTask = activeFetchTask {
            DWLogger.shared.debug("⏳ Joining existing subscription fetch task", category: .subscription)
            do {
                let sub = try await existingTask.value
                await MainActor.run {
                    self.subscription = sub
                    self.currentTier = sub.tier
                }
            } catch {
                DWLogger.shared.error("Failed to join subscription fetch", error: error, category: .subscription)
            }
            return
        }

        // Create new fetch task
        let fetchTask = Task<Subscription, Error> {
            DWLogger.shared.info("🌐 Fetching subscription from backend", category: .subscription)

            await incrementLoading()
            defer { 
                Task { @MainActor in
                    self.decrementLoading()
                }
            }

            do {
                let sub = try await apiClient.getSubscription()

                await MainActor.run {
                    self.subscription = sub
                    self.currentTier = sub.tier

                    // Update cache
                    self.cachedSubscription = sub
                    self.cacheTimestamp = Date()
                }

                let limitText = sub.usage.storiesLimit.map { String($0) } ?? "∞"
                DWLogger.shared.logSubscriptionEvent(
                    "Subscription Loaded",
                    tier: sub.tier.rawValue,
                    details: "Status: \(sub.status.rawValue), Stories: \(sub.usage.storiesThisMonth)/\(limitText)"
                )

                return sub

            } catch {
                DWLogger.shared.error("Failed to load subscription", error: error, category: .subscription)
                throw error
            }
        }

        activeFetchTask = fetchTask

        do {
            _ = try await fetchTask.value
            activeFetchTask = nil
        } catch {
            activeFetchTask = nil
        }
    }

    // MARK: - Cache Helper

    private func getCachedSubscription() -> Subscription? {
        guard let cached = cachedSubscription,
              let timestamp = cacheTimestamp,
              Date().timeIntervalSince(timestamp) < cacheDuration else {
            return nil
        }

        return cached
    }

    /// Clear cached subscription (call on logout or when subscription changes)
    func clearCache() {
        cachedSubscription = nil
        cacheTimestamp = nil
        activeFetchTask?.cancel()
        activeFetchTask = nil
        currentTier = .free
        subscription = nil
        DWLogger.shared.info("🗑️ Subscription cache cleared", category: .subscription)
    }
    
    // MARK: - Feature Gates
    
    func canCreateStory() -> (allowed: Bool, reason: String?) {
        guard let usage = subscription?.usage else {
            return (false, "Abonelik bilgisi yüklenemedi")
        }
        
        if currentTier == .free {
            if let limit = usage.storiesLimit, usage.storiesThisMonth >= limit {
                return (false, "Aylık hikaye limitinize ulaştınız. Plus'a yükseltin!")
            }
        }
        
        return (true, nil)
    }
    
    func canAddCharacter(currentCount: Int) -> (allowed: Bool, reason: String?) {
        let maxChars = currentTier.maxCharactersPerStory
        
        if currentCount >= maxChars {
            let nextTier = currentTier == .free ? "Plus" : "Pro"
            return (false, "\(nextTier)'a yükselterek daha fazla karakter ekleyin")
        }
        
        return (true, nil)
    }
    
    func canSaveCharacter(currentCount: Int) -> (allowed: Bool, reason: String?) {
        if currentTier == .free {
            return (false, "Karakter kaydetmek için Plus'a yükseltin")
        }
        
        if let maxSaved = currentTier.maxSavedCharacters {
            if currentCount >= maxSaved {
                return (false, "Kayıtlı karakter limitinize ulaştınız. Pro'ya yükseltin!")
            }
        }
        
        return (true, nil)
    }
    
    func canAccessIllustrations() -> (allowed: Bool, reason: String?) {
        if !currentTier.canAccessIllustrations {
            return (false, "İllüstrasyonlar Pro üyelerine özeldir")
        }
        return (true, nil)
    }
    
    func canAccessPremiumVoices() -> (allowed: Bool, reason: String?) {
        if !currentTier.canAccessPremiumVoices {
            return (false, "Premium sesler Pro üyelerine özeldir")
        }
        return (true, nil)
    }
    
    // MARK: - Upgrade
    
    func createCheckoutSession(tier: SubscriptionTier) async throws -> String {
        DWLogger.shared.info("Creating checkout session for: \(tier.displayName)", category: .subscription)
        
        do {
            let response: CheckoutSessionResponse = try await apiClient.makeRequest(
                endpoint: Constants.API.Endpoints.checkout,
                method: .post,
                body: ["tier": tier.rawValue]
            )
            
            DWLogger.shared.logSubscriptionEvent(
                "Checkout Session Created",
                tier: tier.rawValue,
                details: "URL: \(response.url)"
            )
            
            return response.url
        } catch {
            DWLogger.shared.error("Failed to create checkout session", error: error, category: .subscription)
            throw error
        }
    }
    
    // MARK: - Usage Tracking
    
    func incrementStoryUsage() async {
        guard var sub = subscription else { return }
        
        sub.usage = SubscriptionUsage(
            storiesThisMonth: sub.usage.storiesThisMonth + 1,
            storiesLimit: sub.usage.storiesLimit,
            storiesThisMonthCount: sub.usage.storiesThisMonthCount,
            lastResetDate: sub.usage.lastResetDate
        )
        
        await MainActor.run {
            self.subscription = sub
        }
        
        let limitText = sub.usage.storiesLimit.map { String($0) } ?? "∞"
        DWLogger.shared.info("Story usage incremented: \(sub.usage.storiesThisMonth)/\(limitText)", category: .subscription)
    }
    
    // MARK: - Helper Methods
    
    func requiresUpgrade(for feature: Feature) -> Bool {
        switch feature {
        case .illustrations:
            return !currentTier.canAccessIllustrations
        case .premiumVoices:
            return !currentTier.canAccessPremiumVoices
        case .saveCharacters:
            return currentTier == .free
        case .unlimitedStories:
            return currentTier == .free
        }
    }
    
    enum Feature {
        case illustrations
        case premiumVoices
        case saveCharacters
        case unlimitedStories
    }
}

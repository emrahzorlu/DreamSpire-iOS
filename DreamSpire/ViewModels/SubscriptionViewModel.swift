//
//  SubscriptionViewModel.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025-11-02.
//

import Foundation
import StoreKit
import Combine

@MainActor
class SubscriptionViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var currentTier: SubscriptionTier = .free
    @Published var subscription: Subscription?
    @Published var isLoading: Bool = false
    private var loadingCount: Int = 0
    private var isSubscribing: Bool = false
    @Published var error: String?
    @Published var successMessage: String?
    
    // Products (for Apple IAP)
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    
    // Usage Stats
    @Published var storiesThisMonth: Int = 0
    @Published var storiesLimit: Int? = 3
    @Published var remainingStories: Int? = 3
    
    // Billing Period Selection (default to monthly)
    @Published var selectedBillingPeriod: BillingPeriod = .monthly
    
    // MARK: - Dependencies
    
    private let apiClient = APIClient.shared
    private let storeKitService = StoreKitService.shared
    private var cancellables = Set<AnyCancellable>()
    private var updateListenerTask: Task<Void, Error>?
    
    // MARK: - Product IDs (✅ Real Product IDs from App Store Connect)

    private let productIDs = [
        "com.emrahzorlu.DreamSpire.plus.monthly",
        "com.emrahzorlu.DreamSpire.pro.monthly",
        "com.emrahzorlu.DreamSpire.subscription.plus.yearly",
        "com.emrahzorlu.DreamSpire.subscription.pro.yearly"
    ]
    
    // MARK: - Initialization
    
    init() {
        updateListenerTask = listenForTransactions()
        
        // Sync with SubscriptionService source of truth
        SubscriptionService.shared.$currentTier
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentTier)
            
        SubscriptionService.shared.$subscription
            .receive(on: DispatchQueue.main)
            .assign(to: &$subscription)
        
        Task {
            await loadProducts()
            await loadSubscription()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Loading Helpers
    
    private func incrementLoading() {
        loadingCount += 1
        isLoading = loadingCount > 0
    }
    
    private func decrementLoading() {
        loadingCount = max(0, loadingCount - 1)
        isLoading = loadingCount > 0
    }
    
    private func resetLoading() {
        loadingCount = 0
        isLoading = false
    }

    // MARK: - Settings Persistence handled by SubscriptionService
    
    // MARK: - Subscription Loading
    
    func loadSubscription() async {
        // Skip if already subscribing to avoid conflicts
        if isSubscribing {
            DWLogger.shared.debug("⏭️ Skipping loadSubscription - purchase in progress", category: .subscription)
            return
        }
        
        incrementLoading()
        defer { decrementLoading() }
        
        do {
            // Add timeout to prevent permanent hang
            try await withTimeout(seconds: 15) {
                // Let SubscriptionService handle the update
                await SubscriptionService.shared.loadSubscription(forceRefresh: true)
            }
            
            // Usage stats from updated subscription info
            if let usage = SubscriptionService.shared.subscription?.usage {
                storiesThisMonth = usage.storiesThisMonth
                storiesLimit = usage.storiesLimit
                
                if let limit = storiesLimit {
                    remainingStories = max(0, limit - storiesThisMonth)
                } else {
                    remainingStories = nil // Unlimited
                }
            }
            
            DWLogger.shared.info("Subscription VM synced with service: \(currentTier.displayName)", category: .subscription)
        } catch {
            self.error = "Abonelik bilgisi yüklenemedi"
            DWLogger.shared.error("Subscription loading error", error: error, category: .subscription)
        }
    }
    
    // MARK: - Apple IAP - Load Products
    
    func loadProducts() async {
        incrementLoading()
        defer { decrementLoading() }
        
        do {
            // Add timeout for product loading
            let storeProducts = try await withTimeout(seconds: 20) {
                try await Product.products(for: self.productIDs)
            }
            
            products = storeProducts.sorted { $0.price < $1.price }
            
            DWLogger.shared.info("✅ Loaded \(products.count) subscription products", category: .subscription)
            
            for product in products {
                DWLogger.shared.debug(
                    "Product: \(product.id) - \(product.displayName) - \(product.displayPrice)",
                    category: .subscription
                )
            }
            
        } catch {
            self.error = "Abonelik paketleri yüklenemedi"
            DWLogger.shared.error("Failed to load subscription products", error: error, category: .subscription)
        }
    }
    
    // MARK: - Apple IAP - Purchase Subscription
    
    // Track the tier being purchased (for verification)
    private var purchasingTier: SubscriptionTier?
    
    func subscribe(tier: SubscriptionTier, period: BillingPeriod? = nil) async {
        // Prevent concurrent subscriptions
        if isSubscribing {
            DWLogger.shared.warning("⚠️ Already subscribing, ignoring request", category: .subscription)
            return
        }
        
        // Use passed period or fall back to selected period
        let billingPeriod = period ?? selectedBillingPeriod
        
        // Find the product for this tier and period
        let productId = productIdForTier(tier, period: billingPeriod)
        guard let product = products.first(where: { $0.id == productId }) else {
            error = "Abonelik paketi bulunamadı"
            DWLogger.shared.error("Product not found for tier: \(tier.rawValue), period: \(billingPeriod.rawValue)", category: .subscription)
            return
        }
        
        isSubscribing = true
        incrementLoading()
        defer { 
            isSubscribing = false
            decrementLoading() 
        }
        
        // Track which tier we're purchasing
        purchasingTier = tier
        
        DWLogger.shared.info("🛒 Starting subscription purchase: \(product.displayName) for tier: \(tier.rawValue)", category: .subscription)
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                DWLogger.shared.info("✅ Purchase successful", category: .subscription)
                
                // Verify the transaction
                let transaction = try checkVerified(verification)
                
                // Verify with backend with timeout
                try await withTimeout(seconds: 30) {
                    try await self.verifySubscriptionWithBackend(transaction)
                }
                
                // Finish the transaction
                await transaction.finish()
                
                // Clear purchasing tier
                purchasingTier = nil
                
                DWLogger.shared.info("✅ Transaction finished: \(transaction.id)", category: .subscription)
                
                // Reload subscription from backend
                await loadSubscription()

                // Success message will be set by backend verification

                DWLogger.shared.logAnalyticsEvent("subscription_purchased", parameters: [
                    "product_id": product.id,
                    "tier": tier.rawValue
                ])
                
            case .userCancelled:
                DWLogger.shared.info("User cancelled subscription purchase", category: .subscription)
                
            case .pending:
                error = "Ödeme beklemede. Lütfen daha sonra kontrol edin."
                DWLogger.shared.info("Subscription purchase pending", category: .subscription)
                
            @unknown default:
                DWLogger.shared.warning("Unknown purchase result", category: .subscription)
            }
            
        } catch let storeError as StoreError {
            switch storeError {
            case .failedVerification:
                error = "Abonelik doğrulaması başarısız"
                DWLogger.shared.error("Subscription verification failed", category: .subscription)
            }
            
        } catch {
            self.error = "Abonelik başlatılamadı: \(error.localizedDescription)"
            DWLogger.shared.error("Subscription purchase failed", error: error, category: .subscription)
        }
    }
    
    // MARK: - Backend Verification

    private func verifySubscriptionWithBackend(_ transaction: Transaction) async throws {
        DWLogger.shared.info("🔐 Verifying subscription with backend: \(transaction.id)", category: .subscription)
        DWLogger.shared.info("🛒 Transaction productID: \(transaction.productID)", category: .subscription)

        // WORKAROUND: In test mode, use the tier we're purchasing instead of transaction productID
        // because StoreKit Sandbox sometimes returns wrong productID
        let effectiveProductId: String
        if let tier = purchasingTier {
            effectiveProductId = productIdForTier(tier)
            DWLogger.shared.info("⚠️ Using purchasingTier override: \(tier.rawValue) -> \(effectiveProductId)", category: .subscription)
        } else {
            effectiveProductId = transaction.productID
        }
        
        do {
            // Get receipt if available (optional for sandbox)
            var receiptString: String? = nil
            if let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
               let receiptData = try? Data(contentsOf: appStoreReceiptURL) {
                receiptString = receiptData.base64EncodedString()
            }
            
            // Send to backend for verification
            let request = VerifySubscriptionRequest(
                transactionId: String(transaction.id),
                productId: effectiveProductId,  // Use effective productId
                receipt: receiptString
            )
            
            let response = try await apiClient.verifySubscription(request)

            // Unwrap subscription or use tier from response
            guard let subscription = response.subscription else {
                // Fallback to tier from response if subscription object not provided
                let tier = SubscriptionTier(rawValue: response.tier) ?? .free
                SubscriptionService.shared.currentTier = tier

                DWLogger.shared.info(
                    "✅ Backend verification successful: \(tier) subscription activated",
                    category: .subscription
                )

                // ✅ CRITICAL: Force refresh coin balance from backend (bypass cache!)
                do {
                    _ = try await CoinService.shared.getCurrentBalance(forceRefresh: true)
                    DWLogger.shared.info("✅ Coin balance FORCE REFRESHED after subscription (fallback)", category: .subscription)
                } catch {
                    DWLogger.shared.error("⚠️ Failed to load coin balance after subscription", error: error, category: .subscription)
                }

                await MainActor.run {
                    // Post notification for UI to update
                    NotificationCenter.default.post(name: .subscriptionDidChange, object: nil)

                    successMessage = "\(tier.displayName) aboneliği başarıyla aktifleştirildi!"
                }
                return
            }

            DWLogger.shared.info(
                "✅ Backend verification successful: \(subscription.tier) subscription activated",
                category: .subscription
            )

            // Update shared service tier
            SubscriptionService.shared.currentTier = subscription.tier

            // ✅ CRITICAL: Force refresh coin balance from backend (bypass cache!)
            do {
                _ = try await CoinService.shared.getCurrentBalance(forceRefresh: true)
                DWLogger.shared.info("✅ Coin balance FORCE REFRESHED after subscription verification", category: .subscription)
            } catch {
                DWLogger.shared.error("⚠️ Failed to load coin balance after subscription", error: error, category: .subscription)
            }

            // Post notification for other views to update
            await MainActor.run {
                NotificationCenter.default.post(name: .subscriptionDidChange, object: nil)
            }

            // Show success message
            await MainActor.run {
                successMessage = "\(subscription.tier.displayName) aboneliği başarıyla aktifleştirildi!"
            }
            
        } catch {
            DWLogger.shared.error("Backend subscription verification failed", error: error, category: .subscription)
            throw error
        }
    }
    
    // MARK: - Transaction Listener
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            guard let self = self else { return }
            
            for await result in Transaction.updates {
                do {
                    // SKIP if we are already in the middle of a subscribe() call
                    // This listener also receives updates for the current purchase flow
                    if await MainActor.run(body: { self.isSubscribing }) {
                        DWLogger.shared.debug("⏭️ Skipping transaction listener update - subscribe() is already context handling", category: .subscription)
                        continue
                    }

                    let transaction = try await self.checkVerified(result)
                    
                    DWLogger.shared.info(
                        "📱 Subscription transaction update received: \(transaction.id)",
                        category: .subscription
                    )
                    
                    // Only reload subscription state - verification is done in purchase method
                    // This prevents duplicate backend calls
                    await self.loadSubscription()
                    
                    // Finish the transaction
                    await transaction.finish()
                    
                    DWLogger.shared.info(
                        "✅ Transaction finished and subscription reloaded: \(transaction.id)",
                        category: .subscription
                    )
                    
                } catch {
                    DWLogger.shared.error(
                        "Failed to process subscription transaction update",
                        error: error,
                        category: .subscription
                    )
                }
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async {
        incrementLoading()
        defer { decrementLoading() }

        DWLogger.shared.info("🔄 Restoring subscription purchases", category: .subscription)

        do {
            try await AppStore.sync()
            await loadSubscription()
            successMessage = "restore_success_message".localized

            DWLogger.shared.logUserAction("Subscription Purchases Restored")
        } catch {
            self.error = "restore_error_message".localized
            DWLogger.shared.error("Restore subscription purchases error", error: error, category: .subscription)
        }
    }
    
    // MARK: - Helper Methods

    func productIdForTier(_ tier: SubscriptionTier, period: BillingPeriod = .monthly) -> String {
        switch (tier, period) {
        case (.free, _):
            return ""
        case (.plus, .monthly):
            return "com.emrahzorlu.DreamSpire.plus.monthly"
        case (.plus, .yearly):
            return "com.emrahzorlu.DreamSpire.subscription.plus.yearly"
        case (.pro, .monthly):
            return "com.emrahzorlu.DreamSpire.pro.monthly"
        case (.pro, .yearly):
            return "com.emrahzorlu.DreamSpire.subscription.pro.yearly"
        }
    }
    
    func getProductForTier(_ tier: SubscriptionTier, period: BillingPeriod? = nil) -> Product? {
        let billingPeriod = period ?? selectedBillingPeriod
        let productId = productIdForTier(tier, period: billingPeriod)
        return products.first { $0.id == productId }
    }
    
    func getLocalizedPrice(for tier: SubscriptionTier, period: BillingPeriod? = nil) -> String? {
        getProductForTier(tier, period: period)?.displayPrice
    }
    
    // MARK: - Feature Gates
    
    func canAccessFeature(_ feature: Feature) -> Bool {
        switch feature {
        case .illustratedStories:
            return currentTier == .pro
        case .premiumVoices:
            return currentTier == .pro
        case .saveCharacters:
            return currentTier != .free
        case .unlimitedStories:
            return currentTier != .free
        case .pdfExport:
            return currentTier != .free
        }
    }
    
    func getRequiredTier(for feature: Feature) -> SubscriptionTier {
        switch feature {
        case .illustratedStories, .premiumVoices:
            return .pro
        case .saveCharacters, .unlimitedStories, .pdfExport:
            return .plus
        }
    }
    
    func getUpgradeMessage(for feature: Feature) -> String {
        let requiredTier = getRequiredTier(for: feature)
        return "\(requiredTier.displayName) aboneliğine yükseltin"
    }
    
    // MARK: - Usage Checks
    
    func canCreateStory() -> (canCreate: Bool, message: String?) {
        // Pro and Plus have unlimited stories
        if currentTier == .plus || currentTier == .pro {
            return (true, nil)
        }
        
        // Free tier has limits
        guard let remaining = remainingStories else {
            return (true, nil)
        }
        
        if remaining > 0 {
            return (true, "Bu ay \(remaining) hikaye hakkınız kaldı")
        } else {
            return (false, "Aylık hikaye limitiniz doldu. Plus'a yükseltin!")
        }
    }
    
    func canAddCharacter(currentCount: Int) -> (canAdd: Bool, message: String?) {
        let maxAllowed = currentTier.maxCharactersPerStory
        
        if currentCount < maxAllowed {
            return (true, nil)
        } else {
            let nextTier: SubscriptionTier = currentTier == .free ? .plus : .pro
            return (false, "\(nextTier.displayName) ile \(nextTier.maxCharactersPerStory) karakter ekleyebilirsiniz")
        }
    }
    
    func canSaveCharacter(currentCount: Int) -> (canSave: Bool, message: String?) {
        guard currentTier != .free else {
            return (false, "Plus veya Pro aboneliğiyle karakter kaydedebilirsiniz")
        }
        
        if let maxSaved = currentTier.maxSavedCharacters {
            if currentCount < maxSaved {
                return (true, nil)
            } else {
                return (false, "Maksimum \(maxSaved) karakter kaydedebilirsiniz. Pro ile sınırsız!")
            }
        } else {
            return (true, nil) // Unlimited
        }
    }
    
    // MARK: - Tier Comparison
    
    func getAllTiers() -> [SubscriptionTier] {
        return [.free, .plus, .pro]
    }
    
    func getTierFeatures(_ tier: SubscriptionTier) -> [String] {
        return tier.features
    }
    
    func getTierPrice(_ tier: SubscriptionTier) -> String {
        if tier == .free {
            return "subscription_free".localized
        }
        
        // Try to get real price from StoreKit
        if let product = getProductForTier(tier) {
            return product.displayPrice
        }
        
        // Fallback to locale-aware currency
        let formatted = tier.fallbackMonthlyPrice.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
        return "\(formatted)/\("paywall_per_month".localized.replacingOccurrences(of: "/", with: "").trimmingCharacters(in: .whitespaces))"
    }
    
    // MARK: - Timeout Helper
    
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw URLError(.timedOut)
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

// MARK: - Supporting Types

enum Feature {
    case illustratedStories
    case premiumVoices
    case saveCharacters
    case unlimitedStories
    case pdfExport

    var displayName: String {
        switch self {
        case .illustratedStories:
            return "İllüstrasyonlu Hikayeler"
        case .premiumVoices:
            return "Premium Sesler"
        case .saveCharacters:
            return "Karakter Kaydetme"
        case .unlimitedStories:
            return "Sınırsız Hikaye"
        case .pdfExport:
            return "PDF Dışa Aktarma"
        }
    }
}

// MARK: - Billing Period

enum BillingPeriod: String, CaseIterable {
    case monthly
    case yearly
    
    var displayName: String {
        switch self {
        case .monthly: return "paywall_monthly".localized
        case .yearly: return "paywall_yearly".localized
        }
    }
    
    var savingsBadge: String? {
        switch self {
        case .monthly: return nil
        case .yearly: return "paywall_yearly_savings".localized  // "2 ay bedava"
        }
    }
}

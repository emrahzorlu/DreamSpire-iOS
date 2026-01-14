//
//  StoreKitService.swift
//  DreamSpire
//
//  Created by DreamSpire Team on 11/7/24.
//

import Foundation
import StoreKit
import Combine

/// Service for managing Apple In-App Purchases (StoreKit 2)
@MainActor
class StoreKitService: ObservableObject {
    static let shared = StoreKitService()
    
    @Published var products: [Product] = []
    @Published var purchasedProductIDs = Set<String>()
    @Published var isPurchasing = false
    @Published var error: String?
    
    private let coinService = CoinService.shared
    private var updateListenerTask: Task<Void, Error>?
    
    // REAL Product IDs from App Store Connect (✅ Updated to match .storekit file)
    private let productIDs = [
        // Consumable Coin Packages
        "com.emrahzorlu.DreamSpire.coins.starter",     // 500 coins
        "com.emrahzorlu.DreamSpire.coins.basic2",      // 1,200 coins
        "com.emrahzorlu.DreamSpire.coins.popular",     // 2,500 coins
        "com.emrahzorlu.DreamSpire.coins.mega",        // 5,500 coins
        "com.emrahzorlu.DreamSpire.coins.ultimate",    // 12,000 coins

        // Auto-Renewable Subscriptions (Monthly)
        "com.emrahzorlu.DreamSpire.plus.monthly",      // Plus Monthly
        "com.emrahzorlu.DreamSpire.pro.monthly",       // Pro Monthly

        // Auto-Renewable Subscriptions (Yearly)
        "com.emrahzorlu.DreamSpire.subscription.plus.yearly",  // Plus Yearly
        "com.emrahzorlu.DreamSpire.subscription.pro.yearly"    // Pro Yearly
    ]
    
    private init() {
        DWLogger.shared.info("🛍️ StoreKitService initialized", category: .app)
        
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()
        
        // Load products on init
        Task {
            await loadProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Load Products
    
    /// Load products from App Store
    func loadProducts() async {
        DWLogger.shared.info("📦 Loading products from App Store...", category: .app)
        
        do {
            let storeProducts = try await Product.products(for: productIDs)
            
            self.products = storeProducts.sorted { product1, product2 in
                // Sort by price (ascending)
                return product1.price < product2.price
            }
            
            DWLogger.shared.info("✅ Loaded \(storeProducts.count) products", category: .app)
            
            // Log product details
            for product in storeProducts {
                DWLogger.shared.debug(
                    "Product: \(product.id) - \(product.displayName) - \(product.displayPrice)",
                    category: .app
                )
            }
            
        } catch {
            self.error = "Failed to load products: \(error.localizedDescription)"
            DWLogger.shared.error("Failed to load products", error: error, category: .app)
        }
    }
    
    // MARK: - Purchase
    
    /// Purchase a product
    func purchase(_ product: Product) async throws {
        DWLogger.shared.info("🛒 Initiating purchase: \(product.id)", category: .app)
        
        guard !isPurchasing else {
            DWLogger.shared.warning("Purchase already in progress", category: .app)
            return
        }
        
        isPurchasing = true
        error = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                DWLogger.shared.info("✅ Purchase successful", category: .app)
                
                // Verify the transaction locally
                let transaction = try checkVerified(verification)
                
                // Verify with backend (using signed JWT)
                try await verifyWithBackend(verification)
                
                // Finish the transaction
                await transaction.finish()
                
                DWLogger.shared.info("✅ Transaction finished: \(transaction.id)", category: .app)
                
                isPurchasing = false
                
            case .userCancelled:
                DWLogger.shared.info("User cancelled purchase", category: .app)
                isPurchasing = false
                
            case .pending:
                DWLogger.shared.info("Purchase pending approval", category: .app)
                error = "Purchase pending approval"
                isPurchasing = false
                
            @unknown default:
                DWLogger.shared.warning("Unknown purchase result", category: .app)
                isPurchasing = false
            }
            
        } catch StoreError.failedVerification {
            error = "Purchase verification failed"
            isPurchasing = false
            DWLogger.shared.error("Purchase verification failed", category: .app)
            throw StoreError.failedVerification
            
        } catch {
            self.error = error.localizedDescription
            isPurchasing = false
            DWLogger.shared.error("Purchase failed", error: error, category: .app)
            throw error
        }
    }
    
    // MARK: - Transaction Verification
    
    /// Verify transaction with Apple
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            DWLogger.shared.error("Transaction failed verification", category: .app)
            throw StoreError.failedVerification
        case .verified(let safe):
            DWLogger.shared.info("✅ Transaction verified by Apple", category: .app)
            return safe
        }
    }
    
    /// Verify transaction with backend (StoreKit 2 JWT)
    private func verifyWithBackend(_ verification: VerificationResult<Transaction>) async throws {
        let transaction = try checkVerified(verification)
        DWLogger.shared.info("🔐 Verifying with backend (JWT): \(transaction.id)", category: .app)
        
        do {
            // Check if this is a subscription or coin purchase
            // Monthly: .plus.monthly, .pro.monthly
            // Yearly: subscription.plus.yearly, subscription.pro.yearly
            let isSubscription = transaction.productID.contains("subscription") ||
                                 transaction.productID.contains(".plus.") ||
                                 transaction.productID.contains(".pro.")
            
            if isSubscription {
                // This is a subscription - use subscription verification
                let _ = try await SubscriptionService.shared.verifySubscription(signedTransaction: verification.jwsRepresentation)
                
                DWLogger.shared.info(
                    "✅ Subscription verification successful",
                    category: .app
                )
            } else {
                // This is a coin purchase - use coin verification
                let response = try await coinService.verifyPurchase(signedTransaction: verification.jwsRepresentation)
                
                DWLogger.shared.info(
                    "✅ Coin purchase verified: +\(response.coins) coins",
                    category: .app
                )
            }
            
            // Update purchased products
            purchasedProductIDs.insert(transaction.productID)
            
        } catch {
            DWLogger.shared.error("Backend verification failed", error: error, category: .app)
            throw error
        }
    }
    
    // MARK: - Transaction Listener
    
    /// Listen for transaction updates
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    // Try to verify locally first
                    let transaction = try await self.checkVerified(result)
                    
                    DWLogger.shared.info(
                        "📱 Transaction update received: \(transaction.id)",
                        category: .app
                    )
                    
                    // Skip subscription verification here - SubscriptionViewModel handles it
                    if transaction.productID.contains("subscription") {
                        DWLogger.shared.info(
                            "⏭️ Skipping subscription verification in StoreKitService - handled by SubscriptionViewModel",
                            category: .app
                        )
                        await transaction.finish()
                        continue
                    }
                    
                    // Verify with backend (passing the VerificationResult to get JWS)
                    try await self.verifyWithBackend(result)
                    
                    // Finish the transaction
                    await transaction.finish()
                    
                } catch {
                    DWLogger.shared.error(
                        "Failed to process transaction update",
                        error: error,
                        category: .app
                    )
                }
            }
        }
    }
    
    // MARK: - Restore Purchases
    
    /// Restore purchases (for debugging, consumables can't be restored)
    func restorePurchases() async {
        DWLogger.shared.info("🔄 Restoring purchases...", category: .app)
        
        do {
            try await AppStore.sync()
            DWLogger.shared.info("✅ Purchases restored", category: .app)
        } catch {
            self.error = "Failed to restore purchases"
            DWLogger.shared.error("Failed to restore purchases", error: error, category: .app)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Get product by ID
    func product(for id: String) -> Product? {
        return products.first { $0.id == id }
    }
    
    /// Check if product is purchased (for consumables, always false)
    func isPurchased(_ productID: String) -> Bool {
        return purchasedProductIDs.contains(productID)
    }
    
    /// Get coin package info for a product
    func coinPackage(for product: Product) -> CoinPackage? {
        return CoinPackage.package(for: product.id)
    }
}

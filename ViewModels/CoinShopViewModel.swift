//
//  CoinShopViewModel.swift
//  DreamSpire
//
//  Handles coin shop business logic, IAP, and backend integration
//  Real Apple IAP + Backend Verification
//

import Foundation
import StoreKit
import Combine

@MainActor
class CoinShopViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var currentBalance: Int = 0
    @Published var packages: [CoinPackage] = []
    @Published var selectedPackage: CoinPackage?
    @Published var isPurchasing: Bool = false
    @Published var error: String?
    @Published var successMessage: String?

    // Products
    @Published var products: [Product] = []

    // MARK: - Dependencies
    private let coinService = CoinService.shared
    var onDismiss: (() -> Void)?
    private var cancellables = Set<AnyCancellable>()
    private var updateListenerTask: Task<Void, Error>?
    
    // MARK: - Initialization
    init() {
        setupPackages()
        updateListenerTask = listenForTransactions()

        // Initialize with cached balance immediately to avoid showing 0
        currentBalance = coinService.coinBalance?.balance ?? 0

        Task {
            await loadProducts()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Setup
    private func setupPackages() {
        // Use predefined packages from CoinPackage model
        packages = CoinPackage.allPackages
    }
    
    // MARK: - Load Current Balance
    func loadCurrentBalance() async {
        do {
            currentBalance = try await coinService.getCurrentBalance()
        } catch {
            print("❌ Failed to load balance: \(error)")
            self.error = "Bakiye yüklenemedi"
        }
    }
    
    // MARK: - Select Package
    func selectPackage(_ package: CoinPackage) {
        selectedPackage = package
    }
    
    // MARK: - Load Products
    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: CoinPackage.allPackages.map { $0.productId })

            products = storeProducts.sorted { $0.price < $1.price }

            // Map StoreKit products to CoinPackage
            packages = CoinPackage.allPackages.compactMap { package in
                var mutablePackage = package
                mutablePackage.storeKitProduct = storeProducts.first { $0.id == package.productId }
                return mutablePackage
            }

            DWLogger.shared.info("✅ Loaded \(products.count) coin products", category: .general)

        } catch {
            DWLogger.shared.error("Failed to load coin products", error: error, category: .general)
            self.error = "Coin paketleri yüklenemedi"
        }
    }

    // MARK: - Purchase (Real IAP)
    func purchaseSelectedPackage() async {
        guard let package = selectedPackage else { return }

        // Find product
        guard let product = products.first(where: { $0.id == package.productId }) else {
            error = "Paket bulunamadı"
            DWLogger.shared.error("Product not found for package: \(package.productId)", category: .general)
            return
        }

        isPurchasing = true
        defer { isPurchasing = false }

        DWLogger.shared.info("🛒 Starting coin purchase: \(product.displayName)", category: .general)

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                DWLogger.shared.info("✅ Purchase successful", category: .general)

                // Verify transaction locally
                let transaction = try checkVerified(verification)

                // Verify with backend
                try await verifyPurchaseWithBackend(verification, package: package)

                // Finish transaction
                await transaction.finish()

                DWLogger.shared.info("✅ Transaction finished: \(transaction.id)", category: .general)

                // Reload balance
                await loadCurrentBalance()

                // Clear selection
                selectedPackage = nil

                // Set success message (will trigger GlassAlert in View)
                successMessage = String(format: "coin_purchase_success_message".localized, package.coins)

                // Dismiss sheet after showing alert
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds delay
                    self.onDismiss?()
                }

                DWLogger.shared.logAnalyticsEvent("coin_purchased", parameters: [
                    "product_id": product.id,
                    "coins": package.coins
                ])

            case .userCancelled:
                DWLogger.shared.info("User cancelled coin purchase", category: .general)

            case .pending:
                error = "Ödeme beklemede"
                DWLogger.shared.info("Coin purchase pending", category: .general)

            @unknown default:
                DWLogger.shared.warning("Unknown purchase result", category: .general)
            }

        } catch let storeError as StoreError {
            switch storeError {
            case .failedVerification:
                error = "Doğrulama başarısız"
                DWLogger.shared.error("Coin purchase verification failed", category: .general)
                GlassAlertManager.shared.error(
                    "coin_purchase_error".localized,
                    message: "coin_purchase_verification_failed".localized
                )
            }

        } catch {
            self.error = "Satın alma başarısız: \(error.localizedDescription)"
            DWLogger.shared.error("Coin purchase failed", error: error, category: .general)
            GlassAlertManager.shared.error(
                "coin_purchase_error".localized,
                message: error.localizedDescription
            )
        }
    }

    // MARK: - Backend Verification
    private func verifyPurchaseWithBackend(_ verification: VerificationResult<Transaction>, package: CoinPackage) async throws {
        let transaction = try checkVerified(verification)
        DWLogger.shared.info("🔐 Verifying coin purchase with backend: \(transaction.id)", category: .general)

        let response = try await coinService.verifyPurchase(signedTransaction: verification.jwsRepresentation)

        DWLogger.shared.info(
            "✅ Backend verification successful: +\(response.coins) coins",
            category: .general
        )

        // Refresh balance from backend after successful purchase
        await coinService.refreshBalance()
        currentBalance = coinService.currentBalance
    }

    // MARK: - Transaction Listener
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { return }

                do {
                    let transaction = try await self.checkVerified(result)

                    DWLogger.shared.info(
                        "📱 Coin transaction update received: \(transaction.id)",
                        category: .general
                    )

                    // Reload balance
                    await self.loadCurrentBalance()

                    // Finish transaction
                    await transaction.finish()

                    DWLogger.shared.info(
                        "✅ Transaction finished and balance reloaded: \(transaction.id)",
                        category: .general
                    )

                } catch {
                    DWLogger.shared.error(
                        "Failed to process coin transaction update",
                        error: error,
                        category: .general
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
        isPurchasing = true
        defer { isPurchasing = false }
        
        DWLogger.shared.info("🔄 Restoring coin purchases", category: .coin)
        
        do {
            // StoreKit 2: Request fresh synchronization
            try await AppStore.sync()
            
            // Refresh balance from backend
            await loadCurrentBalance()
            
            DWLogger.shared.info("✅ Purchases restored and balance updated", category: .coin)
            
            // Success alert
            GlassAlertManager.shared.success(
                "Geri Yükleme Başarılı",
                message: "Satın alımlarınız kontrol edildi ve bakiyeniz güncellendi."
            )
            
        } catch {
            DWLogger.shared.error("❌ Restore failed", error: error, category: .coin)
            self.error = "Geri yükleme başarısız: \(error.localizedDescription)"
            
            GlassAlertManager.shared.error(
                "Geri Yükleme Hatası",
                message: error.localizedDescription
            )
        }
    }
}

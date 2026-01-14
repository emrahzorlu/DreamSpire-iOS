//
//  CoinBalanceView.swift
//  DreamSpire
//
//  Updated: Subscription-first approach with reactive updates
//

import SwiftUI

struct CoinBalanceView: View {
    @ObservedObject var coinService = CoinService.shared
    @ObservedObject var subscriptionService = SubscriptionService.shared
    @State private var showPaywall = false
    @State private var showCoinShop = false
    
    var body: some View {
        Button(action: {
            handleCoinTap()
        }) {
            HStack(spacing: 6) {
                CoinIconView(size: 20)
                
                if let balance = coinService.coinBalance {
                    Text("\(balance.balance)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                } else {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.2))
            .cornerRadius(20)
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView()
        }
        .fullScreenCover(isPresented: $showCoinShop) {
            CoinShopView()
        }
        .onAppear {
            Task {
                try? await coinService.fetchBalance()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .coinBalanceDidChange)) { _ in
            DWLogger.shared.info("🔔 CoinBalance: coinBalanceDidChange received", category: .coin)
            // CoinService @Published property already updated, SwiftUI will rerender
        }
        .onReceive(NotificationCenter.default.publisher(for: .subscriptionDidChange)) { _ in
            DWLogger.shared.info("🔔 CoinBalance: subscriptionDidChange received - refreshing", category: .coin)
            Task {
                await subscriptionService.refreshSubscription()
                try? await coinService.fetchBalance()
            }
        }
        .onChange(of: showPaywall) { _, isShowing in
            if !isShowing {
                // Paywall kapandığında durumu yenile
                Task {
                    await subscriptionService.refreshSubscription()
                    try? await coinService.fetchBalance()
                }
            }
        }
        .onChange(of: showCoinShop) { _, isShowing in
            if !isShowing {
                // CoinShop kapandığında coin durumunu yenile
                Task {
                    try? await coinService.fetchBalance()
                }
            }
        }
    }
    
    // MARK: - Handle Coin Tap
    
    private func handleCoinTap() {
        // ✅ Use currentTier directly - it's always up-to-date
        let tier = subscriptionService.currentTier
        
        DWLogger.shared.info("🪙 Coin icon tapped - User tier: \(tier.rawValue), currentTier: \(subscriptionService.currentTier.rawValue)", category: .app)
        
        switch tier {
        case .free:
            // Free user → Show Paywall to encourage subscription
            DWLogger.shared.info("→ Showing Paywall for Free user", category: .app)
            showPaywall = true
            
        case .plus, .pro:
            // Plus/Pro user → Show Coin Shop directly
            DWLogger.shared.info("→ Showing Coin Shop for \(tier.displayName) user", category: .app)
            showCoinShop = true
        }
    }
}

#Preview {
    CoinBalanceView()
}

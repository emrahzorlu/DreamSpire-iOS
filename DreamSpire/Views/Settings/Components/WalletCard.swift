//
//  WalletCard.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025.
//

import SwiftUI

/// Wallet card showing coin balance and subscription tier
struct WalletCard: View {
    let coinBalance: Int
    let tier: SubscriptionTier
    var isLoading: Bool = false
    var onBuyCoins: () -> Void
    var onUpgrade: () -> Void
    var onTransactionHistory: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            // Coin Row
            HStack {
                Button(action: {
                    onTransactionHistory?()
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("subscription_coin_balance".localized)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white.opacity(0.7))

                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                                    .frame(height: 33)
                            } else {
                                Text("\(coinBalance)")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            CoinIconView(size: 24)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .contentShape(Rectangle())
                .disabled(onTransactionHistory == nil)

                Spacer()

                Button(action: onBuyCoins) {
                    Text("subscription_load".localized)
                        .font(.footnote.bold())
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .cornerRadius(20)
                }
                .buttonStyle(PlainButtonStyle())
            }

            Divider().background(Color.white.opacity(0.3))

            // Subscription Row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("subscription_membership".localized)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.7))

                    HStack(spacing: 6) {
                        Image(systemName: tier == .pro ? "crown.fill" : "star.fill")
                            .foregroundColor(tier == .pro ? .yellow : .orange)
                        Text(tier.displayName)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }

                Spacer()

                if tier != .pro {
                    Button(action: onUpgrade) {
                        Text("subscription_upgrade".localized)
                            .font(.footnote.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.purple)
                            .cornerRadius(20)
                    }
                }
            }

            // Transaction History Button
            if let onTransactionHistory = onTransactionHistory {
                Button(action: onTransactionHistory) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 14))
                        Text("coins_history".localized)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                .contentShape(Rectangle())
                .padding(.top, 4)
            }
        }
        .padding(20)
        .background(
            Color.white.opacity(0.15)
                .overlay(Color.white.opacity(0.05))
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
        )
        .accessibilityLabel("Cüzdan: \(coinBalance) coin, \(tier.displayName) üyelik")
    }
}

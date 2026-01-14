//
//  CoinServiceProtocol.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025.
//

import Foundation
import Combine

/// Protocol for coin-related operations
/// Enables testing with mock services
@MainActor
protocol CoinServiceProtocol: ObservableObject {
    
    // Published properties
    var balance: Int { get }
    var isLoading: Bool { get }
    var error: String? { get }
    
    // Balance operations
    func fetchBalance() async
    func refreshBalance() async
    
    // Cost calculation
    func calculateCost(
        duration: StoryDuration,
        addons: StoryAddons,
        isSubscriber: Bool
    ) -> Int
    
    // Spending
    func spendCoins(amount: Int, reason: String) async throws
    
    // Purchase verification
    func verifyPurchase(productId: String, transactionId: String) async throws
}

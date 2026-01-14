//
//  SubscriptionServiceProtocol.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025.
//

import Foundation
import Combine

/// Subscription tier levels
enum SubscriptionTier: String, Codable {
    case free = "free"
    case plus = "plus"
    case pro = "pro"
}

/// Protocol for subscription-related operations
@MainActor
protocol SubscriptionServiceProtocol: ObservableObject {
    
    // Current subscription state
    var currentTier: SubscriptionTier { get }
    var isSubscribed: Bool { get }
    var expirationDate: Date? { get }
    
    // Feature access
    func canAccess(feature: String) -> Bool
    func getMonthlyCoins() -> Int
    
    // Subscription operations
    func fetchSubscriptionStatus() async
    func verifySubscription(productId: String, transactionId: String) async throws
    func restorePurchases() async throws
}

//
//  MockCoinService.swift
//  DreamSpireTests
//
//  Created by Emrah Zorlu on 2025.
//

import Foundation
@testable import DreamSpire

/// Mock coin service for unit testing
@MainActor
class MockCoinService: ObservableObject {
    
    // Test configuration
    var mockBalance: Int = 500
    var shouldFailFetch: Bool = false
    var shouldFailSpend: Bool = false
    
    // Track method calls for verification
    var fetchBalanceCallCount = 0
    var spendCoinsCallCount = 0
    var lastSpendAmount: Int?
    var lastSpendReason: String?
    
    // Published properties
    @Published var balance: Int = 500
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    func fetchBalance() async {
        fetchBalanceCallCount += 1
        
        if shouldFailFetch {
            error = "Mock fetch error"
            return
        }
        
        balance = mockBalance
    }
    
    func refreshBalance() async {
        await fetchBalance()
    }
    
    func spendCoins(amount: Int, reason: String) async throws {
        spendCoinsCallCount += 1
        lastSpendAmount = amount
        lastSpendReason = reason
        
        if shouldFailSpend {
            throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock spend error"])
        }
        
        if amount > balance {
            throw NSError(domain: "MockError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Insufficient coins"])
        }
        
        balance -= amount
    }
    
    func calculateCost(duration: StoryDuration, addons: StoryAddons, isSubscriber: Bool) -> Int {
        // Simple mock calculation
        var cost = duration.baseCost
        if addons.includeIllustrations { cost += 20 }
        if addons.includeAudio { cost += 10 }
        if isSubscriber { cost = Int(Double(cost) * 0.8) }
        return cost
    }
    
    // Reset for clean test state
    func reset() {
        mockBalance = 500
        balance = 500
        shouldFailFetch = false
        shouldFailSpend = false
        fetchBalanceCallCount = 0
        spendCoinsCallCount = 0
        lastSpendAmount = nil
        lastSpendReason = nil
        error = nil
        isLoading = false
    }
}

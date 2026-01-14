//
//  CoinBalance.swift
//  DreamSpire
//
//  Created by DreamSpire Team on 11/7/24.
//

import Foundation

/// User's coin balance information
struct CoinBalance: Codable {
    let balance: Int
    let monthlyAllocation: Int
    let lastRefillDate: Date?
    let rolloverBalance: Int
    let lifetimeEarned: Int
    let lifetimeSpent: Int
    
    enum CodingKeys: String, CodingKey {
        case balance
        case monthlyAllocation
        case lastRefillDate
        case rolloverBalance
        case lifetimeEarned
        case lifetimeSpent
    }
    
    // Firestore Timestamp to Date conversion
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        balance = try container.decode(Int.self, forKey: .balance)
        monthlyAllocation = try container.decode(Int.self, forKey: .monthlyAllocation)
        rolloverBalance = try container.decode(Int.self, forKey: .rolloverBalance)
        lifetimeEarned = try container.decode(Int.self, forKey: .lifetimeEarned)
        lifetimeSpent = try container.decode(Int.self, forKey: .lifetimeSpent)
        
        // Handle Firestore Timestamp
        if let timestamp = try? container.decode([String: Double].self, forKey: .lastRefillDate),
           let seconds = timestamp["_seconds"] {
            lastRefillDate = Date(timeIntervalSince1970: seconds)
        } else {
            lastRefillDate = nil
        }
    }
    
    // For encoding (if needed)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(balance, forKey: .balance)
        try container.encode(monthlyAllocation, forKey: .monthlyAllocation)
        try container.encode(rolloverBalance, forKey: .rolloverBalance)
        try container.encode(lifetimeEarned, forKey: .lifetimeEarned)
        try container.encode(lifetimeSpent, forKey: .lifetimeSpent)
        
        if let date = lastRefillDate {
            let timestamp = ["_seconds": date.timeIntervalSince1970]
            try container.encode(timestamp, forKey: .lastRefillDate)
        }
    }
    
    // Manual initializer for testing
    init(
        balance: Int,
        monthlyAllocation: Int,
        lastRefillDate: Date?,
        rolloverBalance: Int,
        lifetimeEarned: Int,
        lifetimeSpent: Int
    ) {
        self.balance = balance
        self.monthlyAllocation = monthlyAllocation
        self.lastRefillDate = lastRefillDate
        self.rolloverBalance = rolloverBalance
        self.lifetimeEarned = lifetimeEarned
        self.lifetimeSpent = lifetimeSpent
    }
    
    /// Days until next refill
    var daysUntilRefill: Int? {
        guard let lastRefill = lastRefillDate else { return nil }
        let nextRefill = Calendar.current.date(byAdding: .month, value: 1, to: lastRefill) ?? lastRefill
        let days = Calendar.current.dateComponents([.day], from: Date(), to: nextRefill).day ?? 0
        return max(0, days)
    }
    
    /// Coins used this month
    var coinsUsedThisMonth: Int {
        return monthlyAllocation + rolloverBalance - balance
    }
}

/// Response from coin balance API
struct CoinBalanceResponse: Codable {
    let success: Bool
    let balance: Int
    let data: CoinBalance
}

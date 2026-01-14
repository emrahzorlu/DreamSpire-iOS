//
//  CoinTransaction.swift
//  DreamSpire
//
//  Created by DreamSpire Team on 11/7/24.
//

import Foundation
import SwiftUI

/// Coin transaction record
struct CoinTransaction: Codable, Identifiable {
    let id: String
    let type: TransactionType
    let amount: Int
    let reason: String
    let timestamp: Date
    let storyId: String?
    let breakdown: CoinBreakdown?
    
    enum TransactionType: String, Codable {
        case spent
        case earned
        case purchased
        case refunded
        
        var displayName: String {
            switch self {
            case .spent: return "Spent"
            case .earned: return "Earned"
            case .purchased: return "Purchased"
            case .refunded: return "Refunded"
            }
        }
        
        var icon: String {
            switch self {
            case .spent: return "arrow.down.circle.fill"
            case .earned: return "arrow.up.circle.fill"
            case .purchased: return "creditcard.fill"
            case .refunded: return "arrow.uturn.backward.circle.fill"
            }
        }
        
        var color: String {
            switch self {
            case .spent: return "red"
            case .earned: return "green"
            case .purchased: return "blue"
            case .refunded: return "orange"
            }
        }

        var swiftUIColor: Color {
            switch self {
            case .spent: return .red
            case .earned: return .green
            case .purchased: return .blue
            case .refunded: return .orange
            }
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case amount
        case reason
        case timestamp
        case storyId
        case breakdown
    }
    
    // Firestore Timestamp to Date conversion
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(TransactionType.self, forKey: .type)
        amount = try container.decode(Int.self, forKey: .amount)
        reason = try container.decode(String.self, forKey: .reason)
        storyId = try? container.decode(String.self, forKey: .storyId)
        breakdown = try? container.decode(CoinBreakdown.self, forKey: .breakdown)
        
        // Handle Firestore Timestamp
        if let timestampDict = try? container.decode([String: Double].self, forKey: .timestamp),
           let seconds = timestampDict["_seconds"] {
            timestamp = Date(timeIntervalSince1970: seconds)
        } else if let date = try? container.decode(Date.self, forKey: .timestamp) {
            timestamp = date
        } else {
            timestamp = Date()
        }
    }
    
    // Manual initializer
    init(
        id: String,
        type: TransactionType,
        amount: Int,
        reason: String,
        timestamp: Date,
        storyId: String? = nil,
        breakdown: CoinBreakdown? = nil
    ) {
        self.id = id
        self.type = type
        self.amount = amount
        self.reason = reason
        self.timestamp = timestamp
        self.storyId = storyId
        self.breakdown = breakdown
    }
    
    /// Display amount with sign
    var displayAmount: String {
        let sign = type == .spent ? "-" : "+"
        return "\(sign)\(abs(amount))"
    }
    
    /// Formatted date
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    /// Relative date (e.g., "2 hours ago")
    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        // Use app locale instead of system locale
        let langCode = LocalizationManager.shared.currentLanguage.rawValue
        formatter.locale = Locale(identifier: langCode)
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
    
    /// User-friendly display name for the transaction reason
    var displayReason: String {
        // Map raw reason strings to localized user-friendly names
        switch reason.lowercased() {
        case "story_creation":
            return "transaction_reason_story_creation".localized
        case "apple_purchase":
            return "transaction_reason_purchase".localized
        case "refund", _ where reason.lowercased().hasPrefix("refund"):
            return "transaction_reason_refund".localized
        case "daily_reward":
            return "transaction_reason_daily_reward".localized
        case "welcome_gift":
            return "transaction_reason_welcome_gift".localized
        case "subscription":
            return "transaction_reason_subscription".localized
        case "subscription_started":
            return "transaction_reason_subscription_started".localized
        case "bonus":
            return "transaction_reason_bonus".localized
        case "subscription_coins_fix":
            return "transaction_reason_subscription_coins".localized
        case "account_created":
            return "transaction_reason_account_created".localized
        case "monthly_refill", "monthly-refill":
            return "transaction_reason_monthly_refill".localized
        case "subscription_renewal":
            return "transaction_reason_subscription_renewal".localized
        case "subscription_upgrade":
            return "transaction_reason_subscription_upgrade".localized
        case "welcome_bonus":
            return "transaction_reason_welcome_bonus".localized
        case "guest_account_linked", "guest_account_merged":
            return "transaction_reason_guest_account_linked".localized
        case "account_created_no_coins_abuse_prevention":
            return "transaction_reason_account_created_no_coins_abuse_prevention".localized
        case "account_created_transaction_error":
            return "transaction_reason_account_created_transaction_error".localized
        case "account_initialization_fix", "account_initialization_fix_middleware":
            return "transaction_reason_account_sync".localized
        case "subscription_verified":
            return "transaction_reason_subscription_verified".localized
        case "abuse_prevention_device_used":
            return "transaction_reason_abuse_prevention".localized
        default:
            // If no mapping found, return the raw reason (shouldn't happen in production)
            DWLogger.shared.warning("Unknown transaction reason: \(reason)", category: .coin)
            return reason
        }
    }
}

/// Coin cost breakdown
struct CoinBreakdown: Codable {
    let text: Int?
    let cover: Int?
    let audio: Int?
    let illustrated: Int?
    
    var total: Int {
        return (text ?? 0) + (cover ?? 0) + (audio ?? 0) + (illustrated ?? 0)
    }
    
    var components: [(String, Int)] {
        var result: [(String, Int)] = []
        if let text = text { result.append(("Text", text)) }
        if let cover = cover { result.append(("Cover", cover)) }
        if let audio = audio { result.append(("Audio", audio)) }
        if let illustrated = illustrated { result.append(("Illustrated", illustrated)) }
        return result
    }
}

/// Response from transactions API
struct CoinTransactionsResponse: Codable {
    let success: Bool
    let data: [CoinTransaction]
}

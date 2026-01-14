//
//  Subscription.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//

import Foundation

// MARK: - Firebase Timestamp Helper
struct FirebaseTimestamp: Codable {
    let _seconds: Int
    let _nanoseconds: Int
    
    var date: Date {
        return Date(timeIntervalSince1970: TimeInterval(_seconds))
    }
}

// MARK: - Subscription
struct Subscription: Codable {
    let userId: String
    let tier: SubscriptionTier
    let status: SubscriptionStatus
    
    // Optional - may not exist for free tier
    let amount: Double?
    let currency: String?
    let interval: SubscriptionInterval?
    let currentPeriodStart: FirebaseTimestamp?
    let currentPeriodEnd: FirebaseTimestamp?
    let productId: String?  // Apple product ID
    let expiresAt: FirebaseTimestamp?  // Subscription expiration
    
    var usage: SubscriptionUsage
    let createdAt: FirebaseTimestamp?
    let updatedAt: FirebaseTimestamp?
}

// MARK: - Subscription Usage
struct SubscriptionUsage: Codable {
    let storiesThisMonth: Int
    let storiesLimit: Int?
    let storiesThisMonthCount: Int?  // Backend sometimes sends this
    let lastResetDate: FirebaseTimestamp
    
    enum CodingKeys: String, CodingKey {
        case storiesThisMonth
        case storiesLimit
        case storiesThisMonthCount
        case lastResetDate
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try both keys for stories count
        if let count = try? container.decode(Int.self, forKey: .storiesThisMonth) {
            storiesThisMonth = count
        } else if let count = try? container.decode(Int.self, forKey: .storiesThisMonthCount) {
            storiesThisMonth = count
        } else {
            storiesThisMonth = 0
        }
        
        storiesLimit = try? container.decodeIfPresent(Int.self, forKey: .storiesLimit)
        storiesThisMonthCount = try? container.decodeIfPresent(Int.self, forKey: .storiesThisMonthCount)
        lastResetDate = try container.decode(FirebaseTimestamp.self, forKey: .lastResetDate)
    }
    
    init(storiesThisMonth: Int, storiesLimit: Int?, storiesThisMonthCount: Int?, lastResetDate: FirebaseTimestamp) {
        self.storiesThisMonth = storiesThisMonth
        self.storiesLimit = storiesLimit
        self.storiesThisMonthCount = storiesThisMonthCount
        self.lastResetDate = lastResetDate
    }
}

// MARK: - Subscription Tier
enum SubscriptionTier: String, Codable {
    case free
    case plus
    case pro
    
    var displayName: String {
        switch self {
        case .free: return "subscription_free".localized
        case .plus: return "Plus"
        case .pro: return "Pro"
        }
    }
    
    var icon: String {
        switch self {
        case .free: return "🆓"
        case .plus: return "💎"
        case .pro: return "👑"
        }
    }
    
    // Removed hardcoded prices - now using StoreKit Product prices
    // These are only used as fallbacks in case StoreKit fails
    var fallbackMonthlyPrice: Double {
        switch self {
        case .free: return 0
        case .plus: return 9.99
        case .pro: return 17.99
        }
    }

    var fallbackYearlyPrice: Double {
        switch self {
        case .free: return 0
        case .plus: return 79.99   // ~$6.67/month - 33% savings
        case .pro: return 143.99   // ~$12/month - 33% savings
        }
    }

    // Product IDs for StoreKit
    func productId(for period: SubscriptionInterval) -> String {
        switch self {
        case .free:
            return "" // Free has no product
        case .plus:
            return period == .month
                ? "com.emrahzorlu.DreamSpire.plus.monthly"
                : "com.emrahzorlu.DreamSpire.subscription.plus.yearly"
        case .pro:
            return period == .month
                ? "com.emrahzorlu.DreamSpire.pro.monthly"
                : "com.emrahzorlu.DreamSpire.subscription.pro.yearly"
        }
    }
    
    // Feature gates
    var storiesPerMonth: Int? {
        switch self {
        case .free: return 3
        case .plus, .pro: return nil  // Unlimited
        }
    }
    
    var maxCharactersPerStory: Int {
        switch self {
        case .free: return 2
        case .plus: return 4
        case .pro: return 6
        }
    }
    
    var maxSavedCharacters: Int? {
        switch self {
        case .free: return nil  // Cannot save
        case .plus: return 10
        case .pro: return nil   // Unlimited
        }
    }
    
    var canAccessIllustrations: Bool {
        return self == .pro
    }
    
    var canAccessPremiumVoices: Bool {
        return self == .pro
    }
    
    var features: [String] {
        switch self {
        case .free:
            return [
                "Ayda 3 hikaye",
                "Hikaye başına 2 karakter",
                "15 hazır hikaye",
                "Standart ses",
                "Kapak görseli"
            ]
        case .plus:
            return [
                "Sınırsız hikaye",
                "Hikaye başına 4 karakter",
                "50 hazır hikaye",
                "10 karakter kaydet",
                "PDF dışa aktarma"
            ]
        case .pro:
            return [
                "Plus'taki her şey",
                "Hikaye başına 6 karakter",
                "İllüstrasyonlu hikayeler (4+ resim)",
                "Premium sesler",
                "Tüm hazır hikayeler",
                "Sınırsız karakter kaydı"
            ]
        }
    }
}

enum SubscriptionStatus: String, Codable {
    case active
    case inactive  // Free tier users
    case canceled
    case expired
    case pastDue = "past_due"
    case trial
    
    var displayName: String {
        switch self {
        case .active: return "subscription_status_active".localized
        case .inactive: return "subscription_status_inactive".localized
        case .canceled: return "subscription_status_canceled".localized
        case .expired: return "subscription_status_expired".localized
        case .pastDue: return "subscription_status_past_due".localized
        case .trial: return "subscription_status_trial".localized
        }
    }
}

enum SubscriptionInterval: String, Codable {
    case month
    case year
    
    var displayName: String {
        switch self {
        case .month: return "subscription_interval_month".localized
        case .year: return "subscription_interval_year".localized
        }
    }
}

// MARK: - Subscription Verification

struct VerifySubscriptionRequest: Codable {
    let transactionId: String
    let productId: String
    let receipt: String?
    
    init(transactionId: String, productId: String, receipt: String? = nil) {
        self.transactionId = transactionId
        self.productId = productId
        self.receipt = receipt
    }
}

struct VerifySubscriptionResponse: Codable {
    let success: Bool
    let tier: String
    let expiresAt: String?
    
    // Legacy support
    let subscription: Subscription?
    let message: String?
}

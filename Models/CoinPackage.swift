//
//  CoinPackage.swift
//  DreamSpire
//
//  Created by DreamSpire Team on 11/7/24.
//

import Foundation
import StoreKit

/// Coin package for purchase
struct CoinPackage: Identifiable {
    let id: String
    let coins: Int
    let price: Double // Fallback price
    let discount: Double
    let badge: String?
    let productId: String

    // StoreKit Product for localized pricing
    var storeKitProduct: Product?

    // NEW: Icon name for asset images
    var iconName: String {
        switch coins {
        case 0..<1000: return "CoinIcon"              // starter: 500
        case 1000..<2000: return "coin_small"         // basic: 1200
        case 2000..<4000: return "coin_bag_little"    // popular: 2500
        case 4000..<10000: return "coin_bag_medium"   // mega: 5500
        case 10000..<20000: return "coin_treasure_chest"   // ultimate: 12000
        default: return "coin_treasure_chest"              // future packages
        }
    }

    var priceString: String {
        // Use StoreKit product price if available
        if let product = storeKitProduct {
            return product.displayPrice
        }

        // Fallback to locale-aware currency
        return price.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }
    
    var storiesApprox: String {
        let stories = coins / 255 // Based on standard story with cover + audio
        return "~\(stories) hikaye"
    }
    
    // NEW: Alias for compatibility
    var valueDescription: String {
        return storiesApprox
    }
    
    // NEW: Discount as percentage Int
    var discountPercent: Int {
        return Int(discount * 100)
    }
    
    var discountString: String {
        guard discount > 0 else { return "" }
        let percentage = Int(discount * 100)
        return "\(percentage)% Off"
    }
    
    var isPopular: Bool {
        return badge?.contains("POPULAR") ?? false
    }
    
    var isBestValue: Bool {
        return badge?.contains("BEST VALUE") ?? false
    }
    
    /// ✅ UPDATED: Real Product IDs from App Store Connect
    static let starter = CoinPackage(
        id: "starter",
        coins: 500,
        price: 2.99,
        discount: 0,
        badge: nil,
        productId: "com.emrahzorlu.DreamSpire.coins.starter"
    )
    
    static let basic = CoinPackage(
        id: "basic",
        coins: 1200,
        price: 5.99,
        discount: 0.17,
        badge: nil,
        productId: "com.emrahzorlu.DreamSpire.coins.basic2"
    )
    
    static let popular = CoinPackage(
        id: "popular",
        coins: 2500,
        price: 9.99,
        discount: 0.33,
        badge: "coin_badge_popular".localized,
        productId: "com.emrahzorlu.DreamSpire.coins.popular"
    )
    
    static let mega = CoinPackage(
        id: "mega",
        coins: 5500,
        price: 17.99,
        discount: 0.45,
        badge: "coin_badge_best_value".localized,
        productId: "com.emrahzorlu.DreamSpire.coins.mega"
    )
    
    static let ultimate = CoinPackage(
        id: "ultimate",
        coins: 12000,
        price: 29.99,
        discount: 0.58,
        badge: nil,
        productId: "com.emrahzorlu.DreamSpire.coins.ultimate"
    )
    
    static let allPackages: [CoinPackage] = [
        starter, basic, popular, mega, ultimate
    ]
    
    /// Get package by product ID
    static func package(for productId: String) -> CoinPackage? {
        return allPackages.first { $0.productId == productId }
    }
}

/// API response for coin packages
struct CoinPackagesResponse: Codable {
    let success: Bool
    let data: PackagesData
    
    struct PackagesData: Codable {
        let tier: String
        let packages: [PackageInfo]
    }
    
    struct PackageInfo: Codable {
        let id: String
        let coins: Int
        let price: Double
        let discount: Double
        let badge: String?
        let name: String
        let description: String
    }
}

/// API response for products (Apple Product IDs)
struct CoinProductsResponse: Codable {
    let success: Bool
    let data: ProductsData
    
    struct ProductsData: Codable {
        let tier: String
        let products: [ProductInfo]
    }
    
    struct ProductInfo: Codable {
        let productId: String
        let packageId: String
        let coins: Int
        let name: String
        let description: String
        let badge: String?
        let discount: Double
    }
}

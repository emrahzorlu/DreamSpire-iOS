//
//  AppReviewManager.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025-12-31.
//

import Foundation
import StoreKit
import SwiftUI

class AppReviewManager {
    static let shared = AppReviewManager()
    
    private let minimumStoriesForReview = 1
    private let reviewRequestKey = "lastReviewRequestDate"
    private let storyCountKey = "totalStoriesGeneratedCount"
    
    private init() {}
    
    /// Increments the count of stories generated and requests a review if conditions are met
    func requestReviewIfAppropriate() {
        // Increment story count
        let currentCount = UserDefaults.standard.integer(forKey: storyCountKey)
        let newCount = currentCount + 1
        UserDefaults.standard.set(newCount, forKey: storyCountKey)

        DWLogger.shared.info("📊 Story generated. Total count: \(newCount) (minimum required: \(minimumStoriesForReview))", category: .app)

        // Conditions for review:
        // 1. User has generated at least N stories
        // 2. We haven't asked too recently (Apple handles this, but we can add our own buffer)

        guard newCount >= minimumStoriesForReview else {
            DWLogger.shared.debug("⏭️ Skipping review request - not enough stories yet (\(newCount)/\(minimumStoriesForReview))", category: .app)
            return
        }

        DWLogger.shared.info("✅ Requesting app review (story count: \(newCount))", category: .app)

        // Request review
        requestReview()
    }
    
    private func requestReview() {
        DWLogger.shared.info("⏳ Scheduling app review request in 2 seconds...", category: .app)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else {
                DWLogger.shared.warning("⚠️ AppReviewManager deallocated before review request", category: .app)
                return
            }

            // Find active scene
            let activeScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene

            if let scene = activeScene {
                DWLogger.shared.info("📱 Found active scene, requesting review...", category: .app)
                SKStoreReviewController.requestReview(in: scene)
                UserDefaults.standard.set(Date(), forKey: self.reviewRequestKey)
                DWLogger.shared.info("✅ App Review Requested Successfully", category: .app)
                DWLogger.shared.info("ℹ️ Note: Review dialog may not appear due to Apple's rate limiting (max 3 times per year, debug/TestFlight builds may not show it)", category: .app)
            } else {
                DWLogger.shared.warning("⚠️ No active foreground scene found - review request skipped", category: .app)
                DWLogger.shared.debug("Connected scenes: \(UIApplication.shared.connectedScenes.map { "\($0.activationState.rawValue)" }.joined(separator: ", "))", category: .app)
            }
        }
    }

    // MARK: - Testing & Debug

    /// Force shows the review dialog immediately (for testing purposes)
    func forceShowReview() {
        DWLogger.shared.info("🧪 [TEST] Force showing review dialog", category: .app)

        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
            DWLogger.shared.info("✅ [TEST] App Review Dialog Requested", category: .app)
            DWLogger.shared.info("ℹ️ Note: Dialog may not appear in debug/TestFlight builds or if you've seen it 3+ times this year", category: .app)
        } else {
            DWLogger.shared.warning("⚠️ [TEST] No active scene found", category: .app)
        }
    }

    /// Resets the story count (for testing purposes)
    func resetStoryCount() {
        UserDefaults.standard.set(0, forKey: storyCountKey)
        UserDefaults.standard.removeObject(forKey: reviewRequestKey)
        DWLogger.shared.info("🧪 [TEST] Story count reset to 0", category: .app)
    }

    /// Gets current story count (for debugging)
    func getCurrentStoryCount() -> Int {
        return UserDefaults.standard.integer(forKey: storyCountKey)
    }
}

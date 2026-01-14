//
//  AnalyticsManager.swift
//  DreamSpire
//
//  Professional Analytics Tracking System
//

import Foundation
import FirebaseAnalytics

/// Comprehensive analytics manager for tracking all user interactions and business metrics
final class AnalyticsManager {
    static let shared = AnalyticsManager()
    
    private init() {}
    
    // MARK: - User Lifecycle Events
    
    /// Track user signup with detailed method and source
    func trackUserSignUp(method: AuthMethod, source: String? = nil) {
        var parameters: [String: Any] = [
            "method": method.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ]
        if let source = source {
            parameters["source"] = source
        }
        logEvent("user_signed_up", parameters: parameters)
    }
    
    /// Track user login
    func trackUserSignIn(method: AuthMethod) {
        logEvent("user_signed_in", parameters: [
            "method": method.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Track user logout
    func trackUserSignOut() {
        logEvent("user_signed_out", parameters: [
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Track onboarding completion
    func trackOnboardingCompleted(stepsCompleted: Int, timeSpent: TimeInterval) {
        logEvent("onboarding_completed", parameters: [
            "steps_completed": stepsCompleted,
            "time_spent_seconds": Int(timeSpent),
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Story Creation Events
    
    /// Track story creation start
    func trackStoryCreationStarted(type: StoryCreationType) {
        logEvent("story_creation_started", parameters: [
            "type": type.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Track story creation completion with full details
    func trackStoryCreated(
        storyId: String,
        type: StoryCreationType,
        genre: String,
        tone: String,
        ageRange: String,
        duration: Int,
        characterCount: Int,
        hasAudio: Bool,
        hasImages: Bool,
        language: String,
        timeSpent: TimeInterval,
        coinsSpent: Int
    ) {
        logEvent("story_created", parameters: [
            "story_id": storyId,
            "type": type.rawValue,
            "genre": genre,
            "tone": tone,
            "age_range": ageRange,
            "duration_minutes": duration,
            "character_count": characterCount,
            "has_audio": hasAudio,
            "has_images": hasImages,
            "language": language,
            "time_spent_seconds": Int(timeSpent),
            "coins_spent": coinsSpent,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Track story creation failure
    func trackStoryCreationFailed(
        type: StoryCreationType,
        errorCode: String,
        errorMessage: String,
        step: String
    ) {
        logEvent("story_creation_failed", parameters: [
            "type": type.rawValue,
            "error_code": errorCode,
            "error_message": errorMessage,
            "failed_at_step": step,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Track story creation abandoned
    func trackStoryCreationAbandoned(
        step: String,
        timeSpent: TimeInterval,
        charactersAdded: Int
    ) {
        logEvent("story_creation_abandoned", parameters: [
            "abandoned_at_step": step,
            "time_spent_seconds": Int(timeSpent),
            "characters_added": charactersAdded,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Template Events
    
    /// Track template viewed
    func trackTemplateViewed(
        templateId: String,
        templateTitle: String,
        category: String,
        tier: String
    ) {
        logEvent("template_viewed", parameters: [
            "template_id": templateId,
            "template_title": templateTitle,
            "category": category,
            "tier": tier,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Track template used
    func trackTemplateUsed(
        templateId: String,
        templateTitle: String,
        category: String,
        characterCount: Int
    ) {
        logEvent("template_used", parameters: [
            "template_id": templateId,
            "template_title": templateTitle,
            "category": category,
            "character_count": characterCount,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Character Events
    
    /// Track character creation
    func trackCharacterCreated(
        characterType: String,
        hasVisualProfile: Bool,
        hasAge: Bool,
        hasDescription: Bool,
        timeSpent: TimeInterval
    ) {
        logEvent("character_created", parameters: [
            "character_type": characterType,
            "has_visual_profile": hasVisualProfile,
            "has_age": hasAge,
            "has_description": hasDescription,
            "time_spent_seconds": Int(timeSpent),
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Track character saved to library
    func trackCharacterSaved(
        characterType: String,
        hasVisualProfile: Bool
    ) {
        logEvent("character_saved", parameters: [
            "character_type": characterType,
            "has_visual_profile": hasVisualProfile,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Track character deleted
    func trackCharacterDeleted(characterType: String) {
        logEvent("character_deleted", parameters: [
            "character_type": characterType,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Story Reading Events
    
    /// Track story opened
    func trackStoryOpened(
        storyId: String,
        storyType: String,
        category: String,
        hasAudio: Bool,
        isIllustrated: Bool,
        source: String
    ) {
        logEvent("story_opened", parameters: [
            "story_id": storyId,
            "story_type": storyType,
            "category": category,
            "has_audio": hasAudio,
            "is_illustrated": isIllustrated,
            "source": source,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Track story reading progress
    func trackStoryProgress(
        storyId: String,
        currentPage: Int,
        totalPages: Int,
        timeSpent: TimeInterval
    ) {
        let progress = Double(currentPage) / Double(totalPages)
        logEvent("story_progress", parameters: [
            "story_id": storyId,
            "current_page": currentPage,
            "total_pages": totalPages,
            "progress_percentage": Int(progress * 100),
            "time_spent_seconds": Int(timeSpent),
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Track story completed
    func trackStoryCompleted(
        storyId: String,
        totalPages: Int,
        timeSpent: TimeInterval,
        completionRate: Double
    ) {
        logEvent("story_completed", parameters: [
            "story_id": storyId,
            "total_pages": totalPages,
            "time_spent_seconds": Int(timeSpent),
            "completion_rate": Int(completionRate * 100),
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Track audio playback
    func trackAudioPlayed(
        storyId: String,
        page: Int,
        duration: TimeInterval
    ) {
        logEvent("audio_played", parameters: [
            "story_id": storyId,
            "page": page,
            "duration_seconds": Int(duration),
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Track audio completed
    func trackAudioCompleted(
        storyId: String,
        totalDuration: TimeInterval
    ) {
        logEvent("audio_completed", parameters: [
            "story_id": storyId,
            "total_duration_seconds": Int(totalDuration),
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Monetization Events
    
    /// Track subscription viewed
    func trackSubscriptionViewed(
        tier: String,
        source: String
    ) {
        logEvent("subscription_viewed", parameters: [
            "tier": tier,
            "source": source,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Track subscription purchased
    func trackSubscriptionPurchased(
        productId: String,
        tier: String,
        price: Double,
        currency: String,
        isFreeTrial: Bool
    ) {
        logEvent("subscription_purchased", parameters: [
            "product_id": productId,
            "tier": tier,
            "price": price,
            "currency": currency,
            "is_free_trial": isFreeTrial,
            "timestamp": Date().timeIntervalSince1970
        ])
        
        // Also log as purchase event for revenue tracking
        Analytics.logEvent(AnalyticsEventPurchase, parameters: [
            AnalyticsParameterTransactionID: productId,
            AnalyticsParameterValue: price,
            AnalyticsParameterCurrency: currency,
            AnalyticsParameterItemName: "Subscription_\(tier)"
        ])
    }
    
    /// Track subscription cancelled
    func trackSubscriptionCancelled(
        tier: String,
        reason: String?,
        daysActive: Int
    ) {
        var parameters: [String: Any] = [
            "tier": tier,
            "days_active": daysActive,
            "timestamp": Date().timeIntervalSince1970
        ]
        if let reason = reason {
            parameters["reason"] = reason
        }
        logEvent("subscription_cancelled", parameters: parameters)
    }
    
    /// Track coin purchase
    func trackCoinPurchased(
        productId: String,
        coins: Int,
        price: Double,
        currency: String
    ) {
        logEvent("coin_purchased", parameters: [
            "product_id": productId,
            "coins": coins,
            "price": price,
            "currency": currency,
            "timestamp": Date().timeIntervalSince1970
        ])
        
        // Also log as purchase event
        Analytics.logEvent(AnalyticsEventPurchase, parameters: [
            AnalyticsParameterTransactionID: productId,
            AnalyticsParameterValue: price,
            AnalyticsParameterCurrency: currency,
            AnalyticsParameterItemName: "Coins_\(coins)"
        ])
    }
    
    /// Track coin spent
    func trackCoinSpent(
        amount: Int,
        purpose: String,
        itemId: String?
    ) {
        var parameters: [String: Any] = [
            "amount": amount,
            "purpose": purpose,
            "timestamp": Date().timeIntervalSince1970
        ]
        if let itemId = itemId {
            parameters["item_id"] = itemId
        }
        logEvent("coin_spent", parameters: parameters)
    }
    
    /// Track upgrade prompt shown
    func trackUpgradePromptShown(
        source: String,
        currentTier: String,
        targetTier: String
    ) {
        logEvent("upgrade_prompt_shown", parameters: [
            "source": source,
            "current_tier": currentTier,
            "target_tier": targetTier,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Track upgrade prompt tapped
    func trackUpgradePromptTapped(
        source: String,
        currentTier: String,
        targetTier: String
    ) {
        logEvent("upgrade_prompt_tapped", parameters: [
            "source": source,
            "current_tier": currentTier,
            "target_tier": targetTier,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Engagement Events
    
    /// Track app opened
    func trackAppOpened(source: String? = nil) {
        var parameters: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970
        ]
        if let source = source {
            parameters["source"] = source
        }
        logEvent("app_opened", parameters: parameters)
    }
    
    /// Track screen viewed
    func trackScreenViewed(
        screenName: String,
        screenClass: String? = nil
    ) {
        var parameters: [String: Any] = [
            "screen_name": screenName,
            "timestamp": Date().timeIntervalSince1970
        ]
        if let screenClass = screenClass {
            parameters["screen_class"] = screenClass
        }
        Analytics.logEvent(AnalyticsEventScreenView, parameters: parameters)
    }
    
    /// Track search performed
    func trackSearchPerformed(
        query: String,
        resultsCount: Int,
        category: String?
    ) {
        var parameters: [String: Any] = [
            "search_term": query,
            "results_count": resultsCount,
            "timestamp": Date().timeIntervalSince1970
        ]
        if let category = category {
            parameters["category"] = category
        }
        Analytics.logEvent(AnalyticsEventSearch, parameters: parameters)
    }
    
    /// Track share action
    func trackShareAction(
        contentType: String,
        contentId: String,
        method: String
    ) {
        Analytics.logEvent(AnalyticsEventShare, parameters: [
            AnalyticsParameterContentType: contentType,
            AnalyticsParameterItemID: contentId,
            AnalyticsParameterMethod: method,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Track notification permission
    func trackNotificationPermission(granted: Bool) {
        logEvent(granted ? "notification_permission_granted" : "notification_permission_denied", parameters: [
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Track notification received
    func trackNotificationReceived(
        type: String,
        actionTaken: Bool
    ) {
        logEvent("notification_received", parameters: [
            "type": type,
            "action_taken": actionTaken,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Error Tracking
    
    /// Track error occurred
    func trackError(
        errorCode: String,
        errorMessage: String,
        context: String,
        isFatal: Bool = false
    ) {
        logEvent("error_occurred", parameters: [
            "error_code": errorCode,
            "error_message": errorMessage,
            "context": context,
            "is_fatal": isFatal,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - User Properties
    
    /// Set user properties for segmentation
    func setUserProperties(
        tier: String,
        language: String,
        totalStoriesCreated: Int,
        totalCharactersSaved: Int,
        daysSinceSignup: Int
    ) {
        Analytics.setUserProperty(tier, forName: "subscription_tier")
        Analytics.setUserProperty(language, forName: "preferred_language")
        Analytics.setUserProperty("\(totalStoriesCreated)", forName: "total_stories")
        Analytics.setUserProperty("\(totalCharactersSaved)", forName: "total_characters")
        Analytics.setUserProperty("\(daysSinceSignup)", forName: "days_since_signup")
    }
    
    /// Update user tier
    func updateUserTier(_ tier: String) {
        Analytics.setUserProperty(tier, forName: "subscription_tier")
    }
    
    /// Set user ID
    func setUserId(_ userId: String) {
        Analytics.setUserID(userId)
    }
    
    // MARK: - Helper Methods
    
    private func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        #if DEBUG
        print("📊 Analytics: \(name)")
        if let parameters = parameters {
            print("   Parameters: \(parameters)")
        }
        #endif
        
        Analytics.logEvent(name, parameters: parameters)
    }
}

// MARK: - Supporting Types

enum AuthMethod: String {
    case email = "email"
    case apple = "apple"
    case google = "google"
    case guest = "guest"
}

enum StoryCreationType: String {
    case custom = "custom"
    case template = "template"
    case quick = "quick"
}

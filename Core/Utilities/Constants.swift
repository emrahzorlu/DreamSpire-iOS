//
//  Constants.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025-11-02.
//

import Foundation
import SwiftUI

struct Constants {
    
    // MARK: - API Configuration
    
    struct API {
        static let baseURL = "https://dreamweaver-backend-v2-production.up.railway.app"
        static let requestTimeout: TimeInterval = 30
        static let resourceTimeout: TimeInterval = 300 // For long story generation
        
        struct Endpoints {
            // Stories
            static let stories = "/api/stories"
            static let createStory = "/api/stories/create"
            static let createIllustratedStory = "/api/stories/create-illustrated"
            static let userStories = "/api/stories/user"
            static let singleStory = "/api/stories"
            
            // Templates
            static let templates = "/api/templates"
            static let generateFromTemplate = "/api/templates"
            
            // Prewritten
            static let prewritten = "/api/prewritten"
            
            // Characters
            static let characters = "/api/characters"
            
            // Favorites
            static let favorites = "/api/favorites"
            static let toggleFavorite = "/api/favorites/toggle"
            
            // User & Subscription
            static let userProfile = "/api/user/profile"
            static let subscription = "/api/user/subscription"
            static let usage = "/api/user/usage"
            static let checkout = "/api/user/subscription/checkout"
        }
    }
    
    // MARK: - Story Configuration
    
    struct Story {
        static let minIdeaLength = 10
        static let maxIdeaLength = 500
        static let minReadingMinutes = 3
        static let maxReadingMinutes = 15
        static let defaultReadingMinutes = 5
        
        // Genres
        static let genres = [
            "adventure": "Macera",
            "fantasy": "Fantezi",
            "fairy_tale": "Masal",
            "mystery": "Gizem",
            "educational": "Eğitici",
            "bedtime": "Uyku Vakti",
            "comedy": "Komedi",
            "animals": "Hayvanlar"
        ]
        
        // Tones
        static let tones = [
            "calm": "Sakin",
            "exciting": "Heyecanlı",
            "happy": "Neşeli",
            "mysterious": "Gizemli",
            "educational": "Eğitici",
            "adventurous": "Maceralı"
        ]
        
        // Age Ranges
        static let ageRanges = [
            "toddler": "0-3 yaş",
            "young": "4-6 yaş",
            "middle": "7-9 yaş",
            "preteen": "10-12 yaş",
            "teen": "13+ yaş"
        ]
    }
    
    // MARK: - Character Configuration
    
    struct Character {
        static let maxNameLength = 50
        static let maxDescriptionLength = 200
    }
    
    // MARK: - Subscription Configuration
    
    struct Subscription {
        // Free Tier
        static let freeStoriesPerMonth = 3
        static let freeMaxCharacters = 2
        static let freePrewrittenAccess = 15
        
        // Plus Tier
        static let plusMonthlyPrice = 9.99
        static let plusMaxCharacters = 4
        static let plusMaxSavedCharacters = 10
        static let plusPrewrittenAccess = 50
        
        // Pro Tier
        static let proMonthlyPrice = 19.99
        static let proMaxCharacters = 6
        static let proPrewrittenAccessAll = true
    }
    
    // MARK: - UI Configuration
    
    struct UI {
        // Colors
        static let primaryColor = Color("PrimaryColor")
        static let secondaryColor = Color("SecondaryColor")
        static let accentColor = Color("AccentColor")
        
        // Gradients
        static let backgroundGradient = LinearGradient(
            colors: [
                Color(red: 0.4, green: 0.8, blue: 1.0),  // Cyan
                Color(red: 0.6, green: 0.4, blue: 1.0)   // Purple
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        // Spacing
        static let cornerRadius: CGFloat = 12
        static let cardCornerRadius: CGFloat = 16
        static let buttonCornerRadius: CGFloat = 12
        static let shadowRadius: CGFloat = 8
        
        // Animations
        static let defaultAnimationDuration: Double = 0.3
        static let longAnimationDuration: Double = 0.6
    }
    
    // MARK: - Analytics Events
    
    struct Analytics {
        // User Events
        static let userSignedIn = "user_signed_in"
        static let userSignedUp = "user_signed_up"
        static let userSignedOut = "user_signed_out"
        static let onboardingCompleted = "onboarding_completed"
        
        // Story Events
        static let storyCreated = "story_created"
        static let storyViewed = "story_viewed"
        static let storyCompleted = "story_completed"
        static let storyShared = "story_shared"
        
        // Audio Events
        static let audioPlayed = "audio_played"
        static let audioCompleted = "audio_completed"
        
        // Subscription Events
        static let subscriptionStarted = "subscription_started"
        static let subscriptionUpgraded = "subscription_upgraded"
        static let subscriptionCanceled = "subscription_canceled"
        
        // Character Events
        static let characterCreated = "character_created"
        static let characterSaved = "character_saved"
        static let characterReused = "character_reused"
    }
    
    // MARK: - Error Messages
    
    struct ErrorMessages {
        static let networkError = "İnternet bağlantınızı kontrol edin"
        static let authRequired = "Lütfen giriş yapın"
        static let subscriptionRequired = "Bu özellik için abonelik gerekli"
        static let limitReached = "Aylık hikaye limitiniz doldu"
        static let unknownError = "Bir hata oluştu. Lütfen tekrar deneyin"
    }
    
    // MARK: - App Information
    
    struct App {
        static let name = "DreamSpire"
        static let version = "1.0"
        static let buildNumber = "1"
        static let bundleIdentifier = "com.emrahzorlu.DreamSpire"
        static let defaultLanguage = "tr"

        // Support
        static let supportEmail = "dreamspire.help@gmail.com"
        static let privacyPolicyURL = "https://dreamweaver-backend-v2-production.up.railway.app/privacy.html"
        static let termsOfServiceURL = "https://dreamweaver-backend-v2-production.up.railway.app/terms.html"

        // Social
        static let websiteURL = "https://dreamspire.app"
        static let twitterHandle = "@dreamspire"
    }
    
    // MARK: - Storage Keys
    
    struct StorageKeys {
        // User Preferences
        static let hasSeenOnboarding = "hasSeenOnboarding"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let hasCompletedAuthChoice = "hasCompletedAuthChoice" // Tracks if user finished login/signup/guest flow
        static let selectedLanguage = "selectedLanguage"
        static let notificationsEnabled = "notificationsEnabled"
        static let autoPlayAudio = "autoPlayAudio"
        
        // Reading Settings
        static let fontSize = "fontSize"
        static let isDarkMode = "isDarkMode"
        static let downloadQuality = "downloadQuality"
        static let dataUsageMode = "dataUsageMode"
        
        // Cache
        static let cachedStories = "cachedStories"
        static let lastSyncDate = "lastSyncDate"
    }
    
    // MARK: - Feature Flags
    
    struct FeatureFlags {
        static let enableIllustrations = true
        static let enablePremiumVoices = true
        static let enableOfflineMode = false
        static let enableSocialSharing = true
        static let enableAnalytics = true
    }
}

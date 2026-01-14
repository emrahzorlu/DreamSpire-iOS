//
//  Container.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025.
//

import Foundation

/// Central dependency container for the app
/// Makes it easy to swap out dependencies for testing
@MainActor
final class Container {
    
    // Singleton for production use
    static let shared = Container()
    
    // MARK: - Services
    
    // API client for network requests
    lazy var apiClient: APIClient = {
        APIClient.shared
    }()
    
    // Authentication manager
    lazy var authManager: AuthManager = {
        AuthManager.shared
    }()
    
    // Coin management
    lazy var coinService: CoinService = {
        CoinService.shared
    }()
    
    // Subscriptions
    lazy var subscriptionService: SubscriptionService = {
        SubscriptionService.shared
    }()
    
    // MARK: - Repositories
    
    lazy var storyRepository: StoryRepository = {
        StoryRepository.shared
    }()
    
    lazy var characterRepository: CharacterRepository = {
        CharacterRepository.shared
    }()
    
    lazy var userStoryRepository: UserStoryRepository = {
        UserStoryRepository.shared
    }()
    
    lazy var templateRepository: TemplateRepository = {
        TemplateRepository.shared
    }()
    
    // MARK: - Initialization
    
    private init() {
        // Private init ensures singleton pattern
    }
    
    /// Create a container with custom dependencies (for testing)
    init(
        apiClient: APIClient? = nil,
        authManager: AuthManager? = nil,
        coinService: CoinService? = nil,
        subscriptionService: SubscriptionService? = nil
    ) {
        if let apiClient = apiClient {
            self.apiClient = apiClient
        }
        if let authManager = authManager {
            self.authManager = authManager
        }
        if let coinService = coinService {
            self.coinService = coinService
        }
        if let subscriptionService = subscriptionService {
            self.subscriptionService = subscriptionService
        }
    }
}

//
//  APIClientProtocol.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025.
//

import Foundation

/// Protocol for API networking operations
/// Allows injecting mock clients for testing
protocol APIClientProtocol {
    
    /// Make a generic API request
    func makeRequest<T: Decodable>(
        endpoint: String,
        method: HTTPMethod,
        body: Encodable?,
        requiresAuth: Bool,
        includeDeviceId: Bool,
        idempotencyKey: String?
    ) async throws -> T
    
    // Subscription
    func getSubscription() async throws -> Subscription
    func verifySubscription(_ request: VerifySubscriptionRequest) async throws -> VerifySubscriptionResponse
    
    // Stories
    func getUserStories(userId: String, summary: Bool) async throws -> [Story]
    
    // Favorites
    func getUserFavorites() async throws -> [Story]
    
    // Characters
    func getSavedCharacters() async throws -> [Character]
    func saveCharacter(_ character: Character) async throws -> Character
    func deleteCharacter(id: String) async throws
    
    // Transactions
    func getCoinTransactions() async throws -> [CoinTransaction]
}

// Default parameter values for makeRequest
extension APIClientProtocol {
    func makeRequest<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        requiresAuth: Bool = true,
        includeDeviceId: Bool = false,
        idempotencyKey: String? = nil
    ) async throws -> T {
        try await makeRequest(
            endpoint: endpoint,
            method: method,
            body: body,
            requiresAuth: requiresAuth,
            includeDeviceId: includeDeviceId,
            idempotencyKey: idempotencyKey
        )
    }
}

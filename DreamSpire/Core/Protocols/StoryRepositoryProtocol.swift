//
//  StoryRepositoryProtocol.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025.
//

import Foundation
import Combine

/// Protocol for story data operations
/// Handles caching and fetching
@MainActor
protocol StoryRepositoryProtocol: ObservableObject {
    
    // Cached stories
    var stories: [Story] { get }
    var isLoading: Bool { get }
    var error: String? { get }
    
    // Fetch operations
    func getStories(language: String?, forceRefresh: Bool, summary: Bool) async throws -> [Story]
    func getStoriesByTag(_ tag: String, language: String?) async throws -> [Story]
    func getStory(id: String) async throws -> Story
    
    // Cache management
    func refresh(language: String?) async throws -> [Story]
    func clearCache(for language: String)
}

// Default parameter values
extension StoryRepositoryProtocol {
    func getStories(language: String? = nil, forceRefresh: Bool = false, summary: Bool = true) async throws -> [Story] {
        try await getStories(language: language, forceRefresh: forceRefresh, summary: summary)
    }
}

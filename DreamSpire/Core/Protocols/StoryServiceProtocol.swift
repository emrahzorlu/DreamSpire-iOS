//
//  StoryServiceProtocol.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025.
//

import Foundation

/// Protocol for story creation and management
protocol StoryServiceProtocol {
    
    // Story creation
    func createStory(request: CreateStoryWithCoinsRequest) async throws -> StoryJob
    
    // Story retrieval
    func getStory(id: String) async throws -> Story
    func getUserStories(userId: String) async throws -> [Story]
    
    // Story deletion
    func deleteStory(id: String) async throws
    
    // Favorites
    func toggleFavorite(storyId: String) async throws -> Bool
}

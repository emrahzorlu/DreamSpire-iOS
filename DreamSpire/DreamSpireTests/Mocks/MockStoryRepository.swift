//
//  MockStoryRepository.swift
//  DreamSpireTests
//
//  Created by Emrah Zorlu on 2025.
//

import Foundation
@testable import DreamSpire

/// Mock story repository for unit testing
@MainActor
class MockStoryRepository: ObservableObject {
    
    // Test data
    var mockStories: [Story] = []
    var shouldFailFetch: Bool = false
    
    // Track method calls
    var getStoriesCallCount = 0
    var refreshCallCount = 0
    
    // Published properties
    @Published var stories: [Story] = []
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    func getStories(language: String? = nil, forceRefresh: Bool = false, summary: Bool = true) async throws -> [Story] {
        getStoriesCallCount += 1
        
        if shouldFailFetch {
            throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock fetch error"])
        }
        
        stories = mockStories
        return mockStories
    }
    
    func getStoriesByTag(_ tag: String, language: String? = nil) async throws -> [Story] {
        let all = try await getStories(language: language)
        return all.filter { $0.tags?.contains(tag) ?? false }
    }
    
    func getStory(id: String) async throws -> Story {
        guard let story = mockStories.first(where: { $0.id == id }) else {
            throw NSError(domain: "MockError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Story not found"])
        }
        return story
    }
    
    func refresh(language: String? = nil) async throws -> [Story] {
        refreshCallCount += 1
        return try await getStories(language: language, forceRefresh: true)
    }
    
    func clearCache(for language: String) {
        // Mock implementation
        stories = []
    }
    
    // Reset for clean test state
    func reset() {
        mockStories = []
        shouldFailFetch = false
        getStoriesCallCount = 0
        refreshCallCount = 0
        stories = []
        isLoading = false
        error = nil
    }
    
    // Helper to create test story
    static func createTestStory(
        id: String = UUID().uuidString,
        title: String = "Test Story",
        tags: [String]? = nil
    ) -> Story {
        return Story(
            id: id,
            userId: "test-user",
            type: .prewritten,
            title: title,
            language: "en",
            pages: [
                StoryPage(id: "1", pageNumber: 1, text: "Once upon a time...")
            ],
            coverImageUrl: nil,
            audioUrl: nil,
            category: "adventure",
            estimatedMinutes: 5,
            characterProfiles: nil,
            metadata: nil,
            ageRange: "7-9",
            tone: nil,
            tags: tags,
            isFavorite: false,
            isSummary: false,
            views: 0,
            favorites: 0,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

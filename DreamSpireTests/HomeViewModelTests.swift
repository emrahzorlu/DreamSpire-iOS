//
//  HomeViewModelTests.swift
//  DreamSpireTests
//
//  Created by Emrah Zorlu on 2025.
//

import XCTest
@testable import DreamSpire

@MainActor
final class HomeViewModelTests: XCTestCase {
    
    var mockStoryRepository: MockStoryRepository!
    var mockAuthManager: MockAuthManager!
    
    override func setUp() {
        super.setUp()
        mockStoryRepository = MockStoryRepository()
        mockAuthManager = MockAuthManager()
    }
    
    override func tearDown() {
        mockStoryRepository = nil
        mockAuthManager = nil
        super.tearDown()
    }
    
    // MARK: - Content Loading Tests
    
    func testLoadContentFetchesStories() async throws {
        // Given
        let testStories = [
            MockStoryRepository.createTestStory(title: "Adventure Story", tags: ["adventure"]),
            MockStoryRepository.createTestStory(title: "Classic Tale", tags: ["classic"]),
            MockStoryRepository.createTestStory(title: "Animal Story", tags: ["animals"])
        ]
        mockStoryRepository.mockStories = testStories
        
        // When
        _ = try await mockStoryRepository.getStories()
        
        // Then
        XCTAssertEqual(mockStoryRepository.stories.count, 3)
        XCTAssertEqual(mockStoryRepository.getStoriesCallCount, 1)
    }
    
    func testLoadContentByTagFiltersCorrectly() async throws {
        // Given
        let testStories = [
            MockStoryRepository.createTestStory(title: "Adventure 1", tags: ["adventure"]),
            MockStoryRepository.createTestStory(title: "Adventure 2", tags: ["adventure"]),
            MockStoryRepository.createTestStory(title: "Classic Tale", tags: ["classic"])
        ]
        mockStoryRepository.mockStories = testStories
        
        // When
        let adventureStories = try await mockStoryRepository.getStoriesByTag("adventure")
        
        // Then
        XCTAssertEqual(adventureStories.count, 2)
        XCTAssertTrue(adventureStories.allSatisfy { $0.tags?.contains("adventure") ?? false })
    }
    
    // MARK: - User State Tests
    
    func testUserNameIsLoadedForAuthenticatedUser() {
        // Given
        mockAuthManager.currentUserName = "John"
        
        // Then
        XCTAssertEqual(mockAuthManager.currentUserName, "John")
        XCTAssertTrue(mockAuthManager.isAuthenticated)
    }
    
    func testGuestUserHasNoName() async throws {
        // Given
        try await mockAuthManager.signInAnonymously()
        
        // Then
        XCTAssertTrue(mockAuthManager.isGuest)
        XCTAssertNil(mockAuthManager.currentUserName)
    }
    
    // MARK: - Refresh Tests
    
    func testForceRefreshClearsAndReloads() async throws {
        // Given
        mockStoryRepository.mockStories = [
            MockStoryRepository.createTestStory(title: "Story 1")
        ]
        _ = try await mockStoryRepository.getStories()
        
        // When
        mockStoryRepository.mockStories = [
            MockStoryRepository.createTestStory(title: "Story 1"),
            MockStoryRepository.createTestStory(title: "Story 2")
        ]
        _ = try await mockStoryRepository.refresh()
        
        // Then
        XCTAssertEqual(mockStoryRepository.stories.count, 2)
        XCTAssertEqual(mockStoryRepository.refreshCallCount, 1)
    }
    
    // MARK: - Error Handling Tests
    
    func testLoadContentHandlesError() async {
        // Given
        mockStoryRepository.shouldFailFetch = true
        
        // When/Then
        do {
            _ = try await mockStoryRepository.getStories()
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - Cache Tests
    
    func testCacheIsUsedOnSecondLoad() async throws {
        // Given
        mockStoryRepository.mockStories = [
            MockStoryRepository.createTestStory(title: "Cached Story")
        ]
        
        // When
        _ = try await mockStoryRepository.getStories()
        _ = try await mockStoryRepository.getStories() // Second call
        
        // Then
        XCTAssertEqual(mockStoryRepository.getStoriesCallCount, 2)
    }
}

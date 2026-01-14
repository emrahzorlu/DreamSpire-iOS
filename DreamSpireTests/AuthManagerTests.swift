//
//  AuthManagerTests.swift
//  DreamSpireTests
//
//  Created by Emrah Zorlu on 2025.
//

import XCTest
@testable import DreamSpire

@MainActor
final class AuthManagerTests: XCTestCase {
    
    var mockAuthManager: MockAuthManager!
    
    override func setUp() {
        super.setUp()
        mockAuthManager = MockAuthManager()
    }
    
    override func tearDown() {
        mockAuthManager = nil
        super.tearDown()
    }
    
    // MARK: - Sign In Tests
    
    func testSignInSuccess() async throws {
        // Given
        let email = "test@example.com"
        let password = "password123"
        
        // When
        try await mockAuthManager.signIn(email: email, password: password)
        
        // Then
        XCTAssertTrue(mockAuthManager.isAuthenticated)
        XCTAssertFalse(mockAuthManager.isGuest)
        XCTAssertEqual(mockAuthManager.currentUserEmail, email)
        XCTAssertEqual(mockAuthManager.signInCallCount, 1)
    }
    
    func testSignInFailure() async {
        // Given
        mockAuthManager.shouldFailSignIn = true
        
        // When/Then
        do {
            try await mockAuthManager.signIn(email: "test@example.com", password: "wrong")
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertFalse(mockAuthManager.isGuest) // State unchanged from initial
        }
    }
    
    // MARK: - Sign Up Tests
    
    func testSignUpSuccess() async throws {
        // Given
        let email = "new@example.com"
        let password = "password123"
        let name = "New User"
        
        // When
        try await mockAuthManager.signUp(email: email, password: password, name: name)
        
        // Then
        XCTAssertTrue(mockAuthManager.isAuthenticated)
        XCTAssertFalse(mockAuthManager.isGuest)
        XCTAssertEqual(mockAuthManager.currentUserEmail, email)
        XCTAssertEqual(mockAuthManager.currentUserName, name)
        XCTAssertEqual(mockAuthManager.signUpCallCount, 1)
    }
    
    func testSignUpFailure() async {
        // Given
        mockAuthManager.shouldFailSignUp = true
        
        // When/Then
        do {
            try await mockAuthManager.signUp(email: "test@example.com", password: "pass", name: "Test")
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertEqual(mockAuthManager.signUpCallCount, 1)
        }
    }
    
    // MARK: - Anonymous Sign In Tests
    
    func testSignInAnonymously() async throws {
        // When
        try await mockAuthManager.signInAnonymously()
        
        // Then
        XCTAssertTrue(mockAuthManager.isAuthenticated)
        XCTAssertTrue(mockAuthManager.isGuest)
        XCTAssertNotNil(mockAuthManager.currentUserId)
        XCTAssertNil(mockAuthManager.currentUserEmail)
    }
    
    // MARK: - Sign Out Tests
    
    func testSignOut() async throws {
        // Given
        try await mockAuthManager.signIn(email: "test@example.com", password: "password")
        XCTAssertTrue(mockAuthManager.isAuthenticated)
        
        // When
        try mockAuthManager.signOut()
        
        // Then
        XCTAssertFalse(mockAuthManager.isAuthenticated)
        XCTAssertTrue(mockAuthManager.isGuest)
        XCTAssertNil(mockAuthManager.currentUserId)
        XCTAssertEqual(mockAuthManager.signOutCallCount, 1)
    }
    
    // MARK: - State Tests
    
    func testInitialState() {
        // Given - fresh mock
        mockAuthManager.reset()
        
        // Then
        XCTAssertTrue(mockAuthManager.isAuthenticated) // Default mock state
        XCTAssertFalse(mockAuthManager.isGuest)
        XCTAssertNotNil(mockAuthManager.currentUserId)
    }
    
    func testResetClearsState() {
        // Given
        mockAuthManager.signInCallCount = 5
        mockAuthManager.shouldFailSignIn = true
        
        // When
        mockAuthManager.reset()
        
        // Then
        XCTAssertEqual(mockAuthManager.signInCallCount, 0)
        XCTAssertFalse(mockAuthManager.shouldFailSignIn)
    }
}

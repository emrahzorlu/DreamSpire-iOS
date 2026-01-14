//
//  MockAuthManager.swift
//  DreamSpireTests
//
//  Created by Emrah Zorlu on 2025.
//

import Foundation
@testable import DreamSpire

/// Mock auth manager for unit testing
@MainActor
class MockAuthManager: ObservableObject {
    
    // Test configuration
    var mockUserId: String? = "test-user-123"
    var mockUserName: String? = "Test User"
    var mockUserEmail: String? = "test@example.com"
    var mockIsAuthenticated: Bool = true
    var mockIsGuest: Bool = false
    var shouldFailSignIn: Bool = false
    var shouldFailSignUp: Bool = false
    
    // Track method calls
    var signInCallCount = 0
    var signUpCallCount = 0
    var signOutCallCount = 0
    
    // Published properties
    @Published var isAuthenticated: Bool = true
    @Published var isGuest: Bool = false
    @Published var currentUserId: String? = "test-user-123"
    @Published var currentUserEmail: String? = "test@example.com"
    @Published var currentUserName: String? = "Test User"
    
    func signIn(email: String, password: String) async throws {
        signInCallCount += 1
        
        if shouldFailSignIn {
            throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock sign in error"])
        }
        
        isAuthenticated = true
        isGuest = false
        currentUserId = mockUserId
        currentUserEmail = email
        currentUserName = mockUserName
    }
    
    func signUp(email: String, password: String, name: String) async throws {
        signUpCallCount += 1
        
        if shouldFailSignUp {
            throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock sign up error"])
        }
        
        isAuthenticated = true
        isGuest = false
        currentUserId = mockUserId
        currentUserEmail = email
        currentUserName = name
    }
    
    func signInAnonymously() async throws {
        isAuthenticated = true
        isGuest = true
        currentUserId = "guest-user-\(UUID().uuidString.prefix(8))"
        currentUserEmail = nil
        currentUserName = nil
    }
    
    func signOut() throws {
        signOutCallCount += 1
        isAuthenticated = false
        isGuest = true
        currentUserId = nil
        currentUserEmail = nil
        currentUserName = nil
    }
    
    // Reset for clean test state
    func reset() {
        mockUserId = "test-user-123"
        mockUserName = "Test User"
        mockUserEmail = "test@example.com"
        mockIsAuthenticated = true
        mockIsGuest = false
        shouldFailSignIn = false
        shouldFailSignUp = false
        signInCallCount = 0
        signUpCallCount = 0
        signOutCallCount = 0
        
        isAuthenticated = mockIsAuthenticated
        isGuest = mockIsGuest
        currentUserId = mockUserId
        currentUserEmail = mockUserEmail
        currentUserName = mockUserName
    }
}

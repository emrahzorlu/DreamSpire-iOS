//
//  AuthManagerProtocol.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025.
//

import Foundation
import Combine
import AuthenticationServices

/// Protocol for authentication operations
/// Allows mocking auth state in tests
@MainActor
protocol AuthManagerProtocol: ObservableObject {
    
    // User state
    var isAuthenticated: Bool { get }
    var isGuest: Bool { get }
    var currentUserId: String? { get }
    var currentUserEmail: String? { get }
    var currentUserName: String? { get }
    
    // Sign in operations
    func signIn(email: String, password: String) async throws
    func signUp(email: String, password: String, name: String) async throws
    func signInWithApple(credentials: ASAuthorizationAppleIDCredential) async throws
    func signInAnonymously() async throws
    
    // Sign out
    func signOut() throws
    
    // Password reset
    func resetPassword(email: String) async throws
}

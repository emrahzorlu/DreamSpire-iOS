//
//  AuthManager.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//

import Foundation
import FirebaseAuth
import Combine
import UIKit  // For UIDevice
import AuthenticationServices
import CryptoKit

/// Authentication manager with Firebase integration
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    // User state
    @Published var userState: UserState = .guest
    @Published var isAuthenticated: Bool = false
    @Published var isGuest: Bool = true

    // User info
    @Published var currentUser: FirebaseAuth.User?
    @Published var currentUserId: String?
    @Published var currentUserEmail: String?
    @Published var currentUserName: String?

    private var handle: AuthStateDidChangeListenerHandle?

    // For Sign In With Apple
    @Published var currentNonce: String?

    // Flag to prevent auto anonymous sign-in when user explicitly signs out
    private var shouldPreventAutoAnonymousSignIn: Bool = false

    // Device-bound guest session ID (persistent across sign outs)
    private let deviceGuestUserIdKey = "DeviceGuestUserId"
    
    private init() {
        DWLogger.shared.info("AuthManager initialized", category: .auth)
        registerAuthStateHandler()
    }
    
    deinit {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Auth State
    
    private func registerAuthStateHandler() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let strongSelf = self else { return }
                strongSelf.currentUser = user
                strongSelf.currentUserId = user?.uid
                strongSelf.currentUserEmail = user?.email
                strongSelf.currentUserName = user?.displayName

                // Determine if user is anonymous
                let isAnonymous = user?.isAnonymous ?? false

                if let user = user {
                    // User exists (either authenticated or anonymous)
                    strongSelf.isAuthenticated = true
                    strongSelf.isGuest = isAnonymous
                    strongSelf.userState = isAnonymous ? .guest : .authenticated

                    if isAnonymous {
                        DWLogger.shared.info("Anonymous user active: \(user.uid)", category: .auth)
                    } else {
                        DWLogger.shared.info("Authenticated user: \(user.uid)", category: .auth)
                    }
                } else {
                    // No user at all
                    strongSelf.isAuthenticated = false
                    strongSelf.isGuest = true
                    strongSelf.userState = .guest

                    // Only auto-create anonymous user if NOT explicitly prevented (e.g., after sign out)
                    if !strongSelf.shouldPreventAutoAnonymousSignIn {
                        DWLogger.shared.info("No user found, creating anonymous session...", category: .auth)
                        do {
                            let result = try await Auth.auth().signInAnonymously()
                            DWLogger.shared.logAuthEvent("Anonymous Sign In Success", userId: result.user.uid)
                            // State will be updated by this listener being called again
                        } catch {
                            DWLogger.shared.error("Anonymous Sign In Failed: \(error.localizedDescription)", category: .auth)
                        }
                    } else {
                        // User explicitly signed out, stay in signed-out state
                        DWLogger.shared.info("User signed out, preventing auto anonymous sign-in", category: .auth)
                    }
                }

                if let userId = strongSelf.currentUser?.uid {
                    DWLogger.shared.logAuthEvent("User State Updated", userId: userId)
                } else {
                    DWLogger.shared.logAuthEvent("User Signed Out")
                }
            }
        }
    }
    
    // MARK: - Sign In

    func signIn(email: String, password: String) async throws {
        DWLogger.shared.info("Attempting sign in: \(email)", category: .auth)

        // IMPORTANT: We don't transfer guest data on sign in to EXISTING account
        // The user is logging into an EXISTING account, so their data is already there
        // Guest data transfer is ONLY for NEW signUps and NEW Apple registrations
        // If user was in a guest session before login, that session is preserved
        // and can be restored when user signs out and continues as guest again

        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        
        await MainActor.run {
            self.currentUser = result.user
            self.isAuthenticated = true
            self.currentUserId = result.user.uid
            self.currentUserEmail = result.user.email
            self.currentUserName = result.user.displayName
        }
        
        // Clear caches to fetch fresh data for the logged-in user
        Task { @MainActor in
            AppPreloadService.shared.clearAllCaches()
        }
        
        DWLogger.shared.logAuthEvent("Sign In Success", userId: result.user.uid, details: email)
        DWLogger.shared.logAnalyticsEvent("user_signed_in", parameters: ["method": "email"])
    }
    
    // MARK: - Sign Up
    
    func signUp(email: String, password: String, name: String) async throws {
        DWLogger.shared.info("📧 Attempting sign up: \(email)", category: .auth)

        // Capture current guest UID before sign up (for data transfer)
        let currentUser = Auth.auth().currentUser
        let isCurrentlyAnonymous = currentUser?.isAnonymous ?? false
        let guestUidBeforeSignUp = isCurrentlyAnonymous ? currentUser?.uid : nil

        DWLogger.shared.info("📧 Pre-signup state:", category: .auth)
        DWLogger.shared.info("  - Current User ID: \(currentUser?.uid ?? "none")", category: .auth)
        DWLogger.shared.info("  - Is Anonymous: \(isCurrentlyAnonymous)", category: .auth)
        DWLogger.shared.info("  - Guest UID captured: \(guestUidBeforeSignUp ?? "none")", category: .auth)

        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        DWLogger.shared.info("📧 User created: \(result.user.uid)", category: .auth)
        
        // Update display name
        let changeRequest = result.user.createProfileChangeRequest()
        changeRequest.displayName = name
        try await changeRequest.commitChanges()
        
        // Send email verification
        try await result.user.sendEmailVerification()
        DWLogger.shared.info("Email verification sent to: \(email)", category: .auth)
        
        await MainActor.run {
            self.currentUser = result.user
            self.isAuthenticated = true
            self.currentUserId = result.user.uid
            self.currentUserEmail = result.user.email
            self.currentUserName = name
        }
        
        // Transfer guest data to new account
        DWLogger.shared.info("📧 Checking guest data transfer...", category: .auth)
        if let guestUid = guestUidBeforeSignUp {
            DWLogger.shared.info("📧 ✅ Guest data exists → TRANSFERRING from \(guestUid) to \(result.user.uid)", category: .auth)
            await linkGuestDataToNewAccount(guestUserId: guestUid)
        } else {
            DWLogger.shared.info("📧 ℹ️ No guest data to transfer", category: .auth)
        }

        DWLogger.shared.logAuthEvent("Sign Up Success", userId: result.user.uid, details: email)
        DWLogger.shared.logAnalyticsEvent("user_signed_up", parameters: ["method": "email"])
    }
    
    // MARK: - Sign In with Apple
    
    func signInWithApple(credentials: ASAuthorizationAppleIDCredential) async throws {
        DWLogger.shared.info("🍎 signInWithApple called in AuthManager", category: .auth)

        guard let nonce = currentNonce else {
            DWLogger.shared.critical("🍎 Invalid state: A login callback was received, but no login flow is in progress.", category: .auth)
            throw AuthError.invalidCredentials
        }
        DWLogger.shared.debug("🍎 Nonce validated", category: .auth)

        guard let appleIDToken = credentials.identityToken else {
            DWLogger.shared.warning("🍎 Could not find identity token.", category: .auth)
            throw AuthError.invalidCredentials
        }
        DWLogger.shared.debug("🍎 Identity token found", category: .auth)

        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            DWLogger.shared.warning("🍎 Could not stringify identity token.", category: .auth)
            throw AuthError.invalidCredentials
        }
        DWLogger.shared.debug("🍎 ID token string created", category: .auth)

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: credentials.fullName
        )
        DWLogger.shared.info("🍎 Firebase credential created, attempting Sign in with Apple via Firebase", category: .auth)
        
        // Capture current guest UID before sign in (for data transfer)
        let currentUser = Auth.auth().currentUser
        let isCurrentlyAnonymous = currentUser?.isAnonymous ?? false
        let guestUidBeforeSignIn = isCurrentlyAnonymous ? currentUser?.uid : nil

        DWLogger.shared.info("🍎 Pre-login state:", category: .auth)
        DWLogger.shared.info("  - Current User ID: \(currentUser?.uid ?? "none")", category: .auth)
        DWLogger.shared.info("  - Is Anonymous: \(isCurrentlyAnonymous)", category: .auth)
        DWLogger.shared.info("  - Guest UID captured: \(guestUidBeforeSignIn ?? "none")", category: .auth)

        do {
            DWLogger.shared.info("🍎 Calling Firebase Auth.auth().signIn(with:)...", category: .auth)
            let result = try await Auth.auth().signIn(with: firebaseCredential)
            DWLogger.shared.info("🍎 Firebase sign in successful! User: \(result.user.uid)", category: .auth)
            DWLogger.shared.info("🍎 isNewUser: \(result.additionalUserInfo?.isNewUser ?? false)", category: .auth)

            // Update user info if it's the first time
            if let fullName = credentials.fullName {
                DWLogger.shared.debug("🍎 Updating display name with fullName", category: .auth)
                let changeRequest = result.user.createProfileChangeRequest()
                let givenName = fullName.givenName ?? ""
                let familyName = fullName.familyName ?? ""
                changeRequest.displayName = "\(givenName) \(familyName)".trimmingCharacters(in: .whitespacesAndNewlines)
                try await changeRequest.commitChanges()
                await MainActor.run {
                    self.currentUserName = changeRequest.displayName
                }
                DWLogger.shared.debug("🍎 Display name updated", category: .auth)
            }

            await MainActor.run {
                self.currentUser = result.user
                self.isAuthenticated = true
                self.currentUserId = result.user.uid
                self.currentUserEmail = result.user.email
            }
            DWLogger.shared.info("🍎 AuthManager state updated", category: .auth)

            // Transfer guest data to new account ONLY IF it's a new registration
            DWLogger.shared.info("🍎 Checking guest data transfer...", category: .auth)
            DWLogger.shared.info("  - guestUidBeforeSignIn: \(guestUidBeforeSignIn ?? "nil")", category: .auth)
            DWLogger.shared.info("  - isNewUser: \(result.additionalUserInfo?.isNewUser ?? false)", category: .auth)

            if let guestUid = guestUidBeforeSignIn {
                if result.additionalUserInfo?.isNewUser == true {
                    DWLogger.shared.info("🍎 ✅ NEW Apple user + Guest data exists → TRANSFERRING from \(guestUid) to \(result.user.uid)", category: .auth)
                    await linkGuestDataToNewAccount(guestUserId: guestUid)
                } else {
                    DWLogger.shared.warning("🍎 ⚠️ EXISTING Apple user (isNewUser=false) → SKIPPING transfer to prevent abuse", category: .auth)
                }
            } else {
                DWLogger.shared.info("🍎 ℹ️ No guest data to transfer (user was not anonymous before login)", category: .auth)
            }

            DWLogger.shared.logAuthEvent("Sign In with Apple Success", userId: result.user.uid)
            DWLogger.shared.logAnalyticsEvent("user_signed_in", parameters: ["method": "apple"])
            DWLogger.shared.info("🍎 ✅ Apple Sign In completed successfully!", category: .auth)

        } catch {
            DWLogger.shared.error("🍎 ❌ Firebase Apple Sign In failed", error: error, category: .auth)
            throw error
        }
    }
    
    // MARK: - Email Verification
    
    /// Send email verification to current user
    func sendEmailVerification() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.notAuthenticated
        }
        
        try await user.sendEmailVerification()
        DWLogger.shared.info("Email verification sent", category: .auth)
    }
    
    /// Check if current user's email is verified
    var isEmailVerified: Bool {
        return Auth.auth().currentUser?.isEmailVerified ?? false
    }
    
    /// Reload user to get latest email verification status
    func reloadUser() async throws {
        try await Auth.auth().currentUser?.reload()
        await MainActor.run {
            self.currentUser = Auth.auth().currentUser
        }
    }
    
    // MARK: - Password Reset
    
    /// Send password reset email
    func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
        DWLogger.shared.info("Password reset email sent to: \(email)", category: .auth)
    }
    
    // MARK: - Guest / Anonymous Sign In

    /// Explicitly sign in as guest (anonymous user)
    /// Restores previous guest session if user signed out from guest mode
    func continueAsGuest() async throws {
        DWLogger.shared.info("User chose to continue as guest", category: .auth)

        // Check if there's a saved guest ID from previous session
        let savedGuestId = UserDefaults.standard.string(forKey: deviceGuestUserIdKey)
        if let savedId = savedGuestId {
            DWLogger.shared.info("📱 Found saved device guest ID: \(savedId)", category: .auth)
        } else {
            DWLogger.shared.info("📱 No saved guest ID, creating new guest session", category: .auth)
        }

        // Allow anonymous sign-in
        shouldPreventAutoAnonymousSignIn = false

        // Sign in anonymously (Firebase always creates new session)
        let result = try await Auth.auth().signInAnonymously()
        let newGuestId = result.user.uid

        // If we had a previous guest session with a different ID, merge them
        if let savedId = savedGuestId, savedId != newGuestId {
            DWLogger.shared.info("🔄 Merging guest sessions: \(savedId) → \(newGuestId)", category: .auth)
            await mergeGuestSessions(oldGuestId: savedId, newGuestId: newGuestId)
        }

        // Save new guest ID for future
        UserDefaults.standard.set(newGuestId, forKey: deviceGuestUserIdKey)

        DWLogger.shared.logAuthEvent("Guest Mode - Anonymous Sign In Success", userId: result.user.uid)
        DWLogger.shared.logAnalyticsEvent("user_continued_as_guest")
    }

    // MARK: - Sign Out

    func signOut() throws {
        DWLogger.shared.info("Signing out user", category: .auth)

        // 💾 IMPORTANT: Save guest user ID if currently in guest mode
        // This preserves guest purchases when user returns as guest later
        if let currentUser = Auth.auth().currentUser, currentUser.isAnonymous {
            let guestId = currentUser.uid
            UserDefaults.standard.set(guestId, forKey: deviceGuestUserIdKey)
            DWLogger.shared.info("💾 Saved device guest ID for later restore: \(guestId)", category: .auth)
        }

        // Set flag to prevent auto anonymous sign-in
        shouldPreventAutoAnonymousSignIn = true

        try Auth.auth().signOut()

        currentUser = nil
        isAuthenticated = false
        isGuest = true
        currentUserId = nil
        currentUserEmail = nil
        currentUserName = nil
        userState = .guest

        // Clear all caches on logout
        Task { @MainActor in
            AppPreloadService.shared.clearAllCaches()
            DWLogger.shared.info("All caches cleared after logout", category: .auth)
        }

        // Clear auth choice flag so user returns to login screen
        UserDefaults.standard.set(false, forKey: Constants.StorageKeys.hasCompletedAuthChoice)

        DWLogger.shared.logAuthEvent("Sign Out Success")
    }

    // MARK: - Delete Account

    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }

        DWLogger.shared.info("Deleting user account: \(user.uid)", category: .auth)

        // Remove auth state listener to prevent freeze
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
            self.handle = nil
        }

        do {
            // 1. Call Backend to delete user data (Stories, Characters, DB Record)
            DWLogger.shared.info("Calling backend to delete user data...", category: .auth)
            
            struct DeleteResponse: Codable {
                let success: Bool
                let message: String?
            }
            
            let _: DeleteResponse = try await APIClient.shared.makeRequest(
                endpoint: "/api/user/delete",
                method: .delete
            )
            
            DWLogger.shared.info("Backend data deleted successfully", category: .auth)
            
            // 2. Delete user from Firebase Auth
            try await user.delete()
            
            // 3. Clear ALL caches to prevent stale data
            Task { @MainActor in
                AppPreloadService.shared.clearAllCaches()
                DWLogger.shared.info("All caches cleared after account deletion", category: .auth)
            }
            
            // 4. Clear local state
            await MainActor.run {
                currentUser = nil
                isAuthenticated = false
                isGuest = true
                currentUserId = nil
                currentUserEmail = nil
                currentUserName = nil
                userState = .guest
                
                // Prevent auto anonymous sign in until user explicitly chooses
                shouldPreventAutoAnonymousSignIn = true
                
                // Clear auth choice flag so user returns to login screen
                UserDefaults.standard.set(false, forKey: Constants.StorageKeys.hasCompletedAuthChoice)
            }

            DWLogger.shared.logAuthEvent("Account and Data Deleted Successfully")
            
        } catch {
            DWLogger.shared.error("Delete account failed: \(error.localizedDescription)", category: .auth)
            
            // Re-register auth listener if deletion fails so app continues to work
            registerAuthStateHandler()
            throw error
        }
    }

    // MARK: - Password Reset
    
    func resetPassword(email: String) async throws {
        DWLogger.shared.info("Password reset requested: \(email)", category: .auth)
        
        try await Auth.auth().sendPasswordReset(withEmail: email)
        
        DWLogger.shared.logAuthEvent("Password Reset Email Sent", details: email)
    }
    
    // MARK: - Get Auth Token
    
    func getAuthToken() async throws -> String {
        guard let user = currentUser else {
            throw AuthError.notAuthenticated
        }
        
        return try await user.getIDToken()
    }
    
    // MARK: - Print Token for Testing
    
    /// Prints the current user's Firebase auth token to console for testing backend API
    func printAuthTokenForTesting() {
        Task {
            do {
                let token = try await getAuthToken()
                print("\n" + String(repeating: "=", count: 80))
                print("🔑 FIREBASE AUTH TOKEN FOR TESTING")
                print(String(repeating: "=", count: 80))
                print(token)
                print(String(repeating: "=", count: 80))
                print("\n📋 Token copied to console. Use this in your curl commands:")
                print("curl -H \"Authorization: Bearer \(token)\" ...")
                print(String(repeating: "=", count: 80) + "\n")
                
                DWLogger.shared.info("Auth token printed for testing", category: .auth)
            } catch {
                print("❌ Error getting token: \(error.localizedDescription)")
                DWLogger.shared.error("Failed to get token: \(error.localizedDescription)", category: .auth)
            }
        }
    }
    
    // MARK: - Guest Data Transfer

    /// Merges two guest sessions (when user returns as guest after sign out)
    /// This preserves purchases made in the old guest session
    private func mergeGuestSessions(oldGuestId: String, newGuestId: String) async {
        DWLogger.shared.info("🔄 [MERGE-GUEST] STARTING merge from \(oldGuestId) to \(newGuestId)", category: .auth)

        do {
            struct MergeGuestResponse: Codable {
                let success: Bool
                let message: String?
                let merged: MergedData?

                struct MergedData: Codable {
                    let stories: Int
                    let coins: Int
                }
            }

            DWLogger.shared.info("🔄 [MERGE-GUEST] Calling API endpoint...", category: .auth)

            let response: MergeGuestResponse = try await APIClient.shared.makeRequest(
                endpoint: "/api/user/merge-guest-sessions",
                method: .post,
                body: ["oldGuestId": oldGuestId, "newGuestId": newGuestId]
            )

            if response.success, let merged = response.merged {
                DWLogger.shared.info("✅ [MERGE-GUEST] SUCCESS: \(merged.stories) stories, \(merged.coins) coins merged", category: .auth)

                // Clear caches to reload merged data
                await MainActor.run {
                    AppPreloadService.shared.clearAllCaches()
                }

                // Show user notification if any data was merged
                if merged.coins > 0 || merged.stories > 0 {
                    await MainActor.run {
                        var details: [String] = []
                        if merged.coins > 0 {
                            let coinsStr = String(format: NSLocalizedString("coins_count_format", comment: ""), merged.coins)
                            details.append(coinsStr)
                        }
                        if merged.stories > 0 {
                            let storiesStr = String(format: NSLocalizedString("stories_count", comment: ""), merged.stories)
                            details.append(storiesStr)
                        }

                        let welcomeTitle = NSLocalizedString("alert_welcome_back", comment: "")
                        let message = details.isEmpty ?
                            welcomeTitle :
                            welcomeTitle + "\n" + details.joined(separator: ", ")

                        GlassAlertManager.shared.info(message, duration: 3.0)
                    }
                }
            }
        } catch {
            // Non-critical - log and continue
            DWLogger.shared.error("❌ [MERGE-GUEST] FAILED: \(error.localizedDescription)", category: .auth)
        }
    }

    /// Transfers data from guest account to newly authenticated account
    private func linkGuestDataToNewAccount(guestUserId: String) async {
        DWLogger.shared.info("🔄 [LINK-GUEST-DATA] STARTING transfer from \(guestUserId)", category: .auth)
        DWLogger.shared.info("🔄 [LINK-GUEST-DATA] Current user: \(Auth.auth().currentUser?.uid ?? "none")", category: .auth)

        do {
            // Response struct
            struct LinkGuestResponse: Codable {
                let success: Bool
                let message: String?
                let transferred: TransferredData?

                struct TransferredData: Codable {
                    let stories: Int
                    let coins: Int
                    let characters: Int
                }
            }

            DWLogger.shared.info("🔄 [LINK-GUEST-DATA] Calling API endpoint...", category: .auth)

            let response: LinkGuestResponse = try await APIClient.shared.makeRequest(
                endpoint: "/api/user/link-guest-data",
                method: .post,
                body: ["guestUserId": guestUserId]
            )

            DWLogger.shared.info("🔄 [LINK-GUEST-DATA] API response received: success=\(response.success)", category: .auth)

            if response.success, let transferred = response.transferred {
                DWLogger.shared.info("✅ [LINK-GUEST-DATA] SUCCESS: \(transferred.stories) stories, \(transferred.coins) coins, \(transferred.characters) characters", category: .auth)

                // Clear local caches to force reload with new data
                await MainActor.run {
                    AppPreloadService.shared.clearAllCaches()
                }

                // Show user notification if any data was transferred
                if transferred.coins > 0 || transferred.stories > 0 || transferred.characters > 0 {
                    await MainActor.run {
                        var details: [String] = []
                        if transferred.coins > 0 {
                            let coinsStr = String(format: NSLocalizedString("coins_count_format", comment: ""), transferred.coins)
                            details.append(coinsStr)
                        }
                        if transferred.stories > 0 {
                            let storiesStr = String(format: NSLocalizedString("stories_count", comment: ""), transferred.stories)
                            details.append(storiesStr)
                        }
                        if transferred.characters > 0 {
                            let charsStr = String(format: NSLocalizedString("character_count", comment: ""), transferred.characters)
                            details.append(charsStr)
                        }

                        let linkedTitle = NSLocalizedString("alert_account_linked", comment: "")
                        let message = details.isEmpty ?
                            linkedTitle :
                            linkedTitle + "\n" + details.joined(separator: ", ")

                        GlassAlertManager.shared.success(message, duration: 3.0)
                    }
                }
            }
        } catch {
            // Non-critical - just log and continue
            DWLogger.shared.error("❌ [LINK-GUEST-DATA] FAILED: \(error.localizedDescription)", category: .auth)
            if let apiError = error as? APIError {
                DWLogger.shared.error("❌ [LINK-GUEST-DATA] API Error details: \(apiError)", category: .auth)
            }
        }
    }
    
    // MARK: - Nonce Helpers for Sign In with Apple
    
    /// Generate a random nonce string for Apple Sign In
    func generateNonce() -> String {
        return randomNonceString()
    }
    
    /// Hash a nonce string with SHA256 for Apple Sign In
    func hashNonce(_ input: String) -> String {
        return sha256(input)
    }
}

// MARK: - Nonce Generators
// These helpers are used for Sign In with Apple
fileprivate func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    
    let charset = "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._"
    
    var result = ""
    for _ in 0..<length {
        guard let randomChar = charset.randomElement() else {
            fatalError("Unable to generate random character")
        }
        result.append(randomChar)
    }
    
    return result
}

@available(iOS 13, *)
fileprivate func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashedData = SHA256.hash(data: inputData)
    let hashString = hashedData.compactMap {
        String(format: "%02x", $0)
    }.joined()
    
    return hashString
}


// MARK: - User State

enum UserState: Equatable {
    case guest
    case authenticated
    
    var description: String {
        switch self {
        case .guest:
            return "Guest"
        case .authenticated:
            return "Authenticated"
        }
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case notAuthenticated
    case notImplemented
    case invalidCredentials
    case userNotFound
    case emailAlreadyInUse
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Lütfen giriş yapın"
        case .notImplemented:
            return "Bu özellik henüz eklenmedi"
        case .invalidCredentials:
            return "Geçersiz e-posta veya şifre"
        case .userNotFound:
            return "Kullanıcı bulunamadı"
        case .emailAlreadyInUse:
            return "Bu e-posta adresi zaten kullanımda"
        }
    }
}


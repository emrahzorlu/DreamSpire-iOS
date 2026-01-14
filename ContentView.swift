//
//  ContentView.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var appState: AppState = .splash

    enum AppState {
        case splash
        case onboarding
        case auth
        case home
    }

    var body: some View {
        ZStack {
            // Always render background to prevent black screen
            LinearGradient.dwBackground
                .ignoresSafeArea()

            Group {
                switch appState {
                case .splash:
                    SplashView {
                        // Check if user has seen onboarding
                        if hasSeenOnboarding() {
                            // Check if user has COMPLETED their auth choice (login/signup/guest)
                            // This prevents users stuck on login screen from auto-entering as guest
                            if hasCompletedAuthChoice() && authManager.isAuthenticated {
                                // User already has a session AND completed auth flow, go directly to home
                                appState = .home
                            } else {
                                // Either: no session, or user was on login screen (didn't complete auth)
                                // Show login screen
                                appState = .auth
                            }
                        } else {
                            appState = .onboarding
                        }
                    }

                case .onboarding:
                    EnchantedOnboardingView { result in
                        markOnboardingComplete()
                        switch result {
                        case .guest:
                            // Guest mode - will create anonymous user in LoginView
                            appState = .auth
                        case .login, .createAccount:
                            appState = .auth
                        }
                    }
                    .transition(.opacity)

                case .auth:
                    // LoginView will be responsible for handling both login and sign-up.
                    // It will call the onAuthenticated closure upon success.
                    LoginView(onAuthenticated: {
                        // Mark that user completed their auth choice
                        markAuthChoiceComplete()
                        appState = .home
                    })
                    .transition(.opacity)

                case .home:
                    HomeView(onSignOut: {
                        // After sign out, clear auth choice so user sees login screen
                        clearAuthChoice()
                        appState = .auth
                    })
                    .transition(.opacity)
                }
            }
        }
        .onChange(of: authManager.isAuthenticated) { _, newValue in
            // If user signs out from anywhere, go back to auth screen
            if !newValue && appState == .home {
                clearAuthChoice()
                appState = .auth
            }
        }
    }

    private func hasSeenOnboarding() -> Bool {
        return UserDefaults.standard.bool(forKey: Constants.StorageKeys.hasSeenOnboarding)
    }

    private func markOnboardingComplete() {
        UserDefaults.standard.set(true, forKey: Constants.StorageKeys.hasSeenOnboarding)
        DWLogger.shared.info("Onboarding marked as complete", category: .general)
    }
    
    private func hasCompletedAuthChoice() -> Bool {
        return UserDefaults.standard.bool(forKey: Constants.StorageKeys.hasCompletedAuthChoice)
    }
    
    private func markAuthChoiceComplete() {
        UserDefaults.standard.set(true, forKey: Constants.StorageKeys.hasCompletedAuthChoice)
        DWLogger.shared.info("Auth choice marked as complete", category: .auth)
    }
    
    private func clearAuthChoice() {
        UserDefaults.standard.set(false, forKey: Constants.StorageKeys.hasCompletedAuthChoice)
        DWLogger.shared.info("Auth choice cleared", category: .auth)
    }
}

#Preview {
    ContentView()
}

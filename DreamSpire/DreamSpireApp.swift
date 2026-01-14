//
//  DreamSpireApp.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 1.11.2025.
//

import SwiftUI
import UIKit
import FirebaseCore
import FirebaseAnalytics
import UserNotifications
import FirebaseMessaging

// MARK: - App Delegate for Orientation Lock and Notifications
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait // Force portrait mode only
    }
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Set APNs token to Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken

        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("✅ APNs Device Token: \(token)")

        #if DEBUG
        // After setting APNs token, fetch FCM token
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            Messaging.messaging().token { fcmToken, error in
                if let error = error {
                    print("❌ Error fetching FCM token: \(error)")
                } else if let fcmToken = fcmToken {
                    print("🔥 FCM Registration Token: \(fcmToken)")
                }
            }
        }
        #endif
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
}

@main
struct DreamSpireApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var coinService = CoinService.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var jobManager = GenerationJobManager.shared
    
    init() {
        // Configure Firebase FIRST
        FirebaseApp.configure()
        
        // Enable Firebase Analytics
        Analytics.setAnalyticsCollectionEnabled(true)
        
        // Initialize LocalizationManager to load saved language
        _ = LocalizationManager.shared
        
        // Setup notification delegate
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        Messaging.messaging().delegate = NotificationManager.shared
        
        // MARK: - Global UI Appearance
        // Set pull-to-refresh loading indicator to white globally
        UIRefreshControl.appearance().tintColor = .white
        
        setupApp()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(coinService)
                .tint(.white) // Set global tint color to white for text field underlines
                .withGlassAlerts() // ✅ Global Glass Alert System
                .withGlassDialogs() // ✅ Global Glass Dialog System
                .onAppear {
                    DWLogger.shared.logViewAppear("ContentView")
                    
                    // Track app opened
                    AnalyticsManager.shared.trackAppOpened()
                    
                    // Resume polling for active jobs
                    Task {
                        await jobManager.resumeAllPolling()
                        // Ensure notification status is checked and remote registration happens
                        await notificationManager.checkPermissionStatus()
                    }

                    #if DEBUG
                    // Auto-print token when user is authenticated (DEBUG only)
                    if authManager.isAuthenticated {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            authManager.printAuthTokenForTesting()
                        }
                    }
                    #endif
                }
        }
    }
    
    private func setupApp() {
        // Log app launch
        DWLogger.shared.logAppLaunch()
        
        // Configure logger
        #if DEBUG
        DWLogger.shared.logLevel = .debug
        DWLogger.shared.info("Running in DEBUG mode", category: .general)
        #else
        DWLogger.shared.logLevel = .info
        DWLogger.shared.info("Running in RELEASE mode", category: .general)
        #endif
        
        // Log configuration
        logConfiguration()
    }
    
    private func logConfiguration() {
        DWLogger.shared.info("""
        
        ╔═════════════════════════════════════════════════════
        ║ 🔧 APP CONFIGURATION
        ╠═════════════════════════════════════════════════════
        ║ Backend URL: \(Constants.API.baseURL)
        ║ Default Language: \(Constants.App.defaultLanguage)
        ║ Log Level: \(DWLogger.shared.logLevel)
        ║ Free Stories: \(Constants.Subscription.freeStoriesPerMonth)/month
        ║ Plus Price: $\(Constants.Subscription.plusMonthlyPrice)
        ║ Pro Price: $\(Constants.Subscription.proMonthlyPrice)
        ╚═════════════════════════════════════════════════════
        
        """, category: .general)
    }
}

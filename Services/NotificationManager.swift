//
//  NotificationManager.swift
//  DreamSpire
//
//  Manages local notifications for story generation completion
//

import Foundation
import UserNotifications
import UIKit
import FirebaseMessaging

@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var permissionGranted: Bool = false
    @Published var permissionStatus: UNAuthorizationStatus = .notDetermined
    
    private let notificationCenter = UNUserNotificationCenter.current()

    nonisolated override private init() {
        super.init()
    }
    
    // MARK: - Permission Management
    
    /// Check current notification permission status
    func checkPermissionStatus() async {
        let settings = await notificationCenter.notificationSettings()
        permissionStatus = settings.authorizationStatus
        permissionGranted = settings.authorizationStatus == .authorized
        
        DWLogger.shared.info("Notification permission status: \(settings.authorizationStatus.rawValue)", category: .app)
        
        // Ensure remote registration happens even if permission was already granted previously
        if permissionGranted {
            await MainActor.run {
                if !UIApplication.shared.isRegisteredForRemoteNotifications {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    /// Request notification permission from user
    /// - Returns: True if permission granted
    @discardableResult
    func requestPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            
            await checkPermissionStatus()
            
            if granted {
                DWLogger.shared.info("Notification permission granted", category: .app)
                DWLogger.shared.logAnalyticsEvent("notification_permission_granted")
                
                // Register for remote notifications on main thread
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                DWLogger.shared.warning("Notification permission denied", category: .app)
                DWLogger.shared.logAnalyticsEvent("notification_permission_denied")
            }
            
            return granted
        } catch {
            DWLogger.shared.error("Failed to request notification permission", error: error, category: .app)
            return false
        }
    }
    
    // MARK: - Story Completion Notifications
    
    /// Schedule a notification for when story generation completes
    /// - Parameters:
    ///   - storyTitle: Title of the story being generated
    ///   - jobId: Job ID for tracking
    ///   - estimatedSeconds: Estimated time until completion (for scheduling)
    func scheduleStoryCompletionNotification(
        storyTitle: String,
        jobId: String,
        estimatedSeconds: TimeInterval = 180 // Default 3 minutes
    ) async {
        // Check permission first
        guard permissionGranted else {
            DWLogger.shared.warning("Cannot schedule notification - permission not granted", category: .app)
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "notification_story_ready_title".localized
        content.body = String(format: "notification_story_ready_body".localized, storyTitle)
        content.sound = .default
        content.badge = NSNumber(value: await getCurrentBadgeCount() + 1)
        
        // Add userInfo for deep linking
        content.userInfo = [
            "type": "story_completed",
            "jobId": jobId,
            "storyTitle": storyTitle
        ]
        
        // Schedule for estimated completion time (with buffer)
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(10, estimatedSeconds),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "story_\(jobId)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await notificationCenter.add(request)
            DWLogger.shared.info("Scheduled notification for story: \(storyTitle)", category: .app)
        } catch {
            DWLogger.shared.error("Failed to schedule notification", error: error, category: .app)
        }
    }
    
    /// Send immediate notification when story is ready
    /// - Parameters:
    ///   - storyTitle: Title of the completed story
    ///   - storyId: Story ID for deep linking
    func sendStoryReadyNotification(storyTitle: String, storyId: String) async {
        guard permissionGranted else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "notification_story_ready_title".localized
        content.body = String(format: "notification_story_ready_body".localized, storyTitle)
        content.sound = .default
        content.badge = NSNumber(value: await getCurrentBadgeCount() + 1)
        
        // Add userInfo for deep linking
        content.userInfo = [
            "type": "story_ready",
            "storyId": storyId,
            "storyTitle": storyTitle
        ]
        
        // Immediate trigger (1 second delay)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "story_ready_\(storyId)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await notificationCenter.add(request)
            DWLogger.shared.info("Sent story ready notification: \(storyTitle)", category: .app)
            DWLogger.shared.logAnalyticsEvent("notification_story_ready_sent", parameters: [
                "story_id": storyId,
                "story_title": storyTitle
            ])
        } catch {
            DWLogger.shared.error("Failed to send notification", error: error, category: .app)
        }
    }
    
    // MARK: - Badge Management
    
    /// Get current badge count
    private func getCurrentBadgeCount() async -> Int {
        return await UIApplication.shared.applicationIconBadgeNumber
    }
    
    /// Update badge count
    func updateBadgeCount(_ count: Int) async {
        if #available(iOS 16.0, *) {
            try? await UNUserNotificationCenter.current().setBadgeCount(count)
        } else {
            await MainActor.run {
                UIApplication.shared.applicationIconBadgeNumber = count
            }
        }
        DWLogger.shared.debug("Updated badge count to: \(count)", category: .app)
    }
    
    /// Clear badge count
    func clearBadge() async {
        await updateBadgeCount(0)
    }
    
    /// Increment badge count
    func incrementBadge() async {
        let current = await getCurrentBadgeCount()
        await updateBadgeCount(current + 1)
    }
    
    /// Decrement badge count
    func decrementBadge() async {
        let current = await getCurrentBadgeCount()
        await updateBadgeCount(max(0, current - 1))
    }
    
    // MARK: - Notification Management
    
    /// Cancel a specific notification
    func cancelNotification(identifier: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        DWLogger.shared.debug("Cancelled notification: \(identifier)", category: .app)
    }
    
    /// Cancel all story-related notifications
    func cancelAllStoryNotifications() async {
        let pending = await notificationCenter.pendingNotificationRequests()
        let storyNotifications = pending.filter { $0.identifier.hasPrefix("story_") }
        let identifiers = storyNotifications.map { $0.identifier }
        
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        DWLogger.shared.info("Cancelled \(identifiers.count) story notifications", category: .app)
    }
    
    /// Get all pending notifications
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await notificationCenter.pendingNotificationRequests()
    }
}

// MARK: - Notification Handling Delegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    /// Handle notification when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    /// Handle notification tap
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        Task { @MainActor in
            await handleNotificationTap(userInfo: userInfo)
        }
        
        completionHandler()
    }
    
    /// Handle notification tap and navigate to library
    private func handleNotificationTap(userInfo: [AnyHashable: Any]) async {
        guard let type = userInfo["type"] as? String else { return }

        switch type {
        case "story_ready", "story_completed":
            // Navigate to library tab to show the completed story
            NotificationCenter.default.post(
                name: .navigateToLibrary,
                object: nil
            )

            if let storyId = userInfo["storyId"] as? String {
                DWLogger.shared.logUserAction("Opened Library from Story Notification", details: storyId)
            } else {
                DWLogger.shared.logUserAction("Opened Library from Story Notification", details: "unknown")
            }

        default:
            break
        }

        // Decrement badge
        await decrementBadge()
    }
}

// MARK: - Firebase Messaging Delegate

extension NotificationManager: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        
        // Log token
        print("\n🔥 Firebase Registration Token: \(token)\n")
        
        let dataDict: [String: String] = ["token": token]
        NotificationCenter.default.post(
            name: Notification.Name("FCMToken"),
            object: nil,
            userInfo: dataDict
        )
        
        // Send token to backend
        Task {
            await saveDeviceToken(token)
        }
    }
    
    /// Send FCM token to backend
    private nonisolated func saveDeviceToken(_ token: String) async {
        // Only send if user is logged in (auth token available)
        // Check AuthManager.shared.isAuthenticated but safely since we are nonisolated
        
        // Actually, we can just try sending it. If 401, it fails gracefully.
        // Or we can construct a request.
        
        do {
            if await AuthManager.shared.isAuthenticated {
                DWLogger.shared.info("Sending FCM token to backend...", category: .app)
                
                // Get current language and timezone for localized notifications
                let currentLanguage = await MainActor.run {
                    LocalizationManager.shared.currentLanguage.rawValue
                }
                let currentTimezone = TimeZone.current.identifier
                
                struct TokenRequest: Codable {
                    let token: String
                    let platform: String
                    let language: String
                    let timezone: String
                }
                
                struct TokenResponse: Codable {
                    let success: Bool
                }
                
                let _: TokenResponse = try await APIClient.shared.makeRequest(
                    endpoint: "/api/user/device-token",
                    method: .post,
                    body: TokenRequest(
                        token: token,
                        platform: "ios",
                        language: currentLanguage,
                        timezone: currentTimezone
                    )
                )
                
                DWLogger.shared.info("✅ FCM token saved to backend (lang: \(currentLanguage), tz: \(currentTimezone))", category: .app)
            }
        } catch {
            // It might fail if user is not logged in yet, thats fine.
            // We should arguably also send it upon login.
            DWLogger.shared.warning("Failed to save FCM token: \(error.localizedDescription)", category: .app)
        }
    }

}

// MARK: - Notification Names

extension Notification.Name {
    static let openStory = Notification.Name("openStory")
}

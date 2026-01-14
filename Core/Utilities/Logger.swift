//
//  DWLogger.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025-11-02.
//

import Foundation
import OSLog

/// DreamSpire unified logging system
class DWLogger {
    static let shared = DWLogger()
    
    private let logger: Logger
    var logLevel: LogLevel = .debug
    
    enum LogLevel: String {
        case debug = "Debug"
        case info = "Info"
        case warning = "Warning"
        case error = "Error"
        case critical = "Critical"
    }
    
    private init() {
        self.logger = Logger(subsystem: Constants.App.bundleIdentifier, category: "DreamSpire")
    }
    
    // MARK: - Log Levels
    
    func debug(_ message: String, category: LogCategory = .general) {
        logger.debug("[\(category.rawValue)] \(message)")
    }
    
    func info(_ message: String, category: LogCategory = .general) {
        logger.info("[\(category.rawValue)] \(message)")
    }
    
    func warning(_ message: String, category: LogCategory = .general) {
        logger.warning("[\(category.rawValue)] ⚠️ \(message)")
    }
    
    func error(_ message: String, error: Error? = nil, category: LogCategory = .general) {
        if let error = error {
            logger.error("[\(category.rawValue)] ❌ \(message) - Error: \(error.localizedDescription)")
        } else {
            logger.error("[\(category.rawValue)] ❌ \(message)")
        }
    }
    
    func critical(_ message: String, error: Error? = nil, category: LogCategory = .general) {
        if let error = error {
            logger.critical("[\(category.rawValue)] 🔥 \(message) - Error: \(error.localizedDescription)")
        } else {
            logger.critical("[\(category.rawValue)] 🔥 \(message)")
        }
    }
    
    // MARK: - Convenience Method (for backward compatibility)
    
    /// Logs an error with context
    func logError(_ error: Error, context: String, category: LogCategory = .general) {
        self.error(context, error: error, category: category)
    }
    
    // MARK: - Specialized Logging
    
    // MARK: Network Logging
    
    func logNetworkRequest(url: String, method: String, headers: [String: String]?, body: Data?) {
        var message = "🌐 Request: \(method) \(url)"
        
        if let headers = headers, !headers.isEmpty {
            message += "\nHeaders: \(headers)"
        }
        
        if let body = body, let bodyString = String(data: body, encoding: .utf8) {
            message += "\nBody: \(bodyString)"
        }
        
        debug(message, category: .network)
    }
    
    func logNetworkResponse(url: String, statusCode: Int, data: Data?, error: Error?, duration: TimeInterval) {
        var message = "🌐 Response: \(statusCode) \(url) (\(String(format: "%.2f", duration))s)"
        
        if let error = error {
            message += "\nError: \(error.localizedDescription)"
        }
        
        if let data = data {
            message += "\nSize: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))"
        }
        
        if statusCode >= 200 && statusCode < 300 {
            debug(message, category: .network)
        } else {
            self.error(message, error: nil, category: .network)
        }
    }
    
    // MARK: API Logging
    
    func logAPISuccess(endpoint: String, duration: TimeInterval) {
        info("✅ API Success: \(endpoint) (\(String(format: "%.2f", duration))s)", category: .api)
    }
    
    func logAPIError(endpoint: String, error: Error, duration: TimeInterval) {
        self.error("❌ API Failed: \(endpoint) (\(String(format: "%.2f", duration))s)", error: error, category: .api)
    }
    
    // MARK: Auth Logging
    
    func logAuthEvent(_ event: String, userId: String? = nil, details: String? = nil) {
        var message = "🔐 Auth: \(event)"
        
        if let userId = userId {
            message += " - User: \(userId)"
        }
        
        if let details = details {
            message += " - \(details)"
        }
        
        info(message, category: .auth)
    }
    
    // MARK: Story Logging
    
    func logStoryCreationStart(prompt: String, characters: Int) {
        info("📖 Story Creation Started - Characters: \(characters), Prompt: \(prompt.prefix(50))...", category: .story)
    }
    
    func logStoryCreationComplete(storyId: String, duration: TimeInterval, pages: Int, isIllustrated: Bool) {
        info("✅ Story Created: \(storyId) - Pages: \(pages), Illustrated: \(isIllustrated), Duration: \(String(format: "%.2f", duration))s", category: .story)
    }
    
    func logStoryCreationProgress(stage: String, progress: Double) {
        debug("📝 Story Generation: \(stage) - \(Int(progress * 100))%", category: .story)
    }
    
    // MARK: Character Logging
    
    func logCharacterAction(_ action: String, characterName: String) {
        info("👤 Character: \(action) - \(characterName)", category: .character)
    }
    
    // MARK: Analytics Logging
    
    func logAnalyticsEvent(_ eventName: String, parameters: [String: Any]? = nil) {
        guard Constants.FeatureFlags.enableAnalytics else { return }
        
        var message = "📊 Analytics: \(eventName)"
        
        if let parameters = parameters {
            let paramString = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            message += " - \(paramString)"
        }
        
        debug(message, category: .analytics)
        
        // TODO: Send to Firebase Analytics
        // Analytics.logEvent(eventName, parameters: parameters)
    }
    
    // MARK: User Action Logging
    
    func logUserAction(_ action: String, details: String? = nil) {
        var message = "👆 User Action: \(action)"
        
        if let details = details {
            message += " - \(details)"
        }
        
        debug(message, category: .ui)
    }
    
    // MARK: Performance Logging
    
    func logPerformance(_ metric: String, duration: TimeInterval) {
        info("⚡️ Performance: \(metric) - \(String(format: "%.2f", duration))s", category: .performance)
    }
    
    // MARK: Cache Logging
    
    func logCacheEvent(_ event: String, key: String) {
        debug("💾 Cache: \(event) - \(key)", category: .cache)
    }
    
    // MARK: Subscription Logging
    
    func logSubscriptionEvent(_ event: String, tier: String? = nil, details: String? = nil) {
        var message = "💎 Subscription: \(event)"
        
        if let tier = tier {
            message += " - Tier: \(tier)"
        }
        
        if let details = details {
            message += " - \(details)"
        }
        
        info(message, category: .subscription)
    }
    
    // MARK: - View Lifecycle Logging
    
    func logViewAppear(_ viewName: String) {
        debug("👁️ View Appeared: \(viewName)", category: .ui)
    }
    
    func logAppLaunch() {
        info("🚀 App Launched", category: .general)
    }
    
    func logLevel(_ level: String, message: String) {
        switch level.lowercased() {
        case "debug":
            debug(message)
        case "info":
            info(message)
        case "warning":
            warning(message)
        case "error":
            self.error(message)
        case "critical":
            critical(message)
        default:
            debug(message)
        }
    }
}

// MARK: - Log Category

enum LogCategory: String {
    case general = "General"
    case network = "Network"
    case api = "API"
    case auth = "Auth"
    case story = "Story"
    case character = "Character"
    case ui = "UI"
    case analytics = "Analytics"
    case audio = "Audio"
    case subscription = "Subscription"
    case cache = "Cache"
    case performance = "Performance"
    case data = "Data"
    case app = "App"
    case coin = "Coin"
}

// MARK: - Log Formatting Helpers

extension DWLogger {
    /// Format bytes to human readable string
    static func formatBytes(_ bytes: Int64) -> String {
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    
    /// Format duration to human readable string
    static func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return String(format: "%.0fms", duration * 1000)
        } else if duration < 60 {
            return String(format: "%.2fs", duration)
        } else {
            let minutes = Int(duration / 60)
            let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(seconds)s"
        }
    }
}

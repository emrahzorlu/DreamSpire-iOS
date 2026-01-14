//
//  GenerationJobState.swift
//  DreamSpire
//
//  Model for tracking story generation jobs
//

import Foundation

struct GenerationJobState: Codable, Identifiable {
    let id: String // jobId
    let storyTitle: String
    var progress: Double // 0.0 - 1.0
    var status: String
    let createdAt: Date
    let startTime: Date
    var lastUpdateTime: Date
    var estimatedCompletionTime: Date?

    // Story metadata
    let userId: String
    var storyId: String?

    // Error tracking
    var error: String? // Technical error message
    var userFriendlyError: String? // User-friendly error message
    var errorCategory: String? // content_safety, timeout, rate_limit, network, unknown
    var coinsRefunded: Bool? // Whether coins were refunded
    var originalRequest: CreateStoryWithCoinsRequest? // Stored request for automatic retry

    // Notification tracking
    var shouldNotify: Bool // User wants to be notified when complete
    var notificationScheduled: Bool
    var notificationSent: Bool

    init(
        jobId: String,
        storyTitle: String,
        userId: String,
        progress: Double = 0.0,
        status: String = "pending",
        shouldNotify: Bool = false
    ) {
        self.id = jobId
        self.storyTitle = storyTitle
        self.userId = userId
        self.progress = progress
        self.status = status
        self.createdAt = Date()
        self.startTime = Date()
        self.lastUpdateTime = Date()
        self.error = nil
        self.userFriendlyError = nil
        self.errorCategory = nil
        self.coinsRefunded = nil
        self.shouldNotify = shouldNotify
        self.notificationScheduled = false
        self.notificationSent = false
    }
    
    var isCompleted: Bool {
        status.lowercased() == "completed" || storyId != nil
    }
    
    var isFailed: Bool {
        status.lowercased() == "failed" || status.lowercased() == "error"
    }
    
    var isActive: Bool {
        !isCompleted && !isFailed
    }
    
    var elapsedTime: TimeInterval {
        Date().timeIntervalSince(startTime)
    }
    
    var estimatedRemainingTime: TimeInterval? {
        guard let estimatedCompletion = estimatedCompletionTime else { return nil }
        let remaining = estimatedCompletion.timeIntervalSince(Date())
        return max(0, remaining)
    }
}

// MARK: - UserDefaults Keys

extension GenerationJobState {
    static let storageKey = "com.dreamweaver.generationJobs"
}

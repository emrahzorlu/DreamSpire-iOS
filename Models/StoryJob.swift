//
//  StoryJob.swift
//  DreamSpire
//
//  Created by DreamSpire Team on 12/22/24.
//

import Foundation

// MARK: - Story Job Models

struct StoryJobStatusResponse: Codable {
    let success: Bool
    let job: StoryJob
}

struct StoryJob: Codable {
    let jobId: String
    let status: String  // pending, processing, completed, failed
    let progress: Double
    let currentStep: String?
    let storyId: String?
    let error: String?
    let userFriendlyError: String?
    let errorCategory: String?
    let coinsRefunded: Bool?
    let createdAt: Date
    let updatedAt: Date
    let completedAt: Date?

    var isCompleted: Bool {
        return status == "completed"
    }

    var isFailed: Bool {
        return status == "failed"
    }

    var isProcessing: Bool {
        return status == "processing" || status == "pending"
    }
}

// MARK: - Story Response

struct StoryResponse: Codable {
    let success: Bool
    let story: Story
}

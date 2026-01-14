//
//  GeneratingStoryInfo.swift
//  DreamSpire
//
//  Tracks individual story generation with real-time status
//

import Foundation

struct GeneratingStoryInfo: Identifiable {
    let id: String
    let storyId: String
    var status: StoryGenerationStatus
    let startedAt: Date
    
    var isCompleted: Bool {
        status.isCompleted
    }
    
    var isFailed: Bool {
        status.isFailed
    }
}

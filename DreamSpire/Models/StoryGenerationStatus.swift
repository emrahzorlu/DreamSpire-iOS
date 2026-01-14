//
//  StoryGenerationStatus.swift
//  DreamSpire
//
//  Real-time story generation status tracking
//  Polls backend for step-by-step progress updates
//

import Foundation

// MARK: - Generation Step
enum StoryGenerationStep: String, Codable {
    case initializing
    case writing
    case audio
    case cover
    case finalizing
    case completed
    case failed
    
    var displayName: String {
        switch self {
        case .initializing:
            return "story_gen_initializing".localized
        case .writing:
            return "story_gen_writing".localized
        case .audio:
            return "story_gen_audio".localized
        case .cover:
            return "story_gen_cover".localized
        case .finalizing:
            return "story_gen_finalizing".localized
        case .completed:
            return "story_gen_completed".localized
        case .failed:
            return "story_gen_failed".localized
        }
    }
    
    var icon: String {
        switch self {
        case .initializing:
            return "sparkles"
        case .writing:
            return "pencil.line"
        case .audio:
            return "waveform"
        case .cover:
            return "photo.on.rectangle"
        case .finalizing:
            return "checkmark.circle"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }
    
    var order: Int {
        switch self {
        case .initializing: return 0
        case .writing: return 1
        case .audio: return 2
        case .cover: return 3
        case .finalizing: return 4
        case .completed: return 5
        case .failed: return -1
        }
    }
}

// MARK: - Status Response
struct StoryGenerationStatusResponse: Codable {
    let success: Bool
    let status: StoryGenerationStatus
}

// MARK: - Generation Status
struct StoryGenerationStatus: Codable {
    let storyId: String
    let step: StoryGenerationStep
    let progress: Int
    let message: String
    let content: ContentStatus?
    let cover: MediaStatus?
    let audio: MediaStatus?
    let isGenerating: Bool
    let error: ErrorInfo?
    
    struct ContentStatus: Codable {
        let ready: Bool
        let title: String?
        let pageCount: Int?
    }
    
    struct MediaStatus: Codable {
        let ready: Bool
        let url: String?
    }
    
    struct ErrorInfo: Codable {
        let message: String
        let name: String
    }
    
    var isCompleted: Bool {
        step == .completed
    }
    
    var isFailed: Bool {
        step == .failed
    }
    
    var progressPercent: Double {
        Double(progress) / 100.0
    }
}

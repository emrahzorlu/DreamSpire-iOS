//
//  StoryDuration.swift
//  DreamSpire
//
//  Created by DreamSpire Team on 11/7/24.
//

import Foundation

/// Story duration options
enum StoryDuration: String, CaseIterable, Codable {
    case quick = "quick"
    case standard = "standard"
    case extended = "extended"
    case epic = "epic"
    
    var minutes: Int {
        switch self {
        case .quick: return 3
        case .standard: return 5
        case .extended: return 8
        case .epic: return 12
        }
    }
    
    var displayName: String {
        switch self {
        case .quick: return "duration_quick_name".localized
        case .standard: return "duration_standard_name".localized
        case .extended: return "duration_extended_name".localized
        case .epic: return "duration_epic_name".localized
        }
    }

    var icon: String {
        switch self {
        case .quick: return "⚡"
        case .standard: return "📖"
        case .extended: return "🌟"
        case .epic: return "🎭"
        }
    }

    var description: String {
        switch self {
        case .quick: return "duration_quick_desc".localized
        case .standard: return "duration_standard_desc".localized
        case .extended: return "duration_extended_desc".localized
        case .epic: return "duration_epic_desc".localized
        }
    }

    var badge: String? {
        switch self {
        case .standard: return "duration_most_popular_badge".localized
        default: return nil
        }
    }
    
    /// Base coin cost (text only) - scales with duration
    /// Updated: Increased for better margin (synced with backend)
    var baseCost: Int {
        switch self {
        case .quick: return 15      // Was 5, increased 3x
        case .standard: return 25   // Was 10, increased 2.5x
        case .extended: return 40   // Was 15, increased 2.7x
        case .epic: return 60       // Was 25, increased 2.4x
        }
    }
    
    /// Audio coin cost
    var audioCost: Int {
        switch self {
        case .quick: return 75
        case .standard: return 150
        case .extended: return 240
        case .epic: return 360
        }
    }

    /// Illustrated story coin cost (based on image count)
    var illustratedCost: Int {
        switch self {
        case .quick: return 200      // 2 images × $0.04 = $0.08
        case .standard: return 300   // 3 images × $0.04 = $0.12
        case .extended: return 400   // 5 images × $0.04 = $0.20
        case .epic: return 600       // 7 images × $0.04 = $0.28
        }
    }

    /// Number of illustrations for illustrated stories
    var illustrationCount: Int {
        switch self {
        case .quick: return 2
        case .standard: return 3
        case .extended: return 5
        case .epic: return 7
        }
    }

    /// Estimated word count
    var estimatedWords: Int {
        return minutes * 150 // ~150 words per minute
    }
}

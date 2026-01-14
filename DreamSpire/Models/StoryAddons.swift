//
//  StoryAddons.swift
//  DreamSpire
//
//  Created by DreamSpire Team on 11/7/24.
//

import Foundation

/// Story add-ons (optional features)
struct StoryAddons: Codable {
    var cover: Bool = false
    var audio: Bool = false
    var illustrated: Bool = false
    
    /// Convert to dictionary for API request
    var dictionary: [String: Bool] {
        return [
            "cover": cover,
            "audio": audio,
            "illustrated": illustrated
        ]
    }
    
    /// Total coin cost for selected addons
    func totalCost(duration: StoryDuration) -> Int {
        var total = 0
        
        if cover {
            total += 100 // Cover image cost
        }
        
        if audio {
            total += duration.audioCost
        }
        
        if illustrated {
            total += duration.illustratedCost // Duration-based illustrated cost
        }
        
        return total
    }
    
    /// List of selected addon names
    var selectedAddons: [String] {
        var addons: [String] = []
        if cover { addons.append("Cover Image") }
        if audio { addons.append("Audio") }
        if illustrated { addons.append("Illustrated") }
        return addons
    }
    
    /// Check if any addons are selected
    var hasSelectedAddons: Bool {
        return cover || audio || illustrated
    }
    
    /// Reset all addons
    mutating func reset() {
        cover = false
        audio = false
        illustrated = false
    }
}

/// Addon metadata for display
struct AddonInfo {
    let id: String
    let name: String
    let cost: Int
    let icon: String
    let description: String
    let availability: AddonAvailability
    
    enum AddonAvailability {
        case all
        case pro
        
        var displayText: String {
            switch self {
            case .all: return "Available to all"
            case .pro: return "Pro only"
            }
        }
    }
    
    /// Dynamic addon definitions for localization
    static var cover: AddonInfo {
        AddonInfo(
            id: "cover",
            name: "addon_cover_name".localized,
            cost: 100,
            icon: "photo.fill",
            description: "addon_cover_desc".localized,
            availability: .all
        )
    }

    static var audio: AddonInfo {
        AddonInfo(
            id: "audio",
            name: "addon_audio_name".localized,
            cost: 0, // Variable based on duration
            icon: "speaker.wave.2.fill",
            description: "addon_audio_desc".localized,
            availability: .all
        )
    }

    static var illustrated: AddonInfo {
        AddonInfo(
            id: "illustrated",
            name: "addon_illustrated_name".localized,
            cost: 0, // Variable based on duration
            icon: "paintbrush.fill",
            description: "addon_illustrated_desc".localized,
            availability: .pro
        )
    }
    
    static var allAddons: [AddonInfo] {
        return [cover, audio, illustrated]
    }
}

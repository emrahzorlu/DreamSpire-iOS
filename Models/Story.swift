//
//  Story.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//

import Foundation
import AVFoundation

struct Story: Codable, Identifiable {
    let id: String
    let userId: String?
    let type: StoryType

    let title: String
    let language: String
    let pages: [StoryPage]

    let coverImageUrl: String?
    let audioUrl: String?

    // Pro features
    let isIllustrated: Bool
    let illustrations: [Illustration]?

    // Character visual consistency
    let characterProfiles: [VisualProfile]?

    let category: String
    let tags: [String]?
    let estimatedMinutes: Int
    let metadata: StoryMetadata?

    var isFavorite: Bool = false
    let views: Int?
    let favorites: Int?
    var isSummary: Bool = false

    let createdAt: Date
    let updatedAt: Date
    
    enum StoryType: String, Codable {
        case user
        case prewritten
    }
    
    // MARK: - Custom Decoding
    
    enum CodingKeys: String, CodingKey {
        case id, userId, type, title, language, pages, content
        case coverImageUrl, audioUrl
        case isIllustrated, illustrations, pageImages
        case characterProfiles
        case category, estimatedMinutes, metadata
        case isFavorite, views, favorites
        case createdAt, updatedAt
        case ageRange, tone, tags
        case isSummary
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        type = try container.decode(StoryType.self, forKey: .type)

        // Title might be missing in old user stories - use category/genre as fallback
        if let titleValue = try? container.decode(String.self, forKey: .title) {
            title = titleValue
        } else if let cat = try? container.decode(String.self, forKey: .category) {
            title = cat
        } else if let meta = try? container.decode(StoryMetadata.self, forKey: .metadata),
                  let genre = meta.genre {
            title = genre
        } else {
            title = "story_default_title".localized
        }
        
        // Language is optional - old user stories don't have it
        // Default to "tr" if missing
        language = (try? container.decode(String.self, forKey: .language)) ?? "tr"
        
        // Handle both "pages" (user stories) and "content" (prewritten stories)
        if let pagesArray = try? container.decode([StoryPage].self, forKey: .pages) {
            // User story with pages array
            pages = pagesArray
        } else if let contentString = try? container.decode(String.self, forKey: .content) {
            // Prewritten story with single content string
            // Convert content to a single page
            pages = [StoryPage(pageNumber: 1, text: contentString)]
        } else {
            // Fallback: empty pages
            pages = []
        }
        
        coverImageUrl = try container.decodeIfPresent(String.self, forKey: .coverImageUrl)
        audioUrl = try container.decodeIfPresent(String.self, forKey: .audioUrl)

        isIllustrated = try container.decodeIfPresent(Bool.self, forKey: .isIllustrated) ?? false

        // Handle both "pageImages" (new format) and "illustrations" (old format)
        if let pageImagesArray = try? container.decode([Illustration].self, forKey: .pageImages) {
            illustrations = pageImagesArray
        } else {
            illustrations = try container.decodeIfPresent([Illustration].self, forKey: .illustrations)
        }
        
        characterProfiles = try container.decodeIfPresent([VisualProfile].self, forKey: .characterProfiles)
        
        // Category is optional - fallback to metadata.genre or default
        if let cat = try? container.decode(String.self, forKey: .category) {
            category = cat
        } else if let meta = try? container.decode(StoryMetadata.self, forKey: .metadata),
                  let genre = meta.genre {
            category = genre
        } else {
            category = "all" // Default category key
        }

        // Tags are optional
        tags = try container.decodeIfPresent([String].self, forKey: .tags)

        // estimatedMinutes might be missing in old user stories
        estimatedMinutes = (try? container.decode(Int.self, forKey: .estimatedMinutes)) ?? 5
        
        // Metadata might be nested or at root level for prewritten stories
        metadata = try? container.decodeIfPresent(StoryMetadata.self, forKey: .metadata)
        
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        views = try container.decodeIfPresent(Int.self, forKey: .views)
        favorites = try container.decodeIfPresent(Int.self, forKey: .favorites)
        
        // Handle Firebase timestamp format
        if let timestamp = try? container.decode(FirebaseTimestamp.self, forKey: .createdAt) {
            createdAt = timestamp.date
        } else {
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }
        
        if let timestamp = try? container.decode(FirebaseTimestamp.self, forKey: .updatedAt) {
            updatedAt = timestamp.date
        } else {
            updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        }
        
        isSummary = try container.decodeIfPresent(Bool.self, forKey: .isSummary) ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encode(type, forKey: .type)
        try container.encode(title, forKey: .title)
        try container.encode(language, forKey: .language)
        try container.encode(pages, forKey: .pages)
        try container.encodeIfPresent(coverImageUrl, forKey: .coverImageUrl)
        try container.encodeIfPresent(audioUrl, forKey: .audioUrl)
        try container.encode(isIllustrated, forKey: .isIllustrated)
        try container.encodeIfPresent(illustrations, forKey: .illustrations)
        try container.encodeIfPresent(characterProfiles, forKey: .characterProfiles)
        try container.encode(category, forKey: .category)
        try container.encodeIfPresent(tags, forKey: .tags)
        try container.encode(estimatedMinutes, forKey: .estimatedMinutes)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encodeIfPresent(views, forKey: .views)
        try container.encodeIfPresent(favorites, forKey: .favorites)
        try container.encode(isSummary, forKey: .isSummary)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
    
    // MARK: - Designated Initializer
    
    init(
        id: String,
        userId: String?,
        type: StoryType,
        title: String,
        language: String,
        pages: [StoryPage],
        coverImageUrl: String?,
        audioUrl: String?,
        isIllustrated: Bool,
        illustrations: [Illustration]?,
        characterProfiles: [VisualProfile]?,
        category: String,
        tags: [String]? = nil,
        estimatedMinutes: Int,
        metadata: StoryMetadata?,
        isFavorite: Bool = false,
        isSummary: Bool = false,
        views: Int?,
        favorites: Int? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.type = type
        self.title = title
        self.language = language
        self.pages = pages
        self.coverImageUrl = coverImageUrl
        self.audioUrl = audioUrl
        self.isIllustrated = isIllustrated
        self.illustrations = illustrations
        self.characterProfiles = characterProfiles
        self.category = category
        self.tags = tags
        self.estimatedMinutes = estimatedMinutes
        self.metadata = metadata
        self.isFavorite = isFavorite
        self.isSummary = isSummary
        self.views = views
        self.favorites = favorites
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Localized Category

    /// Returns the localized version of the category string
    var localizedCategory: String {
        // Map backend category strings to localized keys
        switch category.lowercased() {
        case "classic", "klasik":
            return "template_category_classic".localized
        case "adventure", "macera":
            return "template_category_adventure".localized
        case "bedtime", "uyku vakti", "uyku":
            return "template_category_bedtime".localized
        case "family", "aile":
            return "template_category_family".localized
        case "friendship", "dostluk":
            return "template_category_friendship".localized
        case "fantasy", "fantastik":
            return "template_category_fantasy".localized
        case "animals", "hayvanlar":
            return "template_category_animals".localized
        case "princess", "prenses":
            return "template_category_princess".localized
        case "nature", "doğa":
            return "template_category_nature".localized
        case "all", "genel":
            return "template_category_all".localized
        default:
            return category // Fallback to original if no match
        }
    }

    // MARK: - Duration Calculation

    /// Returns the actual duration from metadata if available, otherwise falls back to estimatedMinutes
    /// This is the real TTS-measured duration in seconds from the backend
    var actualDurationSeconds: Int? {
        return metadata?.actualDuration
    }

    /// Returns the reading time rounded to the nearest 0.5 minute
    /// Priority: Uses actualDuration if available, otherwise falls back to estimatedMinutes
    /// Examples:
    /// - 4.2 min -> 4 min
    /// - 4.5 min -> 5 min
    /// - 4.7 min -> 5 min
    /// - 5.2 min -> 5 min
    /// - 5.8 min -> 6 min
    var roundedMinutes: Int {
        let minutes: Double

        // Use actual duration if available (from TTS measurement)
        if let actualSeconds = actualDurationSeconds {
            minutes = Double(actualSeconds) / 60.0
        } else {
            minutes = Double(estimatedMinutes)
        }

        // Round to nearest 0.5, then round up to whole minute
        // This gives more accurate representation while staying user-friendly
        return Int(round(minutes))
    }

    // MARK: - Audio Duration Calculation

    /// Calculates actual audio duration from audio URL
    /// Returns nil if audio URL is not available or duration cannot be determined
    func getAudioDuration() async -> Double? {
        guard let audioUrlString = audioUrl,
              let url = URL(string: audioUrlString) else {
            return nil
        }

        do {
            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration)
            return duration.seconds
        } catch {
            DWLogger.shared.error("Failed to load audio duration", error: error, category: .general)
            return nil
        }
    }

    /// Returns audio duration in minutes, rounded up to nearest minute
    func getAudioMinutes() async -> Int? {
        guard let seconds = await getAudioDuration() else {
            return nil
        }
        return Int(ceil(seconds / 60.0))
    }
}

// MARK: - Firebase Timestamp Helper

struct StoryPage: Codable, Identifiable {
    let id: String
    let pageNumber: Int
    let text: String
    let imageUrl: String? // Some user stories have per-page images
    
    enum CodingKeys: String, CodingKey {
        case id
        case pageNumber
        case text
        case scene      // Fallback for user stories
        case imageUrl
        case previewImageUrl
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Backend may not send id, generate one if missing
        if let decodedId = try? container.decode(String.self, forKey: .id) {
            id = decodedId
        } else {
            id = UUID().uuidString
        }
        
        pageNumber = try container.decode(Int.self, forKey: .pageNumber)
        
        // Handle both "text" and "scene" (user stories use scene)
        if let decodedText = try? container.decode(String.self, forKey: .text) {
            text = decodedText
        } else {
            text = try container.decode(String.self, forKey: .scene)
        }
        
        // Handle image URLs if present
        if let url = try? container.decode(String.self, forKey: .imageUrl) {
            imageUrl = url
        } else {
            imageUrl = try? container.decode(String.self, forKey: .previewImageUrl)
        }
    }
    
    init(id: String = UUID().uuidString, pageNumber: Int, text: String, imageUrl: String? = nil) {
        self.id = id
        self.pageNumber = pageNumber
        self.text = text
        self.imageUrl = imageUrl
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(pageNumber, forKey: .pageNumber)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
    }
}

struct Illustration: Codable, Identifiable {
    let id: String
    let pageNumber: Int
    let imageUrl: String
    let scene: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case pageNumber
        case imageUrl
        case scene
        case text // Fallback
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Backend may not send id, generate one if missing
        if let decodedId = try? container.decode(String.self, forKey: .id) {
            id = decodedId
        } else {
            id = UUID().uuidString
        }
        
        pageNumber = try container.decode(Int.self, forKey: .pageNumber)
        imageUrl = try container.decode(String.self, forKey: .imageUrl)
        
        // Handle both "scene" and "text"
        if let decodedScene = try? container.decode(String.self, forKey: .scene) {
            scene = decodedScene
        } else {
            scene = try container.decode(String.self, forKey: .text)
        }
    }
    
    init(id: String = UUID().uuidString, pageNumber: Int, imageUrl: String, scene: String) {
        self.id = id
        self.pageNumber = pageNumber
        self.imageUrl = imageUrl
        self.scene = scene
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(pageNumber, forKey: .pageNumber)
        try container.encode(imageUrl, forKey: .imageUrl)
        try container.encode(scene, forKey: .scene)
    }
}

struct StoryMetadata: Codable {
    let tone: String?
    let ageRange: String?
    let genre: String?
    let voice: String?
    let tier: String?
    let templateId: String?
    let generationCost: Double?
    let prompt: String?
    let createdBy: String?
    let wordCount: Int?
    let actualDuration: Int?
}

// MARK: - Mock Data for Preview

extension Story {
    static var mockStory: Story {
        Story(
            id: "story-1",
            userId: "user-1",
            type: .user,
            title: "Sofia'nın Sihirli Macerası",
            language: "tr",
            pages: [
                StoryPage(pageNumber: 1, text: "Bir zamanlar Sofia adında meraklı bir kız yaşarmış. Bir gün bahçede parlak bir taş bulmuş."),
                StoryPage(pageNumber: 2, text: "Taşa dokunduğunda sihirli bir kapı açılmış ve Sofia bambaşka bir dünyaya adım atmış."),
                StoryPage(pageNumber: 3, text: "Orada konuşan hayvanlar ve uçan atlar varmış. Sofia onlarla harika maceralar yaşamış.")
            ],
            coverImageUrl: nil,
            audioUrl: "https://example.com/audio.mp3",
            isIllustrated: true,
            illustrations: [
                Illustration(pageNumber: 1, imageUrl: "https://example.com/img1.jpg", scene: "Sofia finding the stone"),
                Illustration(pageNumber: 2, imageUrl: "https://example.com/img2.jpg", scene: "Magical door opening")
            ],
            characterProfiles: [VisualProfile.mockProfile],
            category: "Macera",
            estimatedMinutes: 8,
            metadata: StoryMetadata(
                tone: "magical",
                ageRange: "young",
                genre: "adventure",
                voice: "shimmer",
                tier: "pro",
                templateId: nil,
                generationCost: 0.15,
                prompt: nil,
                createdBy: nil,
                wordCount: 250,
                actualDuration: 5
            ),
            isFavorite: false,
            views: 42,
            favorites: 5,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    static var mockPrewrittenStory: Story {
        Story(
            id: "prewritten-1",
            userId: nil,
            type: .prewritten,
            title: "Kırmızı Başlıklı Kız",
            language: "tr",
            pages: [
                StoryPage(pageNumber: 1, text: "Bir zamanlar, ormanın yanında küçük bir evde yaşayan sevimli bir kız vardı...")
            ],
            coverImageUrl: "https://example.com/cover.jpg",
            audioUrl: "https://example.com/audio.mp3",
            isIllustrated: false,
            illustrations: nil,
            characterProfiles: nil,
            category: "classic",
            estimatedMinutes: 5,
            metadata: StoryMetadata(
                tone: "soothing",
                ageRange: "middle",
                genre: nil,
                voice: nil,
                tier: "free",
                templateId: nil,
                generationCost: nil,
                prompt: "Kırmızı başlıklı küçük bir kızın orman yolculuğu",
                createdBy: "admin",
                wordCount: 150,
                actualDuration: 3
            ),
            isFavorite: false,
            views: 150,
            favorites: 23,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

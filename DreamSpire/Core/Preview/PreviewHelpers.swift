//
//  PreviewHelpers.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025.
//

import SwiftUI

// MARK: - Preview Background

/// Standard preview background for consistent previews
struct PreviewBackground: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.1, blue: 0.25),
                    Color(red: 0.1, green: 0.08, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            content
        }
    }
}

extension View {
    /// Apply standard preview background
    func previewBackground() -> some View {
        modifier(PreviewBackground())
    }
}

// MARK: - Preview Data

/// Sample data for SwiftUI previews
enum PreviewData {
    
    // Sample user
    static let userName = "Emrah"
    static let userEmail = "emrah@example.com"
    
    // Sample story
    static var sampleStory: Story {
        Story(
            id: "preview-story-1",
            userId: "preview-user",
            type: .prewritten,
            title: "The Magical Forest Adventure",
            language: "en",
            pages: [
                StoryPage(id: "1", pageNumber: 1, text: "Once upon a time, in a magical forest..."),
                StoryPage(id: "2", pageNumber: 2, text: "A brave little fox set out on an adventure..."),
                StoryPage(id: "3", pageNumber: 3, text: "And they all lived happily ever after.")
            ],
            coverImageUrl: nil,
            audioUrl: nil,
            category: "adventure",
            estimatedMinutes: 5,
            characterProfiles: nil,
            metadata: nil,
            ageRange: "7-9",
            tone: nil,
            tags: ["adventure", "animals"],
            isFavorite: false,
            isSummary: false,
            views: 150,
            favorites: 25,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    // Sample character
    static var sampleCharacter: Character {
        Character(
            id: "preview-char-1",
            name: "Luna",
            gender: "female",
            relationship: "friend",
            description: "A curious little girl who loves exploring",
            userId: "preview-user",
            usageCount: 5,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    // Sample stories list
    static var sampleStories: [Story] {
        [
            sampleStory,
            Story(
                id: "preview-story-2",
                userId: "preview-user",
                type: .prewritten,
                title: "The Friendly Dragon",
                language: "en",
                pages: [StoryPage(id: "1", pageNumber: 1, text: "High in the mountains...")],
                coverImageUrl: nil,
                audioUrl: nil,
                category: "adventure",
                estimatedMinutes: 7,
                characterProfiles: nil,
                metadata: nil,
                ageRange: "7-9",
                tone: nil,
                tags: ["adventure", "fantasy"],
                isFavorite: true,
                isSummary: false,
                views: 200,
                favorites: 45,
                createdAt: Date().addingTimeInterval(-86400),
                updatedAt: Date().addingTimeInterval(-86400)
            )
        ]
    }
}

// MARK: - Preview Device Modifier

extension View {
    /// Preview on multiple device sizes
    func previewDevices() -> some View {
        Group {
            self
                .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro"))
                .previewDisplayName("iPhone 15 Pro")
            
            self
                .previewDevice(PreviewDevice(rawValue: "iPhone SE (3rd generation)"))
                .previewDisplayName("iPhone SE")
        }
    }
}

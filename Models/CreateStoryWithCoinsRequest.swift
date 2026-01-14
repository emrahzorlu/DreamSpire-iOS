//
//  CreateStoryWithCoinsRequest.swift
//  DreamSpire
//
//  Created by DreamSpire Team on 11/7/24.
//

import Foundation

// MARK: - Request Models

struct CreateStoryWithCoinsRequest: Codable {
    let duration: String  // "quick", "standard", "extended", "epic"
    let addons: AddonsRequest
    let prompt: String
    let genre: String
    let tone: String
    let ageRange: String
    let language: String
    let voice: String?
    let characters: [CharacterRequest]
}

struct AddonsRequest: Codable {
    let cover: Bool
    let audio: Bool
    let illustrated: Bool
}

struct CharacterRequest: Codable {
    let name: String
    let type: String
    let age: Int?
    let description: String?
    
    init(from character: Character) {
        self.name = character.name
        self.type = character.type.rawValue
        self.age = character.age
        self.description = character.description
    }
    
    // For StoryCharacter (used in StoryCreationFlowView)
    init(from storyCharacter: StoryCharacter) {
        self.name = storyCharacter.name
        self.type = storyCharacter.type.rawValue
        self.age = storyCharacter.age
        self.description = storyCharacter.description.isEmpty ? nil : storyCharacter.description
    }
}

// MARK: - Response Models

struct StoryCreationResponse: Codable {
    let success: Bool
    let async: Bool
    
    // Sync response fields
    let story: Story?
    
    // Async response fields
    let jobId: String?
    let status: String?
    let message: String?
    
    // Common field
    let coinTransaction: StoryCreationCoinTransaction
    
    var isAsync: Bool {
        return async
    }
}

struct StoryCreationCoinTransaction: Codable {
    let spent: Int
    let breakdown: StoryCreationCoinBreakdown
    let newBalance: Int
}

struct StoryCreationCoinBreakdown: Codable {
    let text: Int
    let cover: Int?
    let audio: Int?
    let illustrated: Int?
    
    // Computed property for backward compatibility
    var duration: Int {
        return text
    }
}

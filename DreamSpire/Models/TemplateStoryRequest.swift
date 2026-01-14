//
//  TemplateStoryRequest.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//

import Foundation

struct CreateStoryRequest: Codable {
    let prompt: String
    let readingMinutes: Int
    let genre: String
    let tone: String
    let ageRange: String
    let language: String
    let characters: [Character]
    let generateImage: Bool
    let generateAudio: Bool
    let illustrationMode: Bool?
}

struct TemplateStoryRequest: Codable {
    let characters: [String: Character]
    let readingMinutes: Int
    let generateAudio: Bool
    let generateImage: Bool
    let illustrated: Bool  // NEW: Illustrated story support
}

struct EmptyResponse: Codable {
    let success: Bool?
}

struct ToggleFavoriteResponse: Codable {
    let success: Bool
    let isFavorite: Bool
}

// Character format for template API
struct TemplateCharacter: Codable {
    let name: String
    let type: String
    let age: Int?
    let description: String?
}

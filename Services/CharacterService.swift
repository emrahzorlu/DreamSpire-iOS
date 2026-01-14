//
//  CharacterService.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//

import Foundation

class CharacterService {
    static let shared = CharacterService()
    private let apiClient = APIClient.shared
    
    // Cache key for characters endpoint
    private var charactersCacheKey: String {
        return "/api/characters_true"
    }
    
    private init() {
        DWLogger.shared.info("CharacterService initialized", category: .character)
    }
    
    // MARK: - Cache Invalidation
    
    private func invalidateCharactersCache() {
        Task { @MainActor in
            RequestBatcher.shared.clearCache(for: charactersCacheKey)
            DWLogger.shared.debug("Characters cache invalidated", category: .character)
        }
    }
    
    // MARK: - Get Saved Characters

    func getSavedCharacters() async throws -> [Character] {
        DWLogger.shared.info("Fetching saved characters", category: .character)

        do {
            let characters = try await apiClient.getSavedCharacters()

            DWLogger.shared.info("Fetched \(characters.count) saved characters", category: .character)
            return characters
        } catch {
            DWLogger.shared.error("Failed to fetch saved characters", error: error, category: .character)
            throw error
        }
    }
    
    // MARK: - Save Character
    
    func saveCharacter(_ character: Character) async throws -> Character {
        DWLogger.shared.info("Saving character: \(character.name)", category: .character)

        do {
            let savedCharacter = try await apiClient.saveCharacter(character)

            // Invalidate cache so next fetch gets fresh data
            invalidateCharactersCache()
            
            DWLogger.shared.info("Character saved successfully: \(savedCharacter.id)", category: .character)
            DWLogger.shared.logAnalyticsEvent(
                "character_saved",
                parameters: [
                    "character_type": character.type.rawValue,
                    "has_visual_profile": character.visualProfile != nil
                ]
            )

            return savedCharacter
        } catch {
            DWLogger.shared.error("Failed to save character", error: error, category: .character)
            throw error
        }
    }
    
    // MARK: - Update Character

    func updateCharacter(id: String, character: Character) async throws -> Character {
        DWLogger.shared.info("Updating character: \(id)", category: .character)

        struct UpdateCharacterResponse: Codable {
            let success: Bool
            let character: Character
        }

        do {
            let response: UpdateCharacterResponse = try await apiClient.makeRequest(
                endpoint: "\(Constants.API.Endpoints.characters)/\(id)",
                method: .put,
                body: character
            )

            // Invalidate cache so next fetch gets fresh data
            invalidateCharactersCache()

            DWLogger.shared.info("Character updated successfully", category: .character)
            return response.character
        } catch {
            DWLogger.shared.error("Failed to update character", error: error, category: .character)
            throw error
        }
    }
    
    // MARK: - Delete Character

    func deleteCharacter(id: String) async throws {
        DWLogger.shared.info("Deleting character: \(id)", category: .character)

        do {
            let _: EmptyResponse = try await apiClient.makeRequest(
                endpoint: "\(Constants.API.Endpoints.characters)/\(id)",
                method: .delete
            )

            // Invalidate cache so next fetch gets fresh data
            invalidateCharactersCache()
            
            DWLogger.shared.info("Character deleted successfully", category: .character)
        } catch {
            DWLogger.shared.error("Failed to delete character", error: error, category: .character)
            throw error
        }
    }

    // MARK: - Increment Usage

    func incrementCharacterUsage(characterId: String, storyId: String?) async throws {
        DWLogger.shared.info("Incrementing usage for character: \(characterId)", category: .character)

        struct UsageRequest: Codable {
            let storyId: String?
        }

        struct Response: Codable {
            let success: Bool
            let message: String?
        }

        do {
            let _: Response = try await apiClient.makeRequest(
                endpoint: "\(Constants.API.Endpoints.characters)/\(characterId)/use",
                method: .post,
                body: UsageRequest(storyId: storyId)
            )

            DWLogger.shared.info("Character usage incremented successfully", category: .character)
        } catch {
            DWLogger.shared.error("Failed to increment character usage", error: error, category: .character)
            throw error
        }
    }
}

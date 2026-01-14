//
//  CharacterRepository.swift
//  DreamSpire
//
//  Professional character repository with intelligent caching
//  Eliminates redundant character loading across views
//

import Foundation
import Combine

/// Centralized repository for saved characters with intelligent caching
@MainActor
final class CharacterRepository: ObservableObject {

    // MARK: - Singleton

    static let shared = CharacterRepository()

    // MARK: - Published Properties

    /// All cached characters
    @Published private(set) var characters: [Character] = []

    /// Loading state
    @Published private(set) var isLoading = false

    /// Error state
    @Published private(set) var error: Error?

    // MARK: - Cache Management

    /// Cache timestamp
    private var cacheTimestamp: Date?

    /// Cache duration (3 minutes - characters change frequently)
    private let cacheDuration: TimeInterval = 3 * 60

    /// Active fetch task to prevent duplicate requests
    private var activeFetchTask: Task<[Character], Error>?

    // MARK: - Dependencies

    private let characterService = CharacterService.shared

    // MARK: - Initialization

    private init() {
        DWLogger.shared.info("CharacterRepository initialized", category: .ui)
    }

    // MARK: - Get Characters (With Cache)

    /// Get all saved characters (uses cache if valid)
    /// - Parameter forceRefresh: Force bypass cache and fetch fresh data
    /// - Returns: Array of saved characters
    func getCharacters(forceRefresh: Bool = false) async throws -> [Character] {
        // Check cache validity
        if !forceRefresh,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheDuration {
            let age = Int(Date().timeIntervalSince(timestamp))
            DWLogger.shared.debug("✅ Using cached characters: \(characters.count) (age: \(age)s)", category: .ui)
            return characters
        }

        // Check if fetch already in progress
        if let existingTask = activeFetchTask {
            DWLogger.shared.debug("⏳ Character fetch in progress, waiting...", category: .ui)
            return try await existingTask.value
        }

        // Create new fetch task
        let task = Task<[Character], Error> {
            DWLogger.shared.info("🔄 Fetching characters from backend...", category: .ui)
            isLoading = true
            error = nil

            do {
                let fetchedCharacters = try await characterService.getSavedCharacters()

                // Update cache
                await MainActor.run {
                    characters = fetchedCharacters
                    cacheTimestamp = Date()
                    isLoading = false
                }

                DWLogger.shared.debug("✅ Characters cached: \(fetchedCharacters.count)", category: .ui)
                return fetchedCharacters

            } catch let fetchError {
                await MainActor.run {
                    error = fetchError
                    isLoading = false
                }
                DWLogger.shared.error("Failed to fetch characters", error: fetchError, category: .ui)
                throw fetchError
            }
        }

        activeFetchTask = task

        do {
            let result = try await task.value
            activeFetchTask = nil
            return result
        } catch {
            activeFetchTask = nil
            throw error
        }
    }

    // MARK: - Get Single Character

    /// Get a specific character by ID (from cache if available)
    func getCharacter(id: String) async throws -> Character? {
        // Try cache first
        if let cached = characters.first(where: { $0.id == id }),
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheDuration {
            return cached
        }

        // Refresh cache and search again
        let allCharacters = try await getCharacters(forceRefresh: true)
        return allCharacters.first(where: { $0.id == id })
    }

    // MARK: - Create Character

    /// Create new character (optimistic update)
    func createCharacter(name: String, visualProfile: VisualProfile) async throws -> Character {
        DWLogger.shared.info("Creating character: \(name)", category: .ui)

        // Create character model
        let character = Character(
            name: name,
            type: .child, // Default type, can be customized later
            visualProfile: visualProfile
        )

        // Save via service
        let savedCharacter = try await characterService.saveCharacter(character)

        // Optimistically add to cache
        await MainActor.run {
            characters.append(savedCharacter)
            DWLogger.shared.debug("✅ Character added to cache: \(name)", category: .ui)
        }

        return savedCharacter
    }

    // MARK: - Update Character

    /// Update existing character (optimistic update)
    func updateCharacter(id: String, character: Character) async throws -> Character {
        DWLogger.shared.info("Updating character: \(id)", category: .ui)

        // Update via service
        let updatedCharacter = try await characterService.updateCharacter(id: id, character: character)

        // Optimistically update cache
        await MainActor.run {
            if let index = characters.firstIndex(where: { $0.id == id }) {
                characters[index] = updatedCharacter
                DWLogger.shared.debug("✅ Character updated in cache: \(character.name)", category: .ui)
            }
        }

        return updatedCharacter
    }

    // MARK: - Delete Character

    /// Delete character (optimistic update)
    func deleteCharacter(id: String) async throws {
        DWLogger.shared.info("Deleting character: \(id)", category: .ui)

        // Optimistically remove from cache
        let originalCharacters = characters
        await MainActor.run {
            characters.removeAll(where: { $0.id == id })
            DWLogger.shared.debug("✅ Character removed from cache", category: .ui)
        }

        do {
            // Delete via service
            try await characterService.deleteCharacter(id: id)
        } catch {
            // Rollback on error
            await MainActor.run {
                characters = originalCharacters
                DWLogger.shared.error("❌ Character delete failed, cache rolled back", error: error, category: .ui)
            }
            throw error
        }
    }

    // MARK: - Force Refresh

    /// Force refresh characters from backend
    func refresh() async throws -> [Character] {
        return try await getCharacters(forceRefresh: true)
    }

    // MARK: - Clear Cache

    /// Clear character cache (useful for logout)
    func clearCache() {
        characters = []
        cacheTimestamp = nil
        activeFetchTask?.cancel()
        activeFetchTask = nil
        DWLogger.shared.info("Character cache cleared", category: .ui)
    }
}

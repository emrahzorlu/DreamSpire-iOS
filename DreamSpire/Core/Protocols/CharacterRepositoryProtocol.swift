//
//  CharacterRepositoryProtocol.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025.
//

import Foundation
import Combine

/// Protocol for character data operations
@MainActor
protocol CharacterRepositoryProtocol: ObservableObject {
    
    // Cached characters
    var characters: [Character] { get }
    var isLoading: Bool { get }
    
    // CRUD operations
    func getCharacters(forceRefresh: Bool) async throws -> [Character]
    func saveCharacter(_ character: Character) async throws -> Character
    func updateCharacter(_ character: Character) async throws -> Character
    func deleteCharacter(id: String) async throws
    
    // Cache management
    func refresh() async throws
}

// Default parameter values
extension CharacterRepositoryProtocol {
    func getCharacters(forceRefresh: Bool = false) async throws -> [Character] {
        try await getCharacters(forceRefresh: forceRefresh)
    }
}

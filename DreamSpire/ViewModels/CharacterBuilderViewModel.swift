//
//  CharacterBuilderViewModel.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025-11-02.
//

import Foundation
import Combine

@MainActor
final class CharacterBuilderViewModel: ObservableObject {
    // MARK: - Singleton

    static let shared = CharacterBuilderViewModel()

    // MARK: - Published Properties

    @Published var characters: [Character] = []
    @Published var savedCharacters: [Character] = []
    @Published var selectedCharacter: Character?

    @Published var isLoading: Bool = true
    @Published var isSavingCharacter: Bool = false
    @Published var error: String?
    @Published var successMessage: String?

    // Character Type Selection
    @Published var showingTypePicker: Bool = false
    @Published var selectedTypeCategory: CharacterCategory = .people

    // MARK: - Dependencies

    private let characterRepository = CharacterRepository.shared
    private let subscriptionService = SubscriptionService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var maxCharactersAllowed: Int {
        return subscriptionService.currentTier.maxCharactersPerStory
    }
    
    var canAddMoreCharacters: Bool {
        return characters.count < maxCharactersAllowed
    }
    
    var availableCharacterTypes: [CharacterType] {
        return CharacterType.allCases.filter { $0.category == selectedTypeCategory }
    }
    
    var characterCategories: [CharacterCategory] {
        return CharacterCategory.allCases
    }

    // MARK: - Initialization

    private init() {
        DWLogger.shared.info("CharacterBuilderViewModel initialized", category: .character)
    }

    // MARK: - Character Management
    
    func addCharacter(type: CharacterType = .child) {
        let check = subscriptionService.canAddCharacter(currentCount: characters.count)
        guard check.allowed else {
            error = check.reason ?? "Maksimum karakter sayısına ulaştınız"
            return
        }
        
        let newCharacter = Character(type: type)
        characters.append(newCharacter)
    }
    
    func removeCharacter(at index: Int) {
        guard index >= 0 && index < characters.count else { return }
        characters.remove(at: index)
    }
    
    func removeCharacter(id: String) {
        characters.removeAll { $0.id == id }
    }
    
    func updateCharacter(_ character: Character) {
        if let index = characters.firstIndex(where: { $0.id == character.id }) {
            characters[index] = character
        }
    }
    
    func moveCharacter(from source: IndexSet, to destination: Int) {
        characters.move(fromOffsets: source, toOffset: destination)
    }
    
    // MARK: - Saved Characters

    func loadSavedCharacters() async {
        isLoading = true
        error = nil

        do {
            // Use repository - automatically handles caching!
            savedCharacters = try await characterRepository.getCharacters(forceRefresh: false)
        } catch {
            self.error = "Kayıtlı karakterler yüklenemedi: \(error.localizedDescription)"
            DWLogger.shared.error("Saved characters loading error", error: error, category: .character)
        }

        isLoading = false
    }
    
    func useSavedCharacter(_ savedCharacter: Character) {
        let check = subscriptionService.canAddCharacter(currentCount: characters.count)
        guard check.allowed else {
            error = check.reason ?? "Maksimum karakter sayısına ulaştınız"
            return
        }
        
        // Create a new character with saved character's data
        // Keep the savedCharacterId so we can track usage after story creation
        var newCharacter = savedCharacter
        newCharacter.savedCharacterId = savedCharacter.id  // Store original saved character ID
        newCharacter.id = UUID().uuidString  // New instance ID
        characters.append(newCharacter)
        
        successMessage = "\(savedCharacter.name) eklendi"
    }
    
    func saveCharacter(_ character: Character) async {
        // Check if user can save characters
        let check = subscriptionService.canSaveCharacter(currentCount: savedCharacters.count)
        guard check.allowed else {
            error = check.reason ?? "Karakter kaydetme için yükseltme gerekli"
            return
        }

        // Visual profile is required for saving
        guard let visualProfile = character.visualProfile else {
            error = "Karakter için görsel profil gerekli"
            return
        }

        isSavingCharacter = true
        error = nil

        do {
            // Use repository - optimistic update with cache
            let savedCharacter = try await characterRepository.createCharacter(
                name: character.name,
                visualProfile: visualProfile
            )
            savedCharacters.append(savedCharacter)
            successMessage = "\(character.name) başarıyla kaydedildi"

            // Notify that character count changed
            NotificationCenter.default.post(name: .characterCountDidChange, object: nil)
        } catch {
            self.error = "Karakter kaydedilemedi: \(error.localizedDescription)"
            DWLogger.shared.error("Character save error", error: error, category: .character)
        }

        isSavingCharacter = false
    }
    
    func deleteSavedCharacter(id: String) async {
        do {
            // Use repository - optimistic update with rollback on error
            try await characterRepository.deleteCharacter(id: id)
            savedCharacters.removeAll { $0.id == id }
            successMessage = "Karakter silindi"

            // Notify that character count changed
            NotificationCenter.default.post(name: .characterCountDidChange, object: nil)
        } catch {
            self.error = "Karakter silinemedi: \(error.localizedDescription)"
            DWLogger.shared.error("Character delete error", error: error, category: .character)
        }
    }
    
    // MARK: - Validation
    
    func validateCharacters() -> (isValid: Bool, message: String?) {
        // Check if we have at least one character
        guard !characters.isEmpty else {
            return (false, "En az bir karakter eklemelisiniz")
        }
        
        // Check if all characters have names
        let unnamedCharacters = characters.filter { $0.name.isEmpty }
        guard unnamedCharacters.isEmpty else {
            return (false, "Tüm karakterlerin isim alanlarını doldurun")
        }
        
        // Check name length
        let tooShortNames = characters.filter { $0.name.count < 2 }
        guard tooShortNames.isEmpty else {
            return (false, "Karakter isimleri en az 2 karakter olmalı")
        }
        
        // Check for duplicate names
        let names = characters.map { $0.name.lowercased() }
        let uniqueNames = Set(names)
        guard names.count == uniqueNames.count else {
            return (false, "Karakter isimleri benzersiz olmalı")
        }
        
        return (true, nil)
    }
    
    // MARK: - Character Type Helpers
    
    func getCharacterTypeIcon(_ type: CharacterType) -> String {
        return type.icon
    }
    
    func getCharacterTypeDisplayName(_ type: CharacterType) -> String {
        return type.displayName
    }
    
    func selectTypeCategory(_ category: CharacterCategory) {
        selectedTypeCategory = category
    }
    
    // MARK: - Smart Relationship Detection
    
    func detectRelationships() {
        // Detect siblings
        let children = characters.filter { $0.type == .child || $0.type == .sibling }
        if children.count >= 2 {
            // Mark them as siblings
            for i in 0..<children.count {
                var character = children[i]
                if character.type == .child {
                    character.type = .sibling
                    updateCharacter(character)
                }
            }
        }
        
        // Detect family relationships
        let hasParents = characters.contains { $0.type == .mother || $0.type == .father }
        let hasChildren = children.count > 0
        
        if hasParents && hasChildren {
            // This is a family story
            print("Family story detected")
        }
    }
    
    // MARK: - Reset
    
    func reset() {
        characters = []
        selectedCharacter = nil
        error = nil
        successMessage = nil
    }
}

// MARK: - Character Category Extension

extension CharacterCategory {
    
    var icon: String {
        switch self {
        case .people:
            return "person.3.fill"
        case .pets:
            return "pawprint.fill"
        }
    }
}

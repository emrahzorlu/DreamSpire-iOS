//
//  StoryCreationStep2View.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//

import SwiftUI

struct StoryCreationStep2View: View {
    @Binding var characters: [StoryCharacter]
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var characterViewModel = CharacterBuilderViewModel.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    
    var showCoinBalance: Bool = false
    var presentedFromTab: Bool = false
    let onNext: () -> Void
    let onBack: () -> Void
    
    @State private var showingCharacterTypePicker = false
    @State private var selectedCharacterIndex: Int?
    @State private var showingSavedCharacters = false
    @State private var showingPaywall = false
    @State private var savedCharacterNames: Set<String> = []  // Track by name instead of UUID
    @State private var characterIndexToSave: Int? = nil
    @State private var charactersFromSaved: Set<UUID> = []
    @ObservedObject private var characterRepository = CharacterRepository.shared
    
    // Content Safety
    @State private var contentSafetyWarning: String? = nil
    @State private var warningDebounceTask: Task<Void, Never>? = nil

    var maxCharacters: Int {
        subscriptionService.currentTier.maxCharactersPerStory
    }

    var isValidToProgress: Bool {
        // Must have at least 1 character with a name
        let charactersWithNames = characters.filter { !$0.name.isEmpty }
        guard charactersWithNames.count >= 1 else { return false }

        // All characters must have a name
        for character in characters {
            if character.name.isEmpty {
                return false
            }
        }

        // Content safety check
        guard contentSafetyWarning == nil else { return false }

        return true
    }
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient.dwBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Bar
                topBar
                
                // Progress
                progressIndicator
                
                // Content Safety Warning Banner
                if let warning = contentSafetyWarning {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.red)
                        
                        Text(warning)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.red.opacity(0.25))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.5), lineWidth: 1.5)
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Content
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 20) {
                            // Info Card
                            infoCard

                            // Saved Characters Button (Plus/Pro only)
                            if subscriptionService.currentTier != .free && !characterViewModel.savedCharacters.isEmpty {
                                savedCharactersButton
                            }

                            // Character Cards
                            ForEach(Array(characters.enumerated()), id: \.element.id) { index, character in
                                CharacterCardView(
                                    character: $characters[index],
                                    characterNumber: index + 1,
                                    isMainCharacter: index == 0,
                                    isSaved: savedCharacterNames.contains(character.name),
                                    isFromSaved: charactersFromSaved.contains(character.id),
                                    onDelete: {
                                        characters.remove(at: index)
                                        charactersFromSaved.remove(character.id)
                                    },
                                    onSelectType: {
                                        selectedCharacterIndex = index
                                        showingCharacterTypePicker = true
                                    },
                                    onSave: {
                                        characterIndexToSave = index
                                    },
                                    scrollProxy: proxy
                                )
                                .id("character_\(character.id)")
                            }

                            // Add Character Button
                            if characters.count < maxCharacters {
                                addCharacterButton
                            }

                            // Upgrade prompt
                            if characters.count >= maxCharacters {
                                upgradePrompt
                            }

                            Spacer()
                                .frame(height: presentedFromTab ? 180 : 120)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                }
                
                Spacer()
            }
            
            // Bottom Buttons
            VStack {
                Spacer()
                bottomButtons
            }
        }
        .dismissKeyboardOnTap() // Dismiss keyboard on tap
        .sheet(isPresented: $showingCharacterTypePicker) {
            if let index = selectedCharacterIndex {
                CharacterTypePickerView(
                    selectedType: $characters[index].type,
                    selectedGender: $characters[index].gender,
                    selectedRelationship: $characters[index].relationship
                )
            }
        }
        .sheet(isPresented: $showingSavedCharacters) {
            SavedCharactersPickerView(
                savedCharacters: characterViewModel.savedCharacters,
                onSelect: { savedCharacter in
                    addCharacterFromSaved(savedCharacter)
                    showingSavedCharacters = false
                }
            )
        }
        .fullScreenCover(isPresented: $showingPaywall) {
            PaywallView()
        }
        .withGlassAlerts()
        .task {
            await subscriptionService.loadSubscription()
            await characterViewModel.loadSavedCharacters()
        }
        .onAppear {
            // Load saved character names from repository
            updateSavedCharacterNames()
        }
        .onChange(of: characterIndexToSave) { _, newValue in
            if let index = newValue, index < characters.count {
                let char = characters[index]
                Task {
                    await toggleSaveCharacter(char)
                }
                characterIndexToSave = nil
            }
        }
        .onChange(of: characters) { _, _ in
            validateContentSafety()
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        ZStack {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
                
                Spacer()
            }
            
            Text("step_2_title".localized)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            HStack {
                Spacer()
                
                if showCoinBalance {
                    CompactCoinBalanceView()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        VStack(spacing: 8) {
            Text("step_2_of_4".localized)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
            
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 8, height: 8)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
                
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 8, height: 8)
                
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
    
    // MARK: - Info Card
    
    private var infoCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 28))
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("add_hero".localized)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Text(String(format: "min_max_characters".localized, maxCharacters))
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .dwGlassCard()
    }
    
    // MARK: - Add Character Button
    
    private var addCharacterButton: some View {
        Button(action: {
            // Check if free user trying to add 2nd character
            if subscriptionService.currentTier == .free && characters.count >= 1 {
                DWLogger.shared.logAnalyticsEvent("paywall_triggered", parameters: [
                    "source": "character_limit",
                    "current_tier": "free",
                    "character_count": characters.count
                ])
                showingPaywall = true
            } else {
                characters.append(StoryCharacter())
            }
        }) {
            VStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("character_add".localized)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                    )
                    .foregroundColor(.white.opacity(0.4))
            )
        }
    }
    
    // MARK: - Upgrade Prompt
    
    private var upgradePrompt: some View {
        Group {
            if subscriptionService.currentTier != .pro {
                Button(action: {
                    showingPaywall = true
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 32))
                            .foregroundColor(Color(hex: "FFD700"))
                        
                        let nextLimit = subscriptionService.currentTier == .free ? 4 : 6
                        Text(String(format: "upgrade_for_characters".localized, nextLimit))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "FFD700"))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: "FFD700").opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color(hex: "FFD700").opacity(0.5), lineWidth: 2)
                            )
                    )
                }
                .transition(.opacity)
            }
        }
    }
    
    // MARK: - Bottom Buttons
    
    private var bottomButtons: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("back".localized)
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(width: 100, height: 48)
                .background(Color.white.opacity(0.2))
                .cornerRadius(12)
            }
            
            Button(action: onNext) {
                HStack(spacing: 8) {
                    Text("continue".localized)
                        .font(.system(size: 18, weight: .bold))
                    
                    Image(systemName: "arrow.forward")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(Color(red: 0.545, green: 0.361, blue: 0.965))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: Color.purple.opacity(0.3), radius: 20, x: 0, y: 10)
            }
            .disabled(!isValidToProgress)
            .opacity(isValidToProgress ? 1 : 0.5)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, presentedFromTab ? 100 : 24)
    }
    
    // MARK: - Saved Characters Button
    
    private var savedCharactersButton: some View {
        Button(action: {
            showingSavedCharacters = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color(red: 0.902, green: 0.475, blue: 0.976))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("character_select_saved".localized)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(String(format: "character_count".localized, characterRepository.characters.count))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.15))
                    .background(.ultraThinMaterial.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [Color(red: 0.902, green: 0.475, blue: 0.976).opacity(0.5), Color.purple.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: Color(red: 0.902, green: 0.475, blue: 0.976).opacity(0.2), radius: 8, x: 0, y: 4)
        }
    }
    
    // MARK: - Helper Functions
    
    private func addCharacterFromSaved(_ savedCharacter: Character) {
        guard characters.count < maxCharacters else { return }

        // Debug log to verify saved character type
        print("📝 Adding character from saved: \(savedCharacter.name), type: \(savedCharacter.type.displayName)")

        let newCharacter = StoryCharacter(
            type: savedCharacter.type,
            name: savedCharacter.name,
            age: savedCharacter.age,
            gender: savedCharacter.gender ?? .unspecified,
            relationship: savedCharacter.relationship,
            description: savedCharacter.description ?? ""
        )

        print("📝 Created story character: \(newCharacter.name), type: \(newCharacter.type.displayName)")

        // Check if there's an empty slot (character with no name)
        if let emptyIndex = characters.firstIndex(where: { $0.name.isEmpty }) {
            // Remove the empty slot and insert new character to force UI update
            characters.remove(at: emptyIndex)
            characters.insert(newCharacter, at: emptyIndex)
            charactersFromSaved.insert(newCharacter.id)
        } else {
            // No empty slot, append as new
            characters.append(newCharacter)
            charactersFromSaved.insert(newCharacter.id)
        }
    }
    
    func toggleSaveCharacter(_ character: StoryCharacter) async {
        // Check tier - free users get paywall
        if subscriptionService.currentTier == .free {
            await MainActor.run {
                showingPaywall = true
            }
            return
        }

        // Toggle logic
        if savedCharacterNames.contains(character.name) {
            // Already saved - delete from backend
            // Find the character ID from repository
            if let savedChar = characterRepository.characters.first(where: { $0.name == character.name }) {
                do {
                    try await CharacterService.shared.deleteCharacter(id: savedChar.id)
                    try await CharacterRepository.shared.refresh()
                    
                    await MainActor.run {
                        savedCharacterNames.remove(character.name)
                        
                        // Notify that character count changed
                        NotificationCenter.default.post(name: .characterCountDidChange, object: nil)
                        
                        GlassAlertManager.shared.info(
                            "character_save_removed".localized,
                            message: String(format: "character_save_removed_message".localized, character.name)
                        )
                        
                        DWLogger.shared.info("✅ Character deleted and repository refreshed: \(savedChar.id)", category: .character)
                    }
                } catch {
                    await MainActor.run {
                        GlassAlertManager.shared.error(
                            "error".localized,
                            message: "Failed to delete character"
                        )
                    }
                    DWLogger.shared.error("Failed to delete character", error: error, category: .character)
                }
            }
        } else {
            // Not saved - save it
            let characterToSave = Character(
                name: character.name,
                type: character.type,
                relationship: character.relationship,
                gender: character.gender,
                age: character.age,
                description: character.description.isEmpty ? nil : character.description
            )

            do {
                // Save via CharacterService and refresh repository
                let savedCharacter = try await CharacterService.shared.saveCharacter(characterToSave)
                try await CharacterRepository.shared.refresh()
                
                await MainActor.run {
                    savedCharacterNames.insert(character.name)
                    
                    // Notify that character count changed
                    NotificationCenter.default.post(name: .characterCountDidChange, object: nil)
                    
                    GlassAlertManager.shared.success(
                        "character_save_success".localized,
                        message: String(format: "character_save_success_message".localized, character.name)
                    )
                    
                    DWLogger.shared.info("✅ Character saved and repository refreshed: \(savedCharacter.id)", category: .character)
                }
            } catch {
                await MainActor.run {
                    GlassAlertManager.shared.error(
                        "character_save_failed".localized,
                        message: "character_save_failed_message".localized
                    )
                }
                DWLogger.shared.error("Failed to save character", error: error, category: .character)
            }
        }
    }

    private func validateContentSafety() {
        warningDebounceTask?.cancel()
        warningDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                let currentLanguage = LocalizationManager.shared.currentLanguage.rawValue
                
                var foundWarning: String? = nil
                
                for character in characters {
                    if let warning = ContentSafetyValidator.getSoftWarning(for: character.name, language: currentLanguage) {
                        foundWarning = warning.message
                        break
                    }
                    if let warning = ContentSafetyValidator.getSoftWarning(for: character.description, language: currentLanguage) {
                        foundWarning = warning.message
                        break
                    }
                }
                
                withAnimation {
                    contentSafetyWarning = foundWarning
                }
            }
        }
    }
    
    private func updateSavedCharacterNames() {
        savedCharacterNames = Set(characterRepository.characters.map { $0.name })
    }
}

// MARK: - Saved Characters Picker

struct SavedCharactersPickerView: View {
    let savedCharacters: [Character]
    let onSelect: (Character) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient.dwBackground
                    .ignoresSafeArea()

                if savedCharacters.isEmpty {
                    // Empty State
                    VStack(spacing: 24) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.6))

                        VStack(spacing: 8) {
                            Text("step2_no_saved".localized)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)

                            Text("step2_add_hero".localized)
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                    }
                } else {
                    // Grid Layout
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ],
                            spacing: 16
                        ) {
                            ForEach(savedCharacters) { character in
                                SavedCharacterPickerCard(
                                    character: character,
                                    onTap: {
                                        onSelect(character)
                                        dismiss()
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("saved_characters_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("saved_characters_title".localized)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

// MARK: - Saved Character Picker Card

struct SavedCharacterPickerCard: View {
    let character: Character
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Icon
                HStack {
                    Text(character.type.icon)
                        .font(.system(size: 50))

                    Spacer()
                }

                Spacer()

                // Character info
                VStack(alignment: .leading, spacing: 4) {
                    Text(character.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(character.type.displayName)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.8))

                    if let age = character.age {
                        Text(String(format: "age_years".localized, age))
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                // Add icon
                HStack {
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(red: 0.902, green: 0.475, blue: 0.976))
                }
            }
            .frame(height: 180)
            .padding(16)
            .dwGlassCard()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Character Card

struct CharacterCardView: View {
    @Binding var character: StoryCharacter
    let characterNumber: Int
    var isMainCharacter: Bool = false
    var isSaved: Bool = false
    var isFromSaved: Bool = false
    let onDelete: () -> Void
    let onSelectType: () -> Void
    var onSave: (() -> Void)? = nil
    var scrollProxy: ScrollViewProxy? = nil

    private enum Field { case name, age, description }
    @FocusState private var focusedField: Field?

    private var canSave: Bool {
        !character.name.isEmpty && character.name.count >= 2
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 12) {
                    // Circle with star for main character, number for others
                    Circle()
                        .fill(isMainCharacter ? 
                            LinearGradient(
                                colors: [Color(hex: "FFD700"), Color(hex: "FFA500")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) : 
                            LinearGradient(
                                colors: [Color.white.opacity(0.3), Color.white.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                        .overlay(
                            Group {
                                if isMainCharacter {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                } else {
                                    Text("\(characterNumber)")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        )
                    
                    // Title: "Ana Karakter" for first, "Karakter N" for others
                    Text(isMainCharacter ? "main_character_badge".localized : String(format: "character_title".localized, characterNumber))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    if let onSave = onSave, canSave {
                        Button(action: {
                            // Eğer kayıtlı karakterlerden seçilmişse, kaydetme
                            if !isFromSaved {
                                onSave()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: (isSaved || isFromSaved) ? "bookmark.fill" : "bookmark")
                                    .font(.system(size: 14))
                                Text((isSaved || isFromSaved) ? "character_saved".localized : "character_save".localized)
                                    .font(.system(size: 13, weight: .semibold))
                                    .lineLimit(1)
                                    .fixedSize()
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.902, green: 0.475, blue: 0.976), Color.purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(8)
                        }
                        .disabled(isFromSaved)
                        .opacity(isFromSaved ? 0.7 : 1.0)
                    }

                    Button(action: onDelete) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 40, height: 40)
                    }
                }
            }
            
            // Character Type Selector
            Button(action: onSelectType) {
                HStack {
                    Text(character.type.icon + " " + character.type.displayName)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            
            // Name Field
            VStack(alignment: .leading, spacing: 8) {
                Text("character_name_required".localized)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                TextField("character_name_placeholder".localized, text: $character.name)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .age }
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .padding(14)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.words)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
            
            // Age Field (Optional)
            VStack(alignment: .leading, spacing: 8) {
                Text("character_age_optional".localized)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                TextField("age_example".localized, value: $character.age, format: .number)
                    .focused($focusedField, equals: .age)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .description }
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .keyboardType(.numberPad)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
            
            // Description Field (Optional)
            VStack(alignment: .leading, spacing: 8) {
                Text("character_description_optional".localized)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                TextField("character_description_placeholder".localized, text: $character.description, axis: .vertical)
                    .focused($focusedField, equals: .description)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .lineLimit(3...5)
                    .padding(14)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.sentences)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
        }
        .padding(20)
        .dwGlassCard()
        .onChange(of: focusedField) { _, newValue in
            if newValue != nil {
                // Delay scroll slightly to ensure keyboard is visible
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        scrollProxy?.scrollTo("character_\(character.id)", anchor: .top)
                    }
                }
            }
        }
    }
}

// MARK: - Character Type Picker

struct CharacterTypePickerView: View {
    @Binding var selectedType: CharacterType
    @Binding var selectedGender: CharacterGender
    @Binding var selectedRelationship: CharacterRelationship?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient.dwBackground
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Character Type Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("character_type_required".localized)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            
                            ForEach(CharacterCategory.allCases, id: \.self) { category in
                                characterCategorySection(category)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.08))
                        )
                        .padding(.horizontal, 16)
                        
                        // Gender Selector (only if needed)
                        if selectedType.needsGender {
                            CharacterGenderSelector(selectedGender: $selectedGender)
                                .padding(.horizontal, 16)
                        }
                        
                        // Relationship Selector (only for people)
                        if selectedType.canHaveRelationship {
                            CharacterRelationshipSelector(selectedRelationship: $selectedRelationship)
                                .padding(.horizontal, 16)
                        }
                        
                        Spacer()
                            .frame(height: 40)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("character_type_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("character_type_title".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
    private func characterCategorySection(_ category: CharacterCategory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category.displayName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 20)
            
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(CharacterType.allCases.filter { $0.category == category }, id: \.self) { type in
                            Button(action: {
                                selectedType = type
                                withAnimation {
                                    proxy.scrollTo(type, anchor: .center)
                                }
                            }) {
                                VStack(spacing: 6) {
                                    Text(type.icon)
                                        .font(.system(size: 32))
                                    
                                    Text(type.displayName)
                                        .font(.system(size: 11, weight: selectedType == type ? .semibold : .regular))
                                        .foregroundColor(.white)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .frame(width: 70)
                                }
                                .frame(width: 85, height: 85)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedType == type ? Color.blue.opacity(0.25) : Color.white.opacity(0.06))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedType == type ? Color.blue : Color.white.opacity(0.15), lineWidth: selectedType == type ? 2 : 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .id(type)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo(selectedType, anchor: .center)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Story Character Model

struct StoryCharacter: Identifiable, Equatable {
    let id = UUID()
    var type: CharacterType = .child
    var name: String = ""
    var age: Int?
    var gender: CharacterGender = .unspecified
    var relationship: CharacterRelationship?
    var description: String = ""
}

// MARK: - Preview

#Preview {
    StoryCreationStep2View(
        characters: .constant([StoryCharacter()]),
        showCoinBalance: true,
        onNext: {},
        onBack: {}
    )
}

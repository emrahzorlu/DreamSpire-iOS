//
//  CharacterEditView.swift
//  DreamSpire
//
//  Character editing view with proper implementation
//

import SwiftUI

struct CharacterEditView: View {
    let character: Character
    var onUpdate: ((Character) -> Void)? = nil
    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var selectedType: CharacterType
    @State private var selectedRelationship: CharacterRelationship?  // NEW
    @State private var selectedGender: CharacterGender
    @State private var age: String
    @State private var description: String
    
    // Content Safety
    @State private var contentSafetyWarning: ContentSafetyValidator.SoftWarning?
    @State private var warningDebounceTask: Task<Void, Never>?

    init(character: Character, onUpdate: ((Character) -> Void)? = nil) {
        self.character = character
        self.onUpdate = onUpdate
        _name = State(initialValue: character.name)
        _selectedType = State(initialValue: character.type)
        _selectedRelationship = State(initialValue: character.relationship)  // NEW
        _selectedGender = State(initialValue: character.gender ?? .unspecified)
        _age = State(initialValue: character.age.map { String($0) } ?? "")
        _description = State(initialValue: character.description ?? "")
    }

    var body: some View {
        ZStack {
            LinearGradient.dwBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Header
                headerView

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Preview
                        VStack(spacing: 12) {
                            Text(selectedType.icon)
                                .font(.system(size: 80))

                            Text(name.isEmpty ? "character_name_placeholder".localized : name)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)

                            Text(selectedType.displayName)
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(16)

                        // Form Fields
                        VStack(spacing: 16) {
                            // Name
                            VStack(alignment: .leading, spacing: 8) {
                                Text("character_name_label".localized)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)

                                TextField("character_name_placeholder".localized, text: $name)
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(Color.white.opacity(0.15))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                                    .onChange(of: name) { _, newValue in
                                        validateContentSafety()
                                    }

                                // SUBTLE Name Safety Warning
                                if let warning = contentSafetyWarning, !name.isEmpty && ContentSafetyValidator.getSoftWarning(for: name, language: LocalizationManager.shared.currentLanguage.rawValue) != nil {
                                    HStack(spacing: 4) {
                                        Image(systemName: "exclamationmark.shield.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.orange)
                                        Text(warning.message)
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                    .padding(.top, 4)
                                    .transition(.opacity)
                                }
                            }

                            // Type
                            VStack(alignment: .leading, spacing: 8) {
                                Text("character_type_label".localized)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(CharacterType.allCases, id: \.self) { type in
                                            TypeButton(type: type, isSelected: selectedType == type) {
                                                selectedType = type
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Gender Selector (only if needed)
                            if selectedType.needsGender {
                                CharacterGenderSelector(selectedGender: $selectedGender)
                            }
                            
                            // Relationship (only for people types)
                            if selectedType.canHaveRelationship {
                                CharacterRelationshipSelector(selectedRelationship: $selectedRelationship)
                            }

                            // Age
                            VStack(alignment: .leading, spacing: 8) {
                                Text("character_age_label".localized)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)

                                TextField("character_age_placeholder".localized, text: $age)
                                    .keyboardType(.numberPad)
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(Color.white.opacity(0.15))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            }

                            // Description
                            VStack(alignment: .leading, spacing: 8) {
                                Text("character_description_label".localized)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)

                                TextEditor(text: $description)
                                    .frame(height: 100)
                                    .padding(12)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                                    .foregroundColor(.white)
                                    .scrollContentBackground(.hidden)
                                    .onChange(of: description) { _, newValue in
                                        validateContentSafety()
                                    }
                                
                                // Hint text for description
                                Text("character_description_hint".localized)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.6))
                                    .italic()
                                
                                // General Content Safety Warning UI (if not name)
                                if let warning = contentSafetyWarning, ContentSafetyValidator.getSoftWarning(for: name, language: LocalizationManager.shared.currentLanguage.rawValue) == nil {
                                    HStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                        
                                        Text(warning.message)
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.9))
                                        
                                        Spacer()
                                    }
                                    .padding(10)
                                    .background(Color.orange.opacity(0.15))
                                    .cornerRadius(8)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                                }
                            }
                        }
                        .padding(20)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(16)

                        // Save Button - Larger tap area
                        Button(action: {
                            hideKeyboard()
                            saveChanges()
                        }) {
                            Text(contentSafetyWarning == nil ? "save_changes".localized : "Kaydedilemez")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: (name.isEmpty || contentSafetyWarning != nil) ? [Color.gray] : [Color.blue, Color.purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(name.isEmpty || contentSafetyWarning != nil)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                }
            }
        }
        .dismissKeyboardOnTap()
        .withGlassAlerts()
        .preferredColorScheme(.light)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.9))
                    .symbolRenderingMode(.hierarchical)
            }

            Spacer()

            Text("edit_character".localized)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            // Invisible spacer for centering
            Image(systemName: "chevron.left")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.clear)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }

    // MARK: - Actions

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func validateContentSafety() {
        warningDebounceTask?.cancel()
        warningDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                let currentLanguage = LocalizationManager.shared.currentLanguage.rawValue
                
                let nameWarning = ContentSafetyValidator.getSoftWarning(for: name, language: currentLanguage)
                let descWarning = ContentSafetyValidator.getSoftWarning(for: description, language: currentLanguage)
                
                withAnimation {
                    contentSafetyWarning = nameWarning ?? descWarning
                }
            }
        }
    }

    private func saveChanges() {
        var updatedCharacter = character
        updatedCharacter.name = name
        updatedCharacter.type = selectedType
        updatedCharacter.relationship = selectedType.canHaveRelationship ? selectedRelationship : nil
        updatedCharacter.gender = selectedType.needsGender ? selectedGender : selectedType.defaultGender
        updatedCharacter.age = Int(age)
        updatedCharacter.description = description.isEmpty ? nil : description

        Task {
            do {
                let saved = try await CharacterService.shared.updateCharacter(id: character.id, character: updatedCharacter)
                
                // Immediately refresh repository to update character list
                try await CharacterRepository.shared.refresh()

                await MainActor.run {
                    // Show floating success toast instead of blocking dialog
                    GlassAlertManager.shared.success(
                        "success".localized,
                        message: "character_saved_success".localized
                    )

                    // Call update callback instead of notification
                    onUpdate?(saved)
                    
                    // Notify that character changed
                    NotificationCenter.default.post(name: .characterCountDidChange, object: nil)
                    
                    DWLogger.shared.info("✅ Character updated and repository refreshed: \(saved.id)", category: .character)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    GlassAlertManager.shared.error(
                        "Hata",
                        message: error.localizedDescription
                    )
                }
            }
        }
    }
}

// MARK: - Type Button

struct TypeButton: View {
    let type: CharacterType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(type.icon)
                    .font(.system(size: 32))
                Text(type.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
            }
            .frame(width: 80)
            .padding(.vertical, 12)
            .background(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.white.opacity(0.5) : Color.clear, lineWidth: 2)
            )
        }
    }
}

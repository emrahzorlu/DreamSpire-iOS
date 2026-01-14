//
//  CharacterCreateView.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025-11-02
//

import SwiftUI

struct CharacterCreateView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = CharacterCreateViewModel()
    
    private enum FormFocus {
        case name, age, description
    }
    
    @State private var name: String = ""
    @State private var selectedType: CharacterType = .child
    @State var selectedRelationship: CharacterRelationship? = nil  // NEW
    @State var selectedGender: CharacterGender = .unspecified
    @State private var age: String = ""
    @State private var description: String = ""
    @FocusState private var focusedField: FormFocus?
    
    // Content Safety
    @State private var contentSafetyWarning: ContentSafetyValidator.SoftWarning?
    @State private var warningDebounceTask: Task<Void, Never>?
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient.dwBackground
                    .ignoresSafeArea()
                
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            // Preview
                            characterPreviewView
                            
                            // Form
                            formView
                            
                            // Save Button
                            saveButtonView
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                    }
                    .onChange(of: focusedField) { _, newValue in
                        if let field = newValue {
                            withAnimation {
                                proxy.scrollTo(field, anchor: .center)
                            }
                        }
                    }
                }
            }
            .dismissKeyboardOnTap() // General dismiss on tap
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.9))
                            .symbolRenderingMode(.hierarchical)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("character_new".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onChange(of: viewModel.showingSuccessAlert) { _, isShowing in
            if isShowing {
                // Show floating success toast instead of blocking dialog
                GlassAlertManager.shared.success(
                    "success".localized,
                    message: "character_saved_success".localized
                )
                
                // Return to previous screen immediately
                dismiss()
                
                viewModel.showingSuccessAlert = false
            }
        }
        .onChange(of: viewModel.error) { _, newError in
            if let error = newError {
                GlassAlertManager.shared.errorAlert(
                    "error".localized,
                    message: error
                ) {
                    viewModel.error = nil
                }
            }
        }
        .withGlassAlerts()
        .preferredColorScheme(.light)
    }
    
    // MARK: - Character Preview
    
    private var characterPreviewView: some View {
        VStack(spacing: 12) {
            Text(selectedType.icon)
                .font(.system(size: 80))
            
            if !name.isEmpty {
                Text(name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Text("character_name_placeholder".localized)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Text(selectedType.displayName)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .dwGlassCard()
    }
    
    // MARK: - Form
    
    private var formView: some View {
        VStack(spacing: 20) {
            // Name Input - MOVED TO TOP
            VStack(alignment: .leading, spacing: 8) {
                Text("character_name_required".localized)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                
                TextField("character_name_placeholder".localized, text: $name)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .age }
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
                        validateContentSafety(text: newValue)
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
            .id(FormFocus.name)
            
            // Character Type
            characterTypePickerView
            
            // Gender Selector (only if needed)
            if selectedType.needsGender {
                CharacterGenderSelector(selectedGender: $selectedGender)
            }
            
            // Relationship Selector (only for people, not pets)
            if selectedType.canHaveRelationship {
                CharacterRelationshipSelector(selectedRelationship: $selectedRelationship)
            }
            
            // Age Input
            VStack(alignment: .leading, spacing: 8) {
                Text("character_age_label".localized)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                
                TextField("character_age".localized, text: $age)
                    .focused($focusedField, equals: .age)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .keyboardType(.numberPad)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            }
            .id(FormFocus.age)
            
            // Description Input
            VStack(alignment: .leading, spacing: 8) {
                Text("character_description_label".localized)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                
                TextEditor(text: $description)
                    .focused($focusedField, equals: .description)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .frame(height: 100)
                    .padding(12)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .onChange(of: description) { _, newValue in
                        validateContentSafety(text: newValue)
                    }
            }
            .id(FormFocus.description)
            
            VStack(alignment: .leading, spacing: 8) {
                
                if description.isEmpty {
                    Text("character_description_hint".localized)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                }
                
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
        .padding(16)
        .dwGlassCard()
    }
    
    // MARK: - Character Type Picker
    
    private var characterTypePickerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("character_type_required".localized)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            
            // Categories - dynamically show all available categories
            VStack(spacing: 12) {
                ForEach(CharacterCategory.allCases, id: \.self) { category in
                    characterCategorySection(category)
                }
            }
        }
    }
    
    private func characterCategorySection(_ category: CharacterCategory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category.displayName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 4)
            
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(CharacterType.allCases.filter { $0.category == category }, id: \.self) { type in
                            CharacterTypeButton(
                                type: type,
                                isSelected: selectedType == type,
                                action: {
                                    selectedType = type
                                    withAnimation {
                                        proxy.scrollTo(type, anchor: .center)
                                    }
                                }
                            )
                            .id(type)
                        }
                    }
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
    
    // MARK: - Save Button
    
    private var saveButtonView: some View {
        Button(action: {
            saveCharacter()
        }) {
            if viewModel.isSaving {
                ProgressView()
                    .tint(.white)
            } else {
                Text("character_save".localized)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: canSave ? [Color.blue, Color.purple] : [Color.gray, Color.gray],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(14)
        .disabled(!canSave || viewModel.isSaving)
        .opacity(canSave ? 1.0 : 0.5)
    }
    
    // MARK: - Helpers
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && contentSafetyWarning == nil
    }
    
    private func validateContentSafety(text: String) {
        warningDebounceTask?.cancel()
        warningDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                // Check both name and description
                let currentLanguage = LocalizationManager.shared.currentLanguage.rawValue
                
                let nameWarning = ContentSafetyValidator.getSoftWarning(for: name, language: currentLanguage)
                let descWarning = ContentSafetyValidator.getSoftWarning(for: description, language: currentLanguage)
                
                contentSafetyWarning = nameWarning ?? descWarning
            }
        }
    }
    
    private func saveCharacter() {
        var character = Character(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            type: selectedType,
            relationship: selectedType.canHaveRelationship ? selectedRelationship : nil,
            gender: selectedType.needsGender ? selectedGender : selectedType.defaultGender
        )
        
        if let ageInt = Int(age.trimmingCharacters(in: .whitespacesAndNewlines)) {
            character.age = ageInt
        }
        
        if !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            character.description = description.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        Task {
            await viewModel.saveCharacter(character)
        }
    }
}

// MARK: - Character Type Button

struct CharacterTypeButton: View {
    let type: CharacterType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(type.icon)
                    .font(.system(size: 32))
                
                Text(type.displayName)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 70)
            }
            .frame(width: 85, height: 85)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.white.opacity(0.25) : Color.white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.white.opacity(0.5) : Color.white.opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Character Create ViewModel

@MainActor
class CharacterCreateViewModel: ObservableObject {
    @Published var isSaving = false
    @Published var error: String?
    @Published var showingSuccessAlert = false
    
    private let characterService = CharacterService.shared
    private let subscriptionService = SubscriptionService.shared
    
    func saveCharacter(_ character: Character) async {
        // Check if can save
        let repository = CharacterRepository.shared
        let savedCount = repository.characters.count
        let (allowed, reason) = subscriptionService.canSaveCharacter(currentCount: savedCount)
        
        guard allowed else {
            error = reason
            return
        }
        
        isSaving = true
        error = nil
        
        DWLogger.shared.info("Saving character: \(character.name)", category: .character)
        
        do {
            let savedCharacter = try await characterService.saveCharacter(character)
            
            // Immediately refresh repository to update character list
            try await repository.refresh()
            
            DWLogger.shared.logAnalyticsEvent("character_saved", parameters: [
                "type": character.type.rawValue,
                "has_age": character.age != nil,
                "has_description": character.description != nil
            ])
            
            // Notify that character count changed so other views can refresh
            NotificationCenter.default.post(name: .characterCountDidChange, object: nil)
            
            DWLogger.shared.info("✅ Character saved and repository refreshed: \(savedCharacter.id)", category: .character)
            showingSuccessAlert = true
            
        } catch {
            self.error = error.localizedDescription
            DWLogger.shared.error("Failed to save character", error: error, category: .character)
        }
        
        isSaving = false
    }
}

// MARK: - Preview

#Preview {
    CharacterCreateView()
}

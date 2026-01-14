//
//  MyCharactersView.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025-11-02
//

import SwiftUI
import Combine

struct MyCharactersView: View {
    @ObservedObject private var viewModel = CharacterBuilderViewModel.shared
    @ObservedObject private var repository = CharacterRepository.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    @Environment(\.dismiss) var dismiss

    @State private var selectedCharacter: Character?
    @State private var showingCreateSheet = false
    @State private var characterToDelete: Character?
    @State private var hasLoaded = false
    @State private var showingPaywall = false
    
    private var characterLimit: Int {
        switch subscriptionService.currentTier {
        case .free: return 0     // Free users cannot save characters
        case .plus: return 10
        case .pro: return 999
        }
    }
    
    private var canSaveCharacters: Bool {
        return subscriptionService.currentTier != .free
    }
    
    var body: some View {
        ZStack {
            LinearGradient.dwBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header - Fixed at top
                headerView
                
                // Content
                if repository.isLoading && !hasLoaded {
                    loadingView
                } else if let error = repository.error {
                    errorView(message: error.localizedDescription)
                } else if repository.characters.isEmpty {
                    emptyStateView
                } else {
                    charactersGridView
                }
            }
        }
        .fullScreenCover(item: $selectedCharacter) { character in
            CharacterDetailView(
                character: character,
                onDelete: {
                    // Delete using repository (handles cache automatically)
                    Task {
                        try? await repository.deleteCharacter(id: character.id)
                    }
                    GlassAlertManager.shared.success(
                        "character_deleted".localized,
                        message: String(format: "character_deleted_message".localized, character.name)
                    )
                },
                onUpdate: { updatedCharacter in
                    // Repository handles update automatically
                    Task {
                        try? await repository.updateCharacter(id: updatedCharacter.id, character: updatedCharacter)
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showingCreateSheet, onDismiss: {
            // No need to reload - repository handles caching
            hasLoaded = true
        }) {
            CharacterCreateView()
        }
        .fullScreenCover(isPresented: $showingPaywall) {
            PaywallView()
        }
        .task {
            // Skip if already loaded (repository uses cache)
            guard !hasLoaded else {
                DWLogger.shared.debug("✅ Characters already loaded, using cache", category: .general)
                return
            }

            do {
                try await subscriptionService.loadSubscription()
                _ = try await repository.getCharacters()
                hasLoaded = true
                DWLogger.shared.info("✅ MyCharactersView loaded from repository", category: .general)
            } catch {
                DWLogger.shared.error("Failed to load characters", error: error, category: .general)
            }
        }
        .withGlassDialogs()
        .withGlassAlerts()
        .preferredColorScheme(.light)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: 16) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
            }

            Text("my_characters_title".localized)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            if canSaveCharacters {
                if characterLimit < 999 {
                    Text("\(repository.characters.count)/\(characterLimit)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(repository.characters.count >= characterLimit ? .orange : Color(red: 0.902, green: 0.475, blue: 0.976))
                } else {
                    Text("\(repository.characters.count)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            Spacer()

            Button(action: {
                if !canSaveCharacters {
                    showingPaywall = true
                } else if repository.characters.count >= characterLimit {
                    if subscriptionService.currentTier == .plus {
                        // For Plus users reaching 10 chars, offer Pro upgrade
                        GlassDialogManager.shared.confirm(
                            title: "pro_upgrade_limited_chars".localized,
                            message: "pro_upgrade_unlimited_chars_message".localized,
                            confirmTitle: "upgrade".localized,
                            confirmAction: { showingPaywall = true }
                        )
                    } else {
                        GlassAlertManager.shared.warning(
                            "character_limit".localized,
                            message: String(format: "character_limit_message".localized, characterLimit)
                        )
                    }
                } else {
                    showingCreateSheet = true
                }
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(!canSaveCharacters ? .orange : .white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    // MARK: - Characters Grid
    
    private var charactersGridView: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 16
            ) {
                ForEach(repository.characters) { character in
                    SavedCharacterCard(
                        character: character,
                        onTap: {
                            selectedCharacter = character
                        },
                        onDelete: {
                            GlassDialogManager.shared.confirm(
                                title: "character_delete_title".localized,
                                message: "character_delete_message".localized,
                                confirmTitle: "delete".localized,
                                confirmAction: {
                                    // Delete using repository (handles cache automatically)
                                    Task {
                                        try? await repository.deleteCharacter(id: character.id)
                                    }

                                    // Show success message
                                    GlassAlertManager.shared.success(
                                    "character_deleted".localized,
                                    message: String(format: "character_deleted_message".localized, character.name)
                                    )
                                },
                                isDestructive: true
                            )
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: repository.characters.count)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
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
            
            Button(action: {
                showingCreateSheet = true
            }) {
                Text("character_add".localized)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Loading & Error
    
    private var loadingView: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 16
            ) {
                ForEach(0..<6, id: \.self) { _ in
                    CharacterCardSkeleton()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.white.opacity(0.6))
            
            Text(message)
                .font(.system(size: 17))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Button("retry".localized) {
                Task {
                    do {
                        _ = try await repository.getCharacters(forceRefresh: true)
                        hasLoaded = true
                    } catch {
                        DWLogger.shared.error("Retry failed", error: error, category: .general)
                    }
                }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.2))
            .cornerRadius(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
}

// MARK: - Saved Character Card

struct SavedCharacterCard: View {
    let character: Character
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Icon and delete button
                HStack {
                    Text(character.type.icon)
                        .font(.system(size: 50))
                    
                    Spacer()
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(PlainButtonStyle())
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
                
                // Usage info (only show if character has been used)
                let usageCount = character.storiesCreated?.count ?? character.timesUsed ?? 0
                if usageCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 10))

                        Text(String(format: "used_in_stories".localized, usageCount))
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.white.opacity(0.6))
                }
            }
            .frame(height: 180)
            .padding(16)
            .dwGlassCard()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    MyCharactersView()
}

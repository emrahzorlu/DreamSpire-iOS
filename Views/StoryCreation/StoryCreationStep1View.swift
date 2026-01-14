//
//  StoryCreationStep1View.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//

import SwiftUI

struct StoryCreationStep1View: View {
    @Binding var storyIdea: String
    @Binding var selectedGenre: String
    @Binding var selectedTone: String
    @Environment(\.dismiss) var dismiss
    
    // Keyboard Focus State
    @FocusState private var isTextEditorFocused: Bool

    var showCoinBalance: Bool = false
    var showDismissButton: Bool = true
    var presentedFromTab: Bool = false
    let onNext: () -> Void

    @State private var characterCount: Int = 0
    @State private var contentSafetyWarning: ContentSafetyValidator.SoftWarning?
    @State private var warningDebounceTask: Task<Void, Never>?
    
    var genres: [(String, String)] {
        [
            ("🌙", "genre_bedtime".localized),
            ("🏰", "genre_adventure".localized),
            ("👨‍👩‍👧", "genre_family".localized),
            ("🤝", "genre_friendship".localized),
            ("🦄", "genre_fantasy".localized),
            ("🐾", "genre_animals".localized),
            ("👑", "genre_princess".localized),
            ("📚", "genre_classic".localized),
            ("🔍", "genre_mystery".localized)
        ]
    }
    
    var tones: [(String, String)] {
        [
            ("😌", "tone_calm".localized),
            ("🎉", "tone_exciting".localized),
            ("😄", "tone_funny".localized),
            ("😊", "tone_cheerful".localized),
            ("🔮", "tone_mysterious".localized),
            ("🤗", "tone_heartwarming".localized),
            ("⚡", "tone_adventurous".localized),
            ("🌙", "tone_relaxing".localized),
            ("💕", "tone_romantic".localized)
        ]
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
                
                // Content
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 24) {
                            // Story Idea Section
                            storyIdeaSection
                                .id("storyIdea")

                            // Genre Section
                            genreSection

                            // Tone Section
                            toneSection

                            Spacer()
                                .frame(height: presentedFromTab ? 180 : 100)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .onChange(of: isTextEditorFocused) { _, newValue in
                            if newValue {
                                // Delay slightly to allow keyboard to start appearing, 
                                // then scroll without heavy animation if it's the first focus
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        proxy.scrollTo("storyIdea", anchor: .top)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Spacer()
            }
            
            // Bottom Button
            VStack {
                Spacer()
                continueButton
            }
        }
        .dismissKeyboardOnTap() // Dismiss keyboard when tapping outside
        .onAppear {
            // Sync character count with current storyIdea value
            characterCount = storyIdea.count
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        ZStack {
            HStack {
                if showDismissButton && !presentedFromTab {
                    Button(action: {
                        DWLogger.shared.info("Dismissing story creation", category: .ui)
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                } else {
                    Color.clear
                        .frame(width: 44, height: 44)
                }
                
                Spacer()
            }
            
            Text("step1_create_story".localized)
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
            Text("step1_progress".localized)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
            
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
                
                Circle()
                    .fill(Color.white.opacity(0.3))
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
    
    // MARK: - Story Idea Section
    
    private var storyIdeaSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("step1_story_idea".localized)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    if storyIdea.isEmpty {
                        Text("step1_placeholder".localized)
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7)) // More visible lighter color
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                    
                    TextField("", text: $storyIdea, axis: .vertical)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .padding(12)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.sentences)
                        .lineLimit(6...10)
                        .focused($isTextEditorFocused)
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
                .onChange(of: storyIdea) { _, newValue in
                    // Strict 500 character limit enforcement
                    if newValue.count > 500 {
                        DispatchQueue.main.async {
                            storyIdea = String(newValue.prefix(500))
                            characterCount = 500
                        }
                    } else {
                        characterCount = newValue.count
                    }

                    // Debounced content safety check
                    warningDebounceTask?.cancel()
                    warningDebounceTask = Task {
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
                        guard !Task.isCancelled else { return }

                        await MainActor.run {
                            // Get current language from settings
                            let currentLanguage = LocalizationManager.shared.currentLanguage.rawValue
                            contentSafetyWarning = ContentSafetyValidator.getSoftWarning(
                                for: storyIdea,
                                language: currentLanguage
                            )
                        }
                    }
                }
                
                // Content Safety Warning (Soft)
                if let warning = contentSafetyWarning {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.red)

                        Text(warning.message)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer()
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red.opacity(0.25))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.red.opacity(0.5), lineWidth: 1.5)
                            )
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            generateRandomIdea()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Text("💡")
                                .font(.system(size: 16))
                            Text("step1_get_inspired".localized)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.15))
                        )
                    }
                    .scaleEffect(1.0)
                    .animation(.easeInOut(duration: 0.1), value: storyIdea)

                    Spacer()

                    Text("\(characterCount) / 500")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(20)
        .dwGlassCard()
        .animation(.easeInOut(duration: 0.25), value: contentSafetyWarning != nil)
    }

    
    // MARK: - Genre Section
    
    private var genreSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("step1_select_genre".localized)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                ForEach(genres, id: \.1) { emoji, genre in
                    GenreButton(
                        emoji: emoji,
                        title: genre,
                        isSelected: selectedGenre == genre
                    ) {
                        selectedGenre = genre
                    }
                }
            }
        }
        .padding(20)
        .dwGlassCard()
    }
    
    // MARK: - Tone Section
    
    private var toneSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("step1_select_tone".localized)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                ForEach(tones, id: \.1) { emoji, tone in
                    GenreButton(
                        emoji: emoji,
                        title: tone,
                        isSelected: selectedTone == tone
                    ) {
                        selectedTone = tone
                    }
                }
            }
        }
        .padding(20)
        .dwGlassCard()
    }
    
    // MARK: - Continue Button
    
    private var continueButton: some View {
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
        .padding(.horizontal, 16)
        .padding(.bottom, presentedFromTab ? 100 : 24)
        .disabled(storyIdea.count < 10 || contentSafetyWarning != nil)
        .opacity((storyIdea.count < 10 || contentSafetyWarning != nil) ? 0.5 : 1)
    }
    
    // MARK: - Helper Functions
    
    private func generateRandomIdea() {
        let storyIdeas = [
            "inspiration_space_adventure".localized,
            "inspiration_underwater".localized,
            "inspiration_time_travel".localized,
            "inspiration_magical_forest".localized,
            "inspiration_robot_friend".localized,
            "inspiration_talking_animals".localized
        ]
        
        let randomIdea = storyIdeas.randomElement() ?? storyIdeas[0]
        storyIdea = randomIdea
        characterCount = randomIdea.count
        
        // Rastgele tür ve ton da seçelim
        if let randomGenre = genres.randomElement() {
            selectedGenre = randomGenre.1
        }
        if let randomTone = tones.randomElement() {
            selectedTone = randomTone.1
        }
    }
}

// MARK: - Genre Button

struct GenreButton: View {
    let emoji: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(emoji)
                    .font(.system(size: 24))
                
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(isSelected ? Color(red: 0.545, green: 0.361, blue: 0.965) : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(
                isSelected ? Color.white.opacity(0.9) : Color.white.opacity(0.2)
            )
            .cornerRadius(12)
        }
    }
}

// MARK: - Preview

#Preview {
    StoryCreationStep1View(
        storyIdea: .constant(""),
        selectedGenre: .constant("Macera"),
        selectedTone: .constant("Heyecanlı"),
        showCoinBalance: true,
        showDismissButton: true,
        onNext: {}
    )
}

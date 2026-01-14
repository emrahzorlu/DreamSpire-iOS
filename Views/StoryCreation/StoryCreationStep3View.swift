//
//  StoryCreationStep3View.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//  Updated for Coin System - Reading time removed (now in Step 2.5 as Duration)
//

import SwiftUI

struct StoryCreationStep3View: View {
    @Binding var settings: StorySettings
    @Environment(\.dismiss) var dismiss
    
    let onGenerate: () -> Void
    let onBack: () -> Void
    
    var ageRanges: [String] {
        [
            "age_range_0_3".localized,
            "age_range_4_6".localized,
            "age_range_7_9".localized,
            "age_range_10_12".localized,
            "age_range_13_plus".localized
        ]
    }
    
    var languages: [String] {
        LocalizationManager.Language.allCases.map { $0.displayName }
    }
    
    var voices: [(String, String)] {
        [
            ("voice_female_1".localized, "female-1"),
            ("voice_female_2".localized, "female-2"),
            ("voice_male_1".localized, "male-1"),
            ("voice_male_2".localized, "male-2")
        ]
    }
    
    @State private var showVoicePicker = false
    
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
                ScrollView {
                    VStack(spacing: 24) {
                        // Info Card
                        infoCard
                        
                        // Age Range Section
                        ageRangeSection
                        
                        // Language Section
                        languageSection
                        
                        // Voice Selection
                        voiceSection
                        
                        Spacer()
                            .frame(height: 120)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
                
                Spacer()
            }
            
            // Bottom Buttons
            VStack {
                Spacer()
                bottomButtons
            }
        }
        .sheet(isPresented: $showVoicePicker) {
            VoicePickerSheet(selectedVoice: $settings.voiceId)
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
            
            Spacer()
            
            Text("details_title".localized)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        VStack(spacing: 12) {
            Text("step_4_of_4".localized)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
            
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 8, height: 8)
                
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 8, height: 8)
                
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 8, height: 8)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - Info Card
    
    private var infoCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("almost_ready".localized)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Text("almost_ready_subtitle".localized)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .dwGlassCard()
    }
    
    // MARK: - Age Range Section
    
    private var ageRangeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("step3_age_range_title".localized)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text("step3_age_range_subtitle".localized)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                ForEach(ageRanges, id: \.self) { range in
                    AgeRangeButton(
                        title: range,
                        isSelected: settings.ageRange == range
                    ) {
                        settings.ageRange = range
                    }
                }
            }
        }
        .padding(20)
        .dwGlassCard()
    }
    
    // MARK: - Language Section
    
    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("step3_language_title".localized)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text("step3_language_subtitle".localized)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                ForEach(languages, id: \.self) { language in
                    LanguageButton(
                        title: language,
                        flag: languageFlag(language),
                        isSelected: settings.language == language
                    ) {
                        settings.language = language
                    }
                }
            }
        }
        .padding(20)
        .dwGlassCard()
    }
    
    // MARK: - Voice Section
    
    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("step3_voice_title".localized)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("optional".localized)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(6)
            }
            
            Text("step3_voice_subtitle".localized)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
            
            Button(action: {
                showVoicePicker = true
            }) {
                HStack {
                    Text(selectedVoiceName)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(16)
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
    }
    
    private var selectedVoiceName: String {
        voices.first { $0.1 == settings.voiceId }?.0 ?? "voice_female_1".localized
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
            
            Button(action: onGenerate) {
                HStack(spacing: 8) {
                    Text("generate_story".localized)
                        .font(.system(size: 18, weight: .bold))
                    
                    Text("🪄")
                        .font(.system(size: 18))
                }
                .foregroundColor(Color(red: 0.545, green: 0.361, blue: 0.965))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: Color.purple.opacity(0.3), radius: 20, x: 0, y: 10)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }
    
    // MARK: - Helper Methods
    
    private func languageFlag(_ language: String) -> String {
        switch language {
        case "Türkçe": return "🇹🇷"
        case "English": return "🇬🇧"
        case "Español": return "🇪🇸"
        case "Français": return "🇫🇷"
        case "Deutsch": return "🇩🇪"
        default: return "🌍"
        }
    }
}

// MARK: - Age Range Button

struct AgeRangeButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundColor(isSelected ? Color(red: 0.545, green: 0.361, blue: 0.965) : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    isSelected ? Color.white.opacity(0.9) : Color.white.opacity(0.2)
                )
                .cornerRadius(12)
        }
    }
}

// MARK: - Language Button

struct LanguageButton: View {
    let title: String
    let flag: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(flag)
                    .font(.system(size: 20))
                
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? Color(red: 0.545, green: 0.361, blue: 0.965) : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                isSelected ? Color.white.opacity(0.9) : Color.white.opacity(0.2)
            )
            .cornerRadius(12)
        }
    }
}

// MARK: - Voice Picker Sheet

struct VoicePickerSheet: View {
    @Binding var selectedVoice: String
    @Environment(\.dismiss) var dismiss
    
    let voices = [
        ("voice_female_1".localized, "female-1", "voice_female_1_desc".localized),
        ("voice_female_2".localized, "female-2", "voice_female_2_desc".localized),
        ("voice_male_1".localized, "male-1", "voice_male_1_desc".localized),
        ("voice_male_2".localized, "male-2", "voice_male_2_desc".localized)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient.dwBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(voices, id: \.1) { name, id, description in
                            Button(action: {
                                selectedVoice = id
                                dismiss()
                            }) {
                                HStack(spacing: 16) {
                                    // Voice Info
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(name)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.white)
                                        
                                        Text(description)
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    
                                    Spacer()
                                    
                                    // Selection indicator
                                    if selectedVoice == id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(Color(red: 0.545, green: 0.361, blue: 0.965))
                                    } else {
                                        Circle()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                            .frame(width: 24, height: 24)
                                    }
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedVoice == id ? Color.white.opacity(0.25) : Color.white.opacity(0.1))
                                )
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("step3_voice_selection".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Story Settings Model

struct StorySettings {
    var ageRange: String = "age_range_4_6".localized
    var language: String = "language_turkish".localized
    var voiceId: String = "female-1"
    
    // Deprecated - moved to Duration selection in Step 2.5
    @available(*, deprecated, message: "Use StoryDuration enum instead")
    var readingMinutes: Double = 5
    @available(*, deprecated, message: "Use StoryAddons instead")
    var generateCoverImage: Bool = true
    @available(*, deprecated, message: "Use StoryAddons instead")
    var generateAudio: Bool = true
    @available(*, deprecated, message: "Use StoryAddons instead")
    var generateIllustrations: Bool = false
}

// MARK: - Preview

#Preview {
    StoryCreationStep3View(
        settings: .constant(StorySettings()),
        onGenerate: {},
        onBack: {}
    )
}

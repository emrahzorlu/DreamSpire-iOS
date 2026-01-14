//
//  LanguagePickerView.swift
//  DreamSpire
//
//  Language selection sheet - Supports 5 languages
//

import SwiftUI

struct LanguagePickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedLanguage: String
    @ObservedObject private var localizationManager = LocalizationManager.shared

    let languages: [(code: String, name: String, flag: String)] = [
        ("tr", "Türkçe", "🇹🇷"),
        ("en", "English", "🇬🇧"),
        ("fr", "Français", "🇫🇷"),
        ("de", "Deutsch", "🇩🇪"),
        ("es", "Español", "🇪🇸")
    ]

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient.dwBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(languages, id: \.code) { language in
                            Button(action: {
                                selectedLanguage = language.code
                                // Update LocalizationManager
                                if let lang = LocalizationManager.Language(rawValue: language.code) {
                                    localizationManager.setLanguage(lang)
                                }
                                dismiss()
                            }) {
                                HStack(spacing: 16) {
                                    Text(language.flag)
                                        .font(.system(size: 32))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(language.name)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        Text(nativeLanguageName(for: language.code))
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.6))
                                    }

                                    Spacer()

                                    if selectedLanguage == language.code {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.title3)
                                    }
                                }
                                .padding()
                                .background(
                                    Color.white.opacity(selectedLanguage == language.code ? 0.25 : 0.15)
                                        .overlay(Color.white.opacity(0.05))
                                )
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("settings_language".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("close".localized) {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
    // Show native language name as subtitle
    private func nativeLanguageName(for code: String) -> String {
        switch code {
        case "tr": return "Turkish"
        case "en": return "İngilizce"
        case "fr": return "French"
        case "de": return "German"
        case "es": return "Spanish"
        default: return ""
        }
    }
}

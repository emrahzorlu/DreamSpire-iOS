//
//  StoryReaderView.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//
//  This view is now a lightweight container that decides whether to show
//  the Reading or Audio mode. The complex reading UI has been refactored
//  into ReadingModeView.swift.
//

import SwiftUI
import UIKit

struct StoryReaderView: View {
    @StateObject private var viewModel: StoryReaderViewModel
    @ObservedObject private var favoriteStore = FavoriteStore.shared
    @Environment(\.dismiss) var dismiss
    @State private var isAudioMode = false
    @State private var isTogglingFavorite = false
    @AppStorage("readingFontSize") private var fontSizeValue: Double = 16
    @State private var showFontSlider = false

    // Computed property for displaying accurate duration
    // Uses real audio duration when available, regardless of current mode
    private var displayMinutes: Int {
        // If audio exists and duration is measured, always use real duration
        if viewModel.story.audioUrl != nil, viewModel.duration > 0 {
            return Int(round(viewModel.duration / 60.0))
        }
        // Fallback to story metadata
        return viewModel.story.roundedMinutes
    }

    // The book-like background is defined here as it's part of the parent container.
    private let bookBackground = LinearGradient(
        colors: [
            Color(red: 0.953, green: 0.925, blue: 1.0),    // #F3ECFF - Light purple
            Color(red: 0.910, green: 0.871, blue: 1.0)      // #E8DEFF - Slightly deeper purple
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    private let pageBackground = Color.white // Pure white for readability
    
    init(story: Story) {
        _viewModel = StateObject(wrappedValue: StoryReaderViewModel(story: story))
    }
    
    var body: some View {
        ZStack {
            // Book background - DreamSpire gradient
            bookBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Navigation
                headerView
                
                // Mode Toggle (Reading/Listening) - only if audio exists
                if viewModel.story.audioUrl != nil {
                    ModeToggleView(isAudioMode: $isAudioMode)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                        .onChange(of: isAudioMode) { oldValue, newValue in
                            if !newValue {
                                // Switched to reading mode - pause audio
                                if viewModel.isPlaying {
                                    viewModel.toggleAudio()
                                }
                            }
                            // Note: Auto-play is now handled by AudioModeView.onAppear
                        }
                }
                
                // Content Area
                ZStack {
                    if isAudioMode && viewModel.story.audioUrl != nil {
                        // Audio Mode - show immediately even if pages are loading
                        AudioModeView(viewModel: viewModel)
                            .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                    } else {
                        // Reading Mode is now cleanly delegated to ReadingModeView
                        ReadingModeView(viewModel: viewModel, fontSize: fontSizeValue)
                            .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                    }
                }
                .frame(maxHeight: .infinity) // Ensure the content area fills available space
            }
        }
        .navigationBarHidden(true)
        .task {
            await favoriteStore.load()
        }
        .onAppear {
            DWLogger.shared.logViewAppear("StoryReaderView")
            // Always start with 16pt font
            fontSizeValue = 16
            
            // Welcoming haptic
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
        }
        .preferredColorScheme(.light)
        .overlay {
            // Tap-to-dismiss background when slider is shown
            if showFontSlider {
                Color.black.opacity(0.001) // Invisible but tappable
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            showFontSlider = false
                        }
                    }
                    .zIndex(998)
            }
        }
        .overlay(alignment: .topTrailing) {
            // Font Size Slider Popup - top level overlay
            if showFontSlider {
                fontSliderOverlay
                    .padding(.top, 60)
                    .padding(.trailing, 20)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9, anchor: .topTrailing).combined(with: .opacity),
                        removal: .scale(scale: 0.9, anchor: .topTrailing).combined(with: .opacity)
                    ))
                    .zIndex(999)
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: showFontSlider)
    }
    
    // MARK: - Font Slider Overlay (Top Level)
    
    private var fontSliderOverlay: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Text("A")
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundColor(.gray)
                
                Slider(value: $fontSizeValue, in: 14...24, step: 1)
                    .accentColor(Color(red: 0.545, green: 0.361, blue: 0.965))
                    .frame(width: 150)
                
                Text("A")
                    .font(.system(size: 20, weight: .medium, design: .serif))
                    .foregroundColor(.gray)
            }
            
            Text("\(Int(fontSizeValue)) pt")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(red: 0.545, green: 0.361, blue: 0.965))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
        )
        .onTapGesture { } // Prevent tap from dismissing
    }
    
    // MARK: - Favorites
    
    private func toggleFavorite() async {
        guard !isTogglingFavorite else { return }
        
        await MainActor.run {
            isTogglingFavorite = true
        }
        defer {
            Task { @MainActor in
                isTogglingFavorite = false
            }
        }
        
        await favoriteStore.toggle(viewModel.story.id)
        DWLogger.shared.logUserAction("Toggle Favorite - \(viewModel.story.title)")
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack(spacing: 16) {
            // Back Button
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(red: 0.545, green: 0.361, blue: 0.965))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(pageBackground)
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    )
            }
            
            // Title - Up to 3 lines support with better spacing
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.story.title)
                    .font(.custom("Georgia", size: 15))
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 0.298, green: 0.235, blue: 0.361))
                    .lineLimit(3)
                    .lineSpacing(3)
                    .minimumScaleFactor(0.9)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Metadata with proper formatting
                HStack(spacing: 4) {
                    if let metadata = viewModel.story.metadata, let ageRange = metadata.ageRange {
                        Text(localizedAgeRange(ageRange))
                            .font(.custom("Georgia", size: 12))
                            .foregroundColor(Color(red: 0.545, green: 0.361, blue: 0.965).opacity(0.7))
                    }
                    
                    if viewModel.story.metadata?.ageRange != nil { Text("•").foregroundColor(.gray) }
                    
                    if let metadata = viewModel.story.metadata, let tone = metadata.tone {
                        Text(localizedTone(tone))
                            .font(.custom("Georgia", size: 12))
                            .foregroundColor(Color(red: 0.545, green: 0.361, blue: 0.965).opacity(0.7))
                    }
                    
                    if viewModel.story.metadata?.tone != nil { Text("•").foregroundColor(.gray) }

                    Text("\(displayMinutes) \("reader_minutes_suffix_short".localized)")
                        .font(.custom("Georgia", size: 12))
                        .foregroundColor(Color(red: 0.545, green: 0.361, blue: 0.965).opacity(0.7))
                }
            }
            
            Spacer()
            
            // Font Size Button (Aa) - only in reading mode
            if !isAudioMode {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showFontSlider.toggle()
                    }
                }) {
                    Text("Aa")
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundColor(Color(red: 0.545, green: 0.361, blue: 0.965))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(pageBackground)
                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        )
                }
            }
            
            // Favorite Button
            Button(action: {
                Task { await toggleFavorite() }
            }) {
                Image(systemName: favoriteStore.isFavorite(viewModel.story.id) ? "heart.fill" : "heart")
                    .font(.system(size: 20))
                    .foregroundColor(favoriteStore.isFavorite(viewModel.story.id) ? Color(red: 0.902, green: 0.475, blue: 0.976) : Color(red: 0.545, green: 0.361, blue: 0.965))
                    .symbolEffect(.bounce, value: favoriteStore.isFavorite(viewModel.story.id))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(pageBackground)
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    )
            }
            .disabled(isTogglingFavorite)
            .opacity(isTogglingFavorite ? 0.5 : 1.0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Color(red: 0.976, green: 0.965, blue: 0.988) // Soft purple background
        )
    }
    
    // MARK: - Localized Helpers
    
    private func localizedAgeRange(_ ageRange: String) -> String {
        switch ageRange.lowercased() {
        case "toddler": return "age_range_0_3".localized
        case "preschool": return "age_range_4_6".localized
        case "young": return "age_range_7_9".localized
        case "middle", "older": return "age_range_10_12".localized
        case "teen": return "age_range_13_plus".localized
        default: return ageRange.capitalized
        }
    }
    
    private func localizedTone(_ tone: String) -> String {
        switch tone.lowercased() {
        case "calm", "soothing": return "tone_calm_title".localized
        case "funny": return "tone_funny_title".localized
        case "adventurous", "magical": return "tone_adventure_title".localized
        case "educational": return "tone_educational_title".localized
        default: return tone.capitalized
        }
    }
}

// All the previous reader-specific code (readingModeView, bottomNavigationView,
// BookPageView, PageCurlReaderView, etc.) has been removed from this file
// and now lives in ReadingModeView.swift.

// MARK: - Preview

#Preview {
    StoryReaderView(story: Story.mockStory)
}
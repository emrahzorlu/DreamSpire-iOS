//
//  StoryCreationFlowView.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//  Updated for Coin System on 11/7/24
//  Updated: Reordered steps - Step 3: Details, Step 4: Duration
//

import SwiftUI
import UserNotifications

// MARK: - Voice Option Model
struct VoiceOption: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
}

struct StoryCreationFlowView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var coinService = CoinService.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    @StateObject private var libraryViewModel = LibraryViewModel.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    
    var presentedFromTab: Bool = false // Tab'dan mı yoksa başka bir yerden mi açıldı?
    
    @State private var currentStep: CreationStep = .step1
    
    // Step 1 Data
    @State private var storyIdea: String = ""
    @State private var selectedGenre: String = "genre_adventure".localized
    @State private var selectedTone: String = "tone_excited".localized
    
    // Step 2 Data
    @State private var characters: [StoryCharacter] = [StoryCharacter()]
    
    // Step 3 Data (Detaylar: Yaş, Dil, Ses)
    @State private var selectedVoice: String = "shimmer" // Varsayılan
    @State private var settings: StorySettings = StorySettings()
    
    // Step 4 Data (Duration & Addons)
    @State private var selectedDuration: StoryDuration = .standard
    @State private var addons = StoryAddons(cover: true, audio: true)
    
    // Coin related
    @State private var calculatedCost: Int = 0
    @State private var showCoinShop = false
    @State private var showPaywall = false
    
    // Generation
    @State private var isGenerating = false
    @State private var generationProgress: Double = 0.0
    @State private var generationStage: String = ""
    @State private var generatedStory: Story?
    @State private var generationError: String?
    @State private var contentSafetyError: ContentSafetyError?
    @State private var showContentSafetySheet = false
    @State private var rotationAngle: Double = 0
    @State private var shouldSendNotification = false
    @State private var hasNotificationPermission = false

    // Check if user has active jobs
    @StateObject private var jobManager = GenerationJobManager.shared
    
    // Fullscreen covers for generating and result
    @State private var showGeneratingCover = false
    @State private var showResultCover = false

    // Track if we need to reset form when returning to this view
    @State private var shouldResetOnAppear = false

    enum CreationStep {
        case step1, step2, step3, step4, generating, result
    }
    
    var body: some View {
        ZStack {
            Group {
                switch currentStep {
                case .step1:
                    StoryCreationStep1View(
                        storyIdea: $storyIdea,
                        selectedGenre: $selectedGenre,
                        selectedTone: $selectedTone,
                        showCoinBalance: true,
                        showDismissButton: !presentedFromTab,
                        presentedFromTab: presentedFromTab,
                        onNext: {
                            withAnimation {
                                currentStep = .step2
                            }
                        }
                    )
                
                case .step2:
                    StoryCreationStep2View(
                        characters: $characters,
                        showCoinBalance: true,
                        presentedFromTab: presentedFromTab,
                        onNext: {
                            withAnimation {
                                currentStep = .step3
                            }
                        },
                        onBack: {
                            withAnimation {
                                currentStep = .step1
                            }
                        }
                    )
                
                case .step3:
                    detailsStep
                
                case .step4:
                    durationAndAddonsStep
                
                case .generating, .result:
                    // Show empty view, content is in fullScreenCover
                    Color.clear
                }
            }
        }
        .fullScreenCover(isPresented: $showGeneratingCover) {
            OwlGeneratingView(
                progress: $generationProgress,
                stage: $generationStage,
                storySnippet: Binding.constant(storyIdea.isEmpty ? "generating_story".localized : storyIdea),
                onDismiss: {
                    showGeneratingCover = false
                    currentStep = .step1
                    
                    // Navigate to library tab to show generating card
                    NotificationCenter.default.post(name: .navigateToLibraryMyStories, object: nil)
                    
                    if !presentedFromTab {
                        dismiss()
                    }
                },
                onRequestNotification: {
                    shouldSendNotification = true
                    requestNotificationPermission()
                    showGeneratingCover = false
                    currentStep = .step1
                    shouldResetOnAppear = true

                    // Navigate to library tab to show generating card
                    NotificationCenter.default.post(name: .navigateToLibraryMyStories, object: nil)
                    
                    if !presentedFromTab {
                        dismiss()
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showResultCover) {
            if let story = generatedStory {
                StoryResultView(story: story) {
                    // Dismiss result cover and mark for reset on next appear
                    showResultCover = false
                    currentStep = .step1
                    shouldResetOnAppear = true

                    // If not presented from tab, also dismiss the entire flow
                    if !presentedFromTab {
                        dismiss()
                    }
                }
            }
        }

        .fullScreenCover(isPresented: $showCoinShop) {
            CoinShopView()
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView()
        }

        .sheet(isPresented: $showContentSafetySheet) {
            if let error = contentSafetyError {
                ContentSafetyErrorView(
                    error: error,
                    onTryExample: { example in
                        storyIdea = example
                        showContentSafetySheet = false
                        // Go back to Step 1 to edit
                        withAnimation {
                            currentStep = .step1
                        }
                    },
                    onDismiss: {
                        showContentSafetySheet = false
                        contentSafetyError = nil
                    }
                )
            }
        }
        .onChange(of: generationError) { _, newError in
            if let error = newError {
                GlassDialogManager.shared.alert(
                    title: "Hata",
                    message: error,
                    buttonTitle: "Tamam",
                    action: {
                        generationError = nil
                        currentStep = .step4
                    }
                )
            }
        }
        .withGlassDialogs()
        .onAppear {
            // Reset form if a story was just generated and user is coming back
            if shouldResetOnAppear {
                resetForm()
                shouldResetOnAppear = false
            }

            // Set initial language from app settings
            settings.language = localizationManager.currentLanguage.displayName

            Task {
                try? await coinService.fetchBalance()
            }
        }
        .onChange(of: localizationManager.currentLanguage) { _, newValue in
            // Update default language in settings when app language changes
            settings.language = newValue.displayName
            
            // Reset genre/tone to current localized defaults
            selectedGenre = "genre_adventure".localized
            selectedTone = "tone_excited".localized
        }
        .preferredColorScheme(.light)
    }
    
    // MARK: - Step 3: Details (Yaş, Dil, Ses)

    private var detailsStep: some View {
        ZStack {
            LinearGradient.dwBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Bar with Coin Balance
                ZStack {
                    HStack {
                        Button(action: {
                            withAnimation {
                                currentStep = .step2
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                        }

                        Spacer()
                    }

                    Text("details_title".localized)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    HStack {
                        Spacer()

                        CompactCoinBalanceView()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Progress
                VStack(spacing: 8) {
                    Text("step_3_of_4".localized)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))

                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)

                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)

                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)

                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 12)

                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Age Range
                        ageRangeSection

                        // Language
                        languageSection

                        // Voice Selection (Compact)
                        voiceSelectionSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, presentedFromTab ? 180 : 120)
                }

                Spacer()
            }
            
            // Bottom Buttons
            VStack {
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: {
                        withAnimation {
                            currentStep = .step2
                        }
                    }) {
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
                    
                    Button(action: {
                        withAnimation {
                            currentStep = .step4
                        }
                    }) {
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
                }
                .padding(.horizontal, 16)
                .padding(.bottom, presentedFromTab ? 100 : 24)
            }
        }
    }
    
    // MARK: - Age Range Section
    
    private var ageRangeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("details_age_range".localized)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text("details_age_range_subtitle".localized)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                let ageRangeOptions = [
                    ("0-3", "age_range_0_3".localized),
                    ("4-6", "age_range_4_6".localized),
                    ("7-9", "age_range_7_9".localized),
                    ("10-12", "age_range_10_12".localized),
                    ("13+", "age_range_13_plus".localized)
                ]
                ForEach(ageRangeOptions, id: \.0) { value, localizedTitle in
                    AgeRangeButton(
                        title: localizedTitle,
                        isSelected: settings.ageRange == value
                    ) {
                        settings.ageRange = value
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
            Text("details_language".localized)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Text("details_language_subtitle".localized)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                // Use displayName for consistency with Step 3
                ForEach(LocalizationManager.Language.allCases, id: \.rawValue) { lang in
                    LanguageButton(
                        title: lang.displayName,
                        flag: lang.flag,
                        isSelected: settings.language == lang.displayName
                    ) {
                        settings.language = lang.displayName
                    }
                }
            }
        }
        .padding(20)
        .dwGlassCard()
    }
    
    // MARK: - Voice Selection Section (Compact)
    
    private var voiceSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("details_voice".localized)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("voice_optional".localized)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(6)
            }
            
            Text("details_voice_subtitle".localized)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
            
            // Voice Cards Grid (Compact - same size as language)
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                ForEach(availableVoices, id: \.id) { voice in
                    CompactVoiceCard(
                        voice: voice,
                        isSelected: selectedVoice == voice.id
                    ) {
                        selectedVoice = voice.id
                    }
                }
            }
        }
        .padding(20)
        .dwGlassCard()
    }
    
    private var availableVoices: [VoiceOption] {
        [
            VoiceOption(id: "nova", name: "voice_nova".localized, description: "voice_nova_desc".localized, icon: "✨"),
            VoiceOption(id: "shimmer", name: "voice_shimmer".localized, description: "voice_shimmer_desc".localized, icon: "🎭"),
            VoiceOption(id: "fable", name: "voice_fable".localized, description: "voice_fable_desc".localized, icon: "📖"),
            VoiceOption(id: "alloy", name: "voice_alloy".localized, description: "voice_alloy_desc".localized, icon: "🎪"),
            VoiceOption(id: "echo", name: "voice_echo".localized, description: "voice_echo_desc".localized, icon: "🎨"),
            VoiceOption(id: "onyx", name: "voice_onyx".localized, description: "voice_onyx_desc".localized, icon: "🔊")
        ]
    }
    
    // MARK: - Step 4: Duration & Addons

    private var durationAndAddonsStep: some View {
        ZStack {
            LinearGradient.dwBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Bar with Coin Balance
                ZStack {
                    HStack {
                        Button(action: {
                            withAnimation {
                                currentStep = .step3
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                        }

                        Spacer()
                    }

                    Text("step_4_title".localized)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    HStack {
                        Spacer()

                        CompactCoinBalanceView()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Progress
                VStack(spacing: 8) {
                    Text("step_4_of_4".localized)
                        .font(.system(size: 13))
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
                .padding(.top, 8)
                .padding(.bottom, 12)

                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        StoryDurationPickerView(
                            selectedDuration: $selectedDuration,
                            addons: $addons
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, presentedFromTab ? 180 : 120)
                }

                Spacer()
            }
            
            // Bottom Buttons
            VStack {
                Spacer()

                if jobManager.hasActiveJobs {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("story_creation_already_in_progress".localized)
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.orange.opacity(0.3))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
                
                // Removed the previous "duration_insufficient_balance" text as user requested orange button instead

                HStack(spacing: 12) {
                    Button(action: {
                        withAnimation {
                            currentStep = .step3
                        }
                    }) {
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

                VStack(spacing: 12) {
                    Button(action: {
                        handleGenerationTap()
                    }) {
                        let currentCost = coinService.calculateCostLocal(duration: selectedDuration, addons: addons)
                        let isInsufficient = (coinService.coinBalance?.balance ?? 0) < currentCost
                        
                        HStack(spacing: 8) {
                            Text(jobManager.hasActiveJobs ? "template_generating".localized : (isInsufficient ? "insufficient_balance_button".localized : "generate_story".localized))
                                .font(.system(size: 18, weight: .bold))
                            
                            if !jobManager.hasActiveJobs {
                                Text(isInsufficient ? "❗️" : "🪄")
                                    .font(.system(size: 18))
                            }
                        }
                        .foregroundColor(jobManager.hasActiveJobs ? .white.opacity(0.8) : (isInsufficient ? .white : Color(red: 0.545, green: 0.361, blue: 0.965)))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            jobManager.hasActiveJobs 
                                ? Color.white.opacity(0.4) 
                                : (isInsufficient ? Color.orange : Color.white)
                        )
                        .cornerRadius(12)
                        .shadow(color: jobManager.hasActiveJobs ? Color.clear : (isInsufficient ? Color.orange.opacity(0.3) : Color.purple.opacity(0.3)), radius: 20, x: 0, y: 10)
                    }
                    .disabled(jobManager.hasActiveJobs)
                }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, presentedFromTab ? 100 : 24) // Extra space for floating TabBar when in tab
            }
        }
    }
    
    // MARK: - Generating View
    
    private var generatingView: some View {
        ZStack {
            LinearGradient.dwBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with close option
                HStack {
                    Spacer()
                    
                    Button(action: {
                        shouldSendNotification = true
                        requestNotificationPermission()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
                
                // Main content centered
                VStack(spacing: 32) {
                    // Animated magic wand with Lottie-like effect
                    ZStack {
                        // Pulsing background circles
                        ForEach(0..<3) { index in
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.2),
                                            Color.purple.opacity(0.3)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                                .frame(width: 100 + CGFloat(index * 30))
                                .scaleEffect(1.0 + sin(Date().timeIntervalSince1970 * 2 + Double(index)) * 0.1)
                                .opacity(0.6 - Double(index) * 0.15)
                        }
                        
                        // Central magic wand
                        Text("🪄")
                            .font(.system(size: 60))
                            .rotationEffect(.degrees(rotationAngle * 0.1))
                    }
                    .frame(height: 180)
                    
                    // Message & Progress
                    VStack(spacing: 16) {
                        Text("generating_title".localized)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(generationStage.isEmpty ? "create_characters_coming".localized : generationStage)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .animation(.easeInOut(duration: 0.3), value: generationStage)
                        
                        // Smooth animated progress bar
                        VStack(spacing: 10) {
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    // Background
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white.opacity(0.2))
                                        .frame(height: 8)
                                    
                                    // Progress
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.white, Color.white.opacity(0.8)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geometry.size.width * generationProgress, height: 8)
                                        .animation(.easeInOut(duration: 0.5), value: generationProgress)
                                }
                            }
                            .frame(width: 250, height: 8)
                            
                            Text("\(Int(generationProgress * 100))%")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
                
                Spacer()
                
                // Notification option - cleaner design
                VStack(spacing: 12) {
                    if hasNotificationPermission {
                        // Already has permission - show info and continue button
                        HStack(spacing: 10) {
                            Image(systemName: "bell.badge.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.green)

                            Text("notification_will_send".localized)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)

                        Button(action: {
                            shouldSendNotification = true
                            // Dismiss to show library with generating card
                            if presentedFromTab {
                                // Can't navigate, just dismiss
                                showGeneratingCover = false
                            } else {
                                dismiss()
                            }
                        }) {
                            Text("continue_in_background".localized)
                                .font(.system(size: 15, weight: .semibold))
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
                    } else {
                        // Need permission
                        Text("notification_ask_permission".localized)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            GlassDialogManager.shared.confirm(
                                title: "notification_permission_title".localized,
                                message: "notification_permission_message".localized,
                                confirmTitle: "permission_allow".localized,
                                confirmAction: {
                                    shouldSendNotification = true
                                    requestNotificationPermission()
                                }
                            )
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 14))
                                Text("permission_allow".localized)
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [Color.orange, Color.pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            startRotationAnimation()
            startSmoothProgressSimulation()
            checkNotificationPermission()
        }
    }
    
    // MARK: - Helper Functions
    
    private func startRotationAnimation() {
        withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
    }
    
    private func startSmoothProgressSimulation() {
        // Smooth continuous progress animation
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            guard isGenerating else {
                timer.invalidate()
                return
            }
            
            // Smooth increment
            if generationProgress < 0.9 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    generationProgress += 0.005
                }
            }
        }
    }
    
    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                hasNotificationPermission = settings.authorizationStatus == .authorized
                
                // If already has permission, enable notifications automatically
                if hasNotificationPermission {
                    shouldSendNotification = true
                }
            }
        }
    }
    
    private func requestNotificationPermission() {
        Task {
            let granted = await NotificationManager.shared.requestPermission()
            if granted {
                DWLogger.shared.info("Notification permission granted - will notify when story is ready", category: .app)
            } else {
                DWLogger.shared.warning("Notification permission denied", category: .app)
            }
        }
    }
    
    private func sendStoryReadyNotification() {
        guard let story = generatedStory else { return }
        
        Task {
            await NotificationManager.shared.sendStoryReadyNotification(
                storyTitle: story.title,
                storyId: story.id
            )
        }
    }
    
    private func cancelStoryGeneration() {
        // Cancel the ongoing story generation
        isGenerating = false
        generationProgress = 0.0
        generationStage = ""
        
        // Cancel any scheduled notifications
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["story-ready"])
        
        DWLogger.shared.info("Story generation cancelled by user", category: .story)
    }
    
    // MARK: - Check Coins & Generate
    
    private func handleGenerationTap() {
        // Calculate cost correctly
        calculatedCost = coinService.calculateCostLocal(
            duration: selectedDuration,
            addons: addons
        )
        
        guard let balance = coinService.coinBalance else {
            generationError = "Bakiye bilgisi alınamadı"
            return
        }
        
        if balance.balance < calculatedCost {
            // Insufficient coins - Redirect based on tier
            let tier = subscriptionService.currentTier
            DWLogger.shared.info("🪙 Insufficient coins for story creation. Redirecting tier \(tier.rawValue)", category: .story)
            
            if tier == .free {
                showPaywall = true
            } else {
                showCoinShop = true
            }
            return
        }
        
        // Has enough coins - Generate
        generateStory()
    }
    
    // Removed checkCoinsAndGenerate in favor of handleGenerationTap
    
    private func generateStory() {
        isGenerating = true
        currentStep = .generating
        showGeneratingCover = true
        generationProgress = 0.0
        generationError = nil

        // Simulate progress
        startProgressSimulation()

        // Pre-register a temporary job immediately so it shows in library even if user dismisses early
        let tempJobId = UUID().uuidString
        let userId = AuthManager.shared.currentUserId ?? "guest"
        let storyTitle = storyIdea.isEmpty ? "Yeni Hikaye" : String(storyIdea.prefix(50))

        // Register job SYNCHRONOUSLY on main thread (without polling - it's just a temporary placeholder)
        GenerationJobManager.shared.startJob(
            jobId: tempJobId,
            storyTitle: storyTitle,
            userId: userId,
            shouldNotify: shouldSendNotification,
            startPolling: false  // Don't poll temporary job - backend doesn't know about it yet
        )

        Task {

            do {
                let validCharacters = characters.filter { !$0.name.isEmpty }

                // Map age range
                let ageRange = mapAgeRange(settings.ageRange)

                // Map language from selection to API code
                // settings.language contains the displayName (e.g., "Türkçe", "English")
                let selectedLangString = settings.language

                // DEBUG: Log the selected language before conversion
                print("🔍 [LANGUAGE DEBUG] Selected language string: '\(selectedLangString)'")

                // Find matching language by displayName (independent of app UI language)
                let language: String
                if let matchedLang = LocalizationManager.Language.allCases.first(where: { $0.displayName == selectedLangString }) {
                    language = matchedLang.apiLanguage
                    print("✅ [LANGUAGE DEBUG] Matched to: \(matchedLang.rawValue) → API code: '\(language)'")
                } else {
                    // Fallback: use current app language (should rarely happen)
                    language = localizationManager.currentLanguage.apiLanguage
                    print("⚠️ [LANGUAGE DEBUG] No match found! Falling back to app language: '\(language)'")
                }

                // Prepare character requests for API (using StoryCharacter init)
                let characterRequests = validCharacters.map { CharacterRequest(from: $0) }

                // Use selected voice
                settings.voiceId = selectedVoice

                // Map genre and tone to backend-expected values (lowercase)
                let genre = mapGenre(selectedGenre)
                let tone = mapTone(selectedTone)

                // Map voice to OpenAI voice names
                let voice = mapVoice(selectedVoice)

                print("🔍 [PROMPT DEBUG] storyIdea: '\(storyIdea)' (isEmpty: \(storyIdea.isEmpty))")
                print("🔍 [GENRE DEBUG] Selected: '\(selectedGenre)' → Mapped: '\(genre)'")
                print("🔍 [TONE DEBUG] Selected: '\(selectedTone)' → Mapped: '\(tone)'")
                print("🔍 [VOICE DEBUG] Selected: '\(selectedVoice)' → Mapped: '\(voice)'")

                // API Request
                let request = CreateStoryWithCoinsRequest(
                    duration: selectedDuration.rawValue,
                    addons: AddonsRequest(
                        cover: addons.cover,
                        audio: addons.audio,
                        illustrated: addons.illustrated
                    ),
                    prompt: storyIdea,
                    genre: genre,
                    tone: tone,
                    ageRange: ageRange,
                    language: language,
                    voice: voice,
                    characters: characterRequests
                )

                // Check if user is authenticated
                let isGuest = AuthManager.shared.currentUser == nil

                // Generate idempotency key for duplicate prevention
                let idempotencyKey = UUID().uuidString

                let response: StoryCreationResponse = try await APIClient.shared.makeRequest(
                    endpoint: "/api/stories/create",
                    method: .post,
                    body: request,
                    requiresAuth: !isGuest,  // Don't require auth for guests
                    includeDeviceId: isGuest,  // Include deviceId for guests
                    idempotencyKey: idempotencyKey  // Prevent duplicate requests
                )

                // Handle async vs sync response
                let story: Story
                if response.isAsync {
                    // Async response - poll for job completion
                    guard let jobId = response.jobId else {
                        DWLogger.shared.error("Async response missing jobId", category: .story)
                        throw APIError.decodingError
                    }

                    DWLogger.shared.info("Story generation is async, job ID: \(jobId)", category: .story)

                    // Cancel temporary job and register real job
                    await GenerationJobManager.shared.cancelJob(jobId: tempJobId)

                    await GenerationJobManager.shared.startJob(
                        jobId: jobId,
                        storyTitle: storyTitle,
                        userId: userId,
                        originalRequest: request,
                        shouldNotify: shouldSendNotification
                    )
                    
                    // ALWAYS add to library view so user sees generating card
                    await MainActor.run {
                        libraryViewModel.addGeneratingStory(storyId: jobId, title: storyTitle)
                    }

                    // If user wants background notification, dismiss and let them see the job card in library
                    if shouldSendNotification {
                        await MainActor.run {
                            isGenerating = false
                            showGeneratingCover = false

                            DWLogger.shared.info("Story generating in background, navigating to library", category: .story)

                            // Navigate to library tab to show the generating card
                            if presentedFromTab {
                                // We're in a tab, post notification to switch to library tab
                                NotificationCenter.default.post(name: .navigateToLibrary, object: nil)
                            } else {
                                // We're in a fullscreen cover, dismiss to go back
                                dismiss()
                            }
                        }

                        // Don't wait for completion, let it run in background
                        return
                    }

                    // Otherwise, poll synchronously and wait for completion
                    story = try await StoryService.shared.pollJobStatus(jobId: jobId) { progress, status in
                        await MainActor.run {
                            self.generationProgress = progress
                            self.generationStage = status
                        }
                    }
                } else {
                    // Sync response - story is ready (but might still need processing)
                    // Cancel temporary job
                    await GenerationJobManager.shared.cancelJob(jobId: tempJobId)

                    // Check if we got a jobId for tracking
                    if let jobId = response.jobId {
                        // Register real job even for sync responses in case they need tracking
                        await GenerationJobManager.shared.startJob(
                            jobId: jobId,
                            storyTitle: storyTitle,
                            userId: userId,
                            originalRequest: request,
                            shouldNotify: shouldSendNotification
                        )

                        // Poll for completion
                        story = try await StoryService.shared.pollJobStatus(jobId: jobId) { progress, status in
                            await MainActor.run {
                                self.generationProgress = progress
                                self.generationStage = status
                            }
                        }
                    } else {
                        // True sync - story is immediately ready
                        guard let syncStory = response.story else {
                            DWLogger.shared.error("Sync response missing story", category: .story)
                            throw APIError.decodingError
                        }
                        story = syncStory
                    }
                }
                
                await MainActor.run {
                    generationProgress = 1.0
                    generatedStory = story
                    isGenerating = false
                    generationError = nil // Clear any previous errors
                    
                    // Close generating cover and show result cover
                    showGeneratingCover = false
                    currentStep = .result
                    
                    // Small delay to ensure generating cover is dismissed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showResultCover = true
                    }
                    
                    // Send notification if user requested it
                    if shouldSendNotification {
                        sendStoryReadyNotification()
                    }
                    
                    // Refresh coin balance
                    Task {
                        try? await coinService.fetchBalance()
                    }
                    
                    // Push to repository cache immediately (Incremental Update!)
                    UserStoryRepository.shared.addStory(story)
                }
                
                DWLogger.shared.info("✅ Story created successfully with coins", category: .story)
                DWLogger.shared.info("💰 Coins spent: \(response.coinTransaction.spent), New balance: \(response.coinTransaction.newBalance)", category: .story)
                
            } catch {
                // Cancel temporary job on error
                await GenerationJobManager.shared.cancelJob(jobId: tempJobId)

                await MainActor.run {
                    // Check for content safety error
                    if let safetyError = error.contentSafetyError {
                        contentSafetyError = safetyError
                        showContentSafetySheet = true
                        DWLogger.shared.warning("Content safety violation: \(safetyError.title)", category: .story)
                    } else if error.isInsufficientCoins {
                        // Backend returned 402 - show insufficient coins modal
                        DWLogger.shared.warning("Insufficient coins from backend (402)", category: .coin)
                        isGenerating = false
                        showGeneratingCover = false
                        currentStep = .step4
                        if subscriptionService.currentTier == .free {
                            showPaywall = true
                        } else {
                            showCoinShop = true
                        }
                    } else if let apiError = error as? APIError, case .jobInProgress(let jobId) = apiError {
                        // User already has a job in progress - show them the library
                        generationError = "story_creation_already_in_progress_detail".localized
                        DWLogger.shared.warning("Job already in progress: \(jobId)", category: .story)

                        // Navigate to library to show the in-progress job
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            if presentedFromTab {
                                NotificationCenter.default.post(name: .navigateToLibrary, object: nil)
                            } else {
                                dismiss()
                            }
                        }
                    } else if isTimeoutError(error) {
                        // Network/polling timeout - story continues in background
                        DWLogger.shared.info("⏰ Story generation timeout - continuing in background", category: .story)
                        
                        // Simply close the generating cover, DON'T navigate anywhere
                        // User might be doing something else in the app
                        // We're already in MainActor.run, so no need for nested await
                        isGenerating = false
                        showGeneratingCover = false
                        
                        // NOTE: We do NOT cancel the GenerationJobManager job
                        // It will continue polling and the story will appear in Library when complete
                    } else {
                        generationError = "Hikaye oluşturulamadı: \(error.localizedDescription)"
                        DWLogger.shared.error("Failed to create story", error: error, category: .story)
                        
                        isGenerating = false
                        showGeneratingCover = false
                        currentStep = .step4
                    }
                }
            }
        }
    }
    
    private func startProgressSimulation() {
        var stages: [String] = [
            "generating_stage_structure".localized,
            "generating_stage_characters".localized,
            "generating_stage_writing".localized
        ]

        if addons.cover {
            stages.append("generating_stage_cover".localized)
        }

        if addons.audio {
            stages.append("generating_stage_audio".localized)
        }

        if addons.illustrated {
            stages.append("generating_stage_illustrations".localized)
        }

        stages.append("generating_stage_finalizing".localized)
        
        Task {
            for (index, stage) in stages.enumerated() {
                guard isGenerating else { break }
                
                await MainActor.run {
                    generationStage = stage
                    generationProgress = Double(index + 1) / Double(stages.count + 1) * 0.9
                }
                
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func mapAgeRange(_ range: String) -> String {
        // Handle both localized and raw age range strings
        let lowered = range.lowercased()
        if lowered.contains("0-3") || lowered.contains("toddler") { return "toddler" }
        if lowered.contains("4-6") || lowered.contains("preschool") { return "preschool" }
        if lowered.contains("7-9") || lowered.contains("young") { return "young" }
        if lowered.contains("10-12") || lowered.contains("middle") { return "middle" }
        if lowered.contains("13") || lowered.contains("teen") { return "teen" }
        return "young" // default
    }

    private func mapGenre(_ genre: String) -> String {
        // Map localized genre strings to backend API values (lowercase)
        let lowered = genre.lowercased()

        // Match against localization keys and display values
        if lowered.contains("bedtime") || lowered.contains("uyku") { return "bedtime" }
        if lowered.contains("adventure") || lowered.contains("macera") { return "adventure" }
        if lowered.contains("family") || lowered.contains("aile") { return "family" }
        if lowered.contains("friendship") || lowered.contains("arkadaşlık") || lowered.contains("arkadas") { return "friendship" }
        if lowered.contains("fantasy") || lowered.contains("fantastik") || lowered.contains("hayal") { return "fantasy" }
        if lowered.contains("animal") || lowered.contains("hayvan") { return "animals" }
        if lowered.contains("princess") || lowered.contains("prenses") { return "princess" }
        if lowered.contains("classic") || lowered.contains("klasik") { return "classic" }
        if lowered.contains("mystery") || lowered.contains("gizem") { return "mystery" }
        if lowered.contains("science") || lowered.contains("bilim") { return "science" }
        if lowered.contains("educational") || lowered.contains("eğitici") || lowered.contains("egitici") { return "educational" }

        return "adventure" // default fallback
    }

    private func mapTone(_ tone: String) -> String {
        // Map localized tone strings to backend API values (lowercase)
        let lowered = tone.lowercased()

        // Match against localization keys and display values
        if lowered.contains("calm") || lowered.contains("sakin") { return "calm" }
        if lowered.contains("excit") || lowered.contains("heyecan") { return "exciting" }  // matches "exciting" and "excited"
        if lowered.contains("funny") || lowered.contains("komik") || lowered.contains("eğlen") { return "funny" }
        if lowered.contains("cheerful") || lowered.contains("neşe") || lowered.contains("nese") { return "cheerful" }
        if lowered.contains("mysterious") || lowered.contains("gizem") { return "mysterious" }
        if lowered.contains("heartwarming") || lowered.contains("duygusal") || lowered.contains("sıcak") { return "heartwarming" }
        if lowered.contains("adventurous") || lowered.contains("macera") { return "adventurous" }
        if lowered.contains("relaxing") || lowered.contains("rahatla") { return "relaxing" }
        if lowered.contains("romantic") || lowered.contains("romantik") { return "romantic" }

        return "calm" // default fallback
    }

    private func mapVoice(_ voice: String) -> String {
        // Map custom voice IDs to OpenAI TTS voice names
        // iOS uses: female-1, female-2, male-1, male-2
        // OpenAI uses: alloy, echo, fable, onyx, nova, shimmer

        switch voice {
        case "female-1": return "shimmer"  // Young, warm female voice
        case "female-2": return "nova"     // Energetic female voice
        case "male-1": return "echo"       // Calm male voice
        case "male-2": return "onyx"       // Deep male voice
        default:
            // If already an OpenAI voice name, return as-is
            let validVoices = ["alloy", "echo", "fable", "onyx", "nova", "shimmer"]
            if validVoices.contains(voice.lowercased()) {
                return voice.lowercased()
            }
            return "shimmer" // default fallback
        }
    }
    
    private func resetForm() {
        // Reset all form fields to initial state
        storyIdea = ""
        selectedGenre = "genre_adventure".localized
        selectedTone = "tone_excited".localized
        characters = [StoryCharacter()]
        selectedVoice = "shimmer"
        settings = StorySettings()
        settings.language = LocalizationManager.shared.currentLanguage.displayName
        selectedDuration = .standard
        addons = StoryAddons(cover: true, audio: true)
        generatedStory = nil
        generationProgress = 0.0
        generationStage = ""
    }
    
    /// Detect if error is a timeout (network, polling, or URLSession)
    private func isTimeoutError(_ error: Error) -> Bool {
        // Check for URLSession timeout
        if let urlError = error as? URLError {
            return urlError.code == .timedOut || urlError.code == .networkConnectionLost
        }
        
        // Check for StoryServiceError polling timeout
        if let storyError = error as? StoryServiceError {
            switch storyError {
            case .pollingTimeout:
                return true
            default:
                return false
            }
        }
        
        // Check error description for timeout keywords
        let description = error.localizedDescription.lowercased()
        return description.contains("timeout") || 
               description.contains("timed out") ||
               description.contains("connection lost")
    }
}

// MARK: - Compact Voice Card Component

struct CompactVoiceCard: View {
    let voice: VoiceOption
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(voice.icon)
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(voice.name)
                        .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(.white)
                    
                    Text(voice.description)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.white.opacity(0.25) : Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? Color(red: 0.545, green: 0.361, blue: 0.965) : Color.white.opacity(0.2),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
    }
}

// MARK: - Compact Coin Balance View

struct CompactCoinBalanceView: View {
    @StateObject private var coinService = CoinService.shared
    @StateObject private var subscriptionService = SubscriptionService.shared // Added SubscriptionService
    @State private var showPaywall = false
    @State private var showCoinShop = false // Added CoinShop state
    
    var body: some View {
        Button(action: {
            // Intelligent redirection based on tier
            if subscriptionService.currentTier == .free {
                showPaywall = true
            } else {
                showCoinShop = true
            }
        }) {
            HStack(spacing: 6) {
                CoinIconView(size: 20)
                
                Text(formattedBalance)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.2))
            )
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView()
        }
        .fullScreenCover(isPresented: $showCoinShop) { // Added CoinShop presentation
            CoinShopView()
        }
        .onAppear {
            Task {
                try? await coinService.fetchBalance()
            }
        }
    }
    
    private var formattedBalance: String {
        guard let balance = coinService.coinBalance?.balance else {
            return "..."
        }
        
        // Format with thousand separator
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.groupingSize = 3
        
        return formatter.string(from: NSNumber(value: balance)) ?? "\(balance)"
    }
}

// MARK: - Preview

#Preview {
    StoryCreationFlowView()
}

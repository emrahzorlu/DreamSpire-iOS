//
//  TemplateDetailView.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025-11-02
//  Redesigned with Step-by-Step Wizard Pattern
//

import SwiftUI
import SDWebImageSwiftUI

struct TemplateDetailView: View {
    let template: Template
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: TemplateDetailViewModel
    @ObservedObject private var characterViewModel = CharacterBuilderViewModel.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    @ObservedObject private var coinService = CoinService.shared
    @ObservedObject private var jobManager = GenerationJobManager.shared

    @State private var currentStep = 0
    @State private var showingCharacterTypePicker = false
    @State private var selectedCharacterSlotId: String?
    @State private var showCoinShop = false
    @State private var showingSavedCharacters = false
    @State private var showingPaywall = false
    @State private var savedCharacterIds: Set<String> = []
    @State private var charactersFromSaved: Set<String> = []
    @State private var characterSlotToSave: String? = nil
    @State private var showGeneratingCover = false
    @State private var generationProgress: Double = 0.0
    @State private var generationStage: String = ""

    init(template: Template) {
        self.template = template
        _viewModel = StateObject(wrappedValue: TemplateDetailViewModel(template: template))
    }
    
    private var templateDuration: StoryDuration {
        let minutes = template.fixedParams.defaultMinutes
        switch minutes {
        case 0...3: return .quick
        case 4...5: return .standard
        case 6...8: return .extended
        default: return .epic
        }
    }
    
    private var totalCost: Int {
        var cost = templateDuration.baseCost // Base text cost (scales with duration)
        if viewModel.generateAudio {
            cost += templateDuration.audioCost
        }
        if viewModel.generateCoverImage {
            cost += 100 // Cover image cost
        }
        if viewModel.generateIllustrated {
            cost += templateDuration.illustratedCost // Illustrated story cost
        }
        return cost
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient.dwBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Navigation Header
                navigationHeader

                // Step Content - Disabled swipe gesture
                Group {
                    switch currentStep {
                    case 0:
                        step1Preview
                    case 1:
                        step2Characters
                    case 2:
                        step3Options
                    default:
                        step1Preview
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom Navigation
                bottomNavigation
            }
        }
        .dismissKeyboardOnTap()
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
        .sheet(isPresented: $showingCharacterTypePicker) {
            if let slotId = selectedCharacterSlotId {
                CharacterTypePickerView(
                    selectedType: Binding(
                        get: { viewModel.characters[slotId]?.type ?? .child },
                        set: { newType in
                            if var character = viewModel.characters[slotId] {
                                character.type = newType
                                viewModel.updateCharacter(slotId: slotId, character: character)
                            }
                        }
                    ),
                    selectedGender: Binding(
                        get: { viewModel.characters[slotId]?.gender ?? .unspecified },
                        set: { newGender in
                            if var character = viewModel.characters[slotId] {
                                character.gender = newGender
                                viewModel.updateCharacter(slotId: slotId, character: character)
                            }
                        }
                    ),
                    selectedRelationship: Binding(
                        get: { viewModel.characters[slotId]?.relationship },
                        set: { newRelationship in
                            if var character = viewModel.characters[slotId] {
                                character.relationship = newRelationship
                                viewModel.updateCharacter(slotId: slotId, character: character)
                            }
                        }
                    )
                )
            }
        }

        .fullScreenCover(isPresented: $showCoinShop) {
            CoinShopView()
        }
        .sheet(isPresented: $showingSavedCharacters) {
            SavedCharactersPickerView(
                savedCharacters: characterViewModel.savedCharacters,
                onSelect: { savedCharacter in
                    // Find first empty required slot or use selectedCharacterSlotId
                    let targetSlotId: String
                    if let slotId = selectedCharacterSlotId {
                        targetSlotId = slotId
                    } else {
                        // Find first empty required slot
                        let emptySlot = template.characterSchema.requiredSlots.first { slot in
                            if let char = viewModel.characters[slot.id] {
                                return char.name.isEmpty
                            }
                            return true
                        }
                        targetSlotId = emptySlot?.id ?? template.characterSchema.requiredSlots.first?.id ?? ""
                    }
                    
                    if !targetSlotId.isEmpty {
                        addCharacterFromSaved(savedCharacter, toSlot: targetSlotId)
                    }
                    showingSavedCharacters = false
                }
            )
        }
        .fullScreenCover(isPresented: $showGeneratingCover) {
            OwlGeneratingView(
                progress: $generationProgress,
                stage: $generationStage,
                storySnippet: .constant("template_generating_message".localized),
                onDismiss: {
                    // Close generating view and return to template gallery
                    showGeneratingCover = false
                    dismiss()
                    
                    // Navigate to library to show the in-progress job
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NotificationCenter.default.post(name: .navigateToLibraryMyStories, object: nil)
                    }
                },
                onRequestNotification: {
                    // Continue in background, navigate to library
                    showGeneratingCover = false
                    dismiss()
                    // Navigate to library to show the in-progress job
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NotificationCenter.default.post(name: .navigateToLibraryMyStories, object: nil)
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showingPaywall) {
            PaywallView()
        }
        .task {
            try? await coinService.fetchBalance()
            await subscriptionService.loadSubscription()
            await characterViewModel.loadSavedCharacters()
        }
        .onAppear {
            // Reset to first step when view appears
            currentStep = 0
        }
        .onChange(of: characterSlotToSave) { _, newValue in
            if let slotId = newValue, let character = viewModel.characters[slotId] {
                Task {
                    await toggleSaveCharacter(character, slotId: slotId)
                }
                characterSlotToSave = nil
            }
        }
        .onChange(of: viewModel.insufficientCoinsError) { _, isInsufficient in
            // Handle backend 402 insufficient coins error
            if isInsufficient {
                showGeneratingCover = false  // Close generating view
                // Show appropriate screen based on subscription tier
                if subscriptionService.currentTier == .free {
                    showingPaywall = true
                } else {
                    showCoinShop = true
                }
                viewModel.insufficientCoinsError = false  // Reset flag
            }
        }
        .preferredColorScheme(.light)
    }

    // MARK: - Navigation Header

    private var navigationHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                // Back Button (Arrow only)
                if currentStep > 0 {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            currentStep -= 1
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color.white.opacity(0.2)))
                    }
                } else {
                    Color.clear
                        .frame(width: 40, height: 40)
                }

                Spacer()
                
                // Step indicator text
                Text(stepTitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                // Close Button
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white.opacity(0.2)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)

            // Progress Dots
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index == currentStep ? Color.cyan : Color.white.opacity(0.3))
                        .frame(width: index == currentStep ? 28 : 8, height: 6)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
                }
            }
            .padding(.bottom, 4)
        }
    }
    
    private var stepTitle: String {
        switch currentStep {
        case 0: return "template_step_preview".localized
        case 1: return "template_step_characters".localized
        case 2: return "template_step_options".localized
        default: return ""
        }
    }

    // MARK: - Step 1: Preview

    private var step1Preview: some View {
        VStack(spacing: 20) {
            Spacer()
                .frame(height: 8)

            // Template Image or Emoji
            templateHeroImage

            // Title
            Text(template.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            // Description
            Text(template.description)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, 28)

            // Info Chips
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    infoChip(icon: "book.fill", text: localizedGenre)
                    infoChip(icon: "face.smiling", text: localizedTone)
                }

                HStack(spacing: 10) {
                    infoChip(icon: "clock.fill", text: "\(template.fixedParams.defaultMinutes) " + "minutes_short_text".localized)
                    infoChip(icon: "figure.child", text: ageRangeText)
                }
            }

            Spacer()
        }
    }

    private var templateHeroImage: some View {
        ZStack {
            // Gradient Background
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            tierGradientColors.0,
                            tierGradientColors.1
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 180, height: 180)
                .blur(radius: 40)

            // Image or Emoji
            if let previewImageUrl = template.previewImageUrl, !previewImageUrl.isEmpty {
                WebImage(url: URL(string: previewImageUrl)) { image in
                    image.resizable()
                } placeholder: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 32)
                            .fill(
                                LinearGradient(
                                    colors: [tierGradientColors.0, tierGradientColors.1],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                    }
                }
                .transition(.fade(duration: 0.3))
                .scaledToFill()
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 32))
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(Color.white.opacity(0.2), lineWidth: 2)
                )
                .shadow(color: tierGradientColors.0.opacity(0.5), radius: 30, x: 0, y: 15)
            } else {
                Text(template.emoji)
                    .font(.system(size: 100))
            }
        }
        .frame(height: 220)
    }

    private var tierGradientColors: (Color, Color) {
        switch template.tier {
        case .free:
            return (Color.gray.opacity(0.4), Color.gray.opacity(0.2))
        case .plus:
            return (Color.blue.opacity(0.5), Color.cyan.opacity(0.3))
        case .pro:
            return (Color.purple.opacity(0.5), Color.pink.opacity(0.3))
        }
    }

    private func infoChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(text)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.15))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
        )
    }

    private var ageRangeText: String {
        switch template.fixedParams.ageRange {
        case "toddler": return "template_age_toddler".localized
        case "preschool": return "template_age_preschool".localized
        case "young": return "template_age_young".localized
        case "middle": return "template_age_middle".localized
        default: return "template_age_all".localized
        }
    }
    
    private var localizedGenre: String {
        let genre = template.fixedParams.genre.lowercased()
        let genreMap: [String: String] = [
            // Turkish keys
            "uyku vakti": "genre_bedtime".localized,
            "macera": "genre_adventure".localized,
            "aile": "genre_family".localized,
            "arkadaşlık": "genre_friendship".localized,
            "fantastik": "genre_fantasy".localized,
            "hayvanlar": "genre_animals".localized,
            "prenses": "genre_princess".localized,
            "klasik": "genre_classic".localized,
            "gizem": "genre_mystery".localized,
            "fantezi": "genre_fantasy".localized,
            "komedi": "genre_comedy".localized,
            "eğitici": "genre_educational".localized,
            "masal": "genre_fairytale".localized,

            // German keys
            "gute nacht": "genre_bedtime".localized,
            "abenteuer": "genre_adventure".localized,
            "familie": "genre_family".localized,
            "freundschaft": "genre_friendship".localized,
            "fantasie": "genre_fantasy".localized,
            "tiere": "genre_animals".localized,
            "prinzessin": "genre_princess".localized,
            "klassisch": "genre_classic".localized,
            "geheimnis": "genre_mystery".localized,

            // French keys
            "coucher": "genre_bedtime".localized,
            "aventure": "genre_adventure".localized,
            "famille": "genre_family".localized,
            "amitié": "genre_friendship".localized,
            "fantastique": "genre_fantasy".localized,
            "animaux": "genre_animals".localized,
            "princesse": "genre_princess".localized,
            "classique": "genre_classic".localized,
            "mystère": "genre_mystery".localized,

            // Spanish keys
            "hora de dormir": "genre_bedtime".localized,
            "aventura": "genre_adventure".localized,
            "familia": "genre_family".localized,
            "amistad": "genre_friendship".localized,
            "fantasía": "genre_fantasy".localized,
            "animales": "genre_animals".localized,
            "princesa": "genre_princess".localized,
            "clásico": "genre_classic".localized,
            "misterio": "genre_mystery".localized,

            // English keys (from backend)
            "bedtime": "genre_bedtime".localized,
            "adventure": "genre_adventure".localized,
            "family": "genre_family".localized,
            "friendship": "genre_friendship".localized,
            "fantasy": "genre_fantasy".localized,
            "animals": "genre_animals".localized,
            "princess": "genre_princess".localized,
            "classic": "genre_classic".localized,
            "comedy": "genre_comedy".localized,
            "mystery": "genre_mystery".localized,
            "educational": "genre_educational".localized,
            "fairytale": "genre_fairytale".localized
        ]
        return (genreMap[genre] ?? template.fixedParams.genre).capitalized
    }
    
    private var localizedTone: String {
        let tone = template.fixedParams.tone.lowercased()
        let toneMap: [String: String] = [
            // Turkish keys
            "sakin": "tone_calm".localized,
            "heyecanlı": "tone_exciting".localized,
            "eğlenceli": "tone_fun".localized,
            "duygusal": "tone_heartwarming".localized,
            "gerilimli": "tone_suspenseful".localized,
            "ilham verici": "tone_inspiring".localized,
            "komik": "tone_funny".localized,
            "romantik": "tone_romantic".localized,
            "neşeli": "tone_cheerful".localized,
            "gizemli": "tone_mysterious".localized,
            "maceracı": "tone_adventurous".localized,
            "rahatlatıcı": "tone_relaxing".localized,

            // German keys
            "ruhig": "tone_calm".localized,
            "aufregend": "tone_exciting".localized,
            "lustig": "tone_funny".localized,
            "fröhlich": "tone_cheerful".localized,
            "geheimnisvoll": "tone_mysterious".localized,
            "herzerwärmend": "tone_heartwarming".localized,
            "abenteuerlich": "tone_adventurous".localized,
            "entspannend": "tone_relaxing".localized,
            "romantisch": "tone_romantic".localized,

            // French keys
            "calme": "tone_calm".localized,
            "excitant": "tone_exciting".localized,
            "drôle": "tone_funny".localized,
            "joyeux": "tone_cheerful".localized,
            "mystérieux": "tone_mysterious".localized,
            "émouvant": "tone_heartwarming".localized,
            "aventureux": "tone_adventurous".localized,
            "relaxant": "tone_relaxing".localized,
            "romantique": "tone_romantic".localized,

            // Spanish keys
            "tranquilo": "tone_calm".localized,
            "emocionante": "tone_exciting".localized,
            "divertido": "tone_funny".localized,
            "alegre": "tone_cheerful".localized,
            "misterioso": "tone_mysterious".localized,
            "conmovedor": "tone_heartwarming".localized,
            "aventurero": "tone_adventurous".localized,
            "relajante": "tone_relaxing".localized,
            "romántico": "tone_romantic".localized,

            // English keys (from backend)
            "calm": "tone_calm".localized,
            "exciting": "tone_exciting".localized,
            "fun": "tone_fun".localized,
            "funny": "tone_funny".localized,
            "cheerful": "tone_cheerful".localized,
            "mysterious": "tone_mysterious".localized,
            "heartwarming": "tone_heartwarming".localized,
            "adventurous": "tone_adventurous".localized,
            "relaxing": "tone_relaxing".localized,
            "romantic": "tone_romantic".localized,

            // Legacy/Extra mappings
            "emotional": "tone_heartwarming".localized,
            "suspenseful": "tone_mysterious".localized,
            "inspiring": "tone_heartwarming".localized
        ]
        return (toneMap[tone] ?? template.fixedParams.tone).capitalized
    }

    // MARK: - Step 2: Characters

    private var step2Characters: some View {
        VStack(spacing: 16) {
            // Title
            Text("template_add_characters".localized)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 12)

            // Saved Characters Button (Plus/Pro only)
            if subscriptionService.currentTier != .free && !characterViewModel.savedCharacters.isEmpty {
                savedCharactersButton
                    .padding(.horizontal, 20)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    ForEach(Array(template.characterSchema.allSlots.enumerated()), id: \.element.id) { index, slot in
                        WizardCharacterCard(
                            slot: slot,
                            number: index + 1,
                            character: Binding(
                                get: { viewModel.characters[slot.id] ?? Character(id: "", name: "", type: .child) },
                                set: { newCharacter in viewModel.updateCharacter(slotId: slot.id, character: newCharacter) }
                            ),
                            isSaved: savedCharacterIds.contains(slot.id),
                            isFromSaved: charactersFromSaved.contains(slot.id),
                            onSelectType: {
                                selectedCharacterSlotId = slot.id
                                showingCharacterTypePicker = true
                            },
                            onSave: {
                                characterSlotToSave = slot.id
                            },
                            onWarningChange: { hasWarning in
                                viewModel.updateContentSafetyWarning(slotId: slot.id, hasWarning: hasWarning)
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
        }
    }

    // MARK: - Step 3: Options

    private var step3Options: some View {
        VStack(spacing: 20) {
            // Title
            Text("options_title".localized)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 16)

            // Warning if job in progress
            if jobManager.hasActiveJobs {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("story_creation_already_in_progress".localized)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.orange.opacity(0.3))
                .cornerRadius(12)
                .padding(.horizontal, 20)
            }

            // Options
            VStack(spacing: 14) {
                WizardOptionCard(
                    icon: "🔊",
                    title: "addon_audio".localized,
                    subtitle: "addon_audio_subtitle".localized,
                    cost: templateDuration.audioCost,
                    isOn: $viewModel.generateAudio
                )

                WizardOptionCard(
                    icon: "🎨",
                    title: "addon_cover".localized,
                    subtitle: "addon_cover_subtitle".localized,
                    cost: 100,
                    isOn: $viewModel.generateCoverImage
                )

                WizardOptionCard(
                    icon: "📖",
                    title: "addon_illustrated".localized,
                    subtitle: "addon_illustrated_desc".localized,
                    cost: templateDuration.illustratedCost,
                    isOn: $viewModel.generateIllustrated
                )
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Cost Summary Card
            costSummaryCard
                .padding(.horizontal, 20)
            
            Spacer()
                .frame(height: 20)
        }
    }
    
    private var costSummaryCard: some View {
        VStack(spacing: 16) {
            // Total Cost
            HStack {
                Text("options_total_cost".localized)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Text("\(totalCost)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    CoinIconView(size: 24)
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Balance Check
            if let balance = coinService.coinBalance {
                HStack(spacing: 8) {
                    Image(systemName: balance.balance >= totalCost ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(balance.balance >= totalCost ? .green : .orange)
                        .font(.system(size: 18))
                    
                    Text(balance.balance >= totalCost ? "options_sufficient_balance".localized : "options_insufficient_balance".localized)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(balance.balance >= totalCost ? .green : .orange)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text(String(format: "duration_balance".localized, balance.balance))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        CoinIconView(size: 16)
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
                .contentShape(Rectangle())
                .onTapGesture {
                    if balance.balance < totalCost {
                        if subscriptionService.currentTier == .free {
                            showingPaywall = true
                        } else {
                            showCoinShop = true
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Bottom Navigation

    private var bottomNavigation: some View {
        VStack(spacing: 0) {
            Button(action: {
                if currentStep < 2 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        currentStep += 1
                    }
                } else {
                    // Check coins and generate
                    checkCoinsAndGenerate()
                }
            }) {
                HStack(spacing: 10) {
                    if viewModel.isGenerating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }

                    Text(buttonTitle)
                        .font(.system(size: 17, weight: .bold))

                    if currentStep < 2 {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .bold))
                    } else {
                        HStack(spacing: 4) {
                            Text("\(totalCost)")
                                .font(.system(size: 17, weight: .bold))
                            CoinIconView(size: 18)
                        }
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.545, green: 0.361, blue: 0.965), Color.purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
                .shadow(color: Color.purple.opacity(0.4), radius: 12, x: 0, y: 6)
            }
            .disabled(isButtonDisabled)
            .opacity(isButtonDisabled ? 0.5 : 1.0)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }
    
    private func checkCoinsAndGenerate() {
        guard let balance = coinService.coinBalance else {
            GlassAlertManager.shared.errorAlert(
                "error".localized,
                message: "error_balance_load".localized
            )
            return
        }

        if balance.balance < totalCost {
            // Show appropriate screen based on subscription tier:
            // - Free users → Paywall (to encourage subscription which includes coins)
            // - Subscribers (Plus/Pro) → Coin Shop (to buy more coins)
            if subscriptionService.currentTier == .free {
                showingPaywall = true
            } else {
                showCoinShop = true
            }
            return
        }

        // Show generating view
        showGeneratingCover = true
        generationProgress = 0.0
        generationStage = "generating_preparing".localized

        // Start progress simulation
        startProgressSimulation()

        Task {
            await viewModel.generateStory()

            await MainActor.run {
                generationProgress = 1.0

                // Only auto-dismiss and close generating view if:
                // 1. Story was successfully generated (not started in background)
                // 2. Generating view is still showing (user didn't dismiss it manually)
                if viewModel.generatedStory != nil && showGeneratingCover {
                    showGeneratingCover = false
                    dismiss()
                }
            }
        }
    }

    private var buttonTitle: String {
        if viewModel.isGenerating {
            return "template_generating".localized
        } else if currentStep < 2 {
            return "continue".localized
        } else {
            return "generate_story".localized
        }
    }

    private var isButtonDisabled: Bool {
        if viewModel.isGenerating {
            return true
        }

        // Disable if another job is already in progress
        if currentStep == 2 && jobManager.hasActiveJobs {
            return true
        }

        // Disable if there are any content safety warnings active
        if viewModel.contentSafetyWarnings.values.contains(true) {
            return true
        }

        // Step 1 (Characters): Disable until all required slots are filled
        if currentStep == 1 {
            let requiredSlots = template.characterSchema.requiredSlots
            for slot in requiredSlots {
                if let char = viewModel.characters[slot.id] {
                    if char.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        return true
                    }
                } else {
                    return true
                }
            }
        }

        if currentStep == 2 {
            return !viewModel.canGenerate
        }

        return false
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

                    Text(String(format: "character_count".localized, characterViewModel.savedCharacters.count))
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

    private func addCharacterFromSaved(_ savedCharacter: Character, toSlot slotId: String) {
        // Create a copy with savedCharacterId for usage tracking
        var newCharacter = Character(
            id: UUID().uuidString,  // New instance ID
            name: savedCharacter.name,
            type: savedCharacter.type,
            age: savedCharacter.age,
            description: savedCharacter.description
        )
        newCharacter.savedCharacterId = savedCharacter.id  // Store original ID for tracking

        viewModel.updateCharacter(slotId: slotId, character: newCharacter)
        charactersFromSaved.insert(slotId)
    }
    
    private func startProgressSimulation() {
        // Smooth progress simulation
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            guard viewModel.isGenerating else {
                timer.invalidate()
                return
            }
            
            // Smooth increment up to 90%
            if generationProgress < 0.9 {
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        generationProgress += 0.008
                    }
                    
                    // Update stage messages
                    if generationProgress < 0.3 {
                        generationStage = "create_characters_coming".localized
                    } else if generationProgress < 0.6 {
                        generationStage = "create_writing".localized
                    } else if generationProgress < 0.8 {
                        generationStage = "create_final_touches".localized
                    } else {
                        generationStage = "create_almost_ready".localized
                    }
                }
            }
        }
    }

    func toggleSaveCharacter(_ character: Character, slotId: String) async {
        // Check tier - free users get paywall
        if subscriptionService.currentTier == .free {
            await MainActor.run {
                showingPaywall = true
            }
            return
        }

        // Toggle logic
        if savedCharacterIds.contains(slotId) {
            // Already saved - remove from saved
            await MainActor.run {
                savedCharacterIds.remove(slotId)
                GlassAlertManager.shared.info(
                    "character_save_removed".localized,
                    message: String(format: "character_save_removed_message".localized, character.name)
                )
            }
        } else {
            // Not saved - save it
            let characterToSave = Character(
                id: character.id,
                name: character.name,
                type: character.type,
                age: character.age,
                description: character.description
            )

            do {
                _ = try await characterViewModel.saveCharacter(characterToSave)
                await MainActor.run {
                    savedCharacterIds.insert(slotId)
                    GlassAlertManager.shared.success(
                        "character_save_success".localized,
                        message: String(format: "character_save_success_message".localized, character.name)
                    )
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
}

// MARK: - Wizard Character Card

private struct WizardCharacterCard: View {
    let slot: CharacterSlot
    let number: Int
    @Binding var character: Character
    var isSaved: Bool = false
    var isFromSaved: Bool = false
    let onSelectType: () -> Void
    var onSave: (() -> Void)? = nil
    var onWarningChange: ((Bool) -> Void)? = nil

    private enum Field { case name, age, description }
    @FocusState private var focusedField: Field?
    @State private var contentSafetyWarning: ContentSafetyValidator.SoftWarning? = nil
    @State private var warningDebounceTask: Task<Void, Never>? = nil

    private var canSave: Bool {
        !character.name.isEmpty && character.name.count >= 2
    }

    var body: some View {
        VStack(spacing: 20) {
            headerSection
            inputSection
        }
        .padding(20)
        .modifier(WizardCardStyle())
        .onChange(of: character.name) { _, _ in handleContentChange() }
        .onChange(of: character.description) { _, _ in handleContentChange() }
    }

    private var inputSection: some View {
        VStack(spacing: 16) {
            typeSelector
            nameInputField
            ageInputField
            descriptionInputField
            safetyWarningView
        }
    }

    private func handleContentChange() {
        let combined = character.name + " " + (character.description ?? "")
        validateContent(combined)
    }

    private var headerSection: some View {
        HStack(spacing: 12) {
            Text(character.type.icon)
                .font(.system(size: 40))

            VStack(alignment: .leading, spacing: 4) {
                Text(slot.role)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(String(format: "character_title".localized, number))
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Save button
            if let onSave = onSave, canSave {
                Button(action: {
                    if !isFromSaved {
                        onSave()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: (isSaved || isFromSaved) ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 12))
                        Text((isSaved || isFromSaved) ? "character_saved".localized : "character_save".localized)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
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
                .fixedSize()
            }

            if slot.required {
                Text("required".localized)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.3))
                            .overlay(
                                Capsule()
                                    .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                            )
                    )
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }

    private var typeSelector: some View {
        Button(action: onSelectType) {
            HStack {
                Text(character.type.displayName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }

    private var nameInputField: some View {
        TextField("character_name_placeholder".localized, text: $character.name)
            .focused($focusedField, equals: .name)
            .submitLabel(.next)
            .onSubmit { focusedField = .age }
            .font(.system(size: 17))
            .foregroundColor(.white)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
    }

    private var ageInputField: some View {
        TextField("character_age_optional".localized, value: $character.age, format: .number)
            .focused($focusedField, equals: .age)
            .submitLabel(.next)
            .onSubmit { focusedField = .description }
            .font(.system(size: 17))
            .foregroundColor(.white)
            .keyboardType(.numberPad)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
    }

    private var descriptionInputField: some View {
        TextField("character_description_optional".localized, text: Binding(
            get: { character.description ?? "" },
            set: { character.description = $0.isEmpty ? nil : $0 }
        ), axis: .vertical)
            .focused($focusedField, equals: .description)
            .submitLabel(.done)
            .onSubmit { focusedField = nil }
            .font(.system(size: 15))
            .foregroundColor(.white)
            .lineLimit(3...5)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
    }

    private var safetyWarningView: some View {
        Group {
            if let warning = contentSafetyWarning {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 14))
                    
                    Text(warning.message)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
                .padding(12)
                .background(Color.orange.opacity(0.2))
                .cornerRadius(10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func validateContent(_ text: String) {
        warningDebounceTask?.cancel()
        warningDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
            guard !Task.isCancelled else { return }

            await MainActor.run {
                let currentLanguage = LocalizationManager.shared.currentLanguage.rawValue
                let warning = ContentSafetyValidator.getSoftWarning(
                    for: text,
                    language: currentLanguage
                )
                self.contentSafetyWarning = warning
                self.onWarningChange?(warning != nil)
            }
        }
    }
}

// MARK: - Wizard Option Card

private struct WizardOptionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    var cost: Int? = nil
    @Binding var isOn: Bool

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isOn.toggle()
            }
        }) {
            HStack(spacing: 14) {
                // Icon
                Text(icon)
                    .font(.system(size: 32))

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        if let cost = cost {
                            HStack(spacing: 3) {
                                Text("+\(cost)")
                                    .font(.system(size: 13, weight: .semibold))
                                CoinIconView(size: 14)
                            }
                            .foregroundColor(.white.opacity(0.7))
                        }
                    }

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                // Toggle Switch
                ZStack {
                    Capsule()
                        .fill(isOn ? Color.cyan : Color.white.opacity(0.2))
                        .frame(width: 50, height: 28)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                        .offset(x: isOn ? 10 : -10)
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isOn ? Color.cyan.opacity(0.1) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isOn ? Color.cyan.opacity(0.35) : Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    TemplateDetailView(template: Template.mockTemplate)
}

// MARK: - Helpers

private struct WizardCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
    }
}

extension Template {
    static var mockTemplate: Template {
        Template(
            id: "princess-castle",
            title: "Prenses Macerası",
            description: "Küçük bir prensesin büyülü krallıkta yaşadığı macera. Prenses, cesur bir arkadaş edinir ve birlikte krallığı kötülükten kurtarırlar.",
            emoji: "👑",
            category: .macera,
            tier: .plus,
            fixedParams: FixedParams(
                genre: "Macera, Fantezi",
                tone: "Heyecanlı",
                ageRange: "young",
                defaultMinutes: 5,
                language: "tr"
            ),
            characterSchema: CharacterSchema(
                minCharacters: 2,
                maxCharacters: 2,
                requiredSlots: [
                    CharacterSlot(
                        id: "princess",
                        role: "Prenses",
                        description: "Hikayenin ana kahramanı",
                        required: true
                    ),
                    CharacterSlot(
                        id: "friend",
                        role: "Arkadaş",
                        description: "Prensesin cesur arkadaşı",
                        required: true
                    )
                ],
                optionalSlots: []
            ),
            isPremium: true,
            usageCount: nil,
            previewImageUrl: nil
        )
    }
}

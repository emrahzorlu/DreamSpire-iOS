//
//  StoryCreationViewModel.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//

import Foundation
import Combine

@MainActor
class StoryCreationViewModel: ObservableObject {
    // MARK: - Published Properties
    
    // Navigation
    @Published var currentStep: CreationStep = .idea
    @Published var creationMode: CreationMode = .custom
    
    // Step 1: Story Idea
    @Published var storyIdea: String = ""
    @Published var selectedGenre: String = "adventure"
    @Published var selectedTone: String = "calm"
    
    // Step 2: Characters
    @Published var characters: [Character] = []
    @Published var savedCharacters: [Character] = []
    
    // Step 3: Audience Settings
    @Published var selectedAgeRange: String = "young"
    @Published var language: String = "tr"
    
    // Coin System: Duration & Addons
    @Published var selectedDuration: StoryDuration = .standard
    @Published var addons = StoryAddons(cover: true, audio: true)
    
    // State
    @Published var isGenerating: Bool = false
    @Published var generationProgress: Double = 0.0
    @Published var generationStage: String = ""
    @Published var generatedStory: Story?
    @Published var errorMessage: String?
    @Published var contentSafetyError: ContentSafetyError?
    @Published var showContentSafetySheet: Bool = false
    @Published var insufficientCoinsError: Bool = false  // Backend returned 402
    
    // MARK: - Dependencies
    
    private let storyService = StoryService.shared
    private let characterService = CharacterService.shared
    private let subscriptionService = SubscriptionService.shared
    private let authManager = AuthManager.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var canProceedToNextStep: Bool {
        switch currentStep {
        case .idea:
            return !storyIdea.isEmpty && storyIdea.count >= Constants.Story.minIdeaLength
        case .characters:
            return characters.filter { !$0.name.isEmpty }.count >= 1
        case .settings:
            return true
        case .generating, .result:
            return false
        }
    }
    
    var maxCharactersForTier: Int {
        subscriptionService.currentTier.maxCharactersPerStory
    }
    
    var canAddMoreCharacters: Bool {
        characters.count < maxCharactersForTier
    }
    
    var validCharacters: [Character] {
        characters.filter { !$0.name.isEmpty }
    }
    
    // MARK: - Initialization
    
    init() {
        DWLogger.shared.info("StoryCreationViewModel initialized", category: .story)
        
        // Add initial character
        addCharacter()
    }
    
    // MARK: - Navigation
    
    func goToNextStep() {
        guard canProceedToNextStep else { return }
        
        DWLogger.shared.logUserAction("Story Creation: Next Step", details: currentStep.description)
        
        switch currentStep {
        case .idea:
            currentStep = .characters
            Task { await loadSavedCharacters() }
        case .characters:
            currentStep = .settings
        case .settings:
            Task { await generateStory() }
        case .generating, .result:
            break
        }
    }
    
    func goToPreviousStep() {
        DWLogger.shared.logUserAction("Story Creation: Previous Step", details: currentStep.description)
        
        switch currentStep {
        case .idea:
            break
        case .characters:
            currentStep = .idea
        case .settings:
            currentStep = .characters
        case .generating, .result:
            break
        }
    }
    
    func reset() {
        DWLogger.shared.info("Resetting story creation", category: .story)
        
        currentStep = .idea
        storyIdea = ""
        characters = []
        selectedGenre = "adventure"
        selectedTone = "calm"
        selectedAgeRange = "young"
        language = "tr"
        selectedDuration = .standard
        addons = StoryAddons(cover: true, audio: true)
        isGenerating = false
        generationProgress = 0.0
        generationStage = ""
        generatedStory = nil
        errorMessage = nil
        
        // Add initial character
        addCharacter()
    }
    
    // MARK: - Character Management
    
    func addCharacter() {
        let (allowed, reason) = subscriptionService.canAddCharacter(currentCount: characters.count)
        
        guard allowed else {
            errorMessage = reason
            DWLogger.shared.warning("Cannot add character: \(reason ?? "Unknown")", category: .character)
            return
        }
        
        let newCharacter = Character(type: .child)
        characters.append(newCharacter)
        
        DWLogger.shared.debug("Character added, total: \(characters.count)", category: .character)
    }
    
    func removeCharacter(at index: Int) {
        guard index < characters.count else { return }
        
        characters.remove(at: index)
        DWLogger.shared.debug("Character removed, remaining: \(characters.count)", category: .character)
    }
    
    func updateCharacter(at index: Int, character: Character) {
        guard index < characters.count else { return }
        
        characters[index] = character
        DWLogger.shared.debug("Character updated at index: \(index)", category: .character)
    }
    
    func loadSavedCharacters() async {
        guard subscriptionService.currentTier != .free else {
            DWLogger.shared.debug("Skipping saved characters (free tier)", category: .character)
            return
        }
        
        DWLogger.shared.info("Loading saved characters", category: .character)
        
        do {
            savedCharacters = try await characterService.getSavedCharacters()
            DWLogger.shared.info("Loaded \(savedCharacters.count) saved characters", category: .character)
        } catch {
            DWLogger.shared.error("Failed to load saved characters", error: error, category: .character)
        }
    }
    
    func useSavedCharacter(_ savedCharacter: Character) {
        let (allowed, reason) = subscriptionService.canAddCharacter(currentCount: characters.count)
        
        guard allowed else {
            errorMessage = reason
            return
        }
        
        // Create a copy with savedCharacterId set for usage tracking
        var characterCopy = savedCharacter
        characterCopy.savedCharacterId = savedCharacter.id  // Store original ID for tracking
        characterCopy.id = UUID().uuidString  // New instance ID
        
        characters.append(characterCopy)
        DWLogger.shared.logUserAction("Used Saved Character", details: savedCharacter.name)
    }
    
    func saveCharacter(_ character: Character) async {
        let (allowed, reason) = subscriptionService.canSaveCharacter(currentCount: savedCharacters.count)
        
        guard allowed else {
            errorMessage = reason
            DWLogger.shared.warning("Cannot save character: \(reason ?? "Unknown")", category: .character)
            return
        }
        
        do {
            let saved = try await characterService.saveCharacter(character)
            savedCharacters.append(saved)
            
            // Notify that character count changed so other views can refresh
            NotificationCenter.default.post(name: .characterCountDidChange, object: nil)
            
            DWLogger.shared.info("Character saved: \(saved.name)", category: .character)
        } catch {
            errorMessage = "Karakter kaydedilemedi"
            DWLogger.shared.error("Failed to save character", error: error, category: .character)
        }
    }
    
    // MARK: - Story Generation
    
    func generateStory() async {
        guard !isGenerating else { return }
        
        // Check if user can create story
        let (allowed, reason) = subscriptionService.canCreateStory()
        guard allowed else {
            errorMessage = reason
            return
        }
        
        isGenerating = true
        currentStep = .generating
        generationProgress = 0.0
        errorMessage = nil
        
        DWLogger.shared.logStoryCreationStart(prompt: storyIdea, characters: validCharacters.count)
        
        do {
            // Use coin-based story creation
            let response = try await storyService.createStoryWithCoins(
                prompt: storyIdea,
                duration: selectedDuration,
                addons: addons,
                genre: selectedGenre,
                tone: selectedTone,
                ageRange: selectedAgeRange,
                language: language,
                characters: validCharacters,
                voice: nil // Will use default voice selection
            )
            
            // 💰 UPDATE COIN BALANCE IMMEDIATELY
            await CoinService.shared.updateBalance(response.coinTransaction.newBalance)
            DWLogger.shared.info("💰 Coin balance updated: \(response.coinTransaction.newBalance) (spent: \(response.coinTransaction.spent))", category: .coin)
 
            // Handle async generation with real-time progress
            if response.isAsync, let jobId = response.jobId {
                DWLogger.shared.info("Async generation started, polling job: \(jobId)", category: .story)
                
                // Register job with GenerationJobManager
                let userId = authManager.currentUserId ?? "guest"
                await GenerationJobManager.shared.startJob(
                    jobId: jobId,
                    storyTitle: storyIdea.isEmpty ? "Yeni Hikaye" : String(storyIdea.prefix(50)),
                    userId: userId
                )
                
                // Poll with real-time progress callback
                let story = try await storyService.pollJobStatus(jobId: jobId) { [weak self] progress, statusMessage in
                    guard let self = self else { return }
                    self.generationProgress = progress
                    self.generationStage = statusMessage
                    
                    // Update job manager
                    await GenerationJobManager.shared.updateJob(
                        jobId: jobId,
                        progress: progress,
                        status: statusMessage
                    )
                    
                    DWLogger.shared.debug("Progress: \(Int(progress * 100))% - \(statusMessage)", category: .story)
                }
                
                generatedStory = story
                
                // Mark job as completed
                await GenerationJobManager.shared.completeJob(jobId: jobId, story: story)
                
            } else {
                // Sync generation - story is ready immediately
                generatedStory = response.story
            }
            
            generationProgress = 1.0
            currentStep = .result

            // Request app review if appropriate
            AppReviewManager.shared.requestReviewIfAppropriate()

            // Increment usage
            await subscriptionService.incrementStoryUsage()
            
            // Increment saved character usage (track which characters were used in stories)
            await incrementSavedCharacterUsage(storyId: generatedStory?.id)

            DWLogger.shared.logAnalyticsEvent(
                Constants.Analytics.storyCreated,
                parameters: [
                    "type": "custom",
                    "tier": subscriptionService.currentTier.rawValue,
                    "illustrated": addons.illustrated,
                    "characters": validCharacters.count,
                    "duration": selectedDuration.rawValue,
                    "coins_spent": response.coinTransaction.spent
                ]
            )
            
        } catch {
            // Check if this is a polling timeout (story still generating in background)
            if let timeoutError = error as? StoryServiceError,
               case .pollingTimeout(let jobId, _) = timeoutError {
                DWLogger.shared.warning("⏰ Polling timeout - story will continue in background: \(jobId)", category: .story)

                // Story is still generating in background - user will see it in library
                isGenerating = false
                currentStep = .settings

                // Show informative alert
                GlassAlertManager.shared.info(
                    "Hikaye Arka Planda Oluşturuluyor",
                    message: "Hikayeniz arka planda oluşturulmaya devam ediyor. Hazır olduğunda kütüphanenizde görünecek.",
                    duration: 5.0
                )
                generatedStory = nil
                return
            }

            // Check for structured StoryError (NEW format)
            if let storyError = error.storyError {
                self.contentSafetyError = nil // Clear legacy error
                DWLogger.shared.warning("Story error: \(storyError.type.rawValue)", category: .story)

                // Show with retry button
                storyError.show(onRetry: { [weak self] in
                    // Retry story generation
                    Task { @MainActor in
                        await self?.generateStory()
                    }
                })

                isGenerating = false
                currentStep = .settings
                return
            }

            // Check for legacy ContentSafetyError
            if let safetyError = error.contentSafetyError {
                self.contentSafetyError = safetyError
                self.showContentSafetySheet = true
                DWLogger.shared.warning("Content safety violation: \(safetyError.title)", category: .story)

                isGenerating = false
                currentStep = .settings
                return
            }

            // Check for insufficient coins error
            if error.isInsufficientCoins {
                DWLogger.shared.warning("Insufficient coins for story creation", category: .coin)
                insufficientCoinsError = true  // Trigger modal display
                isGenerating = false
                currentStep = .settings
                return
            }

            // Handle with unified error handler
            DWLogger.shared.error("Story generation failed", error: error, category: .story)
            GlassAlertManager.shared.handleError(
                error,
                defaultTitle: "error_story_create".localized,
                onRetry: { [weak self] in
                    Task { @MainActor in
                        await self?.generateStory()
                    }
                }
            )

            isGenerating = false
            currentStep = .settings
        }
    }
    
    // MARK: - Types
    
    enum CreationStep {
        case idea
        case characters
        case settings
        case generating
        case result
        
        var description: String {
            switch self {
            case .idea: return "Story Idea"
            case .characters: return "Characters"
            case .settings: return "Settings"
            case .generating: return "Generating"
            case .result: return "Result"
            }
        }
    }
    
    enum CreationMode {
        case custom
        case template
    }

    // MARK: - Content Safety Helpers

    func useExamplePrompt(_ example: String) {
        storyIdea = example
        showContentSafetySheet = false
        DWLogger.shared.logUserAction("Used Content Safety Example", details: example)
    }

    func dismissContentSafetyError() {
        showContentSafetySheet = false
        contentSafetyError = nil
    }
    
    // MARK: - Character Usage Tracking
    
    /// Increment usage count for saved characters used in this story
    private func incrementSavedCharacterUsage(storyId: String?) async {
        // Get character IDs from characters that have savedCharacterId set
        // (meaning they were copied from saved characters)
        let savedCharacterIds = validCharacters.compactMap { $0.savedCharacterId }
        
        guard !savedCharacterIds.isEmpty else {
            DWLogger.shared.debug("No saved characters to track usage for", category: .character)
            return
        }
        
        DWLogger.shared.info("Tracking usage for \(savedCharacterIds.count) saved character(s)", category: .character)
        
        for characterId in savedCharacterIds {
            do {
                try await characterService.incrementCharacterUsage(characterId: characterId, storyId: storyId)
                DWLogger.shared.debug("Usage incremented for character: \(characterId)", category: .character)
            } catch {
                // Don't fail story creation if usage tracking fails
                DWLogger.shared.warning("Failed to increment usage for character \(characterId): \(error.localizedDescription)", category: .character)
            }
        }
    }
}

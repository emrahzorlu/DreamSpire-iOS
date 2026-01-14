//
//  TemplateDetailViewModel.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025-11-02
//

import Foundation
import Combine

@MainActor
class TemplateDetailViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var characters: [String: Character] = [:]
    @Published var generateAudio: Bool = true
    @Published var generateCoverImage: Bool = true
    @Published var generateIllustrated: Bool = false  // NEW: Illustrated story (default off)
    @Published var isGenerating: Bool = false
    @Published var error: String?
    @Published var insufficientCoinsError: Bool = false  // Backend returned 402
    @Published var generatedStory: Story?
    @Published var generationProgress: Double = 0.0
    @Published var generationStage: String = ""
    @Published var contentSafetyWarnings: [String: Bool] = [:] // slotId: hasWarning
    
    // MARK: - Properties
    
    let template: Template
    private let templateService = TemplateService.shared
    private let subscriptionService = SubscriptionService.shared
    private let authManager = AuthManager.shared
    private let storyService = StoryService.shared
    
    // MARK: - Computed Properties
    
    var canGenerate: Bool {
        let requiredSlots = template.characterSchema.requiredSlots
        return requiredSlots.allSatisfy { slot in
            if let character = characters[slot.id] {
                return !character.name.isEmpty
            }
            return false
        }
    }
    
    
    // MARK: - Initialization
    
    init(template: Template) {
        self.template = template
        
        // Initialize empty characters for all slots
        for slot in template.characterSchema.allSlots {
            characters[slot.id] = Character(type: .child) // Default type
        }
        
        DWLogger.shared.info("TemplateDetailViewModel initialized: \(template.title)", category: .ui)
    }
    
    // MARK: - Actions
    
    func updateCharacter(slotId: String, character: Character) {
        characters[slotId] = character
        DWLogger.shared.debug("Updated character for slot: \(slotId)", category: .character)
    }
    
    func updateContentSafetyWarning(slotId: String, hasWarning: Bool) {
        contentSafetyWarnings[slotId] = hasWarning
    }
    
    func generateStory() async {
        guard canGenerate else {
            error = "error_fill_required".localized
            return
        }

        // Check subscription limits
        let (allowed, reason) = subscriptionService.canCreateStory()
        guard allowed else {
            error = reason
            return
        }

        isGenerating = true
        error = nil
        generationProgress = 0.0
        generationStage = "create_preparing".localized

        DWLogger.shared.logUserAction("Generate Story from Template", details: template.title)

        do {
            // Use template's defaultMinutes instead of hardcoded 10
            let response = try await templateService.generateFromTemplate(
                templateId: template.id,
                characters: characters,
                readingMinutes: template.fixedParams.defaultMinutes,
                generateAudio: generateAudio,
                generateImage: generateCoverImage,
                illustrated: generateIllustrated
            )
 
            // 💰 UPDATE COIN BALANCE IMMEDIATELY
            if let coinTx = response.coinTransaction {
                await CoinService.shared.updateBalance(coinTx.newBalance)
                DWLogger.shared.info("💰 Coin balance updated immediately from template response: \(coinTx.newBalance)", category: .coin)
            }
 
            // Handle async generation with real-time progress
            if response.isAsync, let jobId = response.jobId {
                DWLogger.shared.info("Async template generation started, polling job: \(jobId)", category: .story)
                
                // Register job with GenerationJobManager
                let userId = authManager.currentUserId ?? "guest"
                await GenerationJobManager.shared.startJob(
                    jobId: jobId,
                    storyTitle: template.title,
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
                
            } else if let story = response.story {
                // Sync generation - story is ready immediately
                generatedStory = story
            }

            generationProgress = 1.0

            DWLogger.shared.logAnalyticsEvent("story_created_from_template", parameters: [
                "template_id": template.id,
                "template_title": template.title,
                "character_count": characters.count,
                "reading_minutes": template.fixedParams.defaultMinutes
            ])

            // Increment usage
            await subscriptionService.incrementStoryUsage()
            
            // Increment saved character usage
            await incrementSavedCharacterUsage(storyId: generatedStory?.id)

        } catch let apiError as APIError {
            // Handle specific API errors
            switch apiError {
            case .insufficientCoins:
                // Set special flag to show insufficient coins modal
                self.insufficientCoinsError = true
                DWLogger.shared.warning("Insufficient coins for template story", category: .coin)
            case .contentSafety(let safetyError):
                self.error = safetyError.formattedMessage
                DWLogger.shared.warning("Content safety violation: \(safetyError.title)", category: .story)
            case .storyError(let storyError):
                self.error = storyError.userMessage.message
                DWLogger.shared.warning("Story error: \(storyError.title)", category: .story)
            default:
                self.error = "error_story_generation_failed".localized + ": " + apiError.localizedDescription
                DWLogger.shared.error("Template story generation failed", error: apiError, category: .story)
            }
        } catch {
            // Use localized error message from backend if available, otherwise fallback to generic
            let errorMessage = error.localizedDescription
            if errorMessage.contains("content safety") || errorMessage.contains("uygunsuz içerik") {
                self.error = errorMessage
            } else {
                self.error = "error_story_generation_failed".localized + ": " + errorMessage
            }
            DWLogger.shared.error("Template story generation failed", error: error, category: .story)
        }

        isGenerating = false
    }
    
    // MARK: - Character Usage Tracking
    
    /// Increment usage count for saved characters used in this story
    private func incrementSavedCharacterUsage(storyId: String?) async {
        let characterService = CharacterService.shared
        
        // Get character IDs from characters that have savedCharacterId set
        // (meaning they were copied from saved characters)
        let savedCharacterIds = characters.values.compactMap { $0.savedCharacterId }
        
        guard !savedCharacterIds.isEmpty else {
            DWLogger.shared.debug("No saved characters to track usage for in template", category: .character)
            return
        }
        
        DWLogger.shared.info("Tracking usage for \(savedCharacterIds.count) saved character(s) in template", category: .character)
        
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

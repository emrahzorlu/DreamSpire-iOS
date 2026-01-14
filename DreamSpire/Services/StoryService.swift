//
//  StoryService.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//

import Foundation

class StoryService {
    static let shared = StoryService()
    private let apiClient = APIClient.shared
    private let authManager = AuthManager.shared
    
    private init() {
        DWLogger.shared.info("StoryService initialized", category: .story)
    }
    
    // MARK: - Job Polling
    
    /// Poll job status until completion with real-time progress updates
    /// Poll job status with progressive intervals:
    /// - 0-30s: 3s interval (responsive without spamming)
    /// - 30s-2min: 5s interval (moderate)
    /// - 2min+: 8s interval (slow updates for long jobs like illustrations)
    /// - Parameters:
    ///   - jobId: The job ID to poll
    ///   - progressCallback: Real-time progress updates (0.0 - 1.0, status message)
    /// - Returns: The completed story
    func pollJobStatus(
        jobId: String,
        progressCallback: (@MainActor @Sendable (Double, String) async -> Void)? = nil
    ) async throws -> Story {
        DWLogger.shared.info("Polling job status: \(jobId) with progressive intervals", category: .story)

        let startTime = Date()
        var attempts = 0
        let maxDuration: TimeInterval = 30 * 60 // 30 minutes max (for illustrated stories with 7 images)

        while Date().timeIntervalSince(startTime) < maxDuration {
            attempts += 1

            // Get job status
            let statusResponse: StoryJobStatusResponse = try await apiClient.makeRequest(
                endpoint: "/api/story-jobs/\(jobId)",
                method: .get,
                requiresAuth: true
            )

            let job = statusResponse.job

            DWLogger.shared.debug("Job \(jobId) status: \(job.status), progress: \(job.progress)%", category: .story)

            // Send real-time progress update
            if let callback = progressCallback {
                let progress = job.progress / 100.0
                let statusMessage = getStatusMessage(from: job.status)
                await callback(progress, statusMessage)
            }

            if job.isCompleted {
                guard let storyId = job.storyId else {
                    // Race condition: Backend marked job as completed but storyId not yet set
                    // This can happen due to timing - wait and poll again instead of failing
                    DWLogger.shared.warning("⚠️ Job marked completed but storyId not yet available - will retry", category: .story)

                    // Send near-completion progress to show we're almost done
                    if let callback = progressCallback {
                        await callback(0.98, "create_final_touches".localized)
                    }

                    // Wait a bit before next poll (backend needs time to update storyId)
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    continue // Poll again
                }

                DWLogger.shared.info("✅ Job completed in \(Int(Date().timeIntervalSince(startTime)))s (attempts: \(attempts))", category: .story)

                // Send 100% progress before fetching story
                if let callback = progressCallback {
                    await callback(1.0, "create_final_touches".localized)
                }

                // Fetch the completed story
                let storyResponse: StoryResponse = try await apiClient.makeRequest(
                    endpoint: "/api/stories/\(storyId)",
                    method: .get,
                    requiresAuth: true
                )

                return storyResponse.story
            }

            if job.isFailed {
                // Use user-friendly error if available, otherwise technical error
                let errorMsg = job.userFriendlyError ?? job.error ?? "Hikaye oluşturulurken bir hata oluştu"
                DWLogger.shared.error("Job failed: \(errorMsg) (category: \(job.errorCategory ?? "unknown"))", category: .story)

                // Update job manager with error details
                await GenerationJobManager.shared.updateJob(
                    jobId: jobId,
                    progress: Double(job.progress) / 100.0,
                    status: job.status,
                    error: job.error,
                    userFriendlyError: job.userFriendlyError,
                    errorCategory: job.errorCategory,
                    coinsRefunded: job.coinsRefunded
                )

                throw APIError.serverError(500)
            }

            // Progressive polling interval based on elapsed time
            let elapsed = Date().timeIntervalSince(startTime)
            let pollInterval: UInt64
            if elapsed < 30 {
                // First 30 seconds: 3s interval (responsive but not spammy)
                pollInterval = 3_000_000_000
            } else if elapsed < 120 {
                // 30s - 2 minutes: 5s interval (moderate)
                pollInterval = 5_000_000_000
            } else {
                // 2+ minutes: 8s interval (slow, for long illustrated stories)
                pollInterval = 8_000_000_000
            }

            try await Task.sleep(nanoseconds: pollInterval)
        }

        // Polling timeout - but job may still complete in background
        DWLogger.shared.warning("⏰ Polling timeout after \(Int(maxDuration))s - Job will continue in background", category: .story)

        // Mark job as continuing in background (don't throw error)
        await GenerationJobManager.shared.updateJob(
            jobId: jobId,
            progress: 0.95, // Almost done
            status: "Finalizing in background..."
        )

        // Throw a special timeout error that can be handled gracefully
        throw StoryServiceError.pollingTimeout(jobId: jobId, message: "story_generating_background".localized)
    }
    
    /// Convert backend status to user-friendly message
    private func getStatusMessage(from status: String) -> String {
        switch status.lowercased() {
        case "pending", "queued":
            return "create_preparing".localized
        case "generating_content", "generating_story":
            return "create_writing".localized
        case "generating_audio", "creating_audio":
            return "create_audio_generating".localized
        case "generating_images", "creating_images":
            return "create_images_generating".localized
        case "finalizing", "completing":
            return "create_final_touches".localized
        default:
            return "create_adventure_forming".localized
        }
    }
    
    // MARK: - Create Stories (COIN SYSTEM)
    
    /// Create a story with coin system (duration + addons)
    /// Supports all users (authenticated or anonymous)
    func createStoryWithCoins(
        prompt: String,
        duration: StoryDuration,
        addons: StoryAddons,
        genre: String,
        tone: String,
        ageRange: String,
        language: String,
        characters: [Character],
        voice: String? = nil
    ) async throws -> StoryCreationResponse {
        // isGuest check is no longer needed as all users have a userId
        DWLogger.shared.info("Creating story with coin system (all users)", category: .story)
        DWLogger.shared.logStoryCreationStart(prompt: prompt, characters: characters.count)
        let startTime = Date()
        
        // Build request without deviceId
        var request = CreateStoryWithCoinsRequest(
            duration: duration.rawValue,
            addons: AddonsRequest(
                cover: addons.cover,
                audio: addons.audio,
                illustrated: addons.illustrated
            ),
            prompt: prompt,
            genre: genre,
            tone: tone,
            ageRange: ageRange,
            language: language,
            voice: voice,
            characters: characters.map { CharacterRequest(from: $0) }
            // deviceId is no longer sent in the request body
        )
        
        do {
            let response: StoryCreationResponse = try await apiClient.makeRequest(
                endpoint: Constants.API.Endpoints.createStory,
                method: .post,
                body: request
            )
            
            // Only log story details for sync responses
            if !response.isAsync, let story = response.story {
                let duration = Date().timeIntervalSince(startTime)
                DWLogger.shared.logStoryCreationComplete(
                    storyId: story.id,
                    duration: duration,
                    pages: story.pages.count,
                    isIllustrated: story.isIllustrated
                )
            } else if response.isAsync {
                DWLogger.shared.info("Story generation started asynchronously (jobId: \(response.jobId ?? "unknown"))", category: .story)
            }
            
            DWLogger.shared.info("Coins spent: \(response.coinTransaction.spent)", category: .story)
            
            return response
        } catch {
            DWLogger.shared.error("Story creation failed", error: error, category: .story)
            throw error
        }
    }
    
    // MARK: - Fetch Stories
    
    /// Get user's stories
    func getUserStories(userId: String, summary: Bool = false) async throws -> [Story] {
        DWLogger.shared.info("Fetching user stories: \(userId) (summary: \(summary))", category: .story)
        
        do {
            let stories = try await apiClient.getUserStories(userId: userId, summary: summary)
            
            DWLogger.shared.info("Fetched \(stories.count) stories", category: .story)
            return stories
        } catch {
            DWLogger.shared.error("Failed to fetch user stories", error: error, category: .story)
            throw error
        }
    }
    

    

    
    /// Get single story by ID
    func getStory(id: String) async throws -> Story {
        DWLogger.shared.info("Fetching story: \(id)", category: .story)

        do {
            let response: StoryResponse = try await apiClient.makeRequest(
                endpoint: "\(Constants.API.Endpoints.singleStory)/\(id)",
                method: .get
            )

            DWLogger.shared.info("Story fetched: \(response.story.title)", category: .story)
            return response.story
        } catch {
            DWLogger.shared.error("Failed to fetch story", error: error, category: .story)
            throw error
        }
    }
    
    // MARK: - Delete Story
    
    func deleteStory(id: String) async throws {
        DWLogger.shared.info("Deleting story: \(id)", category: .story)
        
        do {
            let _: EmptyResponse = try await apiClient.makeRequest(
                endpoint: "\(Constants.API.Endpoints.singleStory)/\(id)",
                method: .delete
            )
            
            DWLogger.shared.info("Story deleted successfully", category: .story)
        } catch {
            DWLogger.shared.error("Failed to delete story", error: error, category: .story)
            throw error
        }
    }
    
    // MARK: - Favorites
    
    func toggleFavorite(storyId: String) async throws -> Bool {
        DWLogger.shared.info("Toggling favorite: \(storyId)", category: .story)
        
        do {
            let response: ToggleFavoriteResponse = try await apiClient.makeRequest(
                endpoint: Constants.API.Endpoints.toggleFavorite,
                method: .post,
                body: ["storyId": storyId]
            )
            
            DWLogger.shared.info("Favorite toggled: \(response.isFavorite)", category: .story)
            return response.isFavorite
        } catch {
            DWLogger.shared.error("Failed to toggle favorite", error: error, category: .story)
            throw error
        }
    }
    
    func getFavorites() async throws -> [Story] {
        DWLogger.shared.info("Fetching favorites", category: .story)
        
        do {
            let stories = try await apiClient.getUserFavorites()
            
            DWLogger.shared.info("Fetched \(stories.count) favorites", category: .story)
            return stories
        } catch {
            DWLogger.shared.error("Failed to fetch favorites", error: error, category: .story)
            throw error
        }
    }
}

// MARK: - Story Service Errors

enum StoryServiceError: LocalizedError {
    case pollingTimeout(jobId: String, message: String)

    var errorDescription: String? {
        switch self {
        case .pollingTimeout(_, let message):
            return message
        }
    }

    var jobId: String? {
        switch self {
        case .pollingTimeout(let jobId, _):
            return jobId
        }
    }
}

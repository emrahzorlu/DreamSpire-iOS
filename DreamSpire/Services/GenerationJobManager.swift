//
//  GenerationJobManager.swift
//  DreamSpire
//
//  Manages story generation jobs with persistence and background polling
//

import Foundation
import Combine
import UIKit

@MainActor
class GenerationJobManager: ObservableObject {
    static let shared = GenerationJobManager()
    
    @Published var activeJobs: [GenerationJobState] = []
    @Published var completedJobs: [GenerationJobState] = []

    private let storyService = StoryService.shared
    private let notificationManager = NotificationManager.shared
    private var pollingTasks: [String: Task<Void, Never>] = [:]
    private var backgroundTasks: [String: UIBackgroundTaskIdentifier] = [:]

    // Computed property to check if user has active jobs
    var hasActiveJobs: Bool {
        !activeJobs.filter { $0.isActive }.isEmpty
    }
    
    private init() {
        loadPersistedJobs()
        DWLogger.shared.info("GenerationJobManager initialized with \(activeJobs.count) active jobs", category: .app)
    }
    
    // MARK: - Job Management
    
    /// Start tracking a new generation job
    func startJob(jobId: String, storyTitle: String, userId: String, originalRequest: CreateStoryWithCoinsRequest? = nil, shouldNotify: Bool = false, startPolling: Bool = true) {
        var job = GenerationJobState(
            jobId: jobId,
            storyTitle: storyTitle,
            userId: userId,
            shouldNotify: shouldNotify
        )
        job.originalRequest = originalRequest

        activeJobs.append(job)
        persistJobs()

        DWLogger.shared.info("✅ Started tracking job: \(jobId) - \(storyTitle) (notify: \(shouldNotify), polling: \(startPolling)) - Total active jobs: \(activeJobs.count)", category: .story)

        // Start polling only if requested (not for temporary jobs)
        if startPolling {
            self.startPolling(for: jobId)
        }
    }
    
    /// Update job progress
    func updateJob(jobId: String, progress: Double, status: String, error: String? = nil, userFriendlyError: String? = nil, errorCategory: String? = nil, coinsRefunded: Bool? = nil) {
        guard let index = activeJobs.firstIndex(where: { $0.id == jobId }) else { return }

        activeJobs[index].progress = progress
        activeJobs[index].status = status
        activeJobs[index].lastUpdateTime = Date()
        activeJobs[index].error = error
        activeJobs[index].userFriendlyError = userFriendlyError
        activeJobs[index].errorCategory = errorCategory
        activeJobs[index].coinsRefunded = coinsRefunded

        // Estimate completion time based on progress
        if progress > 0 && progress < 1.0 {
            let elapsed = activeJobs[index].elapsedTime
            let estimatedTotal = elapsed / progress
            let remaining = estimatedTotal - elapsed
            activeJobs[index].estimatedCompletionTime = Date().addingTimeInterval(remaining)
        }

        // Trigger SwiftUI update by reassigning the array
        activeJobs = activeJobs

        persistJobs()

        DWLogger.shared.debug("Updated job \(jobId): \(Int(progress * 100))% - \(status)", category: .story)
    }
    
    /// Mark job as completed
    func completeJob(jobId: String, story: Story) {
        guard let index = activeJobs.firstIndex(where: { $0.id == jobId }) else { return }
        
        var job = activeJobs.remove(at: index)
        job.storyId = story.id
        job.status = "completed"
        job.progress = 1.0
        job.lastUpdateTime = Date()
        
        completedJobs.append(job)
        persistJobs()
        
        // Push to repository cache immediately (Incremental Update!)
        UserStoryRepository.shared.addStory(story)
        
        // Stop polling
        stopPolling(for: jobId)

        // Send notification if user requested it and not already sent
        if job.shouldNotify && !job.notificationSent {
            Task {
                await notificationManager.sendStoryReadyNotification(
                    storyTitle: job.storyTitle,
                    storyId: story.id
                )

                // Mark notification as sent
                if let completedIndex = completedJobs.firstIndex(where: { $0.id == jobId }) {
                    completedJobs[completedIndex].notificationSent = true
                    persistJobs()
                }
            }
            DWLogger.shared.info("Completed job: \(jobId) → Story: \(story.id) - Notification sent", category: .story)
        } else {
            DWLogger.shared.info("Completed job: \(jobId) → Story: \(story.id) - No notification (shouldNotify: \(job.shouldNotify))", category: .story)
        }
    }
    
    /// Mark job as failed
    func failJob(jobId: String, error: String, userFriendlyError: String? = nil) {
        guard let index = activeJobs.firstIndex(where: { $0.id == jobId }) else { return }

        var job = activeJobs.remove(at: index)
        job.status = "failed"
        job.error = error

        // Preserve existing userFriendlyError from backend if not provided
        if let providedError = userFriendlyError {
            job.userFriendlyError = providedError
        } else if job.userFriendlyError == nil {
            // Only set default if no user-friendly error exists
            job.userFriendlyError = "Hikaye oluşturulurken bir hata oluştu. Lütfen tekrar deneyin."
        }
        // else: keep existing job.userFriendlyError from backend (updateJob)

        job.lastUpdateTime = Date()

        completedJobs.append(job)
        persistJobs()

        // Stop polling
        stopPolling(for: jobId)

        DWLogger.shared.error("Job failed: \(jobId) - \(error) (User message: \(job.userFriendlyError ?? "none"))", category: .story)
    }
    
    /// Cancel a job
    func cancelJob(jobId: String) {
        guard let index = activeJobs.firstIndex(where: { $0.id == jobId }) else { return }

        activeJobs.remove(at: index)
        persistJobs()

        // Stop polling
        stopPolling(for: jobId)

        // Cancel notification
        notificationManager.cancelNotification(identifier: "story_\(jobId)")

        DWLogger.shared.info("Cancelled job: \(jobId)", category: .story)
    }

    /// Remove a completed/failed job from the list
    func removeCompletedJob(jobId: String) {
        completedJobs.removeAll { $0.id == jobId }
        persistJobs()  // CRITICAL: Persist after removal
        DWLogger.shared.info("Removed completed job: \(jobId)", category: .story)
    }

    /// Retry a failed job automatically
    func retryJob(jobId: String) async {
        guard let index = completedJobs.firstIndex(where: { $0.id == jobId }),
              let request = completedJobs[index].originalRequest else {
            DWLogger.shared.warning("Cannot retry job \(jobId): Request not found or job not in completed list", category: .story)
            return
        }

        let oldJob = completedJobs[index]
        DWLogger.shared.info("🔄 Automatically retrying job: \(jobId) - \(oldJob.storyTitle)", category: .story)

        do {
            // 1. Start a new generation request using the saved request body
            let response: StoryCreationResponse = try await APIClient.shared.makeRequest(
                endpoint: "/api/stories/create",
                method: .post,
                body: request,
                requiresAuth: true
            )

            if let newJobId = response.jobId {
                DWLogger.shared.info("✅ Retry request successful, new jobId: \(newJobId)", category: .story)
                
                // 2. Remove old job from completed list AFTER success
                await MainActor.run {
                    completedJobs.removeAll { $0.id == jobId }
                    persistJobs()
                }
                
                // 3. Start tracking the new job
                startJob(
                    jobId: newJobId,
                    storyTitle: oldJob.storyTitle,
                    userId: oldJob.userId,
                    originalRequest: request,
                    shouldNotify: oldJob.shouldNotify
                )
            } else if let story = response.story {
                // If it returned a sync story (unlikely for jobs but handled)
                DWLogger.shared.info("✅ Retry request returned sync story", category: .story)
                await MainActor.run {
                    completedJobs.removeAll { $0.id == jobId }
                    persistJobs()
                    UserStoryRepository.shared.addStory(story)
                }
            }
        } catch {
            DWLogger.shared.error("❌ Retry request failed for job \(jobId)", error: error, category: .story)
            // Error is logged, job remains in completedJobs so user can try again
        }
    }
    
    /// Get job by ID
    func getJob(jobId: String) -> GenerationJobState? {
        return activeJobs.first(where: { $0.id == jobId })
    }
    
    // MARK: - Background Polling
    
    /// Start polling for a specific job
    private func startPolling(for jobId: String) {
        // Cancel existing polling task if any
        stopPolling(for: jobId)
        
        // Start background task to keep polling alive even when app is backgrounded
        var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
        backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "StoryPolling-\(jobId)") {
            // Called if background time expires
            DWLogger.shared.warning("⏰ Background task expired for job: \(jobId) - polling will continue on app resume", category: .story)
            if backgroundTaskId != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskId)
                backgroundTaskId = .invalid
            }
        }
        
        backgroundTasks[jobId] = backgroundTaskId
        DWLogger.shared.info("🔋 Started background task for job: \(jobId)", category: .story)
        
        let task = Task {
            var retryCount = 0
            let maxRetries = 5 // Increased from 3 to handle race conditions better

            while retryCount <= maxRetries {
                do {
                    let story = try await storyService.pollJobStatus(jobId: jobId) { [weak self] progress, statusMessage in
                        guard let self = self else { return }
                        await self.updateJob(jobId: jobId, progress: progress, status: statusMessage)
                    }
                    
                    await self.completeJob(jobId: jobId, story: story)
                    
                    // End background task on completion
                    if let bgTaskId = await self.backgroundTasks[jobId], bgTaskId != .invalid {
                        UIApplication.shared.endBackgroundTask(bgTaskId)
                        await MainActor.run {
                            self.backgroundTasks.removeValue(forKey: jobId)
                        }
                        DWLogger.shared.info("✅ Ended background task for completed job: \(jobId)", category: .story)
                    }
                    return // Success - exit the retry loop
                    
                } catch {
                    // Special case: If this is a temp job (UUID format) and we get "Job not found",
                    // it means the backend completed sync and never created this job
                    let isTempJob = jobId.contains("-") && jobId.count > 30
                    let errorMessage = error.localizedDescription.lowercased()
                    let isJobNotFound = errorMessage.contains("job not found") || errorMessage.contains("not found")

                    if isTempJob && isJobNotFound {
                        DWLogger.shared.warning("🧹 Temp job \(jobId) not found on backend - likely sync generation. Cancelling.", category: .story)
                        await self.cancelJob(jobId: jobId)
                        return // Exit polling - job is cancelled
                    }

                    // Check if it's a transient network error
                    let isTransientError = self.isTransientNetworkError(error)

                    if isTransientError && retryCount < maxRetries {
                        retryCount += 1
                        DWLogger.shared.warning("⚠️ Transient error for job \(jobId), retry \(retryCount)/\(maxRetries): \(error.localizedDescription)", category: .story)

                        // Don't update UI with error status - keep showing generation progress
                        // This prevents the generating card from showing false errors
                        // Just log the retry silently and continue

                        // Wait before retry (progressive backoff: 2s, 3s, 4s, 5s, 6s)
                        let backoffSeconds = min(2 + retryCount, 6)
                        try? await Task.sleep(nanoseconds: UInt64(backoffSeconds) * 1_000_000_000)
                        continue
                    }

                    // Non-transient error or max retries exceeded
                    // Before failing, do one final check if story actually completed in background
                    DWLogger.shared.warning("⚠️ Max retries reached for job \(jobId) - doing final status check before failing", category: .story)

                    do {
                        // Final poll attempt - maybe backend completed successfully
                        let finalStory = try await storyService.pollJobStatus(jobId: jobId) { [weak self] progress, statusMessage in
                            guard let self = self else { return }
                            await self.updateJob(jobId: jobId, progress: progress, status: statusMessage)
                        }

                        // Success! Story was actually completed
                        DWLogger.shared.info("✅ Final check succeeded - story was completed after all!", category: .story)
                        await self.completeJob(jobId: jobId, story: finalStory)

                        if let bgTaskId = await self.backgroundTasks[jobId], bgTaskId != .invalid {
                            UIApplication.shared.endBackgroundTask(bgTaskId)
                            await MainActor.run {
                                self.backgroundTasks.removeValue(forKey: jobId)
                            }
                        }
                        return
                    } catch {
                        // Final check also failed - now we really need to fail the job
                        DWLogger.shared.error("Polling failed for job: \(jobId) after final check", error: error, category: .story)
                        await failJob(jobId: jobId, error: error.localizedDescription)
                    }

                    // End background task on failure
                    if let bgTaskId = await self.backgroundTasks[jobId], bgTaskId != .invalid {
                        UIApplication.shared.endBackgroundTask(bgTaskId)
                        await MainActor.run {
                            self.backgroundTasks.removeValue(forKey: jobId)
                        }
                        DWLogger.shared.info("❌ Ended background task for failed job: \(jobId)", category: .story)
                    }
                    return // Exit the retry loop
                }
            }
        }
        
        pollingTasks[jobId] = task
    }
    
    /// Stop polling for a specific job
    private func stopPolling(for jobId: String) {
        pollingTasks[jobId]?.cancel()
        pollingTasks.removeValue(forKey: jobId)
        
        // End background task if exists
        if let backgroundTaskId = backgroundTasks[jobId], backgroundTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskId)
            backgroundTasks.removeValue(forKey: jobId)
            DWLogger.shared.info("🔋 Ended background task for stopped job: \(jobId)", category: .story)
        }
    }
    
    /// Resume polling for all active jobs (on app launch)
    func resumeAllPolling() {
        // Clean up stale jobs first (older than 24 hours)
        cleanupStaleJobs()

        for job in activeJobs where job.isActive {
            DWLogger.shared.info("Resuming polling for job: \(job.id)", category: .story)
            startPolling(for: job.id)
        }
    }

    /// Clean up stale jobs that are too old
    private func cleanupStaleJobs() {
        let maxAge: TimeInterval = 24 * 60 * 60 // 24 hours
        let now = Date()

        let staleJobs = activeJobs.filter { job in
            let age = now.timeIntervalSince(job.createdAt)
            return age > maxAge
        }

        for job in staleJobs {
            DWLogger.shared.warning("Removing stale job (created \(Int(now.timeIntervalSince(job.createdAt) / 3600)) hours ago): \(job.id)", category: .story)

            // Mark as failed instead of just removing
            Task {
                await failJob(jobId: job.id, error: "Job too old - cleaned up after 24 hours")
            }
        }

        if !staleJobs.isEmpty {
            DWLogger.shared.info("Cleaned up \(staleJobs.count) stale job(s)", category: .story)
        }
    }
    
    // MARK: - Persistence
    
    /// Save jobs to UserDefaults
    private func persistJobs() {
        let encoder = JSONEncoder()
        
        if let activeData = try? encoder.encode(activeJobs) {
            UserDefaults.standard.set(activeData, forKey: "\(GenerationJobState.storageKey).active")
        }
        
        if let completedData = try? encoder.encode(completedJobs) {
            UserDefaults.standard.set(completedData, forKey: "\(GenerationJobState.storageKey).completed")
        }
    }
    
    /// Load jobs from UserDefaults
    private func loadPersistedJobs() {
        let decoder = JSONDecoder()

        if let activeData = UserDefaults.standard.data(forKey: "\(GenerationJobState.storageKey).active"),
           let jobs = try? decoder.decode([GenerationJobState].self, from: activeData) {
            activeJobs = jobs
        }

        if let completedData = UserDefaults.standard.data(forKey: "\(GenerationJobState.storageKey).completed"),
           let jobs = try? decoder.decode([GenerationJobState].self, from: completedData) {
            completedJobs = jobs
        }

        // Clean up orphaned temp jobs (UUID format jobs that weren't cleaned up)
        // These are temporary placeholder jobs that should have been cancelled
        let orphanedCount = activeJobs.count
        activeJobs.removeAll { job in
            // Temp jobs are UUIDs with dashes (e.g., 5B62EFA8-4983-4789-BC1B-B1736F72F47B)
            // Real backend job IDs don't have dashes
            job.id.contains("-") && job.id.count > 30
        }
        if orphanedCount != activeJobs.count {
            DWLogger.shared.info("🧹 Cleaned up \(orphanedCount - activeJobs.count) orphaned temp jobs on startup", category: .story)
            persistJobs()
        }

        // Clean up old completed jobs (older than 7 days)
        cleanupOldJobs()
    }
    
    /// Remove completed jobs older than 7 days
    private func cleanupOldJobs() {
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        completedJobs.removeAll { $0.lastUpdateTime < sevenDaysAgo }
        persistJobs()
    }
    
    /// Clear all jobs (for testing/debugging)
    func clearAllJobs() {
        activeJobs.removeAll()
        completedJobs.removeAll()
        pollingTasks.values.forEach { $0.cancel() }
        pollingTasks.removeAll()
        
        // End all background tasks
        for (jobId, backgroundTaskId) in backgroundTasks where backgroundTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskId)
            DWLogger.shared.info("🔋 Ended background task for cleared job: \(jobId)", category: .app)
        }
        backgroundTasks.removeAll()
        
        persistJobs()

        DWLogger.shared.info("Cleared all jobs", category: .app)
    }
    
    // MARK: - Error Helpers
    
    /// Check if error is a transient network error that can be retried
    private func isTransientNetworkError(_ error: Error) -> Bool {
        // APIError.decodingError can be transient (race conditions during completion)
        if let apiError = error as? APIError {
            switch apiError {
            case .decodingError:
                // This can happen when backend marks job complete but storyId not yet set
                // It's a race condition, not a real error - should retry
                return true
            case .networkError:
                return true
            case .serverError(let code):
                // 5xx errors are usually transient (server overload, temporary issues)
                return code >= 500
            default:
                break
            }
        }

        // URLError cases
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet,
                 .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                return true
            default:
                return false
            }
        }

        // Check error description for common transient patterns
        let description = error.localizedDescription.lowercased()
        let transientPatterns = [
            "connection interrupted",
            "connection was lost",
            "network connection",
            "timed out",
            "timeout",
            "internet connection",
            "veri işleme hatası" // Our decoding error in Turkish
        ]

        return transientPatterns.contains { description.contains($0) }
    }
}

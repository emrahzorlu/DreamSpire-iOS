//
//  StoryStatusService.swift
//  DreamSpire
//
//  Polls backend for real-time story generation status
//  Professional polling implementation with error handling
//

import Foundation
import Combine

@MainActor
class StoryStatusService: ObservableObject {
    @Published var currentStatus: StoryGenerationStatus?
    @Published var isPolling = false
    
    private var pollingTimer: Timer?
    private let pollInterval: TimeInterval = 2.0 // Poll every 2 seconds
    private let maxPollDuration: TimeInterval = 300.0 // 5 minutes max
    private var pollingStartTime: Date?
    
    private let apiService: APIClient
    
    init(apiService: APIClient = .shared) {
        self.apiService = apiService
    }
    
    // MARK: - Start Polling
    
    /// Start polling for story generation status
    /// - Parameter storyId: The story ID to poll for
    func startPolling(storyId: String) {
        guard !isPolling else {
            DWLogger.shared.warning("Already polling for story status", category: .story)
            return
        }
        
        DWLogger.shared.info("Starting status polling for story: \(storyId)", category: .story)
        
        isPolling = true
        pollingStartTime = Date()
        
        // Fetch immediately
        Task {
            await fetchStatus(storyId: storyId)
        }
        
        // Then poll every 2 seconds
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchStatus(storyId: storyId)
            }
        }
    }
    
    // MARK: - Stop Polling
    
    /// Stop polling for status updates
    func stopPolling() {
        guard isPolling else { return }
        
        DWLogger.shared.info("Stopping status polling", category: .story)
        
        pollingTimer?.invalidate()
        pollingTimer = nil
        isPolling = false
        pollingStartTime = nil
    }
    
    // MARK: - Fetch Status
    
    private func fetchStatus(storyId: String) async {
        // Check timeout
        if let startTime = pollingStartTime,
           Date().timeIntervalSince(startTime) > maxPollDuration {
            DWLogger.shared.warning("Polling timeout exceeded (5 minutes)", category: .story)
            stopPolling()
            return
        }
        
        do {
            let response: StoryGenerationStatusResponse = try await apiService.makeRequest(
                endpoint: "/stories/\(storyId)/status",
                method: .get,
                requiresAuth: true
            )
            
            currentStatus = response.status
            
            // Stop polling if completed or failed
            if response.status.isCompleted || response.status.isFailed {
                DWLogger.shared.info("Story generation \(response.status.step.rawValue)", category: .story)
                stopPolling()
            }
            
        } catch {
            DWLogger.shared.error("Failed to fetch story status", error: error, category: .story)
            
            // Don't stop polling on network errors, just log and continue
            // Only stop if it's a 404 (story not found) or 403 (unauthorized)
            if let apiError = error as? APIError {
                switch apiError {
                case .serverError(404), .unauthorized:
                    stopPolling()
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - Manual Fetch
    
    /// Fetch status once without polling
    func fetchOnce(storyId: String) async throws -> StoryGenerationStatus {
        let response: StoryGenerationStatusResponse = try await apiService.makeRequest(
            endpoint: "/stories/\(storyId)/status",
            method: .get,
            requiresAuth: true
        )
        
        currentStatus = response.status
        return response.status
    }
    
    // MARK: - Cleanup
    
    deinit {
        Task { @MainActor in
            stopPolling()
        }
    }
}

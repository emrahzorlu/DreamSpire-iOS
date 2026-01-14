//
//  StoryPrefetchManager.swift
//  DreamSpire
//
//  Intelligent story prefetching for instant story loading
//  Professional-grade caching with scroll-aware prefetching
//

import Foundation
import Combine

/// Story source type for prefetching
enum PrefetchStoryType {
    case prewritten
    case user
}

/// Manages intelligent prefetching of full story content
/// Uses a hybrid strategy: eager prefetch for visible items + scroll-based prefetch for upcoming items
@MainActor
final class StoryPrefetchManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = StoryPrefetchManager()
    
    // MARK: - Cache
    
    /// In-memory cache of full stories (id -> Story)
    private var fullStoryCache: [String: Story] = [:]
    
    /// Stories currently being fetched (to avoid duplicate requests)
    private var activeFetches: Set<String> = []
    
    /// Prefetch queue (FIFO)
    private var prefetchQueue: [String] = []
    
    /// Maximum concurrent prefetch operations
    private let maxConcurrentFetches = 1
    
    /// Current number of active fetches
    private var currentFetchCount = 0
    
    // MARK: - Dependencies
    
    private let prewrittenService = PrewrittenService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        DWLogger.shared.info("StoryPrefetchManager initialized", category: .story)
        setupLanguageObserver()
    }
    
    private func setupLanguageObserver() {
        NotificationCenter.default.publisher(for: .languageChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DWLogger.shared.info("🌍 Language changed, clearing prefetch cache", category: .story)
                self?.clearCache()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public API
    
    /// Check if a full story is already cached
    func hasCachedStory(id: String) -> Bool {
        return fullStoryCache[id] != nil
    }
    
    /// Get a cached full story (nil if not cached)
    func getCachedStory(id: String) -> Story? {
        if let story = fullStoryCache[id] {
            DWLogger.shared.debug("✅ Cache hit for story: \(id)", category: .story)
            return story
        }
        return nil
    }
    
    /// Get a full story - returns from cache if available, otherwise fetches
    func getFullStory(id: String, isPrewritten: Bool) async throws -> Story {
        // Check cache first
        if let cached = fullStoryCache[id] {
            DWLogger.shared.debug("✅ Returning cached story: \(id)", category: .story)
            return cached
        }
        
        // Not cached, fetch it
        DWLogger.shared.info("🌐 Fetching full story on-demand: \(id)", category: .story)
        
        let story: Story
        if isPrewritten {
            story = try await prewrittenService.getPrewrittenStory(id: id)
        } else {
            story = try await StoryService.shared.getStory(id: id)
        }
        
        // Cache it
        fullStoryCache[id] = story
        
        return story
    }
    
    /// Request prefetch for a list of story IDs (non-blocking)
    /// Called when scroll position changes or new content is loaded
    func requestPrefetch(storyIds: [String], isPrewritten: Bool = true) {
        // Filter out already cached and currently fetching
        let newIds = storyIds.filter { id in
            !fullStoryCache.keys.contains(id) && !activeFetches.contains(id) && !prefetchQueue.contains(id)
        }
        
        guard !newIds.isEmpty else { return }
        
        DWLogger.shared.debug("📥 Queueing \(newIds.count) stories for prefetch", category: .story)
        
        // Add to queue
        prefetchQueue.append(contentsOf: newIds)
        
        // Process queue
        processPrefetchQueue(isPrewritten: isPrewritten)
    }
    
    /// Prefetch visible stories immediately (higher priority)
    func prefetchVisibleStories(_ stories: [Story]) {
        let idsToFetch = stories
            .filter { !$0.isSummary || !fullStoryCache.keys.contains($0.id) }
            .prefix(5) // Limit to first 5 visible
            .map { $0.id }
        
        guard !idsToFetch.isEmpty else { return }
        
        // Insert at front of queue (higher priority)
        let newIds = idsToFetch.filter { id in
            !fullStoryCache.keys.contains(id) && !activeFetches.contains(id)
        }
        
        prefetchQueue.insert(contentsOf: newIds, at: 0)
        processPrefetchQueue(isPrewritten: true)
    }
    
    /// Clear all cached stories
    func clearCache() {
        DWLogger.shared.info("🗑️ Clearing story prefetch cache", category: .story)
        fullStoryCache.removeAll()
        prefetchQueue.removeAll()
    }
    
    /// Get cache statistics
    var cacheStats: (count: Int, queueSize: Int, activeFetches: Int) {
        return (fullStoryCache.count, prefetchQueue.count, currentFetchCount)
    }
    
    // MARK: - Private Methods
    
    private func processPrefetchQueue(isPrewritten: Bool) {
        // Don't exceed max concurrent fetches
        guard currentFetchCount < maxConcurrentFetches else { return }
        guard !prefetchQueue.isEmpty else { return }
        
        // Take next item from queue
        let storyId = prefetchQueue.removeFirst()
        
        // Skip if already cached or fetching
        guard !fullStoryCache.keys.contains(storyId), !activeFetches.contains(storyId) else {
            processPrefetchQueue(isPrewritten: isPrewritten) // Try next
            return
        }
        
        // Mark as fetching
        activeFetches.insert(storyId)
        currentFetchCount += 1
        
        // Fetch in background
        Task.detached(priority: .background) { [weak self] in
            defer {
                Task { @MainActor in
                    self?.activeFetches.remove(storyId)
                    self?.currentFetchCount -= 1
                    // Process next in queue
                    self?.processPrefetchQueue(isPrewritten: isPrewritten)
                }
            }
            
            do {
                // PERFORMANCE: Add small delay between background prefetches to avoid congestion
                try? await Task.sleep(nanoseconds: 800_000_000) // 800ms
                
                let story: Story
                if isPrewritten {
                    story = try await PrewrittenService.shared.getPrewrittenStory(id: storyId)
                } else {
                    story = try await StoryService.shared.getStory(id: storyId)
                }
                
                await MainActor.run {
                    self?.fullStoryCache[storyId] = story
                    DWLogger.shared.debug("✅ Prefetched story: \(storyId)", category: .story)
                }
            } catch {
                DWLogger.shared.debug("⚠️ Prefetch failed for \(storyId): \(error.localizedDescription)", category: .story)
            }
        }
        
        // Continue processing if slots available
        if currentFetchCount < maxConcurrentFetches && !prefetchQueue.isEmpty {
            processPrefetchQueue(isPrewritten: isPrewritten)
        }
    }
}

// MARK: - Scroll Position Tracking

extension StoryPrefetchManager {
    
    /// Called when user scrolls in a story list
    /// Prefetches stories that are about to become visible
    func onScrollPositionChanged(visibleStoryIds: [String], allStories: [Story], isPrewritten: Bool = true) {
        guard let lastVisibleId = visibleStoryIds.last,
              let lastVisibleIndex = allStories.firstIndex(where: { $0.id == lastVisibleId }) else {
            return
        }
        
        // Prefetch next 5 stories after the last visible one
        let startIndex = min(lastVisibleIndex + 1, allStories.count)
        let endIndex = min(startIndex + 5, allStories.count)
        
        guard startIndex < endIndex else { return }
        
        let upcomingIds = allStories[startIndex..<endIndex].map { $0.id }
        requestPrefetch(storyIds: Array(upcomingIds), isPrewritten: isPrewritten)
    }
}

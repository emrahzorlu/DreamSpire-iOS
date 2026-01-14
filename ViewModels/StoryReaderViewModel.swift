//
//  StoryReaderViewModel.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//

import SwiftUI
import AVFoundation
import Combine
import SDWebImageSwiftUI
import SDWebImage

@MainActor
class StoryReaderViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var story: Story
    @Published var currentPageIndex: Int = 0
        
    // Audio
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var playbackSpeed: Float = 1.0
    
    // Reading settings
    @Published var fontSize: CGFloat = 18
    @Published var isDarkMode: Bool = false
    
    // State
    @Published var isLoading = false
    @Published var error: String?
    
    // MARK: - Dependencies
    
    private let storyService = StoryService.shared
    private let prewrittenService = PrewrittenService.shared
    private let userRepository = UserStoryRepository.shared
    private var audioPlayer: AVPlayer?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(story: Story) {
        self.story = story

        // PERFORMANCE: If summary story or no pages, we ARE loading
        self.isLoading = story.isSummary || story.pages.isEmpty

        DWLogger.shared.info("StoryReaderViewModel initialized for: \(story.title) (Loading: \(isLoading))", category: .story)
        DWLogger.shared.logAnalyticsEvent("story_reader_opened", parameters: [
            "story_id": story.id,
            "has_audio": story.audioUrl != nil,
            "is_illustrated": story.isIllustrated,
            "is_summary": story.isSummary,
            "initial_pages": story.pages.count
        ])

        // Handle audio setup
        if let audioUrl = story.audioUrl {
            setupAudioPlayer(url: audioUrl)
        }

        setupNotifications()
        setupLanguageObserver()

        // PERFORMANCE: If summary story, fetch details
        if isLoading {
            Task {
                await fetchFullStory()
            }
        } else {
            // Already full story, prefetch images immediately
            prefetchImages()
        }
    }
    
    private func fetchFullStory() async {
        // PERFORMANCE: Check prefetch cache first for instant loading
        let prefetchManager = StoryPrefetchManager.shared
        
        if let cachedStory = prefetchManager.getCachedStory(id: story.id) {
            DWLogger.shared.info("⚡ Instant load from prefetch cache: \(story.id)", category: .story)
            story = cachedStory
            isLoading = false // CRITICAL: Stop loading state
            prefetchImages()
            
            // Re-setup audio if needed
            if audioPlayer == nil, let audioUrl = cachedStory.audioUrl {
                setupAudioPlayer(url: audioUrl)
            }
            return
        }
        
        // Not in cache, fetch from network
        isLoading = true
        DWLogger.shared.info("📖 Fetching full story from network: \(story.id) (type: \(story.type))", category: .story)
        
        do {
            let isPrewritten = (story.type == .prewritten)
            let fullStory = try await prefetchManager.getFullStory(id: story.id, isPrewritten: isPrewritten)
            
            story = fullStory
            isLoading = false
            
            // Now prefetch images for the full story
            prefetchImages()
            
            // Re-setup audio if needed (in case summary didn't have URL but full does)
            if audioPlayer == nil, let audioUrl = fullStory.audioUrl {
                setupAudioPlayer(url: audioUrl)
            }
            
            DWLogger.shared.info("✅ Full story loaded for reader: \(fullStory.pages.count) pages", category: .story)
        } catch {
            self.error = "Hikaye detayları yüklenemedi"
            isLoading = false
            DWLogger.shared.error("❌ Failed to fetch full story for reader", error: error, category: .story)
        }
    }
    
    private func prefetchImages() {
        guard story.isIllustrated, let illustrations = story.illustrations else { return }
        
        let urls = illustrations.compactMap { URL(string: $0.imageUrl) }
        guard !urls.isEmpty else { return }
        
        DWLogger.shared.info("🖼️ Prefetching \(urls.count) images for illustrated story", category: .story)
        
        SDWebImagePrefetcher.shared.prefetchURLs(urls, progress: { (completedCount: UInt, totalCount: UInt) in
            DWLogger.shared.debug("✅ Image prefetch progress: \(completedCount)/\(totalCount)", category: .story)
        }, completed: { (completedCount: UInt, skippedCount: UInt) in
            DWLogger.shared.info("🏁 Image prefetching finished: \(completedCount) completed, \(skippedCount) skipped", category: .story)
        })
    }
    
    deinit {
        // Clean up synchronously - no @MainActor calls
        if let observer = timeObserver {
            audioPlayer?.removeTimeObserver(observer)
            timeObserver = nil
        }
        audioPlayer?.pause()
        audioPlayer = nil
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Audio Setup
    
    private func setupAudioPlayer(url: String) {
        guard let audioURL = URL(string: url) else {
            DWLogger.shared.error("Invalid audio URL: \(url)", category: .audio)
            return
        }
        
        DWLogger.shared.info("Setting up audio player", category: .audio)
        
        audioPlayer = AVPlayer(url: audioURL)
        audioPlayer?.pause() // Ensure player doesn't start automatically
        audioPlayer?.rate = 0 // CRITICAL: Set rate to 0, not playbackSpeed - prevents auto-start
        audioPlayer?.automaticallyWaitsToMinimizeStalling = false // Prevent buffering auto-play
        
        // Observe playback time
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = audioPlayer?.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            self?.currentTime = time.seconds
        }
        
        // Get duration
        Task {
            if let duration = try? await audioPlayer?.currentItem?.asset.load(.duration) {
                self.duration = duration.seconds
                DWLogger.shared.debug("Audio duration: \(duration.seconds)s", category: .audio)
            }
        }
        
        // Observe playback completion
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: audioPlayer?.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.audioDidFinish()
        }
    }
    
    private func setupNotifications() {
        // App going to background - pause audio
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if self?.isPlaying == true {
                self?.pauseAudio()
            }
        }
    }
    
    private func setupLanguageObserver() {
        // Only observe language changes for prewritten stories
        guard story.type == .prewritten else { return }
        
        NotificationCenter.default.publisher(for: .languageChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.reloadStoryForLanguageChange()
                }
            }
            .store(in: &cancellables)
    }
    
    private func reloadStoryForLanguageChange() async {
        // Pause audio if playing
        if isPlaying {
            pauseAudio()
        }
        
        // Reload story in new language
        do {
            let updatedStory = try await prewrittenService.getPrewrittenStory(id: story.id)
            
            // Update story content
            story = updatedStory
            
            // Reset to first page
            currentPageIndex = 0
            
            // Setup new audio player if audio URL changed
            if let newAudioUrl = updatedStory.audioUrl {
                // Clean up old player
                if let observer = timeObserver {
                    audioPlayer?.removeTimeObserver(observer)
                    timeObserver = nil
                }
                audioPlayer?.pause()
                audioPlayer = nil
                
                // Setup new player
                setupAudioPlayer(url: newAudioUrl)
            }
            
            DWLogger.shared.info("Story reloaded for language change: \(updatedStory.title)", category: .story)
        } catch {
            DWLogger.shared.error("Failed to reload story for language change", error: error, category: .story)
        }
    }
    
    // MARK: - Audio Controls
    
    func toggleAudio() {
        guard let player = audioPlayer else {
            error = "Ses dosyası yüklenemedi"
            return
        }
        
        if isPlaying {
            pauseAudio()
        } else {
            playAudio()
        }
    }
    
    // Start audio automatically (for when switching to audio mode)
    func startAudioAutomatically() {
        guard audioPlayer != nil, !isPlaying else { return }
        
        // REQUIREMENT: Start playing after 1 second delay when mode switches
        DWLogger.shared.debug("⏳ Delaying audio start by 1s as requested", category: .audio)
        
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Check if still not playing (user might have closed or toggled)
            if !self.isPlaying {
                self.playAudio()
            }
        }
    }
    
    private func playAudio() {
        // Configure audio session to bypass silent mode
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            DWLogger.shared.error("Failed to configure audio session", error: error, category: .audio)
        }
        
        // Set playback speed before playing (rate was 0 during setup to prevent auto-start)
        audioPlayer?.rate = playbackSpeed
        audioPlayer?.play()
        isPlaying = true
        
        DWLogger.shared.logAnalyticsEvent(Constants.Analytics.audioPlayed, parameters: [
            "story_id": story.id,
            "page": currentPageIndex
        ])
    }
    
    private func pauseAudio() {
        audioPlayer?.pause()
        isPlaying = false
    }
    
    func seekAudio(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        audioPlayer?.seek(to: cmTime)
        
        DWLogger.shared.debug("Audio seeked to: \(time)s", category: .audio)
    }
    
    func changePlaybackSpeed(_ speed: Float) {
        playbackSpeed = speed
        audioPlayer?.rate = isPlaying ? speed : 0
        
        DWLogger.shared.debug("Playback speed changed to: \(speed)x", category: .audio)
        DWLogger.shared.logUserAction("Changed Playback Speed", details: "\(speed)x")
    }
    
    private func audioDidFinish() {
        isPlaying = false
        currentTime = 0
        audioPlayer?.seek(to: .zero)
        
        DWLogger.shared.info("Audio playback completed", category: .audio)
        DWLogger.shared.logAnalyticsEvent("audio_completed", parameters: [
            "story_id": story.id
        ])
    }
    
    // MARK: - Page Navigation
    
    var currentPage: StoryPage? {
        guard currentPageIndex >= 0 && currentPageIndex < story.pages.count else {
            return nil
        }
        return story.pages[currentPageIndex]
    }
    
    /// Get illustration for current page (if story is illustrated)
    var illustrationForCurrentPage: Illustration? {
        guard story.isIllustrated,
              let illustrations = story.illustrations,
              let currentPage = currentPage else {
            return nil
        }
        
        return illustrations.first { $0.pageNumber == currentPage.pageNumber }
    }
    
    var hasNextPage: Bool {
        currentPageIndex < story.pages.count - 1
    }
    
    var hasPreviousPage: Bool {
        currentPageIndex > 0
    }
    
    func goToNextPage() {
        guard hasNextPage else { return }
        
        currentPageIndex += 1
        DWLogger.shared.debug("Navigated to page: \(currentPageIndex + 1)/\(story.pages.count)", category: .ui)
        
        DWLogger.shared.logUserAction("Next Page", details: "Page \(currentPageIndex + 1)")
    }
    
    func goToPreviousPage() {
        guard hasPreviousPage else { return }
        
        currentPageIndex -= 1
        DWLogger.shared.debug("Navigated to page: \(currentPageIndex + 1)/\(story.pages.count)", category: .ui)
        
        DWLogger.shared.logUserAction("Previous Page", details: "Page \(currentPageIndex + 1)")
    }
    
    func goToPage(_ index: Int) {
        guard index >= 0 && index < story.pages.count else { return }
        
        currentPageIndex = index
        DWLogger.shared.debug("Jumped to page: \(index + 1)", category: .ui)
    }
    
    // MARK: - Reading Settings
    
    func increaseFontSize() {
        fontSize = min(fontSize + 2, 28)
        DWLogger.shared.logUserAction("Increase Font Size", details: "\(fontSize)pt")
    }
    
    func decreaseFontSize() {
        fontSize = max(fontSize - 2, 14)
        DWLogger.shared.logUserAction("Decrease Font Size", details: "\(fontSize)pt")
    }
    
    func toggleDarkMode() {
        isDarkMode.toggle()
        DWLogger.shared.logUserAction("Toggle Dark Mode", details: isDarkMode ? "On" : "Off")
    }
    
    // MARK: - Reading Progress
    
    var readingProgress: Double {
        guard !story.pages.isEmpty else { return 0 }
        return Double(currentPageIndex + 1) / Double(story.pages.count)
    }
    
    func markAsCompleted() {
        DWLogger.shared.logAnalyticsEvent("story_completed", parameters: [
            "story_id": story.id,
            "pages_read": story.pages.count,
            "completion_rate": 1.0
        ])
    }
}

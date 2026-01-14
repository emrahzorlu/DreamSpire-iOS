//
//  TemplateRepository.swift
//  DreamSpire
//
//  Professional template repository with intelligent caching
//

import Foundation
import Combine

/// Centralized repository for templates with intelligent caching
@MainActor
final class TemplateRepository: ObservableObject {

    // MARK: - Singleton

    static let shared = TemplateRepository()

    // MARK: - Published Properties

    /// All cached templates
    @Published private(set) var templates: [Template] = []

    /// Loading state
    @Published private(set) var isLoading = false

    /// Error state
    @Published private(set) var error: Error?

    // MARK: - Cache Management

    /// Memory cache
    private var cache: [Template]?

    /// Cache timestamp
    private var cacheTimestamp: Date?

    /// Cache duration (5 minutes)
    private let cacheDuration: TimeInterval = 5 * 60

    /// Active fetch task to prevent duplicate requests
    private var activeFetchTask: Task<[Template], Error>?

    // MARK: - Dependencies

    private let templateService = TemplateService.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        DWLogger.shared.info("TemplateRepository initialized", category: .ui)
        setupLanguageObserver()
    }

    // MARK: - Language Observer

    private func setupLanguageObserver() {
        NotificationCenter.default.publisher(for: .languageChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }

                DWLogger.shared.info("Language changed, clearing template cache", category: .ui)

                // Clear cache on language change
                Task {
                    _ = try? await self.getTemplates(forceRefresh: true)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public API

    /// Get templates with intelligent caching
    /// - Parameter forceRefresh: Skip cache and fetch fresh data
    /// - Returns: Array of templates
    func getTemplates(forceRefresh: Bool = false) async throws -> [Template] {
        // Check if cache is valid and not forcing refresh
        if !forceRefresh, let cached = getCachedTemplates() {
            DWLogger.shared.debug("✅ Using cached templates: \(cached.count) templates", category: .ui)

            // Update published properties
            self.templates = cached

            return cached
        }

        // Check if there's already an active fetch
        if let existingTask = activeFetchTask {
            DWLogger.shared.debug("⏳ Joining existing fetch task for templates", category: .ui)
            return try await existingTask.value
        }

        // Create new fetch task
        let fetchTask = Task<[Template], Error> {
            DWLogger.shared.info("🌐 Fetching templates from backend", category: .ui)

            self.isLoading = true
            self.error = nil

            do {
                let fetchedTemplates = try await templateService.getAllTemplates()

                // Update cache
                self.cache = fetchedTemplates
                self.cacheTimestamp = Date()

                // Update published properties
                self.templates = fetchedTemplates
                self.isLoading = false

                DWLogger.shared.info("✅ Templates cached: \(fetchedTemplates.count)", category: .ui)

                return fetchedTemplates

            } catch {
                self.error = error
                self.isLoading = false
                DWLogger.shared.error("❌ Failed to fetch templates", error: error, category: .ui)
                throw error
            }
        }

        // Store active task
        activeFetchTask = fetchTask

        defer {
            // Clean up task after completion
            activeFetchTask = nil
        }

        return try await fetchTask.value
    }

    /// Force refresh - clears cache and fetches fresh data
    func refresh() async throws -> [Template] {
        DWLogger.shared.info("🔄 Force refreshing templates", category: .ui)

        // Clear cache
        cache = nil
        cacheTimestamp = nil

        return try await getTemplates(forceRefresh: true)
    }

    /// Clear all cache
    func clearCache() {
        DWLogger.shared.info("🗑️ Clearing template cache", category: .ui)
        cache = nil
        cacheTimestamp = nil
        templates = []
    }

    // MARK: - Cache Helpers

    /// Get cached templates if still valid
    private func getCachedTemplates() -> [Template]? {
        guard let cached = cache,
              let timestamp = cacheTimestamp else {
            return nil
        }

        let age = Date().timeIntervalSince(timestamp)

        if age < cacheDuration {
            DWLogger.shared.debug("✅ Cache valid (age: \(Int(age))s / \(Int(cacheDuration))s)", category: .ui)
            return cached
        } else {
            DWLogger.shared.debug("⏰ Cache expired (age: \(Int(age))s)", category: .ui)
            return nil
        }
    }

    /// Check if cache is valid
    func isCacheValid() -> Bool {
        return getCachedTemplates() != nil
    }

    /// Get cache age in seconds
    func getCacheAge() -> TimeInterval? {
        guard let timestamp = cacheTimestamp else {
            return nil
        }
        return Date().timeIntervalSince(timestamp)
    }
}

// MARK: - Filtering Helpers

extension TemplateRepository {

    /// Get templates by category
    func getTemplatesByCategory(_ category: TemplateCategory) -> [Template] {
        templates.filter { $0.category == category }
    }

    /// Get templates by tier
    func getTemplatesByTier(_ tier: SubscriptionTier) -> [Template] {
        templates.filter { $0.tier == tier }
    }
}

// MARK: - Statistics

extension TemplateRepository {

    /// Total number of cached templates
    var cachedCount: Int {
        cache?.count ?? 0
    }

    /// Cache statistics for debugging
    var cacheStats: String {
        """
        📊 Template Cache Stats:
        - Current Templates: \(templates.count)
        - Cached: \(cachedCount) templates
        - Cache Age: \(getCacheAge().map { "\(Int($0))s" } ?? "N/A")
        - Cache Valid: \(isCacheValid())
        """
    }
}

//
//  TemplateViewModel.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025-11-02
//  Refactored with Repository Pattern for optimal performance
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class TemplateViewModel: ObservableObject {
    // MARK: - Singleton

    static let shared = TemplateViewModel()

    // MARK: - Published Properties

    @Published var templates: [Template] = []
    @Published var filteredTemplates: [Template] = []
    @Published var selectedCategory: String = "filter_all".localized
    @Published var isLoading = true
    @Published var isRefreshing = false  // For language change overlay
    @Published var error: String?

    // MARK: - Dependencies (Repository Pattern)

    private let templateRepository = TemplateRepository.shared
    private let subscriptionService = SubscriptionService.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Localized Category Filters

    var categoryFilters: [String] {
        [
            "filter_all".localized,
            "category_bedtime".localized,
            "category_adventure".localized,
            "category_family".localized,
            "category_friendship".localized,
            "category_fantasy".localized,
            "category_animals".localized,
            "category_princess".localized,
            "category_classic".localized
        ]
    }

    // MARK: - Initialization

    private init() {
        DWLogger.shared.info("TemplateViewModel initialized", category: .ui)

        // Listen for language changes
        NotificationCenter.default.publisher(for: .languageChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }

                // Show skeleton overlay during language change
                self.isRefreshing = true

                Task {
                    await self.loadTemplates()

                    // Hide skeleton overlay
                    await MainActor.run {
                        self.isRefreshing = false
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Load Templates (Using Repository - Auto Cached!)

    func loadTemplates() async {
        DWLogger.shared.info("Loading templates", category: .api)

        // Only show loading if we don't have templates yet
        // This prevents cards from disappearing during language change
        if templates.isEmpty {
            isLoading = true
        }
        error = nil

        do {
            // Repository automatically handles caching!
            let newTemplates = try await templateRepository.getTemplates(forceRefresh: false)

            // Update templates with smooth transition
            templates = newTemplates
            filteredTemplates = newTemplates

            DWLogger.shared.debug("✅ [TemplateViewModel] Templates loaded: \(templates.count)", category: .api)

        } catch {
            self.error = "Şablonlar yüklenemedi: \(error.localizedDescription)"
            DWLogger.shared.error("Failed to load templates", error: error, category: .api)
        }

        isLoading = false
    }
    
    // MARK: - Filtering
    
    func filterByCategory(_ category: String) {
        selectedCategory = category
        
        // Check if "All" category (in any language)
        if category == "filter_all".localized || category == "Tümü" || category == "All" {
            filteredTemplates = templates
        } else {
            // Map category names to TemplateCategory enum
            var categoryMap: [String: TemplateCategory] = [:]
            
            // Add localized keys
            categoryMap["category_bedtime".localized] = .uyku
            categoryMap["category_adventure".localized] = .macera
            categoryMap["category_family".localized] = .aile
            categoryMap["category_friendship".localized] = .dostluk
            categoryMap["category_fantasy".localized] = .fantastik
            categoryMap["category_animals".localized] = .hayvanlar
            categoryMap["category_princess".localized] = .prenses
            categoryMap["category_classic".localized] = .klasik
            
            if let templateCategory = categoryMap[category] {
                filteredTemplates = templates.filter { $0.category == templateCategory }
            } else {
                filteredTemplates = templates.filter { template in
                    template.fixedParams.genre.lowercased() == category.lowercased()
                }
            }
        }
        
        DWLogger.shared.logUserAction("Filter Templates", details: category)
        DWLogger.shared.debug("Filtered templates: \(filteredTemplates.count)/\(templates.count)", category: .ui)
    }
    
    // MARK: - Search
    
    func searchTemplates(query: String) {
        if query.isEmpty {
            filterByCategory(selectedCategory)
            return
        }
        
        let searchQuery = query.lowercased()
        filteredTemplates = templates.filter { template in
            template.title.lowercased().contains(searchQuery) ||
            template.description.lowercased().contains(searchQuery) ||
            template.fixedParams.genre.lowercased().contains(searchQuery)
        }
        
        DWLogger.shared.logUserAction("Search Templates", details: query)
    }
    
    // MARK: - Access Control
    
    func canAccessTemplate(_ template: Template) -> Bool {
        let currentTierLevel = tierLevel(subscriptionService.currentTier)
        let requiredTierLevel = tierLevel(template.tier)
        
        return currentTierLevel >= requiredTierLevel
    }
    
    private func tierLevel(_ tier: SubscriptionTier) -> Int {
        switch tier {
        case .free: return 0
        case .plus: return 1
        case .pro: return 2
        }
    }
    
    // MARK: - Template Selection
    
    func templateSelected(_ template: Template) {
        DWLogger.shared.logUserAction("Template Selected", details: template.title)
        DWLogger.shared.logAnalyticsEvent("template_viewed", parameters: [
            "template_id": template.id,
            "template_category": template.category.rawValue,
            "template_tier": template.tier.rawValue,
            "can_access": canAccessTemplate(template)
        ])
    }
    
    // MARK: - Statistics
    
    var totalTemplates: Int {
        templates.count
    }
    
    var freeTemplates: Int {
        templates.filter { $0.tier == .free }.count
    }
    
    var plusTemplates: Int {
        templates.filter { $0.tier == .plus }.count
    }
    
    var proTemplates: Int {
        templates.filter { $0.tier == .pro }.count
    }
    
    var accessibleTemplates: Int {
        templates.filter { canAccessTemplate($0) }.count
    }
    
    // MARK: - Sorting
    
    enum SortOption {
        case popular // By usage count
        case newest
        case alphabetical
    }
    
    func sortTemplates(by option: SortOption) {
        switch option {
        case .popular:
            filteredTemplates.sort { 
                ($0.usageCount ?? 0) > ($1.usageCount ?? 0)
            }
        case .newest:
            // Assuming templates have creation dates (not in current model)
            // For now, sort by ID (newer IDs = newer templates)
            filteredTemplates.sort { $0.id > $1.id }
        case .alphabetical:
            filteredTemplates.sort { $0.title < $1.title }
        }
        
        DWLogger.shared.logUserAction("Sort Templates", details: "\(option)")
    }
    
    // MARK: - Recommendations
    
    func getRecommendedTemplates(for tier: SubscriptionTier) -> [Template] {
        templates.filter { template in
            let templateTierLevel = tierLevel(template.tier)
            let userTierLevel = tierLevel(tier)
            
            // Recommend templates at user's tier or one tier above
            return templateTierLevel >= userTierLevel && templateTierLevel <= userTierLevel + 1
        }
    }
}

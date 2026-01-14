//
//  PrewrittenLibraryView.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025-11-03
//

import SwiftUI
import SDWebImageSwiftUI

struct PrewrittenLibraryView: View {
    @ObservedObject private var viewModel = PrewrittenViewModel.shared
    @Environment(\.dismiss) var dismiss
    @State private var showingStoryReader = false
    @State private var selectedStory: Story?
    @State private var showFilterSheet = false
    @State private var showingPaywall = false
    @State private var favoriteIds: Set<String> = []
    @State private var togglingIds: Set<String> = []

    // PERFORMANCE OPTIMIZATION: Support preloaded stories to avoid redundant API calls
    let preloadedStories: [Story]?
    // Initial category filter (e.g., "animals", "adventure") - English tag format
    let initialCategory: String?

    init(preloadedStories: [Story]? = nil, initialCategory: String? = nil) {
        self.preloadedStories = preloadedStories
        self.initialCategory = initialCategory
    }

    var body: some View {
        ZStack {
            LinearGradient.dwBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Active Filters Indicator
                if hasActiveFilters {
                    activeFiltersView
                }
                
                // Stories Grid
                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.error {
                    errorView(error)
                } else if viewModel.filteredStories.isEmpty {
                    emptyStateView
                } else {
                    storiesGridView
                }
            }
        }
        .fullScreenCover(item: $selectedStory) { story in
            StoryReaderView(story: story)
        }
        .fullScreenCover(isPresented: $showingPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showFilterSheet) {
            FilterSheetView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            Task {
                await loadFavorites()
                // IMPORTANT: Always load fresh stories with tier-based shuffle
                // Even if preloaded, we need to apply smart shuffle for better UX
                await viewModel.loadPrewrittenStories()
                
                // Apply initial category filter if provided (e.g., from Home "See All" buttons)
                if let category = initialCategory {
                    // Find the localized category name from the English tag
                    let localizedCategory = viewModel.categoryToTagMapping.first { $0.value == category }?.key
                    if let localizedCategory = localizedCategory {
                        viewModel.filterByCategory(localizedCategory)
                    }
                }
            }
        }
        .preferredColorScheme(.light)
    }
    
    // MARK: - Favorites Methods
    
    private func loadFavorites() async {
        do {
            let favorites = try await FavoriteManager.shared.getFavorites()
            await MainActor.run {
                self.favoriteIds = Set(favorites.map { $0.id })
            }
        } catch {
            DWLogger.shared.error("Failed to load favorites in PrewrittenLibraryView", error: error, category: .story)
        }
    }
    
    private func toggleFavorite(_ storyId: String) async {
        guard !togglingIds.contains(storyId) else { return }
        
        await MainActor.run {
            togglingIds.insert(storyId)
        }
        
        do {
            let newState = try await FavoriteManager.shared.toggleFavorite(storyId: storyId)
            
            // Update local state immediately
            await MainActor.run {
                if newState {
                    favoriteIds.insert(storyId)
                } else {
                    favoriteIds.remove(storyId)
                }
                togglingIds.remove(storyId)
            }
            
            // Refresh from backend for consistency
            await loadFavorites()

            // Notify UserLibraryView to refresh FavoriteStore
            await MainActor.run {
                NotificationCenter.default.post(name: .favoriteToggledFromPrewritten, object: nil)
            }

            DWLogger.shared.logUserAction("Toggle Favorite from Prewritten Library")
        } catch {
            await MainActor.run {
                togglingIds.remove(storyId)
            }
            DWLogger.shared.error("Failed to toggle favorite", error: error, category: .story)
        }
    }
    
    // MARK: - Has Active Filters
    
    private var hasActiveFilters: Bool {
        viewModel.selectedCategory != "filter_all".localized || 
        viewModel.selectedTier != nil ||
        viewModel.isIllustratedOnly
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark") 
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.white.opacity(0.2)))
            }
            
            Spacer()
            
            Text("prewritten_title".localized)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            // Filter Button
            Button(action: { showFilterSheet = true }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                    
                    // Active filter indicator
                    if hasActiveFilters {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 10, height: 10)
                            .offset(x: 2, y: -2)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
    
    // MARK: - Active Filters View
    
    private var activeFiltersView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Category filter chip
                if viewModel.selectedCategory != "filter_all".localized {
                    ActiveFilterChip(
                        title: viewModel.selectedCategory,
                        icon: "folder",
                        onRemove: { viewModel.filterByCategory("filter_all".localized) }
                    )
                }
                
                // Tier filter chip
                if let tier = viewModel.selectedTier {
                    ActiveFilterChip(
                        title: tier.displayName,
                        icon: "crown",
                        onRemove: { viewModel.filterByTier(nil) }
                    )
                }

                // Illustrated filter chip
                if viewModel.isIllustratedOnly {
                    ActiveFilterChip(
                        title: "filter_illustrated_only".localized,
                        icon: "photo.artframe",
                        onRemove: { viewModel.isIllustratedOnly = false }
                    )
                }
                
                // Clear all button
                if hasActiveFilters {
                    Button(action: {
                        viewModel.clearFilters()
                    }) {
                        Text("filter_clear".localized)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 12)
    }
    
    // MARK: - Stories Grid
    
    private var storiesGridView: some View {
        ScrollView(showsIndicators: false) {
            // Results count
            HStack {
                Text(String(format: "stories_count".localized, viewModel.filteredStories.count))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: 16
            ) {
                ForEach(viewModel.filteredStories) { story in
                    PrewrittenStoryCard(
                        story: story,
                        isLocked: !viewModel.canAccessStory(story),
                        isFavorite: favoriteIds.contains(story.id),
                        isToggling: togglingIds.contains(story.id),
                        action: {
                            if viewModel.canAccessStory(story) {
                                selectedStory = story
                            } else {
                                // Show paywall
                                DWLogger.shared.logUserAction("Paywall Triggered", details: "Prewritten Story - \(story.title)")
                                DWLogger.shared.logAnalyticsEvent("paywall_triggered", parameters: [
                                    "source": "prewritten_story_locked",
                                    "story_id": story.id,
                                    "story_tier": story.metadata?.tier ?? "unknown"
                                ])
                                showingPaywall = true
                            }
                        },
                        onToggleFavorite: {
                            Task {
                                await toggleFavorite(story.id)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Loading View

    private var loadingView: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: 16
            ) {
                ForEach(0..<6, id: \.self) { _ in
                    PrewrittenStoryCardSkeleton()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Error View
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.white.opacity(0.6))
            
            Text(error)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            
            Button(action: {
                Task { await viewModel.loadPrewrittenStories() }
            }) {
                Text("try_again".localized)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.5))
            
            Text("no_stories_found".localized)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text("no_stories_for_filters".localized)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            
            Button(action: {
                viewModel.clearFilters()
            }) {
                Text("filter_clear_all".localized)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
}

// MARK: - Filter Sheet View

struct FilterSheetView: View {
    @ObservedObject var viewModel: PrewrittenViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Category Section
                        categorySection

                        // Illustrated Section (New)
                        illustratedSection

                        // Tier Section
                        tierSection

                        Spacer()
                            .frame(height: 20)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("filter_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("filter_clear".localized) {
                        viewModel.clearFilters()
                    }
                    .foregroundColor(.orange)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("filter_apply".localized) {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Category Section
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "folder")
                    .font(.system(size: 18))
                    .foregroundColor(.purple)
                
                Text("filter_category".localized)
                    .font(.system(size: 18, weight: .semibold))
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(viewModel.categoryFilters, id: \.self) { category in
                    FilterOptionButton(
                        title: category,
                        icon: getCategoryIcon(category),
                        isSelected: viewModel.selectedCategory == category,
                        action: { viewModel.filterByCategory(category) }
                    )
                }
            }
        }
    }
    

    // MARK: - Illustrated Section
    
    private var illustratedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $viewModel.isIllustratedOnly) {
                HStack(spacing: 12) {
                    Image(systemName: "photo.artframe")
                        .font(.system(size: 18))
                        .foregroundColor(.pink)
                        .frame(width: 36, height: 36)
                        .background(Color.pink.opacity(0.15))
                        .cornerRadius(10)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("filter_illustrated_only".localized)
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text("filter_illustrated_desc".localized)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .pink))
            .padding(14)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(14)
        }
    }
    
    // MARK: - Tier Section
    
    private var tierSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "crown")
                    .font(.system(size: 18))
                    .foregroundColor(.orange)
                
                Text("filter_access_level".localized)
                    .font(.system(size: 18, weight: .semibold))
            }
            
            VStack(spacing: 12) {
                TierFilterOption(
                    title: "filter_all".localized,
                    subtitle: "filter_all_stories".localized,
                    icon: "square.grid.2x2",
                    color: .gray,
                    isSelected: viewModel.selectedTier == nil,
                    action: { viewModel.filterByTier(nil) }
                )
                
                TierFilterOption(
                    title: "filter_free".localized,
                    subtitle: "filter_free_desc".localized,
                    icon: "gift",
                    color: .green,
                    isSelected: viewModel.selectedTier == .free,
                    action: { viewModel.filterByTier(.free) }
                )
                
                TierFilterOption(
                    title: "filter_plus".localized,
                    subtitle: "filter_plus_desc".localized,
                    icon: "star",
                    color: .orange,
                    isSelected: viewModel.selectedTier == .plus,
                    action: { viewModel.filterByTier(.plus) }
                )
                
                TierFilterOption(
                    title: "filter_pro".localized,
                    subtitle: "filter_pro_desc".localized,
                    icon: "crown.fill",
                    color: .purple,
                    isSelected: viewModel.selectedTier == .pro,
                    action: { viewModel.filterByTier(.pro) }
                )
            }
        }
    }
    
    private func getCategoryIcon(_ category: String) -> String {
        // Match against localized strings
        if category == "filter_all".localized { return "square.grid.2x2" }
        else if category == "genre_bedtime".localized { return "moon.stars" }
        else if category == "genre_adventure".localized { return "map" }
        else if category == "genre_family".localized { return "house.fill" }
        else if category == "genre_friendship".localized { return "heart.fill" }
        else if category == "genre_fantasy".localized { return "sparkles" }
        else if category == "genre_animals".localized { return "hare" }
        else if category == "genre_princess".localized { return "crown" }
        else if category == "genre_classic".localized { return "book.closed" }
        else { return "book" }
    }
}

// MARK: - Filter Option Button

struct FilterOptionButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.purple.opacity(0.15) : Color(UIColor.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 2)
            )
            .foregroundColor(isSelected ? .purple : .primary)
        }
    }
}

// MARK: - Tier Filter Option

struct TierFilterOption: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                    .frame(width: 36, height: 36)
                    .background(color.opacity(0.15))
                    .cornerRadius(10)
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(color)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? color.opacity(0.1) : Color(UIColor.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Active Filter Chip

struct ActiveFilterChip: View {
    let title: String
    let icon: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(16)
    }
}

// MARK: - Prewritten Story Card

struct PrewrittenStoryCard: View {
    let story: Story
    let isLocked: Bool
    let isFavorite: Bool
    let isToggling: Bool
    let action: () -> Void
    var onToggleFavorite: (() -> Void)? = nil

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                // Cover Image
                ZStack {
                    if let imageUrl = story.coverImageUrl {
                        WebImage(url: URL(string: imageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            placeholderImage
                        }
                    } else {
                        placeholderImage
                    }

                    // Lock Overlay (shows tier info when locked)
                    if isLocked {
                        lockOverlay
                    } else {
                        // Feature Badges (top right corner)
                        VStack {
                            HStack {
                                Spacer()
                                HStack(spacing: 6) {
                                    // Audio badge
                                    if story.audioUrl != nil {
                                        Text("🎧")
                                            .font(.system(size: 14))
                                            .padding(6)
                                            .background(
                                                Circle()
                                                    .fill(Color.black.opacity(0.6))
                                                    .overlay(
                                                        Circle()
                                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                                    )
                                            )
                                    }
                                    
                                    // Image badge
                                    if story.isIllustrated {
                                        Text("🎨")
                                            .font(.system(size: 14))
                                            .padding(6)
                                            .background(
                                                Circle()
                                                    .fill(Color.black.opacity(0.6))
                                                    .overlay(
                                                        Circle()
                                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                                    )
                                            )
                                    }
                                    
                                    // Tier Badge
                                    Text(getTierDisplayName(story.metadata?.tier ?? "free"))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(tierBadgeColor)
                                        .cornerRadius(8)
                                }
                                .padding(8)
                            }
                            Spacer()
                        }
                        
                        // Favorite Button (bottom right, if not locked)
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Button(action: {
                                    onToggleFavorite?()
                                }) {
                                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                                        .font(.system(size: 18))
                                        .foregroundColor(isFavorite ? .pink : .white)
                                        .symbolEffect(.bounce, value: isFavorite)
                                        .padding(8)
                                        .background(Circle().fill(Color.black.opacity(0.5)))
                                }
                                .disabled(isToggling)
                                .opacity(isToggling ? 0.5 : 1.0)
                                .padding(8)
                            }
                        }
                    }
                }
                .frame(height: 160)
                .clipped()
                .cornerRadius(12)

                // Title (fixed height to ensure consistency)
                Text(story.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .frame(height: 40, alignment: .topLeading)
                
                // Info with Age Range
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        Text("\(story.roundedMinutes) " + "min_suffix".localized)
                            .font(.system(size: 12))
                    }

                    // Age Range Badge
                    if let ageRange = story.metadata?.ageRange {
                        Text(localizedAgeRange(ageRange))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.purple.opacity(0.6)))
                    }

                    Spacer()
                }
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
            }
            .padding(10)
            .background(Color.white.opacity(0.18)) // Increased from 0.10
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1) // Increased from 0.20
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var placeholderImage: some View {
        let hasImageUrl = story.coverImageUrl != nil

        return Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.blue.opacity(0.4), Color.purple.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                VStack(spacing: 6) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.5))

                    // Show loading text only when we have a coverImageUrl (loading state)
                    if hasImageUrl {
                        Text("loading_image".localized)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            )
            .shimmering(active: hasImageUrl) // Shimmer ONLY when image URL exists (loading state)
    }
    
    private var lockOverlay: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.75)

            // Blur effect
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.3)

            VStack(spacing: 12) {
                // Lock icon with glow
                ZStack {
                    Circle()
                        .fill(tierBadgeColor)
                        .frame(width: 60, height: 60)
                        .blur(radius: 10)

                    Circle()
                        .fill(tierBadgeColor)
                        .frame(width: 50, height: 50)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }

                // Tier name
                Text(getTierDisplayName(story.metadata?.tier ?? "free"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(tierBadgeColor)
                    )
            }
        }
    }
    
    
    private var tierBadgeColor: Color {
        let tier = SubscriptionTier(rawValue: story.metadata?.tier ?? "free") ?? .free
        switch tier {
        case .free: return Color.green.opacity(0.8)
        case .plus: return Color.orange.opacity(0.8)
        case .pro: return Color.purple.opacity(0.8)
        }
    }
    
    private func getTierDisplayName(_ tierString: String) -> String {
        let tier = SubscriptionTier(rawValue: tierString) ?? .free
        return tier.displayName
    }
    
    private func localizedAgeRange(_ ageRange: String) -> String {
        switch ageRange.lowercased() {
        case "toddler": return "age_range_0_3".localized
        case "preschool": return "age_range_4_6".localized
        case "young": return "age_range_7_9".localized
        case "middle": return "age_range_10_12".localized
        case "teen": return "age_range_13_plus".localized
        default: return ageRange.capitalized
        }
    }
}

// MARK: - Preview

#Preview {
    PrewrittenLibraryView()
}

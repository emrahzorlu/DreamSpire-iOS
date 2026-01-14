//
//  FavoriteManager.swift
//  DreamSpire
//
//  Simple favorites API wrapper - no observation
//

import Foundation

actor FavoriteManager {
    static let shared = FavoriteManager()
    
    private let storyService = StoryService.shared
    private var togglingIds: Set<String> = []
    
    private init() {
        DWLogger.shared.info("FavoriteManager initialized", category: .app)
    }
    
    // MARK: - API Methods
    
    func getFavorites() async throws -> [Story] {
        return try await storyService.getFavorites()
    }
    
    func toggleFavorite(storyId: String) async throws -> Bool {
        // Prevent multiple toggles
        guard !togglingIds.contains(storyId) else {
            DWLogger.shared.warning("Toggle already in progress for \(storyId)", category: .story)
            throw NSError(domain: "FavoriteManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Toggle in progress"])
        }
        
        togglingIds.insert(storyId)
        defer { togglingIds.remove(storyId) }
        
        let newState = try await storyService.toggleFavorite(storyId: storyId)
        DWLogger.shared.info("Favorite toggled for \(storyId): \(newState)", category: .story)
        
        return newState
    }
}

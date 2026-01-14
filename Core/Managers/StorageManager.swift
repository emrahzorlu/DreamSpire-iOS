//
//  StorageManager.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//

import Foundation

class StorageManager {
    static let shared = StorageManager()
    
    private let userDefaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        
        DWLogger.shared.info("StorageManager initialized", category: .data)
    }
    
    // MARK: - Generic Storage
    
    func save<T: Codable>(_ object: T, forKey key: String) {
        do {
            let data = try encoder.encode(object)
            userDefaults.set(data, forKey: key)
            DWLogger.shared.debug("Saved object for key: \(key)", category: .data)
        } catch {
            DWLogger.shared.error("Failed to save object", error: error, category: .data)
        }
    }
    
    func load<T: Codable>(forKey key: String) -> T? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        
        do {
            let object = try decoder.decode(T.self, from: data)
            DWLogger.shared.debug("Loaded object for key: \(key)", category: .data)
            return object
        } catch {
            DWLogger.shared.error("Failed to load object", error: error, category: .data)
            return nil
        }
    }
    
    func remove(forKey key: String) {
        userDefaults.removeObject(forKey: key)
        DWLogger.shared.debug("Removed object for key: \(key)", category: .data)
    }
    
    // MARK: - Story Caching
    
    func cacheStory(_ story: Story) {
        let key = "cached_story_\(story.id)"
        save(story, forKey: key)
        
        // Add to cached stories list
        var cachedIds: [String] = load(forKey: Constants.StorageKeys.cachedStories) ?? []
        if !cachedIds.contains(story.id) {
            cachedIds.append(story.id)
            save(cachedIds, forKey: Constants.StorageKeys.cachedStories)
        }
        
        DWLogger.shared.debug("Cached story: \(story.id)", category: .data)
    }
    
    func getCachedStory(id: String) -> Story? {
        let key = "cached_story_\(id)"
        return load(forKey: key)
    }
    
    func getCachedStories() -> [Story] {
        let cachedIds: [String] = load(forKey: Constants.StorageKeys.cachedStories) ?? []
        return cachedIds.compactMap { getCachedStory(id: $0) }
    }
    
    func clearCachedStories() {
        let cachedIds: [String] = load(forKey: Constants.StorageKeys.cachedStories) ?? []
        cachedIds.forEach { remove(forKey: "cached_story_\($0)") }
        remove(forKey: Constants.StorageKeys.cachedStories)
        
        DWLogger.shared.info("Cleared all cached stories", category: .data)
    }
    
    // MARK: - App Settings
    
    var selectedLanguage: String {
        get {
            userDefaults.string(forKey: Constants.StorageKeys.selectedLanguage) ?? Constants.App.defaultLanguage
        }
        set {
            userDefaults.set(newValue, forKey: Constants.StorageKeys.selectedLanguage)
            DWLogger.shared.info("Language changed to: \(newValue)", category: .general)
        }
    }
    
    var notificationsEnabled: Bool {
        get {
            userDefaults.bool(forKey: Constants.StorageKeys.notificationsEnabled)
        }
        set {
            userDefaults.set(newValue, forKey: Constants.StorageKeys.notificationsEnabled)
            DWLogger.shared.info("Notifications \(newValue ? "enabled" : "disabled")", category: .general)
        }
    }
    
    // MARK: - Recent Searches
    
    func saveRecentSearch(_ query: String) {
        var searches: [String] = load(forKey: "recent_searches") ?? []
        
        // Remove if already exists
        searches.removeAll { $0 == query }
        
        // Add to beginning
        searches.insert(query, at: 0)
        
        // Keep only last 10
        if searches.count > 10 {
            searches = Array(searches.prefix(10))
        }
        
        save(searches, forKey: "recent_searches")
    }
    
    func getRecentSearches() -> [String] {
        return load(forKey: "recent_searches") ?? []
    }
    
    func clearRecentSearches() {
        remove(forKey: "recent_searches")
    }
    
    // MARK: - Last Sync Date
    
    var lastSyncDate: Date? {
        get {
            return userDefaults.object(forKey: Constants.StorageKeys.lastSyncDate) as? Date
        }
        set {
            userDefaults.set(newValue, forKey: Constants.StorageKeys.lastSyncDate)
        }
    }
    
    // MARK: - Clear All Data
    
    func clearAllData() {
        let domain = Bundle.main.bundleIdentifier!
        userDefaults.removePersistentDomain(forName: domain)
        userDefaults.synchronize()
        
        DWLogger.shared.warning("All UserDefaults data cleared", category: .data)
    }
}

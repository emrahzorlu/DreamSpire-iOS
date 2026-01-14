//
//  PrewrittenService.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//

import Foundation

class PrewrittenService {
    static let shared = PrewrittenService()
    private let apiClient = APIClient.shared
    
    private init() {
        DWLogger.shared.info("PrewrittenService initialized", category: .api)
    }
    
    // MARK: - Get All Prewritten Stories
    
    func getPrewrittenStories(language: String = "tr", summary: Bool = false) async throws -> [Story] {
        print("\n🌐 [PrewrittenService] ===== FETCHING STORIES =====")
        print("🌐 [PrewrittenService] Language: \(language)")
        let endpoint = "\(Constants.API.Endpoints.prewritten)?language=\(language)" + (summary ? "&summary=true" : "")
        print("🌐 [PrewrittenService] Endpoint: \(endpoint)")
        
        DWLogger.shared.info("Fetching prewritten stories (language: \(language))", category: .api)
        
        do {
            print("🌐 [PrewrittenService] Making API request...")
            // Backend returns: { success: true, stories: [...], count: 30 }
            // We need to decode the wrapper
            let response: PrewrittenStoriesResponse = try await apiClient.makeRequest(
                endpoint: endpoint,
                method: .get,
                requiresAuth: false
            )
            
            print("✅ [PrewrittenService] API request successful!")
            print("✅ [PrewrittenService] Response success: \(response.success)")
            print("✅ [PrewrittenService] Stories count: \(response.stories.count)")
            print("✅ [PrewrittenService] Response count field: \(response.count)")
            
            if response.stories.count > 0 {
                print("\n📖 [PrewrittenService] First story details:")
                let first = response.stories[0]
                print("   - ID: \(first.id)")
                print("   - Title: \(first.title)")
                print("   - Category: \(first.category)")
                print("   - Type: \(first.type.rawValue)")
                print("   - Language: \(first.language)")
            } else {
                print("⚠️ [PrewrittenService] STORIES ARRAY IS EMPTY!")
            }
            
            DWLogger.shared.info("Fetched \(response.stories.count) prewritten stories", category: .api)
            print("🌐 [PrewrittenService] ===== FETCH COMPLETE =====\n")
            return response.stories
        } catch {
            print("❌ [PrewrittenService] API REQUEST FAILED!")
            print("❌ [PrewrittenService] Error: \(error)")
            print("❌ [PrewrittenService] Error type: \(type(of: error))")
            print("❌ [PrewrittenService] Localized: \(error.localizedDescription)")
            
            if let apiError = error as? APIError {
                print("❌ [PrewrittenService] APIError details: \(apiError)")
            }
            
            DWLogger.shared.error("Failed to fetch prewritten stories", error: error, category: .api)
            throw error
        }
    }
    
    // MARK: - Get Single Prewritten Story
    
    func getPrewrittenStory(id: String, language: String? = nil) async throws -> Story {
        // Use provided language or get current app language
        let lang = language ?? LocalizationManager.shared.currentLanguage.rawValue
        
        DWLogger.shared.info("Fetching prewritten story: \(id) (language: \(lang))", category: .api)
        
        do {
            // Backend returns: { success: true, story: {...} }
            // CRITICAL: Include language parameter for proper localization
            let response: PrewrittenStoryResponse = try await apiClient.makeRequest(
                endpoint: "\(Constants.API.Endpoints.prewritten)/\(id)?language=\(lang)",
                method: .get,
                requiresAuth: false
            )
            
            DWLogger.shared.info("Prewritten story fetched: \(response.story.title) (lang: \(lang))", category: .api)
            return response.story
        } catch {
            DWLogger.shared.error("Failed to fetch prewritten story", error: error, category: .api)
            throw error
        }
    }
    
    // MARK: - Get by Category
    
    func getPrewrittenByCategory(category: String, language: String = "tr", summary: Bool = false) async throws -> [Story] {
        DWLogger.shared.info("Fetching prewritten stories by category: \(category) (summary: \(summary))", category: .api)
        
        do {
            let endpoint = "\(Constants.API.Endpoints.prewritten)?category=\(category)&language=\(language)" + (summary ? "&summary=true" : "")
            let response: PrewrittenStoriesResponse = try await apiClient.makeRequest(
                endpoint: endpoint,
                method: .get,
                requiresAuth: false
            )
            
            DWLogger.shared.info("Fetched \(response.stories.count) stories in category: \(category)", category: .api)
            return response.stories
        } catch {
            DWLogger.shared.error("Failed to fetch stories by category", error: error, category: .api)
            throw error
        }
    }
    
    // MARK: - Get Featured Stories

    func getFeaturedStories(language: String = "tr", limit: Int = 10, summary: Bool = false) async throws -> [Story] {
        DWLogger.shared.info("Fetching featured stories (limit: \(limit), summary: \(summary))", category: .api)

        do {
            let endpoint = "\(Constants.API.Endpoints.prewritten)/featured?language=\(language)&limit=\(limit)" + (summary ? "&summary=true" : "")
            let response: PrewrittenStoriesResponse = try await apiClient.makeRequest(
                endpoint: endpoint,
                method: .get,
                requiresAuth: false
            )

            DWLogger.shared.info("Fetched \(response.stories.count) featured stories", category: .api)
            return response.stories
        } catch {
            DWLogger.shared.error("Failed to fetch featured stories", error: error, category: .api)
            throw error
        }
    }

    // MARK: - Get Stories by Tag (Tier-Sorted from Backend)

    func getStoriesByTag(_ tag: String, language: String = "tr", limit: Int = 10, summary: Bool = false) async throws -> [Story] {
        DWLogger.shared.info("Fetching stories by tag: \(tag) (limit: \(limit), summary: \(summary))", category: .api)

        do {
            let endpoint = "\(Constants.API.Endpoints.prewritten)/by-tag/\(tag)?language=\(language)&limit=\(limit)" + (summary ? "&summary=true" : "")
            let response: PrewrittenStoriesResponse = try await apiClient.makeRequest(
                endpoint: endpoint,
                method: .get,
                requiresAuth: false
            )

            DWLogger.shared.info("Fetched \(response.stories.count) stories with tag: \(tag) (tier-sorted by backend)", category: .api)
            return response.stories
        } catch {
            DWLogger.shared.error("Failed to fetch stories by tag", error: error, category: .api)
            throw error
        }
    }
}

// MARK: - Response Models

struct PrewrittenStoriesResponse: Codable {
    let success: Bool
    let stories: [Story]
    let count: Int
}

struct PrewrittenStoryResponse: Codable {
    let success: Bool
    let story: Story
}

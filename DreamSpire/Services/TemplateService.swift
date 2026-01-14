//
//  TemplateService.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//

import Foundation

class TemplateService {
    static let shared = TemplateService()
    private let apiClient = APIClient.shared
    
    private init() {
        DWLogger.shared.info("TemplateService initialized", category: .api)
    }
    
    // MARK: - Get All Templates
    
    func getAllTemplates(language: String? = nil) async throws -> [Template] {
        let lang = language ?? LocalizationManager.shared.currentLanguage.rawValue
        DWLogger.shared.info("Fetching all templates (language: \(lang))", category: .api)
        
        struct Response: Codable {
            let success: Bool
            let templates: [Template]
        }
        
        do {
            let endpoint = "\(Constants.API.Endpoints.templates)?language=\(lang)"
            let response: Response = try await apiClient.makeRequest(
                endpoint: endpoint,
                method: .get,
                requiresAuth: false
            )
            
            DWLogger.shared.info("Fetched \(response.templates.count) templates", category: .api)
            return response.templates
        } catch {
            DWLogger.shared.error("Failed to fetch templates", error: error, category: .api)
            throw error
        }
    }
    
    // MARK: - Get Template by ID
    
    func getTemplate(id: String) async throws -> Template {
        DWLogger.shared.info("Fetching template: \(id)", category: .api)
        
        struct Response: Codable {
            let success: Bool
            let template: Template
        }
        
        do {
            let response: Response = try await apiClient.makeRequest(
                endpoint: "\(Constants.API.Endpoints.templates)/\(id)",
                method: .get,
                requiresAuth: false
            )
            
            DWLogger.shared.info("Template fetched: \(response.template.title)", category: .api)
            return response.template
        } catch {
            DWLogger.shared.error("Failed to fetch template", error: error, category: .api)
            throw error
        }
    }
    
    // MARK: - Generate from Template
    
    func generateFromTemplate(
        templateId: String,
        characters: [String: Character],
        readingMinutes: Int,
        generateAudio: Bool = true,
        generateImage: Bool = true,
        illustrated: Bool = false
    ) async throws -> TemplateGenerationResponse {
        DWLogger.shared.info("Generating story from template: \(templateId)", category: .story)
        DWLogger.shared.logStoryCreationStart(prompt: "Template: \(templateId)", characters: characters.count)
        
        let request = TemplateStoryRequest(
            characters: characters,
            readingMinutes: readingMinutes,
            generateAudio: generateAudio,
            generateImage: generateImage,
            illustrated: illustrated
        )
        
        struct Response: Codable {
            let success: Bool
            let async: Bool?
            let jobId: String?
            let story: Story?
            let message: String?
            let coinTransaction: StoryCreationCoinTransaction?
        }
        
        do {
            let response: Response = try await apiClient.makeRequest(
                endpoint: "\(Constants.API.Endpoints.generateFromTemplate)/\(templateId)/generate",
                method: .post,
                body: request
            )
            
            // Check if async response
            if response.async == true, let jobId = response.jobId {
                DWLogger.shared.info("Async template generation started, job ID: \(jobId)", category: .story)
                return TemplateGenerationResponse(
                    isAsync: true, 
                    jobId: jobId, 
                    story: nil,
                    coinTransaction: response.coinTransaction
                )
            } else if let story = response.story {
                DWLogger.shared.info("Sync template generation completed", category: .story)
                return TemplateGenerationResponse(
                    isAsync: false, 
                    jobId: nil, 
                    story: story,
                    coinTransaction: response.coinTransaction
                )
            } else {
                throw APIError.decodingError
            }
        } catch {
            DWLogger.shared.error("Template generation failed", error: error, category: .story)
            throw error
        }
    }
}

// MARK: - Template Generation Response

struct TemplateGenerationResponse {
    let isAsync: Bool
    let jobId: String?
    let story: Story?
    let coinTransaction: StoryCreationCoinTransaction?
}

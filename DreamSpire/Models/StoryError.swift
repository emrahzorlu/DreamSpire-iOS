//
//  StoryError.swift
//  DreamSpire
//
//  Structured error handling for better UX
//

import Foundation

// MARK: - Error Types

enum StoryErrorType: String, Codable {
    case contentSafety = "content_safety"
    case imageRejected = "image_rejected"
    case validation = "validation"
    case rateLimit = "rate_limit"
    case subscription = "subscription"
    case payment = "payment"
    case serverError = "server_error"
    case network = "network"
}

enum StoryErrorCode: String, Codable {
    // Content Safety
    case inappropriatePrompt = "inappropriate_prompt"
    case inappropriateContent = "inappropriate_content"
    case moderationFailed = "moderation_failed"
    
    // Image Generation
    case imageSafetyRejected = "image_safety_rejected"
    case imageGenerationFailed = "image_generation_failed"
    
    // Validation
    case invalidInput = "invalid_input"
    case missingRequired = "missing_required"
    
    // Rate Limiting
    case rateLimitExceeded = "rate_limit_exceeded"
    case dailyLimitReached = "daily_limit_reached"
    
    // Subscription
    case insufficientCoins = "insufficient_coins"
    case featureLocked = "feature_locked"
    case tierRequired = "tier_required"
    
    // Payment
    case paymentFailed = "payment_failed"
    case invalidTransaction = "invalid_transaction"
    
    // Server
    case internalError = "internal_error"
    case serviceUnavailable = "service_unavailable"
}

// MARK: - User Message

struct ErrorUserMessage: Codable {
    let title: String
    let message: String
    let suggestion: String?
    let examples: [String]?
    let canRetry: Bool
    let retryDelay: Int?
    let actionRequired: String?
}

// MARK: - Story Error Response

struct StoryErrorResponse: Codable {
    let success: Bool
    let error: String?
    let errorType: StoryErrorType?
    let errorCode: StoryErrorCode?
    let userMessage: ErrorUserMessage?
    
    enum CodingKeys: String, CodingKey {
        case success
        case error
        case errorType
        case errorCode
        case userMessage
    }
}

// MARK: - Story Error

struct StoryError: Error, LocalizedError {
    let type: StoryErrorType
    let code: StoryErrorCode
    let userMessage: ErrorUserMessage
    
    var errorDescription: String? {
        return userMessage.message
    }
    
    var title: String {
        return userMessage.title
    }
    
    var suggestion: String? {
        return userMessage.suggestion
    }
    
    var examples: [String] {
        return userMessage.examples ?? []
    }
    
    var canRetry: Bool {
        return userMessage.canRetry
    }
    
    var retryDelay: TimeInterval? {
        guard let delay = userMessage.retryDelay else { return nil }
        return TimeInterval(delay) / 1000.0
    }
    
    var actionRequired: String? {
        return userMessage.actionRequired
    }
    
    // MARK: - Factory Methods
    
    static func from(response: StoryErrorResponse) -> StoryError? {
        guard let errorType = response.errorType,
              let errorCode = response.errorCode,
              let userMessage = response.userMessage else {
            return nil
        }
        
        return StoryError(
            type: errorType,
            code: errorCode,
            userMessage: userMessage
        )
    }
    
    // MARK: - Default Errors (Fallback)
    
    static func genericError(message: String) -> StoryError {
        return StoryError(
            type: .serverError,
            code: .internalError,
            userMessage: ErrorUserMessage(
                title: "error".localized,
                message: message,
                suggestion: "try_again".localized,
                examples: nil,
                canRetry: true,
                retryDelay: 3000,
                actionRequired: nil
            )
        )
    }
    
    static func networkError() -> StoryError {
        return StoryError(
            type: .network,
            code: .serviceUnavailable,
            userMessage: ErrorUserMessage(
                title: "error_network".localized,
                message: "error_network_message".localized,
                suggestion: "error_network_suggestion".localized,
                examples: nil,
                canRetry: true,
                retryDelay: 3000,
                actionRequired: nil
            )
        )
    }
}

// MARK: - Error Display Helper

extension StoryError {
    /// Show this error using GlassAlertManager with appropriate styling and actions
    func show(onRetry: (() -> Void)? = nil, onAction: (() -> Void)? = nil) {
        Task { @MainActor in
            // Determine if this is a critical error (red) or warning (orange)
            let isCritical = type == .serverError || type == .network
            
            var fullMessage = userMessage.message
            if let suggestion = userMessage.suggestion {
                fullMessage += "\n\n\(suggestion)"
            }
            
            // Add examples if available
            if let examples = userMessage.examples, !examples.isEmpty {
                fullMessage += "\n\n" + "examples_title".localized + ":\n"
                fullMessage += examples.map { "• \($0)" }.joined(separator: "\n")
            }
            
            if isCritical {
                GlassAlertManager.shared.error(userMessage.title, message: fullMessage)
            } else {
                GlassAlertManager.shared.warning(userMessage.title, message: fullMessage)
            }
            
            // Handle actions if needed
            if let action = userMessage.actionRequired, let onAction = onAction {
                // Trigger action after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onAction()
                }
            }
            
            // Handle retry if available
            if canRetry, let onRetry = onRetry {
                // Could potentially add a retry button in the future
                // For now, just log that retry is available
                DWLogger.shared.info("Error is retryable, callback available", category: .general)
            }
        }
    }
}

//
//  Error+ContentSafety.swift
//  DreamSpire
//
//  ContentSafetyError için helper extensions
//

import SwiftUI

extension Error {
    /// StoryError'ı extract et (NEW: Structured error)
    var storyError: StoryError? {
        if let apiError = self as? APIError,
           case .storyError(let error) = apiError {
            return error
        }
        return nil
    }
    
    /// ContentSafetyError'ı extract et (OLD: Legacy format)
    var contentSafetyError: ContentSafetyError? {
        if let apiError = self as? APIError,
           case .contentSafety(let safetyError) = apiError {
            return safetyError
        }
        return nil
    }

    /// Insufficient coins error mi?
    var isInsufficientCoins: Bool {
        if let apiError = self as? APIError,
           case .insufficientCoins = apiError {
            return true
        }
        return false
    }
}

extension GlassAlertManager {
    /// ContentSafetyError için özel alert göster
    func showContentSafetyError(_ error: ContentSafetyError) {
        // İlk mesajı göster
        self.custom(
            title: error.title,
            message: error.formattedMessage,
            icon: "exclamationmark.triangle.fill",
            color: Color.orange,
            duration: 6.0  // Daha uzun göster çünkü öneriler var
        )

        // Eğer örnekler varsa, 1 saniye sonra örnekleri de göster
        if let examples = error.examplesText {    
            DispatchQueue.main.asyncAfter(deadline: .now() + 6.5) {
                self.info(
                    "Örnek Konular",
                    message: examples,
                    duration: 7.0
                )
            }
        }
    }
}

// MARK: - ViewModels için helper
extension GlassAlertManager {
    /// Generic error handling - Structured error'ları otomatik yakala ve göster
    func handleError(_ error: Error, defaultTitle: String = "error".localized, onRetry: (() -> Void)? = nil, onAction: (() -> Void)? = nil) {
        // Priority 1: New StoryError format
        if let storyError = error.storyError {
            storyError.show(onRetry: onRetry, onAction: onAction)
            return
        }

        // Priority 2: Legacy ContentSafetyError
        if let safetyError = error.contentSafetyError {
            self.showContentSafetyError(safetyError)
            return
        }

        // Priority 3: Insufficient coins
        if error.isInsufficientCoins {
            self.warning(
                "coin_insufficient".localized,
                message: "coin_insufficient_message".localized
            )
            return
        }

        // Priority 4: Enhanced API error handling
        if let apiError = error as? APIError {
            handleAPIError(apiError, defaultTitle: defaultTitle, onRetry: onRetry)
            return
        }

        // Priority 5: Generic error
        self.error(
            defaultTitle,
            message: error.localizedDescription
        )
    }

    /// Handle API errors with context-aware titles and messages
    private func handleAPIError(_ error: APIError, defaultTitle: String, onRetry: (() -> Void)?) {
        let (title, message, alertType) = getAPIErrorDetails(error)

        if let retry = onRetry, error.isRetryable {
            // Show with retry button
            self.showAlert(
                type: alertType,
                title: title,
                message: message,
                buttonTitle: "Tekrar Dene",
                action: retry
            )
        } else {
            // Show without button
            switch alertType {
            case .error:
                self.error(title, message: message)
            case .warning:
                self.warning(title, message: message)
            case .info:
                self.info(title, message: message)
            case .success:
                self.success(title, message: message)
            }
        }
    }

    /// Get user-friendly title, message, and alert type for API errors
    private func getAPIErrorDetails(_ error: APIError) -> (title: String, message: String, type: GlassAlertType) {
        switch error {
        case .networkError:
            return (
                "error_network".localized,
                "error_network_suggestion".localized,
                .warning
            )
        case .unauthorized:
            return (
                "error_auth".localized,
                "Lütfen tekrar giriş yapın",
                .error
            )
        case .serverError(let code):
            if code >= 500 {
                return (
                    "error_server".localized,
                    "Sunucularımızda geçici bir sorun var. Lütfen biraz sonra tekrar deneyin.",
                    .error
                )
            } else {
                return (
                    "error_invalid_request".localized,
                    error.errorDescription ?? "error_generic".localized,
                    .warning
                )
            }
        case .decodingError:
            return (
                "error_data_processing".localized,
                "Veriler işlenirken bir sorun oluştu. Lütfen tekrar deneyin.",
                .error
            )
        case .jobInProgress:
            return (
                "Hikaye Oluşturuluyor",
                "Zaten devam eden bir hikaye oluşturma işleminiz var. Lütfen tamamlanmasını bekleyin.",
                .info
            )
        default:
            return (
                "error".localized,
                error.errorDescription ?? "error_generic".localized,
                .error
            )
        }
    }
}

extension APIError {
    /// Can this error be retried?
    var isRetryable: Bool {
        switch self {
        case .networkError:
            return true
        case .serverError(let code):
            return code >= 500
        default:
            return false
        }
    }
}

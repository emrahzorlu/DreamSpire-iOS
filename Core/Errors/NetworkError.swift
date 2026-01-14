//
//  NetworkError.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025.
//

import Foundation

/// Network-specific errors
enum NetworkError: LocalizedError {
    case notConnected
    case timeout
    case serverError(statusCode: Int)
    case invalidResponse
    case decodingFailed
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "error_network".localized
        case .timeout:
            return "İstek zaman aşımına uğradı. Lütfen tekrar deneyin."
        case .serverError(let code):
            return "Sunucu hatası (\(code)). Lütfen daha sonra tekrar deneyin."
        case .invalidResponse:
            return "Geçersiz sunucu yanıtı."
        case .decodingFailed:
            return "Veri işlenirken hata oluştu."
        }
    }
    
    /// Check if this is a connectivity error that can be retried
    var isRetryable: Bool {
        switch self {
        case .notConnected, .timeout:
            return true
        case .serverError(let code):
            return code >= 500
        case .invalidResponse, .decodingFailed:
            return false
        }
    }
}

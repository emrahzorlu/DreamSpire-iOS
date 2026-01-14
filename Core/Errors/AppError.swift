//
//  AppError.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025.
//

import Foundation

/// Base error type for the app
/// Use specific error types for different domains
enum AppError: LocalizedError {
    case network(NetworkError)
    case validation(ValidationError)
    case auth(AuthError)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .network(let error):
            return error.errorDescription
        case .validation(let error):
            return error.errorDescription
        case .auth(let error):
            return error.errorDescription
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

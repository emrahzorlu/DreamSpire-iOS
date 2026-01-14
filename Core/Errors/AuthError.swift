//
//  AuthError.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025.
//

import Foundation

/// Authentication-related errors
enum AuthError: LocalizedError {
    case notLoggedIn
    case invalidCredentials
    case emailAlreadyInUse
    case weakPassword
    case networkError
    case appleSignInFailed
    case tokenExpired
    
    var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            return "error_auth".localized
        case .invalidCredentials:
            return "E-posta veya şifre hatalı."
        case .emailAlreadyInUse:
            return "Bu e-posta adresi zaten kullanılıyor."
        case .weakPassword:
            return "Şifre çok zayıf. Daha güçlü bir şifre seçin."
        case .networkError:
            return "Bağlantı hatası. İnternet bağlantınızı kontrol edin."
        case .appleSignInFailed:
            return "Apple ile giriş başarısız oldu."
        case .tokenExpired:
            return "Oturum süresi doldu. Lütfen tekrar giriş yapın."
        }
    }
}

//
//  ValidationError.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025.
//

import Foundation

/// Validation errors for user input
enum ValidationError: LocalizedError {
    case emptyField(fieldName: String)
    case invalidEmail
    case passwordTooShort(minLength: Int)
    case passwordMismatch
    case invalidCharacterName
    case storyIdeaTooShort
    
    var errorDescription: String? {
        switch self {
        case .emptyField(let fieldName):
            return "\(fieldName) alanı boş bırakılamaz."
        case .invalidEmail:
            return "Geçerli bir e-posta adresi girin."
        case .passwordTooShort(let minLength):
            return "Şifre en az \(minLength) karakter olmalıdır."
        case .passwordMismatch:
            return "Şifreler eşleşmiyor."
        case .invalidCharacterName:
            return "Karakter adı geçersiz."
        case .storyIdeaTooShort:
            return "Hikaye fikri çok kısa."
        }
    }
}

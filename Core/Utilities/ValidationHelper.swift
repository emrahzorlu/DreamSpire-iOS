//
//  ValidationHelper.swift
//  DreamSpire
//
//  Email and Password Validation Utilities
//

import Foundation

struct ValidationHelper {
    
    // MARK: - Email Validation
    
    /// Validates email format using regex
    static func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    /// Validates email format and provides detailed error message
    static func validateEmail(_ email: String) -> ValidationResult {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return .failure("login_invalid_email".localized)
        }
        
        if !isValidEmail(trimmed) {
            return .failure("login_invalid_email".localized)
        }
        
        return .success
    }
    
    // MARK: - Password Validation
    
    /// Validates password strength
    /// Requirements: Minimum 8 characters, 1 uppercase, 1 lowercase, 1 number
    static func validatePassword(_ password: String) -> ValidationResult {
        if password.count < 8 {
            return .failure("login_weak_password".localized)
        }
        
        let uppercaseRegex = ".*[A-Z]+.*"
        let lowercaseRegex = ".*[a-z]+.*"
        let numberRegex = ".*[0-9]+.*"
        
        let hasUppercase = NSPredicate(format: "SELF MATCHES %@", uppercaseRegex).evaluate(with: password)
        let hasLowercase = NSPredicate(format: "SELF MATCHES %@", lowercaseRegex).evaluate(with: password)
        let hasNumber = NSPredicate(format: "SELF MATCHES %@", numberRegex).evaluate(with: password)
        
        if !hasUppercase || !hasLowercase || !hasNumber {
            return .failure("login_weak_password".localized)
        }
        
        return .success
    }
    
    /// Validates password match for signup
    static func validatePasswordMatch(_ password: String, _ confirmPassword: String) -> ValidationResult {
        if password != confirmPassword {
            return .failure("login_passwords_mismatch".localized)
        }
        return .success
    }
    
    // MARK: - Validation Result
    
    enum ValidationResult {
        case success
        case failure(String)
        
        var isValid: Bool {
            switch self {
            case .success: return true
            case .failure: return false
            }
        }
        
        var errorMessage: String? {
            switch self {
            case .success: return nil
            case .failure(let message): return message
            }
        }
    }
}

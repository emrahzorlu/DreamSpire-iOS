//
//  LocalizationManager.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//  Handles app-wide localization and language switching
//

import Foundation
import SwiftUI

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    // Supported languages
    enum Language: String, CaseIterable {
        case turkish = "tr"
        case english = "en"
        case french = "fr"
        case german = "de"
        case spanish = "es"
        
        var displayName: String {
            switch self {
            case .turkish: return "Türkçe"
            case .english: return "English"
            case .french: return "Français"
            case .german: return "Deutsch"
            case .spanish: return "Español"
            }
        }
        
        var flag: String {
            switch self {
            case .turkish: return "🇹🇷"
            case .english: return "🇬🇧"
            case .french: return "🇫🇷"
            case .german: return "🇩🇪"
            case .spanish: return "🇪🇸"
            }
        }
        
        var locale: Locale {
            return Locale(identifier: rawValue)
        }
        
        // Language name for backend API calls
        var apiLanguage: String {
            switch self {
            case .turkish: return "tr"
            case .english: return "en"
            case .french: return "fr"
            case .german: return "de"
            case .spanish: return "es"
            }
        }
        
        // Full language name for story generation prompts
        var fullName: String {
            switch self {
            case .turkish: return "Turkish"
            case .english: return "English"
            case .french: return "French"
            case .german: return "German"
            case .spanish: return "Spanish"
            }
        }
    }
    
    @Published var currentLanguage: Language {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "selectedLanguage")
            Bundle.setLanguage(currentLanguage.rawValue)
            objectWillChange.send()
            
            // Notify observers that language changed
            NotificationCenter.default.post(name: .languageChanged, object: nil)
        }
    }
    
    private init() {
        // Load saved language or detect from device
        if let savedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage"),
           let language = Language(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            // Detect device language (iOS 15+ compatible)
            let deviceLanguage: String
            if #available(iOS 16, *) {
                deviceLanguage = Locale.current.language.languageCode?.identifier ?? "en"
            } else {
                deviceLanguage = Locale.current.languageCode ?? "en"
            }
            self.currentLanguage = Language(rawValue: deviceLanguage) ?? .english
        }

        Bundle.setLanguage(currentLanguage.rawValue)
    }
    
    func setLanguage(_ language: Language) {
        currentLanguage = language
    }
    
    func setLanguage(_ languageCode: String) {
        if let language = Language(rawValue: languageCode) {
            currentLanguage = language
        }
    }
    
    // Get localized string with current language
    func localizedString(_ key: String) -> String {
        return key.localized
    }
    
    // Get all available languages
    var availableLanguages: [Language] {
        return Language.allCases
    }
}

// MARK: - Bundle Extension for Language Switching

private var bundleKey: UInt8 = 0

extension Bundle {
    private static var onLanguageDispatchOnce: () = {
        object_setClass(Bundle.main, PrivateBundle.self)
    }()
    
    static func setLanguage(_ language: String) {
        Bundle.onLanguageDispatchOnce
        
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            // Fallback to main bundle if language not found
            objc_setAssociatedObject(Bundle.main, &bundleKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return
        }
        
        objc_setAssociatedObject(Bundle.main, &bundleKey, bundle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

private class PrivateBundle: Bundle {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let bundle = objc_getAssociatedObject(self, &bundleKey) as? Bundle else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

// MARK: - String Extension for Localization

extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    func localized(with arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments: arguments)
    }
}

// MARK: - SwiftUI LocalizedStringKey Extension

extension LocalizedStringKey {
    init(_ key: String) {
        self.init(stringLiteral: key)
    }
}

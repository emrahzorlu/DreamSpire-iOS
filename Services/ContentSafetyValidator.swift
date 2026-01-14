//
//  ContentSafetyValidator.swift
//  DreamSpire
//
//  Created by Claude on 2024-12-23.
//  Multi-language client-side content safety validation
//

import Foundation

/// Client-side content safety validator
/// Provides SOFT warnings for potentially inappropriate content
/// Uses LANGUAGE-BASED filtering + GLOBAL keywords
/// NOTE: OpenAI Moderation API on backend provides cross-language protection
class ContentSafetyValidator {

    // Blocklist storage: language code -> Set of blocked words
    private static var blocklists: [String: Set<String>] = [:]
    private static var globalBlocklist: Set<String> = []
    private static var isLoaded = false

    private static func loadBlocklistIfNeeded() {
        guard !isLoaded else { return }
        
        if let path = Bundle.main.path(forResource: "blocklist", ofType: "json"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String]] {
            
            for (language, words) in json {
                let wordSet = Set(words.map { $0.lowercased() })
                
                if language == "global" {
                    globalBlocklist = wordSet
                    print("🛡️ Global blocklist loaded: \(globalBlocklist.count) words")
                } else {
                    blocklists[language] = wordSet
                    print("🛡️ \(language.uppercased()) blocklist loaded: \(wordSet.count) words")
                }
            }
            print("🛡️ ContentSafetyValidator: Language-based blocklists loaded. Languages: \(blocklists.keys.joined(separator: ", "))")
        } else {
            print("⚠️ ContentSafetyValidator: Failed to load blocklist.json.")
        }
        
        isLoaded = true
    }

    // MARK: - Public Methods

    /// Get soft warning for user input
    /// Checks ONLY current language's blocklist + global keywords
    static func getSoftWarning(for text: String, language: String = "tr") -> SoftWarning? {
        guard !text.isEmpty else { return nil }
        
        loadBlocklistIfNeeded()

        let lowercased = text.lowercased()
        let wordsInInput = lowercased.components(separatedBy: .punctuationCharacters)
            .joined(separator: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        // 🌐 Step 1: Always check GLOBAL keywords (sex, porn, etc.)
        for blockedWord in globalBlocklist {
            if blockedWord.count < 4 {
                if wordsInInput.contains(blockedWord) {
                    return SoftWarning(
                        message: getSoftWarningMessage(for: language),
                        severity: .high,
                        detectedKeyword: "Global: \(blockedWord)"
                    )
                }
            } else {
                if lowercased.contains(blockedWord) {
                    return SoftWarning(
                        message: getSoftWarningMessage(for: language),
                        severity: .high,
                        detectedKeyword: "Global: \(blockedWord)"
                    )
                }
            }
        }

        // 🗣️ Step 2: Check CURRENT LANGUAGE's blocklist only
        if let languageBlocklist = blocklists[language] {
            for blockedWord in languageBlocklist {
                if blockedWord.count < 4 {
                    if wordsInInput.contains(blockedWord) {
                        return SoftWarning(
                            message: getSoftWarningMessage(for: language),
                            severity: .high,
                            detectedKeyword: "\(language.uppercased()): \(blockedWord)"
                        )
                    }
                } else {
                    if lowercased.contains(blockedWord) {
                        return SoftWarning(
                            message: getSoftWarningMessage(for: language),
                            severity: .high,
                            detectedKeyword: "\(language.uppercased()): \(blockedWord)"
                        )
                    }
                }
            }
        }

        return nil
    }

    /// Validate text and return detailed result
    /// - Parameters:
    ///   - text: Text to validate
    ///   - language: Language code
    /// - Returns: Validation result
    static func validate(text: String, language: String = "tr") -> ValidationResult {
        if let warning = getSoftWarning(for: text, language: language) {
            return ValidationResult(
                isValid: false,
                warning: warning,
                shouldBlockSubmit: true // 🛡️ HARD BLOCK: Now blocks submission
            )
        }

        return ValidationResult(
            isValid: true,
            warning: nil,
            shouldBlockSubmit: false
        )
    }

    // MARK: - Private Methods

    private static func getSoftWarningMessage(for language: String) -> String {
        switch language {
        case "tr":
            return "Bu konu uygun değildir. Lütfen güvenli ve çocuk dostu içerikler kullanın."
        case "en":
            return "This topic is not appropriate. Please use safe and child-friendly content."
        case "es":
            return "Este tema no es apropiado. Por favor, use contenido seguro y apto para niños."
        case "de":
            return "Dieses Thema ist nicht angemessen. Bitte verwenden Sie sichere und kinderfreundliche Inhalte."
        case "fr":
            return "Ce sujet n'est pas approprié. Veuillez utiliser un contenu sûr et adapté aux enfants."
        case "it":
            return "Questo argomento non è appropriato. Si prega di utilizzare contenuti sicuri e adatti ai bambini."
        case "pt":
            return "Este tema não é apropriado. Por favor, use conteúdo seguro e adequado para crianças."
        case "ru":
            return "Эта тема неуместна. Пожалуйста, используйте безопасный и подходящий для детей контент."
        case "zh":
            return "此主题不合适。请使用安全且适合儿童的内容。"
        case "ar":
            return "هذا الموضوع غير مناسب. يرجى استخدام محتوى آمن وصديق للأطفال."
        case "ja":
            return "このトピックは適切ではありません。安全で子供向けのコンテンツを使用してください。"
        case "hi":
            return "यह विषय उपयुक्त नहीं है। कृपया सुरक्षित और बच्चों के अनुकूल सामग्री का उपयोग करें।"
        default:
            return "This topic is not appropriate. Please use safe and child-friendly content."
        }
    }

    // MARK: - Models

    struct SoftWarning {
        let message: String
        let severity: Severity
        let detectedKeyword: String

        enum Severity {
            case medium
            case high
        }
    }

    struct ValidationResult {
        let isValid: Bool
        let warning: SoftWarning?
        let shouldBlockSubmit: Bool
    }
}

// MARK: - Helper Extensions

extension ContentSafetyValidator {

    /// Get localized example topics
    static func getExampleTopics(for language: String) -> [String] {
        switch language {
        case "tr":
            return [
                "Bir sincabın orman maceraları",
                "Dost canavar ile arkadaşlık",
                "Cesur kızın büyük hayali",
                "Denizin derinliklerinde keşif",
                "Bir ejderhanın dostluk hikayesi"
            ]
        case "en":
            return [
                "A squirrel's forest adventure",
                "Friendship with a friendly monster",
                "A brave girl's big dream",
                "Exploration in the deep ocean",
                "A dragon's friendship story"
            ]
        case "es":
            return [
                "La aventura de una ardilla en el bosque",
                "Amistad con un monstruo amigable",
                "El gran sueño de una niña valiente",
                "Exploración en el océano profundo",
                "La historia de amistad de un dragón"
            ]
        case "de":
            return [
                "Ein Eichhörnchens Waldabenteuer",
                "Freundschaft mit einem freundlichen Monster",
                "Der große Traum eines mutigen Mädchens",
                "Erkundung in der Tiefsee",
                "Die Freundschaftsgeschichte eines Drachen"
            ]
        case "fr":
            return [
                "L'aventure d'un écureuil dans la forêt",
                "Amitié avec un monstre amical",
                "Le grand rêve d'une fille courageuse",
                "Exploration dans les profondeurs de l'océan",
                "L'histoire d'amitié d'un dragon"
            ]
        default:
            return [
                "A squirrel's forest adventure",
                "Friendship with a friendly monster",
                "A brave girl's big dream"
            ]
        }
    }
}

//
//  ContentSafetyError.swift
//  DreamSpire
//
//  Backend'den gelen content safety hata modeli
//

import Foundation

/// Backend'den gelen content safety error response
struct ContentSafetyErrorResponse: Codable {
    let success: Bool
    let code: String
    let error: ContentSafetyErrorDetail

    struct ContentSafetyErrorDetail: Codable {
        let title: String
        let message: String
        let suggestion: String
        let examples: [String]
        let canRetry: Bool
        let reason: String?
    }
}

/// Content safety error - user-friendly error type
struct ContentSafetyError: LocalizedError, Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let suggestion: String
    let examples: [String]
    let canRetry: Bool

    var errorDescription: String? {
        return message
    }

    /// GlassAlert için formatted message
    var formattedMessage: String {
        var result = message
        if !suggestion.isEmpty {
            result += "\n\n💡 \(suggestion)"
        }
        return result
    }

    /// İlk 3 örneği bullet point ile döndür
    var examplesText: String? {
        guard !examples.isEmpty else { return nil }
        let topExamples = Array(examples.prefix(3))
        return topExamples.map { "• \($0)" }.joined(separator: "\n")
    }

    init(from response: ContentSafetyErrorResponse.ContentSafetyErrorDetail) {
        self.title = response.title
        self.message = response.message
        self.suggestion = response.suggestion
        self.examples = response.examples
        self.canRetry = response.canRetry
    }
}

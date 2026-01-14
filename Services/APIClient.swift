//
//  APIClient.swift
//  DreamSpire
//
//  Core HTTP client with Firebase authentication and detailed logging
//

import Foundation
import FirebaseAuth
import UIKit

// MARK: - Response Models

private struct JobInProgressResponse: Codable {
    let code: String?
    let data: JobData?
    
    struct JobData: Codable {
        let jobId: String
    }
}

class APIClient {
    static let shared = APIClient()

    private let baseURL = "https://dreamweaver-backend-v2-production.up.railway.app"
    private let session: URLSession
    
    // Retry configuration
    private let maxRetries = 3
    private let baseRetryDelay: TimeInterval = 1.0
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300  // 5 minutes for long-running illustrated story generations
        config.waitsForConnectivity = true  // Wait for connectivity if network is slow
        config.timeoutIntervalForResource = 1800  // 30 minutes total resource timeout
        self.session = URLSession(configuration: config)

        DWLogger.shared.info("📡 APIClient initialized with baseURL: \(baseURL)", category: .network)
    }
    
    // MARK: - Authentication
    
    private func getAuthToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            DWLogger.shared.warning("No authenticated user found", category: .auth)
            throw APIError.unauthorized
        }
        
        let token = try await user.getIDToken()
        DWLogger.shared.debug("🔑 Auth token obtained", category: .auth)
        return token
    }
    
    // MARK: - Generic Request with Detailed Logging
    
    func makeRequest<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        requiresAuth: Bool = true,
        includeDeviceId: Bool = false,  // For guest/optional auth requests
        idempotencyKey: String? = nil    // For duplicate prevention
    ) async throws -> T {
        return try await performRequestWithRetry(
            endpoint: endpoint,
            method: method,
            body: body,
            requiresAuth: requiresAuth,
            includeDeviceId: includeDeviceId,
            idempotencyKey: idempotencyKey
        )
    }
    
    // MARK: - Request with Retry Logic
    
    private func performRequestWithRetry<T: Decodable>(
        endpoint: String,
        method: HTTPMethod,
        body: Encodable?,
        requiresAuth: Bool,
        includeDeviceId: Bool,
        idempotencyKey: String?,
        attempt: Int = 1
    ) async throws -> T {

        do {
            return try await performRequest(
                endpoint: endpoint,
                method: method,
                body: body,
                requiresAuth: requiresAuth,
                includeDeviceId: includeDeviceId,
                idempotencyKey: idempotencyKey
            )
        } catch {
            // Check if we should retry
            // IMPORTANT: POST requests that create resources should NOT be retried
            if attempt < maxRetries && shouldRetry(error: error, endpoint: endpoint, method: method) {
                let delay = baseRetryDelay * pow(2.0, Double(attempt - 1)) // Exponential backoff
                DWLogger.shared.warning("Retrying request after \(delay)s (attempt \(attempt + 1)/\(maxRetries))", category: .network)

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                return try await performRequestWithRetry(
                    endpoint: endpoint,
                    method: method,
                    body: body,
                    requiresAuth: requiresAuth,
                    includeDeviceId: includeDeviceId,
                    idempotencyKey: idempotencyKey,
                    attempt: attempt + 1
                )
            } else {
                throw error
            }
        }
    }
    
    // MARK: - Core Request Implementation
    
    private func performRequest<T: Decodable>(
        endpoint: String,
        method: HTTPMethod,
        body: Encodable?,
        requiresAuth: Bool,
        includeDeviceId: Bool,
        idempotencyKey: String?
    ) async throws -> T {
        let fullURL = "\(baseURL)\(endpoint)"

        DWLogger.shared.info("🌐 \(method.rawValue) \(endpoint)", category: .network)

        guard let url = URL(string: fullURL) else {
            DWLogger.shared.error("Invalid URL: \(fullURL)", category: .network)
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add idempotency key for duplicate prevention
        if let key = idempotencyKey {
            request.setValue(key, forHTTPHeaderField: "X-Idempotency-Key")
            DWLogger.shared.debug("🔑 Idempotency key added for duplicate prevention", category: .network)
        }

        // Add authentication if required
        if requiresAuth {
            do {
                let token = try await getAuthToken()
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                DWLogger.shared.debug("✅ Authorization header added", category: .network)
            } catch {
                DWLogger.shared.error("Failed to get auth token", error: error, category: .auth)
                throw error
            }
        } else {
            DWLogger.shared.debug("ℹ️ Request without authentication", category: .network)
        }

        // Add device ID for abuse prevention.
        // The backend uses this header to track device usage for new accounts.
        // IMPORTANT: Always send this to ensure backend can prevent coin recycling abuse
        if let deviceId = UIDevice.current.identifierForVendor?.uuidString {
            request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
            DWLogger.shared.debug("📱 Device ID added to headers for abuse prevention", category: .network)
        }
        
        // For optional auth endpoints, try to get token if available
        if !requiresAuth && Auth.auth().currentUser != nil {
            // User is authenticated, add token even for optional auth endpoints
            if let token = try? await getAuthToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                DWLogger.shared.debug("✅ Optional auth header added for authenticated user", category: .network)
            }
        }
        
        // Encode body if present
        if let body = body {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            do {
                request.httpBody = try encoder.encode(body)
                DWLogger.shared.debug("📦 Request body encoded", category: .network)
            } catch {
                DWLogger.shared.error("Failed to encode request body", error: error, category: .network)
                throw error
            }
        }
        
        // Perform request
        let startTime = Date()
        
        do {
            let (data, response) = try await session.data(for: request)
            let duration = Date().timeIntervalSince(startTime)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DWLogger.shared.error("Invalid response from server", category: .network)
                throw APIError.invalidResponse
            }
            
            let dataSize = DWLogger.formatBytes(Int64(data.count))
            let formattedDuration = String(format: "%.2f", duration)
            
            // Log response details
            if (200...299).contains(httpResponse.statusCode) {
                DWLogger.shared.info(
                    "✅ \(httpResponse.statusCode) - \(dataSize) in \(formattedDuration)s",
                    category: .network
                )
            } else {
                DWLogger.shared.error(
                    "❌ \(httpResponse.statusCode) - \(endpoint)",
                    category: .network
                )

                // Log error response body
                if let responseString = String(data: data, encoding: .utf8) {
                    DWLogger.shared.debug("Error response: \(responseString)", category: .network)
                }

                // Handle specific error codes
                if httpResponse.statusCode == 400 {
                    // Try to parse new standardized error response
                    if let errorResponse = try? JSONDecoder().decode(StoryErrorResponse.self, from: data),
                       let storyError = StoryError.from(response: errorResponse) {
                        DWLogger.shared.warning("[\(storyError.type.rawValue)] \(storyError.title)", category: .network)
                        throw APIError.storyError(storyError)
                    }
                    
                    // Fallback: Try to parse old ContentSafetyError format
                    if let safetyResponse = try? JSONDecoder().decode(ContentSafetyErrorResponse.self, from: data),
                       safetyResponse.code == "CONTENT_SAFETY_VIOLATION" {
                        let safetyError = ContentSafetyError(from: safetyResponse.error)
                        DWLogger.shared.warning("Content safety violation: \(safetyError.title)", category: .network)
                        throw APIError.contentSafety(safetyError)
                    }

                    // Fallback: Try to parse InsufficientCoins error
                    if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
                       errorResponse["code"] == "INSUFFICIENT_COINS" {
                        DWLogger.shared.warning("Insufficient coins", category: .network)
                        throw APIError.insufficientCoins
                    }
                }

                // Handle 402 - Payment Required (Insufficient Coins)
                if httpResponse.statusCode == 402 {
                    // Try to parse INSUFFICIENT_COINS error
                    if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
                       errorResponse["code"] == "INSUFFICIENT_COINS" {
                        DWLogger.shared.warning("Insufficient coins (402)", category: .network)
                        throw APIError.insufficientCoins
                    }
                    // Default to insufficient coins for 402
                    DWLogger.shared.warning("Payment required (402)", category: .network)
                    throw APIError.insufficientCoins
                }

                // Handle 429 - Job in progress
                if httpResponse.statusCode == 429 {
                    if let errorResponse = try? JSONDecoder().decode(JobInProgressResponse.self, from: data),
                       errorResponse.code == "JOB_IN_PROGRESS",
                       let jobId = errorResponse.data?.jobId {
                        DWLogger.shared.warning("Job already in progress: \(jobId)", category: .network)
                        throw APIError.jobInProgress(jobId: jobId)
                    }
                }

                throw APIError.serverError(httpResponse.statusCode)
            }
            
            // Decode response
            let decoder = JSONDecoder()
            // Use flexible date decoding for Firebase/backend compatibility
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()

                // Try Firestore Timestamp object first (most likely for Firebase backend)
                if let timestampDict = try? container.decode([String: Int].self),
                   let seconds = timestampDict["_seconds"] {
                    return Date(timeIntervalSince1970: TimeInterval(seconds))
                }

                // Try ISO8601 string
                if let dateString = try? container.decode(String.self) {
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let date = formatter.date(from: dateString) {
                        return date
                    }
                    // Try without fractional seconds
                    formatter.formatOptions = [.withInternetDateTime]
                    if let date = formatter.date(from: dateString) {
                        return date
                    }
                }

                // Try timestamp (milliseconds)
                if let timestamp = try? container.decode(Double.self) {
                    return Date(timeIntervalSince1970: timestamp / 1000.0)
                }

                // Try timestamp (seconds)
                if let timestamp = try? container.decode(Int.self) {
                    return Date(timeIntervalSince1970: TimeInterval(timestamp))
                }

                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date")
            }
            
            do {
                let result = try decoder.decode(T.self, from: data)
                DWLogger.shared.debug("✅ Successfully decoded \(T.self)", category: .network)
                return result
            } catch let DecodingError.keyNotFound(key, context) {
                DWLogger.shared.error("Decoding error for \(T.self) - Missing key: \(key.stringValue)", category: .network)
                DWLogger.shared.debug("Context: \(context.debugDescription)", category: .network)
                DWLogger.shared.debug("CodingPath: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))", category: .network)
                
                // Log raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    let preview = String(responseString.prefix(1000))
                    DWLogger.shared.debug("Raw response: \(preview)...", category: .network)
                }
                
                throw APIError.decodingError
            } catch let DecodingError.typeMismatch(type, context) {
                DWLogger.shared.error("Decoding error for \(T.self) - Type mismatch: \(type)", category: .network)
                DWLogger.shared.debug("Context: \(context.debugDescription)", category: .network)
                DWLogger.shared.debug("CodingPath: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))", category: .network)
                
                // Log raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    let preview = String(responseString.prefix(1000))
                    DWLogger.shared.debug("Raw response: \(preview)...", category: .network)
                }
                
                throw APIError.decodingError
            } catch let DecodingError.valueNotFound(type, context) {
                DWLogger.shared.error("Decoding error for \(T.self) - Value not found: \(type)", category: .network)
                DWLogger.shared.debug("Context: \(context.debugDescription)", category: .network)
                DWLogger.shared.debug("CodingPath: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))", category: .network)
                
                // Log raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    let preview = String(responseString.prefix(1000))
                    DWLogger.shared.debug("Raw response: \(preview)...", category: .network)
                }
                
                throw APIError.decodingError
            } catch {
                DWLogger.shared.error("Decoding error for \(T.self)", error: error, category: .network)
                
                // Log raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    let preview = String(responseString.prefix(1000))
                    DWLogger.shared.debug("Raw response: \(preview)...", category: .network)
                }
                
                throw APIError.decodingError
            }
            
        } catch let error as APIError {
            throw error
        } catch let urlError as URLError {
            // Handle URLError specifically to detect network issues
            DWLogger.shared.error("Network request failed", error: urlError, category: .network)

            // Check if it's a network connectivity issue
            if [.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotConnectToHost].contains(urlError.code) {
                throw APIError.networkError
            }

            throw APIError.networkError
        } catch {
            DWLogger.shared.error("Network request failed", error: error, category: .network)
            throw APIError.networkError
        }
    }
    
    // MARK: - Subscription
    
    func getSubscription() async throws -> Subscription {
        struct Response: Codable {
            let success: Bool
            let subscription: Subscription
        }
        
        let response: Response = try await makeRequest(
            endpoint: "/api/user/subscription"
        )
        
        return response.subscription
    }
    
    func verifySubscription(_ request: VerifySubscriptionRequest) async throws -> VerifySubscriptionResponse {
        return try await makeRequest(
            endpoint: "/api/user/subscription/verify",
            method: .post,
            body: request
        )
    }
    
    // MARK: - Stories
    
    func getUserStories(userId: String, summary: Bool = false) async throws -> [Story] {
        struct Response: Codable {
            let success: Bool
            let stories: [Story]
        }
        
        let endpoint = "/api/stories/user/\(userId)" + (summary ? "?summary=true" : "")
        
        let response: Response = try await makeRequest(
            endpoint: endpoint
        )
        
        return response.stories
    }
    
    // MARK: - Favorites
    
    func getUserFavorites() async throws -> [Story] {
        struct Response: Codable {
            let success: Bool
            let favorites: [Story]
            let count: Int?
        }
        
        let response: Response = try await makeRequest(
            endpoint: "/api/favorites"
        )
        
        return response.favorites
    }
    
    // MARK: - Characters
    
    func getSavedCharacters() async throws -> [Character] {
        struct Response: Codable {
            let success: Bool
            let characters: [Character]
            let count: Int?
        }

        let response: Response = try await makeRequest(
            endpoint: "/api/characters"
        )

        return response.characters
    }
    
    func saveCharacter(_ character: Character) async throws -> Character {
        struct Response: Codable {
            let success: Bool
            let character: Character
        }
        
        let response: Response = try await makeRequest(
            endpoint: "/api/characters",
            method: .post,
            body: character
        )
        
        return response.character
    }
    
    func deleteCharacter(id: String) async throws {
        struct Response: Codable {
            let success: Bool
        }

        let _: Response = try await makeRequest(
            endpoint: "/api/characters/\(id)",
            method: .delete
        )
    }

    // MARK: - Transactions

    func getCoinTransactions() async throws -> [CoinTransaction] {
        // Get the raw data from the endpoint
        let fullURL = "\(baseURL)/api/coins/transactions"
        guard let url = URL(string: fullURL) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add auth token
        let token = try await getAuthToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        DWLogger.shared.info("🌐 GET /api/coins/transactions", category: .network)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            DWLogger.shared.error("❌ \(httpResponse.statusCode) - /api/coins/transactions", category: .network)
            throw APIError.serverError(httpResponse.statusCode)
        }

        // Parse as JSON and manually extract valid transactions
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [Any] else {
            DWLogger.shared.error("Failed to parse transactions response", category: .network)
            throw APIError.decodingError
        }

        let decoder = JSONDecoder()
        var validTransactions: [CoinTransaction] = []

        for (index, item) in dataArray.enumerated() {
            // Skip items that are not dictionaries (invalid data)
            guard let itemDict = item as? [String: Any] else {
                DWLogger.shared.warning("⚠️ Skipping invalid transaction at index \(index) - not a dictionary", category: .network)
                continue
            }

            do {
                let itemData = try JSONSerialization.data(withJSONObject: itemDict)
                let transaction = try decoder.decode(CoinTransaction.self, from: itemData)
                validTransactions.append(transaction)
            } catch {
                DWLogger.shared.warning("⚠️ Skipping invalid transaction at index \(index) - decode error", category: .network)
            }
        }

        if validTransactions.count < dataArray.count {
            DWLogger.shared.warning(
                "⚠️ Filtered out \(dataArray.count - validTransactions.count) invalid transactions",
                category: .network
            )
        }

        DWLogger.shared.info("✅ Loaded \(validTransactions.count) valid transactions", category: .network)

        return validTransactions
    }

    // MARK: - Retry Logic Helper
    
    // MARK: - Helper Methods

    /// Check if an error is a network connectivity error
    static func isNetworkError(_ error: Error) -> Bool {
        if let apiError = error as? APIError, case .networkError = apiError {
            return true
        }
        if let urlError = error as? URLError {
            return [.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotConnectToHost].contains(urlError.code)
        }
        return false
    }

    private func shouldRetry(error: Error, endpoint: String = "", method: HTTPMethod = .get) -> Bool {
        // ⚠️ CRITICAL: Never retry POST requests that create resources
        // Story creation should NEVER be retried automatically - it can cause duplicates
        if method == .post && (endpoint.contains("/stories/create") || endpoint.contains("/stories")) {
            DWLogger.shared.warning("Not retrying story creation request - would cause duplicates", category: .network)
            return false
        }
        
        if let apiError = error as? APIError {
            switch apiError {
            case .serverError(let statusCode):
                // Retry on server errors (5xx) but NOT for POST requests that modify state
                // 429 = rate limit, 5xx = server error
                // Only retry for GET requests
                return method == .get && (statusCode >= 500 || statusCode == 429)
            case .networkError:
                // Retry on network errors only for GET requests
                return method == .get
            case .insufficientCoins, .jobInProgress, .contentSafety, .storyError:
                // Never retry business logic errors
                return false
            default:
                return false
            }
        }
        
        // Retry on URLError network issues ONLY for GET requests
        if let urlError = error as? URLError {
            guard method == .get else { return false }
            switch urlError.code {
            case .timedOut, .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
                return true
            default:
                return false
            }
        }
        
        return false
    }
}

// MARK: - Supporting Types

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case invalidResponse
    case serverError(Int)
    case decodingError
    case networkError
    case contentSafety(ContentSafetyError)
    case insufficientCoins
    case jobInProgress(jobId: String)
    case storyError(StoryError)  // NEW: Structured error with user-friendly messages

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "error_invalid_request".localized
        case .unauthorized:
            return "error_auth".localized
        case .invalidResponse:
            return "error_server".localized
        case .serverError(let code):
            // User-friendly messages based on HTTP status code
            return getUserFriendlyServerError(code: code)
        case .decodingError:
            return "error_data_processing".localized
        case .networkError:
            return "error_network".localized
        case .contentSafety(let error):
            return error.errorDescription
        case .storyError(let error):
            return error.errorDescription
        case .insufficientCoins:
            return "error_insufficient_coins".localized
        case .jobInProgress:
            return "Zaten bir hikaye oluşturuluyor"
        }
    }

    /// Convert HTTP status codes to user-friendly messages
    private func getUserFriendlyServerError(code: Int) -> String {
        switch code {
        case 400...499:
            // Client errors - user can fix
            switch code {
            case 400:
                return "error_invalid_request".localized
            case 401, 403:
                return "error_auth".localized
            case 404:
                return "error_template_not_found".localized
            case 429:
                return "login_error_too_many_requests".localized
            default:
                return "error_invalid_request".localized
            }
        case 500...599:
            // Server errors - backend issue
            return "error_server".localized
        default:
            return "error_generic".localized
        }
    }
}

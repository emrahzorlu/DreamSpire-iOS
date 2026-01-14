//
//  RequestBatcher.swift
//  DreamSpire
//
//  Request batching utility for optimizing API calls
//

import Foundation

class RequestBatcher {
    static let shared = RequestBatcher()

    private init() {}

    // Batch multiple requests together to reduce API calls
    func batchRequests<T>(_ requests: [() async throws -> T]) async throws -> [T] {
        var results: [T] = []

        for request in requests {
            let result = try await request()
            results.append(result)
        }

        return results
    }

    // Clear all cache
    func clearCache() {
        // No-op for now - cache functionality not implemented
    }

    // Clear cache for specific key
    func clearCache(for key: String) {
        // No-op for now - cache functionality not implemented
    }
}

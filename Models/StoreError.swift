//
//  StoreError.swift
//  DreamSpire
//
//  Shared StoreKit Error Types
//

import Foundation

enum StoreError: Error, LocalizedError {
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Failed to verify transaction"
        }
    }
}

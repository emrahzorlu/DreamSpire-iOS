//
//  VisualProfile.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//

import Foundation

/// AI-generated visual DNA for character consistency across illustrations
struct VisualProfile: Codable {
    let character: String
    let appearance: Appearance
    let face: Face
    let hair: Hair
    let clothing: Clothing
    let distinctiveFeatures: [String]
    
    struct Appearance: Codable {
        let age: String
        let gender: String
        let ethnicity: String
        let height: String
        let build: String
    }
    
    struct Face: Codable {
        let shape: String
        let eyes: Eyes
        let nose: String
        let mouth: String
        let skin: String
        
        struct Eyes: Codable {
            let color: String
            let shape: String
            let expression: String
        }
    }
    
    struct Hair: Codable {
        let color: String
        let length: String
        let style: String
        let texture: String
    }
    
    struct Clothing: Codable {
        let primary: String
        let colorScheme: [String]
        let style: String
        let signatureItem: String
    }
}

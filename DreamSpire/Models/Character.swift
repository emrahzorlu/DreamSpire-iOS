//
//  Character.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//

import Foundation

struct Character: Codable, Identifiable {
    var id: String
    var name: String
    var type: CharacterType
    var relationship: CharacterRelationship?  // NEW: Separate relationship field
    var gender: CharacterGender?
    var age: Int?
    var description: String?
    var extraFields: [String: String]?

    // For saved characters (Plus/Pro)
    var visualProfile: VisualProfile?
    var timesUsed: Int?
    var lastUsed: Date?

    // Backend fields
    var userId: String?
    var storiesCreated: [String]?
    var tier: String?
    var createdAt: Date?
    var updatedAt: Date?
    
    // Tracks the original saved character ID when this character was copied from saved characters
    // Used for incrementing usage count after story creation
    var savedCharacterId: String?

    init(
        id: String = UUID().uuidString,
        name: String = "",
        type: CharacterType,
        relationship: CharacterRelationship? = nil,
        gender: CharacterGender? = nil,
        age: Int? = nil,
        description: String? = nil,
        visualProfile: VisualProfile? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.relationship = relationship
        self.gender = gender
        self.age = age
        self.description = description
        self.visualProfile = visualProfile
        self.timesUsed = 0
    }

    // Custom coding keys for backend compatibility
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case relationship
        case gender
        case age
        case description
        case extraFields
        case visualProfile
        case timesUsed
        case lastUsed
        case userId
        case storiesCreated
        case tier
        case createdAt
        case updatedAt
        case savedCharacterId
    }

    // Check if character is saved (has backend data)
    var isSaved: Bool {
        return userId != nil && createdAt != nil
    }
    
    /// Display name combining type and relationship
    var displayDescription: String {
        var parts: [String] = [type.displayName]
        if let rel = relationship, rel != .none {
            parts.append("(\(rel.displayName))")
        }
        return parts.joined(separator: " ")
    }
}

// MARK: - Character Type (Age/Role Based)

enum CharacterType: String, Codable, CaseIterable {
    // People
    case child
    case teen
    case adult
    case mother
    case father
    case sibling
    case grandmother
    case grandfather
    
    // Pets
    case dog
    case cat
    case bird
    case horse
    case rabbit
    case otherPet = "other_pet"
    
    var icon: String {
        switch self {
        case .child: return "👶"
        case .teen: return "🧑"
        case .adult: return "🧑‍🦱"
        case .mother: return "👩"
        case .father: return "👨"
        case .sibling: return "👧👦"
        case .grandmother: return "👵"
        case .grandfather: return "👴"
        case .dog: return "🐶"
        case .cat: return "🐱"
        case .bird: return "🦜"
        case .horse: return "🐴"
        case .rabbit: return "🐰"
        case .otherPet: return "🐾"
        }
    }
    
    var displayName: String {
        switch self {
        case .child: return "character_type_child".localized
        case .teen: return "character_type_teen".localized
        case .adult: return "character_type_adult".localized
        case .mother: return "character_type_mother".localized
        case .father: return "character_type_father".localized
        case .sibling: return "character_type_sibling".localized
        case .grandmother: return "character_type_grandmother".localized
        case .grandfather: return "character_type_grandfather".localized
        case .dog: return "character_type_dog".localized
        case .cat: return "character_type_cat".localized
        case .bird: return "character_type_bird".localized
        case .horse: return "character_type_horse".localized
        case .rabbit: return "character_type_rabbit".localized
        case .otherPet: return "character_type_other_pet".localized
        }
    }
    
    var category: CharacterCategory {
        switch self {
        case .child, .teen, .adult, .mother, .father, .sibling, .grandmother, .grandfather:
            return .people
        case .dog, .cat, .bird, .horse, .rabbit, .otherPet:
            return .pets
        }
    }
    
    var needsGender: Bool {
        switch self {
        case .child, .teen, .adult, .sibling:
            return true
        case .mother, .father, .grandmother, .grandfather:
            return false
        case .dog, .cat, .bird, .horse, .rabbit, .otherPet:
            return false
        }
    }
    
    var defaultGender: CharacterGender? {
        switch self {
        case .mother, .grandmother:
            return .female
        case .father, .grandfather:
            return .male
        default:
            return nil
        }
    }
    
    /// Whether this type can have a relationship (people only)
    var canHaveRelationship: Bool {
        return category == .people
    }
}

// MARK: - Character Relationship (Optional, for people only)

enum CharacterRelationship: String, Codable, CaseIterable {
    case none
    case friend
    case partner
    case familyMember = "family_member"
    
    var icon: String {
        switch self {
        case .none: return "➖"
        case .friend: return "👯"
        case .partner: return "💑"
        case .familyMember: return "👨‍👩‍👧"
        }
    }
    
    var displayName: String {
        switch self {
        case .none: return "character_relationship_none".localized
        case .friend: return "character_relationship_friend".localized
        case .partner: return "character_relationship_partner".localized
        case .familyMember: return "character_relationship_family".localized
        }
    }
    
    /// Cases to show in picker (excluding none)
    static var selectableCases: [CharacterRelationship] {
        return [.friend, .partner, .familyMember]
    }
}

// MARK: - Character Category

enum CharacterCategory: String, CaseIterable, Identifiable {
    case people
    case pets
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .people: return "character_category_people".localized
        case .pets: return "character_category_pets".localized
        }
    }
}

// MARK: - Character Gender

enum CharacterGender: String, Codable {
    case male
    case female
    case unspecified
    
    var icon: String {
        switch self {
        case .male: return "👦"
        case .female: return "👧"
        case .unspecified: return "⚪"
        }
    }
    
    var displayName: String {
        switch self {
        case .male: return "character_gender_male".localized
        case .female: return "character_gender_female".localized
        case .unspecified: return "character_gender_unspecified".localized
        }
    }
}

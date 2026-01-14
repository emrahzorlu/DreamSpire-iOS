//
//  Template.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025-11-02.
//

import Foundation

struct Template: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let emoji: String
    
    let category: TemplateCategory
    let tier: SubscriptionTier
    
    let fixedParams: FixedParams
    let characterSchema: CharacterSchema
    
    let isPremium: Bool?
    let usageCount: Int?
    let previewImageUrl: String?
    
    var isLocked: Bool {
        tier != .free
    }
    
    struct FixedParams: Codable {
        let genre: String
        let tone: String
        let ageRange: String
        let defaultMinutes: Int
        let language: String
    }
}

enum TemplateCategory: String, Codable, CaseIterable {
    case uyku = "Uyku Vakti"
    case macera = "Macera"
    case aile = "Aile"
    case dostluk = "Dostluk"
    case fantastik = "Fantastik"
    case hayvanlar = "Hayvanlar"
    case prenses = "Prenses"
    case klasik = "Klasik"
    case unknown = "Unknown"
    
    // Custom decoder to handle localized category names
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        // Try direct match first
        if let category = TemplateCategory(rawValue: rawValue) {
            self = category
            return
        }
        
        // Map localized names to categories
        let categoryMap: [String: TemplateCategory] = [
            // Turkish
            "Uyku Vakti": .uyku, "Macera": .macera, "Aile": .aile, "Dostluk": .dostluk,
            "Fantastik": .fantastik, "Hayvanlar": .hayvanlar, "Prenses": .prenses, "Klasik": .klasik,
            // English
            "Bedtime": .uyku, "Adventure": .macera, "Family": .aile, "Friendship": .dostluk,
            "Fantasy": .fantastik, "Animals": .hayvanlar, "Princess": .prenses, "Classic": .klasik,
            // French
            "Coucher": .uyku, "Aventure": .macera, "Famille": .aile, "Amitié": .dostluk,
            "Fantastique": .fantastik, "Animaux": .hayvanlar, "Princesse": .prenses, "Classique": .klasik,
            // German
            "Gute Nacht": .uyku, "Abenteuer": .macera, "Familie": .aile, "Freundschaft": .dostluk,
            "Fantasie": .fantastik, "Tiere": .hayvanlar, "Prinzessin": .prenses, "Klassisch": .klasik,
            // Spanish
            "Hora de Dormir": .uyku, "Aventura": .macera, "Familia": .aile, "Amistad": .dostluk,
            "Fantasía": .fantastik, "Animales": .hayvanlar, "Princesa": .prenses, "Clásico": .klasik
        ]
        
        self = categoryMap[rawValue] ?? .unknown
    }
    
    var displayName: String {
        switch self {
        case .uyku: return "template_category_bedtime".localized
        case .macera: return "template_category_adventure".localized
        case .aile: return "template_category_family".localized
        case .dostluk: return "template_category_friendship".localized
        case .fantastik: return "template_category_fantasy".localized
        case .hayvanlar: return "template_category_animals".localized
        case .prenses: return "template_category_princess".localized
        case .klasik: return "template_category_classic".localized
        case .unknown: return "all".localized
        }
    }
    
    var icon: String {
        switch self {
        case .uyku:
            return "moon.stars.fill"
        case .macera:
            return "map.fill"
        case .aile:
            return "house.fill"
        case .dostluk:
            return "heart.fill"
        case .fantastik:
            return "sparkles"
        case .hayvanlar:
            return "hare.fill"
        case .prenses:
            return "crown.fill"
        case .klasik:
            return "book.closed.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }
}

struct CharacterSchema: Codable {
    let minCharacters: Int
    let maxCharacters: Int
    let requiredSlots: [CharacterSlot]
    let optionalSlots: [CharacterSlot]
    
    var allSlots: [CharacterSlot] {
        requiredSlots + optionalSlots
    }
}

struct CharacterSlot: Codable, Identifiable {
    let id: String
    let role: String
    let description: String
    let required: Bool

    var displayName: String {
        // Try to localize the role using a mapping system
        // This handles hardcoded roles from backend (Turkish, German, etc.)
        let roleMap: [String: String] = [
            // Child variations
            "Çocuk": "template_role_child".localized,
            "Kind": "template_role_child".localized,
            "Enfant": "template_role_child".localized,
            "Niño/a": "template_role_child".localized,
            "Child": "template_role_child".localized,

            // Parent variations
            "Anne veya Baba": "template_role_parent".localized,
            "Anne/Baba": "template_role_parent".localized,
            "Ebeveyn": "template_role_parent".localized,
            "Elternteil": "template_role_parent".localized,
            "Parent": "template_role_parent".localized,
            "Padre/Madre": "template_role_parent".localized,

            // Sibling variations
            "Kardeş": "template_role_sibling".localized,
            "Geschwister": "template_role_sibling".localized,
            "Frère/Sœur": "template_role_sibling".localized,
            "Hermano/a": "template_role_sibling".localized,
            "Sibling": "template_role_sibling".localized,

            // Friend variations
            "Arkadaş": "template_role_friend".localized,
            "Freund(in)": "template_role_friend".localized,
            "Ami(e)": "template_role_friend".localized,
            "Amigo/a": "template_role_friend".localized,
            "Friend": "template_role_friend".localized,

            // Princess variations
            "Prenses": "template_role_princess".localized,
            "Prinzessin": "template_role_princess".localized,
            "Princesse": "template_role_princess".localized,
            "Princesa": "template_role_princess".localized,
            "Princess": "template_role_princess".localized,

            // Fairy variations
            "Peri": "template_role_fairy".localized,
            "Fee": "template_role_fairy".localized,
            "Fée": "template_role_fairy".localized,
            "Hada": "template_role_fairy".localized,
            "Fairy": "template_role_fairy".localized,

            // Grandma variations
            "Büyükanne": "template_role_grandma".localized,
            "Oma": "template_role_grandma".localized,
            "Grand-mère": "template_role_grandma".localized,
            "Abuela": "template_role_grandma".localized,
            "Grandma": "template_role_grandma".localized,

            // Alien variations
            "Uzaylı Arkadaş": "template_role_alien".localized,
            "Alien-Freund": "template_role_alien".localized,
            "Ami Extraterrestre": "template_role_alien".localized,
            "Amigo Alienígena": "template_role_alien".localized,
            "Alien Friend": "template_role_alien".localized,

            // Animal variations
            "Orman Arkadaşı": "template_role_animal".localized,
            "Waldfreund": "template_role_animal".localized,
            "Ami de la Forêt": "template_role_animal".localized,
            "Amigo del Bosque": "template_role_animal".localized,
            "Forest Friend": "template_role_animal".localized,

            // Astronaut variations
            "Astronot": "template_role_astronaut".localized,
            "Astronaut": "template_role_astronaut".localized,
            "Astronaute": "template_role_astronaut".localized,
            "Astronauta": "template_role_astronaut".localized,

            // Baby variations
            "Bebek": "template_role_baby".localized,
            "Baby": "template_role_baby".localized,
            "Bébé": "template_role_baby".localized,

            // Classmate variations
            "Sınıf Arkadaşı": "template_role_classmate".localized,
            "Klassenkamerad": "template_role_classmate".localized,
            "Camarade de Classe": "template_role_classmate".localized,
            "Compañero de Clase": "template_role_classmate".localized,
            "Classmate": "template_role_classmate".localized,

            // Companion variations
            "Uyku Arkadaşı": "template_role_companion".localized,
            "Schlafbegleiter": "template_role_companion".localized,
            "Compagnon de Nuit": "template_role_companion".localized,
            "Compañero de Sueños": "template_role_companion".localized,
            "Bedtime Companion": "template_role_companion".localized,

            // Diver variations
            "Dalgıç": "template_role_diver".localized,
            "Taucher": "template_role_diver".localized,
            "Plongeur": "template_role_diver".localized,
            "Buzo": "template_role_diver".localized,
            "Diver": "template_role_diver".localized,

            // Dragon variations
            "Ejderha": "template_role_dragon".localized,
            "Drache": "template_role_dragon".localized,
            "Dragon": "template_role_dragon".localized,
            "Dragón": "template_role_dragon".localized,

            // Helper variations
            "Yardımcı": "template_role_helper".localized,
            "Helfer": "template_role_helper".localized,
            "Assistant": "template_role_helper".localized,
            "Ayudante": "template_role_helper".localized,
            "Helper": "template_role_helper".localized,

            // Hero variations
            "Kahraman": "template_role_hero".localized,
            "Held": "template_role_hero".localized,
            "Héros": "template_role_hero".localized,
            "Héroe": "template_role_hero".localized,
            "Hero": "template_role_hero".localized,

            // Mentor variations
            "Rehber": "template_role_mentor".localized,
            "Mentor": "template_role_mentor".localized,

            // Mermaid variations
            "Deniz Kızı": "template_role_mermaid".localized,
            "Meerjungfrau": "template_role_mermaid".localized,
            "Sirène": "template_role_mermaid".localized,
            "Sirena": "template_role_mermaid".localized,
            "Mermaid": "template_role_mermaid".localized,

            // Pet variations
            "Evcil Hayvan": "template_role_pet".localized,
            "Haustier": "template_role_pet".localized,
            "Animal de Compagnie": "template_role_pet".localized,
            "Mascota": "template_role_pet".localized,
            "Pet": "template_role_pet".localized,

            // Robot variations
            "Robot Arkadaş": "template_role_robot".localized,
            "Roboter-Freund": "template_role_robot".localized,
            "Ami Robot": "template_role_robot".localized,
            "Amigo Robot": "template_role_robot".localized,
            "Robot Friend": "template_role_robot".localized,

            // Older Sibling variations
            "Ağabey/Abla": "template_role_older_sibling".localized,
            "Ältere(r) Geschwister": "template_role_older_sibling".localized,
            "Grand(e) Frère/Sœur": "template_role_older_sibling".localized,
            "Hermano/a Mayor": "template_role_older_sibling".localized,
            "Older Sibling": "template_role_older_sibling".localized,

            // Younger Sibling variations
            "Küçük Kardeş": "template_role_younger_sibling".localized,
            "Jüngere(r) Geschwister": "template_role_younger_sibling".localized,
            "Petit(e) Frère/Sœur": "template_role_younger_sibling".localized,
            "Hermano/a Menor": "template_role_younger_sibling".localized,
            "Younger Sibling": "template_role_younger_sibling".localized
        ]

        return roleMap[role] ?? role
    }

    var placeholder: String {
        return String(format: "character_name_placeholder".localized, displayName)
    }
}

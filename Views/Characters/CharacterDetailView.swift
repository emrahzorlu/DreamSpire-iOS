//
//  CharacterDetailView.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025-11-02
//

import SwiftUI

struct CharacterDetailView: View {
    let character: Character
    var onDelete: (() -> Void)? = nil
    var onUpdate: ((Character) -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    
    @State private var showingEditSheet = false
    
    var body: some View {
        ZStack {
            LinearGradient.dwBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Character Icon & Name
                        characterHeaderView
                        
                        // Visual Profile (if exists)
                        if let profile = character.visualProfile {
                            visualProfileView(profile)
                        }
                        
                        // Basic Info
                        basicInfoView
                        
                        // Stats
                        statsView

                        // Edit Button
                        editButtonView
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            CharacterEditView(character: character, onUpdate: onUpdate)
        }
        .withGlassDialogs()
        .withGlassAlerts()
        .preferredColorScheme(.light)
    }
    
    // MARK: - Delete Confirmation
    
    private func confirmDelete() {
        GlassDialogManager.shared.confirm(
            title: "character_delete_title".localized,
            message: "character_delete_confirm".localized,
            confirmTitle: "delete".localized,
            confirmAction: {
                onDelete?()
                dismiss()
            },
            isDestructive: true
        )
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            Menu {
                Button(action: { showingEditSheet = true }) {
                    Label("edit".localized, systemImage: "pencil")
                }
                
                Button(role: .destructive, action: { confirmDelete() }) {
                    Label("delete".localized, systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 16)
    }
    
    // MARK: - Character Header
    
    private var characterHeaderView: some View {
        VStack(spacing: 16) {
            Text(character.type.icon)
                .font(.system(size: 100))
            
            Text(character.name)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            Text(character.type.displayName)
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.top, 20)
    }
    
    // MARK: - Visual Profile
    
    private func visualProfileView(_ profile: VisualProfile) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("character_dna".localized)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("ai_generated".localized)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
            
            VStack(spacing: 12) {
                ProfileSection(
                    title: "character_appearance".localized,
                    items: [
                        ("character_age".localized, profile.appearance.age),
                        ("character_gender".localized, profile.appearance.gender),
                        ("character_ethnicity".localized, profile.appearance.ethnicity),
                        ("character_height".localized, profile.appearance.height),
                        ("character_build".localized, profile.appearance.build)
                    ]
                )
                
                ProfileSection(
                    title: "character_face".localized,
                    items: [
                        ("character_face_shape".localized, profile.face.shape),
                        ("character_eye_color".localized, profile.face.eyes.color),
                        ("character_eye_shape".localized, profile.face.eyes.shape),
                        ("character_nose".localized, profile.face.nose),
                        ("character_mouth".localized, profile.face.mouth),
                        ("character_skin".localized, profile.face.skin)
                    ]
                )
                
                ProfileSection(
                    title: "character_hair".localized,
                    items: [
                        ("character_hair_color".localized, profile.hair.color),
                        ("character_hair_length".localized, profile.hair.length),
                        ("character_hair_style".localized, profile.hair.style),
                        ("character_hair_texture".localized, profile.hair.texture)
                    ]
                )
                
                ProfileSection(
                    title: "character_clothing".localized,
                    items: [
                        ("character_clothing_primary".localized, profile.clothing.primary),
                        ("character_clothing_colors".localized, profile.clothing.colorScheme.joined(separator: ", ")),
                        ("character_clothing_style".localized, profile.clothing.style),
                        ("character_clothing_signature".localized, profile.clothing.signatureItem)
                    ]
                )
                
                if !profile.distinctiveFeatures.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("distinctive_features".localized)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        
                        ForEach(profile.distinctiveFeatures, id: \.self) { feature in
                            Text("• \(feature)")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .dwGlassCard()
    }
    
    // MARK: - Basic Info
    
    private var basicInfoView: some View {
        VStack(spacing: 12) {
            if let age = character.age {
                InfoRow(icon: "calendar", label: "age".localized, value: "\(age)")
            }
            
            if let description = character.description, !description.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "text.alignleft")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                        Text("description".localized)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
            }
        }
        .padding(16)
        .dwGlassCard()
    }
    
    // MARK: - Stats
    
    private var statsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("statistics".localized)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                // Use storiesCreated array count for accurate stat (backend returns actual story IDs)
                let storyCount = character.storiesCreated?.count ?? character.timesUsed ?? 0
                StatCard(
                    icon: "book.fill",
                    value: "\(storyCount)",
                    label: "used_in_stories".localized
                )
                
                if let lastUsed = character.lastUsed {
                    StatCard(
                        icon: "clock.fill",
                        value: lastUsed.timeAgo,
                        label: "last_used".localized
                    )
                }
            }
        }
        .padding(16)
        .dwGlassCard()
    }
    
    // MARK: - Edit Button

    private var editButtonView: some View {
        Button(action: { showingEditSheet = true }) {
            Text("edit_character".localized)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.2))
                .cornerRadius(12)
        }
    }
}

// MARK: - Profile Section

struct ProfileSection: View {
    let title: String
    let items: [(String, String)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            
            VStack(spacing: 6) {
                ForEach(items, id: \.0) { item in
                    HStack {
                        Text(item.0)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Spacer()
                        
                        Text(item.1)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.95))
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 20)
            
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Date Extension

extension Date {
    var timeAgo: String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day, .hour, .minute], from: self, to: now)
        
        if let days = components.day, days > 0 {
            return "\(days) gün önce"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours) saat önce"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes) dk önce"
        } else {
            return "Az önce"
        }
    }
}

// MARK: - Preview

#Preview {
    CharacterDetailView(character: Character.mockCharacterWithProfile)
}

extension Character {
    static var mockCharacterWithProfile: Character {
        var char = Character(
            id: "char-1",
            name: "Sofia",
            type: .child,
            age: 8,
            description: "Maceracı ve meraklı bir kız. Yeni şeyler keşfetmeyi sever."
        )
        char.timesUsed = 5
        char.lastUsed = Date().addingTimeInterval(-86400 * 3) // 3 days ago
        char.visualProfile = VisualProfile.mockProfile
        return char
    }
}

extension VisualProfile {
    static var mockProfile: VisualProfile {
        VisualProfile(
            character: "Sofia",
            appearance: Appearance(
                age: "8 years old",
                gender: "female",
                ethnicity: "Mediterranean",
                height: "average for age",
                build: "slim and energetic"
            ),
            face: Face(
                shape: "round with soft features",
                eyes: Face.Eyes(
                    color: "emerald green",
                    shape: "large and expressive",
                    expression: "curious and bright"
                ),
                nose: "small and button-like",
                mouth: "wide smile with dimples",
                skin: "warm olive tone"
            ),
            hair: Hair(
                color: "chestnut brown with golden highlights",
                length: "shoulder-length",
                style: "loose waves, often in ponytail",
                texture: "thick and slightly wavy"
            ),
            clothing: Clothing(
                primary: "adventurer outfit",
                colorScheme: ["forest green", "earth brown", "golden yellow"],
                style: "practical yet stylish",
                signatureItem: "red bandana tied around neck"
            ),
            distinctiveFeatures: [
                "Freckles across nose",
                "Always wears explorer's backpack",
                "Bright, infectious smile"
            ]
        )
    }
}

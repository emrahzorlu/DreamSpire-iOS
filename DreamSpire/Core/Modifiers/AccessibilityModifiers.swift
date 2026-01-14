//
//  AccessibilityModifiers.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025.
//

import SwiftUI

// MARK: - Accessibility Button

struct AccessibleButton: ViewModifier {
    let label: String
    let hint: String?
    
    init(label: String, hint: String? = nil) {
        self.label = label
        self.hint = hint
    }
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Accessibility Image

struct AccessibleImage: ViewModifier {
    let label: String
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isImage)
    }
}

// MARK: - Screen Reader Hidden

struct ScreenReaderHidden: ViewModifier {
    func body(content: Content) -> some View {
        content
            .accessibilityHidden(true)
    }
}

// MARK: - View Extensions

extension View {
    /// Make button accessible for VoiceOver
    func accessibleButton(_ label: String, hint: String? = nil) -> some View {
        modifier(AccessibleButton(label: label, hint: hint))
    }
    
    /// Make image accessible for VoiceOver
    func accessibleImage(_ label: String) -> some View {
        modifier(AccessibleImage(label: label))
    }
    
    /// Hide from screen readers (decorative elements)
    func hideFromScreenReader() -> some View {
        modifier(ScreenReaderHidden())
    }
}

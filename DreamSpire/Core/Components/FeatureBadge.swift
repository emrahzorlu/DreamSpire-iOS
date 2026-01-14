//
//  FeatureBadge.swift
//  DreamSpire
//
//  Minimalist feature badge for story cards
//  Shows audio and illustrated features with SF Symbols
//

import SwiftUI

struct FeatureBadge: View {
    let icon: String
    let color: Color

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 16))
            .foregroundColor(color)
            .shadow(color: color.opacity(0.5), radius: 4, x: 0, y: 2)
    }
}

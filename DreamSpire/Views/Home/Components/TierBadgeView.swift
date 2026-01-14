//
//  TierBadgeView.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025.
//

import SwiftUI

/// Badge showing subscription tier (Free, Plus, Pro)
struct TierBadgeView: View {
    let tier: String

    var body: some View {
        Text(tierLabel)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tierBackground)
            .cornerRadius(8)
            .accessibilityLabel("\(tierLabel) içerik")
    }

    private var tierLabel: String {
        switch tier.lowercased() {
        case "free": return "tier_free".localized
        case "plus": return "tier_plus".localized
        case "pro": return "tier_pro".localized
        default: return "tier_free".localized
        }
    }

    private var tierBackground: Color {
        let subscriptionTier = SubscriptionTier(rawValue: tier.lowercased()) ?? .free
        switch subscriptionTier {
        case .free:
            return Color.green.opacity(0.8)
        case .plus:
            return Color.orange.opacity(0.8)
        case .pro:
            return Color.purple.opacity(0.8)
        }
    }
}

#if DEBUG
struct TierBadgeView_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 12) {
            TierBadgeView(tier: "free")
            TierBadgeView(tier: "plus")
            TierBadgeView(tier: "pro")
        }
        .padding()
        .background(Color.black)
    }
}
#endif

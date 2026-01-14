//
//  SubscriptionView.swift
//  DreamSpire
//
//  Modern Subscription Management View
//

import SwiftUI

struct SubscriptionView: View {
    @StateObject private var viewModel = SubscriptionViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var selectedTier: SubscriptionTier = .plus
    
    var body: some View {
        ZStack {
            // Modern gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.4, green: 0.6, blue: 1.0),
                    Color(red: 0.6, green: 0.4, blue: 1.0),
                    Color(red: 0.8, green: 0.4, blue: 0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    headerSection
                    
                    // Main content
                    VStack(spacing: 24) {
                        // Current subscription status
                        currentSubscriptionSection
                        
                        // Subscription options
                        subscriptionOptionsSection
                        
                        // Feature comparison
                        featureComparisonSection
                        
                        // Footer
                        footerSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            
            // Close button
            closeButton
            
            // Loading overlay
            if viewModel.isLoading {
                LoadingOverlay()
            }
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Close Button
    
    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.2))
                        )
                }
                .padding(.trailing, 20)
                .padding(.top, 50)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 20) {
            // Magic sparkle
            VStack(spacing: 8) {
                Text("✨")
                    .font(.system(size: 60))
                
                Text("⭐")
                    .font(.system(size: 24))
                    .offset(x: 30, y: -20)
            }
            .padding(.top, 80)
            
            VStack(spacing: 12) {
                Text("subscription_unlock".localized)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text("subscription_unlimited".localized)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - Current Subscription Section
    
    private var currentSubscriptionSection: some View {
        VStack(spacing: 16) {
            Text("subscription_current".localized)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            // Current subscription card
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("subscription_free_plan".localized)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(String(format: "subscription_monthly_stories".localized, 3))
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Text("subscription_active".localized)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(12)
                }
                
                // Usage info
                VStack(spacing: 8) {
                    HStack {
                        Text("subscription_used_this_month".localized)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Spacer()
                        
                        Text(String(format: "subscription_stories_count".localized, 2, 3))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    // Progress bar
                    ProgressView(value: 2, total: 3)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .scaleEffect(x: 1, y: 2, anchor: .center)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.15))
            )
        }
    }
    
    // MARK: - Subscription Options Section
    
    private var subscriptionOptionsSection: some View {
        VStack(spacing: 16) {
            Text("subscription_upgrade_options".localized)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                // Plus option
                SubscriptionOptionCard(
                    tier: .plus,
                    isSelected: selectedTier == .plus,
                    isRecommended: true,
                    onSelect: { selectedTier = .plus }
                )
                
                // Pro option
                SubscriptionOptionCard(
                    tier: .pro,
                    isSelected: selectedTier == .pro,
                    isRecommended: false,
                    onSelect: { selectedTier = .pro }
                )
            }
            
            // Subscribe button
            subscribeButton
        }
    }
    
    // MARK: - Feature Comparison Section
    
    private var featureComparisonSection: some View {
        VStack(spacing: 20) {
            Text("subscription_compare_features".localized)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            VStack(spacing: 0) {
                // Header row
                featureComparisonHeader
                
                // Feature rows
                featureComparisonRow(
                    title: "subscription_feature_monthly_stories".localized,
                    free: "3",
                    plus: "subscription_feature_unlimited".localized,
                    pro: "subscription_feature_unlimited".localized
                )

                featureComparisonRow(
                    title: "subscription_feature_characters_per_story".localized,
                    free: "2",
                    plus: "4",
                    pro: "6"
                )

                featureComparisonRow(
                    title: "subscription_feature_saved_characters".localized,
                    free: "-",
                    plus: "10",
                    pro: "subscription_feature_unlimited".localized
                )

                featureComparisonRow(
                    title: "subscription_feature_prewritten_stories".localized,
                    free: "15",
                    plus: "50",
                    pro: "subscription_feature_all".localized
                )

                featureComparisonRow(
                    title: "subscription_feature_illustrations".localized,
                    free: "❌",
                    plus: "❌",
                    pro: "✅"
                )

                featureComparisonRow(
                    title: "subscription_feature_premium_voices".localized,
                    free: "❌",
                    plus: "❌",
                    pro: "✅"
                )

                featureComparisonRow(
                    title: "subscription_feature_pdf_export".localized,
                    free: "❌",
                    plus: "✅",
                    pro: "✅"
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
            )
        }
    }
    
    // MARK: - Subscribe Button
    
    private var subscribeButton: some View {
        Button(action: {
            Task {
                await viewModel.subscribe(tier: selectedTier)
            }
        }) {
            Text("subscription_upgrade_now".localized)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        }
        .padding(.top, 8)
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        VStack(spacing: 16) {
            Button("paywall_restore".localized) {
                Task {
                    await viewModel.restorePurchases()
                }
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white.opacity(0.8))
            
            Text("subscription_cancel_anytime".localized)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
    
    // MARK: - Feature Comparison Helpers
    
    private var featureComparisonHeader: some View {
        HStack {
            Text("")
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("subscription_free".localized)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 60)
            
            Text("subscription_plus".localized)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 60)
            
            Text("subscription_pro".localized)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 60)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.1))
    }
    
    private func featureComparisonRow(title: String, free: String, plus: String, pro: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(free)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 60)
            
            Text(plus)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 60)
            
            Text(pro)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 60)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
    }
}

// MARK: - Subscription Option Card

struct SubscriptionOptionCard: View {
    let tier: SubscriptionTier
    let isSelected: Bool
    let isRecommended: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                // Recommended badge
                if isRecommended {
                    recommendedBadge
                }
                
                // Card content
                HStack(spacing: 16) {
                    // Left side - Icon and info
                    HStack(spacing: 12) {
                        Text(tier.icon)
                            .font(.system(size: 32))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tier.displayName)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)

                            Text(priceForTier(tier))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    
                    Spacer()
                    
                    // Right side - Key features
                    VStack(alignment: .trailing, spacing: 4) {
                        if tier == .plus {
                            featureText("subscription_unlimited_stories".localized)
                            featureText(String(format: "subscription_characters_per_story".localized, 4))
                            featureText("subscription_pdf_export".localized)
                        } else {
                            featureText("subscription_plus_illustration".localized)
                            featureText(String(format: "subscription_characters_per_story".localized, 6))
                            featureText("subscription_premium_voices".localized)
                        }
                    }
                }
                .padding(20)
                .background(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
                )
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var recommendedBadge: some View {
        Text("subscription_recommended".localized)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                LinearGradient(
                    colors: [Color.orange, Color.red],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(8)
            .offset(y: -8)
    }
    
    private func featureText(_ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.green)

            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
        }
    }

    private func priceForTier(_ tier: SubscriptionTier) -> String {
        // Use locale-aware currency formatting
        let price = tier.fallbackMonthlyPrice
        let formatted = price.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
        return "\(formatted)/\("paywall_per_month".localized.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "/", with: "").trimmingCharacters(in: .whitespaces))"
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.white.opacity(isSelected ? 0.2 : 0.1))
    }
    
    private var borderColor: Color {
        if isSelected {
            return isRecommended ? Color.orange : Color.purple
        } else {
            return Color.white.opacity(0.3)
        }
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
        }
    }
}

#Preview {
    SubscriptionView()
}

//
//  StoryDurationPickerView.swift
//  DreamSpire
//
//  Created by DreamSpire Team on 11/7/24.
//

import SwiftUI

struct StoryDurationPickerView: View {
    @Binding var selectedDuration: StoryDuration
    @Binding var addons: StoryAddons
    @ObservedObject var coinService = CoinService.shared
    @ObservedObject var subscriptionService = SubscriptionService.shared
    @ObservedObject var localizationManager = LocalizationManager.shared
    
    @State private var calculatedCost: Int = 0
    @State private var showPaywall = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Duration Selection
            durationSection
            
            // Add-ons Section
            addonsSection
            
            // Cost Summary
            costSummary
        }
        .onAppear {
            calculateCost()
        }
        .onChange(of: selectedDuration) { _, _ in
            calculateCost()
        }
        .onChange(of: addons.cover) { _, _ in
            calculateCost()
        }
        .onChange(of: addons.audio) { _, _ in
            calculateCost()
        }
        .onChange(of: addons.illustrated) { _, _ in
            calculateCost()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
    
    // MARK: - Duration Section
    
    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("duration_story_length".localized)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            VStack(spacing: 8) {
                ForEach(StoryDuration.allCases, id: \.self) { duration in
                    DurationCard(
                        duration: duration,
                        isSelected: selectedDuration == duration
                    ) {
                        selectedDuration = duration
                    }
                }
            }
        }
        .padding(20)
        .dwGlassCard()
    }
    
    // MARK: - Addons Section
    
    private var addonsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("duration_extras".localized)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            VStack(spacing: 0) {
                // Cover Image
                AddonToggle(
                    info: AddonInfo.cover,
                    isOn: $addons.cover,
                    isLocked: false,
                    onUpgrade: {}
                )
                
                Divider()
                    .background(Color.white.opacity(0.2))
                    .padding(.horizontal, 16)
                
                // Audio
                AddonToggle(
                    info: AddonInfo.audio,
                    cost: selectedDuration.audioCost,
                    isOn: $addons.audio,
                    isLocked: false,
                    onUpgrade: {}
                )
                
                Divider()
                    .background(Color.white.opacity(0.2))
                    .padding(.horizontal, 16)
                
                // Illustrated (Pro Only)
                AddonToggle(
                    info: AddonInfo.illustrated,
                    cost: selectedDuration.illustratedCost,
                    isOn: $addons.illustrated,
                    isLocked: !subscriptionService.currentTier.canAccessIllustrations,
                    onUpgrade: {
                        DWLogger.shared.logAnalyticsEvent("paywall_triggered", parameters: [
                            "source": "illustrated_addon",
                            "current_tier": subscriptionService.currentTier.rawValue
                        ])
                        showPaywall = true
                    }
                )
            }
        }
        .padding(20)
        .dwGlassCard()
    }
    
    // MARK: - Cost Summary
    
    private var costSummary: some View {
        VStack(spacing: 16) {
            // Breakdown
            if calculatedCost > 0 {
                VStack(spacing: 8) {
                    CostBreakdownRow(
                        label: String(format: "duration_text_with_name".localized, selectedDuration.displayName),
                        cost: selectedDuration.baseCost
                    )
                    
                    if addons.cover {
                        CostBreakdownRow(label: "duration_cover_image".localized, cost: 100)
                    }
                    
                    if addons.audio {
                        CostBreakdownRow(
                            label: String(format: "duration_audio_with_minutes".localized, selectedDuration.minutes),
                            cost: selectedDuration.audioCost
                        )
                    }
                    
                    if addons.illustrated {
                        CostBreakdownRow(
                            label: String(format: "duration_illustrations_with_count".localized, selectedDuration.illustrationCount),
                            cost: selectedDuration.illustratedCost
                        )
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.3))
                    
                    // Total
                    HStack {
                        Text("duration_total_cost".localized)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Text("\(calculatedCost)")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            
                            CoinIconView(size: 22)
                        }
                    }
                }
            }
            
            // Removed balance check row as user requested cleaner UI with only orange button in flow
        }
        .padding(20)
        .dwGlassCard()
    }
    
    // MARK: - Helper Methods
    
    private func calculateCost() {
        calculatedCost = coinService.calculateCostLocal(
            duration: selectedDuration,
            addons: addons
        )
    }
}

// MARK: - Duration Card

struct DurationCard: View {
    let duration: StoryDuration
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                Text(duration.icon)
                    .font(.system(size: 28))
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(duration.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(isSelected ? Color(red: 0.545, green: 0.361, blue: 0.965) : .white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        if let badge = duration.badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .cornerRadius(4)
                                .layoutPriority(1)
                        }
                        
                        Spacer(minLength: 0)
                    }

                    HStack(spacing: 12) {
                        Text("duration_minutes_with_value".localized.replacingOccurrences(of: "%d", with: "\(duration.minutes)"))
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))

                        Text("duration_words_with_value".localized.replacingOccurrences(of: "%d", with: "\(duration.estimatedWords)"))
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Text(duration.description)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.9)
                }
                
                Spacer()
                
                // Selection Indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color(red: 0.545, green: 0.361, blue: 0.965) : Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color(red: 0.545, green: 0.361, blue: 0.965))
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(16)
            .background(
                isSelected ? Color.white.opacity(0.25) : Color.white.opacity(0.1)
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color(red: 0.545, green: 0.361, blue: 0.965) : Color.clear,
                        lineWidth: 2
                    )
            )
        }
    }
}

// MARK: - Addon Toggle

struct AddonToggle: View {
    let info: AddonInfo
    var cost: Int?
    @Binding var isOn: Bool
    let isLocked: Bool
    let onUpgrade: () -> Void
    
    var displayCost: Int {
        cost ?? info.cost
    }
    
    var body: some View {
        Button(action: {
            if isLocked {
                onUpgrade()
            } else {
                isOn.toggle()
            }
        }) {
            HStack(spacing: 10) {
                // Icon
                Image(systemName: info.icon)
                    .font(.system(size: 18))
                    .foregroundColor(isLocked ? Color(red: 1.0, green: 0.84, blue: 0.0) : .white)
                    .frame(width: 28)
                
                // Info (with flexible width)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(info.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isLocked ? .white.opacity(0.6) : .white)
                            .lineLimit(1)

                        if isLocked {
                            Text("addon_pro_badge".localized)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.0))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color(red: 1.0, green: 0.84, blue: 0.0))
                                .cornerRadius(3)
                        }
                    }

                    Text(info.description)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.9)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Cost & Toggle (fixed width)
                if !isLocked {
                    HStack(spacing: 8) {
                        HStack(spacing: 3) {
                            Text("+\(displayCost)")
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(1)
                            CoinIconView(size: 15)
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 60, alignment: .trailing)
                        
                        Toggle("", isOn: $isOn)
                            .labelsHidden()
                            .tint(Color(red: 0.545, green: 0.361, blue: 0.965))
                            .frame(width: 50)
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .frame(width: 110, alignment: .trailing)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
        }
        // Don't disable locked items - they should trigger paywall on tap
        .opacity(isLocked ? 0.9 : 1.0)
    }
}

// MARK: - Cost Breakdown Row

struct CostBreakdownRow: View {
    let label: String
    let cost: Int
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            HStack(spacing: 4) {
                Text("\(cost)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                CoinIconView(size: 16)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LinearGradient.dwBackground
            .ignoresSafeArea()
        
        ScrollView {
            StoryDurationPickerView(
                selectedDuration: .constant(.standard),
                addons: .constant(StoryAddons(cover: true, audio: true))
            )
            .padding()
        }
    }
}

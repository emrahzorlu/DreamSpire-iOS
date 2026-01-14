//
//  PaywallView.swift
//  DreamSpire
//
//  Modern Premium Paywall with Glassmorphism Design
//  Refined: Inline pricing, no toggle, dual CTA
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = SubscriptionViewModel()
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var showingLogin = false
    @State private var selectedTier: SubscriptionTier
    @State private var selectedPeriod: BillingPeriod = .monthly
    @State private var showPrivacySheet = false
    @State private var showTermsSheet = false
    private let initialTier: SubscriptionTier
    
    @Namespace private var animation
    
    init() {
        let currentTier = SubscriptionService.shared.currentTier
        self.initialTier = currentTier
        _selectedTier = State(initialValue: currentTier == .plus ? .pro : .plus)
    }
    
    private var availableTiers: [SubscriptionTier] {
        switch initialTier {
        case .free:
            return [.plus, .pro]
        case .plus:
            return [.pro]
        case .pro:
            return []
        }
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Animated background with particles
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.1)
                
                // Floating particles
                FloatingParticlesView(particleColor: selectedTier == .pro ? .orange : Color(red: 0.545, green: 0.361, blue: 0.965))
                    .opacity(0.6)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Header
                            VStack(spacing: 8) {
                                Text(initialTier == .plus ? "paywall_upgrade_pro".localized : "paywall_go_premium".localized)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)

                                Text(initialTier == .plus ? "paywall_more_features".localized : "paywall_unlimited_stories".localized)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding(.top, 50)
                            .padding(.bottom, 20)
                            
                            // Tier Segment Selector (Compact)
                            TierSegmentSelector(
                                availableTiers: availableTiers,
                                selectedTier: $selectedTier
                            )
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                            
                            // Features Section
                            VStack(alignment: .leading, spacing: 10) {
                                Text(selectedTier == .pro ? "paywall_pro_features".localized : "paywall_plus_features".localized)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(selectedTier == .pro ? .orange : Color(red: 0.545, green: 0.361, blue: 0.965))
                                    .padding(.bottom, 2)
                                    .animation(.easeInOut(duration: 0.3), value: selectedTier)
                                
                                Group {
                                    if selectedTier == .pro {
                                        proFeatures
                                            .transition(.asymmetric(
                                                insertion: .scale(scale: 0.95).combined(with: .opacity),
                                                removal: .scale(scale: 0.95).combined(with: .opacity)
                                            ))
                                    } else {
                                        plusFeatures
                                            .transition(.asymmetric(
                                                insertion: .scale(scale: 0.95).combined(with: .opacity),
                                                removal: .scale(scale: 0.95).combined(with: .opacity)
                                            ))
                                    }
                                }
                                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: selectedTier)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.white.opacity(0.05))
                            )
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                            .id("features")
                        }
                    }
                    .onChange(of: selectedTier) { oldValue, newValue in
                        if newValue == .pro {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo("features", anchor: .bottom)
                            }
                        } else {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo("features", anchor: .top)
                            }
                        }
                    }
                }

                // Period Selection (Radio Style)
                VStack(spacing: 8) {
                    // Monthly Option
                    PeriodRadioRow(
                        title: "paywall_monthly".localized,
                        price: getMonthlyPrice(for: selectedTier),
                        periodLabel: "/ " + "paywall_per_month".localized,
                        isSelected: selectedPeriod == .monthly,
                        badgeText: nil,
                        tierColor: selectedTier == .pro ? .orange : Color(red: 0.545, green: 0.361, blue: 0.965),
                        onTap: { selectedPeriod = .monthly }
                    )
                    
                    // Yearly Option
                    PeriodRadioRow(
                        title: "paywall_yearly".localized,
                        price: getYearlyPrice(for: selectedTier),
                        periodLabel: "/ " + "paywall_per_year".localized,
                        isSelected: selectedPeriod == .yearly,
                        badgeText: "paywall_savings_badge".localized,
                        tierColor: selectedTier == .pro ? .orange : Color(red: 0.545, green: 0.361, blue: 0.965),
                        onTap: { selectedPeriod = .yearly }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .animation(.easeInOut(duration: 0.2), value: selectedPeriod)
                
                // Continue Button
                Button(action: {
                    handleSubscribe(tier: selectedTier, period: selectedPeriod)
                }) {
                    ZStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("paywall_continue".localized)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient(
                            colors: selectedTier == .pro
                                ? [Color.orange, Color(red: 0.976, green: 0.451, blue: 0.086)]
                                : [Color(red: 0.545, green: 0.361, blue: 0.965), Color(red: 0.486, green: 0.231, blue: 0.929)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                    .shadow(
                        color: selectedTier == .pro ? Color.orange.opacity(0.4) : Color(red: 0.545, green: 0.361, blue: 0.965).opacity(0.4),
                        radius: 12, x: 0, y: 6
                    )
                }
                .padding(.horizontal, 20)
                .disabled(viewModel.isLoading)
                .animation(.easeInOut(duration: 0.3), value: selectedTier)
                
                // Footer
                VStack(spacing: 6) {
                    Button("paywall_restore_purchases".localized) {
                        Task { await viewModel.restorePurchases() }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .disabled(viewModel.isLoading)

                    Text("paywall_auto_renew".localized)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.3))
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 12) {
                        Button(action: { showTermsSheet = true }) {
                            Text("paywall_terms".localized).underline()
                        }
                        Text("•").foregroundColor(.white.opacity(0.2))
                        Button(action: { showPrivacySheet = true }) {
                            Text("paywall_privacy".localized).underline()
                        }
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
                }
                .padding(.top, 10)
                .padding(.bottom, 16)
            }

            // Close button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.15)))
            }
            .padding(.top, 8)
            .padding(.trailing, 20)
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showTermsSheet) {
            let langCode = LocalizationManager.shared.currentLanguage.rawValue
            WebContentView(url: "https://dreamweaver-backend-v2-production.up.railway.app/terms_\(langCode).html", title: "paywall_terms".localized)
        }
        .sheet(isPresented: $showPrivacySheet) {
            let langCode = LocalizationManager.shared.currentLanguage.rawValue
            WebContentView(url: "https://dreamweaver-backend-v2-production.up.railway.app/privacy_\(langCode).html", title: "paywall_privacy".localized)
        }
        .sheet(isPresented: $showingLogin) {
            LoginView(onAuthenticated: { showingLogin = false })
        }
        .onChange(of: viewModel.error) { _, newValue in
            if let error = newValue {
                GlassAlertManager.shared.error(
                    "paywall_error_title".localized,
                    message: error
                )
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    viewModel.error = nil
                }
            }
        }
        .onChange(of: viewModel.successMessage) { _, newValue in
            if let message = newValue {
                GlassAlertManager.shared.success(
                    "paywall_success_title".localized,
                    message: message,
                    duration: 2.5  // Give user time to read (2.5 seconds)
                )
                // Dismiss paywall 0.5 seconds after alert dismisses
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    viewModel.successMessage = nil
                    dismiss()
                }
            }
        }
        .withGlassAlerts()
        .onAppear {
            DWLogger.shared.logViewAppear("PaywallView")
        }
        .preferredColorScheme(.light)
    }
    
    // MARK: - Features
    
    private var proFeatures: some View {
        VStack(alignment: .leading, spacing: 10) {
            FeatureRow(text: "paywall_pro_coins".localized)
            FeatureRow(text: "paywall_pro_stories".localized, isExclusive: true)
            FeatureRow(text: "paywall_illustrated_stories".localized, isExclusive: true)
            FeatureRow(text: "paywall_premium_voices".localized, isExclusive: true)
            FeatureRow(text: "paywall_unlimited_characters".localized)
            FeatureRow(text: "paywall_buy_coins".localized)
            FeatureRow(text: "paywall_pdf_audio_export".localized, isExclusive: true)
        }
    }
    
    private var plusFeatures: some View {
        VStack(alignment: .leading, spacing: 10) {
            FeatureRow(text: "paywall_plus_coins".localized)
            FeatureRow(text: "paywall_plus_stories".localized)
            FeatureRow(text: "paywall_plus_characters".localized)
            FeatureRow(text: "paywall_plus_prewritten".localized)
            FeatureRow(text: "paywall_pdf_export".localized)
            FeatureRow(text: "paywall_buy_coins".localized)
        }
    }
    
    // MARK: - Helpers
    private func handleSubscribe(tier: SubscriptionTier, period: BillingPeriod) {
        Task { await viewModel.subscribe(tier: tier, period: period) }
    }
    
    private func getMonthlyPrice(for tier: SubscriptionTier) -> String {
        viewModel.getLocalizedPrice(for: tier, period: .monthly) ?? tier.fallbackMonthlyPrice.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }
    
    private func getYearlyPrice(for tier: SubscriptionTier) -> String {
        viewModel.getLocalizedPrice(for: tier, period: .yearly) ?? tier.fallbackYearlyPrice.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }
}

// MARK: - Tier Segment Selector

struct TierSegmentSelector: View {
    let availableTiers: [SubscriptionTier]
    @Binding var selectedTier: SubscriptionTier
    
    @Namespace private var segmentAnimation
    
    private let plusColor = Color(red: 0.545, green: 0.361, blue: 0.965)
    private let proColor = Color.orange
    
    private var currentColor: Color {
        selectedTier == .pro ? proColor : plusColor
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(availableTiers, id: \.self) { tier in
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        selectedTier = tier
                    }
                }) {
                    Text(tier == .pro ? "PRO" : "PLUS")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(selectedTier == tier ? .white : .white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .contentShape(Rectangle()) // Makes entire area tappable
                    .background {
                        if selectedTier == tier {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    LinearGradient(
                                        colors: tier == .pro 
                                            ? [proColor, Color(red: 0.976, green: 0.451, blue: 0.086)]
                                            : [plusColor, Color(red: 0.486, green: 0.231, blue: 0.929)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .matchedGeometryEffect(id: "SegmentIndicator", in: segmentAnimation)
                                .shadow(color: (tier == .pro ? proColor : plusColor).opacity(0.5), radius: 12, x: 0, y: 4)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(currentColor.opacity(0.3), lineWidth: 1)
                .animation(.easeInOut(duration: 0.3), value: selectedTier)
        )
        .shadow(color: currentColor.opacity(0.3), radius: 16, x: 0, y: 0)
        .animation(.easeInOut(duration: 0.3), value: selectedTier)
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let text: String
    var isExclusive: Bool = false
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(isExclusive ? .orange : .green)
            
            Text(text)
                .font(.system(size: 14, weight: isExclusive ? .semibold : .regular))
                .foregroundColor(.white.opacity(isExclusive ? 1 : 0.85))
            
            Spacer()
            
            if isExclusive {
                Text("PRO")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.orange.opacity(0.2)))
            }
        }
    }
}

// MARK: - Period Radio Row (Enhanced)

struct PeriodRadioRow: View {
    let title: String
    let price: String
    let periodLabel: String
    let isSelected: Bool
    var badgeText: String?
    var tierColor: Color = .orange // Pass tier color for matching glow
    let onTap: () -> Void
    
    @State private var pulseAnimation: Bool = false
    @State private var borderRotation: Double = 0
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            onTap()
        }) {
            HStack(spacing: 12) {
                // Radio circle with glow
                ZStack {
                    // Outer glow ring when selected
                    if isSelected {
                        Circle()
                            .stroke(tierColor.opacity(pulseAnimation ? 0.6 : 0.3), lineWidth: 3)
                            .frame(width: 26, height: 26)
                            .blur(radius: 2)
                    }
                    
                    Circle()
                        .stroke(isSelected ? Color.white : Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    
                    if isSelected {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.white, tierColor.opacity(0.8)],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 8
                                )
                            )
                            .frame(width: 12, height: 12)
                            .shadow(color: tierColor.opacity(0.6), radius: 4, x: 0, y: 0)
                    }
                }
                
                // Title and price
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 4) {
                        Text(price)
                            .font(.system(size: 13, weight: .medium))
                        Text(periodLabel)
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Badge (if any)
                if let badge = badgeText {
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 8, weight: .bold))
                        Text(badge)
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(Color(red: 0.15, green: 0.1, blue: 0.05))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(LinearGradient(
                                colors: [Color(red: 0.95, green: 0.8, blue: 0.4), Color(red: 1.0, green: 0.85, blue: 0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                    )
                    .shadow(color: Color(red: 0.95, green: 0.8, blue: 0.4).opacity(0.5), radius: 6, x: 0, y: 2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                // Glassmorphism background
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            isSelected 
                                ? tierColor.opacity(0.15)
                                : Color.white.opacity(0.05)
                        )
                    
                    // Inner subtle gradient
                    if isSelected {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [tierColor.opacity(0.1), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            )
            .overlay(
                // Animated gradient border when selected
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                AngularGradient(
                                    colors: [tierColor.opacity(0.8), tierColor.opacity(0.3), tierColor.opacity(0.8)],
                                    center: .center,
                                    angle: .degrees(borderRotation)
                                ),
                                lineWidth: 1.5
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    }
                }
            )
            // Glow effect when selected
            .shadow(color: isSelected ? tierColor.opacity(pulseAnimation ? 0.4 : 0.2) : .clear, radius: isSelected ? 12 : 0, x: 0, y: 0)
            // Scale bounce
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: isSelected)
        .onAppear {
            // Start pulse animation
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
            // Start border rotation
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                borderRotation = 360
            }
        }
    }
}

// MARK: - Floating Particles View

struct FloatingParticlesView: View {
    let particleColor: Color
    
    @State private var particles: [Particle] = []
    
    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var opacity: Double
        var speed: Double
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particleColor)
                        .frame(width: particle.size, height: particle.size)
                        .blur(radius: particle.size / 3)
                        .opacity(particle.opacity)
                        .position(x: particle.x, y: particle.y)
                }
            }
            .onAppear {
                // Create initial particles
                particles = (0..<20).map { _ in
                    Particle(
                        x: CGFloat.random(in: 0...geometry.size.width),
                        y: CGFloat.random(in: 0...geometry.size.height),
                        size: CGFloat.random(in: 2...8),
                        opacity: Double.random(in: 0.2...0.6),
                        speed: Double.random(in: 0.5...2)
                    )
                }
                startAnimation(in: geometry.size)
            }
        }
    }
    
    private func startAnimation(in size: CGSize) {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            withAnimation(.linear(duration: 0.05)) {
                for i in particles.indices {
                    particles[i].y -= particles[i].speed
                    particles[i].x += CGFloat.random(in: -0.3...0.3)
                    
                    // Reset particle when it goes off screen
                    if particles[i].y < -10 {
                        particles[i].y = size.height + 10
                        particles[i].x = CGFloat.random(in: 0...size.width)
                        particles[i].opacity = Double.random(in: 0.2...0.6)
                    }
                }
            }
        }
    }
}

// MARK: - Shimmer Effect Modifier

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.3),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.6)
                    .offset(x: phase * geometry.size.width * 1.6 - geometry.size.width * 0.3)
                    .mask(content)
                }
            )
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
}

#Preview {
    PaywallView()
        .environmentObject(AuthManager.shared)
}

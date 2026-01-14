//
//  CoinShopView.swift
//  DreamSpire
//
//  Modern Neon Glow Design with Uniform Cards
//

import SwiftUI

struct CoinShopView: View {
    @StateObject private var viewModel = CoinShopViewModel()
    @EnvironmentObject var coinService: CoinService
    @Environment(\.dismiss) var dismiss
    @State private var showPaywall = false
    @State private var showPrivacySheet = false
    @State private var showTermsSheet = false
    var onPurchaseComplete: (() -> Void)? = nil

    var body: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.1, green: 0.05, blue: 0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView

                // Scrollable Content
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            // Balance Card
                            neonBalanceCard
                                .padding(.horizontal, 20)
                                .padding(.top, 4)
                                .id("top")

                            // Pro Promotion for Plus users
                            if SubscriptionService.shared.currentTier == .plus {
                                CoinShopProBanner(onUpgrade: {
                                    showPaywall = true
                                })
                                .padding(.horizontal, 20)
                            }

                            // Packages Grid
                            VStack(spacing: 14) {
                                // First 4 packages in 2x2 grid
                                LazyVGrid(columns: [
                                    GridItem(.flexible(), spacing: 14),
                                    GridItem(.flexible(), spacing: 14)
                                ], spacing: 14) {
                                    ForEach(viewModel.packages.prefix(4)) { package in
                                        NeonCoinCard(
                                            package: package,
                                            isSelected: viewModel.selectedPackage?.id == package.id,
                                            onTap: {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    viewModel.selectPackage(package)

                                                    // Scroll to position selected package above button
                                                    let packageIndex = viewModel.packages.firstIndex(where: { $0.id == package.id }) ?? 0

                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                                            if packageIndex < 2 {
                                                                // First row packages - scroll to top
                                                                proxy.scrollTo("top", anchor: .top)
                                                            } else {
                                                                // Second row packages - moderate scroll to center
                                                                proxy.scrollTo(package.id, anchor: .center)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        )
                                        .id(package.id)
                                    }
                                }

                                // Last package centered
                                if viewModel.packages.count > 4 {
                                    HStack(spacing: 14) {
                                        Spacer()
                                        NeonCoinCard(
                                            package: viewModel.packages[4],
                                            isSelected: viewModel.selectedPackage?.id == viewModel.packages[4].id,
                                            onTap: {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    viewModel.selectPackage(viewModel.packages[4])

                                                    // Last package - scroll so it's visible above button
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                                            proxy.scrollTo(viewModel.packages[4].id, anchor: UnitPoint(x: 0.5, y: 0.65))
                                                        }
                                                    }
                                                }
                                            }
                                        )
                                        .id(viewModel.packages[4].id)
                                        .frame(width: (UIScreen.main.bounds.width - 54) / 2) // Same width as grid items
                                        Spacer()
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 150) // Bottom padding for scroll space
                        }
                    }
                }
            }

            // Fixed bottom CTA & Footer (Matched with PaywallView)
            VStack(spacing: 0) {
                Spacer()
                
                neonPurchaseButton
                
                // Footer
                VStack(spacing: 6) {
                    Button("paywall_restore_purchases".localized) {
                        Task {
                            await viewModel.restorePurchases()
                        }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .disabled(viewModel.isPurchasing)

                    legalLinksView
                }
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
        }
        .task {
            // Set dismiss callback
            viewModel.onDismiss = { [dismiss] in
                dismiss()
                onPurchaseComplete?()
            }

            // CoinService already handles caching, no need to reload every time
            await viewModel.loadCurrentBalance()
            DWLogger.shared.info("✅ CoinShopView loaded (using cached balance if valid)", category: .coin)
        }
        .onReceive(NotificationCenter.default.publisher(for: .subscriptionDidChange)) { _ in
            // Real-time update when subscription changes
            DWLogger.shared.info("🔔 CoinShop: Subscription changed - Reloading balance", category: .general)
            Task {
                await viewModel.loadCurrentBalance()
            }
        }
        .onChange(of: viewModel.error) { _, newValue in
            if let error = newValue {
                GlassAlertManager.shared.error(
                    "error".localized,
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
                    "success".localized,
                    message: message,
                    duration: 2.0  // Give user time to read
                )
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    viewModel.successMessage = nil
                }
            }
        }
        .withGlassAlerts()
        .preferredColorScheme(.light)
        .interactiveDismissDisabled(viewModel.isPurchasing)
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView()
        }
        .onChange(of: showPaywall) { _, isShowing in
            if !isShowing {
                // Subscription değiştiyse balance'ı güncelle
                Task {
                    await viewModel.loadCurrentBalance()
                }
            }
        }
        .overlay {
            if viewModel.isPurchasing {
                PurchaseLoadingOverlay()
            }
        }
        .sheet(isPresented: $showTermsSheet) {
            let langCode = LocalizationManager.shared.currentLanguage.rawValue
            WebContentView(url: "https://dreamweaver-backend-v2-production.up.railway.app/terms_\(langCode).html", title: "paywall_terms".localized)
        }
        .sheet(isPresented: $showPrivacySheet) {
            let langCode = LocalizationManager.shared.currentLanguage.rawValue
            WebContentView(url: "https://dreamweaver-backend-v2-production.up.railway.app/privacy_\(langCode).html", title: "paywall_privacy".localized)
        }
    }

    // MARK: - Legal Links View

    private var legalLinksView: some View {
        HStack(spacing: 12) {
            Button(action: { showTermsSheet = true }) {
                Text("paywall_terms".localized)
                    .underline()
            }
            Text("•").foregroundColor(.white.opacity(0.2))
            Button(action: { showPrivacySheet = true }) {
                Text("paywall_privacy".localized)
                    .underline()
            }
        }
        .font(.system(size: 10))
        .foregroundColor(.white.opacity(0.4))
    }

    // MARK: - Header

    private var headerView: some View {
        ZStack {
            // Center - Title
            HStack(spacing: 8) {
                Image("CoinIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)

                Text("coin_shop_title".localized)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }

            // Right - Close Button
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .disabled(viewModel.isPurchasing)
                .opacity(viewModel.isPurchasing ? 0.5 : 1.0)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Balance Card

    private var neonBalanceCard: some View {
        HStack(spacing: 16) {
            // Coin icon with glow
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.yellow.opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 30
                        )
                    )
                    .frame(width: 60, height: 60)
                    .blur(radius: 10)

                Image("CoinIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("coins_current_balance".localized)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))

                if coinService.coinBalance == nil {
                    // Show loading while fetching balance
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                        .frame(height: 38)
                } else {
                    Text("\(viewModel.currentBalance)")
                        .font(.system(size: 32, weight: .heavy))
                        .foregroundColor(.white)
                }

                Text("coin_unit".localized)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.cyan.opacity(0.2),
                            Color.blue.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.5), Color.blue.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: Color.cyan.opacity(0.3), radius: 15, x: 0, y: 8)
    }

    // MARK: - Purchase Button

    private var neonPurchaseButton: some View {
        Button(action: {
            Task {
                await viewModel.purchaseSelectedPackage()
            }
        }) {
            HStack(spacing: 8) {
                if viewModel.isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    if let selected = viewModel.selectedPackage {
                        Text(String(format: "coin_shop_buy".localized, selected.priceString))
                            .font(.system(size: 18, weight: .bold))
                    } else {
                        Text("coin_shop_select_package".localized)
                            .font(.system(size: 18, weight: .bold))
                    }
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: viewModel.selectedPackage != nil
                                ? [Color.cyan, Color.blue]
                                : [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shadow(
                color: viewModel.selectedPackage != nil ? Color.cyan.opacity(0.5) : Color.clear,
                radius: 20,
                x: 0,
                y: 10
            )
        }
        .disabled(viewModel.selectedPackage == nil || viewModel.isPurchasing)
        .padding(.horizontal, 20)
    }
}

// MARK: - Neon Coin Card (Uniform Size)

struct NeonCoinCard: View {
    let package: CoinPackage
    let isSelected: Bool
    let onTap: () -> Void

    var glowColor: Color {
        if package.badge == "POPÜLER" {
            return .orange
        } else if package.badge?.contains("VALUE") ?? false || package.badge?.contains("DEĞ") ?? false {
            return .purple
        } else if package.badge == "MEGA" || package.badge == "ULTIMATE" {
            return .pink
        }
        return .cyan
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background & Glow
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.22)) // Biraz daha belirgin zemin
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        glowColor.opacity(isSelected ? 0.8 : 0.4),
                                        glowColor.opacity(isSelected ? 0.4 : 0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .shadow(color: isSelected ? glowColor.opacity(0.3) : Color.black.opacity(0.2), radius: 10, x: 0, y: 5)

                VStack(spacing: 0) {
                    // 1. Image Area (Fixed Height)
                    ZStack {
                        // Glow behind image
                        Circle()
                            .fill(glowColor.opacity(0.15))
                            .frame(width: 80, height: 80)
                            .blur(radius: 20)
                        
                        Image(package.iconName)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(package.coins == 500 ? 0.9 : 1.5) // 500 Coin için %40 küçültme, diğerleri büyük
                            .frame(width: 90, height: 90)
                    }
                    .frame(height: 110) // Görsel için ayrılan sabit alan
                    .padding(.top, 16)
                    
                    // 2. Coin Amount
                    HStack(spacing: 4) {
                        Text("\(package.coins)")
                            .font(.system(size: 30, weight: .heavy)) // Daha büyük font
                            .foregroundColor(.white)
                        
                        Text("Coin")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.top, 8)
                    }
                    
                    Spacer()
                    
                    // 3. Price & Discount Area (Fixed Height at Bottom)
                    VStack(spacing: 4) {
                        Text(package.priceString)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        
                        if package.discountPercent > 0 {
                            Text(String(format: "coin_shop_discount".localized, package.discountPercent))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .cornerRadius(4)
                        } else {
                            Text(" ") // Hizayı korumak için boşluk
                                .font(.system(size: 11))
                                .padding(.vertical, 2)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .frame(height: 260) // Tüm kartlar için sabit yükseklik
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .overlay(
            // Badge Overlay
            Group {
                if let badge = package.badge {
                    ZStack {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [glowColor, glowColor.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: glowColor.opacity(0.5), radius: 4, y: 2)
                        
                        Text(badge)
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                    }
                    .fixedSize()
                    .offset(y: -12) // Kartın tam üst çizgisine ortala
                }
            },
            alignment: .top
        )
    }
}

// MARK: - Pro Banner for Plus Users

struct CoinShopProBanner: View {
    let onUpgrade: () -> Void
    
    var body: some View {
        Button(action: onUpgrade) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "8b5cf6"), Color(hex: "ec4899")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("coinshop_pro_title".localized)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("PRO")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "8b5cf6"), Color(hex: "ec4899")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(3)
                    }
                    
                    Text("coinshop_pro_subtitle".localized)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "ec4899"))
            }
            .padding(12)
            .background(
                LinearGradient(
                    colors: [Color(hex: "8b5cf6").opacity(0.2), Color(hex: "ec4899").opacity(0.15)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(hex: "8b5cf6").opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Purchase Loading Overlay

struct PurchaseLoadingOverlay: View {
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            // Loading card
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("purchase_processing".localized)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("purchase_wait".localized)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.1, green: 0.1, blue: 0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.cyan.opacity(0.3), radius: 20, x: 0, y: 10)
        }
    }
}

// MARK: - Preview

#Preview {
    CoinShopView()
        .environmentObject(CoinService.shared)
}

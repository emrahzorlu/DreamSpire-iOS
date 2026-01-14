//
//  SettingsView.swift
//  DreamSpire
//
//  Redesigned with modern iOS styling and Inline Edit
//

import SwiftUI
import StoreKit
import UserNotifications
import MessageUI

struct SettingsView: View {
    @StateObject fileprivate var viewModel = ProfileViewModel()
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss

    // Sheets & Navigation
    @State private var showingCoinShop = false
    @State private var showingTransactionHistory = false
    @State private var showingPaywall = false
    @State private var showingCharacters = false
    @State private var showingLibrary = false
    @State private var selectedLibraryTab: LibraryTab = .myStories
    @State private var showingLanguagePicker = false
    @State private var showingThemePicker = false
    @State private var showingFAQ = false
    @State private var showingTerms = false
    @State private var showingPrivacy = false
    @State private var showingLogin = false  // For guest login
    @State private var showingMailView = false // New: In-app mail composition

    @ObservedObject fileprivate var coinService = CoinService.shared
    @ObservedObject fileprivate var subscriptionService = SubscriptionService.shared

    @AppStorage("selectedLanguage") private var selectedLanguage = "tr"
    @AppStorage("selectedTheme") private var selectedTheme = "auto"

    @State private var hasLoaded = false

    var onSignOut: () -> Void
    
    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient.dwBackground
                .ignoresSafeArea()
                .onAppear {
                    // Sync selectedLanguage with LocalizationManager on appear
                    selectedLanguage = LocalizationManager.shared.currentLanguage.rawValue
                }

            VStack(spacing: 0) {
                // MARK: - Header Title
                HStack {
                    Text("settings_title".localized)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

                List {
                    // MARK: - Profile, Wallet & Upgrade (Combined Section)
                    // MARK: - Profile, Wallet & Upgrade (Combined Section)
                    Section {
                        // 1. Profile Header
                        Group {
                            if authManager.userState == .authenticated {
                                UserProfileHeader(viewModel: viewModel)
                            } else {
                                GuestUserHeader(onLoginTap: { showingLogin = true })
                            }
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .padding(.bottom, 6)
                        
                        // 2. Wallet Card
                        WalletCard(
                            coinBalance: coinService.currentBalance,
                            tier: subscriptionService.currentTier,
                            isLoading: coinService.isLoading,
                            onBuyCoins: {
                                // Coin shop requires active subscription (Plus or Pro)
                                if subscriptionService.currentTier == .free {
                                    DWLogger.shared.logUserAction("Coin Shop Blocked - Free User")
                                    DWLogger.shared.logAnalyticsEvent("paywall_triggered", parameters: [
                                        "source": "coin_shop_button",
                                        "current_tier": "free"
                                    ])
                                    showingPaywall = true
                                } else {
                                    DWLogger.shared.logUserAction("Coin Shop Opened")
                                    showingCoinShop = true
                                }
                            },
                            onUpgrade: { showingPaywall = true },
                            onTransactionHistory: { showingTransactionHistory = true }
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .padding(.vertical, 6)
                        
                        // 3. Upgrade Promotion Cards
                        Group {
                            if subscriptionService.currentTier == .free {
                                GuestUpgradeCard(onUpgrade: { showingPaywall = true })
                            } else if subscriptionService.currentTier == .plus {
                                PlusToProUpgradeCard(onUpgrade: { showingPaywall = true })
                            }
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .padding(.top, 6)
                    }
                
                // MARK: - Content
                Section(header: Text("settings_content".localized).foregroundColor(.white).font(.system(size: 16, weight: .semibold))) {
                    // My Characters Row with Lock for Free Users
                    if subscriptionService.currentTier == .free {
                        LockedCharactersRow {
                            DWLogger.shared.logUserAction("Characters Blocked - Free User")
                            DWLogger.shared.logAnalyticsEvent("paywall_triggered", parameters: [
                                "source": "my_characters_button",
                                "current_tier": "free"
                            ])
                            showingPaywall = true
                        }
                    } else {
                        SettingsButtonRow(icon: "theatermasks.fill", color: .purple, title: "settings_my_characters".localized, value: viewModel.isLoading ? nil : "\(viewModel.savedCharactersCount)", isLoading: viewModel.isLoading) {
                            showingCharacters = true
                        }
                    }

                    SettingsButtonRow(icon: "book.fill", color: .blue, title: "settings_my_stories".localized, value: viewModel.isLoading ? nil : "\(viewModel.storiesCount)", isLoading: viewModel.isLoading) {
                        selectedLibraryTab = .myStories
                        showingLibrary = true
                    }
                }
                .listRowBackground(
                    Color.white.opacity(0.15)
                        .overlay(Color.white.opacity(0.05))
                )
                
                // MARK: - Preferences
                Section(header: Text("settings_preferences".localized).foregroundColor(.white).font(.system(size: 16, weight: .semibold))) {
                    SettingsToggleRow(icon: "bell.fill", color: .red, title: "settings_notifications".localized, isOn: $viewModel.notificationsEnabled, onChange: handleNotificationToggle)

                    SettingsButtonRow(icon: "globe", color: .cyan, title: "settings_language".localized, value: languageDisplayName) {
                        showingLanguagePicker = true
                    }
                }
                .listRowBackground(
                    Color.white.opacity(0.15)
                        .overlay(Color.white.opacity(0.05))
                )
                
                // MARK: - Support
                Section(header: Text("settings_support".localized).foregroundColor(.white).font(.system(size: 16, weight: .semibold))) {
                    SettingsButtonRow(icon: "questionmark.circle.fill", color: .green, title: "settings_faq".localized) {
                        showingFAQ = true
                    }

                    // Email İletişim - Tıkla: mail aç, Uzun bas: kopyala
                    Button(action: openMailApp) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue)
                                    .frame(width: 30, height: 30)
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            Text("settings_contact".localized)
                                .foregroundColor(.white)
                                .font(.body)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .contextMenu {
                        Button(action: copyEmailToClipboard) {
                            Label("settings_copy_email_long_press".localized, systemImage: "doc.on.doc")
                        }
                    }

                    SettingsButtonRow(icon: "star.circle.fill", color: .orange, title: "settings_rate_app".localized) {
                        requestAppReview()
                    }
                    SettingsButtonRow(icon: "arrow.clockwise.circle.fill", color: .purple, title: "settings_restore_purchases".localized, isLoading: viewModel.isRestoringPurchases) {
                        Task {
                            await viewModel.restorePurchases()
                        }
                    }
                }
                .listRowBackground(
                    Color.white.opacity(0.15)
                        .overlay(Color.white.opacity(0.05))
                )
                
                // MARK: - Legal
                Section(header: Text("settings_legal".localized).foregroundColor(.white).font(.system(size: 16, weight: .semibold))) {
                    SettingsButtonRow(icon: "doc.text.fill", color: .gray, title: "settings_terms".localized) {
                        showingTerms = true
                    }
                    SettingsButtonRow(icon: "hand.raised.fill", color: .gray, title: "settings_privacy".localized) {
                        showingPrivacy = true
                    }
                    
                    HStack {
                        Text("settings_version".localized)
                            .foregroundColor(.white)
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .listRowBackground(
                    Color.white.opacity(0.15)
                        .overlay(Color.white.opacity(0.05))
                )


                // MARK: - Account Actions
                if authManager.userState == .authenticated {
                    Section(footer: 
                        Button(action: confirmDeleteAccount) {
                            Text("settings_delete_account".localized)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color(red: 1.0, green: 0.3, blue: 0.3))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.top, 8)
                    ) {
                        Button(action: { showSignOutConfirmation() }) {
                            Text("settings_sign_out".localized)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .listRowBackground(
                            Color.white.opacity(0.15)
                                .overlay(Color.white.opacity(0.05))
                        )
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
                    .listRowBackground(Color.clear)
                } else {
                    // MARK: - Guest Login Button
                    Section {
                        Button(action: { showingLogin = true }) {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(red: 0.545, green: 0.361, blue: 0.965))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("settings_login_register".localized)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                    Text("settings_login_subtitle".localized)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .listRowBackground(
                        Color.white.opacity(0.15)
                            .overlay(Color.white.opacity(0.05))
                    )
                }
            }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                // FIXED: Force entire list to rebuild when user state changes OR language changes
                .id("\(authManager.userState)-\(selectedLanguage)")
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 100) // Space for floating TabBar
                }
            }
        }
        .fullScreenCover(isPresented: $showingCoinShop) { CoinShopView() }
        .fullScreenCover(isPresented: $showingPaywall) { PaywallView() }
        .fullScreenCover(isPresented: $showingCharacters) {
            MyCharactersView()
            // No need to reload - repository handles caching
        }
        .fullScreenCover(isPresented: $showingLibrary) {
            UserLibraryView(initialTab: selectedLibraryTab, onLoginRequest: {}, onCreateStory: {
                // Post notification to navigate to generate tab
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NotificationCenter.default.post(name: .navigateToGenerateTab, object: nil)
                }
            }, showCloseButton: true)
        }
        .overlay {
            // Language Picker Popup
            if showingLanguagePicker {
                languagePickerPopup
            }
        }
        .fullScreenCover(isPresented: $showingFAQ) {
            FAQView()
        }
        .fullScreenCover(isPresented: $showingTerms) {
            let langCode = LocalizationManager.shared.currentLanguage.apiLanguage
            WebContentView(url: "https://dreamweaver-backend-v2-production.up.railway.app/terms_\(langCode).html", title: "settings_terms".localized)
        }
        .fullScreenCover(isPresented: $showingPrivacy) {
            let langCode = LocalizationManager.shared.currentLanguage.apiLanguage
            WebContentView(url: "https://dreamweaver-backend-v2-production.up.railway.app/privacy_\(langCode).html", title: "settings_privacy".localized)
        }
        .sheet(isPresented: $showingMailView) {
            MailView(
                recipient: Constants.App.supportEmail,
                subject: "DreamSpire Support",
                body: "\n\n---\nApp Version: \(appVersion)\nDevice: \(UIDevice.current.model)\nOS: \(UIDevice.current.systemVersion)"
            )
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showingTransactionHistory) {
            TransactionHistoryView()
        }
        // FIXED: Changed to fullScreenCover as requested
        .fullScreenCover(isPresented: $showingLogin) {
            LoginView(onAuthenticated: { showingLogin = false })
        }
        // MARK: - Real-time Update Listeners
        .onReceive(NotificationCenter.default.publisher(for: .subscriptionDidChange)) { _ in
            DWLogger.shared.info("🔔 Settings: subscriptionDidChange received - refreshing UI", category: .ui)
            Task {
                await subscriptionService.refreshSubscription()
                try? await coinService.fetchBalance()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .coinBalanceDidChange)) { _ in
            DWLogger.shared.info("🔔 Settings: coinBalanceDidChange received", category: .ui)
            // CoinService is @ObservedObject, UI will update automatically
        }
        .onChange(of: showingPaywall) { _, isShowing in
            if !isShowing {
                // Paywall kapandığında subscription ve coin durumunu yenile
                DWLogger.shared.info("📍 Paywall closed - refreshing subscription and coins", category: .ui)
                Task {
                    await subscriptionService.refreshSubscription()
                    try? await coinService.fetchBalance()
                }
            }
        }
        .onChange(of: showingCoinShop) { _, isShowing in
            if !isShowing {
                // CoinShop kapandığında coin durumunu yenile
                DWLogger.shared.info("📍 CoinShop closed - refreshing coins", category: .ui)
                Task {
                    try? await coinService.fetchBalance()
                }
            }
        }
        .onChange(of: showingLogin) { _, isShowing in
            if !isShowing {
                // Login kapandığında tüm kullanıcı verilerini yenile
                DWLogger.shared.info("📍 Login dismissed - refreshing user data", category: .ui)
                Task {
                    // 1. Auth state garantiye al
                    // checkUserState zaten authManager init'te var ama listener belki kaçırdı
                    
                    // 2. Coin ve Subscription yenile (force refresh yapmıyoruz cache varsa kullansın, ama auth değişince cache zaten geçersiz olmalı)
                    // Aslında auth değişince AppPreloadService temizliyor.
                    await coinService.refreshBalance()
                    await subscriptionService.refreshSubscription()
                    
                    // 3. User profilini yenile (loadSettings sync, loadStatistics async)
                    viewModel.loadSettings()
                    await viewModel.loadStatistics()
                }
            }
        }
        .withGlassDialogs()
        .withGlassAlerts()
        .onChange(of: viewModel.successMessage) { _, newValue in
            if let message = newValue {
                GlassAlertManager.shared.success(
                    "settings_success_title".localized,
                    message: message,
                    duration: 2.0  // Give user time to read
                )
                // Clear after showing
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    viewModel.successMessage = nil
                }
            }
        }
        .onChange(of: viewModel.error) { _, newValue in
            if let error = newValue {
                GlassAlertManager.shared.error(
                    "settings_error_title".localized,
                    message: error
                )
                // Clear after showing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    viewModel.error = nil
                }
            }
        }
        .task {
            // ... mevcut task kodu ... -> bunu ellemeyeceğiz
            // Skip if already loaded
            guard !hasLoaded else {
                DWLogger.shared.debug("✅ Settings already loaded, using cache", category: .ui)
                return
            }

            // Load settings once - repositories handle caching
            viewModel.loadSettings()
            checkNotificationStatus()

            // Repositories will use cache if valid, no redundant API calls
            Task {
                try? await coinService.fetchBalance()
                try? await subscriptionService.loadSubscription()
                await viewModel.loadStatistics()

                await MainActor.run {
                    hasLoaded = true
                    DWLogger.shared.info("✅ Settings loaded (first time)", category: .ui)
                }
            }
        }
        .onAppear {
            // Her görünüşte verileri güncelle (Cache logic serviste zaten var)
            Task {
                try? await coinService.fetchBalance()
            }
            
            // Listen for app becoming active (returning from Settings)
            NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: .main
            ) { _ in
                checkNotificationStatus()
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
        }
        .preferredColorScheme(selectedTheme == "light" ? .light : selectedTheme == "dark" ? .dark : nil)
    }

    // MARK: - Computed Properties

    private var languageDisplayName: String {
        switch selectedLanguage {
        case "tr": return "Türkçe"
        case "en": return "English"
        case "fr": return "Français"
        case "de": return "Deutsch"
        case "es": return "Español"
        default: return "Türkçe"
        }
    }

    private var appVersion: String {
        return Constants.App.version
    }
    
    // Language picker popup view
    private var languagePickerPopup: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        showingLanguagePicker = false
                    }
                }
            
            // Popup
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("settings_language".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            showingLanguagePicker = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding()
                
                Divider().background(Color.white.opacity(0.2))
                
                // Language options
                VStack(spacing: 0) {
                    languageOption(code: "tr", name: "Türkçe", flag: "🇹🇷")
                    languageOption(code: "en", name: "English", flag: "🇬🇧")
                    languageOption(code: "fr", name: "Français", flag: "🇫🇷")
                    languageOption(code: "de", name: "Deutsch", flag: "🇩🇪")
                    languageOption(code: "es", name: "Español", flag: "🇪🇸")
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.15, green: 0.1, blue: 0.25))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 40)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: showingLanguagePicker)
    }
    
    private func languageOption(code: String, name: String, flag: String) -> some View {
        Button(action: {
            selectedLanguage = code
            if let language = LocalizationManager.Language(rawValue: code) {
                LocalizationManager.shared.setLanguage(language)
            }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                showingLanguagePicker = false
            }
        }) {
            HStack(spacing: 12) {
                Text(flag)
                    .font(.title2)
                
                Text(name)
                    .font(.body)
                    .foregroundColor(.white)
                
                Spacer()
                
                if selectedLanguage == code {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(selectedLanguage == code ? Color.white.opacity(0.1) : Color.clear)
        }
    }

    // MARK: - Helper Functions

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                viewModel.notificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }

    private func handleNotificationToggle(_ enabled: Bool) {
        if enabled {
            // Check current authorization status
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async {
                    switch settings.authorizationStatus {
                    case .notDetermined:
                        // First time - show explanation and request permission
                        let config = GlassDialogConfig(
                            title: "notification_title".localized,
                            message: "notification_enable_message".localized,
                            primaryButton: .init(
                                title: "notification_enable".localized,
                                role: .normal,
                                action: {
                                    self.requestNotificationPermission()
                                    GlassDialogManager.shared.dismiss()
                                }
                            ),
                            secondaryButton: .init(
                                title: "cancel".localized,
                                role: .cancel,
                                action: {
                                    self.viewModel.notificationsEnabled = false
                                    GlassDialogManager.shared.dismiss()
                                }
                            )
                        )
                        GlassDialogManager.shared.show(config)

                    case .denied:
                        // Previously denied - direct to Settings
                        let config = GlassDialogConfig(
                            title: "notification_title".localized,
                            message: "notification_disabled_message".localized,
                            primaryButton: .init(
                                title: "notification_go_settings".localized,
                                role: .normal,
                                action: {
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                    GlassDialogManager.shared.dismiss()
                                }
                            ),
                            secondaryButton: .init(
                                title: "cancel".localized,
                                role: .cancel,
                                action: {
                                    self.viewModel.notificationsEnabled = false
                                    GlassDialogManager.shared.dismiss()
                                }
                            )
                        )
                        GlassDialogManager.shared.show(config)

                    case .authorized, .provisional, .ephemeral:
                        // Already authorized - just update UI
                        self.viewModel.notificationsEnabled = true

                    @unknown default:
                        self.viewModel.notificationsEnabled = false
                    }
                }
            }
        } else {
            // User wants to disable - guide them to Settings
            let config = GlassDialogConfig(
                title: "notification_title".localized,
                message: "notification_disable_message".localized,
                primaryButton: .init(
                    title: "notification_go_settings".localized,
                    role: .normal,
                    action: {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                        GlassDialogManager.shared.dismiss()
                    }
                ),
                secondaryButton: .init(
                    title: "cancel".localized,
                    role: .cancel,
                    action: {
                        viewModel.notificationsEnabled = true
                        GlassDialogManager.shared.dismiss()
                    }
                )
            )
            GlassDialogManager.shared.show(config)
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                viewModel.notificationsEnabled = granted
                if !granted {
                    GlassDialogManager.shared.alert(
                        title: "notification_disabled_title".localized,
                        message: "notification_disabled_message".localized,
                        buttonTitle: "ok".localized
                    )
                }
            }
        }
    }

    private func requestAppReview() {
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    private func openMailApp() {
        if MFMailComposeViewController.canSendMail() {
            showingMailView = true
        } else {
            // Fallback: Default mail app
            let email = Constants.App.supportEmail
            if let url = URL(string: "mailto:\(email)") {
                UIApplication.shared.open(url) { success in
                    if !success {
                        self.tryAlternativeMailApps()
                    }
                }
            }
        }
    }

    private func tryAlternativeMailApps() {
        let email = Constants.App.supportEmail

        // Popüler mail uygulamaları URL scheme'leri
        let mailApps: [(name: String, urlString: String)] = [
            ("Gmail", "googlegmail://co?to=\(email)"),
            ("Outlook", "ms-outlook://compose?to=\(email)"),
            ("Yahoo Mail", "ymail://mail/compose?to=\(email)"),
            ("Spark", "readdle-spark://compose?recipient=\(email)"),
            ("ProtonMail", "protonmail://mailto:\(email)")
        ]

        // Her bir uygulamayı sırayla dene
        for app in mailApps {
            if let url = URL(string: app.urlString),
               UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                return
            }
        }

        // Hiçbir mail uygulaması bulunamadı, email'i kopyala
        copyEmailToClipboard()
    }

    private func copyEmailToClipboard() {
        UIPasteboard.general.string = Constants.App.supportEmail

        // Kullanıcıya bildirim göster
        GlassAlertManager.shared.show(
            GlassAlertConfig(
                type: .success,
                title: "settings_copy_email_success_title".localized,
                message: "settings_copy_email_success_message".localized,
                duration: 2.0
            )
        )
    }


    private func signOut() {
        do {
            try authManager.signOut()
            onSignOut()
        } catch {
            print("Sign out error: \(error)")
        }
    }

    private func showSignOutConfirmation() {
        let config = GlassDialogConfig(
            title: "settings_sign_out_title".localized,
            message: "settings_sign_out_message".localized,
            primaryButton: .init(
                title: "settings_sign_out_confirm".localized,
                role: .destructive,
                action: {
                    self.signOut()
                    GlassDialogManager.shared.dismiss()
                }
            ),
            secondaryButton: .init(
                title: "settings_sign_out_cancel".localized,
                role: .cancel,
                action: { GlassDialogManager.shared.dismiss() }
            )
        )
        
        GlassDialogManager.shared.show(config)
    }

    private func confirmDeleteAccount() {
        let config = GlassDialogConfig(
            title: "settings_delete_account_title".localized,
            message: "settings_delete_account_message".localized,
            primaryButton: .init(
                title: "settings_delete_account_confirm".localized,
                role: .destructive,
                action: {
                    Task {
                        await self.deleteAccount()
                    }
                    GlassDialogManager.shared.dismiss()
                }
            ),
            secondaryButton: .init(
                title: "cancel".localized,
                role: .cancel,
                action: {
                    GlassDialogManager.shared.dismiss()
                }
            )
        )
        GlassDialogManager.shared.show(config)
    }

    private func deleteAccount() async {
        do {
            try await authManager.deleteAccount()

            await MainActor.run {
                let config = GlassDialogConfig(
                    title: "settings_delete_account_title".localized,
                    message: "settings_account_deleted".localized,
                    primaryButton: .init(
                        title: "ok".localized,
                        role: .normal,
                        action: {
                            GlassDialogManager.shared.dismiss()
                            self.onSignOut()
                        }
                    ),
                    secondaryButton: nil
                )
                GlassDialogManager.shared.show(config)
            }
        } catch {
            await MainActor.run {
                GlassDialogManager.shared.alert(
                    title: "error".localized,
                    message: error.localizedDescription,
                    buttonTitle: "ok".localized
                )
            }
        }
    }
}

// MARK: - Custom Views

struct UserProfileHeader: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    // Inline Edit State
    @State private var isEditing = false
    @State private var editName = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar (Sol taraf)
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 64, height: 64)
                
                // Baş harf veya Anonim İkon
                if viewModel.displayName.isEmpty {
                    Image(systemName: "person.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                } else {
                    Text(String(viewModel.displayName.prefix(1)).uppercased())
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // İsim Alanı (Inline Edit)
                HStack(spacing: 8) {
                    if isEditing {
                        TextField("profile_name_placeholder".localized, text: $editName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($isFocused)
                            .submitLabel(.done)
                            .onSubmit {
                                saveName()
                            }
                            .frame(maxWidth: 200) // Genişlik sınırlaması
                        
                        Button(action: saveName) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title3)
                        }
                    } else {
                        Text(viewModel.displayName.isEmpty ? "profile_user".localized : viewModel.displayName)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        // Sadece kalem ikonu
                        Button(action: {
                            editName = viewModel.displayName
                            isEditing = true
                            isFocused = true
                        }) {
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                
                Text(viewModel.email)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
        .padding()
        .background(
            Color.white.opacity(0.15)
                .overlay(Color.white.opacity(0.05))
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func saveName() {
        if !editName.isEmpty {
            viewModel.displayName = editName
            Task {
                await viewModel.updateDisplayName()
            }
        }
        isEditing = false
    }
}

struct GuestUserHeader: View {
    var onLoginTap: (() -> Void)? = nil
    
    var body: some View {
        Button(action: {
            onLoginTap?()
        }) {
            HStack(spacing: 16) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.545, green: 0.361, blue: 0.965).opacity(0.6), Color(red: 0.902, green: 0.475, blue: 0.976).opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .overlay(Image(systemName: "person.fill").font(.title2).foregroundColor(.white))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("guest_user".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.caption)
                            .foregroundColor(Color(red: 0.545, green: 0.361, blue: 0.965))
                        Text("settings_tap_to_login".localized)
                            .font(.caption)
                            .foregroundColor(Color(red: 0.545, green: 0.361, blue: 0.965))
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.white.opacity(0.15), Color.white.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(red: 0.545, green: 0.361, blue: 0.965).opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct GuestUpgradeCard: View {
    var onUpgrade: () -> Void
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        Button(action: onUpgrade) {
            ZStack {
                // Background Image
                Image("PremiumBannerBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 140)
                    .clipped()
                    .cornerRadius(16)
                
                // Gradient overlay (left dark → right transparent)
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.85),
                        Color.black.opacity(0.6),
                        Color.black.opacity(0.3),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 140)
                .cornerRadius(16)
                
                // Content
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        // Title
                        VStack(alignment: .leading, spacing: 2) {
                            Text("settings_premium_unlock".localized)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("settings_premium_benefits".localized)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(hex: "fbbf24"), Color(hex: "f59e0b")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                        
                        // Benefits row
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "waveform.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "fbbf24"))
                                Text("settings_benefit_audio".localized)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "photo.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "fbbf24"))
                                Text("settings_benefit_images".localized)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                        
                        Spacer(minLength: 0)
                        
                        // CTA
                        HStack(spacing: 6) {
                            Text("settings_upgrade_now".localized)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(hex: "f59e0b"))
                            
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "f59e0b"))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.white))
                        .scaleEffect(pulseScale)
                        .shadow(color: Color(hex: "f59e0b").opacity(pulseScale > 1.03 ? 0.5 : 0.2), radius: pulseScale > 1.03 ? 12 : 6, x: 0, y: 0)
                    }
                    .padding(16)
                    
                    Spacer()
                }
                .frame(height: 140)
            }
            .frame(height: 140)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
            .shadow(color: Color(hex: "f59e0b").opacity(0.2), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseScale = 1.06
            }
        }
    }
}

// MARK: - Plus to Pro Upgrade Card (for Plus tier users)
struct PlusToProUpgradeCard: View {
    var onUpgrade: () -> Void
    @State private var shimmerOffset: CGFloat = -1
    
    var body: some View {
        Button(action: onUpgrade) {
            HStack(spacing: 14) {
                // Illustrated story icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "8b5cf6"), Color(hex: "ec4899")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
                .shadow(color: Color(hex: "8b5cf6").opacity(0.4), radius: 8, x: 0, y: 4)
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("settings_pro_unlock".localized)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        
                        // PRO Badge
                        Text("PRO")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "8b5cf6"), Color(hex: "ec4899")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(4)
                    }
                    
                    Text("settings_pro_illustrated".localized)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "ec4899"))
            }
            .padding(14)
            .background(
                ZStack {
                    // Base gradient
                    LinearGradient(
                        colors: [
                            Color(hex: "8b5cf6").opacity(0.15),
                            Color(hex: "ec4899").opacity(0.1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    
                    // Shimmer effect
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .offset(x: shimmerOffset * 300)
                }
            )
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "8b5cf6").opacity(0.4), Color(hex: "ec4899").opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: false)) {
                shimmerOffset = 1
            }
        }
    }
}

struct WalletCard: View {
    let coinBalance: Int
    let tier: SubscriptionTier
    var isLoading: Bool = false
    var onBuyCoins: () -> Void
    var onUpgrade: () -> Void
    var onTransactionHistory: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            // Coin Row
            HStack {
                // Coin Balance - Tıklanabilir alan
                Button(action: {
                    if let onTransactionHistory = onTransactionHistory {
                        onTransactionHistory()
                    }
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("subscription_coin_balance".localized)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white.opacity(0.7))

                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                                    .frame(height: 33) // Match font height
                            } else {
                                Text("\(coinBalance)")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            CoinIconView(size: 24)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .contentShape(Rectangle())
                .disabled(onTransactionHistory == nil)

                Spacer()

                Button(action: onBuyCoins) {
                    Text("subscription_load".localized)
                        .font(.footnote.bold())
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .cornerRadius(20)
                }
                .buttonStyle(PlainButtonStyle())
            }

            Divider().background(Color.white.opacity(0.3))

            // Subscription Row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("subscription_membership".localized)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.7))

                    HStack(spacing: 6) {
                        Image(systemName: tier == .pro ? "crown.fill" : "star.fill")
                            .foregroundColor(tier == .pro ? .yellow : .orange)
                        Text(tier.displayName)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }

                Spacer()

                if tier != .pro {
                    Button(action: onUpgrade) {
                        Text("subscription_upgrade".localized)
                            .font(.footnote.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.purple)
                            .cornerRadius(20)
                    }
                }
            }

            // Transaction History Button
            if let onTransactionHistory = onTransactionHistory {
                Button(action: onTransactionHistory) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 14))
                        Text("coins_history".localized)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                .contentShape(Rectangle())
                .padding(.top, 4)
            }
        }
        .padding(20)
        .background(
            Color.white.opacity(0.15)
                .overlay(Color.white.opacity(0.05))
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
        )
    }
}

struct SettingsButtonRow: View {
    let icon: String
    let color: Color
    let title: String
    var value: String? = nil
    var isLoading: Bool = false
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon Box
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color)
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .foregroundColor(.white)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white.opacity(0.6))
                } else if let value = value {
                    Text(value)
                        .foregroundColor(.white.opacity(0.6))
                        .font(.subheadline)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
}

struct SettingsToggleRow: View {
    let icon: String
    let color: Color
    let title: String
    @Binding var isOn: Bool
    var onChange: ((Bool) -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }

            Toggle(title, isOn: Binding(
                get: { isOn },
                set: { newValue in
                    if let onChange = onChange {
                        onChange(newValue)
                    } else {
                        isOn = newValue
                    }
                }
            ))
            .foregroundColor(.white)
        }
    }
}

struct LockedCharactersRow: View {
    var onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon with lock overlay
                ZStack(alignment: .bottomTrailing) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.purple)
                            .frame(width: 30, height: 30)
                        Image(systemName: "theatermasks.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    // Small lock badge
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.white)
                        .padding(2)
                        .background(Circle().fill(Color.orange))
                        .offset(x: 4, y: 4)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("settings_my_characters".localized)
                        .foregroundColor(.white)
                        .font(.body)
                    
                    Text("settings_characters_locked".localized)
                        .foregroundColor(.orange.opacity(0.9))
                        .font(.caption)
                }
                
                Spacer()
                
                // Upgrade badge
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.caption2)
                    Text("upgrade".localized)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color.orange, Color.pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                )
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
}

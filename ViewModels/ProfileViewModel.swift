//
//  ProfileViewModel.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025-11-02.
//

import Foundation
import FirebaseAuth
import Combine

@MainActor
class ProfileViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var user: User?
    @Published var displayName: String = ""
    @Published var email: String = ""
    
    // Statistics
    @Published var totalStories: Int = 0
    @Published var totalReadingTime: Double = 0
    @Published var totalCharacters: Int = 0
    @Published var favoriteCount: Int = 0
    @Published var totalReads: Int = 0
    
    // Content counts (for new settings)
    @Published var savedCharactersCount: Int = 0
    @Published var storiesCount: Int = 0
    @Published var favoritesCount: Int = 0
    
    // Settings
    @Published var notificationsEnabled: Bool = true
    @Published var autoPlayAudio: Bool = true
    @Published var offlineContentEnabled: Bool = false
    @Published var downloadQuality: DownloadQuality = .high
    @Published var dataUsageMode: DataUsageMode = .wifiOnly
    
    // Subscription
    @Published var subscription: Subscription?
    @Published var subscriptionTier: SubscriptionTier = .free
    @Published var renewalDate: String = "15 Ara 2024"
    @Published var memberSince: String = "Eki 2024"
    
    // Coins
    @Published var coinBalance: Int = 0
    
    @Published var isLoading: Bool = true
    @Published var isSaving: Bool = false
    @Published var isRestoringPurchases: Bool = false
    @Published var error: String?
    @Published var successMessage: String?
    
    // MARK: - Dependencies

    private let apiClient = APIClient.shared
    private let authManager = AuthManager.shared
    private let characterRepository = CharacterRepository.shared
    private let favoritesRepository = FavoritesRepository.shared
    private let userStoryRepository = UserStoryRepository.shared
    private var cancellables = Set<AnyCancellable>()

    // State tracking to prevent redundant loads
    private var hasLoadedStatistics = false
    
    // MARK: - Initialization
    
    init() {
        loadUserProfile()
        loadSettings()
        observeAuthState()
        observeCharacterChanges()
    }

    private func observeCharacterChanges() {
        NotificationCenter.default.publisher(for: .characterCountDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.refreshCharacterCount()
                }
            }
            .store(in: &cancellables)
    }

    func refreshCharacterCount() async {
        guard authManager.currentUser != nil else { return }

        do {
            // Use repository (cache-aware)
            let characters = try await characterRepository.getCharacters()
            await MainActor.run {
                self.savedCharactersCount = characters.count
                self.totalCharacters = characters.count
            }
        } catch {
            DWLogger.shared.error("Failed to refresh character count", error: error, category: .general)
        }
    }
    
    // MARK: - User Profile
    
    private func observeAuthState() {
        authManager.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] firebaseUser in
                self?.updateFromFirebaseUser(firebaseUser)
            }
            .store(in: &cancellables)
    }

    private func updateFromFirebaseUser(_ firebaseUser: FirebaseAuth.User?) {
        guard let firebaseUser = firebaseUser else {
            self.user = nil
            return
        }

        self.email = firebaseUser.email ?? ""
        self.displayName = firebaseUser.displayName ?? ""

        // Format member since date
        if let creationDate = firebaseUser.metadata.creationDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM yyyy"
            formatter.locale = Locale(identifier: "tr_TR")
            memberSince = formatter.string(from: creationDate)
        }
    }
    
    func loadUserProfile() {
        guard let firebaseUser = authManager.currentUser else { return }
        
        displayName = firebaseUser.displayName ?? ""
        email = firebaseUser.email ?? ""
        
        // Load additional user data from backend
        Task {
            await loadStatistics()
        }
    }
    
    func loadStatistics() async {
        // Skip if already loaded (unless forcing refresh)
        if hasLoadedStatistics {
            DWLogger.shared.debug("✅ Statistics already loaded, using cache", category: .general)
            return
        }

        guard let userId = authManager.currentUser?.uid else { return }

        await MainActor.run {
            isLoading = true
            error = nil
        }

        do {
            // Get user's stories from repository (cache-aware)
            let stories = try await userStoryRepository.getStories(userId: userId)

            // Get favorites from repository (cache-aware)
            let favorites = try await favoritesRepository.getFavorites()

            // Get saved characters from repository (cache-aware)
            let characters = try await characterRepository.getCharacters()

            await MainActor.run {
                totalStories = stories.count

                // Calculate total reading time (using rounded minutes for accurate stats)
                totalReadingTime = stories.reduce(0.0) { $0 + Double($1.roundedMinutes) }

                // Calculate total reads (views)
                totalReads = stories.reduce(0) { $0 + ($1.views ?? 0) }

                favoriteCount = favorites.count
                totalCharacters = characters.count

                // Update content counts
                savedCharactersCount = characters.count
                storiesCount = stories.count
                favoritesCount = favorites.count

                // Mark as loaded
                hasLoadedStatistics = true
            }

            DWLogger.shared.info("✅ Statistics loaded successfully", category: .general)

        } catch {
            await MainActor.run {
                self.error = "İstatistikler yüklenemedi: \(error.localizedDescription)"
            }
            DWLogger.shared.error("Statistics loading error", error: error, category: .general)
        }

        await MainActor.run {
            isLoading = false
        }
    }
    
    // MARK: - Profile Updates
    
    func updateDisplayName() async {
        guard !displayName.isEmpty else {
            await MainActor.run {
                error = "İsim boş olamaz"
            }
            return
        }

        await MainActor.run {
            isSaving = true
            error = nil
        }

        do {
            let changeRequest = authManager.currentUser?.createProfileChangeRequest()
            changeRequest?.displayName = displayName
            try await changeRequest?.commitChanges()

            await MainActor.run {
                successMessage = "İsim güncellendi"
            }
            DWLogger.shared.logUserAction("Display Name Updated", details: displayName)
        } catch {
            await MainActor.run {
                self.error = "İsim güncellenemedi: \(error.localizedDescription)"
            }
            DWLogger.shared.error("Display name update error", error: error, category: .general)
        }

        await MainActor.run {
            isSaving = false
        }
    }
    
    func updateEmail(newEmail: String, password: String) async {
        guard !newEmail.isEmpty else {
            await MainActor.run {
                error = "E-posta boş olamaz"
            }
            return
        }

        guard let currentUser = authManager.currentUser else {
            await MainActor.run {
                error = "Kullanıcı oturumu bulunamadı"
            }
            return
        }

        await MainActor.run {
            isSaving = true
            error = nil
        }

        do {
            // Re-authenticate user before email change
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            try await currentUser.reauthenticate(with: credential)

            // Update email
            try await currentUser.updateEmail(to: newEmail)

            await MainActor.run {
                self.email = newEmail
                successMessage = "E-posta güncellendi"
            }
            DWLogger.shared.logUserAction("Email Updated")
        } catch {
            await MainActor.run {
                self.error = "E-posta güncellenemedi: \(error.localizedDescription)"
            }
            DWLogger.shared.error("Email update error", error: error, category: .general)
        }

        await MainActor.run {
            isSaving = false
        }
    }
    
    func changePassword(currentPassword: String, newPassword: String) async {
        guard !newPassword.isEmpty else {
            await MainActor.run {
                error = "Yeni şifre boş olamaz"
            }
            return
        }

        guard newPassword.count >= 6 else {
            await MainActor.run {
                error = "Şifre en az 6 karakter olmalı"
            }
            return
        }

        guard let currentUser = authManager.currentUser else {
            await MainActor.run {
                error = "Kullanıcı oturumu bulunamadı"
            }
            return
        }

        await MainActor.run {
            isSaving = true
            error = nil
        }

        do {
            // Re-authenticate user
            let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
            try await currentUser.reauthenticate(with: credential)

            // Update password
            try await currentUser.updatePassword(to: newPassword)

            await MainActor.run {
                successMessage = "Şifre güncellendi"
            }
            DWLogger.shared.logUserAction("Password Changed")
        } catch {
            await MainActor.run {
                self.error = "Şifre güncellenemedi: \(error.localizedDescription)"
            }
            DWLogger.shared.error("Password update error", error: error, category: .general)
        }

        await MainActor.run {
            isSaving = false
        }
    }
    
    // MARK: - Settings
    
    func toggleNotifications() {
        // Notification toggle is now handled by SettingsView's handleNotificationToggle
        // which properly checks system permissions and guides user to Settings
        notificationsEnabled.toggle()
        // Don't save to UserDefaults - system permissions are the source of truth
    }
    
    func toggleAutoPlay() {
        autoPlayAudio.toggle()
        saveSettings()
    }
    
    func toggleOfflineContent() {
        offlineContentEnabled.toggle()
        saveSettings()
    }
    
    func updateDownloadQuality(_ quality: DownloadQuality) {
        downloadQuality = quality
        saveSettings()
    }
    
    func updateDataUsageMode(_ mode: DataUsageMode) {
        dataUsageMode = mode
        saveSettings()
    }
    
    func saveSettings() {
        // Don't save notification setting to UserDefaults - it's controlled by system permissions
        UserDefaults.standard.set(autoPlayAudio, forKey: "autoPlayAudio")
        UserDefaults.standard.set(offlineContentEnabled, forKey: "offlineContentEnabled")
        UserDefaults.standard.set(downloadQuality.rawValue, forKey: "downloadQuality")
        UserDefaults.standard.set(dataUsageMode.rawValue, forKey: "dataUsageMode")
    }
    
    func loadSettings() {
        // Don't load notification setting from UserDefaults - let SettingsView check system permission
        // notificationsEnabled will be set by checkNotificationStatus() in SettingsView

        autoPlayAudio = UserDefaults.standard.bool(forKey: "autoPlayAudio")
        offlineContentEnabled = UserDefaults.standard.bool(forKey: "offlineContentEnabled")

        if let qualityString = UserDefaults.standard.string(forKey: "downloadQuality"),
           let quality = DownloadQuality(rawValue: qualityString) {
            downloadQuality = quality
        }

        if let modeString = UserDefaults.standard.string(forKey: "dataUsageMode"),
           let mode = DataUsageMode(rawValue: modeString) {
            dataUsageMode = mode
        }

        // Load coin balance and subscription
        Task {
            await loadCoinBalance()
            await loadSubscription()
        }
    }
    
    func loadCoinBalance() async {
        do {
            let coinService = CoinService.shared
            try await coinService.fetchBalance()
            await MainActor.run {
                self.coinBalance = coinService.currentBalance
            }
        } catch {
            DWLogger.shared.error("Failed to load coin balance", error: error, category: .app)
        }
    }
    
    func loadSubscription() async {
        let subscriptionService = SubscriptionService.shared
        await subscriptionService.loadSubscription()
        await MainActor.run {
            self.subscription = subscriptionService.subscription
        }
    }
    
    func updateNotificationSettings() async {
        // Notification settings are now controlled by system permissions, not UserDefaults
        // SettingsView.checkNotificationStatus() will sync the toggle with actual system state
        // TODO: Update server-side notification preferences if needed
    }
    
    func clearCache() async {
        // TODO: Implement cache clearing
        await MainActor.run {
            successMessage = "Önbellek temizlendi"
        }
        DWLogger.shared.logUserAction("Cache Cleared")
    }
    
    func restorePurchases() async {
        await MainActor.run {
            isRestoringPurchases = true
            error = nil
        }

        await StoreKitService.shared.restorePurchases()

        await MainActor.run {
            isRestoringPurchases = false
            if let storeError = StoreKitService.shared.error {
                self.error = storeError
            } else {
                successMessage = "settings_restore_success".localized
            }
        }
        DWLogger.shared.logUserAction("Purchases Restored")
    }
    
    // MARK: - Account Management
    
    func deleteAccount() async {
        guard let currentUser = authManager.currentUser else {
            await MainActor.run {
                error = "Kullanıcı oturumu bulunamadı"
            }
            return
        }

        await MainActor.run {
            isLoading = true
            error = nil
        }

        do {
            // Delete user account
            try await currentUser.delete()

            // Sign out
            try authManager.signOut()

            await MainActor.run {
                successMessage = "Hesap silindi"
            }
            DWLogger.shared.logUserAction("Account Deleted")
        } catch {
            await MainActor.run {
                self.error = "Hesap silinemedi: \(error.localizedDescription)"
            }
            DWLogger.shared.error("Account deletion error", error: error, category: .general)
        }

        await MainActor.run {
            isLoading = false
        }
    }
    
    func signOut() {
        do {
            try authManager.signOut()
            successMessage = "Çıkış yapıldı"
            DWLogger.shared.logUserAction("Signed Out")
        } catch {
            self.error = "Çıkış yapılamadı: \(error.localizedDescription)"
            DWLogger.shared.error("Sign out error", error: error, category: .general)
        }
    }
    
    // MARK: - Statistics Helpers
    
    var totalReadingHours: Double {
        return totalReadingTime / 60.0
    }
    
    var formattedReadingTime: String {
        if totalReadingTime < 60 {
            return String(format: "%.0f", totalReadingTime)
        } else {
            return String(format: "%.1f", totalReadingHours)
        }
    }
}

// MARK: - Supporting Types

enum DownloadQuality: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .low:
            return "Düşük"
        case .medium:
            return "Orta"
        case .high:
            return "Yüksek"
        }
    }
}

enum DataUsageMode: String, CaseIterable {
    case wifiOnly = "wifi_only"
    case wifiAndCellular = "wifi_and_cellular"
    
    var displayName: String {
        switch self {
        case .wifiOnly:
            return "Yalnızca Wi-Fi"
        case .wifiAndCellular:
            return "Wi-Fi ve Mobil Veri"
        }
    }
}

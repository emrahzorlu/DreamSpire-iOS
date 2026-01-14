//
//  ProfileView.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//

import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var showingSettings = false
    @State private var showingSubscription = false
    @State private var showingCharacters = false
    @State private var showingFavorites = false
    @State private var showingLogin = false
    @State private var showingAccountLink = false
    
    var onSignOut: () -> Void
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient.dwBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header with title and settings button
                    HStack {
                        Text("profile_title".localized)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 50)
                    
                    // User Info Card
                    userInfoCard
                    
                    // Usage Stats Section
                    usageStatsSection
                    
                    // Subscription Details Card
                    subscriptionCard
                    
                    // Quick Actions Section
                    quickActionsSection
                    
                    // Logout Button
                    logoutButton
                    
                    Spacer()
                        .frame(height: 100)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingSettings) {
            SettingsView(onSignOut: onSignOut)
        }
        .sheet(isPresented: $showingSubscription) {
            SubscriptionView()
        }
        .sheet(isPresented: $showingCharacters) {
            MyCharactersView()
        }
        .sheet(isPresented: $showingFavorites) {
            UserLibraryView(onLoginRequest: {
                showingFavorites = false
                showingLogin = true
            })
            .onAppear {
                // Favoriler tabını seç
                // TODO: Tab selection implementation if needed
            }
        }
        .sheet(isPresented: $showingLogin) {
            LoginView(onAuthenticated: {
                // When login is successful from the sheet, dismiss the sheet.
                // The ProfileView will automatically update because authManager's state will change.
                showingLogin = false
            })
        }
        .task {
            await viewModel.loadStatistics()
        }
        .onAppear {
            DWLogger.shared.logViewAppear("ProfileView")
        }
        .preferredColorScheme(.light)
    }
    
    // MARK: - User Info Card
    
    @ViewBuilder
    private var userInfoCard: some View {
        switch authManager.userState {
        case .guest:
            guestUserCard
        case .authenticated:
            authenticatedUserCard
        }
    }
    

    
    // MARK: - Guest User Card
    
    private var guestUserCard: some View {
        VStack(alignment: .center, spacing: 16) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 72))
                .foregroundColor(.white.opacity(0.5))
            
            Text("profile_guest_mode".localized)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            Text("profile_guest_hint".localized)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            
            Button(action: { showingLogin = true }) {
                Text("profile_sign_in_or_create".localized)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                    )
            }
            .padding(.top, 8)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.15))
                .background(.ultraThinMaterial.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Authenticated User Card
    
    private var authenticatedUserCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                // Avatar
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.4), lineWidth: 2)
                    )
                    .overlay(
                        Text(viewModel.displayName.prefix(1).uppercased())
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                    )
                
                // User Details
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.displayName.isEmpty ? "profile_user".localized : viewModel.displayName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(viewModel.email)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(String(format: "profile_member_since".localized, viewModel.memberSince))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            // Plan Badge
            HStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                
                Text(viewModel.subscriptionTier.displayName + "profile_plan_suffix".localized)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.659, green: 0.353, blue: 0.969), Color.purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(20)
            .shadow(color: Color.purple.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.15))
                .background(.ultraThinMaterial.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Usage Stats Section
    
    private var usageStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("profile_this_month".localized)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(
                    icon: "sparkles",
                    value: "\(viewModel.totalStories)",
                    label: "profile_stories".localized
                )
                
                StatCard(
                    icon: "book.fill",
                    value: "\(viewModel.totalReads)",
                    label: "profile_reads".localized
                )
                
                StatCard(
                    icon: "person.3.fill",
                    value: "\(viewModel.totalCharacters)",
                    label: "profile_characters".localized
                )
                
                StatCard(
                    icon: "clock.fill",
                    value: viewModel.formattedReadingTime,
                    label: "profile_hours".localized
                )
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Subscription Card
    
    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("profile_subscription_info".localized)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            VStack(spacing: 0) {
                SubscriptionInfoRow(
                    label: "subscription_plan_label".localized,
                    value: viewModel.subscriptionTier.displayName + "profile_yearly_suffix".localized
                )
                
                SubscriptionInfoDivider()
                
                SubscriptionInfoRow(
                    label: "subscription_price_label".localized,
                    value: viewModel.subscriptionTier.fallbackYearlyPrice.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")) + "/" + "paywall_per_year".localized.replacingOccurrences(of: "/", with: "").trimmingCharacters(in: .whitespaces)
                )

                SubscriptionInfoDivider()

                SubscriptionInfoRow(
                    label: "subscription_renewal_label".localized,
                    value: viewModel.renewalDate
                )
                
                SubscriptionInfoDivider()
                
                HStack {
                    Text("profile_status".localized)
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    Text("profile_active".localized)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.8))
                        .cornerRadius(12)
                }
                .frame(height: 44)
            }
            
            Button(action: { showingSubscription = true }) {
                Text("profile_manage_subscription".localized)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
                            )
                    )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.15))
                .background(.ultraThinMaterial.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        VStack(spacing: 12) {
            QuickActionRow(
                icon: "person.3.fill",
                title: "profile_my_characters".localized,
                count: viewModel.totalCharacters,
                action: { showingCharacters = true }
            )

            QuickActionRow(
                icon: "heart.fill",
                title: "profile_my_favorites".localized,
                count: viewModel.favoriteCount,
                action: { showingFavorites = true }
            )

            QuickActionRow(
                icon: "questionmark.circle.fill",
                title: "profile_help_support".localized,
                count: nil,
                action: {
                    if let url = URL(string: Constants.App.websiteURL + "/help") {
                        UIApplication.shared.open(url)
                    }
                }
            )

            QuickActionRow(
                icon: "info.circle.fill",
                title: "profile_about".localized,
                count: nil,
                action: {
                    if let url = URL(string: Constants.App.websiteURL) {
                        UIApplication.shared.open(url)
                    }
                }
            )
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Logout Button
    
    private var logoutButton: some View {
        Button(action: {
            do {
                try authManager.signOut()
                onSignOut()
            } catch {
                DWLogger.shared.error("Sign out failed", error: error, category: .auth)
            }
        }) {
            Text("profile_sign_out".localized)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(red: 1.0, green: 0.7, blue: 0.7))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                        )
                )
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}


// MARK: - Subscription Info Row

struct SubscriptionInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(height: 44)
    }
}

// MARK: - Subscription Info Divider

struct SubscriptionInfoDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.2))
            .frame(height: 0.5)
    }
}

// MARK: - Quick Action Row

struct QuickActionRow: View {
    let icon: String
    let title: String
    let count: Int?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 28)
                
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                
                Spacer()
                
                if let count = count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.15))
                    .background(.ultraThinMaterial.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ProfileView(onSignOut: {})
        .environmentObject(AuthManager.shared)
}

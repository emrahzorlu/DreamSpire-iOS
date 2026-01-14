//
//  Notification+Extensions.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//

import Foundation

extension Notification.Name {
    /// Posted when user's subscription tier changes
    static let subscriptionDidChange = Notification.Name("subscriptionDidChange")

    /// Posted when user's coin balance changes
    static let coinBalanceDidChange = Notification.Name("coinBalanceDidChange")

    /// Posted when character count changes (add/delete)
    static let characterCountDidChange = Notification.Name("characterCountDidChange")

    /// Posted when user wants to navigate to generate tab
    static let navigateToGenerateTab = Notification.Name("navigateToGenerateTab")

    /// Posted when user wants to navigate to library tab
    static let navigateToLibrary = Notification.Name("navigateToLibrary")

    /// Posted when user wants to navigate to library tab and specifically to My Stories segment
    static let navigateToLibraryMyStories = Notification.Name("navigateToLibraryMyStories")

    /// Posted when app language changes
    static let languageChanged = Notification.Name("languageChanged")

    /// Posted when user wants to show paywall
    static let showPaywall = Notification.Name("showPaywall")

    /// Posted when a favorite is toggled from PrewrittenLibraryView (needs FavoriteStore refresh)
    static let favoriteToggledFromPrewritten = Notification.Name("favoriteToggledFromPrewritten")
}

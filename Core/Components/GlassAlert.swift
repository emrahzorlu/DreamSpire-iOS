//
//  GlassAlert.swift
//  DreamSpire
//
//  Global Glass Effect Alert/Toast System
//  Professional in-app notifications
//

import SwiftUI

// MARK: - Alert Type

enum GlassAlertType {
    case success
    case error
    case info
    case warning

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .info: return .blue
        case .warning: return .orange
        }
    }
}

// MARK: - Alert Model

enum AlertButtonStyle {
    case single(title: String, action: (() -> Void)?)
    case dual(primary: String, primaryAction: (() -> Void)?, secondary: String, secondaryAction: (() -> Void)?)
}

struct GlassAlertConfig {
    let type: GlassAlertType
    let title: String
    let message: String?
    let duration: TimeInterval?
    let buttonStyle: AlertButtonStyle?

    init(
        type: GlassAlertType,
        title: String,
        message: String? = nil,
        duration: TimeInterval? = 3.0,
        buttonStyle: AlertButtonStyle? = nil
    ) {
        self.type = type
        self.title = title
        self.message = message
        self.duration = duration
        self.buttonStyle = buttonStyle
    }
}

// MARK: - Glass Alert Manager (Singleton)

@MainActor
class GlassAlertManager: ObservableObject {
    static let shared = GlassAlertManager()

    @Published var currentAlert: GlassAlertConfig?
    @Published var isShowing: Bool = false

    private init() {}

    func show(_ config: GlassAlertConfig) {
        // Dismiss current alert if exists
        if isShowing {
            dismiss()
        }

        // Show new alert with smooth animation
        withAnimation(.easeOut(duration: 0.35)) {
            currentAlert = config
            isShowing = true
        }

        // Auto-dismiss after duration (only if duration is set and no buttons)
        if let duration = config.duration, config.buttonStyle == nil {
            Task {
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                await MainActor.run {
                    self.dismiss()
                }
            }
        }
    }

    func dismiss() {
        withAnimation(.easeIn(duration: 0.25)) {
            isShowing = false
        }

        // Clear alert after animation
        Task {
            try? await Task.sleep(nanoseconds: 250_000_000) // 0.25s
            await MainActor.run {
                self.currentAlert = nil
            }
        }
    }

    // Convenience methods - Auto-dismiss alerts
    func success(_ title: String, message: String? = nil, duration: TimeInterval = 1.5) {
        show(GlassAlertConfig(type: .success, title: title, message: message, duration: duration))
    }

    func error(_ title: String, message: String? = nil, duration: TimeInterval = 2.0) {
        show(GlassAlertConfig(type: .error, title: title, message: message, duration: duration))
    }

    func info(_ title: String, message: String? = nil, duration: TimeInterval = 1.5) {
        show(GlassAlertConfig(type: .info, title: title, message: message, duration: duration))
    }

    func warning(_ title: String, message: String? = nil, duration: TimeInterval = 2.0) {
        show(GlassAlertConfig(type: .warning, title: title, message: message, duration: duration))
    }

    func custom(title: String, message: String? = nil, icon: String, color: Color, duration: TimeInterval = 3.0) {
        let customConfig = GlassAlertConfig(type: .info, title: title, message: message, duration: duration)
        show(customConfig)
    }

    // Single button alert (requires user to tap OK)
    func showAlert(
        type: GlassAlertType,
        title: String,
        message: String,
        buttonTitle: String = "ok".localized,
        action: (() -> Void)? = nil
    ) {
        let config = GlassAlertConfig(
            type: type,
            title: title,
            message: message,
            duration: nil,
            buttonStyle: .single(title: buttonTitle, action: action)
        )
        show(config)
    }

    // Error alert with single OK button
    func errorAlert(
        _ title: String,
        message: String,
        buttonTitle: String = "ok".localized,
        action: (() -> Void)? = nil
    ) {
        showAlert(type: .error, title: title, message: message, buttonTitle: buttonTitle, action: action)
    }

    // Dual button alert (e.g., Cancel/OK)
    func showConfirm(
        type: GlassAlertType,
        title: String,
        message: String,
        primaryButton: String,
        primaryAction: (() -> Void)?,
        secondaryButton: String,
        secondaryAction: (() -> Void)? = nil
    ) {
        let config = GlassAlertConfig(
            type: type,
            title: title,
            message: message,
            duration: nil,
            buttonStyle: .dual(
                primary: primaryButton,
                primaryAction: primaryAction,
                secondary: secondaryButton,
                secondaryAction: secondaryAction
            )
        )
        show(config)
    }
}

// MARK: - Glass Alert View

struct GlassAlertView: View {
    let config: GlassAlertConfig
    @ObservedObject var manager = GlassAlertManager.shared

    var body: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: config.type.icon)
                .font(.system(size: 34)) // Increased from 28
                .foregroundColor(config.type.color)

            // Title
            Text(config.title)
                .font(.system(size: 19, weight: .bold)) // Increased from 15/semibold
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            // Message (optional)
            if let message = config.message {
                Text(message)
                    .font(.system(size: 15, weight: .medium)) // Increased from 13/regular
                    .foregroundColor(.white.opacity(0.9)) // Slightly more opaque
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Buttons (if any)
            if let buttonStyle = config.buttonStyle {
                buttonView(for: buttonStyle)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .frame(maxWidth: 280)
        .background(
            // Glass Effect Background
            ZStack {
                // Blur background
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)

                // Color tint
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                config.type.color.opacity(0.3),
                                config.type.color.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Border
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                config.type.color.opacity(0.6),
                                config.type.color.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        )
        .shadow(color: config.type.color.opacity(0.3), radius: 20, x: 0, y: 10)
        .onTapGesture {
            // Only dismiss on tap if no buttons
            if config.buttonStyle == nil {
                manager.dismiss()
            }
        }
    }

    @ViewBuilder
    private func buttonView(for style: AlertButtonStyle) -> some View {
        switch style {
        case .single(let title, let action):
            Button(action: {
                action?()
                manager.dismiss()
            }) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.545, green: 0.361, blue: 0.965),
                                Color.purple
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }

        case .dual(let primary, let primaryAction, let secondary, let secondaryAction):
            HStack(spacing: 12) {
                // Secondary button
                Button(action: {
                    secondaryAction?()
                    manager.dismiss()
                }) {
                    Text(secondary)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                )
                        )
                }

                // Primary button
                Button(action: {
                    primaryAction?()
                    manager.dismiss()
                }) {
                    Text(primary)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.545, green: 0.361, blue: 0.965),
                                    Color.purple
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                }
            }
        }
    }
}

// MARK: - Glass Alert Container (Add to Root View)

struct GlassAlertContainer: ViewModifier {
    @ObservedObject var manager = GlassAlertManager.shared

    func body(content: Content) -> some View {
        ZStack {
            content

            // Alert overlay
            if manager.isShowing, let config = manager.currentAlert {
                ZStack {
                    // Dark overlay background
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            manager.dismiss()
                        }

                    // Alert
                    GlassAlertView(config: config)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity.combined(with: .scale(scale: 0.95))
                            )
                        )
                }
                .zIndex(99999)
            }
        }
    }
}

// MARK: - View Extension

extension View {
    func withGlassAlerts() -> some View {
        modifier(GlassAlertContainer())
    }
}

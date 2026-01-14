//
//  GlassDialog.swift
//  DreamSpire
//
//  Custom confirmation dialog with glass effect
//  Replaces system alerts with themed UI
//

import SwiftUI

// MARK: - Dialog Config

struct GlassDialogConfig {
    let title: String
    let message: String
    let primaryButton: DialogButton
    let secondaryButton: DialogButton?

    struct DialogButton {
        let title: String
        let role: ButtonRole
        let action: () -> Void

        enum ButtonRole {
            case normal
            case destructive
            case cancel

            var color: Color {
                switch self {
                case .normal: return .blue
                case .destructive: return .red
                case .cancel: return .gray
                }
            }
        }
    }
}

// MARK: - Glass Dialog Manager

@MainActor
class GlassDialogManager: ObservableObject {
    static let shared = GlassDialogManager()

    @Published var currentDialog: GlassDialogConfig?
    @Published var isShowing: Bool = false

    private init() {}

    func show(_ config: GlassDialogConfig) {
        // Prevent showing multiple dialogs at once
        guard !isShowing else { return }
        
        withAnimation(.easeOut(duration: 0.3)) {
            currentDialog = config
            isShowing = true
        }
    }

    func dismiss() {
        withAnimation(.easeIn(duration: 0.25)) {
            isShowing = false
        }

        Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            await MainActor.run {
                self.currentDialog = nil
            }
        }
    }

    // Convenience method for simple alerts (single button)
    func alert(
        title: String,
        message: String,
        buttonTitle: String = "Tamam",
        action: (() -> Void)? = nil
    ) {
        let config = GlassDialogConfig(
            title: title,
            message: message,
            primaryButton: .init(
                title: buttonTitle,
                role: .normal,
                action: {
                    action?()
                    self.dismiss()
                }
            ),
            secondaryButton: nil
        )
        show(config)
    }

    // Convenience method for confirmation dialogs (two buttons)
    func confirm(
        title: String,
        message: String,
        confirmTitle: String = "Onayla",
        confirmAction: @escaping () -> Void,
        isDestructive: Bool = false
    ) {
        let config = GlassDialogConfig(
            title: title,
            message: message,
            primaryButton: .init(
                title: confirmTitle,
                role: isDestructive ? .destructive : .normal,
                action: {
                    confirmAction()
                    self.dismiss()
                }
            ),
            secondaryButton: .init(
                title: "İptal",
                role: .cancel,
                action: {
                    self.dismiss()
                }
            )
        )
        show(config)
    }
}

// MARK: - Glass Dialog View

struct GlassDialogView: View {
    let config: GlassDialogConfig
    @ObservedObject var manager = GlassDialogManager.shared

    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text(config.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            // Message
            Text(config.message)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // Buttons
            VStack(spacing: 12) {
                // Primary Button
                Button(action: config.primaryButton.action) {
                    Text(config.primaryButton.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(config.primaryButton.role.color)
                        .cornerRadius(12)
                }

                // Secondary Button (if exists)
                if let secondaryButton = config.secondaryButton {
                    Button(action: secondaryButton.action) {
                        Text(secondaryButton.title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: 320)
        .background(
            ZStack {
                // Blur background
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)

                // Gradient overlay
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Border
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        )
        .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 15)
    }
}

// MARK: - Glass Dialog Container

struct GlassDialogContainer: ViewModifier {
    @ObservedObject var manager = GlassDialogManager.shared

    func body(content: Content) -> some View {
        ZStack {
            content

            if manager.isShowing, let config = manager.currentDialog {
                ZStack {
                    // Dark overlay
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .onTapGesture {
                            // Don't dismiss on background tap for confirmation dialogs
                        }

                    // Dialog
                    GlassDialogView(config: config)
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.9).combined(with: .opacity),
                                removal: .scale(scale: 0.95).combined(with: .opacity)
                            )
                        )
                }
                .zIndex(1000)
            }
        }
    }
}

// MARK: - View Extension

extension View {
    func withGlassDialogs() -> some View {
        modifier(GlassDialogContainer())
    }
}

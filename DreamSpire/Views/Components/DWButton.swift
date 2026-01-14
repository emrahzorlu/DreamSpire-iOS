//
//  DWButton.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//

import SwiftUI

struct DWButton: View {
    let title: String
    let icon: String?
    let style: ButtonStyle
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    init(
        title: String,
        icon: String? = nil,
        style: ButtonStyle = .primary,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            if !isLoading && isEnabled {
                action()
            }
        }) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: style.foregroundColor))
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.headline)
                    }
                    
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(style.foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(style.background)
            .cornerRadius(Constants.UI.buttonCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Constants.UI.buttonCornerRadius)
                    .stroke(style.borderColor, lineWidth: style.borderWidth)
            )
            .dwShadow(radius: style.shadowRadius)
            .opacity(isEnabled ? 1.0 : 0.6)
        }
        .disabled(!isEnabled || isLoading)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if isEnabled && !isLoading {
                        isPressed = true
                    }
                }
                .onEnded { _ in isPressed = false }
        )
    }
    
    enum ButtonStyle {
        case primary
        case secondary
        case outline
        case ghost
        case gradient
        case destructive
        
        var foregroundColor: Color {
            switch self {
            case .primary: return .white
            case .secondary: return .dwTextPrimary
            case .outline: return .white
            case .ghost: return .white
            case .gradient: return .white
            case .destructive: return .white
            }
        }
        
        @ViewBuilder
        var background: some View {
            switch self {
            case .primary:
                Color.dwPurple
            case .secondary:
                Color.white.opacity(0.2)
            case .outline:
                Color.clear
            case .ghost:
                Color.clear
            case .gradient:
                LinearGradient.dwButton
            case .destructive:
                Color.dwError
            }
        }
        
        var borderColor: Color {
            switch self {
            case .outline:
                return .white.opacity(0.3)
            default:
                return .clear
            }
        }
        
        var borderWidth: CGFloat {
            switch self {
            case .outline:
                return 2
            default:
                return 0
            }
        }
        
        var shadowRadius: CGFloat {
            switch self {
            case .primary, .gradient:
                return 15
            case .secondary:
                return 8
            default:
                return 0
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LinearGradient.dwBackground
            .ignoresSafeArea()
        
        VStack(spacing: 20) {
            DWButton(title: "Hikaye Oluştur", icon: "sparkles", style: .primary) {}
            
            DWButton(title: "Yükleniyor...", style: .gradient, isLoading: true) {}
            
            DWButton(title: "Devam Et", style: .gradient) {}
            
            DWButton(title: "İptal", style: .secondary) {}
            
            DWButton(title: "Düzenle", icon: "pencil", style: .outline) {}
            
            DWButton(title: "Devre Dışı", style: .primary, isEnabled: false) {}
            
            DWButton(title: "Sil", icon: "trash", style: .destructive) {}
        }
        .padding()
    }
}

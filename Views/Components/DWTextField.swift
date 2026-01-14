//
//  DWTextField.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//

import SwiftUI

struct DWTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String?
    let isSecure: Bool
    let keyboardType: UIKeyboardType
    let onCommit: (() -> Void)?
    
    @FocusState private var isFocused: Bool
    
    init(
        placeholder: String,
        text: Binding<String>,
        icon: String? = nil,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default,
        onCommit: (() -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
        self.isSecure = isSecure
        self.keyboardType = keyboardType
        self.onCommit = onCommit
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(.dwTextSecondary)
                    .frame(width: 20)
            }
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        isFocused = false
                        onCommit?()
                    }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } else {
                TextField(placeholder, text: $text)
                    .focused($isFocused)
                    .keyboardType(keyboardType)
                    .submitLabel(.done)
                    .onSubmit {
                        isFocused = false
                        onCommit?()
                    }
                    .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .sentences)
                    .autocorrectionDisabled(keyboardType == .emailAddress)
            }
        }
        .foregroundColor(.white)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: Constants.UI.buttonCornerRadius)
                .fill(Color.white.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: Constants.UI.buttonCornerRadius)
                        .stroke(
                            isFocused ? Color.white.opacity(0.4) : Color.white.opacity(0.2),
                            lineWidth: 1.5
                        )
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

struct DWTextEditor: View {
    let placeholder: String
    @Binding var text: String
    let minHeight: CGFloat
    
    @FocusState private var isFocused: Bool
    
    init(
        placeholder: String,
        text: Binding<String>,
        minHeight: CGFloat = 120
    ) {
        self.placeholder = placeholder
        self._text = text
        self.minHeight = minHeight
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(.dwTextSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            
            TextEditor(text: $text)
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .frame(minHeight: minHeight)
        .background(
            RoundedRectangle(cornerRadius: Constants.UI.buttonCornerRadius)
                .fill(Color.white.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: Constants.UI.buttonCornerRadius)
                        .stroke(
                            isFocused ? Color.white.opacity(0.4) : Color.white.opacity(0.2),
                            lineWidth: 1.5
                        )
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LinearGradient.dwBackground
            .ignoresSafeArea()
        
        VStack(spacing: 20) {
            DWTextField(
                placeholder: "E-posta adresiniz",
                text: .constant(""),
                icon: "envelope.fill",
                keyboardType: .emailAddress
            )
            
            DWTextField(
                placeholder: "Şifreniz",
                text: .constant(""),
                icon: "lock.fill",
                isSecure: true
            )
            
            DWTextField(
                placeholder: "Hikaye fikrinizi yazın...",
                text: .constant(""),
                icon: "lightbulb.fill"
            )
            
            DWTextEditor(
                placeholder: "Hikayenizi anlatın... Örneğin: Uzayda yaşayan iki kardeşin yeni bir gezegen keşfetmesi...",
                text: .constant(""),
                minHeight: 150
            )
        }
        .padding()
    }
}

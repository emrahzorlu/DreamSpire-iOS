//
//  PasswordResetView.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//

import SwiftUI

struct PasswordResetView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var email = ""
    @State private var isLoading = false
    @State private var emailSent = false
    @State private var errorMessage: String?
    @State private var emailError: String?
    @FocusState private var isEmailFocused: Bool
    
    // Timer for resend cooldown
    @State private var resendCooldown: Int = 0
    @State private var timer: Timer?
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient.dwBackground
                    .ignoresSafeArea()
                    .onTapGesture {
                        isEmailFocused = false
                    }
                
                ScrollView {
                    VStack(spacing: 32) {
                        headerSection
                        
                        if !emailSent {
                            formSection
                        } else {
                            successSection
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            DWLogger.shared.logViewAppear("PasswordResetView")
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: emailSent ? "checkmark.circle.fill" : "lock.rotation")
                .font(.system(size: 72))
                .foregroundColor(.white)
                .symbolEffect(.bounce, value: emailSent)
            
            Text(emailSent ? "password_reset_sent_title".localized : "password_reset_title".localized)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text(emailSent ? "password_reset_sent_subtitle".localized : "password_reset_subtitle".localized)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .animation(.easeInOut(duration: 0.4), value: emailSent)
    }
    
    // MARK: - Form Section
    
    private var formSection: some View {
        VStack(spacing: 24) {
            emailFieldView
            
            if let errorMessage = errorMessage {
                errorMessageView(errorMessage)
            }
            
            sendButtonView
            backButtonView
        }
    }
    
    // MARK: - Email Field
    
    private var emailFieldView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "envelope")
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 20)
                
                TextField("login_email".localized, text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textContentType(.emailAddress)
                    .foregroundColor(.white)
                    .focused($isEmailFocused)
                    .onChange(of: email) { _, newValue in
                        validateEmailRealtime(newValue)
                    }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                emailError != nil ? Color.red.opacity(0.8) :
                                (isEmailFocused ? Color.white.opacity(0.5) : Color.white.opacity(0.2)),
                                lineWidth: 1
                            )
                    )
            )
            
            if let emailError = emailError, !email.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption2)
                    Text(emailError)
                        .font(.caption)
                }
                .foregroundColor(.red.opacity(0.9))
                .transition(.opacity)
            }
        }
    }
    
    // MARK: - Send Button
    
    private var sendButtonView: some View {
        Button(action: handlePasswordReset) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("password_reset_send_button".localized)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.3))
                        .blur(radius: 20)
                        .offset(y: 8)
                    
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .opacity(isValidEmail ? 1.0 : 0.5)
        }
        .disabled(!isValidEmail || isLoading)
    }
    
    // MARK: - Back Button
    
    private var backButtonView: some View {
        Button(action: { dismiss() }) {
            Text("password_reset_back_to_login".localized)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .underline()
        }
    }
    
    // MARK: - Success Section
    
    private var successSection: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Text("password_reset_check_email".localized)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                
                Text(email)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.15))
                    )
            }
            
            Button(action: { dismiss() }) {
                Text("password_reset_back_to_login".localized)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
            
            Button(action: handlePasswordReset) {
                if resendCooldown > 0 {
                    Text("password_reset_resend_wait".localized(with: formatTime(resendCooldown)))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                } else {
                    Text("password_reset_resend".localized)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .underline()
                }
            }
            .disabled(resendCooldown > 0)
        }
    }
    
    // MARK: - Error Message
    
    private func errorMessageView(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
            Text(message)
                .font(.caption)
        }
        .foregroundColor(.red.opacity(0.9))
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // MARK: - Validation
    
    private var isValidEmail: Bool {
        let validation = ValidationHelper.validateEmail(email)
        return validation.isValid
    }
    
    private func validateEmailRealtime(_ email: String) {
        guard !email.isEmpty else {
            emailError = nil
            return
        }
        
        let validation = ValidationHelper.validateEmail(email)
        withAnimation(.easeInOut(duration: 0.2)) {
            emailError = validation.isValid ? nil : "login_error_invalid_email_format".localized
        }
    }
    
    // MARK: - Password Reset Handler
    
    private func handlePasswordReset() {
        errorMessage = nil
        
        let emailValidation = ValidationHelper.validateEmail(email)
        if !emailValidation.isValid {
            withAnimation {
                errorMessage = emailValidation.errorMessage
            }
            return
        }
        
        isLoading = true
        
        Task {
            do {
                try await authManager.sendPasswordReset(email: email)
                
                await MainActor.run {
                    isLoading = false
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        emailSent = true
                    }
                    startResendCooldown()
                    DWLogger.shared.logUserAction("Password Reset Email Sent")
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    withAnimation {
                        errorMessage = localizedFirebaseError(error)
                    }
                    DWLogger.shared.logError(error, context: "Password Reset", category: .auth)
                }
            }
        }
    }
    
    // MARK: - Error Localization
    
    private func localizedFirebaseError(_ error: Error) -> String {
        let errorCode = (error as NSError).code
        let errorDomain = (error as NSError).domain
        
        if errorDomain == "FIRAuthErrorDomain" {
            switch errorCode {
            case 17008:
                return "login_error_invalid_email".localized
            case 17011:
                return "login_error_user_not_found".localized
            case 17020:
                return "login_error_network".localized
            case 17999:
                return "login_error_too_many_requests".localized
            default:
                return "login_error_unknown".localized
            }
        }
        
        return error.localizedDescription
    }
    
    // MARK: - Timer Functions
    
    private func startResendCooldown() {
        resendCooldown = 180 // 3 minutes = 180 seconds
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if resendCooldown > 0 {
                resendCooldown -= 1
            } else {
                timer?.invalidate()
                timer = nil
            }
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

#Preview {
    PasswordResetView()
        .environmentObject(AuthManager.shared)
}

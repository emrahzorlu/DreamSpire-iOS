//
//  LoginView.swift
//  DreamSpire
//
//  Hybrid Authentication: Guest + Login + Signup with Smooth Animations
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var onAuthenticated: () -> Void
    
    @State private var showingSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingPasswordReset = false
    @State private var showingVerificationAlert = false
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @FocusState private var focusedField: Field?
    @State private var emailError: String?
    @State private var passwordError: String?
    @State private var confirmPasswordError: String?
    
    enum Field: Hashable {
        case email, password, confirmPassword
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient.dwBackground
                    .ignoresSafeArea()
                    .onTapGesture {
                        focusedField = nil
                    }
                
                mainScrollContent
                
                // Loading Overlay - Locks UI during auth
                if isLoading {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .zIndex(99)
                        .allowsHitTesting(true) // Block all interactions
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        
                        Text(showingSignUp ? "login_creating_account".localized : "login_signing_in".localized)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Material.ultraThinMaterial)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(100)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            DWLogger.shared.logViewAppear("LoginView")
        }
        .alert("login_verification_sent".localized, isPresented: $showingVerificationAlert) {
            Button("ok".localized) {
                onAuthenticated()
            }
        } message: {
            Text("login_email_not_verified".localized)
        }
        .sheet(isPresented: $showingPasswordReset) {
            PasswordResetView()
                .environmentObject(authManager)
        }
        .preferredColorScheme(.light)
    }
    
    // MARK: - Main Scroll Content
    
    private var mainScrollContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 32) {
                    headerSection
                    
                    if !showingSignUp {
                        appleSignInSection
                    }
                    
                    dividerSection
                    formSection
                    
                    Spacer()
                }
                .onChange(of: focusedField) { _, newValue in
                    if newValue != nil {
                        withAnimation {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Text("✨")
                .font(.system(size: 72))
                .scaleEffect(showingSignUp ? 0.9 : 1.0)
                .animation(.easeInOut(duration: 0.4), value: showingSignUp)
            
            Text(showingSignUp ? "login_create_account".localized : "login_start_adventure".localized)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .id(showingSignUp)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            
            Text(showingSignUp ? "login_join_world".localized : "login_subtitle".localized)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .id("subtitle-\(showingSignUp)")
                .transition(.opacity)
        }
        .padding(.top, 60)
        .animation(.easeInOut(duration: 0.4), value: showingSignUp)
    }
    
    // MARK: - Apple Sign In Section
    
    private var appleSignInSection: some View {
        VStack(spacing: 16) {
            SignInWithAppleButton(
                onRequest: { request in
                    DWLogger.shared.info("🍎 Apple Sign In button tapped - onRequest called", category: .auth)
                    let nonce = authManager.generateNonce()
                    authManager.currentNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = authManager.hashNonce(nonce)
                    DWLogger.shared.debug("🍎 Nonce generated and set", category: .auth)
                },
                onCompletion: { result in
                    DWLogger.shared.info("🍎 Apple Sign In onCompletion called", category: .auth)
                    handleAppleSignIn(result: result)
                }
            )
            .signInWithAppleButtonStyle(.white)
            .frame(height: 56)
            .cornerRadius(Constants.UI.buttonCornerRadius)
            .environment(\.locale, Locale(identifier: Locale.current.language.languageCode?.identifier ?? "en"))
        }
        .padding(.horizontal, 20)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // MARK: - Divider Section
    
    private var dividerSection: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.white.opacity(0.3))
                .frame(height: 1)
            
            Text("login_or".localized)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
            
            Rectangle()
                .fill(Color.white.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - Form Section
    
    private var formSection: some View {
        VStack(spacing: 16) {
            emailFieldView
            passwordFieldView
            
            if showingSignUp {
                confirmPasswordFieldView
            }
            
            if let errorMessage = errorMessage {
                errorMessageView(errorMessage)
            }
            
            actionButtonView
            toggleModeView
            
            if !showingSignUp {
                forgotPasswordView
                guestModeView
            }
        }
        .padding(.horizontal, 20)
        .animation(.easeInOut(duration: 0.35), value: showingSignUp)
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
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .textContentType(.emailAddress)
                    .foregroundColor(.white)
                    .focused($focusedField, equals: .email)
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
                                (focusedField == .email ? Color.white.opacity(0.5) : Color.white.opacity(0.2)),
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
        .id(Field.email)
        .transition(.move(edge: .leading).combined(with: .opacity))
    }
    
    // MARK: - Password Field
    
    private var passwordFieldView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "lock")
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 20)
                
                Group {
                    if showPassword {
                        TextField("login_password".localized, text: $password)
                            .autocorrectionDisabled(true)
                            .autocapitalization(.none)
                    } else {
                        SecureField("login_password".localized, text: $password)
                            .autocorrectionDisabled(true)
                            .autocapitalization(.none)
                    }
                }
                .textContentType(showingSignUp ? .newPassword : .password)
                .foregroundColor(.white)
                .focused($focusedField, equals: .password)
                .onChange(of: password) { _, newValue in
                    if showingSignUp {
                        validatePasswordRealtime(newValue)
                    }
                }
                
                Button(action: { showPassword.toggle() }) {
                    Image(systemName: showPassword ? "eye.fill" : "eye.slash.fill")
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 20)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                passwordError != nil ? Color.red.opacity(0.8) :
                                (focusedField == .password ? Color.white.opacity(0.5) : Color.white.opacity(0.2)),
                                lineWidth: 1
                            )
                    )
            )
            
            if let passwordError = passwordError, !password.isEmpty, showingSignUp {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption2)
                    Text(passwordError)
                        .font(.caption)
                }
                .foregroundColor(.red.opacity(0.9))
                .transition(.opacity)
            }
        }
        .id(Field.password)
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }
    
    // MARK: - Confirm Password Field
    
    private var confirmPasswordFieldView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 20)
                
                Group {
                    if showConfirmPassword {
                        TextField("login_confirm_password".localized, text: $confirmPassword)
                            .autocorrectionDisabled(true)
                            .autocapitalization(.none)
                    } else {
                        SecureField("login_confirm_password".localized, text: $confirmPassword)
                            .autocorrectionDisabled(true)
                            .autocapitalization(.none)
                    }
                }
                .textContentType(.newPassword)
                .foregroundColor(.white)
                .focused($focusedField, equals: .confirmPassword)
                .onChange(of: confirmPassword) { _, newValue in
                    validateConfirmPasswordRealtime(newValue)
                }
                
                Button(action: { showConfirmPassword.toggle() }) {
                    Image(systemName: showConfirmPassword ? "eye.fill" : "eye.slash.fill")
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 20)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                confirmPasswordError != nil ? Color.red.opacity(0.8) :
                                (focusedField == .confirmPassword ? Color.white.opacity(0.5) : Color.white.opacity(0.2)),
                                lineWidth: 1
                            )
                    )
            )
            
            if let confirmPasswordError = confirmPasswordError, !confirmPassword.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption2)
                    Text(confirmPasswordError)
                        .font(.caption)
                }
                .foregroundColor(.red.opacity(0.9))
                .transition(.opacity)
            }
        }
        .id(Field.confirmPassword)
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
            removal: .move(edge: .bottom).combined(with: .opacity)
        ))
    }
    
    // MARK: - Helper Views
    
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
    
    private var actionButtonView: some View {
        Button(action: handleEmailAuth) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(showingSignUp ? "login_create_account".localized : "login_sign_in".localized)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
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
            .opacity(isValidInput ? 1.0 : 0.5)
        }
        .disabled(!isValidInput || isLoading)
        .animation(.easeInOut(duration: 0.3), value: showingSignUp)
    }
    
    private var toggleModeView: some View {
        Text(showingSignUp ? "login_have_account".localized : "login_no_account".localized)
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.7))
            .underline()
            .onTapGesture {
                showingSignUp.toggle()
                if !showingSignUp {
                    confirmPassword = ""
                }
                errorMessage = nil
            }
    }
    
    private var forgotPasswordView: some View {
        Text("login_forgot".localized)
            .font(.caption)
            .foregroundColor(.white.opacity(0.6))
            .underline()
            .onTapGesture {
                showingPasswordReset = true
            }
    }
    
    private var guestModeView: some View {
        Button(action: {
            handleContinueAsGuest()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle")
                    .font(.subheadline)
                Text("onboarding_continue_guest".localized)
                    .font(.subheadline)
            }
            .foregroundColor(.white.opacity(0.7))
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .padding(.top, 8)
    }
    
    
    // MARK: - Validation
    
    private var isValidInput: Bool {
        let emailValidation = ValidationHelper.validateEmail(email)
        let passwordValidation = showingSignUp ? 
            ValidationHelper.validatePassword(password) : 
            (password.count >= 6 ? ValidationHelper.ValidationResult.success : ValidationHelper.ValidationResult.failure(""))
        
        if showingSignUp {
            let passwordMatch = ValidationHelper.validatePasswordMatch(password, confirmPassword)
            return emailValidation.isValid && passwordValidation.isValid && passwordMatch.isValid
        } else {
            return emailValidation.isValid && passwordValidation.isValid
        }
    }
    
    // MARK: - Real-time Validation
    
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
    
    private func validatePasswordRealtime(_ password: String) {
        guard !password.isEmpty else {
            passwordError = nil
            return
        }
        
        let validation = ValidationHelper.validatePassword(password)
        withAnimation(.easeInOut(duration: 0.2)) {
            passwordError = validation.isValid ? nil : validation.errorMessage
        }
    }
    
    private func validateConfirmPasswordRealtime(_ confirmPassword: String) {
        guard !confirmPassword.isEmpty else {
            confirmPasswordError = nil
            return
        }
        
        let validation = ValidationHelper.validatePasswordMatch(password, confirmPassword)
        withAnimation(.easeInOut(duration: 0.2)) {
            confirmPasswordError = validation.isValid ? nil : "login_error_passwords_mismatch".localized
        }
    }
    
    // MARK: - Error Localization

    private func localizedFirebaseError(_ error: Error) -> String {
        let errorCode = (error as NSError).code
        let errorDomain = (error as NSError).domain

        if errorDomain == "FIRAuthErrorDomain" {
            switch errorCode {
            case 17007, 17004: // Email already in use (signup)
                return "login_error_email_exists".localized
            case 17008: // Invalid email format
                return "login_error_invalid_email".localized
            case 17009: // Wrong password OR invalid credentials (login)
                // More user-friendly: don't reveal if email exists or not (security best practice)
                return "login_error_invalid_credentials".localized
            case 17011: // User not found (login)
                // Use same message as 17009 for security (don't reveal if email exists)
                return "login_error_invalid_credentials".localized
            case 17026: // Weak password (signup)
                return "login_error_weak_password".localized
            case 17020: // Network error
                return "login_error_network".localized
            case 17010: // User disabled
                return "login_error_user_disabled".localized
            case 17999: // Too many requests
                return "login_error_too_many_requests".localized
            case 17995: // Malformed or expired credential
                return "login_error_invalid_credential".localized
            case 17005: // Operation not allowed
                return "login_error_operation_not_allowed".localized
            case 17012: // Requires recent login
                return "login_error_requires_recent_login".localized
            default:
                return "login_error_unknown".localized
            }
        }

        return error.localizedDescription
    }
    
    // MARK: - Apple Sign In Error Localization
    
    private func localizedAppleSignInError(_ error: Error) -> String {
        let nsError = error as NSError
        let errorCode = nsError.code
        let errorDomain = nsError.domain
        
        // ASAuthorizationError domain
        if errorDomain == ASAuthorizationError.errorDomain {
            switch errorCode {
            case ASAuthorizationError.canceled.rawValue:
                // User cancelled - no need to show error
                return ""
            case ASAuthorizationError.failed.rawValue:
                return "login_apple_error_failed".localized
            case ASAuthorizationError.invalidResponse.rawValue:
                return "login_apple_error_invalid_response".localized
            case ASAuthorizationError.notHandled.rawValue:
                return "login_apple_error_not_handled".localized
            case ASAuthorizationError.unknown.rawValue:
                return "login_apple_error_unknown".localized
            case ASAuthorizationError.notInteractive.rawValue:
                return "login_apple_error_not_interactive".localized
            default:
                return "login_apple_error".localized
            }
        }
        
        // Firebase Auth errors
        if errorDomain == "FIRAuthErrorDomain" {
            return localizedFirebaseError(error)
        }
        
        // Generic error
        return "login_apple_error".localized
    }
    
    // MARK: - Email Auth
    
    private func handleEmailAuth() {
        errorMessage = nil
        
        let emailValidation = ValidationHelper.validateEmail(email)
        if !emailValidation.isValid {
            withAnimation {
                errorMessage = emailValidation.errorMessage
            }
            return
        }
        
        if showingSignUp {
            let passwordValidation = ValidationHelper.validatePassword(password)
            if !passwordValidation.isValid {
                withAnimation {
                    errorMessage = passwordValidation.errorMessage
                }
                return
            }
            
            let passwordMatch = ValidationHelper.validatePasswordMatch(password, confirmPassword)
            if !passwordMatch.isValid {
                withAnimation {
                    errorMessage = passwordMatch.errorMessage
                }
                return
            }
        }
        
        isLoading = true
        
        Task {
            do {
                if showingSignUp {
                    try await authManager.signUp(
                        email: email,
                        password: password,
                        name: email.components(separatedBy: "@").first ?? "User"
                    )
                    DWLogger.shared.logAnalyticsEvent("user_signed_up", parameters: ["method": "email"])
                    
                    await MainActor.run {
                        isLoading = false
                        // Direct access, skip email verification alert
                        onAuthenticated()
                    }
                } else {
                    try await authManager.signIn(email: email, password: password)
                    DWLogger.shared.logAnalyticsEvent("user_signed_in", parameters: ["method": "email"])
                    
                    await MainActor.run {
                        isLoading = false
                        onAuthenticated()
                    }
                }
                
            } catch {
                await MainActor.run {
                    isLoading = false
                    withAnimation {
                        errorMessage = localizedFirebaseError(error)
                    }
                    DWLogger.shared.logError(
                        error,
                        context: showingSignUp ? "Sign Up" : "Sign In",
                        category: .auth
                    )
                }
            }
        }
    }
    
    // MARK: - Guest Mode

    private func handleContinueAsGuest() {
        DWLogger.shared.logUserAction("Continue as Guest from Login")
        isLoading = true

        Task {
            do {
                try await authManager.continueAsGuest()
                await MainActor.run {
                    isLoading = false
                    onAuthenticated()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    withAnimation {
                        errorMessage = String(format: "login_error_guest_continue".localized, error.localizedDescription)
                    }
                    DWLogger.shared.logError(error, context: "Continue as Guest", category: .auth)
                }
            }
        }
    }

    // MARK: - Apple Sign In

    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        DWLogger.shared.info("🍎 handleAppleSignIn called with result", category: .auth)

        switch result {
        case .success(let authorization):
            DWLogger.shared.info("🍎 Authorization successful", category: .auth)

            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                DWLogger.shared.error("🍎 Apple Authorization failed: credential not found.", category: .auth)
                errorMessage = "login_apple_error".localized
                return
            }

            DWLogger.shared.info("🍎 Apple ID credential obtained, user: \(appleIDCredential.user)", category: .auth)

            // Lock UI during Apple Sign In
            isLoading = true

            Task {
                do {
                    DWLogger.shared.info("🍎 Calling authManager.signInWithApple...", category: .auth)
                    try await authManager.signInWithApple(credentials: appleIDCredential)
                    DWLogger.shared.info("🍎 signInWithApple completed successfully", category: .auth)
                    DWLogger.shared.logAnalyticsEvent("user_signed_in", parameters: ["method": "apple"])

                    await MainActor.run {
                        isLoading = false
                        onAuthenticated()
                    }
                } catch {
                    DWLogger.shared.error("🍎 signInWithApple failed", error: error, category: .auth)
                    await MainActor.run {
                        isLoading = false
                        let localizedError = localizedAppleSignInError(error)
                        if !localizedError.isEmpty {
                            withAnimation {
                                errorMessage = localizedError
                            }
                        }
                        DWLogger.shared.logError(error, context: "Apple Sign In", category: .auth)
                    }
                }
            }

        case .failure(let error):
            DWLogger.shared.error("🍎 Apple Sign In authorization failed", error: error, category: .auth)
            let localizedError = localizedAppleSignInError(error)
            // Don't show error if user cancelled
            if !localizedError.isEmpty {
                withAnimation {
                    errorMessage = localizedError
                }
            }
        }
    }
}

#Preview {
    LoginView(onAuthenticated: { print("Authenticated!") })
        .environmentObject(AuthManager.shared)
}

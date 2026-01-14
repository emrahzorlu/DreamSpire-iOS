//
//  SplashView.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//

import SwiftUI
import Network

struct SplashView: View {
    @State private var iconOpacity: Double = 0
    @State private var iconScale: CGFloat = 0.6
    @State private var iconRotation: Double = -10
    @State private var textOpacity: Double = 0
    @State private var textScale: CGFloat = 0.9
    @State private var taglineOpacity: Double = 0
    @State private var taglineBlur: CGFloat = 10
    @State private var taglineShimmerOffset: CGFloat = -300
    @State private var glowOpacity: Double = 0
    @State private var glowScale: CGFloat = 0.7
    @State private var pulseScale: CGFloat = 1.0
    @State private var particleOpacity: Double = 0
    @State private var shimmerOffset: CGFloat = -500
    @State private var exitOpacity: Double = 1
    @State private var showNoInternetOverlay = false
    @State private var showFinalAlert = false
    @State private var hasNetworkConnection = false
    @State private var retryCount = 0
    private let maxRetries = 5

    var onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient.dwBackground
                .ignoresSafeArea()
            
            // Animated background particles
            SplashParticleEmitterView()
                .opacity(particleOpacity)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Logo and title section
                VStack(spacing: 40) {
                    // Icon with glow effect
                    ZStack {
                        // Animated glow rings
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.dwAccent.opacity(0.3),
                                            Color.dwSecondary.opacity(0.2),
                                            Color.clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                                .frame(width: 220 + CGFloat(index * 30), height: 220 + CGFloat(index * 30))
                                .scaleEffect(glowScale)
                                .opacity(glowOpacity * (1.0 - Double(index) * 0.2))
                                .blur(radius: 5)
                        }

                        // Primary glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        Color.dwAccent.opacity(0.4),
                                        Color.dwSecondary.opacity(0.2),
                                        Color.clear
                                    ]),
                                    center: .center,
                                    startRadius: 50,
                                    endRadius: 140
                                )
                            )
                            .frame(width: 280, height: 280)
                            .scaleEffect(pulseScale)
                            .opacity(glowOpacity)
                            .blur(radius: 25)

                        // Icon container with rounded background
                        ZStack {
                            // Soft background circle
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.15),
                                            Color.white.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 200, height: 200)
                                .shadow(color: Color.dwAccent.opacity(0.3), radius: 30, x: 0, y: 15)

                            // Main icon with rounded corners
                            Image("DreamSpireIcon")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 240, height: 240)
                                .clipShape(RoundedRectangle(cornerRadius: 50))
                                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 50)
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.3),
                                                    Color.white.opacity(0.1)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                                .overlay(
                                    // Shimmer effect
                                    RoundedRectangle(cornerRadius: 50)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.clear,
                                                    Color.white.opacity(0.4),
                                                    Color.white.opacity(0.6),
                                                    Color.white.opacity(0.4),
                                                    Color.clear
                                                ]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: 120)
                                        .offset(x: shimmerOffset)
                                        .blur(radius: 8)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 50))
                        }
                        .scaleEffect(iconScale)
                        .rotationEffect(.degrees(iconRotation))
                        .opacity(iconOpacity)
                    }
                    
                    // App name with shimmer animation
                    VStack(spacing: 16) {
                        Text("DreamSpire")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: Color.dwAccent.opacity(0.6), radius: 20, x: 0, y: 10)
                            .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
                            .overlay(
                                GeometryReader { geometry in
                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.clear,
                                                    Color.dwAccent.opacity(0.7),
                                                    Color.dwSecondary.opacity(0.7),
                                                    Color.purple.opacity(0.5),
                                                    Color.clear
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geometry.size.width * 2)
                                        .offset(x: shimmerOffset)
                                        .blendMode(.overlay)
                                }
                            )
                            .mask(
                                Text("DreamSpire")
                                    .font(.system(size: 52, weight: .bold, design: .rounded))
                            )
                        .scaleEffect(textScale)
                        .opacity(textOpacity)

                        // Tagline with shimmer animation
                        Text("splash_tagline".localized)
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .tracking(2.2)
                            .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 2)
                            .overlay(
                                GeometryReader { geometry in
                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.clear,
                                                    Color.white.opacity(0.6),
                                                    Color.dwAccent.opacity(0.4),
                                                    Color.clear
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geometry.size.width * 2)
                                        .offset(x: shimmerOffset)
                                        .blendMode(.overlay)
                                }
                            )
                            .mask(
                                Text("splash_tagline".localized)
                                    .font(.system(size: 17, weight: .medium, design: .rounded))
                                    .tracking(2.2)
                            )
                            .opacity(taglineOpacity)
                            .blur(radius: taglineBlur)
                    }
                }
                
                Spacer()
                
                // Version
                Text("v\(Constants.App.version)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .opacity(textOpacity)
                    .padding(.bottom, 60)
            }

            // No Internet Overlay
            if showNoInternetOverlay {
                ZStack {
                    // More opaque background for visibility
                    Color.black.opacity(0.85)
                        .ignoresSafeArea()

                    VStack(spacing: 28) {
                        // Wifi icon with slash
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.2))
                                .frame(width: 80, height: 80)

                            Image(systemName: "wifi.slash")
                                .font(.system(size: 40))
                                .foregroundColor(.red.opacity(0.9))
                        }

                        VStack(spacing: 12) {
                            Text("waiting_for_internet".localized)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)

                            Text("retry_attempt".localized + " \(retryCount)/\(maxRetries)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }

                        // Loading indicator
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    }
                    .padding(50)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.2, green: 0.2, blue: 0.3).opacity(0.95),
                                        Color(red: 0.15, green: 0.15, blue: 0.25).opacity(0.95)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color.black.opacity(0.5), radius: 30, x: 0, y: 10)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .transition(.opacity)
            }
        }
        .opacity(exitOpacity)
        .alert("no_internet_title".localized, isPresented: $showFinalAlert) {
            Button("retry".localized) {
                retryCount = 0
                showNoInternetOverlay = false
                checkNetworkAndProceed()
            }
            Button("exit_app".localized, role: .destructive) {
                exit(0)
            }
        } message: {
            Text("no_internet_final_message".localized)
        }
        .onAppear {
            startAnimation()
            DWLogger.shared.info("Splash screen appeared", category: .ui)

            // Check network connection before proceeding
            checkNetworkAndProceed()
        }
    }

    private func proceedToApp() {
        DWLogger.shared.info("📱 Proceeding to app", category: .ui)
        withAnimation(.easeOut(duration: 0.35)) {
            exitOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onComplete()
        }
    }

    private func checkNetworkAndProceed() {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkCheck")

        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    DWLogger.shared.info("✅ Network available, proceeding with app load", category: .ui)

                    hasNetworkConnection = true
                    showNoInternetOverlay = false

                    // Network available, preload data
                    Task {
                        await AppPreloadService.shared.preloadAllData()
                        DWLogger.shared.info("🚀 App data preloaded during splash", category: .general)
                    }

                    monitor.cancel()
                } else {
                    DWLogger.shared.warning("❌ No network connection detected (attempt \(retryCount + 1)/\(maxRetries))", category: .ui)
                    hasNetworkConnection = false
                    monitor.cancel()

                    // Show overlay and retry
                    withAnimation {
                        showNoInternetOverlay = true
                    }

                    // Auto-retry with delay
                    retryCount += 1
                    if retryCount < maxRetries {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            DWLogger.shared.info("🔄 Auto-retrying network check...", category: .ui)
                            checkNetworkAndProceed()
                        }
                    } else {
                        DWLogger.shared.error("❌ Max retries reached, showing final alert", category: .ui)
                        // Hide overlay and show alert
                        withAnimation {
                            showNoInternetOverlay = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showFinalAlert = true
                        }
                    }
                }
            }
        }

        monitor.start(queue: queue)
    }
    
    private func startAnimation() {
        // Phase 1: Icon entrance with rotation and spring
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6, blendDuration: 0)) {
            iconOpacity = 1
            iconScale = 1.0
        }

        // Subtle rotation effect
        withAnimation(.easeOut(duration: 0.7)) {
            iconRotation = 0
        }

        // Phase 2: Glow effects expand smoothly
        withAnimation(.easeOut(duration: 1.0).delay(0.15)) {
            glowOpacity = 1
            glowScale = 1.0
        }

        // Phase 3: Particles fade in gently
        withAnimation(.easeIn(duration: 0.9).delay(0.25)) {
            particleOpacity = 0.5
        }

        // Phase 4: Title appears with scale and fade
        withAnimation(.spring(response: 0.7, dampingFraction: 0.65).delay(0.35)) {
            textOpacity = 1
            textScale = 1.0
        }

        // Phase 5: Tagline fades in with blur reduction
        withAnimation(.easeOut(duration: 0.8).delay(0.5)) {
            taglineOpacity = 1
            taglineBlur = 0
        }

        // Phase 6: Synchronized shimmer across all elements (icon + text + tagline)
        withAnimation(.easeInOut(duration: 2.2).delay(0.9)) {
            shimmerOffset = 500
        }

        // Phase 7: Continuous gentle pulse
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(0.7)) {
            pulseScale = 1.12
        }

        // Phase 8: Quick fade out - no scale (only if network is available)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            // Only proceed if network connection was successful
            guard hasNetworkConnection else {
                DWLogger.shared.info("⏸️ Splash paused - waiting for network connection", category: .ui)
                return
            }

            DWLogger.shared.info("Splash screen completing", category: .ui)
            proceedToApp()
        }
    }
}

// MARK: - Particle Emitter View

struct SplashParticleEmitterView: View {
    let particleCount = 30
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<particleCount, id: \.self) { index in
                    SplashParticleView(
                        size: geometry.size,
                        index: index
                    )
                }
            }
        }
    }
}

struct SplashParticleView: View {
    let size: CGSize
    let index: Int
    
    @State private var opacity: Double = 0
    @State private var position: CGPoint = .zero
    @State private var particleSize: CGFloat = 4
    
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.8),
                        Color.dwAccent.opacity(0.4),
                        Color.clear
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: particleSize
                )
            )
            .frame(width: particleSize * 2, height: particleSize * 2)
            .position(position)
            .opacity(opacity)
            .blur(radius: 1)
            .onAppear {
                setupParticle()
                animateParticle()
            }
    }
    
    private func setupParticle() {
        let randomX = CGFloat.random(in: 0...size.width)
        let randomY = CGFloat.random(in: size.height * 0.3...size.height * 0.7)
        position = CGPoint(x: randomX, y: randomY)
        particleSize = CGFloat.random(in: 2...6)
    }
    
    private func animateParticle() {
        let delay = Double.random(in: 0...2)
        let duration = Double.random(in: 2...4)
        
        withAnimation(.easeInOut(duration: 0.8).delay(delay)) {
            opacity = Double.random(in: 0.3...0.7)
        }
        
        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true).delay(delay)) {
            position = CGPoint(
                x: position.x + CGFloat.random(in: -30...30),
                y: position.y + CGFloat.random(in: -50...(-20))
            )
        }
        
        withAnimation(.easeInOut(duration: duration * 0.7).repeatForever(autoreverses: true).delay(delay + 0.5)) {
            opacity = Double.random(in: 0.1...0.5)
        }
    }
}

// MARK: - Preview

#Preview {
    SplashView {
        print("Splash completed")
    }
}

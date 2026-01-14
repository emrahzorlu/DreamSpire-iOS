//
//  OwlGeneratingView.swift
//  DreamSpire
//

import SwiftUI

struct OwlGeneratingView: View {
    @Binding var progress: Double
    @Binding var stage: String
    @Binding var storySnippet: String
    let onDismiss: () -> Void
    let onRequestNotification: () -> Void
    
    @State private var owlBreathing: Bool = false
    @State private var moonGlow: CGFloat = 0.7
    @State private var cloudOffset1: CGFloat = -150
    @State private var cloudOffset2: CGFloat = -250
    @State private var starScales: [CGFloat] = Array(repeating: 1.0, count: 8)
    @State private var progressGlow: CGFloat = 0
    @State private var currentOwlState: Int = 0
    @State private var owlTimer: Timer?
    @State private var currentMessageIndex: Int = 0
    @State private var messageTimer: Timer?
    
    // Magic particles
    @State private var particleOffsets: [CGFloat] = Array(repeating: 0, count: 8)
    @State private var particleOpacities: [Double] = Array(repeating: 0.8, count: 8)
    
    // Colorful rings
    @State private var ringScales: [CGFloat] = [1.0, 1.0, 1.0]

    var body: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()
            decorativeElements
            VStack(spacing: 0) {
                topBar.padding(.top, 16)
                Spacer()
                centralProgressView.padding(.top, 10)
                motivationalMessageView.padding(.top, 20).padding(.bottom, 8)
                estimatedTimeView.padding(.bottom, 20)
                Spacer()
                notificationPromptView.padding(.bottom, 50)
            }
        }
        .onAppear {
            startAnimations()
            startOwlCycleTimer()
            startMessageCycleTimer()
            startParticleAnimations()
        }
        .onDisappear {
            owlTimer?.invalidate()
            messageTimer?.invalidate()
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(colors: [Color(red: 0.12, green: 0.08, blue: 0.25), Color(red: 0.18, green: 0.12, blue: 0.35), Color(red: 0.25, green: 0.15, blue: 0.45), Color(red: 0.20, green: 0.12, blue: 0.38)], startPoint: .top, endPoint: .bottom)
    }

    private var topBar: some View {
        HStack {
            Image("moon_glow").resizable().scaledToFit().frame(width: 90, height: 90).opacity(moonGlow).shadow(color: .yellow.opacity(0.5), radius: 20)
            Spacer()
            Button(action: onDismiss) { Image(systemName: "xmark.circle.fill").font(.system(size: 30)).foregroundStyle(.white.opacity(0.6)) }
        }.padding(.horizontal, 24)
    }

    private var centralProgressView: some View {
        ZStack {
            // Colorful expanding rings
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.purple.opacity(0.4),
                                Color.blue.opacity(0.3),
                                Color.pink.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 200 + CGFloat(index) * 60, height: 200 + CGFloat(index) * 60)
                    .scaleEffect(ringScales[index])
                    .opacity(0.6 - Double(index) * 0.15)
            }
            
            // Magic dust particles falling
            ForEach(0..<8, id: \.self) { index in
                let angle = Double(index) * (360.0 / 8.0) * .pi / 180.0
                let radius: CGFloat = 140
                let particleColor = [
                    Color.yellow.opacity(0.8),
                    Color.purple.opacity(0.6),
                    Color.blue.opacity(0.7)
                ][index % 3]
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [particleColor, particleColor.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 8, height: 8)
                    .blur(radius: 2)
                    .offset(
                        x: cos(angle) * radius,
                        y: sin(angle) * radius + particleOffsets[index]
                    )
                    .opacity(particleOpacities[index])
            }
            
            // Subtle glow circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.05),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
                .scaleEffect(progressGlow)

            // Owl image - EVEN BIGGER SIZE
            currentOwlImage
                .resizable()
                .scaledToFit()
                .frame(width: 320, height: 320)
                .scaleEffect(owlBreathing ? 1.03 : 1.0)
                .shadow(color: .white.opacity(0.15), radius: 30)
                .animation(.easeInOut(duration: 0.5), value: currentOwlState)
        }
    }

    private var motivationalMessageView: some View {
        Text(motivationalMessages[currentMessageIndex]).font(.system(size: 18, weight: .medium)).foregroundColor(.white.opacity(0.9)).multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.horizontal, 40).transition(.opacity.combined(with: .scale(scale: 0.95))).animation(.easeInOut(duration: 0.4), value: currentMessageIndex).id(currentMessageIndex)
    }
    
    private var motivationalMessages: [String] {
        ["generating_imagination_working".localized, "generating_colors_alive".localized, "generating_words_dancing".localized, "generating_magic_happening".localized, "generating_owl_working".localized, "generating_adventure_shaping".localized, "generating_characters_alive".localized, "generating_worlds_creating".localized]
    }

    private var estimatedTimeView: some View {
        Text(String(format: "estimated_time".localized, 3)).font(.system(size: 14, weight: .medium)).foregroundColor(.white.opacity(0.6)).multilineTextAlignment(.center)
    }

    private var notificationPromptView: some View {
        VStack(spacing: 16) {
            Button(action: onRequestNotification) {
                HStack(spacing: 10) {
                    Image(systemName: "bell.fill").font(.system(size: 16))
                    Text("notification_enable_and_continue".localized).font(.system(size: 16, weight: .semibold))
                }.foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16).background(Capsule().fill(Color.white.opacity(0.2)).overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1.5)))
            }
            Button(action: onDismiss) { Text("continue_in_background".localized).font(.system(size: 15, weight: .medium)).foregroundColor(.white.opacity(0.7)) }
        }.padding(.horizontal, 32)
    }

    private var decorativeElements: some View {
        GeometryReader { geo in
            ZStack {
                Image("cloud_soft").resizable().scaledToFit().frame(width: 120).opacity(0.4).offset(x: cloudOffset1, y: 100)
                Image("cloud_soft").resizable().scaledToFit().frame(width: 100).opacity(0.35).offset(x: cloudOffset2, y: 180)
                ForEach(0..<8, id: \.self) { index in starView(index: index, in: geo.size) }
                Image("star_big").resizable().scaledToFit().frame(width: 50).opacity(0.9).shadow(color: .yellow.opacity(0.6), radius: 10).position(x: geo.size.width * 0.85, y: geo.size.height * 0.25)
            }
        }.allowsHitTesting(false)
    }

    private func starView(index: Int, in size: CGSize) -> some View {
        let positions: [(CGFloat, CGFloat)] = [(0.08, 0.18), (0.92, 0.12), (0.12, 0.45), (0.88, 0.42), (0.15, 0.68), (0.85, 0.72), (0.25, 0.85), (0.75, 0.88)]
        let pos = index < positions.count ? positions[index] : (0.5, 0.5)
        let starSize: CGFloat = index % 2 == 0 ? 24 : 18
        return Image("star").resizable().scaledToFit().frame(width: starSize * starScales[min(index, starScales.count - 1)]).opacity(0.8).shadow(color: .yellow.opacity(0.5), radius: 4).position(x: size.width * pos.0, y: size.height * pos.1)
    }

    private var currentOwlImage: Image {
        let owlStates = ["owl_generating", "owl_eyes_closed", "owl_eyes_open", "owl_wink", "owl_excited", "owl_ok"]
        return Image(owlStates[currentOwlState % owlStates.count])
    }

    private func startOwlCycleTimer() {
        owlTimer?.invalidate()
        owlTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in withAnimation(.easeInOut(duration: 0.5)) { currentOwlState = (currentOwlState + 1) % 6 } }
    }

    private func startMessageCycleTimer() {
        messageTimer?.invalidate()
        messageTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in withAnimation(.easeInOut(duration: 0.4)) { currentMessageIndex = (currentMessageIndex + 1) % motivationalMessages.count } }
    }

    private func startParticleAnimations() {
        // Animate colorful rings expanding
        for i in 0..<3 {
            let delay = Double(i) * 0.4
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: 2.0 + Double(i) * 0.5).repeatForever(autoreverses: true)) {
                    ringScales[i] = 1.2
                }
            }
        }
        
        // Animate magic dust particles
        for i in 0..<8 {
            let delay = Double(i) * 0.3
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    particleOffsets[i] = 40
                }
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    particleOpacities[i] = particleOpacities[i] > 0.5 ? 0.2 : 0.9
                }
            }
        }
    }

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) { owlBreathing = true }
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) { moonGlow = 1.0 }
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { progressGlow = 1.0 }
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) { cloudOffset1 = UIScreen.main.bounds.width + 150 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) { cloudOffset2 = UIScreen.main.bounds.width + 150 } }
        for i in 0..<8 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.3) {
                withAnimation(.easeInOut(duration: 1.0 + Double(i) * 0.15).repeatForever(autoreverses: true)) { starScales[i] = 1.4 }
            }
        }
    }
}

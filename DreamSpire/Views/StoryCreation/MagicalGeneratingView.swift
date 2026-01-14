//
//  MagicalGeneratingView.swift
//  DreamSpire
//
//  Modern animated generating screen with particles and magic book
//

import SwiftUI

struct MagicalGeneratingView: View {
    @Binding var progress: Double
    @Binding var stage: String
    @Binding var storySnippet: String

    let onDismiss: () -> Void
    let onRequestNotification: () -> Void

    @StateObject private var particleSystem = ParticleSystem()
    @State private var showMilestoneCelebration = false
    @State private var lastMilestone: Double = 0

    var body: some View {
        ZStack {
            // Animated gradient background
            AnimatedGradientBackground()
                .ignoresSafeArea()

            // Particle effects
            GeometryReader { geometry in
                ParticleEmitterView(system: particleSystem)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Spacer()

                // Main content
                VStack(spacing: 40) {
                    // Magic Book Animation
                    MagicBookView(progress: progress)
                        .frame(height: 250)

                    // Dynamic Messages
                    VStack(spacing: 16) {
                        Text(currentMessage)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .transition(.opacity.combined(with: .scale))
                            .id("message-\(currentMessage)")

                        // Story snippet with typewriter effect
                        if !storySnippet.isEmpty {
                            TypewriterText(fullText: storySnippet)
                                .padding(.horizontal, 20)
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: currentMessage)

                    // Enhanced Progress Bar
                    VStack(spacing: 12) {
                        ShimmerProgressBar(progress: progress)
                            .frame(width: 280, height: 14)

                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .monospacedDigit()
                    }
                }

                Spacer()

                // Notification prompt
                notificationPrompt
                    .padding(.bottom, 40)
            }

            // Milestone celebration overlay
            if showMilestoneCelebration {
                MilestoneCelebration(show: $showMilestoneCelebration)
            }
        }
        .onChange(of: progress) { oldValue, newValue in
            checkMilestone(newValue)
        }
    }

    // MARK: - Current Message

    private var currentMessage: String {
        if !stage.isEmpty {
            return stage
        }

        switch progress {
        case 0..<0.25:
            return "generating_characters_animating".localized
        case 0.25..<0.5:
            return "generating_adventure_forming".localized
        case 0.5..<0.75:
            return "generating_magic_touches".localized
        case 0.75..<0.9:
            return "generating_images_creating".localized
        default:
            return "generating_final_touches".localized
        }
    }

    // MARK: - Notification Prompt

    private var notificationPrompt: some View {
        VStack(spacing: 12) {
            Text("generating_dont_wait".localized)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            Button(action: onRequestNotification) {
                HStack(spacing: 8) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 14))
                    Text("generating_get_notification".localized)
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color.orange, Color.pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: .orange.opacity(0.3), radius: 8, y: 4)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Milestone Check

    private func checkMilestone(_ value: Double) {
        let milestones = [0.25, 0.5, 0.75, 1.0]

        for milestone in milestones {
            if value >= milestone && lastMilestone < milestone {
                lastMilestone = milestone
                showMilestoneCelebration = true

                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                break
            }
        }
    }
}

// MARK: - Animated Gradient Background

struct AnimatedGradientBackground: View {
    @State private var animateGradient = false

    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.2, green: 0.1, blue: 0.4),
                Color(red: 0.4, green: 0.2, blue: 0.6),
                Color(red: 0.2, green: 0.1, blue: 0.5)
            ],
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}

// MARK: - Magic Book View

struct MagicBookView: View {
    let progress: Double
    @State private var rotation: Double = 0
    @State private var sparklePhase: Double = 0

    var body: some View {
        ZStack {
            // Glow effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.purple.opacity(0.4),
                            Color.blue.opacity(0.2),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
                .scaleEffect(1.0 + sin(sparklePhase) * 0.1)
                .blur(radius: 20)

            // Book emoji
            Text("📖")
                .font(.system(size: 120))
                .rotationEffect(.degrees(sin(rotation) * 10))
                .scaleEffect(1.0 + progress * 0.2)

            // Orbiting sparkles
            ForEach(0..<8) { index in
                Image(systemName: "sparkle")
                    .font(.system(size: 16))
                    .foregroundColor(.yellow)
                    .offset(
                        x: cos(rotation + Double(index) * .pi / 4) * 80,
                        y: sin(rotation + Double(index) * .pi / 4) * 80
                    )
                    .opacity(0.5 + sin(sparklePhase + Double(index)) * 0.5)
                    .scaleEffect(0.8 + sin(sparklePhase + Double(index)) * 0.4)
            }

            // Flying pages
            ForEach(0..<3) { index in
                Text("📄")
                    .font(.system(size: 30))
                    .offset(
                        x: cos(rotation * 2 + Double(index)) * 100,
                        y: -50 - sin(rotation + Double(index)) * 50
                    )
                    .opacity(0.3 + sin(rotation + Double(index)) * 0.3)
                    .rotationEffect(.degrees(rotation * 20 + Double(index * 120)))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                rotation = .pi * 2
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                sparklePhase = .pi * 2
            }
        }
    }
}

// MARK: - Shimmer Progress Bar

struct ShimmerProgressBar: View {
    let progress: Double
    @State private var shimmerOffset: CGFloat = -200
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 14)

                // Progress fill
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress, height: 14)
                    .overlay(
                        // Shimmer
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0),
                                        Color.white.opacity(0.8),
                                        Color.white.opacity(0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 100)
                            .offset(x: shimmerOffset)
                    )
                    .clipShape(Capsule())
                    .animation(.easeOut(duration: 0.5), value: progress)

                // Milestone stars
                ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { milestone in
                    let xPos = geometry.size.width * milestone - 8

                    if progress >= milestone {
                        Image(systemName: "star.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.yellow)
                            .position(x: xPos, y: 7)
                            .scaleEffect(pulseScale)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerOffset = 400
            }
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.2
            }
        }
    }

    private var gradientColors: [Color] {
        switch progress {
        case 0..<0.33:
            return [Color.blue, Color.cyan]
        case 0.33..<0.66:
            return [Color.purple, Color.pink]
        case 0.66..<1.0:
            return [Color.pink, Color.orange]
        default:
            return [Color.green, Color.yellow]
        }
    }
}

// MARK: - Typewriter Text

struct TypewriterText: View {
    let fullText: String
    let speed: Double = 0.05

    @State private var displayedText = ""
    @State private var currentIndex = 0

    var body: some View {
        Text(displayedText)
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.white.opacity(0.9))
            .multilineTextAlignment(.center)
            .frame(maxWidth: 300)
            .onAppear {
                animateText()
            }
            .onChange(of: fullText) { _, newText in
                displayedText = ""
                currentIndex = 0
                animateText()
            }
    }

    private func animateText() {
        guard currentIndex < fullText.count else { return }

        let index = fullText.index(fullText.startIndex, offsetBy: currentIndex)
        displayedText.append(fullText[index])
        currentIndex += 1

        DispatchQueue.main.asyncAfter(deadline: .now() + speed) {
            animateText()
        }
    }
}

// MARK: - Milestone Celebration

struct MilestoneCelebration: View {
    @Binding var show: Bool

    var body: some View {
        ZStack {
            // Confetti
            ForEach(0..<30) { index in
                MagicalConfettiPiece(index: index, show: show)
            }

            // Checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
                .scaleEffect(show ? 1.0 : 0.1)
                .opacity(show ? 1.0 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: show)
        }
        .onChange(of: show) { _, isShowing in
            if isShowing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    show = false
                }
            }
        }
    }
}

struct MagicalConfettiPiece: View {
    let index: Int
    let show: Bool

    @State private var position: CGPoint = CGPoint(x: 200, y: 200)
    @State private var opacity: Double = 1.0

    private let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .pink]

    var body: some View {
        Circle()
            .fill(colors[index % colors.count])
            .frame(width: 8, height: 8)
            .position(position)
            .opacity(opacity)
            .onAppear {
                if show {
                    withAnimation(.easeOut(duration: 1.5)) {
                        position = CGPoint(
                            x: CGFloat.random(in: 0...400),
                            y: CGFloat.random(in: 200...600)
                        )
                        opacity = 0
                    }
                }
            }
    }
}

// MARK: - Particle System

class ParticleSystem: ObservableObject {
    @Published var particles: [Particle] = []
    private var timer: Timer?

    struct Particle: Identifiable {
        let id = UUID()
        var position: CGPoint
        var velocity: CGPoint
        var opacity: Double = 1.0
        var color: Color
        var lifetime: Double = 0
    }

    func start(in size: CGSize) {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.emitParticle(in: size)
            self?.updateParticles()
        }
    }

    private func emitParticle(in size: CGSize) {
        let colors: [Color] = [.yellow, .orange, .pink, .purple, .blue]
        let particle = Particle(
            position: CGPoint(x: size.width / 2, y: size.height * 0.5),
            velocity: CGPoint(
                x: Double.random(in: -50...50),
                y: Double.random(in: -100...(-50))
            ),
            color: colors.randomElement()!
        )
        particles.append(particle)
    }

    private func updateParticles() {
        particles = particles.compactMap { particle in
            var updated = particle
            updated.position.x += particle.velocity.x * 0.1
            updated.position.y += particle.velocity.y * 0.1
            updated.opacity -= 0.02
            updated.lifetime += 0.1

            return updated.opacity > 0 ? updated : nil
        }
    }

    func stop() {
        timer?.invalidate()
        particles.removeAll()
    }
}

struct ParticleEmitterView: View {
    @ObservedObject var system: ParticleSystem

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(system.particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: 8, height: 8)
                        .position(particle.position)
                        .opacity(particle.opacity)
                        .blur(radius: 2)
                }
            }
            .onAppear {
                system.start(in: geometry.size)
            }
            .onDisappear {
                system.stop()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var progress: Double = 0.5
        @State private var stage: String = "Hikaye oluşturuluyor..."
        @State private var snippet: String = "Bir zamanlar küçük bir prenses vardı..."

        var body: some View {
            MagicalGeneratingView(
                progress: $progress,
                stage: $stage,
                storySnippet: $snippet,
                onDismiss: {},
                onRequestNotification: {}
            )
        }
    }

    return PreviewWrapper()
}

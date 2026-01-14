//
//  StoryResultView.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025-11-02
//

import SwiftUI
import SDWebImageSwiftUI

struct StoryResultView: View {
    let story: Story
    let onDismiss: (() -> Void)?
    @Environment(\.dismiss) var dismiss
    
    init(story: Story, onDismiss: (() -> Void)? = nil) {
        self.story = story
        self.onDismiss = onDismiss
    }
    
    @State private var showingStoryReader = false
    @State private var showingShareSheet = false
    @State private var showingSaveCharacterAlert = false
    @State private var animationPhase = 0
    @State private var isGeneratingPDF = false
    @State private var itemsToShare: [Any] = []
    @State private var showPDFShare = false
    @State private var showPaywallForPDF = false
    @State private var shareProgress: String = ""  // For showing progress to user
    @State private var showConfetti = false

    @ObservedObject private var subscriptionService = SubscriptionService.shared
    
    var body: some View {
        ZStack {
            LinearGradient.dwBackground
                .ignoresSafeArea()
            
            // Magical backgrounds
            MagicalBackgroundView()
            
            // Celebration confetti
            ConfettiEffect(show: $showConfetti)
            
            VStack(spacing: 0) {
                // Main content - ScrollView now ignores safe area to use full height
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Compact Success Animation
                        compactSuccessView
                            .padding(.top, 0) // Remove top padding entirely, will use negative offset inside if needed

                        // Compact Story Info
                        compactStoryCard
                            .padding(.top, 5) // Give some air so text isn't covered

                        // Action Buttons (pulled up)
                        actionButtonsView
                            .padding(.top, 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .ignoresSafeArea(edges: .top)
            }
            
            // Header with close button - Fixed overlay
            VStack {
                HStack {
                    Spacer()

                    Button(action: {
                        if let onDismiss = onDismiss {
                            onDismiss()
                        } else {
                            dismiss()
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32)) // Slightly bigger button
                            .foregroundColor(.white.opacity(0.8))
                            .background(Circle().fill(Color.black.opacity(0.1)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
            }
        }
        .fullScreenCover(isPresented: $showingStoryReader) {
            StoryReaderView(story: story)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [story.title, story.pages.first?.text ?? ""])
        }
        .sheet(isPresented: $showPDFShare) {
            ShareSheet(items: itemsToShare) {
                showPDFShare = false
            }
        }
        .fullScreenCover(isPresented: $showPaywallForPDF) {
            PaywallView()
        }
        .onAppear {
            startAnimation()
            logSuccess()
            
            // Trigger confetti
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showConfetti = true
            }
        }
    }
    
    // MARK: - Compact Success View

    private var compactSuccessView: some View {
        VStack(spacing: 0) {
            // Success icon with owl_ok image - Bigger and lifted higher
            Image("owl_ok")
                .resizable()
                .renderingMode(.original)
                .aspectRatio(contentMode: .fit)
                .frame(width: 320, height: 320) // Even bigger
                .shadow(color: .white.opacity(0.3), radius: 25)
                .padding(.top, -40) // Adjusted slightly lower
                .scaleEffect(animationPhase >= 1 ? 1.0 : 0.3)
                .opacity(animationPhase >= 1 ? 1.0 : 0.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.6), value: animationPhase)

            VStack(spacing: 2) {
                Text("result_story_ready".localized)
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .purple.opacity(0.6), radius: 12)

                Text("result_congratulations_message".localized)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, -45) // Pull text much higher up
            .opacity(animationPhase >= 2 ? 1.0 : 0.0)
            .animation(.easeIn(duration: 0.5).delay(0.3), value: animationPhase)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Compact Story Card
    
    private var compactStoryCard: some View {
        VStack(spacing: 16) {
            // Cover Image
            ZStack {
                if let imageUrl = story.coverImageUrl {
                    WebImage(url: URL(string: imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                            .clipped()
                    } placeholder: {
                        compactPlaceholderCover
                    }
                } else {
                    compactPlaceholderCover
                }
                
                // Overlay glow on image
                LinearGradient(colors: [.clear, .black.opacity(0.3)], startPoint: .top, endPoint: .bottom)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 8) {
                // Title
                Text(story.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.2), radius: 2)
                
                // Stats (Primary info)
                HStack(spacing: 12) {
                    StatIconView(icon: "book.pages", text: String(format: "pages_count".localized, story.pages.count))
                    StatIconView(icon: "clock", text: String(format: "minutes_short".localized, story.roundedMinutes))
                }
                
                // Metadata Tags (Environment & Features) - Flowing layout to prevent overflow
                FlowLayout(spacing: 6) {
                    TagView(text: story.localizedCategory, color: .purple)
                    TagView(text: localizedAgeRange, color: .blue)
                    TagView(text: localizedLanguageName, color: .orange)
                    
                    if story.isIllustrated {
                        TagView(text: "result_illustrated".localized, color: .green)
                    }
                    
                    if story.audioUrl != nil {
                        TagView(text: "result_with_audio".localized, color: .pink)
                    }
                }
                .padding(.top, 4)
            }
            .padding(.bottom, 10)
        }
        .padding(12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Material.ultraThinMaterial)
                
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.5), .white.opacity(0.1), .purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        )
        .shadow(color: .purple.opacity(0.2), radius: 20)
        .scaleEffect(animationPhase >= 3 ? 1.0 : 0.9)
        .opacity(animationPhase >= 3 ? 1.0 : 0.0)
        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.6), value: animationPhase)
    }
    
    // MARK: - Helper Methods
    
    private var localizedAgeRange: String {
        let range = story.metadata?.ageRange ?? "0-3"
        switch range {
        case "0-3": return "age_range_0_3".localized
        case "4-6": return "age_range_4_6".localized
        case "7-9": return "age_range_7_9".localized
        case "10-12": return "age_range_10_12".localized
        case "13+": return "age_range_13_plus".localized
        default: return "age_range_0_3".localized
        }
    }
    
    private var localizedLanguageName: String {
        switch story.language.lowercased() {
        case "tr": return "language_turkish".localized
        case "en": return "language_english".localized
        case "fr": return "language_french".localized
        case "de": return "language_german".localized
        case "es": return "language_spanish".localized
        default: return "language_turkish".localized
        }
    }
    
    // MARK: - Success Animation
    
    private var successAnimationView: some View {
        VStack(spacing: 20) {
            ZStack {
                // Animated sparkle circles
                ForEach(0..<4) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.blue.opacity(0.2),
                                    Color.purple.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 100 + CGFloat(index * 35))
                        .scaleEffect(animationPhase >= index ? 1.0 : 0.3)
                        .opacity(animationPhase >= index ? 1.0 : 0.0)
                        .rotationEffect(.degrees(Double(index) * 45))
                }
                
                // Floating sparkles
                ForEach(0..<6) { index in
                    Text("✨")
                        .font(.system(size: 20))
                        .offset(
                            x: cos(Double(index) * .pi / 3) * 60,
                            y: sin(Double(index) * .pi / 3) * 60
                        )
                        .scaleEffect(animationPhase >= 2 ? 1.0 : 0.0)
                        .opacity(animationPhase >= 2 ? 1.0 : 0.0)
                        .animation(
                            .easeInOut(duration: 0.8)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1),
                            value: animationPhase
                        )
                }
                
                // Central success icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.green.opacity(0.9),
                                    Color.blue.opacity(0.8),
                                    Color.purple.opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 90, height: 90)
                        .shadow(color: .white.opacity(0.3), radius: 10)
                    
                    Text("🎉")
                        .font(.system(size: 45))
                }
                .scaleEffect(animationPhase >= 3 ? 1.0 : 0.3)
                .opacity(animationPhase >= 3 ? 1.0 : 0.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.6), value: animationPhase)
            }
            .frame(height: 220)
            
            VStack(spacing: 12) {
                Text("result_story_ready".localized)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2)
                
                Text("result_congratulations_message".localized)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.95))
                
                Text("result_reading_time".localized)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
            }
            .opacity(animationPhase >= 4 ? 1.0 : 0.0)
            .animation(.easeIn(duration: 0.5).delay(0.8), value: animationPhase)
        }
    }
    
    // MARK: - Story Preview
    
    private var storyPreviewCard: some View {
        VStack(spacing: 16) {
            // Cover Image
            if let imageUrl = story.coverImageUrl {
                WebImage(url: URL(string: imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } placeholder: {
                    placeholderCover
                }
            } else {
                placeholderCover
            }
            
            // Title
            Text(story.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            // First paragraph preview
            if let firstPage = story.pages.first {
                Text(firstPage.text)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(20)
        .dwGlassCard()
    }
    
    private var placeholderCover: some View {
        StoryPlaceholderView(size: .large)
            .frame(height: 250)
    }
    
    private var compactPlaceholderCover: some View {
        StoryPlaceholderView(size: .medium)
            .frame(maxWidth: .infinity)
            .frame(height: 200)
    }
    
    // MARK: - Story Stats
    
    private var storyStatsView: some View {
        HStack(spacing: 12) {
            StatBadge(
                icon: "book.pages",
                value: "\(story.pages.count)",
                label: "stat_pages".localized
            )
            
            StatBadge(
                icon: "clock",
                value: "\(story.roundedMinutes)",
                label: "stat_minutes".localized
            )
            
            if story.isIllustrated {
                StatBadge(
                    icon: "photo",
                    value: "\(story.illustrations?.count ?? 0)",
                    label: "stat_illustrations".localized
                )
            }
            
            if story.audioUrl != nil {
                StatBadge(
                    icon: "speaker.wave.2",
                    value: "stat_audio_available".localized,
                    label: "result_with_audio".localized
                )
            }
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtonsView: some View {
        VStack(spacing: 16) {
            // Read Now - Primary Action
            Button(action: {
                showingStoryReader = true
                DWLogger.shared.logUserAction("Read Story from Result", details: story.title)
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 20))
                    Text("result_read_now".localized)
                        .font(.system(size: 18, weight: .black))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(
                    ZStack {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "4F8CFF"), Color(hex: "9F5AFF")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Capsule()
                            .stroke(Color.white.opacity(0.4), lineWidth: 2)
                            .blur(radius: 1)
                    }
                )
                .shadow(color: Color(hex: "4F8CFF").opacity(0.5), radius: 15, x: 0, y: 10)
            }
            .scaleEffect(animationPhase >= 4 ? 1.0 : 0.9)
            .opacity(animationPhase >= 4 ? 1.0 : 0.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.9), value: animationPhase)
            
            // Share Button
            Button(action: {
                handleSharePDF()
            }) {
                HStack(spacing: 10) {
                    if isGeneratingPDF {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.up.fill")
                            .font(.system(size: 18))
                    }
                    Text(isGeneratingPDF ? "pdf_generating".localized : "share".localized)
                        .font(.system(size: 17, weight: .bold))

                    if subscriptionService.currentTier == .free {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.yellow)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                        )
                )
            }
            .disabled(isGeneratingPDF)
            .scaleEffect(animationPhase >= 5 ? 1.0 : 0.9)
            .opacity(animationPhase >= 5 ? 1.0 : 0.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(1.1), value: animationPhase)
        }
    }
    
    // MARK: - Character Save Prompt
    
    private var characterSavePromptView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "person.2.badge.gearshape")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("story_result_save_characters".localized)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text("story_result_save_characters_description".localized)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            Button(action: {
                showingSaveCharacterAlert = true
            }) {
                Text("story_result_save_characters".localized)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.orange, Color.pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(10)
            }
        }
        .padding(16)
        .dwGlassCard()
    }
    
    // MARK: - Helpers
    
    private var hasCharactersWithProfiles: Bool {
        story.characterProfiles?.isEmpty == false
    }
    
    private func startAnimation() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
            animationPhase = 1
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeIn(duration: 0.5)) {
                animationPhase = 2
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animationPhase = 3
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animationPhase = 4
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animationPhase = 5
            }
        }
    }
    
    private func logSuccess() {
        DWLogger.shared.logAnalyticsEvent("story_creation_completed", parameters: [
            "story_id": story.id,
            "pages": story.pages.count,
            "estimated_minutes": story.roundedMinutes,
            "has_audio": story.audioUrl != nil,
            "has_image": story.coverImageUrl != nil,
            "is_illustrated": story.isIllustrated,
            "tier": story.metadata?.tier ?? ""
        ])
    }

    private func handleSharePDF() {
        let currentTier = subscriptionService.currentTier

        // Check tier - Plus and above can share
        if currentTier == .free {
            DWLogger.shared.logUserAction("Share Blocked", details: "Free tier user attempted share")
            showPaywallForPDF = true
            return
        }

        // Start generation process
        isGeneratingPDF = true
        shareProgress = ""

        let shareType = currentTier == .pro && story.audioUrl != nil ? "PDF + Audio" : "PDF Only"
        DWLogger.shared.info("📦 Starting share generation (\(shareType)) for story: \(story.title)", category: .general)

        Task {
            do {
                var itemsToShare: [Any] = []

                // 1️⃣ Generate PDF (Plus and Pro)
                await MainActor.run {
                    shareProgress = "Generating PDF..."
                }

                // Safety check: If story is summary or pages are empty, fetch full story first
                var storyForPDF = story
                if story.isSummary || story.pages.isEmpty {
                    DWLogger.shared.info("📥 Story is summary, fetching full content for PDF...", category: .general)
                    let isPrewritten = (story.type == .prewritten)
                    storyForPDF = try await StoryPrefetchManager.shared.getFullStory(id: story.id, isPrewritten: isPrewritten)
                    DWLogger.shared.info("✅ Full story fetched: \(storyForPDF.pages.count) pages", category: .general)
                }

                let pdfData = try await PDFGenerator.shared.generatePDF(
                    for: storyForPDF,
                    includeCover: true,
                    includeIllustrations: storyForPDF.isIllustrated
                )
                itemsToShare.append(PDFActivityItem(pdfData: pdfData, fileName: "\(story.title).pdf"))
                DWLogger.shared.info("✅ PDF generated successfully (\(pdfData.count) bytes)", category: .general)

                // 2️⃣ Download and add audio (ONLY PRO users)
                if currentTier == .pro, let audioUrl = story.audioUrl {
                    await MainActor.run {
                        shareProgress = "Adding audio file..."
                    }

                    DWLogger.shared.info("🎵 PRO user - Downloading audio for share", category: .general)
                    do {
                        let audioData = try await downloadAudio(from: audioUrl)
                        itemsToShare.append(AudioActivityItem(audioData: audioData, fileName: "\(story.title).mp3"))
                        DWLogger.shared.info("✅ Audio added successfully (\(audioData.count) bytes)", category: .general)
                    } catch {
                        DWLogger.shared.warning("⚠️ Audio download failed, sharing PDF only: \(error.localizedDescription)", category: .general)
                        // Continue with PDF only - don't fail the entire share
                    }
                }

                // 3️⃣ Open share sheet
                await MainActor.run {
                    self.itemsToShare = itemsToShare
                    self.isGeneratingPDF = false
                    self.shareProgress = ""
                    self.showPDFShare = true

                    DWLogger.shared.info("✅ Share sheet opened with \(itemsToShare.count) item(s)", category: .general)
                    DWLogger.shared.logUserAction("Share", details: "\(shareType) - \(story.title)")
                }
            } catch {
                await MainActor.run {
                    self.isGeneratingPDF = false
                    self.shareProgress = ""
                    DWLogger.shared.error("❌ Failed to generate share items", error: error, category: .general)

                    // Show user-friendly error
                    GlassAlertManager.shared.showAlert(
                        type: .error,
                        title: "share_error_title".localized,
                        message: "share_error_message".localized
                    )
                }
            }
        }
    }

    /// Downloads audio file from URL for sharing
    private func downloadAudio(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return data
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.8))
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var onDismiss: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            onDismiss?()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - PDF Activity Item

class PDFActivityItem: NSObject, UIActivityItemSource {
    let pdfData: Data
    let fileName: String
    private var tempFileURL: URL?

    init(pdfData: Data, fileName: String) {
        self.pdfData = pdfData
        // Sanitize filename to remove invalid characters
        let sanitizedName = fileName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
        self.fileName = sanitizedName
        super.init()
        
        // Write PDF to temp directory with proper filename
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(sanitizedName)
        try? pdfData.write(to: fileURL)
        self.tempFileURL = fileURL
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return tempFileURL ?? pdfData
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        // Return file URL for proper filename in WhatsApp and other apps
        return tempFileURL ?? pdfData
    }

    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return fileName
    }

    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        return "com.adobe.pdf"
    }
}

// MARK: - Audio Activity Item

class AudioActivityItem: NSObject, UIActivityItemSource {
    let audioData: Data
    let fileName: String
    private var tempFileURL: URL?

    init(audioData: Data, fileName: String) {
        self.audioData = audioData
        // Sanitize filename to remove invalid characters
        let sanitizedName = fileName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
        self.fileName = sanitizedName
        super.init()
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return URL(fileURLWithPath: fileName)
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        // Create temp file
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try audioData.write(to: fileURL)
            tempFileURL = fileURL
            DWLogger.shared.debug("✅ Audio temp file created: \(fileURL.lastPathComponent)", category: .general)
            return fileURL
        } catch {
            DWLogger.shared.error("Failed to write audio temp file", error: error, category: .general)
            return nil
        }
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        return fileName.replacingOccurrences(of: ".mp3", with: "")
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        return "public.mp3"
    }

    deinit {
        // Clean up temp file
        if let tempURL = tempFileURL {
            try? FileManager.default.removeItem(at: tempURL)
            DWLogger.shared.debug("🗑 Audio temp file cleaned up", category: .general)
        }
    }
}

// MARK: - Layout Components

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            let point = result.points[index]
            subview.place(at: CGPoint(x: point.x + bounds.minX, y: point.y + bounds.minY), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var points: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: LayoutSubviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                points.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
                self.size.width = max(self.size.width, currentX)
            }
            self.size.height = currentY + lineHeight
        }
    }
}

// MARK: - Helper Views

struct MagicalBackgroundView: View {
    var body: some View {
        ZStack {
            ForEach(0..<15) { _ in
                ParticleView()
            }
        }
    }
}

struct ParticleView: View {
    @State private var x = CGFloat.random(in: 0...UIScreen.main.bounds.width)
    @State private var y = CGFloat.random(in: 0...UIScreen.main.bounds.height)
    @State private var opacity = Double.random(in: 0.1...0.4)
    @State private var scale = CGFloat.random(in: 0.5...1.5)
    
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 4, height: 4)
            .scaleEffect(scale)
            .position(x: x, y: y)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: Double.random(in: 3...6)).repeatForever(autoreverses: true)) {
                    x += CGFloat.random(in: -50...50)
                    y += CGFloat.random(in: -50...50)
                    opacity = Double.random(in: 0.1...0.5)
                }
            }
    }
}

struct TagView: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.3))
            .cornerRadius(6)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

struct StatIconView: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.white.opacity(0.1)))
    }
}

// MARK: - Preview

#Preview {
    StoryResultView(story: Story.mockStory)
}

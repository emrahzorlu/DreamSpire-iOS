//
//  AudioModeView.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//

import SwiftUI
import SDWebImageSwiftUI

struct AudioModeView: View {
    @ObservedObject var viewModel: StoryReaderViewModel
    @State private var hasAutoStarted = false
    
    // MARK: - Smooth Slider State
    @State private var isDragging = false
    @State private var dragProgress: Double = 0  // 0.0 to 1.0

    var body: some View {
        if viewModel.story.audioUrl != nil {
            // Actual audio player
            VStack(spacing: 20) {
                // Cover Image or Placeholder
                if let coverUrl = viewModel.story.coverImageUrl {
                    WebImage(url: URL(string: coverUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 280, height: 280)
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    } placeholder: {
                        placeholderCover
                    }
                } else {
                    placeholderCover
                }
                
                // Story Title - Up to 3 lines support with better readability
                Text(viewModel.story.title)
                    .font(.custom("Georgia", size: 18))
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 0.298, green: 0.235, blue: 0.361))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .lineSpacing(3)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 30)
                
                // Audio Player Controls
                VStack(spacing: 20) {
                    // Progress bar with draggable thumb - SMOOTH SLIDER
                    VStack(spacing: 8) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background track
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(red: 0.545, green: 0.361, blue: 0.965).opacity(0.2))
                                    .frame(height: 6)
                                
                                // Progress fill - uses local state when dragging
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.902, green: 0.475, blue: 0.976),
                                                Color(red: 0.545, green: 0.361, blue: 0.965)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: sliderWidth(geometry: geometry), height: 6)
                                
                                // Draggable thumb - scales up when dragging (from center)
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white,
                                                Color(red: 0.95, green: 0.95, blue: 1.0)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: 20, height: 20)
                                    .scaleEffect(isDragging ? 1.3 : 1.0) // Scale from center - no shift
                                    .shadow(color: Color(red: 0.545, green: 0.361, blue: 0.965).opacity(isDragging ? 0.5 : 0.3), radius: isDragging ? 6 : 4, x: 0, y: 2)
                                    .offset(x: sliderWidth(geometry: geometry) - 10)
                                    .animation(.spring(response: 0.15, dampingFraction: 0.7), value: isDragging)
                            }
                            .contentShape(Rectangle()) // Make entire area tappable
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        // Use local state during drag - no player update
                                        if !isDragging {
                                            isDragging = true
                                        }
                                        let width = geometry.size.width
                                        dragProgress = max(0, min(1, value.location.x / width))
                                    }
                                    .onEnded { value in
                                        // Only seek when drag ends - smooth experience
                                        let width = geometry.size.width
                                        let finalProgress = max(0, min(1, value.location.x / width))
                                        viewModel.seekAudio(to: finalProgress * viewModel.duration)
                                        
                                        // Reset drag state after a small delay for smooth transition
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            isDragging = false
                                        }
                                    }
                            )
                            // Tap to seek
                            .onTapGesture { location in
                                let progress = max(0, min(1, location.x / geometry.size.width))
                                viewModel.seekAudio(to: progress * viewModel.duration)
                            }
                        }
                        .frame(height: 26) // Slightly taller for better touch target
                        
                        // Time labels - shows drag position when dragging
                        HStack {
                            Text(formatTime(displayTime))
                                .font(.custom("Georgia", size: 12))
                                .foregroundColor(Color(red: 0.545, green: 0.361, blue: 0.965).opacity(0.7))
                                .monospacedDigit() // Prevent layout jump during drag
                            
                            Spacer()
                            
                            // Show placeholder if duration is still loading
                            Text(viewModel.duration > 0 ? formatTime(viewModel.duration) : "--:--")
                                .font(.custom("Georgia", size: 12))
                                .foregroundColor(Color(red: 0.545, green: 0.361, blue: 0.965).opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 40)
                    // Play/Pause controls - Premium floating panel
                    HStack(spacing: 40) {
                        // Skip backward button with background
                        Button(action: {
                            let newTime = max(0, viewModel.currentTime - 15)
                            viewModel.seekAudio(to: newTime)
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 56, height: 56)
                                    .shadow(color: Color(red: 0.545, green: 0.361, blue: 0.965).opacity(0.15), radius: 8, x: 0, y: 4)
                                
                                Image(systemName: "gobackward.15")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(Color(red: 0.545, green: 0.361, blue: 0.965))
                            }
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        // Main play/pause button
                        Button(action: {
                            viewModel.toggleAudio()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.902, green: 0.475, blue: 0.976),
                                                Color(red: 0.698, green: 0.408, blue: 0.976),
                                                Color(red: 0.545, green: 0.361, blue: 0.965)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                    .shadow(color: Color(red: 0.545, green: 0.361, blue: 0.965).opacity(0.4), radius: 16, x: 0, y: 8)
                                
                                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                                    .offset(x: viewModel.isPlaying ? 0 : 2)
                            }
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        // Skip forward button with background
                        Button(action: {
                            let newTime = min(viewModel.duration, viewModel.currentTime + 15)
                            viewModel.seekAudio(to: newTime)
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 56, height: 56)
                                    .shadow(color: Color(red: 0.545, green: 0.361, blue: 0.965).opacity(0.15), radius: 8, x: 0, y: 4)
                                
                                Image(systemName: "goforward.15")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(Color(red: 0.545, green: 0.361, blue: 0.965))
                            }
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .padding(.top, 24)
                    
                    // Speed controls - Modern pill design
                    HStack(spacing: 8) {
                        ForEach([0.5, 0.75, 1.0, 1.25, 1.5], id: \.self) { speed in
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    viewModel.changePlaybackSpeed(Float(speed))
                                }
                            }) {
                                Text("\(speed, specifier: "%.2g")x")
                                    .font(.system(size: 14, weight: viewModel.playbackSpeed == Float(speed) ? .bold : .medium, design: .rounded))
                                    .foregroundColor(
                                        viewModel.playbackSpeed == Float(speed)
                                            ? .white
                                            : Color(red: 0.545, green: 0.361, blue: 0.965)
                                    )
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        Group {
                                            if viewModel.playbackSpeed == Float(speed) {
                                                Capsule()
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [
                                                                Color(red: 0.902, green: 0.475, blue: 0.976),
                                                                Color(red: 0.545, green: 0.361, blue: 0.965)
                                                            ],
                                                            startPoint: .leading,
                                                            endPoint: .trailing
                                                        )
                                                    )
                                                    .shadow(color: Color(red: 0.545, green: 0.361, blue: 0.965).opacity(0.3), radius: 6, x: 0, y: 3)
                                            } else {
                                                Capsule()
                                                    .fill(Color.white.opacity(0.9))
                                                    .overlay(
                                                        Capsule()
                                                            .stroke(Color(red: 0.545, green: 0.361, blue: 0.965).opacity(0.2), lineWidth: 1)
                                                    )
                                            }
                                        }
                                    )
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, 20)
                }
                .padding(.top, 20)
            }
            .frame(maxHeight: .infinity)
            .onAppear {
                // Auto-start audio 1 second after screen opens
                guard !hasAutoStarted, !viewModel.isPlaying else { return }
                hasAutoStarted = true

                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

                    // Check if still not playing (user might have closed or toggled)
                    if !viewModel.isPlaying {
                        viewModel.toggleAudio()
                    }
                }
            }
            .onDisappear {
                // Reset flag when leaving audio mode
                hasAutoStarted = false
            }
        } else {
            // Empty state - no audio
            emptyAudioState
        }
    }
    
    private var placeholderCover: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.902, green: 0.475, blue: 0.976).opacity(0.6),
                            Color(red: 0.545, green: 0.361, blue: 0.965).opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 280, height: 280)

            VStack(spacing: 12) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.6))

                // Loading indicator when cover is missing/loading
                if viewModel.story.coverImageUrl != nil {
                    Text("loading_image".localized)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .shimmering(active: viewModel.story.coverImageUrl != nil) // Shimmer ONLY when loading (has URL)
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
    
    private var emptyAudioState: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.slash")
                .font(.system(size: 60))
                .foregroundColor(Color(red: 0.545, green: 0.361, blue: 0.965).opacity(0.5))

            Text("audio_mode_file_not_found".localized)
                .font(.custom("Georgia", size: 20))
                .fontWeight(.semibold)
                .foregroundColor(Color(red: 0.298, green: 0.235, blue: 0.361))

            Text("audio_mode_no_audio_message".localized)
                .font(.custom("Georgia", size: 14))
                .foregroundColor(Color(red: 0.545, green: 0.361, blue: 0.965).opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
    }
    
    private func sliderWidth(geometry: GeometryProxy) -> CGFloat {
        guard viewModel.duration > 0 else { return 0 }
        
        // Use local drag progress when dragging, otherwise use player's current time
        let progress = isDragging ? dragProgress : (viewModel.currentTime / viewModel.duration)
        return geometry.size.width * CGFloat(progress)
    }
    
    /// Returns the time to display - uses drag position when dragging
    private var displayTime: Double {
        if isDragging {
            return dragProgress * viewModel.duration
        }
        return viewModel.currentTime
    }
    
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(red: 0.95, green: 0.93, blue: 0.88)
            .ignoresSafeArea()
        
        AudioModeView(viewModel: StoryReaderViewModel(story: Story.mockStory))
    }
}

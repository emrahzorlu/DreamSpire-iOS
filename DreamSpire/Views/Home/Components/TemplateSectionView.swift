//
//  TemplateSectionView.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025.
//

import SwiftUI
import SDWebImageSwiftUI

/// Template stories section for home screen
struct TemplateSectionView: View {
    @Binding var showingTemplateGallery: Bool
    @ObservedObject private var viewModel = TemplateViewModel.shared
    @State private var selectedTemplate: Template?
    
    var body: some View {
        VStack(spacing: 10) {
            // Section Header
            HStack {
                Text("home_quick_stories_emoji".localized)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: { showingTemplateGallery = true }) {
                    HStack(spacing: 4) {
                        Text("home_see_all".localized)
                            .font(.system(size: 15, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 20)
            
            // Horizontal Scroll
            ZStack {
                // Show skeleton on initial load
                if viewModel.isLoading {
                    TemplateSkeletonRow()
                }
                // Show content
                else if !viewModel.templates.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.templates.prefix(8)) { template in
                                TemplateHomeCard(
                                    template: template,
                                    isLocked: !viewModel.canAccessTemplate(template),
                                    action: {
                                        if viewModel.canAccessTemplate(template) {
                                            selectedTemplate = template
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                // Skeleton overlay during language change
                if viewModel.isRefreshing && !viewModel.templates.isEmpty {
                    ZStack {
                        Color.black.opacity(0.7)
                        TemplateSkeletonRow()
                    }
                }
            }
        }
        .task {
            await viewModel.loadTemplates()
        }
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            Task {
                await viewModel.loadTemplates()
            }
        }
        .fullScreenCover(item: $selectedTemplate) { template in
            TemplateDetailView(template: template)
        }
    }
}

// MARK: - Skeleton Row

private struct TemplateSkeletonRow: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    TemplateCardSkeleton(width: 140, height: 190)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Template Home Card

struct TemplateHomeCard: View {
    let template: Template
    let isLocked: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Background Image
                if let imageUrl = template.previewImageUrl, let url = URL(string: imageUrl) {
                    WebImage(url: url) { image in
                        image.resizable()
                    } placeholder: {
                        TemplateCardPlaceholder(emoji: template.emoji)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 140, height: 190)
                    .clipped()
                } else {
                    TemplateCardPlaceholder(emoji: template.emoji)
                }
                
                // Gradient overlay
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Spacer()
                    
                    Text(template.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .shadow(radius: 2)
                    
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text("\(template.fixedParams.defaultMinutes) " + "minutes_short_text".localized)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.9))
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Lock overlay
                if isLocked {
                    ZStack {
                        Color.black.opacity(0.6)
                        Image(systemName: "lock.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                }
            }
            .frame(width: 140, height: 190)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(template.title)
        .accessibilityHint(isLocked ? "Kilitli içerik" : "Hikaye oluşturmak için dokunun")
    }
}

// MARK: - Placeholder

private struct TemplateCardPlaceholder: View {
    let emoji: String
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.purple.opacity(0.4), Color.blue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(emoji)
                .font(.system(size: 50))
        }
        .frame(width: 140, height: 190)
    }
}

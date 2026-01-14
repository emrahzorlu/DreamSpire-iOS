//
//  TemplateGalleryView.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025-11-02
//

import SwiftUI
import SDWebImageSwiftUI

struct TemplateGalleryView: View {
    @ObservedObject private var viewModel = TemplateViewModel.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedTemplate: Template?
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient.dwBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Category Filters
                categoryFiltersView
                
                // Templates Grid
                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.error {
                    errorView(message: error)
                } else {
                    templatesGridView
                }
            }
        }
        .dismissKeyboardOnTap()
        .fullScreenCover(item: $selectedTemplate) { template in
            TemplateDetailView(template: template)
        }
        .onAppear {
            Task {
                await viewModel.loadTemplates()
            }
        }
        .preferredColorScheme(.light)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.white.opacity(0.2)))
            }
            
            Spacer()
            
            Text("template_gallery_title".localized)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            // Placeholder for symmetry
            Color.clear
                .frame(width: 32, height: 32)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }
    
    // MARK: - Search Bar
    
    private var searchBarView: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
            
            TextField("template_search_placeholder".localized, text: $searchText)
                .focused($isSearchFocused)
                .submitLabel(.done)
                .onSubmit { isSearchFocused = false }
                .font(.system(size: 16))
                .foregroundColor(.white)
                .accentColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.15))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    // MARK: - Category Filters
    
    private var categoryFiltersView: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.categoryFilters, id: \.self) { category in
                        FilterChip(
                            title: category,
                            isSelected: viewModel.selectedCategory == category,
                            action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    viewModel.filterByCategory(category)
                                    proxy.scrollTo(category, anchor: .center)
                                }
                            }
                        )
                        .id(category)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
    }
    
    // MARK: - Templates Grid

    private var templatesGridView: some View {
        ZStack {
            // Real content
            ScrollView(showsIndicators: false) {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ],
                    spacing: 16
                ) {
                    ForEach(viewModel.filteredTemplates) { template in
                        TemplateCard(
                            template: template,
                            isLocked: !viewModel.canAccessTemplate(template),
                            action: {
                                if viewModel.canAccessTemplate(template) {
                                    selectedTemplate = template
                                } else {
                                    // Show paywall
                                    DWLogger.shared.logUserAction("Locked Template Tapped", details: template.title)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }

            // Skeleton overlay during language change
            if viewModel.isRefreshing && !viewModel.filteredTemplates.isEmpty {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ],
                        spacing: 16
                    ) {
                        ForEach(0..<6, id: \.self) { _ in
                            TemplateCardSkeleton(height: 170, cornerRadius: 16)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.1, green: 0.1, blue: 0.2),
                            Color(red: 0.15, green: 0.1, blue: 0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .opacity(0.95)
                )
            }
        }
    }
    
    // MARK: - Loading & Error
    
    private var loadingView: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ],
                spacing: 16
            ) {
                ForEach(0..<6, id: \.self) { _ in
                    TemplateCardSkeleton(height: 170, cornerRadius: 16)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.white.opacity(0.6))
            
            Text(message)
                .font(.system(size: 17))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Button("try_again".localized) {
                Task {
                    await viewModel.loadTemplates()
                }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.2))
            .cornerRadius(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
}

// MARK: - Template Card

struct TemplateCard: View {
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
                        ZStack {
                            LinearGradient(
                                colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 170)
                    .clipped()
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [Color.purple.opacity(0.4), Color.blue.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Text(template.emoji)
                            .font(.system(size: 50))
                    }
                }
                
                // Gradient overlay
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.8)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    Spacer()
                    
                    Text(template.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .shadow(radius: 2)
                    
                    Text(template.description)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(2)
                        .shadow(radius: 1)
                    
                    // Info row
                    HStack(spacing: 8) {
                        HStack(spacing: 3) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 10))
                            Text("\(template.characterSchema.allSlots.count)")
                                .font(.system(size: 11, weight: .medium))
                        }
                        
                        HStack(spacing: 3) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 10))
                            Text("\(template.fixedParams.defaultMinutes) " + "minutes_short_text".localized)
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .foregroundColor(.white.opacity(0.85))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Lock overlay
                if isLocked {
                    ZStack {
                        Color.black.opacity(0.6)
                        
                        VStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                            
                            Text(template.tier == .plus ? "Plus" : "Pro")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .frame(height: 170)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    TemplateGalleryView()
}

//
//  ReadingModeView.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//
//  This is the final, refactored version that supports both text-only and illustrated pages
//  within the Page-Curl UI, and incorporates all user-requested layout adjustments.
//

import SwiftUI
import SDWebImageSwiftUI
import UIKit

// MARK: - Vintage Book Design Constants
private struct VintageBookStyle {
    static let fontName = "SFProDisplay-Medium"
    static let dropCapFont = "PlayfairDisplay-Bold" // Decorative font for first letter
    static let textColor = Color(red: 0.25, green: 0.2, blue: 0.15) // Darker brown
    static let dropCapColor = Color(red: 0.4, green: 0.2, blue: 0.5) // Dark purple
    static let pageColor = Color(red: 0.98, green: 0.96, blue: 0.92) // Warmer cream
    static let borderColor = Color(red: 0.6, green: 0.5, blue: 0.35)
    static let dividerColor = Color(red: 0.5, green: 0.4, blue: 0.3)
}

// View for text-only pages with vintage design
struct BookPageView: View {
    let text: String
    let isFirstPage: Bool
    let fontSize: CGFloat
    
    init(text: String, isFirstPage: Bool = false, fontSize: CGFloat = 17) {
        self.text = text
        self.isFirstPage = isFirstPage
        self.fontSize = fontSize
    }
    
    var body: some View {
        ZStack {
            // Warm paper background
            VintageBookStyle.pageColor
            
            // Vintage double border frame
            vintageBorderFrame
            
            // ScrollView for overflow handling
            ScrollView(showsIndicators: false) {
                styledText(fontSize: fontSize)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 24)
            }
            .padding(12) // Space for border
        }
        .clipped()
    }
    
    // Vintage decorative border frame
    private var vintageBorderFrame: some View {
        ZStack {
            // Outer border
            RoundedRectangle(cornerRadius: 4)
                .stroke(VintageBookStyle.borderColor.opacity(0.4), lineWidth: 2)
                .padding(8)
            
            // Inner border
            RoundedRectangle(cornerRadius: 2)
                .stroke(VintageBookStyle.borderColor.opacity(0.25), lineWidth: 1)
                .padding(14)
        }
    }
    
    @ViewBuilder
    private func styledText(fontSize: CGFloat) -> some View {
        let paragraphs = text.components(separatedBy: "\n\n").filter { !$0.isEmpty }
        
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                // Decorative drop cap for first paragraph of first page
                if index == 0 && isFirstPage && paragraph.count > 1 {
                    decorativeDropCap(paragraph, fontSize: fontSize)
                } else {
                    Text(paragraph)
                        .font(.custom(VintageBookStyle.fontName, size: fontSize))
                        .lineSpacing(6)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(VintageBookStyle.textColor)
                }
                
                // Diamond divider between paragraphs (not after last)
                if index < paragraphs.count - 1 {
                    sectionDivider
                }
            }
        }
    }
    
    // Decorative drop cap - large fancy first letter inline with text
    @ViewBuilder
    private func decorativeDropCap(_ paragraph: String, fontSize: CGFloat) -> some View {
        let firstChar = String(paragraph.prefix(1))
        let restOfText = String(paragraph.dropFirst())
        
        // Using Text concatenation for inline styling
        (Text(firstChar)
            .font(.custom(VintageBookStyle.dropCapFont, size: fontSize * 2.5))
            .foregroundColor(VintageBookStyle.dropCapColor)
         + Text(restOfText)
            .font(.custom(VintageBookStyle.fontName, size: fontSize))
            .foregroundColor(VintageBookStyle.textColor))
            .lineSpacing(6)
            .multilineTextAlignment(.leading)
    }
    
    // Diamond section divider (like in reference image)
    private var sectionDivider: some View {
        HStack(spacing: 16) {
            Rectangle()
                .fill(VintageBookStyle.dividerColor.opacity(0.3))
                .frame(height: 1)
            
            Text("◆")
                .font(.system(size: 8))
                .foregroundColor(VintageBookStyle.dividerColor.opacity(0.5))
            
            Rectangle()
                .fill(VintageBookStyle.dividerColor.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.vertical, 20)
    }
}

// View for illustrated pages with image and text in single scrollable container
struct IllustratedBookPageView: View {
    let imageUrl: String
    let text: String
    let isFirstPage: Bool
    let fontSize: CGFloat

    init(imageUrl: String, text: String, isFirstPage: Bool = false, fontSize: CGFloat = 15) {
        self.imageUrl = imageUrl
        self.text = text
        self.isFirstPage = isFirstPage
        self.fontSize = fontSize
    }
    
    var body: some View {
        ZStack {
            VintageBookStyle.pageColor
            
            // Single ScrollView containing both image and text
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Image with enhanced shimmer loader for smooth loading indication
                    WebImage(
                        url: URL(string: imageUrl),
                        options: [.retryFailed, .scaleDownLargeImages, .queryMemoryData]
                    ) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } placeholder: {
                        // Enhanced shimmer placeholder for illustrated story images
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.9, green: 0.9, blue: 0.9),
                                            Color(red: 0.95, green: 0.95, blue: 0.95)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(height: 280)

                            // Photo icon to indicate image loading
                            VStack(spacing: 8) {
                                Image(systemName: "photo")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray.opacity(0.3))

                                Text("loading_image".localized)
                                    .font(.caption)
                                    .foregroundColor(.gray.opacity(0.5))
                            }
                        }
                        .shimmering(active: true) // Active shimmer during image loading
                    }
                    .onFailure { error in
                        DWLogger.shared.error("❌ Failed to load illustration: \(imageUrl)", error: error, category: .story)
                    }
                    .transition(.opacity)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // Diamond divider between image and text
                    illustratedDivider

                    // Text content
                    illustratedText(fontSize: fontSize)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
            }
            .padding(.horizontal, 8)
        }
    }
    
    @ViewBuilder
    private func illustratedText(fontSize: CGFloat) -> some View {
        let paragraphs = text.components(separatedBy: "\n\n").filter { !$0.isEmpty }
        
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                // Decorative drop cap for first paragraph of first page
                if index == 0 && isFirstPage && paragraph.count > 1 {
                    illustratedDecorativeDropCap(paragraph, fontSize: fontSize)
                } else {
                    Text(paragraph)
                        .font(.custom(VintageBookStyle.fontName, size: fontSize))
                        .lineSpacing(5)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(VintageBookStyle.textColor)
                }
            }
        }
    }
    
    // Decorative drop cap for illustrated pages
    @ViewBuilder
    private func illustratedDecorativeDropCap(_ paragraph: String, fontSize: CGFloat) -> some View {
        let firstChar = String(paragraph.prefix(1))
        let restOfText = String(paragraph.dropFirst())
        
        (Text(firstChar)
            .font(.custom(VintageBookStyle.dropCapFont, size: fontSize * 2.2))
            .foregroundColor(VintageBookStyle.dropCapColor)
         + Text(restOfText)
            .font(.custom(VintageBookStyle.fontName, size: fontSize))
            .foregroundColor(VintageBookStyle.textColor))
            .lineSpacing(5)
            .multilineTextAlignment(.leading)
    }
    
    // Diamond divider
    private var illustratedDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(VintageBookStyle.dividerColor.opacity(0.25))
                .frame(height: 1)
            
            Text("◆")
                .font(.system(size: 6))
                .foregroundColor(VintageBookStyle.dividerColor.opacity(0.4))
            
            Rectangle()
                .fill(VintageBookStyle.dividerColor.opacity(0.25))
                .frame(height: 1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 16)
    }
}


// MARK: - Main Reading View

struct ReadingModeView: View {
    @ObservedObject var viewModel: StoryReaderViewModel
    let fontSize: Double
    @State private var currentPageIndex = 0
    
    private let pageBackground = Color.white
    
    init(viewModel: StoryReaderViewModel, fontSize: Double = 17) {
        self.viewModel = viewModel
        self.fontSize = fontSize
    }

    // This computed property prepares the array of pages to be displayed.
    private var preparedPageViews: [AnyView] {
        let illustrationDict = Dictionary(
            (viewModel.story.illustrations ?? []).map { ($0.pageNumber, $0.imageUrl) },
            uniquingKeysWith: { (first, _) in first }
        )
        
        return viewModel.story.pages.enumerated().map { index, page in
            let isFirstPage = (index == 0)
            
            if let imageUrl = illustrationDict[page.pageNumber] {
                return AnyView(IllustratedBookPageView(
                    imageUrl: imageUrl,
                    text: page.text,
                    isFirstPage: isFirstPage,
                    fontSize: max(CGFloat(fontSize) - 2, 13)
                ))
            } else {
                return AnyView(BookPageView(
                    text: page.text,
                    isFirstPage: isFirstPage,
                    fontSize: CGFloat(fontSize)
                ))
            }
        }
    }

    var body: some View {
        ZStack {
            if viewModel.isLoading {
                // Magical loading state while fetching full story
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(Color(red: 0.545, green: 0.361, blue: 0.965))
                    
                    Text("create_final_touches".localized)
                        .font(.custom("Georgia", size: 18))
                        .italic()
                        .foregroundColor(Color(red: 0.545, green: 0.361, blue: 0.965).opacity(0.8))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.story.pages.isEmpty && !viewModel.isLoading {
                // Error state for unreachable or empty story
                VStack(spacing: 20) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.4))

                    Text("Hikaye bulunamadı".localized)
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("story_loading_error".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(VintageBookStyle.pageColor)
            } else {
                VStack(spacing: 0) {
                    PageCurlReaderView(
                        pages: preparedPageViews,
                        currentIndex: $currentPageIndex
                    )
                    // Force rebuild when story content changes (critical for cache hits)
                    .id("\(viewModel.story.id)_\(viewModel.story.pages.count)_\(fontSize)")
                    .background(pageBackground)
                    .clipped()
                    .frame(maxHeight: .infinity)
                    
                    bottomNavigationView
                }
                .transition(.opacity)
            }
            
        }
        .animation(.easeInOut, value: viewModel.isLoading)
        .onChange(of: currentPageIndex) { oldValue, newValue in
            // Haptic feedback on page turn
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            // Log completion on last page
            if newValue == viewModel.story.pages.count - 1 && newValue > oldValue {
                viewModel.markAsCompleted()
            }
        }
    }
    
    private var bottomNavigationView: some View {
        VStack(spacing: 0) {
            // Page Navigation - Premium floating bar
            HStack(spacing: 20) {
                // Previous button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        if currentPageIndex > 0 { currentPageIndex -= 1 }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(currentPageIndex == 0 ? Color.gray.opacity(0.1) : Color.white)
                            .frame(width: 44, height: 44)
                            .shadow(color: Color(red: 0.545, green: 0.361, blue: 0.965).opacity(currentPageIndex == 0 ? 0 : 0.15), radius: 6, x: 0, y: 3)
                        
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(currentPageIndex == 0 ? Color.gray.opacity(0.4) : Color(red: 0.545, green: 0.361, blue: 0.965))
                    }
                }
                .disabled(currentPageIndex == 0)
                .buttonStyle(ScaleButtonStyle())
                
                Spacer()
                
                // Page indicator - pill style
                if !viewModel.story.pages.isEmpty {
                    HStack(spacing: 8) {
                        Text("\(currentPageIndex + 1)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.545, green: 0.361, blue: 0.965))
                        
                        Text("/")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(red: 0.545, green: 0.361, blue: 0.965).opacity(0.5))
                        
                        Text("\(viewModel.story.pages.count)")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(Color(red: 0.545, green: 0.361, blue: 0.965).opacity(0.6))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.9))
                            .shadow(color: Color(red: 0.545, green: 0.361, blue: 0.965).opacity(0.1), radius: 4, x: 0, y: 2)
                    )
                }
                
                Spacer()
                
                // Next button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        if currentPageIndex < viewModel.story.pages.count - 1 { currentPageIndex += 1 }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(currentPageIndex == viewModel.story.pages.count - 1 ? Color.gray.opacity(0.1) : Color.white)
                            .frame(width: 44, height: 44)
                            .shadow(color: Color(red: 0.545, green: 0.361, blue: 0.965).opacity(currentPageIndex == viewModel.story.pages.count - 1 ? 0 : 0.15), radius: 6, x: 0, y: 3)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(currentPageIndex == viewModel.story.pages.count - 1 ? Color.gray.opacity(0.4) : Color(red: 0.545, green: 0.361, blue: 0.965))
                    }
                }
                .disabled(currentPageIndex == viewModel.story.pages.count - 1)
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.976, green: 0.965, blue: 0.988).opacity(0.95))
                    .shadow(color: Color(red: 0.545, green: 0.361, blue: 0.965).opacity(0.08), radius: 8, x: 0, y: -2)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .background(Color(red: 0.976, green: 0.965, blue: 0.988))
    }
}

private struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color(red: 0.545, green: 0.361, blue: 0.965))
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - UIKit Page Curl Wrapper (Modified)

// This wrapper is now simplified to accept an array of pre-built `AnyView`s.
struct PageCurlReaderView: UIViewControllerRepresentable {
    let pages: [AnyView]
    @Binding var currentIndex: Int
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIPageViewController {
        let controller = UIPageViewController(
            transitionStyle: .pageCurl,
            navigationOrientation: .horizontal,
            options: nil
        )
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        controller.isDoubleSided = false
        controller.view.backgroundColor = .white
        
        // Build controllers from the AnyView array
        context.coordinator.controllers = pages.map { UIHostingController(rootView: $0) }
        
        if let first = context.coordinator.controllers[safe: currentIndex] {
            controller.setViewControllers([first], direction: .forward, animated: false)
        }
        return controller
    }
    
    func updateUIViewController(_ vc: UIPageViewController, context: Context) {
        let target = context.coordinator.controllers[safe: currentIndex]
        let visible = vc.viewControllers?.first
        if let target, target !== visible {
            let visibleIndex = context.coordinator.controllers.firstIndex(where: { $0 === visible }) ?? 0
            let direction: UIPageViewController.NavigationDirection = (currentIndex >= visibleIndex) ? .forward : .reverse
            vc.setViewControllers([target], direction: direction, animated: true)
        }
    }
    
    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: PageCurlReaderView
        var controllers: [UIViewController] = []
        
        init(_ parent: PageCurlReaderView) {
            self.parent = parent
        }
        
        func pageViewController(_ vc: UIPageViewController, viewControllerBefore vcBefore: UIViewController) -> UIViewController? {
            guard let index = controllers.firstIndex(of: vcBefore), index > 0 else { return nil }
            return controllers[index - 1]
        }
        
        func pageViewController(_ vc: UIPageViewController, viewControllerAfter vcAfter: UIViewController) -> UIViewController? {
            guard let index = controllers.firstIndex(of: vcAfter), index < controllers.count - 1 else { return nil }
            return controllers[index + 1]
        }
        
        func pageViewController(_ vc: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            guard completed, let visible = vc.viewControllers?.first, let newIndex = controllers.firstIndex(of: visible) else { return }
            if parent.currentIndex != newIndex {
                parent.currentIndex = newIndex
            }
        }
    }
}

// MARK: - Safe Array Extension
private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

// MARK: - Preview
#Preview {
    ReadingModeView(viewModel: StoryReaderViewModel(story: Story.mockStory))
}

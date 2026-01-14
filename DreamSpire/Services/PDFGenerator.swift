//
//  PDFGenerator.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025-12-31.
//

import Foundation
import UIKit
import PDFKit
import SwiftUI

class PDFGenerator {
    static let shared = PDFGenerator()

    private init() {}

    /// Generate a PDF from a story with optional cover and illustrations
    /// - Parameters:
    ///   - story: The story to convert to PDF
    ///   - includeCover: Whether to include cover image as first page (default: true)
    ///   - includeIllustrations: Whether to include illustrations for illustrated stories (default: true)
    /// - Returns: PDF data that can be shared
    func generatePDF(for story: Story, includeCover: Bool = true, includeIllustrations: Bool = true) async throws -> Data {
        DWLogger.shared.info("📄 Generating PDF for story: \(story.title)", category: .general)

        // Pre-download all images asynchronously for better performance
        var coverImage: UIImage?
        var illustrationImages: [Int: UIImage] = [:]

        // Download cover image if needed
        if includeCover, let coverUrl = story.coverImageUrl {
            DWLogger.shared.debug("📥 Downloading cover image...", category: .general)
            coverImage = await downloadImage(from: coverUrl)
        }

        // Download illustration images if needed
        if includeIllustrations, let illustrations = story.illustrations {
            DWLogger.shared.debug("📥 Downloading \(illustrations.count) illustrations...", category: .general)
            await withTaskGroup(of: (Int, UIImage?).self) { group in
                for illustration in illustrations {
                    group.addTask {
                        let image = await self.downloadImage(from: illustration.imageUrl)
                        return (illustration.pageNumber, image)
                    }
                }

                for await (pageNumber, image) in group {
                    if let image = image {
                        illustrationImages[pageNumber] = image
                    }
                }
            }
            DWLogger.shared.debug("✅ Downloaded \(illustrationImages.count) illustrations", category: .general)
        }

        let pdfMetaData = [
            kCGPDFContextTitle: story.title,
            kCGPDFContextAuthor: "DreamSpire",
            kCGPDFContextCreator: "DreamSpire App"
        ] as [String: Any]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData

        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 size in points
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            // Add cover page if available and requested
            if includeCover, let coverUrl = story.coverImageUrl {
                context.beginPage()
                drawCoverPage(context: context, pageRect: pageRect, story: story, coverImage: coverImage)
            }

            // Add story pages
            for (index, page) in story.pages.enumerated() {
                context.beginPage()

                // Check if this page has an illustration
                let illustration = story.isIllustrated && includeIllustrations
                    ? story.illustrations?.first(where: { $0.pageNumber == page.pageNumber })
                    : nil

                if let illustration = illustration {
                    // Draw page with illustration (use pre-downloaded image)
                    let illustrationImage = illustrationImages[page.pageNumber]
                    drawPageWithIllustration(
                        context: context,
                        pageRect: pageRect,
                        page: page,
                        illustration: illustration,
                        illustrationImage: illustrationImage,
                        pageIndex: index,
                        totalPages: story.pages.count
                    )
                } else {
                    // Draw text-only page
                    drawTextPage(
                        context: context,
                        pageRect: pageRect,
                        page: page,
                        pageIndex: index,
                        totalPages: story.pages.count,
                        storyTitle: story.title
                    )
                }
            }
        }

        DWLogger.shared.info("✅ PDF generated successfully (\(data.count) bytes)", category: .general)
        return data
    }

    // MARK: - Image Download Helper

    private func downloadImage(from urlString: String) async -> UIImage? {
        guard let url = URL(string: urlString) else {
            DWLogger.shared.warning("❌ Invalid image URL: \(urlString)", category: .general)
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else {
                DWLogger.shared.warning("❌ Failed to decode image from: \(urlString)", category: .general)
                return nil
            }
            DWLogger.shared.debug("✅ Downloaded image from: \(urlString)", category: .general)
            return image
        } catch {
            DWLogger.shared.error("❌ Failed to download image", error: error, category: .general)
            return nil
        }
    }

    // MARK: - Cover Page Drawing

    private func drawCoverPage(context: UIGraphicsPDFRendererContext, pageRect: CGRect, story: Story, coverImage: UIImage?) {
        // Elegant gradient background - soft purple to pink
        let colors = [
            UIColor(red: 0.95, green: 0.94, blue: 0.98, alpha: 1.0), // Very light purple
            UIColor(red: 0.98, green: 0.95, blue: 0.97, alpha: 1.0)  // Very light pink
        ]
        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors.map { $0.cgColor } as CFArray,
            locations: [0.0, 1.0]
        ) {
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: pageRect.midX, y: pageRect.minY),
                end: CGPoint(x: pageRect.midX, y: pageRect.maxY),
                options: []
            )
        }

        // Decorative top border
        context.cgContext.setFillColor(UIColor(red: 0.6, green: 0.4, blue: 1.0, alpha: 0.15).cgColor)
        context.cgContext.fill(CGRect(x: 0, y: 0, width: pageRect.width, height: 8))

        // Draw cover image with rounded corners if available
        if let coverImage = coverImage {
            let imageHeight: CGFloat = 420
            let imageWidth: CGFloat = pageRect.width * 0.75
            let imageRect = CGRect(
                x: (pageRect.width - imageWidth) / 2,
                y: 80,
                width: imageWidth,
                height: imageHeight
            )

            // Add strong shadow for depth
            context.cgContext.saveGState()
            context.cgContext.setShadow(
                offset: CGSize(width: 0, height: 8),
                blur: 20,
                color: UIColor.black.withAlphaComponent(0.25).cgColor
            )

            // Draw with rounded corners
            let path = UIBezierPath(roundedRect: imageRect, cornerRadius: 16)
            context.cgContext.addPath(path.cgPath)
            context.cgContext.clip()
            coverImage.draw(in: imageRect)
            context.cgContext.restoreGState()
        }

        // Draw decorative line above title
        let lineY: CGFloat = 520
        context.cgContext.setStrokeColor(UIColor(red: 0.6, green: 0.4, blue: 1.0, alpha: 0.3).cgColor)
        context.cgContext.setLineWidth(2)
        context.cgContext.move(to: CGPoint(x: pageRect.width * 0.3, y: lineY))
        context.cgContext.addLine(to: CGPoint(x: pageRect.width * 0.7, y: lineY))
        context.cgContext.strokePath()

        // Draw title with elegant styling
        let titleY = 540.0
        let titleRect = CGRect(x: 40, y: titleY, width: pageRect.width - 80, height: 100)

        let titleStyle = NSMutableParagraphStyle()
        titleStyle.alignment = .center
        titleStyle.lineBreakMode = .byWordWrapping

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 32, weight: .bold),
            .foregroundColor: UIColor(hex: "#2C1F3D"),
            .paragraphStyle: titleStyle
        ]

        story.title.draw(in: titleRect, withAttributes: titleAttributes)

        // Draw category/genre badge
        if let category = story.metadata?.genre ?? story.category.nilIfEmpty {
            let categoryY = titleY + 80
            let categoryText = category.uppercased()
            
            let categoryFont = UIFont.systemFont(ofSize: 11, weight: .semibold)
            let categorySize = categoryText.size(withAttributes: [.font: categoryFont])

            let badgePaddingH: CGFloat = 20
            let badgePaddingV: CGFloat = 8
            let badgeWidth = categorySize.width + (badgePaddingH * 2)
            let badgeHeight = categorySize.height + (badgePaddingV * 2)
            
            let badgeRect = CGRect(
                x: (pageRect.width - badgeWidth) / 2,
                y: categoryY,
                width: badgeWidth,
                height: badgeHeight
            )

            // Draw badge background with subtle gradient effect
            let badgePath = UIBezierPath(roundedRect: badgeRect, cornerRadius: badgeHeight / 2)
            context.cgContext.setFillColor(UIColor(red: 0.6, green: 0.4, blue: 1.0, alpha: 0.1).cgColor)
            context.cgContext.addPath(badgePath.cgPath)
            context.cgContext.fillPath()

            // Draw badge border
            context.cgContext.setStrokeColor(UIColor(red: 0.6, green: 0.4, blue: 1.0, alpha: 0.25).cgColor)
            context.cgContext.setLineWidth(1)
            context.cgContext.addPath(badgePath.cgPath)
            context.cgContext.strokePath()

            // Draw category text - properly centered
            let textRect = CGRect(
                x: badgeRect.origin.x,
                y: badgeRect.origin.y + badgePaddingV,
                width: badgeRect.width,
                height: categorySize.height
            )
            
            let categoryStyle = NSMutableParagraphStyle()
            categoryStyle.alignment = .center

            let categoryAttributes: [NSAttributedString.Key: Any] = [
                .font: categoryFont,
                .foregroundColor: UIColor(red: 0.45, green: 0.25, blue: 0.85, alpha: 1.0),
                .paragraphStyle: categoryStyle,
                .kern: 1.5
            ]

            categoryText.draw(in: textRect, withAttributes: categoryAttributes)
        }

        // Draw decorative bottom elements
        let footerY = pageRect.height - 130

        // Story stats (page count & reading time)
        let statsY = footerY - 10
        let statsStyle = NSMutableParagraphStyle()
        statsStyle.alignment = .center
        
        let pagesLabel = "pdf_cover_pages".localized
        let minutesLabel = "pdf_cover_minutes".localized
        let statsText = "📖 \(story.pages.count) \(pagesLabel)  •  ⏱ \(story.roundedMinutes) \(minutesLabel)"
        let statsRect = CGRect(x: 50, y: statsY, width: pageRect.width - 100, height: 24)
        let statsAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: UIColor(red: 0.4, green: 0.35, blue: 0.5, alpha: 0.7),
            .paragraphStyle: statsStyle
        ]
        statsText.draw(in: statsRect, withAttributes: statsAttributes)

        // Decorative separator
        let separatorY = footerY + 25
        context.cgContext.setStrokeColor(UIColor(red: 0.6, green: 0.4, blue: 1.0, alpha: 0.2).cgColor)
        context.cgContext.setLineWidth(1)
        context.cgContext.move(to: CGPoint(x: pageRect.width * 0.35, y: separatorY))
        context.cgContext.addLine(to: CGPoint(x: pageRect.width * 0.65, y: separatorY))
        context.cgContext.strokePath()

        // Footer text with icon
        let footerRect = CGRect(x: 50, y: separatorY + 15, width: pageRect.width - 100, height: 50)

        let footerStyle = NSMutableParagraphStyle()
        footerStyle.alignment = .center
        footerStyle.lineSpacing = 4

        // Main footer text
        let footerMainAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: UIColor(red: 0.5, green: 0.3, blue: 0.9, alpha: 0.8),
            .paragraphStyle: footerStyle,
            .kern: 0.5
        ]

        "pdf_cover_created_by".localized.draw(in: footerRect, withAttributes: footerMainAttributes)

        // Small tagline
        let taglineRect = CGRect(x: 50, y: separatorY + 35, width: pageRect.width - 100, height: 20)
        let taglineAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .regular),
            .foregroundColor: UIColor(red: 0.5, green: 0.3, blue: 0.9, alpha: 0.5),
            .paragraphStyle: footerStyle
        ]

        "pdf_cover_tagline".localized.draw(in: taglineRect, withAttributes: taglineAttributes)
        
        // Add watermark to cover page
        drawWatermark(context: context, pageRect: pageRect)
    }

    // MARK: - Text Page Drawing

    private func drawTextPage(
        context: UIGraphicsPDFRendererContext,
        pageRect: CGRect,
        page: StoryPage,
        pageIndex: Int,
        totalPages: Int,
        storyTitle: String
    ) {
        // Background
        UIColor(hex: "#F8F4F0").setFill()
        context.fill(pageRect)

        // Decorative corner elements
        drawDecorativeCorners(context: context, pageRect: pageRect)

        // Draw header with story title
        let headerRect = CGRect(x: 50, y: 40, width: pageRect.width - 100, height: 30)
        let headerStyle = NSMutableParagraphStyle()
        headerStyle.alignment = .center

        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: UIColor(hex: "#8B7355").withAlphaComponent(0.6),
            .paragraphStyle: headerStyle,
            .kern: 0.5
        ]

        storyTitle.draw(in: headerRect, withAttributes: headerAttributes)

        // Draw decorative separator
        drawDecorativeSeparator(context: context, pageRect: pageRect, y: 75)

        // Prepare text attributes
        let textStyle = NSMutableParagraphStyle()
        textStyle.alignment = .left
        textStyle.lineSpacing = 10
        textStyle.firstLineHeadIndent = 20

        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15, weight: .regular),
            .foregroundColor: UIColor(hex: "#2C2416"),
            .paragraphStyle: textStyle
        ]

        // Split text into paragraphs
        let paragraphs = page.text.components(separatedBy: "\n\n")
        let hasMultipleParagraphs = paragraphs.count > 1

        if hasMultipleParagraphs {
            // Draw with paragraph separators
            var currentY: CGFloat = 95
            let paragraphSpacing: CGFloat = 18

            for (index, paragraph) in paragraphs.enumerated() {
                guard !paragraph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

                let paragraphRect = CGRect(
                    x: 60,
                    y: currentY,
                    width: pageRect.width - 120,
                    height: pageRect.height - currentY - 80
                )

                let paragraphHeight = paragraph.boundingRect(
                    with: CGSize(width: paragraphRect.width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: textAttributes,
                    context: nil
                ).height

                paragraph.draw(in: paragraphRect, withAttributes: textAttributes)

                currentY += paragraphHeight + paragraphSpacing

                // Draw subtle separator between paragraphs
                if index < paragraphs.count - 1 && currentY < pageRect.height - 100 {
                    drawParagraphSeparator(context: context, pageRect: pageRect, y: currentY - paragraphSpacing / 2)
                }
            }
            
            // Add decorative footer if page has lots of empty space
            if currentY < pageRect.height - 250 {
                drawDecorativeFooter(context: context, pageRect: pageRect, bottomY: pageRect.height - 100)
            }
        } else {
            // Single paragraph - draw normally
            let textRect = CGRect(x: 60, y: 95, width: pageRect.width - 120, height: pageRect.height - 175)
            let drawnHeight = page.text.boundingRect(
                with: CGSize(width: textRect.width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: textAttributes,
                context: nil
            ).height
            
            page.text.draw(in: textRect, withAttributes: textAttributes)
            
            // Add decorative footer if page has lots of empty space
            if drawnHeight < pageRect.height - 350 {
                drawDecorativeFooter(context: context, pageRect: pageRect, bottomY: pageRect.height - 100)
            }
        }

        // Draw page number with background
        drawPageNumber(
            context: context,
            pageRect: pageRect,
            pageIndex: pageIndex,
            totalPages: totalPages
        )
    }

    // MARK: - Page with Illustration Drawing

    private func drawPageWithIllustration(
        context: UIGraphicsPDFRendererContext,
        pageRect: CGRect,
        page: StoryPage,
        illustration: Illustration,
        illustrationImage: UIImage?,
        pageIndex: Int,
        totalPages: Int
    ) {
        // Background with subtle texture
        UIColor(hex: "#F8F4F0").setFill()
        context.fill(pageRect)

        // Decorative corner elements (subtle)
        drawDecorativeCorners(context: context, pageRect: pageRect)

        // Calculate text height to determine layout
        let textStyle = NSMutableParagraphStyle()
        textStyle.alignment = .left
        textStyle.lineSpacing = 8
        textStyle.firstLineHeadIndent = 20

        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .regular),
            .foregroundColor: UIColor(hex: "#2C2416"),
            .paragraphStyle: textStyle
        ]

        // Split text into paragraphs for better formatting
        let paragraphs = page.text.components(separatedBy: "\n\n")
        let hasMultipleParagraphs = paragraphs.count > 1

        // Estimate text height
        let estimatedTextHeight = estimateTextHeight(
            text: page.text,
            width: pageRect.width - 120,
            attributes: textAttributes
        )

        // Draw illustration if available
        var illustrationHeight: CGFloat = 0
        let illustrationTopMargin: CGFloat = 50

        if let image = illustrationImage {
            // Calculate image dimensions respecting aspect ratio
            let maxWidth = pageRect.width - 140  // Slightly narrower than text
            let maxHeight: CGFloat = estimatedTextHeight > 400 ? 280 : 340
            
            let imageAspectRatio = image.size.width / image.size.height
            var imageWidth: CGFloat
            var imageHeight: CGFloat
            
            // Fit image within max bounds while preserving aspect ratio
            if imageAspectRatio > 1 {
                // Landscape or square - limit by width
                imageWidth = min(maxWidth, image.size.width)
                imageHeight = imageWidth / imageAspectRatio
                
                // Check if height exceeds limit
                if imageHeight > maxHeight {
                    imageHeight = maxHeight
                    imageWidth = imageHeight * imageAspectRatio
                }
            } else {
                // Portrait - limit by height
                imageHeight = min(maxHeight, image.size.height)
                imageWidth = imageHeight * imageAspectRatio
                
                // Check if width exceeds limit
                if imageWidth > maxWidth {
                    imageWidth = maxWidth
                    imageHeight = imageWidth / imageAspectRatio
                }
            }
            
            illustrationHeight = imageHeight
            
            // Center the image horizontally
            let imageX = (pageRect.width - imageWidth) / 2
            
            let imageRect = CGRect(
                x: imageX,
                y: illustrationTopMargin,
                width: imageWidth,
                height: imageHeight
            )

            // Draw decorative frame around image
            context.cgContext.saveGState()

            // Shadow
            context.cgContext.setShadow(
                offset: CGSize(width: 0, height: 4),
                blur: 12,
                color: UIColor.black.withAlphaComponent(0.12).cgColor
            )

            // Rounded rectangle clip path
            let cornerRadius: CGFloat = 12
            let path = UIBezierPath(roundedRect: imageRect, cornerRadius: cornerRadius)
            context.cgContext.addPath(path.cgPath)
            context.cgContext.clip()

            // Draw image
            image.draw(in: imageRect)
            context.cgContext.restoreGState()

            // Subtle border around image
            context.cgContext.setStrokeColor(UIColor(hex: "#D4C4B0").withAlphaComponent(0.4).cgColor)
            context.cgContext.setLineWidth(1.5)
            context.cgContext.addPath(UIBezierPath(roundedRect: imageRect, cornerRadius: cornerRadius).cgPath)
            context.cgContext.strokePath()
        }

        // Decorative separator between image and text
        let separatorY = illustrationTopMargin + illustrationHeight + 20
        drawDecorativeSeparator(context: context, pageRect: pageRect, y: separatorY)

        // Draw text below illustration with paragraph spacing
        let textY = separatorY + 20
        let textRect = CGRect(
            x: 60,
            y: textY,
            width: pageRect.width - 120,
            height: pageRect.height - textY - 70
        )

        if hasMultipleParagraphs {
            // Draw with paragraph separators
            var currentY = textY
            let paragraphSpacing: CGFloat = 16

            for (index, paragraph) in paragraphs.enumerated() {
                guard !paragraph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

                let paragraphRect = CGRect(
                    x: 60,
                    y: currentY,
                    width: pageRect.width - 120,
                    height: pageRect.height - currentY - 70
                )

                let paragraphHeight = paragraph.boundingRect(
                    with: CGSize(width: paragraphRect.width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: textAttributes,
                    context: nil
                ).height

                paragraph.draw(in: paragraphRect, withAttributes: textAttributes)

                currentY += paragraphHeight + paragraphSpacing

                // Draw subtle separator between paragraphs (except last)
                if index < paragraphs.count - 1 && currentY < pageRect.height - 100 {
                    drawParagraphSeparator(context: context, pageRect: pageRect, y: currentY - paragraphSpacing / 2)
                }
            }
        } else {
            // Single paragraph - draw normally
            page.text.draw(in: textRect, withAttributes: textAttributes)
        }

        // Draw page number with subtle background
        drawPageNumber(
            context: context,
            pageRect: pageRect,
            pageIndex: pageIndex,
            totalPages: totalPages
        )
    }

    // MARK: - Helper Drawing Methods

    private func drawDecorativeCorners(context: UIGraphicsPDFRendererContext, pageRect: CGRect) {
        // Subtle corner decorations
        let cornerSize: CGFloat = 30
        let cornerColor = UIColor(hex: "#D4C4B0").withAlphaComponent(0.15)

        context.cgContext.setStrokeColor(cornerColor.cgColor)
        context.cgContext.setLineWidth(1)

        // Top left
        context.cgContext.move(to: CGPoint(x: 40, y: 40 + cornerSize))
        context.cgContext.addLine(to: CGPoint(x: 40, y: 40))
        context.cgContext.addLine(to: CGPoint(x: 40 + cornerSize, y: 40))
        context.cgContext.strokePath()

        // Top right
        context.cgContext.move(to: CGPoint(x: pageRect.width - 40 - cornerSize, y: 40))
        context.cgContext.addLine(to: CGPoint(x: pageRect.width - 40, y: 40))
        context.cgContext.addLine(to: CGPoint(x: pageRect.width - 40, y: 40 + cornerSize))
        context.cgContext.strokePath()
    }

    private func drawDecorativeSeparator(context: UIGraphicsPDFRendererContext, pageRect: CGRect, y: CGFloat) {
        let centerX = pageRect.width / 2
        let lineLength: CGFloat = 60

        // Main line - thinner
        context.cgContext.setStrokeColor(UIColor(hex: "#D4C4B0").withAlphaComponent(0.25).cgColor)
        context.cgContext.setLineWidth(0.5)
        context.cgContext.move(to: CGPoint(x: centerX - lineLength, y: y))
        context.cgContext.addLine(to: CGPoint(x: centerX + lineLength, y: y))
        context.cgContext.strokePath()

        // Center ornament - smaller
        context.cgContext.setFillColor(UIColor(hex: "#8B7355").withAlphaComponent(0.15).cgColor)
        context.cgContext.fillEllipse(in: CGRect(x: centerX - 2, y: y - 2, width: 4, height: 4))
    }

    private func drawParagraphSeparator(context: UIGraphicsPDFRendererContext, pageRect: CGRect, y: CGFloat) {
        // Three small dots as paragraph separator (like in app)
        let dotSize: CGFloat = 2
        let spacing: CGFloat = 6
        let centerX = pageRect.width / 2

        context.cgContext.setFillColor(UIColor(hex: "#8B7355").withAlphaComponent(0.3).cgColor)

        for i in -1...1 {
            let x = centerX + CGFloat(i) * (dotSize + spacing)
            context.cgContext.fillEllipse(in: CGRect(x: x - dotSize/2, y: y - dotSize/2, width: dotSize, height: dotSize))
        }
    }
    
    private func drawDecorativeFooter(context: UIGraphicsPDFRendererContext, pageRect: CGRect, bottomY: CGFloat) {
        let centerX = pageRect.width / 2
        
        // Draw elegant ornamental divider
        let dividerY = bottomY - 40
        
        // Center star/flower ornament
        let ornamentSize: CGFloat = 8
        context.cgContext.setFillColor(UIColor(hex: "#8B7355").withAlphaComponent(0.15).cgColor)
        
        // Draw diamond shape
        let diamondPath = UIBezierPath()
        diamondPath.move(to: CGPoint(x: centerX, y: dividerY - ornamentSize/2))
        diamondPath.addLine(to: CGPoint(x: centerX + ornamentSize/2, y: dividerY))
        diamondPath.addLine(to: CGPoint(x: centerX, y: dividerY + ornamentSize/2))
        diamondPath.addLine(to: CGPoint(x: centerX - ornamentSize/2, y: dividerY))
        diamondPath.close()
        context.cgContext.addPath(diamondPath.cgPath)
        context.cgContext.fillPath()
        
        // Side lines
        let lineLength: CGFloat = 80
        let lineOffset: CGFloat = 15
        context.cgContext.setStrokeColor(UIColor(hex: "#D4C4B0").withAlphaComponent(0.2).cgColor)
        context.cgContext.setLineWidth(0.5)
        
        // Left line
        context.cgContext.move(to: CGPoint(x: centerX - lineOffset, y: dividerY))
        context.cgContext.addLine(to: CGPoint(x: centerX - lineOffset - lineLength, y: dividerY))
        context.cgContext.strokePath()
        
        // Right line
        context.cgContext.move(to: CGPoint(x: centerX + lineOffset, y: dividerY))
        context.cgContext.addLine(to: CGPoint(x: centerX + lineOffset + lineLength, y: dividerY))
        context.cgContext.strokePath()
        
        // Small dots at line ends
        let dotSize: CGFloat = 2
        context.cgContext.setFillColor(UIColor(hex: "#8B7355").withAlphaComponent(0.2).cgColor)
        context.cgContext.fillEllipse(in: CGRect(
            x: centerX - lineOffset - lineLength - dotSize/2,
            y: dividerY - dotSize/2,
            width: dotSize,
            height: dotSize
        ))
        context.cgContext.fillEllipse(in: CGRect(
            x: centerX + lineOffset + lineLength - dotSize/2,
            y: dividerY - dotSize/2,
            width: dotSize,
            height: dotSize
        ))
    }

    private func drawPageNumber(context: UIGraphicsPDFRendererContext, pageRect: CGRect, pageIndex: Int, totalPages: Int) {
        let pageNumberText = "\(pageIndex + 1) / \(totalPages)"
        let pageNumberY = pageRect.height - 45

        let pageNumberStyle = NSMutableParagraphStyle()
        pageNumberStyle.alignment = .center

        let pageNumberAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: UIColor(hex: "#8B7355").withAlphaComponent(0.6),
            .paragraphStyle: pageNumberStyle
        ]

        // Background for page number
        let textSize = pageNumberText.size(withAttributes: pageNumberAttributes)
        let badgeRect = CGRect(
            x: (pageRect.width - textSize.width - 20) / 2,
            y: pageNumberY - 6,
            width: textSize.width + 20,
            height: textSize.height + 12
        )

        context.cgContext.setFillColor(UIColor.white.withAlphaComponent(0.5).cgColor)
        context.cgContext.addPath(UIBezierPath(roundedRect: badgeRect, cornerRadius: 10).cgPath)
        context.cgContext.fillPath()

        context.cgContext.setStrokeColor(UIColor(hex: "#D4C4B0").withAlphaComponent(0.3).cgColor)
        context.cgContext.setLineWidth(1)
        context.cgContext.addPath(UIBezierPath(roundedRect: badgeRect, cornerRadius: 10).cgPath)
        context.cgContext.strokePath()

        let pageNumberRect = CGRect(x: 50, y: pageNumberY, width: pageRect.width - 100, height: 30)
        pageNumberText.draw(in: pageNumberRect, withAttributes: pageNumberAttributes)
        
        // Draw app icon and "DreamSpire" watermark in bottom right corner
        drawWatermark(context: context, pageRect: pageRect)
    }
    
    private func drawWatermark(context: UIGraphicsPDFRendererContext, pageRect: CGRect) {
        let iconSize: CGFloat = 18
        let spacing: CGFloat = 4
        let rightMargin: CGFloat = 50
        let pillPaddingH: CGFloat = 10
        let pillPaddingV: CGFloat = 6
        
        // Load DreamSpire icon
        let appIcon = UIImage(named: "DreamSpireIcon") ?? UIImage(systemName: "sparkles")
        
        // Text setup
        let dreamSpireText = "DreamSpire"
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: UIColor(hex: "#5A4A3A").withAlphaComponent(0.85)
        ]
        
        let textSize = dreamSpireText.size(withAttributes: textAttributes)
        
        // Calculate pill dimensions
        let contentWidth = iconSize + spacing + textSize.width
        let pillWidth = contentWidth + (pillPaddingH * 2)
        let pillHeight = max(iconSize, textSize.height) + (pillPaddingV * 2)
        
        // Align with page number position (pageRect.height - 45)
        let pageNumberY = pageRect.height - 45
        let pillX = pageRect.width - rightMargin - pillWidth
        let pillY = pageNumberY - 6
        
        let pillRect = CGRect(x: pillX, y: pillY, width: pillWidth, height: pillHeight)
        
        // Draw pill background with shadow
        context.cgContext.saveGState()
        
        let pillPath = UIBezierPath(roundedRect: pillRect, cornerRadius: pillHeight / 2)
        
        // Add shadow
        context.cgContext.setShadow(
            offset: CGSize(width: 0, height: 2),
            blur: 6,
            color: UIColor.black.withAlphaComponent(0.12).cgColor
        )
        
        // Background fill with slight purple tint
        context.cgContext.setFillColor(UIColor(red: 0.98, green: 0.97, blue: 0.99, alpha: 0.85).cgColor)
        context.cgContext.addPath(pillPath.cgPath)
        context.cgContext.fillPath()
        
        context.cgContext.restoreGState()
        
        // Border (without shadow)
        context.cgContext.setStrokeColor(UIColor(hex: "#C4B4A0").withAlphaComponent(0.5).cgColor)
        context.cgContext.setLineWidth(1.2)
        context.cgContext.addPath(pillPath.cgPath)
        context.cgContext.strokePath()
        
        // Calculate content positions inside pill
        let contentStartX = pillX + pillPaddingH
        let contentCenterY = pillY + (pillHeight / 2)
        
        // Draw app icon with rounded corners
        if let icon = appIcon {
            let iconRect = CGRect(
                x: contentStartX,
                y: contentCenterY - (iconSize / 2),
                width: iconSize,
                height: iconSize
            )
            
            context.cgContext.saveGState()
            
            // Clip to rounded rect for icon
            let iconPath = UIBezierPath(roundedRect: iconRect, cornerRadius: iconSize * 0.22)
            context.cgContext.addPath(iconPath.cgPath)
            context.cgContext.clip()
            
            icon.draw(in: iconRect)
            context.cgContext.restoreGState()
        }
        
        // Draw "DreamSpire" text
        let textRect = CGRect(
            x: contentStartX + iconSize + spacing,
            y: contentCenterY - (textSize.height / 2),
            width: textSize.width,
            height: textSize.height
        )
        dreamSpireText.draw(in: textRect, withAttributes: textAttributes)
    }

    private func estimateTextHeight(text: String, width: CGFloat, attributes: [NSAttributedString.Key: Any]) -> CGFloat {
        let boundingRect = text.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        return boundingRect.height
    }
}

// MARK: - Helper Extensions

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

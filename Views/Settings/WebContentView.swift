//
//  WebContentView.swift
//  DreamSpire
//
//  Professional web content viewer for Terms, Privacy, etc.
//  Uses identical gradient background on iOS and HTML for seamless appearance
//

import SwiftUI
import WebKit

struct WebContentView: View {
    @Environment(\.dismiss) var dismiss
    let url: String
    let title: String
    
    // Exact gradient colors matching iOS dwBackground
    private let gradientTop = Color(red: 26/255, green: 19/255, blue: 64/255)     // #1A1340
    private let gradientBottom = Color(red: 10/255, green: 10/255, blue: 18/255)  // #0A0A12

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Solid matching gradient - same as HTML
            LinearGradient(
                colors: [gradientTop, gradientBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if let url = URL(string: url) {
                WebView(url: url)
                    .ignoresSafeArea()
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.yellow)

                    Text("web_content_failed".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Floating Close Button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white.opacity(0.9))
                    .background(Circle().fill(Color.black.opacity(0.4)))
                    .padding(20)
            }
        }
    }
}

struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        
        // CRITICAL: Transparent background so iOS gradient shows through
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.backgroundColor = .clear
        
        // Clean appearance
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        
        // Allow bouncing - now safe because HTML bg is transparent
        webView.scrollView.bounces = true
        webView.scrollView.alwaysBounceVertical = true
        
        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

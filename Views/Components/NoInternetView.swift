//
//  NoInternetView.swift
//  DreamSpire
//
//  Full-screen view shown when there's no internet connection
//

import SwiftUI

struct NoInternetView: View {
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            // Background gradient (matches app theme)
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.15, green: 0.15, blue: 0.25)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 120, height: 120)

                    Image(systemName: "wifi.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.6))
                }

                // Title
                Text("no_internet_title".localized)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                // Message
                Text("no_internet_message".localized)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()

                // Retry Button
                Button(action: onRetry) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                        Text("retry".localized)
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.blue.opacity(0.8),
                                Color.blue
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NoInternetView(onRetry: {
        print("Retry tapped")
    })
}

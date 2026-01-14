//
//  DWTabBar.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//

import SwiftUI

// MARK: - Tab Model

enum DWTab: String, CaseIterable {
    case home
    case create
    case library
    case settings
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .create: return "plus.circle.fill"
        case .library: return "books.vertical.fill"
        case .settings: return "gearshape.fill"
        }
    }
    
    var title: String {
        switch self {
        case .home: return "tab_home".localized
        case .create: return "tab_create".localized
        case .library: return "tab_library".localized
        case .settings: return "tab_settings".localized
        }
    }
}

// MARK: - DWTabBar

struct DWTabBar: View {
    @Binding var selectedTab: DWTab
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(DWTab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color(red: 0.3, green: 0.25, blue: 0.5).opacity(0.95))
                .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: -3)
        )
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private func tabButton(for tab: DWTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            ZStack {
                // BÜYÜK CAM CIRCLE - Sadece seçili tabda
                if selectedTab == tab {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.25, green: 0.22, blue: 0.45).opacity(0.8),
                                    Color(red: 0.35, green: 0.28, blue: 0.55).opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 70)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    Color.white.opacity(0.2),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                        .offset(y: -25)
                        .matchedGeometryEffect(id: "tab_background", in: animation)
                }
                
                // Icon - Smooth animation added
                Image(systemName: tab.icon)
                    .font(.system(size: selectedTab == tab ? 28 : 24, weight: .medium))
                    .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.6))
                    .offset(y: selectedTab == tab ? -25 : 0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTab)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LinearGradient.dwBackground
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            DWTabBar(selectedTab: .constant(.home))
        }
    }
}

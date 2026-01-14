//
//  ConfettiEffect.swift
//  DreamSpire
//
//  Reusable confetti particle effect for celebrations
//

import SwiftUI

struct ConfettiEffect: View {
    @Binding var show: Bool
    
    var body: some View {
        ZStack {
            if show {
                // Center fall
                ForEach(0..<20) { index in
                    ConfettiPiece(index: index, show: show, type: .top)
                }
                
                // Left burst
                ForEach(0..<15) { index in
                    ConfettiPiece(index: index, show: show, type: .left)
                }
                
                // Right burst
                ForEach(0..<15) { index in
                    ConfettiPiece(index: index, show: show, type: .right)
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: show) { oldValue, newValue in
            if newValue {
                // Auto hide after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    show = false
                }
            }
        }
    }
}

struct ConfettiPiece: View {
    let index: Int
    let show: Bool
    let type: ConfettiType
    
    enum ConfettiType {
        case top, left, right
    }
    
    @State private var position: CGPoint = CGPoint(x: 200, y: 0)
    @State private var opacity: Double = 1.0
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    
    private let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .pink, .orange, .cyan]
    
    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(colors[index % colors.count])
                .frame(width: CGFloat.random(in: 6...12), height: CGFloat.random(in: 6...12))
                .rotationEffect(.degrees(rotation))
                .scaleEffect(scale)
                .position(position)
                .opacity(opacity)
                .onAppear {
                    let width = geometry.size.width
                    let height = geometry.size.height
                    
                    switch type {
                    case .top:
                        position = CGPoint(x: CGFloat.random(in: 0...width), y: -20)
                        withAnimation(.easeOut(duration: Double.random(in: 2.0...3.0))) {
                            position = CGPoint(x: position.x + CGFloat.random(in: -100...100), y: height + 50)
                            rotation = Double.random(in: 360...720)
                            opacity = 0
                            scale = 0.5
                        }
                    case .left:
                        position = CGPoint(x: -20, y: height * 0.7)
                        withAnimation(.interpolatingSpring(stiffness: 50, damping: 10).delay(Double.random(in: 0...0.3))) {
                            position = CGPoint(x: width * CGFloat.random(in: 0.2...0.8), y: height * CGFloat.random(in: 0.1...0.5))
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation(.easeIn(duration: 1.5)) {
                                position.y = height + 50
                                position.x += CGFloat.random(in: 20...100)
                                opacity = 0
                            }
                        }
                    case .right:
                        position = CGPoint(x: width + 20, y: height * 0.7)
                        withAnimation(.interpolatingSpring(stiffness: 50, damping: 10).delay(Double.random(in: 0...0.3))) {
                            position = CGPoint(x: width * CGFloat.random(in: 0.2...0.8), y: height * CGFloat.random(in: 0.1...0.5))
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation(.easeIn(duration: 1.5)) {
                                position.y = height + 50
                                position.x -= CGFloat.random(in: 20...100)
                                opacity = 0
                            }
                        }
                    }
                    
                    withAnimation(.linear(duration: 2.0)) {
                        rotation = Double.random(in: 360...1080)
                    }
                }
        }
    }
}

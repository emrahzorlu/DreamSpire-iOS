import SwiftUI

struct StoryPlaceholderView: View {
    let size: PlaceholderSize
    
    init(size: PlaceholderSize = .medium) {
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Soft gradient background - consistent across app
            LinearGradient(
                colors: [
                    Color(red: 0.6, green: 0.5, blue: 0.9).opacity(0.8),
                    Color(red: 0.5, green: 0.6, blue: 0.95).opacity(0.7)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Book icon only - clean and minimal
            Image(systemName: "book.fill")
                .font(.system(size: size.iconSize, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius))
    }
}

// MARK: - Placeholder Size Configuration

enum PlaceholderSize {
    case small, medium, large
    
    var iconSize: CGFloat {
        switch self {
        case .small: return 24
        case .medium: return 36
        case .large: return 50
        }
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .small: return 8
        case .medium: return 12
        case .large: return 16
        }
    }
}

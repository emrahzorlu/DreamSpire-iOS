# DreamSpire iOS

AI-powered children's story creation app for iOS. Create personalized bedtime stories with custom characters, illustrations, and narration.

![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![iOS](https://img.shields.io/badge/iOS-16.0+-blue)
![SwiftUI](https://img.shields.io/badge/SwiftUI-4.0-purple)

## Features

- **AI Story Generation** - Create unique stories based on child's ideas
- **Custom Characters** - Build and save personalized characters
- **Multiple Languages** - English, Turkish, German, French, Spanish
- **Age-Appropriate** - Content tailored for 4-12 year olds
- **Audio Narration** - Listen to stories with AI-generated voices
- **PDF Export** - Save and share stories as illustrated PDFs
- **Subscription Tiers** - Free, Plus, and Pro options

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                        Views                             │
│  (SwiftUI Views with custom ViewModifiers)              │
├─────────────────────────────────────────────────────────┤
│                     ViewModels                           │
│  (@MainActor, @Published, Combine)                      │
├─────────────────────────────────────────────────────────┤
│                    Repositories                          │
│  (Caching, Data management)                             │
├─────────────────────────────────────────────────────────┤
│                      Services                            │
│  (API, Auth, StoreKit, PDF generation)                  │
├─────────────────────────────────────────────────────────┤
│                     Protocols                            │
│  (Dependency injection, Testing support)                │
└─────────────────────────────────────────────────────────┘
```

## Tech Stack

| Category | Technology |
|----------|------------|
| **UI Framework** | SwiftUI 4.0 |
| **Architecture** | MVVM + Repository |
| **Networking** | URLSession, async/await |
| **Authentication** | Firebase Auth, Apple Sign In |
| **Payments** | StoreKit 2 |
| **Analytics** | Firebase Analytics |
| **Push Notifications** | FCM |
| **PDF Generation** | PDFKit |

## Project Structure

```
DreamSpire/
├── Core/
│   ├── DI/              # Dependency injection
│   ├── Errors/          # Typed error handling
│   ├── Modifiers/       # Custom ViewModifiers
│   ├── Protocols/       # Service protocols
│   ├── Extensions/      # Swift extensions
│   └── Managers/        # App managers
├── Models/              # Data models
├── ViewModels/          # MVVM view models
├── Views/
│   ├── Home/
│   ├── StoryCreation/
│   ├── StoryReader/
│   ├── Library/
│   ├── Characters/
│   ├── Settings/
│   └── Components/      # Reusable UI components
├── Services/            # API, Auth, StoreKit
├── Repositories/        # Data layer with caching
└── Resources/           # Fonts, assets
```

## Key Components

### Dependency Injection
```swift
// Protocol-based services for testability
@MainActor
final class Container {
    static let shared = Container()
    
    lazy var apiClient: APIClientProtocol = APIClient.shared
    lazy var authManager: AuthManagerProtocol = AuthManager.shared
}
```

### Custom ViewModifiers
```swift
// Reusable styling
Text("Title")
    .titleStyle()

Button("Continue") { }
    .primaryButtonStyle()

view
    .glassCard()
    .shimmer()
```

### Accessibility
```swift
// VoiceOver support
Button(action: { }) {
    Image(systemName: "heart.fill")
}
.accessibleButton("Add to favorites")
```

## Requirements

- iOS 16.0+
- Xcode 15.0+
- Swift 5.9+

## Setup

1. Clone the repository
2. Open `DreamSpire.xcodeproj`
3. Add your `GoogleService-Info.plist` for Firebase
4. Build and run

## Author

**Emrah Zorlu**

## License

This project is proprietary software. All rights reserved.

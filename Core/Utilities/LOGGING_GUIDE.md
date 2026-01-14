# 📝 DreamWeaver Logging System

## Genel Bakış

DreamWeaver, kapsamlı bir loglama sistemi içerir. Tüm önemli olaylar, API çağrıları, hatalar ve kullanıcı etkileşimleri otomatik olarak loglanır.

## Log Kategorileri

### 🌐 Network
Tüm HTTP istekleri ve yanıtları
```swift
DWLogger.shared.logNetworkRequest(url: url, method: "POST", headers: headers, body: data)
DWLogger.shared.logNetworkResponse(url: url, statusCode: 200, data: data, duration: 2.5)
```

### 📡 API
API çağrıları ve sonuçları
```swift
DWLogger.shared.logAPICall(endpoint: "/api/stories/create", parameters: params)
DWLogger.shared.logAPISuccess(endpoint: "/api/stories/create", duration: 3.2)
DWLogger.shared.logAPIError(endpoint: "/api/stories/create", error: error, duration: 1.5)
```

### 📖 Story
Hikaye oluşturma süreçleri
```swift
DWLogger.shared.logStoryCreationStart(prompt: "...", characters: 2)
DWLogger.shared.logStoryCreationProgress(stage: "Writing story...", progress: 0.5)
DWLogger.shared.logStoryCreationComplete(storyId: "story_123", duration: 45.0, pages: 8, isIllustrated: true)
```

### 🔐 Auth
Kimlik doğrulama olayları
```swift
DWLogger.shared.logAuthEvent("User Login", userId: "user_123", details: "Email login")
```

### 💎 Subscription
Abonelik değişiklikleri
```swift
DWLogger.shared.logSubscriptionEvent("Subscription Started", tier: .pro, details: [:])
```

### 📊 Analytics
Analitik olayları
```swift
DWLogger.shared.logAnalyticsEvent("story_created", parameters: ["tier": "pro"])
```

### 🎨 UI
Kullanıcı arayüzü olayları
```swift
DWLogger.shared.logViewAppear("HomeView")
DWLogger.shared.logViewDisappear("HomeView")
DWLogger.shared.logUserAction("Tapped Story Card", details: "Story ID: 123")
```

## Kısa Yollar

Global fonksiyonlar ile hızlı loglama:

```swift
logDebug("Debug mesajı", category: .general)
logInfo("Bilgi mesajı", category: .network)
logWarning("Uyarı mesajı", category: .api)
logError("Hata mesajı", error: someError, category: .error)
logCritical("Kritik hata!", error: criticalError, category: .error)
```

## Log Seviyeleri

```swift
DWLogger.shared.logLevel = .debug   // Tüm loglar
DWLogger.shared.logLevel = .info    // Info ve üzeri
DWLogger.shared.logLevel = .warning // Uyarı ve üzeri
DWLogger.shared.logLevel = .error   // Sadece hatalar
```

## Console'da Log Filtreleme

Xcode Console'da kategoriye göre filtreleme:

- `🌐 Network` - Network logları
- `📡 API` - API logları
- `📖 Story` - Hikaye logları
- `🔐 Auth` - Auth logları
- `💎 Subscription` - Abonelik logları
- `📊 Analytics` - Analitik logları
- `🎨 UI` - UI logları
- `❌ Error` - Hata logları

## Örnek Kullanım

### ViewModel'de Loglama

```swift
class StoryCreationViewModel: ObservableObject {
    func createStory() async {
        logInfo("Starting story creation", category: .story)
        
        DWLogger.shared.logStoryCreationStart(
            prompt: storyIdea,
            characters: characters.count
        )
        
        do {
            let story = try await apiClient.createStory(request: request)
            
            DWLogger.shared.logStoryCreationComplete(
                storyId: story.id,
                duration: duration,
                pages: story.pages.count,
                isIllustrated: story.isIllustrated
            )
            
            logInfo("Story created successfully: \(story.id)", category: .story)
            
        } catch {
            logError("Story creation failed", error: error, category: .story)
        }
    }
}
```

### View'da Loglama

```swift
struct HomeView: View {
    var body: some View {
        // ...
    }
    .onAppear {
        DWLogger.shared.logViewAppear("HomeView")
    }
    .onDisappear {
        DWLogger.shared.logViewDisappear("HomeView")
    }
}
```

### Button Tap Loglama

```swift
Button("Create Story") {
    DWLogger.shared.logUserAction("Tapped Create Story Button")
    createStory()
}
```

## Log Formatı

### Network Request
```
┌─────────────────────────────────────────────────────
│ 📤 OUTGOING REQUEST
├─────────────────────────────────────────────────────
│ Method: POST
│ URL: https://api.example.com/stories/create
├─────────────────────────────────────────────────────
│ Headers:
│   Content-Type: application/json
│   Authorization: Bearer ***
├─────────────────────────────────────────────────────
│ Body Size: 256 bytes
│ Body (JSON):
{"prompt":"...","characters":[...]}
└─────────────────────────────────────────────────────
```

### Network Response
```
┌─────────────────────────────────────────────────────
│ ✅ INCOMING RESPONSE
├─────────────────────────────────────────────────────
│ URL: https://api.example.com/stories/create
│ Status Code: 200
│ Duration: 2.45s
│ Response Size: 1024 bytes
├─────────────────────────────────────────────────────
│ Response (JSON):
{"id":"story_123","title":"..."}
└─────────────────────────────────────────────────────
```

### Story Creation Progress
```
│ 🎬 STORY PROGRESS: Writing story...
│ [██████████░░░░░░░░░░] 50%
```

## Production'da Loglama

Production build'de log seviyesi otomatik olarak `.info`'ya ayarlanır:

```swift
#if DEBUG
DWLogger.shared.logLevel = .debug
#else
DWLogger.shared.logLevel = .info
#endif
```

## Hassas Bilgilerin Maskelenmesi

Authorization header'ları otomatik olarak maskelenir:
```
│ Authorization: Bearer ***
```

## Best Practices

1. **Her önemli işlemi logla**
   - API çağrıları
   - Kullanıcı eylemleri
   - Hata durumları
   - Kritik state değişiklikleri

2. **Doğru kategoriyi kullan**
   - Network işlemleri için `.network`
   - API çağrıları için `.api`
   - UI olayları için `.ui`
   - Hatalar için `.error`

3. **Context ekle**
   ```swift
   logError("Story creation failed", error: error, category: .story)
   // Yerine:
   logError("Story creation failed for user \(userId), story ID: \(storyId)", 
            error: error, category: .story)
   ```

4. **Progress logla**
   - Uzun işlemler için progress logları
   - Kullanıcıya görsel feedback için

5. **Hassas bilgileri loglama**
   - Şifreler
   - Token'lar (maskelenmediyse)
   - Kişisel veriler

## Test

ContentView'da test butonları var:
- Test API Call
- Test Story Creation
- Test Auth Event
- Test Subscription
- Test Error

Her butona basarak loglama sistemini test edebilirsin!

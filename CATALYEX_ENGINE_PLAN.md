# Catalyex Download Engine Implementation Plan

## 🎯 Overview
**Catalyex** will be a new download engine that sits alongside the existing engines (Recooma, Gallery-dl, Cyberdrop) while maintaining compatibility with the legacy download system architecture.

## 📁 Architecture Analysis

### Current Engine Structure:
```
Legacy Download System:
├── main.dart (UI + Engine Selection)
├── RecoomaEngine (view-models/Recooma_engine.dart)
│   └── CybCrawl (downloader/coomercrawl.dart) ❌ NOT connected to ScraperManager
├── GalleryDlEngine (downloader/external/gallery_dl_engine.dart)
└── CyberDropEngine (downloader/external/cyberdrop_dl_engine.dart)

Unified System (Parallel):
├── DownloadManager (services/download_manager.dart)
├── ScraperManager (scrapers/ScraperManager.dart) ✅ Connected to scrapers
└── EventBus (services/event_bus.dart)
```

### Key Finding:
- **CybCrawl is NOT connected to ScraperManager** - it's a standalone legacy component
- **RecoomaEngine** calls CybCrawl directly via `CybCrawl.getFileContent()`
- **Settings integration** happens in main.dart with `settingMap['eng']` selection

## 🏗️ Catalyex Engine Implementation Plan

### Phase 1: Core Engine Structure
```
lib/
├── view-models/
│   └── Catalyex_engine.dart          // Main engine class (follows RecoomaEngine pattern)
├── downloader/
│   └── catalyex_core.dart            // Core download logic (follows CybCrawl pattern) 
├── crawlers/
│   └── catalyex_crawler.dart         // Specialized crawling logic
└── services/
    └── catalyex_config.dart          // Engine configuration & settings
```

### Phase 2: Engine Features & Capabilities

#### Core Features:
1. **Multi-threaded Downloads** - Advanced parallel processing
2. **Smart Site Detection** - Intelligent URL pattern recognition  
3. **Adaptive Retry Logic** - Progressive backoff with circuit breaker
4. **Performance Monitoring** - Real-time metrics and optimization
5. **Memory Management** - Efficient resource utilization
6. **Content Validation** - File integrity verification

#### Advanced Capabilities:
1. **AI-Powered Crawling** - Machine learning for content discovery
2. **Dynamic Load Balancing** - Automatic thread optimization
3. **Bandwidth Management** - Intelligent speed control
4. **Content Classification** - Automatic media type detection
5. **Deduplication Engine** - Advanced duplicate detection
6. **Cloud Integration** - Optional cloud storage support

### Phase 3: Integration Points

#### A. Settings Integration (main.dart)
```dart
// Add Catalyex to engine selection
if (settingMap['eng'] == 3) {  // New engine ID
  await CatalyexEngineDownload(downloaded, total);
} else if (settingMap['eng'] == 0) {
  await RecoomaEngineDownload(downloaded, total);
}
```

#### B. Settings UI (settingsPage.dart)
```dart
// Add Catalyex option to engine dropdown
DropdownMenuItem(
  value: 3,
  child: Row(
    children: [
      Icon(Icons.rocket_launch, color: Colors.purple),
      SizedBox(width: 8),
      Text('Catalyex Engine'),
    ],
  ),
),
```

#### C. Download Task Integration
```dart
// Use existing DownloadTaskServices pattern
class CatalyexTaskService {
  static Future<void> startDownload(
    DownloadTask task,
    Isar isar,
    StreamSink singleComplete,
    StreamSink SendLogs,
    int type,
  ) async {
    // Bridge to CatalyexCore
  }
}
```

### Phase 4: File Structure Details

#### 1. **CatalyexEngine** (view-models/Catalyex_engine.dart)
```dart
class CatalyexEngine {
  Future<void> download({
    required String url,
    required String directory,
    required BuildContext context,
    required Map settingMap,
    required Box historyBox,
    // ... other parameters matching RecoomaEngine signature
  }) async {
    // Main engine orchestration
    // Calls CatalyexCore.processContent()
  }
}
```

#### 2. **CatalyexCore** (downloader/catalyex_core.dart)
```dart
class CatalyexCore {
  static Future<void> processContent({
    required String url,
    required String directory,
    required int downloadID,
    required Isar isar,
    // ... parameters matching CybCrawl.getFileContent signature
  }) async {
    // Core download processing
    // Isolate communication via IsolateNameServer
    // Progress reporting to main thread
  }
}
```

#### 3. **CatalyexCrawler** (crawlers/catalyex_crawler.dart)
```dart
class CatalyexCrawler {
  static Future<Map<String, dynamic>> crawlSite(String url) async {
    // Advanced crawling logic
    // AI-powered content discovery
    // Return standardized format compatible with existing system
  }
}
```

#### 4. **CatalyexConfig** (services/catalyex_config.dart)
```dart
class CatalyexConfig {
  static const String ENGINE_NAME = 'Catalyex';
  static const int ENGINE_ID = 3;
  
  // Configuration options
  static const int DEFAULT_THREADS = 8;
  static const int MAX_RETRIES = 5;
  static const Duration RETRY_DELAY = Duration(seconds: 2);
  
  // Performance tuning
  static Map<String, dynamic> getOptimizedSettings(String url) {
    // Return optimized settings based on URL/site
  }
}
```

### Phase 5: Legacy System Integration

#### Communication Flow:
```
User selects Catalyex in Settings
        ↓
main.dart detects settingMap['eng'] == 3
        ↓
CatalyexEngineDownload() called
        ↓
CatalyexEngine.download() orchestrates
        ↓
CatalyexCore.processContent() executes
        ↓
IsolateNameServer messaging to main thread
        ↓
DownloadWidget receives updates via existing streams
```

#### Key Integration Points:
1. **Isolate Communication** - Use existing `IsolateNameServer.lookupPortByName("single")`
2. **Database Updates** - Update `DownloadTask` objects in Isar
3. **Progress Reporting** - Send status via existing `downloadLogListner.sink`
4. **Error Handling** - Use existing snackbar notification system
5. **File Management** - Follow existing folder structure patterns

### Phase 6: Advanced Features

#### A. Performance Monitoring
```dart
class CatalyexMetrics {
  static void trackDownloadSpeed(int downloadId, double bytesPerSecond);
  static void trackCrawlingEfficiency(String site, Duration time);
  static void trackErrorRates(String site, int errors, int total);
  static Map<String, dynamic> getPerformanceReport();
}
```

#### B. Smart Site Optimization
```dart
class CatalyexOptimizer {
  static Future<Map<String, dynamic>> analyzesite(String url);
  static int calculateOptimalThreads(String site);
  static Duration predictDownloadTime(List<String> urls);
  static Map<String, String> getOptimizedHeaders(String site);
}
```

#### C. AI-Powered Features
```dart
class CatalyexAI {
  static Future<List<String>> predictAdditionalContent(String url);
  static bool isContentDuplicate(String url, String filename);
  static String classifyContentType(String url, Map headers);
  static double calculateContentQuality(String url);
}
```

### Phase 7: Implementation Steps

#### Step 1: Basic Engine Structure
1. Create `Catalyex_engine.dart` with basic download method
2. Create `catalyex_core.dart` with simple content processing
3. Add engine option to settings (ID: 3)
4. Test basic integration with existing UI

#### Step 2: Core Functionality
1. Implement isolate-based downloading
2. Add progress reporting via existing streams
3. Integrate with Isar database updates
4. Test with simple URLs

#### Step 3: Advanced Crawling
1. Create `catalyex_crawler.dart` with site-specific logic
2. Add support for major sites (coomer, kemono, erome)
3. Implement content discovery algorithms
4. Add deduplication logic

#### Step 4: Performance Features
1. Add multi-threading with dynamic optimization
2. Implement adaptive retry logic
3. Add bandwidth management
4. Create performance monitoring dashboard

#### Step 5: AI Integration
1. Add machine learning for content prediction
2. Implement intelligent site analysis
3. Create quality scoring system
4. Add automatic optimization

### Phase 8: Testing Strategy

#### Unit Tests:
- CatalyexCore download functions
- CatalyexCrawler site parsing
- CatalyexConfig optimization logic

#### Integration Tests:
- Settings UI integration
- Database operations
- Stream communication
- Error handling

#### Performance Tests:
- Multi-threaded download efficiency
- Memory usage optimization
- Speed comparison with existing engines

### Phase 9: Documentation

#### User Documentation:
- Engine feature comparison
- Configuration options
- Troubleshooting guide

#### Developer Documentation:
- Architecture overview
- API reference
- Extension guidelines

## 🚀 Key Advantages of Catalyex

1. **Modern Architecture** - Built with performance and scalability in mind
2. **Legacy Compatibility** - Seamless integration with existing UI/database
3. **AI-Enhanced** - Machine learning for intelligent downloading
4. **Performance Focused** - Advanced optimization and monitoring
5. **Extensible Design** - Easy to add new sites and features
6. **User-Friendly** - Minimal configuration required

## 📋 Implementation Checklist

- [ ] Create basic engine structure
- [ ] Implement core download logic
- [ ] Add settings integration
- [ ] Create crawler component
- [ ] Add performance monitoring
- [ ] Implement AI features
- [ ] Write comprehensive tests
- [ ] Create user documentation
- [ ] Performance optimization
- [ ] Beta testing with real users

## 🎯 Success Metrics

1. **Performance**: 20%+ faster than existing engines
2. **Efficiency**: 15%+ better resource utilization  
3. **Reliability**: 95%+ success rate on supported sites
4. **User Experience**: Seamless integration with existing UI
5. **Extensibility**: Easy addition of new site support

---

**Note**: This plan maintains full compatibility with the existing legacy system while providing a pathway for future enhancements and modern features.

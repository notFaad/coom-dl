# 🚀 Community Scraper Development Guide

Welcome to the CoomDL Community Scraper System! This guide will help you create your own scrapers for any website you want to support.

## 📋 Table of Contents
- [Quick Start](#quick-start)
- [Architecture Overview](#architecture-overview)
- [Creating Your First Scraper](#creating-your-first-scraper)
- [Advanced Features](#advanced-features)
- [Testing & Debugging](#testing--debugging)
- [Sharing Your Scraper](#sharing-your-scraper)
- [API Reference](#api-reference)

## 🏃‍♂️ Quick Start

1. **Create your scraper:** Add a new file in `lib/scrapers/builtin/`
2. **Update scraper info:** Change ID, name, author, etc.
3. **Define URL patterns:** Specify which URLs your scraper handles
4. **Implement scraping logic:** Add your site-specific code
5. **Test thoroughly:** Ensure it works with various URLs
6. **Submit Pull Request:** Contribute back to the project

## 🏗️ Architecture Overview

```
ScraperManager
├── ScraperRegistry (manages all scrapers)
├── BaseScraper (abstract class all scrapers inherit from)
└── Built-in Scrapers (coomer, kemono, erome, fapello, community PRs)
```

### Core Components

- **BaseScraper**: Abstract class defining the scraper interface
- **ScraperRegistry**: Manages registration and discovery of scrapers
- **ScraperManager**: Integrates scrapers with the download system
- **ScrapingRequest/Result**: Standardized data structures

## 🛠️ Creating Your First Scraper

### Step 1: Create Your Scraper File

```bash
# Create a new scraper file
touch lib/scrapers/builtin/MySiteScraper.dart
```

### Step 2: Update Basic Info

```dart
class MySiteScraper extends BaseScraper {
  @override
  String get scraperId => 'mysite';  // Unique ID
  
  @override
  String get displayName => 'My Site Scraper';
  
  @override
  String get author => 'YourUsername';  // Your GitHub/Discord username
  
  @override
  String get description => 'Downloads content from mysite.com';
}
```

### Step 3: Define URL Patterns

```dart
@override
List<String> get supportedUrlPatterns => [
  r'^https://mysite\.com/user/\w+$',        // User profiles
  r'^https://mysite\.com/post/\d+$',        // Individual posts
  r'^https://mysite\.com/gallery/\w+$',     // Galleries
];
```

### Step 4: Implement Scraping Logic

```dart
@override
Future<ScrapingResult> scrape(ScrapingRequest request) async {
  final downloadItems = <DownloadItem>[];
  
  // Make HTTP request
  final response = await _makeRequest(request.url);
  final document = parser.parse(response.body);
  
  // Find images
  final images = document.querySelectorAll('img.content');
  for (final img in images) {
    final src = img.attributes['src'];
    if (src != null) {
      downloadItems.add(DownloadItem(
        downloadName: _extractFileName(src),
        link: _makeAbsoluteUrl(src),
        mimeType: 'image',
      ));
    }
  }
  
  // Return results
  return ScrapingResult(
    creatorName: extractCreatorName(request.url),
    folderName: 'Downloaded Content',
    downloadItems: downloadItems,
    // ... other fields
  );
}
```

## 🎯 Advanced Features

### 🔐 Authentication & Headers

```dart
@override
Map<String, String> getCustomHeaders(String url) {
  return {
    'User-Agent': 'Mozilla/5.0 (compatible; CoomDL)',
    'Referer': 'https://mysite.com/',
    'Authorization': 'Bearer ${_config['api_token']}',
  };
}
```

### ⏱️ Rate Limiting

```dart
@override
int getRateLimitDelay(String url) {
  // Return delay in milliseconds
  return 1000; // 1 second delay between requests
}
```

### 🔄 Pagination Support

```dart
Future<void> _scrapePaginated(ScrapingRequest request, List<DownloadItem> items) async {
  String? nextPageUrl = request.url;
  
  while (nextPageUrl != null && !request.shouldCancel()) {
    final response = await _makeRequest(nextPageUrl);
    final document = parser.parse(response.body);
    
    // Extract items from current page
    _extractItemsFromPage(document, items);
    
    // Find next page URL
    nextPageUrl = _findNextPageUrl(document);
    
    // Rate limiting
    await Future.delayed(Duration(milliseconds: getRateLimitDelay(nextPageUrl ?? '')));
  }
}
```

### 🍪 Cookie Management

```dart
class MySiteScraper extends BaseScraper {
  http.Client? _client;
  
  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    _client = http.Client();
    // Set up cookie jar, authentication, etc.
  }
  
  @override
  Future<void> dispose() async {
    _client?.close();
  }
}
```

## 🧪 Testing & Debugging

### Test URLs
Create a test file with various URLs:

```dart
void main() {
  final scraper = MySiteScraper();
  
  final testUrls = [
    'https://mysite.com/user/testuser',
    'https://mysite.com/post/12345',
    'https://mysite.com/gallery/testgallery',
  ];
  
  for (final url in testUrls) {
    assert(scraper.canHandle(url), 'Should handle: $url');
  }
}
```

### Debug Logging
Use the onLog callback for debugging:

```dart
request.onLog('DEBUG: Found ${images.length} images');
request.onLog('DEBUG: Processing URL: $currentUrl');
```

### Progress Reporting
Keep users informed with progress updates:

```dart
request.onProgress(ScrapingProgress(
  phase: 'fetching',
  currentUrl: currentUrl,
  totalItems: totalItems,
  processedItems: processedItems,
  statusMessage: 'Processing page ${pageNum}/${totalPages}',
));
```

## 🚀 Sharing Your Scraper

### 1. Code Quality Checklist
- [ ] Follows naming conventions
- [ ] Includes error handling
- [ ] Has proper rate limiting
- [ ] Respects robots.txt
- [ ] Includes comments/documentation

### 2. Testing Checklist
- [ ] Tests with various URL patterns
- [ ] Handles empty results gracefully
- [ ] Handles network errors
- [ ] Doesn't crash on malformed HTML
- [ ] Respects cancellation requests

### 3. Submission Methods

#### GitHub Pull Request
1. Fork the repository
2. Add your scraper to `lib/scrapers/community/`
3. Update the scraper registry
4. Submit pull request

#### Discord/Community
1. Join the CoomDL Discord server
2. Share your scraper in #scraper-sharing
3. Include test URLs and screenshots

## 📚 API Reference

### BaseScraper Abstract Class

#### Required Properties
```dart
String get scraperId;           // Unique identifier
String get displayName;         // Human-readable name
String get version;             // Scraper version
String get author;              // Your username
String get description;         // What it does
List<String> get supportedUrlPatterns; // Regex patterns
Set<ScraperCapability> get capabilities; // What it can do
```

#### Required Methods
```dart
Future<void> initialize(Map<String, dynamic> config);
Future<ScrapingResult> scrape(ScrapingRequest request);
String extractCreatorName(String url);
ContentType getContentType(String url);
```

#### Optional Methods
```dart
Map<String, String> getCustomHeaders(String url);
int getRateLimitDelay(String url);
Future<void> dispose();
```

### ScrapingRequest Object
```dart
final String url;                           // URL to scrape
final Map<String, dynamic> config;         // Configuration
final Function(ScrapingProgress) onProgress; // Progress callback
final Function(String) onLog;              // Logging callback
final bool Function() shouldCancel;        // Cancellation check
```

### ScrapingResult Object
```dart
final String creatorName;              // Extracted creator name
final String folderName;               // Folder for downloads
final List<DownloadItem> downloadItems; // Found items
final Map<String, dynamic> metadata;   // Extra info
final List<String> errors;             // Any errors
final ScrapingStats stats;             // Statistics
```

## 🎨 Scraper Capabilities

Define what your scraper can do:

```dart
Set<ScraperCapability> get capabilities => {
  ScraperCapability.images,        // Can download images
  ScraperCapability.videos,        // Can download videos
  ScraperCapability.pagination,    // Supports multiple pages
  ScraperCapability.authentication, // Requires login
  ScraperCapability.creatorScraping, // Can scrape creator profiles
  ScraperCapability.postScraping,  // Can scrape individual posts
  ScraperCapability.customHeaders, // Needs special headers
  ScraperCapability.javascript,    // Requires JS execution
};
```

## 🤝 Best Practices

### 1. Respect Websites
- Follow robots.txt
- Use reasonable rate limiting
- Don't overload servers
- Respect terms of service

### 2. Error Handling
```dart
try {
  final response = await _makeRequest(url);
  // Process response
} catch (e) {
  request.onLog('Error fetching $url: $e');
  errors.add('Failed to fetch: $e');
  // Continue with other URLs
}
```

### 3. User Experience
- Provide meaningful progress updates
- Log important information
- Handle cancellation gracefully
- Return partial results on errors

### 4. Performance
- Use connection pooling
- Implement proper timeouts
- Avoid memory leaks
- Cache when appropriate

## 🆘 Getting Help

### Discord Community
Join our Discord server for real-time help:
- #scraper-development
- #general-help
- #showcase

### GitHub Issues
For bugs or feature requests:
- Use issue templates
- Include test URLs
- Provide error logs

### Example Scrapers
Study existing scrapers for reference:
- `CoomerScraper.dart` - API-based scraping
- `EromeScraper.dart` - HTML parsing
- `FapelloScraper.dart` - JavaScript execution

## 🏆 Hall of Fame

### Top Community Contributors
- **@user1** - InstagramScraper (1000+ downloads)
- **@user2** - TwitterScraper (800+ downloads)
- **@user3** - RedditScraper (600+ downloads)

### Featured Scrapers
- **TikTokScraper** - Downloads TikTok content
- **PinterestScraper** - Pinterest board scraping
- **DeviantArtScraper** - DeviantArt gallery support

---

**Happy Scraping! 🎉**

*Remember: With great scraping power comes great responsibility. Always respect websites and their terms of service.*

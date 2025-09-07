import 'dart:async';
import '../../data/models/download.dart';

/// Base abstract class for all community scrapers
/// This provides a standardized interface that all scrapers must implement
abstract class BaseScraper {
  /// Unique identifier for this scraper (e.g., "coomer", "kemono", "custom_site")
  String get scraperId;

  /// Display name for this scraper
  String get displayName;

  /// Version of the scraper (for compatibility and updates)
  String get version;

  /// Author information
  String get author;

  /// Description of what this scraper does
  String get description;

  /// List of URL patterns this scraper can handle (regex patterns)
  List<String> get supportedUrlPatterns;

  /// Required configuration keys for this scraper
  List<String> get requiredConfigKeys;

  /// Optional configuration keys with default values
  Map<String, dynamic> get defaultConfig;

  /// Check if this scraper can handle the given URL
  bool canHandle(String url) {
    return supportedUrlPatterns.any((pattern) => RegExp(pattern).hasMatch(url));
  }

  /// Initialize the scraper with configuration
  Future<void> initialize(Map<String, dynamic> config);

  /// Main scraping method - this is what gets called to scrape content
  /// Returns a standardized ScrapingResult object
  Future<ScrapingResult> scrape(ScrapingRequest request);

  /// Validate configuration before scraping
  bool validateConfig(Map<String, dynamic> config) {
    for (String key in requiredConfigKeys) {
      if (!config.containsKey(key)) {
        return false;
      }
    }
    return true;
  }

  /// Get scraper capabilities/features
  Set<ScraperCapability> get capabilities;

  /// Custom headers needed for requests (anti-bot measures, etc.)
  Map<String, String> getCustomHeaders(String url) => {};

  /// Handle rate limiting - return delay in milliseconds
  int getRateLimitDelay(String url) => 500;

  /// Parse creator/folder name from URL
  String extractCreatorName(String url);

  /// Parse content type (post, album, creator, etc.)
  ContentType getContentType(String url);

  /// Cleanup method called when scraper is disposed
  Future<void> dispose() async {}
}

/// Enum for different scraper capabilities
enum ScraperCapability {
  images,
  videos,
  audio,
  documents,
  pagination,
  authentication,
  creatorScraping,
  postScraping,
  albumScraping,
  bulkDownload,
  customHeaders,
  javascript,
  cookies
}

/// Enum for content types
enum ContentType { creator, post, album, gallery, single, unknown }

/// Standardized request object
class ScrapingRequest {
  final String url;
  final Map<String, dynamic> config;
  final Map<String, String> customHeaders;
  final Function(ScrapingProgress) onProgress;
  final Function(String) onLog;
  final bool Function() shouldCancel;

  ScrapingRequest({
    required this.url,
    required this.config,
    this.customHeaders = const {},
    required this.onProgress,
    required this.onLog,
    required this.shouldCancel,
  });
}

/// Standardized result object
class ScrapingResult {
  final String creatorName;
  final String folderName;
  final List<DownloadItem> downloadItems;
  final Map<String, dynamic> metadata;
  final List<String> errors;
  final ScrapingStats stats;

  ScrapingResult({
    required this.creatorName,
    required this.folderName,
    required this.downloadItems,
    this.metadata = const {},
    this.errors = const [],
    required this.stats,
  });
}

/// Progress reporting
class ScrapingProgress {
  final String phase; // "connecting", "fetching", "parsing", "downloading"
  final String currentUrl;
  final int totalItems;
  final int processedItems;
  final String statusMessage;

  ScrapingProgress({
    required this.phase,
    required this.currentUrl,
    required this.totalItems,
    required this.processedItems,
    required this.statusMessage,
  });
}

/// Statistics tracking
class ScrapingStats {
  final int totalFound;
  final int images;
  final int videos;
  final int other;
  final int failed;
  final Duration scrapingTime;
  final List<String> skippedUrls;

  ScrapingStats({
    required this.totalFound,
    required this.images,
    required this.videos,
    required this.other,
    required this.failed,
    required this.scrapingTime,
    this.skippedUrls = const [],
  });
}

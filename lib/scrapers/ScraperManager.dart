import 'dart:async';
import 'package:isar/isar.dart';
import 'base/BaseScraper.dart';
import 'base/ScraperRegistry.dart';
import 'builtin/NeoCrawlerScraper.dart';
import 'builtin/ModernEromeScraper.dart';
import '../data/models/DlTask.dart';
import '../data/models/Link.dart';

/// Manager that integrates the scraper system with the existing download engine
class ScraperManager {
  static final ScraperManager _instance = ScraperManager._internal();
  factory ScraperManager() => _instance;
  ScraperManager._internal();

  final ScraperRegistry _registry = ScraperRegistry();

  /// Initialize the scraper manager and load all available scrapers
  Future<void> initialize() async {
    await _loadBuiltInScrapers();
    await _loadCommunityScrapers();

    // Validate all scrapers
    final issues = _registry.validateAllScrapers();
    if (issues.isNotEmpty) {
      print('Scraper validation issues found:');
      issues.forEach((scraperId, scraperIssues) {
        print('  $scraperId: ${scraperIssues.join(', ')}');
      });
    }

    print(
        'ScraperManager initialized with ${_registry.getAllScrapers().length} scrapers');
  }

  /// Load built-in scrapers (existing ones)
  Future<void> _loadBuiltInScrapers() async {
    print('Loading built-in scrapers...');

    // Register the neocrawler scraper for coomer/kemono sites
    final neoCrawlerScraper = NeoCrawlerScraper();
    _registry.registerScraper(neoCrawlerScraper);
    print('Registered NeoCrawlerScraper for coomer.st and kemono sites');

    // Register the modern Erome scraper
    final modernEromeScraper = ModernEromeScraper();
    _registry.registerScraper(modernEromeScraper);
    print('Registered ModernEromeScraper for erome.com sites');
  }

  /// Load community scrapers from plugins directory
  Future<void> _loadCommunityScrapers() async {
    const scrapersPath = 'lib/scrapers/community/';
    await _registry.loadScrapersFromDirectory(scrapersPath);
  }

  /// Check if a URL can be handled by any scraper
  bool canHandle(String url) {
    return _registry.findScraperForUrl(url) != null;
  }

  /// Get the best scraper for a URL
  BaseScraper? getScraperForUrl(String url) {
    return _registry.findScraperForUrl(url);
  }

  /// Get all scrapers that can handle a URL
  List<BaseScraper> getAllScrapersForUrl(String url) {
    return _registry.findAllScrapersForUrl(url);
  }

  /// Execute scraping with the best available scraper
  /// This integrates with the existing download task system
  Future<Map<String, dynamic>> executeScraping({
    required String url,
    required int downloadId,
    required Isar isar,
    required Function(Map<String, dynamic>) onProgress,
    required Function(String) onLog,
    required bool Function() shouldCancel,
    Map<String, dynamic> customConfig = const {},
  }) async {
    final scraper = getScraperForUrl(url);
    if (scraper == null) {
      throw Exception('No scraper found for URL: $url');
    }

    onLog(
        'Using scraper: ${scraper.displayName} v${scraper.version} by ${scraper.author}');

    // Initialize scraper with config
    await scraper.initialize(customConfig);

    // Create scraping request
    final request = ScrapingRequest(
      url: url,
      config: customConfig,
      onProgress: (progress) {
        onProgress({
          'phase': progress.phase,
          'current_url': progress.currentUrl,
          'total': progress.totalItems,
          'processed': progress.processedItems,
          'message': progress.statusMessage,
        });
      },
      onLog: onLog,
      shouldCancel: shouldCancel,
    );

    try {
      // Execute scraping
      final result = await scraper.scrape(request);

      // Convert to existing format for compatibility
      final compatibleResult = {
        'creator': result.creatorName,
        'folder': result.folderName,
        'downloads': result.downloadItems,
        'count': result.downloadItems.length,
        'metadata': result.metadata,
        'stats': {
          'total': result.stats.totalFound,
          'images': result.stats.images,
          'videos': result.stats.videos,
          'other': result.stats.other,
          'failed': result.stats.failed,
          'duration': result.stats.scrapingTime.inMilliseconds,
        },
        'errors': result.errors,
      };

      // Store results in database
      await _storeScrapingResults(downloadId, result, isar);

      onLog('Scraping completed: ${result.downloadItems.length} items found');

      return compatibleResult;
    } catch (e) {
      onLog('Scraping failed: $e');
      rethrow;
    } finally {
      await scraper.dispose();
    }
  }

  /// Store scraping results in the database (compatible with existing system)
  Future<void> _storeScrapingResults(
    int downloadId,
    ScrapingResult result,
    Isar isar,
  ) async {
    // Convert download items to Links
    final links = result.downloadItems
        .map((item) => Links()
          ..filename = item.downloadName
          ..url = item.link
          ..type = item.mimeType ?? 'unknown'
          ..isCompleted = false
          ..skipped = false
          ..isFailure = false)
        .toList();

    // Store in database
    await isar.writeTxn(() async {
      await isar.links.putAll(links);
    });

    // Update download task
    final task =
        await isar.downloadTasks.where().idEqualTo(downloadId).findFirst();

    if (task != null) {
      task.links.addAll(links);
      task.totalNum = result.downloadItems.length;
      task.name = result.folderName;

      await isar.writeTxn(() async {
        await task.links.save();
        await isar.downloadTasks.put(task);
      });
    }
  }

  /// Get list of all available scrapers for UI display
  List<ScraperInfo> getAvailableScrapers() {
    final metadata = _registry.getAllMetadata();
    return metadata
        .map((meta) => ScraperInfo(
              id: meta.id,
              displayName: meta.displayName,
              version: meta.version,
              author: meta.author,
              description: meta.description,
              supportedSites: _extractSiteNames(meta.supportedUrlPatterns),
              capabilities: meta.capabilities.toList(),
              isEnabled: meta.isEnabled,
            ))
        .toList();
  }

  /// Enable/disable a scraper
  void setScraperEnabled(String scraperId, bool enabled) {
    _registry.setScraperEnabled(scraperId, enabled);
  }

  /// Get scraper statistics
  ScraperManagerStats getStats() {
    final scrapers = _registry.getAllScrapers();
    final metadata = _registry.getAllMetadata();

    return ScraperManagerStats(
      totalScrapers: scrapers.length,
      enabledScrapers: metadata.where((m) => m.isEnabled).length,
      communityScrapers:
          scrapers.where((s) => !_isBuiltInScraper(s.scraperId)).length,
      supportedSites: _getAllSupportedSites(metadata),
    );
  }

  /// Register a new scraper (for community plugins)
  void registerScraper(BaseScraper scraper) {
    _registry.registerScraper(scraper);
  }

  /// Unregister a scraper
  void unregisterScraper(String scraperId) {
    _registry.unregisterScraper(scraperId);
  }

  // Helper methods

  List<String> _extractSiteNames(List<String> patterns) {
    return patterns
        .map((pattern) {
          // Extract domain names from regex patterns
          final domainMatch =
              RegExp(r'\\\.([a-zA-Z0-9-]+)\\\.').firstMatch(pattern);
          return domainMatch?.group(1) ?? 'unknown';
        })
        .toSet()
        .toList();
  }

  bool _isBuiltInScraper(String scraperId) {
    return ['coomer', 'kemono', 'erome', 'fapello'].contains(scraperId);
  }

  Set<String> _getAllSupportedSites(List<ScraperMetadata> metadata) {
    final sites = <String>{};
    for (final meta in metadata) {
      sites.addAll(_extractSiteNames(meta.supportedUrlPatterns));
    }
    return sites;
  }
}

/// Information about a scraper for UI display
class ScraperInfo {
  final String id;
  final String displayName;
  final String version;
  final String author;
  final String description;
  final List<String> supportedSites;
  final List<ScraperCapability> capabilities;
  final bool isEnabled;

  ScraperInfo({
    required this.id,
    required this.displayName,
    required this.version,
    required this.author,
    required this.description,
    required this.supportedSites,
    required this.capabilities,
    required this.isEnabled,
  });
}

/// Statistics about the scraper manager
class ScraperManagerStats {
  final int totalScrapers;
  final int enabledScrapers;
  final int communityScrapers;
  final Set<String> supportedSites;

  ScraperManagerStats({
    required this.totalScrapers,
    required this.enabledScrapers,
    required this.communityScrapers,
    required this.supportedSites,
  });
}

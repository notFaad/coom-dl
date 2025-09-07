import 'dart:io';
import 'BaseScraper.dart';

/// Central registry for managing all available scrapers
/// This allows for dynamic loading and discovery of community scrapers
class ScraperRegistry {
  static final ScraperRegistry _instance = ScraperRegistry._internal();
  factory ScraperRegistry() => _instance;
  ScraperRegistry._internal();

  final Map<String, BaseScraper> _scrapers = {};
  final Map<String, ScraperMetadata> _metadata = {};

  /// Register a scraper instance
  void registerScraper(BaseScraper scraper) {
    _scrapers[scraper.scraperId] = scraper;
    _metadata[scraper.scraperId] = ScraperMetadata(
      id: scraper.scraperId,
      displayName: scraper.displayName,
      version: scraper.version,
      author: scraper.author,
      description: scraper.description,
      supportedUrlPatterns: scraper.supportedUrlPatterns,
      capabilities: scraper.capabilities,
      isEnabled: true,
    );
  }

  /// Unregister a scraper
  void unregisterScraper(String scraperId) {
    _scrapers[scraperId]?.dispose();
    _scrapers.remove(scraperId);
    _metadata.remove(scraperId);
  }

  /// Get all registered scrapers
  List<BaseScraper> getAllScrapers() => _scrapers.values.toList();

  /// Get scraper by ID
  BaseScraper? getScraper(String scraperId) => _scrapers[scraperId];

  /// Find scraper that can handle a specific URL
  BaseScraper? findScraperForUrl(String url) {
    for (BaseScraper scraper in _scrapers.values) {
      if (scraper.canHandle(url)) {
        return scraper;
      }
    }
    return null;
  }

  /// Get all scrapers that can handle a URL (in case of multiple matches)
  List<BaseScraper> findAllScrapersForUrl(String url) {
    return _scrapers.values.where((scraper) => scraper.canHandle(url)).toList();
  }

  /// Get scraper metadata
  List<ScraperMetadata> getAllMetadata() => _metadata.values.toList();

  /// Enable/disable a scraper
  void setScraperEnabled(String scraperId, bool enabled) {
    if (_metadata.containsKey(scraperId)) {
      _metadata[scraperId]!.isEnabled = enabled;
    }
  }

  /// Check if scraper is enabled
  bool isScraperEnabled(String scraperId) {
    return _metadata[scraperId]?.isEnabled ?? false;
  }

  /// Load scrapers from a directory (for community plugins)
  Future<void> loadScrapersFromDirectory(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      print('Scrapers directory does not exist: $directoryPath');
      return;
    }

    await for (FileSystemEntity entity in directory.list()) {
      if (entity is File && entity.path.endsWith('.dart')) {
        try {
          await _loadScraperFromFile(entity.path);
        } catch (e) {
          print('Failed to load scraper from ${entity.path}: $e');
        }
      }
    }
  }

  /// Load a single scraper file
  Future<void> _loadScraperFromFile(String filePath) async {
    // This would need platform-specific implementation
    // For now, we'll use a registration-based approach
    print('Loading scraper from: $filePath');
  }

  /// Validate all scrapers
  Map<String, List<String>> validateAllScrapers() {
    Map<String, List<String>> issues = {};

    for (BaseScraper scraper in _scrapers.values) {
      List<String> scraperIssues = [];

      // Check required properties
      if (scraper.scraperId.isEmpty) {
        scraperIssues.add('Scraper ID cannot be empty');
      }

      if (scraper.supportedUrlPatterns.isEmpty) {
        scraperIssues.add('Must have at least one supported URL pattern');
      }

      // Validate URL patterns
      for (String pattern in scraper.supportedUrlPatterns) {
        try {
          RegExp(pattern);
        } catch (e) {
          scraperIssues.add('Invalid regex pattern: $pattern');
        }
      }

      if (scraperIssues.isNotEmpty) {
        issues[scraper.scraperId] = scraperIssues;
      }
    }

    return issues;
  }

  /// Get scrapers by capability
  List<BaseScraper> getScrapersByCapability(ScraperCapability capability) {
    return _scrapers.values
        .where((scraper) => scraper.capabilities.contains(capability))
        .toList();
  }

  /// Clear all scrapers (for testing)
  void clear() {
    for (BaseScraper scraper in _scrapers.values) {
      scraper.dispose();
    }
    _scrapers.clear();
    _metadata.clear();
  }
}

/// Metadata about a scraper
class ScraperMetadata {
  final String id;
  final String displayName;
  final String version;
  final String author;
  final String description;
  final List<String> supportedUrlPatterns;
  final Set<ScraperCapability> capabilities;
  bool isEnabled;

  ScraperMetadata({
    required this.id,
    required this.displayName,
    required this.version,
    required this.author,
    required this.description,
    required this.supportedUrlPatterns,
    required this.capabilities,
    this.isEnabled = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'version': version,
        'author': author,
        'description': description,
        'supportedUrlPatterns': supportedUrlPatterns,
        'capabilities': capabilities.map((c) => c.toString()).toList(),
        'isEnabled': isEnabled,
      };
}

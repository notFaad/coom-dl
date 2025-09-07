import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import '../../scrapers/base/BaseScraper.dart';
import '../../../data/models/download.dart';

/// Example community scraper template
/// Copy this file and modify it for your own site!
///
/// Steps to create your own scraper:
/// 1. Copy this file and rename it (e.g., MySiteScraper.dart)
/// 2. Update the class name and scraper information
/// 3. Modify supportedUrlPatterns to match your site
/// 4. Implement the scrape() method with your site's logic
/// 5. Register it in the ScraperManager
class ExampleCommunityScraper extends BaseScraper {
  // STEP 1: Update these with your scraper information
  @override
  String get scraperId => 'example_site'; // Unique ID for your scraper

  @override
  String get displayName => 'Example Site Scraper';

  @override
  String get version => '1.0.0';

  @override
  String get author => 'YourUsername'; // Put your username here!

  @override
  String get description => 'Downloads content from example.com';

  // STEP 2: Update URL patterns to match your target site
  @override
  List<String> get supportedUrlPatterns => [
        r'^((https:\/\/)|(https:\/\/www\.))?example\.com\/user\/\w+$',
        r'^((https:\/\/)|(https:\/\/www\.))?example\.com\/post\/\d+$',
        r'^((https:\/\/)|(https:\/\/www\.))?example\.com\/gallery\/\w+$',
      ];

  @override
  List<String> get requiredConfigKeys => [];

  @override
  Map<String, dynamic> get defaultConfig => {
        'delay_ms': 500,
        'max_retries': 3,
        'user_agent': 'Mozilla/5.0 (compatible; CoomDL/1.0)',
      };

  // STEP 3: Define what your scraper can do
  @override
  Set<ScraperCapability> get capabilities => {
        ScraperCapability.images,
        ScraperCapability.videos,
        ScraperCapability.pagination,
        ScraperCapability.creatorScraping,
        ScraperCapability.postScraping,
      };

  // Configuration storage
  Map<String, dynamic> _config = {};

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    _config = {...defaultConfig, ...config};
    print('ExampleScraper initialized with config: $_config');
  }

  // STEP 4: Implement the main scraping logic
  @override
  Future<ScrapingResult> scrape(ScrapingRequest request) async {
    final stopwatch = Stopwatch()..start();
    final List<DownloadItem> downloadItems = [];
    final List<String> errors = [];

    try {
      request.onProgress(ScrapingProgress(
        phase: 'connecting',
        currentUrl: request.url,
        totalItems: 0,
        processedItems: 0,
        statusMessage: 'Connecting to ${extractCreatorName(request.url)}...',
      ));

      final contentType = getContentType(request.url);
      final creatorName = extractCreatorName(request.url);

      switch (contentType) {
        case ContentType.creator:
          await _scrapeCreator(request, downloadItems, errors);
          break;
        case ContentType.post:
          await _scrapePost(request, downloadItems, errors);
          break;
        case ContentType.album:
          await _scrapeAlbum(request, downloadItems, errors);
          break;
        default:
          throw Exception('Unsupported content type: $contentType');
      }

      stopwatch.stop();

      return ScrapingResult(
        creatorName: creatorName,
        folderName: '$creatorName (Example Site)',
        downloadItems: downloadItems,
        metadata: {
          'url': request.url,
          'scraper': scraperId,
          'timestamp': DateTime.now().toIso8601String(),
        },
        errors: errors,
        stats: ScrapingStats(
          totalFound: downloadItems.length,
          images: downloadItems.where((item) => _isImage(item.mimeType)).length,
          videos: downloadItems.where((item) => _isVideo(item.mimeType)).length,
          other: downloadItems
              .where((item) =>
                  !_isImage(item.mimeType) && !_isVideo(item.mimeType))
              .length,
          failed: errors.length,
          scrapingTime: stopwatch.elapsed,
        ),
      );
    } catch (e) {
      errors.add('Scraping failed: $e');
      request.onLog('ERROR: $e');

      stopwatch.stop();

      return ScrapingResult(
        creatorName: extractCreatorName(request.url),
        folderName: 'Failed Download',
        downloadItems: downloadItems,
        errors: errors,
        stats: ScrapingStats(
          totalFound: downloadItems.length,
          images: 0,
          videos: 0,
          other: 0,
          failed: errors.length,
          scrapingTime: stopwatch.elapsed,
        ),
      );
    }
  }

  // STEP 5: Implement helper methods for different content types

  /// Scrape a creator's profile (multiple posts)
  Future<void> _scrapeCreator(
    ScrapingRequest request,
    List<DownloadItem> downloadItems,
    List<String> errors,
  ) async {
    request.onLog('Scraping creator: ${extractCreatorName(request.url)}');

    // Example implementation - replace with your site's logic
    final response = await _makeRequest(request.url, request.customHeaders);
    final document = parser.parse(response.body);

    // Find all post links (adapt selectors for your site)
    final postLinks = document.querySelectorAll('a.post-link');

    request.onProgress(ScrapingProgress(
      phase: 'fetching',
      currentUrl: request.url,
      totalItems: postLinks.length,
      processedItems: 0,
      statusMessage: 'Found ${postLinks.length} posts',
    ));

    for (int i = 0; i < postLinks.length; i++) {
      if (request.shouldCancel()) break;

      final postUrl = postLinks[i].attributes['href'];
      if (postUrl != null) {
        try {
          await _scrapePostUrl(postUrl, downloadItems, request);

          request.onProgress(ScrapingProgress(
            phase: 'fetching',
            currentUrl: postUrl,
            totalItems: postLinks.length,
            processedItems: i + 1,
            statusMessage: 'Processed ${i + 1}/${postLinks.length} posts',
          ));

          // Rate limiting
          await Future.delayed(Duration(milliseconds: _config['delay_ms']));
        } catch (e) {
          errors.add('Failed to scrape post $postUrl: $e');
          request.onLog('Failed to scrape post $postUrl: $e');
        }
      }
    }
  }

  /// Scrape a single post
  Future<void> _scrapePost(
    ScrapingRequest request,
    List<DownloadItem> downloadItems,
    List<String> errors,
  ) async {
    await _scrapePostUrl(request.url, downloadItems, request);
  }

  /// Scrape an album/gallery
  Future<void> _scrapeAlbum(
    ScrapingRequest request,
    List<DownloadItem> downloadItems,
    List<String> errors,
  ) async {
    // Similar to _scrapePost but for album-specific logic
    await _scrapePostUrl(request.url, downloadItems, request);
  }

  /// Helper method to scrape a specific post URL
  Future<void> _scrapePostUrl(
    String postUrl,
    List<DownloadItem> downloadItems,
    ScrapingRequest request,
  ) async {
    final response = await _makeRequest(postUrl, request.customHeaders);
    final document = parser.parse(response.body);

    // Find all media elements (adapt selectors for your site)
    final images = document.querySelectorAll('img.content-image');
    final videos = document.querySelectorAll('video.content-video source');

    // Process images
    for (final img in images) {
      final src = img.attributes['src'] ?? img.attributes['data-src'];
      if (src != null) {
        downloadItems.add(DownloadItem(
          downloadName: _extractFileName(src),
          link: _makeAbsoluteUrl(src),
          mimeType: 'image',
        ));
      }
    }

    // Process videos
    for (final video in videos) {
      final src = video.attributes['src'];
      if (src != null) {
        downloadItems.add(DownloadItem(
          downloadName: _extractFileName(src),
          link: _makeAbsoluteUrl(src),
          mimeType: 'video',
        ));
      }
    }
  }

  // STEP 6: Implement utility methods

  @override
  String extractCreatorName(String url) {
    // Extract creator name from URL - adapt for your site
    final uri = Uri.parse(url);
    final segments = uri.pathSegments;

    if (segments.length >= 2 && segments[0] == 'user') {
      return segments[1];
    }

    return 'unknown_creator';
  }

  @override
  ContentType getContentType(String url) {
    if (url.contains('/user/')) {
      return ContentType.creator;
    } else if (url.contains('/post/')) {
      return ContentType.post;
    } else if (url.contains('/gallery/')) {
      return ContentType.album;
    }
    return ContentType.unknown;
  }

  @override
  Map<String, String> getCustomHeaders(String url) {
    return {
      'User-Agent': _config['user_agent'],
      'Referer': 'https://example.com/',
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    };
  }

  @override
  int getRateLimitDelay(String url) {
    return _config['delay_ms'];
  }

  // Private helper methods

  Future<http.Response> _makeRequest(
      String url, Map<String, String> customHeaders) async {
    final headers = {...getCustomHeaders(url), ...customHeaders};

    for (int attempt = 1; attempt <= _config['max_retries']; attempt++) {
      try {
        final response = await http.get(Uri.parse(url), headers: headers);

        if (response.statusCode == 200) {
          return response;
        } else if (response.statusCode == 429) {
          // Rate limited, wait and retry
          await Future.delayed(Duration(seconds: attempt * 2));
          continue;
        } else {
          throw Exception(
              'HTTP ${response.statusCode}: ${response.reasonPhrase}');
        }
      } catch (e) {
        if (attempt == _config['max_retries']) {
          throw Exception(
              'Failed after ${_config['max_retries']} attempts: $e');
        }
        await Future.delayed(Duration(seconds: attempt));
      }
    }

    throw Exception('Request failed after all retries');
  }

  String _extractFileName(String url) {
    final uri = Uri.parse(url);
    final fileName = uri.pathSegments.last;
    return fileName.isNotEmpty ? fileName : 'unknown_file';
  }

  String _makeAbsoluteUrl(String url) {
    if (url.startsWith('http')) {
      return url;
    } else if (url.startsWith('//')) {
      return 'https:$url';
    } else if (url.startsWith('/')) {
      return 'https://example.com$url';
    } else {
      return 'https://example.com/$url';
    }
  }

  bool _isImage(String? mimeType) {
    return mimeType?.startsWith('image') ?? false;
  }

  bool _isVideo(String? mimeType) {
    return mimeType?.startsWith('video') ?? false;
  }
}

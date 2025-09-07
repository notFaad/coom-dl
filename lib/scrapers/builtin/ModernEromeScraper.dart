import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import '../base/BaseScraper.dart';
import '../../data/models/download.dart';

/// Modernized Erome scraper using the new community system
/// This shows how to adapt existing scrapers to the new architecture
class ModernEromeScraper extends BaseScraper {
  @override
  String get scraperId => 'erome_modern';

  @override
  String get displayName => 'Erome Scraper (Modern)';

  @override
  String get version => '2.0.0';

  @override
  String get author => 'CoomDL Team';

  @override
  String get description => 'Downloads albums and profiles from Erome.com';

  @override
  List<String> get supportedUrlPatterns => [
        r'^((https:\/\/)|(https:\/\/www\.))?erome\.com\/\w+$', // Creator profile
        r'^((https:\/\/)|(https:\/\/www\.))?erome\.com\/a\/\w+$', // Album
      ];

  @override
  List<String> get requiredConfigKeys => [];

  @override
  Map<String, dynamic> get defaultConfig => {
        'delay_ms': 500,
        'max_retries': 3,
        'user_agent': 'Mozilla/5.0 (compatible; CoomDL/2.0)',
      };

  @override
  Set<ScraperCapability> get capabilities => {
        ScraperCapability.images,
        ScraperCapability.videos,
        ScraperCapability.pagination,
        ScraperCapability.creatorScraping,
        ScraperCapability.albumScraping,
      };

  Map<String, dynamic> _config = {};

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    _config = {...defaultConfig, ...config};
  }

  @override
  Future<ScrapingResult> scrape(ScrapingRequest request) async {
    final stopwatch = Stopwatch()..start();
    final downloadItems = <DownloadItem>[];
    final errors = <String>[];

    try {
      final contentType = getContentType(request.url);
      final creatorName = extractCreatorName(request.url);

      request.onProgress(ScrapingProgress(
        phase: 'connecting',
        currentUrl: request.url,
        totalItems: 0,
        processedItems: 0,
        statusMessage: 'Connecting to Erome...',
      ));

      switch (contentType) {
        case ContentType.creator:
          await _scrapeCreatorProfile(request, downloadItems, errors);
          break;
        case ContentType.album:
          await _scrapeAlbum(request, downloadItems, errors);
          break;
        default:
          throw Exception('Unsupported Erome URL type');
      }

      stopwatch.stop();

      return ScrapingResult(
        creatorName: creatorName,
        folderName: '$creatorName (Erome ${contentType.name.capitalize()})',
        downloadItems: downloadItems,
        metadata: {
          'url': request.url,
          'scraper': scraperId,
          'content_type': contentType.name,
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
      errors.add('Erome scraping failed: $e');
      request.onLog('ERROR: $e');

      stopwatch.stop();

      return ScrapingResult(
        creatorName: extractCreatorName(request.url),
        folderName: 'Failed Erome Download',
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

  /// Scrape a creator's profile with pagination
  Future<void> _scrapeCreatorProfile(
    ScrapingRequest request,
    List<DownloadItem> downloadItems,
    List<String> errors,
  ) async {
    request.onLog('Scraping Erome creator: ${extractCreatorName(request.url)}');

    String? currentUrl = request.url;
    int pageNum = 1;

    while (currentUrl != null && !request.shouldCancel()) {
      try {
        request.onProgress(ScrapingProgress(
          phase: 'fetching',
          currentUrl: currentUrl,
          totalItems: 0, // Unknown total for profiles
          processedItems: pageNum - 1,
          statusMessage: 'Processing page $pageNum...',
        ));

        final response = await _makeRequest(currentUrl, request.customHeaders);
        final document = parser.parse(response.body);

        // Find album links on the profile page
        final albumLinks = document.querySelectorAll('a.album-link');

        if (albumLinks.isEmpty) {
          request.onLog('No more albums found on page $pageNum');
          break;
        }

        request.onLog('Found ${albumLinks.length} albums on page $pageNum');

        // Process each album
        for (int i = 0; i < albumLinks.length && !request.shouldCancel(); i++) {
          final albumUrl = albumLinks[i].attributes['href'];
          if (albumUrl != null) {
            final fullAlbumUrl = albumUrl.startsWith('http')
                ? albumUrl
                : 'https://erome.com$albumUrl';

            try {
              await _scrapeAlbumUrl(fullAlbumUrl, downloadItems, request);

              request.onProgress(ScrapingProgress(
                phase: 'fetching',
                currentUrl: fullAlbumUrl,
                totalItems: albumLinks.length,
                processedItems: i + 1,
                statusMessage:
                    'Processed ${i + 1}/${albumLinks.length} albums on page $pageNum',
              ));

              // Rate limiting between albums
              await Future.delayed(Duration(milliseconds: _config['delay_ms']));
            } catch (e) {
              errors.add('Failed to scrape album $fullAlbumUrl: $e');
              request.onLog('Failed to scrape album $fullAlbumUrl: $e');
            }
          }
        }

        // Look for next page
        final nextPageLink = document.querySelector('a[rel="next"]');
        currentUrl = nextPageLink?.attributes['href'];
        if (currentUrl != null && !currentUrl.startsWith('http')) {
          currentUrl = 'https://erome.com$currentUrl';
        }

        pageNum++;

        // Rate limiting between pages
        await Future.delayed(Duration(milliseconds: _config['delay_ms'] * 2));
      } catch (e) {
        errors.add('Failed to process page $pageNum: $e');
        request.onLog('Failed to process page $pageNum: $e');
        break;
      }
    }
  }

  /// Scrape a single album
  Future<void> _scrapeAlbum(
    ScrapingRequest request,
    List<DownloadItem> downloadItems,
    List<String> errors,
  ) async {
    await _scrapeAlbumUrl(request.url, downloadItems, request);
  }

  /// Helper method to scrape a specific album URL
  Future<void> _scrapeAlbumUrl(
    String albumUrl,
    List<DownloadItem> downloadItems,
    ScrapingRequest request,
  ) async {
    final response = await _makeRequest(albumUrl, request.customHeaders);
    final document = parser.parse(response.body);

    // Extract images
    final images = document.querySelectorAll('img.img-front');
    for (final img in images) {
      final src = img.attributes['data-src'] ?? img.attributes['src'];
      if (src != null) {
        downloadItems.add(DownloadItem(
          downloadName: _extractFileName(src),
          link: _makeAbsoluteUrl(src),
          mimeType: 'image',
        ));
      }
    }

    // Extract videos
    final videos = document.querySelectorAll('video source');
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

    request.onLog(
        'Extracted ${images.length} images and ${videos.length} videos from album');
  }

  @override
  String extractCreatorName(String url) {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments;

    if (segments.isNotEmpty) {
      // For albums: /a/albumname -> albumname
      // For creators: /creatorname -> creatorname
      if (segments.length >= 2 && segments[0] == 'a') {
        return segments[1];
      } else if (segments.length >= 1) {
        return segments[0];
      }
    }

    return 'unknown_erome_user';
  }

  @override
  ContentType getContentType(String url) {
    if (url.contains('/a/')) {
      return ContentType.album;
    } else {
      return ContentType.creator;
    }
  }

  @override
  Map<String, String> getCustomHeaders(String url) {
    return {
      'User-Agent': _config['user_agent'],
      'Referer': 'https://www.erome.com/',
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.5',
      'DNT': '1',
      'Connection': 'keep-alive',
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
          // Rate limited
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
    final fileName = uri.pathSegments.last.split('?').first;
    return fileName.isNotEmpty ? fileName : 'unknown_file';
  }

  String _makeAbsoluteUrl(String url) {
    if (url.startsWith('http')) {
      return url;
    } else if (url.startsWith('//')) {
      return 'https:$url';
    } else if (url.startsWith('/')) {
      return 'https://erome.com$url';
    } else {
      return 'https://erome.com/$url';
    }
  }

  bool _isImage(String? mimeType) {
    return mimeType == 'image' || mimeType?.startsWith('image/') == true;
  }

  bool _isVideo(String? mimeType) {
    return mimeType == 'video' || mimeType?.startsWith('video/') == true;
  }
}

// Extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

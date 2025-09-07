import '../../neocrawler/coomer_crawler.dart';
import '../base/BaseScraper.dart';
import '../../data/models/download.dart';

/// Modern Neocrawler integration for coomer.st and kemono sites
class NeoCrawlerScraper extends BaseScraper {
  @override
  String get scraperId => 'neocrawler-coomer-kemono';

  @override
  String get displayName => 'Neocrawler Scraper (Coomer/Kemono)';

  @override
  String get version => '2.0.0';

  @override
  String get author => 'CNEX Team';

  @override
  String get description =>
      'Advanced scraper for coomer.st and kemono sites using the neocrawler engine';

  @override
  List<String> get supportedUrlPatterns => [
        r'^((https:\/\/)|(https:\/\/www\.))?coomer\.(party|su|st){1}\/(onlyfans|fansly|candfans){1}\/user{1}\/.+$',
        r'^((https:\/\/)|(https:\/\/www\.))?kemono\.(party|su|cr){1}\/.+$'
      ];

  @override
  List<String> get requiredConfigKeys => [];

  @override
  Map<String, dynamic> get defaultConfig => {
        'timeout_seconds': 300,
        'max_retries': 3,
        'concurrent_downloads': 5,
      };

  @override
  Set<ScraperCapability> get capabilities => {
        ScraperCapability.images,
        ScraperCapability.videos,
        ScraperCapability.creatorScraping,
        ScraperCapability.postScraping,
        ScraperCapability.pagination,
        ScraperCapability.bulkDownload,
      };

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    // Neocrawler doesn't require special initialization
  }

  @override
  String extractCreatorName(String url) {
    final match = RegExp(r'/(user|creator)/([^/]+)').firstMatch(url);
    return match?.group(2) ?? 'unknown';
  }

  @override
  ContentType getContentType(String url) {
    if (url.contains('/user/')) return ContentType.creator;
    if (url.contains('/post/')) return ContentType.post;
    return ContentType.unknown;
  }

  @override
  Future<ScrapingResult> scrape(ScrapingRequest request) async {
    final stopwatch = Stopwatch()..start();
    final creatorName = extractCreatorName(request.url);

    try {
      request.onLog('Starting neocrawler scraping for: ${request.url}');
      request.onProgress(ScrapingProgress(
        phase: 'connecting',
        currentUrl: request.url,
        totalItems: 0,
        processedItems: 0,
        statusMessage: 'Initializing scraper...',
      ));

      // Use the existing neocrawler
      final result = await NeoCoomer.init(url: request.url);

      if (request.shouldCancel()) {
        throw Exception('Cancelled by user');
      }

      final files = result['downloads'] as List<dynamic>? ?? [];
      request.onLog('Neocrawler returned ${files.length} files');

      final downloadItems = <DownloadItem>[];
      int processedCount = 0;
      int imageCount = 0;
      int videoCount = 0;
      int otherCount = 0;

      for (final item in files) {
        if (request.shouldCancel()) {
          throw Exception('Cancelled by user');
        }

        // The files are already DownloadItem objects from coomer_crawler
        final downloadItem = item as DownloadItem;
        downloadItems.add(downloadItem);
        processedCount++;

        // Count by type based on mimeType set by DownloadItem constructor
        if (downloadItem.mimeType == 'Photos') {
          imageCount++;
        } else if (downloadItem.mimeType == 'Videos') {
          videoCount++;
        } else {
          otherCount++;
        }

        // Update progress
        request.onProgress(ScrapingProgress(
          phase: 'parsing',
          currentUrl: request.url,
          totalItems: files.length,
          processedItems: processedCount,
          statusMessage: 'Processing file $processedCount of ${files.length}',
        ));
      }

      stopwatch.stop();

      request.onLog(
          'Successfully processed ${downloadItems.length} files from neocrawler');

      return ScrapingResult(
        creatorName: creatorName,
        folderName: creatorName,
        downloadItems: downloadItems,
        metadata: {
          'source': 'neocrawler',
          'api_version': 'v1',
          'total_posts': result['total_posts'] ?? 0,
        },
        stats: ScrapingStats(
          totalFound: downloadItems.length,
          images: imageCount,
          videos: videoCount,
          other: otherCount,
          failed: 0,
          scrapingTime: stopwatch.elapsed,
        ),
      );
    } catch (error, _) {
      request.onLog('Neocrawler scraping failed: $error');
      stopwatch.stop();

      return ScrapingResult(
        creatorName: creatorName,
        folderName: creatorName,
        downloadItems: [],
        errors: [error.toString()],
        stats: ScrapingStats(
          totalFound: 0,
          images: 0,
          videos: 0,
          other: 0,
          failed: 1,
          scrapingTime: stopwatch.elapsed,
        ),
      );
    }
  }
}

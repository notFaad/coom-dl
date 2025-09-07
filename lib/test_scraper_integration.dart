import 'package:coom_dl/scrapers/ScraperManager.dart';

/// Test function to verify scraper registration and URL handling
Future<void> testScraperIntegration() async {
  print('🧪 Testing scraper integration...');

  // Initialize the scraper manager
  final scraperManager = ScraperManager();
  await scraperManager.initialize();

  // Test URLs for both scrapers
  final testUrls = [
    'https://coomer.st/onlyfans/user/test_user/post/123456', // NeoCrawler
    'https://kemono.party/patreon/user/test_user/post/123456', // NeoCrawler
    'https://www.erome.com/a/test_album', // ModernErome
    'https://erome.com/test_creator', // ModernErome
    'https://example.com/unsupported', // Should not be handled
  ];

  print('\n📋 Testing URL detection and scraper assignment...');
  for (String url in testUrls) {
    final canHandle = scraperManager.canHandle(url);
    final scraper = scraperManager.getScraperForUrl(url);

    print('\n🌐 URL: $url');
    print('   ✅ Can handle: $canHandle');
    print('   🔧 Assigned scraper: ${scraper?.displayName ?? 'None'}');
    print('   🆔 Scraper ID: ${scraper?.scraperId ?? 'N/A'}');

    if (scraper != null) {
      print('   📝 Supported patterns: ${scraper.supportedUrlPatterns}');
    }
  }

  print('\n✅ Scraper integration test complete!');
}

main() async {
  await testScraperIntegration();
}

import 'package:coom_dl/scrapers/ScraperManager.dart';
import 'package:coom_dl/scrapers/base/ScraperRegistry.dart';
import 'package:coom_dl/scrapers/builtin/ModernEromeScraper.dart';

/// Quick test function to verify the scraper system is working
void testScraperSystem() {
  print("🚀 Testing Community Scraper System");

  // Initialize the registry
  final registry = ScraperRegistry();

  // Register our scrapers
  registry.registerScraper(ModernEromeScraper());

  print("✅ Registered ${registry.getAllScrapers().length} scrapers");

  // Test URL matching
  final testUrls = [
    'https://example.com/creator/username',
    'https://erome.com/a/xyz123',
    'https://coomer.st/onlyfans/user/test',
  ];

  for (final url in testUrls) {
    final scraper = registry.findScraperForUrl(url);
    if (scraper != null) {
      print("🎯 Found scraper for $url: ${scraper.displayName}");
    } else {
      print("❌ No scraper found for $url");
    }
  }

  // Initialize ScraperManager
  ScraperManager();

  print("🎉 Scraper system is ready for community use!");
  print("📚 Community developers can now:");
  print("   1. Extend BaseScraper to create custom scrapers");
  print("   2. Register scrapers with the registry");
  print("   3. Use ScraperManager for integration");
  print("");
  print("🌟 Ready to empower 1000+ community members!");
}

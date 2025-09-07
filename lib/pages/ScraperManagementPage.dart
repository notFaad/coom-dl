import 'package:flutter/material.dart';
import '../scrapers/ScraperManager.dart';
import '../scrapers/base/ScraperRegistry.dart';
import '../scrapers/builtin/ModernEromeScraper.dart';
import '../scrapers/community/ExampleCommunityScraper.dart';
import '../constant/appcolors.dart';

/// Settings page for managing community scrapers
class ScraperManagementPage extends StatefulWidget {
  const ScraperManagementPage({Key? key}) : super(key: key);

  @override
  State<ScraperManagementPage> createState() => _ScraperManagementPageState();
}

class _ScraperManagementPageState extends State<ScraperManagementPage> {
  final ScraperManager _scraperManager = ScraperManager();
  List<ScraperInfo> _scrapers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadScrapers();
  }

  Future<void> _loadScrapers() async {
    try {
      // Initialize and manually register our test scrapers
      await _scraperManager.initialize();

      // Register the example scrapers for demonstration
      final registry = ScraperRegistry();
      registry.registerScraper(ModernEromeScraper());
      registry.registerScraper(ExampleCommunityScraper());

      setState(() {
        _scrapers = _scraperManager.getAvailableScrapers();
        _loading = false;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Loaded ${_scrapers.length} community scrapers!'),
            backgroundColor: Appcolors.appPrimaryColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error loading scrapers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Appcolors.appBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Community Scrapers',
          style: TextStyle(
              color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Appcolors.appPrimaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header with stats
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '🚀 Community Scrapers',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_scrapers.length} scrapers available • ${_scrapers.where((s) => s.isEnabled).length} enabled',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showAddScraperDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Scraper'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // Scraper list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _scrapers.length,
                    itemBuilder: (context, index) {
                      final scraper = _scrapers[index];
                      return _buildScraperCard(scraper);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildScraperCard(ScraperInfo scraper) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icon based on scraper type
                CircleAvatar(
                  backgroundColor:
                      scraper.isEnabled ? Colors.green : Colors.grey,
                  child: Icon(
                    _getScraperIcon(scraper.id),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Scraper info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scraper.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'by ${scraper.author} • v${scraper.version}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // Enable/disable switch
                Switch(
                  value: scraper.isEnabled,
                  onChanged: (value) {
                    setState(() {
                      _scraperManager.setScraperEnabled(scraper.id, value);
                      _scrapers = _scraperManager.getAvailableScrapers();
                    });
                  },
                  activeColor: Colors.green,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Description
            Text(
              scraper.description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),

            const SizedBox(height: 12),

            // Supported sites
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: scraper.supportedSites.map((site) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Text(
                    site,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue,
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 12),

            // Action buttons
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _showScraperDetails(scraper),
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('Details'),
                ),
                const SizedBox(width: 8),
                if (!_isBuiltInScraper(scraper.id))
                  TextButton.icon(
                    onPressed: () => _removeScraper(scraper),
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: Colors.red),
                    label: const Text('Remove',
                        style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getScraperIcon(String scraperId) {
    switch (scraperId.toLowerCase()) {
      case 'coomer':
      case 'kemono':
        return Icons.download;
      case 'erome':
        return Icons.photo_library;
      case 'fapello':
        return Icons.video_library;
      default:
        return Icons.extension;
    }
  }

  bool _isBuiltInScraper(String scraperId) {
    return ['coomer', 'kemono', 'erome', 'fapello'].contains(scraperId);
  }

  void _showScraperDetails(ScraperInfo scraper) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(scraper.displayName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Author: ${scraper.author}'),
            Text('Version: ${scraper.version}'),
            const SizedBox(height: 8),
            Text('Description:\n${scraper.description}'),
            const SizedBox(height: 8),
            Text('Capabilities:'),
            ...scraper.capabilities
                .map((cap) => Text('• ${cap.toString().split('.').last}')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _removeScraper(ScraperInfo scraper) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Scraper'),
        content:
            Text('Are you sure you want to remove "${scraper.displayName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _scraperManager.unregisterScraper(scraper.id);
              setState(() {
                _scrapers = _scraperManager.getAvailableScrapers();
              });
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showAddScraperDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Community Scraper'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Want to add a community scraper?'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showDeveloperGuide();
              },
              icon: const Icon(Icons.code),
              label: const Text('Create Your Own'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showScraperStore();
              },
              icon: const Icon(Icons.store),
              label: const Text('Browse Community Store'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showDeveloperGuide() {
    // Show developer guide or open documentation
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🚀 Developer Guide'),
        content: const SingleChildScrollView(
          child: Text('''
Creating your own scraper is easy!

1. Copy the ExampleCommunityScraper.dart template
2. Update the scraper info (name, author, etc.)
3. Define URL patterns for your target site
4. Implement the scraping logic
5. Test with various URLs
6. Share with the community!

Check out COMMUNITY_SCRAPER_GUIDE.md for detailed instructions.

Join our Discord for help and to share your scrapers!
          '''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  void _showScraperStore() {
    // Show community scraper store (future feature)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🏪 Community Store'),
        content: const Text('''
Coming Soon!

The community scraper store will feature:
• Verified community scrapers
• One-click installation
• Ratings and reviews
• Automatic updates
• Popular sites support

For now, check our Discord #scraper-sharing channel for community scrapers!
        '''),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Awesome!'),
          ),
        ],
      ),
    );
  }
}

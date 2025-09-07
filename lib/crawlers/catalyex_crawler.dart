import 'package:coom_dl/services/catalyex_config.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;

class CatalyexCrawler {
  /// Main crawling method that handles different site types
  static Future<Map<String, dynamic>> crawlSite({
    required String url,
    required String siteType,
    required Map<String, dynamic> settings,
    required Function(Map<String, dynamic>) onProgress,
  }) async {
    print("🕸️ CATALYEX CRAWLER: Starting crawl for $siteType");

    try {
      onProgress({
        'stage': 'crawling',
        'message': 'Analyzing $siteType content...',
        'site_type': siteType,
      });

      // Route to appropriate crawler based on site type
      switch (siteType) {
        case 'coomer':
          return await _crawlCoomerSite(url, settings, onProgress);
        case 'kemono':
          return await _crawlKemonoSite(url, settings, onProgress);
        case 'erome':
          return await _crawlEromeSite(url, settings, onProgress);
        case 'fapello':
          return await _crawlFapelloSite(url, settings, onProgress);
        case 'cyberdrop':
          return await _crawlCyberdropSite(url, settings, onProgress);
        default:
          return await _crawlGenericSite(url, settings, onProgress);
      }
    } catch (error) {
      print("❌ CATALYEX CRAWLER ERROR: $error");
      return {
        'success': false,
        'error': error.toString(),
        'downloads': [],
        'site_type': siteType,
      };
    }
  }

  /// Crawl Coomer sites (coomer.st, coomer.su)
  static Future<Map<String, dynamic>> _crawlCoomerSite(
    String url,
    Map<String, dynamic> settings,
    Function(Map<String, dynamic>) onProgress,
  ) async {
    print("🎯 Crawling Coomer site: $url");

    try {
      // Extract user and service from URL
      RegExp userRegex = RegExp(r'coomer\.[^/]+/([^/]+)/user/([^/?]+)');
      Match? match = userRegex.firstMatch(url);

      if (match == null) {
        throw Exception('Invalid Coomer URL format');
      }

      String service = match.group(1)!;
      String userId = match.group(2)!;

      print("👤 Service: $service, User: $userId");

      onProgress({
        'stage': 'api_query',
        'message': 'Fetching posts for $userId...',
        'service': service,
        'user': userId,
      });

      // Use Coomer API for efficient content discovery
      String apiUrl =
          'https://coomer.st/api/v1/$service/user/$userId/posts?o=2000';

      Dio dio = Dio();
      dio.options.headers = CatalyexConfig.getOptimizedHeaders(url);

      Response response = await dio.get(apiUrl);

      if (response.statusCode != 200) {
        throw Exception('API request failed: ${response.statusCode}');
      }

      List<dynamic> posts = response.data;
      List<Map<String, dynamic>> downloads = [];

      print("📚 Found ${posts.length} posts");

      // Process posts to extract downloadable content
      for (int i = 0; i < posts.length; i++) {
        var post = posts[i];

        onProgress({
          'stage': 'processing_posts',
          'message': 'Processing post ${i + 1}/${posts.length}...',
          'progress': (i + 1) / posts.length,
        });

        // Extract files from post
        if (post['file'] != null && post['file']['path'] != null) {
          String filePath = post['file']['path'];
          String fileName = post['file']['name'] ?? 'coomer_file_${post['id']}';
          String downloadUrl = 'https://coomer.st/data$filePath?f=$fileName';

          downloads.add({
            'url': downloadUrl,
            'filename': fileName,
            'type': 'file',
            'post_id': post['id'],
            'service': service,
            'user': userId,
          });
        }

        // Extract attachments
        if (post['attachments'] != null) {
          for (var attachment in post['attachments']) {
            if (attachment['path'] != null) {
              String attachPath = attachment['path'];
              String attachName = attachment['name'] ??
                  'attachment_${attachment['path'].split('/').last}';
              String attachUrl =
                  'https://coomer.st/data$attachPath?f=$attachName';

              downloads.add({
                'url': attachUrl,
                'filename': attachName,
                'type': 'attachment',
                'post_id': post['id'],
                'service': service,
                'user': userId,
              });
            }
          }
        }
      }

      print("✅ Coomer crawl complete: ${downloads.length} items found");

      return {
        'success': true,
        'downloads': downloads,
        'site_type': 'coomer',
        'service': service,
        'user': userId,
        'total_posts': posts.length,
        'total_downloads': downloads.length,
      };
    } catch (error) {
      print("❌ Coomer crawl error: $error");
      return {
        'success': false,
        'error': error.toString(),
        'downloads': [],
        'site_type': 'coomer',
      };
    }
  }

  /// Crawl Kemono sites (kemono.party, kemono.su)
  static Future<Map<String, dynamic>> _crawlKemonoSite(
    String url,
    Map<String, dynamic> settings,
    Function(Map<String, dynamic>) onProgress,
  ) async {
    print("🎯 Crawling Kemono site: $url");

    // Similar to Coomer but with Kemono-specific API endpoints
    try {
      RegExp userRegex = RegExp(r'kemono\.[^/]+/([^/]+)/user/([^/?]+)');
      Match? match = userRegex.firstMatch(url);

      if (match == null) {
        throw Exception('Invalid Kemono URL format');
      }

      String service = match.group(1)!;
      String userId = match.group(2)!;

      onProgress({
        'stage': 'api_query',
        'message': 'Fetching Kemono posts for $userId...',
        'service': service,
        'user': userId,
      });

      String apiUrl =
          'https://kemono.party/api/v1/$service/user/$userId/posts?o=2000';

      Dio dio = Dio();
      dio.options.headers = CatalyexConfig.getOptimizedHeaders(url);

      Response response = await dio.get(apiUrl);
      List<dynamic> posts = response.data;
      List<Map<String, dynamic>> downloads = [];

      // Process Kemono posts (similar structure to Coomer)
      for (int i = 0; i < posts.length; i++) {
        var post = posts[i];

        onProgress({
          'stage': 'processing_posts',
          'message': 'Processing Kemono post ${i + 1}/${posts.length}...',
          'progress': (i + 1) / posts.length,
        });

        // Extract files and attachments using Kemono URL structure
        if (post['file'] != null && post['file']['path'] != null) {
          String filePath = post['file']['path'];
          String fileName = post['file']['name'] ?? 'kemono_file_${post['id']}';
          String downloadUrl = 'https://kemono.party/data$filePath?f=$fileName';

          downloads.add({
            'url': downloadUrl,
            'filename': fileName,
            'type': 'file',
            'post_id': post['id'],
            'service': service,
            'user': userId,
          });
        }

        // Process attachments
        if (post['attachments'] != null) {
          for (var attachment in post['attachments']) {
            if (attachment['path'] != null) {
              String attachPath = attachment['path'];
              String attachName = attachment['name'] ??
                  'kemono_attachment_${attachment['path'].split('/').last}';
              String attachUrl =
                  'https://kemono.party/data$attachPath?f=$attachName';

              downloads.add({
                'url': attachUrl,
                'filename': attachName,
                'type': 'attachment',
                'post_id': post['id'],
                'service': service,
                'user': userId,
              });
            }
          }
        }
      }

      print("✅ Kemono crawl complete: ${downloads.length} items found");

      return {
        'success': true,
        'downloads': downloads,
        'site_type': 'kemono',
        'service': service,
        'user': userId,
        'total_posts': posts.length,
        'total_downloads': downloads.length,
      };
    } catch (error) {
      print("❌ Kemono crawl error: $error");
      return {
        'success': false,
        'error': error.toString(),
        'downloads': [],
        'site_type': 'kemono',
      };
    }
  }

  /// Crawl Erome sites
  static Future<Map<String, dynamic>> _crawlEromeSite(
    String url,
    Map<String, dynamic> settings,
    Function(Map<String, dynamic>) onProgress,
  ) async {
    print("🎯 Crawling Erome site: $url");

    // Placeholder for Erome-specific crawling logic
    // This would use HTML parsing since Erome doesn't have a public API

    onProgress({
      'stage': 'html_parsing',
      'message': 'Parsing Erome content...',
    });

    try {
      Dio dio = Dio();
      dio.options.headers = CatalyexConfig.getOptimizedHeaders(url);

      Response response = await dio.get(url);
      dom.Document document = parser.parse(response.data);

      // Extract video and image URLs from Erome page structure
      List<Map<String, dynamic>> downloads = [];

      // Look for video sources
      var videoElements =
          document.querySelectorAll('video source, .video-js source');
      for (var element in videoElements) {
        String? src = element.attributes['src'];
        if (src != null) {
          downloads.add({
            'url': src.startsWith('http') ? src : 'https://www.erome.com$src',
            'filename': 'erome_video_${downloads.length + 1}.mp4',
            'type': 'video',
          });
        }
      }

      // Look for image sources
      var imgElements =
          document.querySelectorAll('.media-group img, .img-back');
      for (var element in imgElements) {
        String? src =
            element.attributes['src'] ?? element.attributes['data-src'];
        if (src != null && !src.contains('thumbnail')) {
          downloads.add({
            'url': src.startsWith('http') ? src : 'https://www.erome.com$src',
            'filename': 'erome_image_${downloads.length + 1}.jpg',
            'type': 'image',
          });
        }
      }

      print("✅ Erome crawl complete: ${downloads.length} items found");

      return {
        'success': true,
        'downloads': downloads,
        'site_type': 'erome',
        'total_downloads': downloads.length,
      };
    } catch (error) {
      print("❌ Erome crawl error: $error");
      return {
        'success': false,
        'error': error.toString(),
        'downloads': [],
        'site_type': 'erome',
      };
    }
  }

  /// Crawl Fapello sites
  static Future<Map<String, dynamic>> _crawlFapelloSite(
    String url,
    Map<String, dynamic> settings,
    Function(Map<String, dynamic>) onProgress,
  ) async {
    print("🎯 Crawling Fapello site: $url");

    onProgress({
      'stage': 'fapello_processing',
      'message': 'Processing Fapello content...',
    });

    // Placeholder for Fapello crawling - would need site-specific implementation
    return {
      'success': true,
      'downloads': [],
      'site_type': 'fapello',
      'message': 'Fapello crawler not yet implemented',
    };
  }

  /// Crawl Cyberdrop sites
  static Future<Map<String, dynamic>> _crawlCyberdropSite(
    String url,
    Map<String, dynamic> settings,
    Function(Map<String, dynamic>) onProgress,
  ) async {
    print("🎯 Crawling Cyberdrop site: $url");

    onProgress({
      'stage': 'cyberdrop_processing',
      'message': 'Processing Cyberdrop content...',
    });

    // Placeholder for Cyberdrop crawling
    return {
      'success': true,
      'downloads': [],
      'site_type': 'cyberdrop',
      'message': 'Cyberdrop crawler not yet implemented',
    };
  }

  /// Generic crawler for unknown sites
  static Future<Map<String, dynamic>> _crawlGenericSite(
    String url,
    Map<String, dynamic> settings,
    Function(Map<String, dynamic>) onProgress,
  ) async {
    print("🎯 Crawling generic site: $url");

    onProgress({
      'stage': 'generic_processing',
      'message': 'Processing generic content...',
    });

    // Basic HTML parsing for unknown sites
    try {
      Dio dio = Dio();
      dio.options.headers = CatalyexConfig.getOptimizedHeaders(url);

      Response response = await dio.get(url);
      dom.Document document = parser.parse(response.data);

      List<Map<String, dynamic>> downloads = [];

      // Look for common media elements
      var mediaElements = document.querySelectorAll(
          'img, video, a[href*=".jpg"], a[href*=".png"], a[href*=".mp4"], a[href*=".webm"]');

      for (var element in mediaElements) {
        String? src = element.attributes['src'] ?? element.attributes['href'];
        if (src != null) {
          downloads.add({
            'url': src.startsWith('http') ? src : '$url/$src',
            'filename':
                'generic_${downloads.length + 1}_${src.split('/').last}',
            'type': 'generic',
          });
        }
      }

      return {
        'success': true,
        'downloads': downloads,
        'site_type': 'generic',
        'total_downloads': downloads.length,
      };
    } catch (error) {
      return {
        'success': false,
        'error': error.toString(),
        'downloads': [],
        'site_type': 'generic',
      };
    }
  }
}

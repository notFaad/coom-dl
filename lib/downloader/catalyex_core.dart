import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:coom_dl/crawlers/catalyex_crawler.dart';
import 'package:coom_dl/services/catalyex_config.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class CatalyexCore {
  static int totalDownloaded = 0;
  static int threadsUsed = 0;
  static bool isContinue = true;
  static bool isPaused = false;

  /// Main content processing method - equivalent to CybCrawl.getFileContent
  static Future<void> processContent({
    required String url,
    required String directory,
    required bool isStandardPhoto,
    required bool debug,
    required Map settingMap,
    required Map linksConfig,
    required int currentOption,
    required Function(Map<String, dynamic>) onProgress,
    required Function(Map<String, dynamic>) onScrape,
    required Function(String) onError,
    required bool Function() getCanceled,
  }) async {
    print("🔥 CATALYEX CORE: Processing $url");

    try {
      // Initialize isolate communication
      ReceivePort logger = ReceivePort();
      IsolateNameServer.registerPortWithName(
          logger.sendPort, "catalyex_logger");

      logger.listen((message) async {
        print("📡 Catalyex Log: $message");
        onProgress(message);
      });

      // Analyze URL and determine best processing strategy
      String siteType = CatalyexConfig.detectSiteType(url);
      Map<String, dynamic> optimizedSettings =
          CatalyexConfig.getOptimizedSettings(url);

      print(
          "🎯 Site: $siteType | Threads: ${optimizedSettings['threads']} | Strategy: ${optimizedSettings['strategy']}");

      // Send initialization message
      IsolateNameServer.lookupPortByName("catalyex_logger")?.send({
        'title': 'CATALYEX_INIT',
        'status': 'STARTING',
        'm': 'Catalyex Engine initializing for $siteType',
        'site_type': siteType,
        'optimized_threads': optimizedSettings['threads'],
        'timestamp': DateTime.now().toIso8601String()
      });

      // Use Catalyex Crawler for content discovery
      Map<String, dynamic> crawlResult = await CatalyexCrawler.crawlSite(
        url: url,
        siteType: siteType,
        settings: optimizedSettings,
        onProgress: onScrape,
      );

      if (crawlResult['success'] != true) {
        throw Exception('Crawling failed: ${crawlResult['error']}');
      }

      List<dynamic> downloadLinks = crawlResult['downloads'] ?? [];
      print("📚 Found ${downloadLinks.length} items to download");

      // Send crawling complete message
      IsolateNameServer.lookupPortByName("catalyex_logger")?.send({
        'title': 'CRAWL_COMPLETE',
        'status': 'CRAWLED',
        'm': 'Found ${downloadLinks.length} items',
        'total_items': downloadLinks.length,
        'timestamp': DateTime.now().toIso8601String()
      });

      // Process downloads with Catalyex optimization
      await _processDownloads(
        links: downloadLinks,
        directory: directory,
        settings: optimizedSettings,
        isStandardPhoto: isStandardPhoto,
        onProgress: onProgress,
        getCanceled: getCanceled,
      );

      print("✅ CATALYEX CORE: Completed processing $url");
    } catch (error) {
      print("❌ CATALYEX CORE ERROR: $error");
      onError(error.toString());

      // Send error message via isolate
      IsolateNameServer.lookupPortByName("catalyex_logger")?.send({
        'title': 'CATALYEX_ERROR',
        'status': 'ERROR',
        'm': 'Processing failed: $error',
        'error': error.toString(),
        'timestamp': DateTime.now().toIso8601String()
      });

      rethrow;
    } finally {
      // Cleanup isolate communication
      try {
        IsolateNameServer.removePortNameMapping("catalyex_logger");
      } catch (e) {
        print("⚠️ Cleanup warning: $e");
      }
    }
  }

  /// Process downloads with optimized threading
  static Future<void> _processDownloads({
    required List<dynamic> links,
    required String directory,
    required Map<String, dynamic> settings,
    required bool isStandardPhoto,
    required Function(Map<String, dynamic>) onProgress,
    required bool Function() getCanceled,
  }) async {
    int maxThreads = settings['threads'] ?? CatalyexConfig.DEFAULT_THREADS;
    int completed = 0;
    int failed = 0;
    List<Future> activeDownloads = [];

    print("⚡ Starting downloads with $maxThreads threads");

    for (int i = 0; i < links.length; i++) {
      // Check for cancellation
      if (getCanceled()) {
        print("❌ Downloads cancelled by user");
        break;
      }

      // Limit concurrent downloads
      if (activeDownloads.length >= maxThreads) {
        // Wait for at least one download to complete
        await Future.any(activeDownloads);
        // Rebuild the list with only non-completed futures
        activeDownloads.clear();
      }

      // Start download in parallel
      var downloadFuture = _downloadSingleFile(
        link: links[i],
        directory: directory,
        index: i,
        total: links.length,
        isStandardPhoto: isStandardPhoto,
        onComplete: (success) {
          if (success) {
            completed++;
          } else {
            failed++;
          }

          // Send progress update
          onProgress({
            'status': success ? 'ok' : 'fail',
            'completed': completed,
            'failed': failed,
            'total': links.length,
            'progress': (completed + failed) / links.length,
            'timestamp': DateTime.now().toIso8601String()
          });
        },
      );

      activeDownloads.add(downloadFuture);
    }

    // Wait for all downloads to complete
    await Future.wait(activeDownloads);

    print("🎉 Downloads completed: $completed success, $failed failed");
  }

  /// Download a single file with Catalyex optimization
  static Future<void> _downloadSingleFile({
    required dynamic link,
    required String directory,
    required int index,
    required int total,
    required bool isStandardPhoto,
    required Function(bool) onComplete,
  }) async {
    try {
      String downloadUrl = link['url'] ?? link['link'] ?? '';
      String fileName =
          link['filename'] ?? link['downloadName'] ?? 'catalyex_${index}.file';

      if (downloadUrl.isEmpty) {
        throw Exception('No download URL found');
      }

      print("⬇️ [$index/$total] Downloading: $fileName");

      // Create directory structure
      String fullPath = '$directory/$fileName';
      Directory(Directory(fullPath).parent.path).createSync(recursive: true);

      // Download with optimized headers and retry logic
      await _downloadWithRetry(
        url: downloadUrl,
        filePath: fullPath,
        maxRetries: CatalyexConfig.MAX_RETRIES,
      );

      // Send success message via isolate
      IsolateNameServer.lookupPortByName("catalyex_logger")?.send({
        'title': fileName,
        'status': 'ok',
        'index': index,
        'total': total,
        'size': await File(fullPath).length(),
        'timestamp': DateTime.now().toIso8601String()
      });

      onComplete(true);
      print("✅ [$index/$total] Completed: $fileName");
    } catch (error) {
      print("❌ [$index/$total] Failed: $error");

      // Send failure message via isolate
      IsolateNameServer.lookupPortByName("catalyex_logger")?.send({
        'title': 'Download Failed',
        'status': 'fail',
        'index': index,
        'total': total,
        'error': error.toString(),
        'timestamp': DateTime.now().toIso8601String()
      });

      onComplete(false);
    }
  }

  /// Download with retry logic and optimized settings
  static Future<void> _downloadWithRetry({
    required String url,
    required String filePath,
    required int maxRetries,
  }) async {
    int attempt = 0;

    while (attempt < maxRetries) {
      try {
        // Use Dio for better performance and control
        Dio dio = Dio();
        dio.options.connectTimeout = Duration(seconds: 30);
        dio.options.receiveTimeout = Duration(seconds: 60);

        // Optimized headers for different sites
        Map<String, String> headers = CatalyexConfig.getOptimizedHeaders(url);

        await dio.download(
          url,
          filePath,
          options: Options(headers: headers),
        );

        // Success - exit retry loop
        return;
      } catch (error) {
        attempt++;
        print("⚠️ Download attempt $attempt failed: $error");

        if (attempt >= maxRetries) {
          throw Exception('Download failed after $maxRetries attempts: $error');
        }

        // Progressive delay between retries
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
  }
}

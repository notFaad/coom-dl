import 'package:flutter_test/flutter_test.dart';
import 'package:coom_dl/services/event_bus.dart';
import 'dart:async';

void main() {
  group('EventBus Tests', () {
    late EventBus eventBus;

    setUp(() {
      eventBus = EventBus();
    });

    tearDown(() async {
      await eventBus.dispose();
    });

    test('should emit and receive download started events', () async {
      DownloadStartedEvent? receivedEvent;

      eventBus.on<DownloadStartedEvent>().listen((event) {
        receivedEvent = event;
      });

      final emittedEvent = DownloadStartedEvent(123, 'https://example.com');
      eventBus.emit(emittedEvent);

      // Allow event to propagate
      await Future.delayed(Duration(milliseconds: 10));

      expect(receivedEvent, isNotNull);
      expect(receivedEvent!.downloadId, equals(123));
      expect(receivedEvent!.url, equals('https://example.com'));
      expect(receivedEvent!.timestamp, isA<DateTime>());
    });

    test('should emit and receive download progress events', () async {
      DownloadProgressEvent? receivedEvent;

      eventBus.on<DownloadProgressEvent>().listen((event) {
        receivedEvent = event;
      });

      final progress = DownloadProgress(
        downloadId: 456,
        completedFiles: 5,
        totalFiles: 10,
        currentFileProgress: 0.7,
        bytesDownloaded: 1024,
        totalBytes: 2048,
        speedBps: 512.5,
        estimatedTimeRemaining: Duration(minutes: 2),
      );

      final emittedEvent = DownloadProgressEvent(456, progress);
      eventBus.emit(emittedEvent);

      await Future.delayed(Duration(milliseconds: 10));

      expect(receivedEvent, isNotNull);
      expect(receivedEvent!.downloadId, equals(456));
      expect(receivedEvent!.progress.completedFiles, equals(5));
      expect(receivedEvent!.progress.totalFiles, equals(10));
      expect(receivedEvent!.progress.overallProgress,
          closeTo(0.57, 0.01)); // (5 + 0.7) / 10
    });

    test('should emit and receive download error events', () async {
      DownloadErrorEvent? receivedEvent;

      eventBus.on<DownloadErrorEvent>().listen((event) {
        receivedEvent = event;
      });

      final emittedEvent = DownloadErrorEvent(789, 'Network timeout');
      eventBus.emit(emittedEvent);

      await Future.delayed(Duration(milliseconds: 10));

      expect(receivedEvent, isNotNull);
      expect(receivedEvent!.downloadId, equals(789));
      expect(receivedEvent!.error, equals('Network timeout'));
    });

    test('should handle multiple listeners for same event type', () async {
      final receivedEvents = <DownloadCompletedEvent>[];

      eventBus.on<DownloadCompletedEvent>().listen((event) {
        receivedEvents.add(event);
      });

      eventBus.on<DownloadCompletedEvent>().listen((event) {
        receivedEvents.add(event);
      });

      final emittedEvent = DownloadCompletedEvent(101);
      eventBus.emit(emittedEvent);

      await Future.delayed(Duration(milliseconds: 10));

      expect(receivedEvents.length, equals(2));
      expect(receivedEvents[0].downloadId, equals(101));
      expect(receivedEvents[1].downloadId, equals(101));
    });

    test('should handle different event types separately', () async {
      DownloadStartedEvent? startedEvent;
      DownloadCompletedEvent? completedEvent;
      DownloadErrorEvent? errorEvent;

      eventBus.on<DownloadStartedEvent>().listen((event) {
        startedEvent = event;
      });

      eventBus.on<DownloadCompletedEvent>().listen((event) {
        completedEvent = event;
      });

      eventBus.on<DownloadErrorEvent>().listen((event) {
        errorEvent = event;
      });

      eventBus.emit(DownloadStartedEvent(1, 'url1'));
      eventBus.emit(DownloadCompletedEvent(2));
      eventBus.emit(DownloadErrorEvent(3, 'error'));

      await Future.delayed(Duration(milliseconds: 10));

      expect(startedEvent?.downloadId, equals(1));
      expect(completedEvent?.downloadId, equals(2));
      expect(errorEvent?.downloadId, equals(3));
    });

    test('should emit download manager events', () async {
      DownloadManagerEvent? receivedEvent;

      eventBus.on<DownloadManagerEvent>().listen((event) {
        receivedEvent = event;
      });

      final emittedEvent = DownloadManagerEvent.initialized();
      eventBus.emit(emittedEvent);

      await Future.delayed(Duration(milliseconds: 10));

      expect(receivedEvent, isNotNull);
      expect(receivedEvent!.message, equals('Download Manager initialized'));
    });

    test('should emit error recovery events', () async {
      ErrorRecoveryEvent? receivedEvent;

      eventBus.on<ErrorRecoveryEvent>().listen((event) {
        receivedEvent = event;
      });

      final emittedEvent = ErrorRecoveryEvent(
        downloadId: 123,
        errorType: 'network',
        recoveryAction: 'retry with exponential backoff',
        successful: true,
      );
      eventBus.emit(emittedEvent);

      await Future.delayed(Duration(milliseconds: 10));

      expect(receivedEvent, isNotNull);
      expect(receivedEvent!.downloadId, equals(123));
      expect(receivedEvent!.errorType, equals('network'));
      expect(receivedEvent!.recoveryAction,
          equals('retry with exponential backoff'));
      expect(receivedEvent!.successful, isTrue);
    });

    test('should clean up streams on dispose', () async {
      bool eventReceived = false;

      eventBus.on<DownloadStartedEvent>().listen((event) {
        eventReceived = true;
      });

      await eventBus.dispose();

      // Emit after dispose - should not be received
      eventBus.emit(DownloadStartedEvent(999, 'test'));
      await Future.delayed(Duration(milliseconds: 10));

      expect(eventReceived, isFalse);
    });
  });

  group('DownloadProgress Tests', () {
    test('should calculate overall progress correctly', () {
      final progress = DownloadProgress(
        downloadId: 1,
        completedFiles: 3,
        totalFiles: 10,
        currentFileProgress: 0.5,
      );

      expect(progress.overallProgress, equals(0.35)); // (3 + 0.5) / 10
      expect(progress.percentageComplete, equals(35.0));
    });

    test('should handle zero total files', () {
      final progress = DownloadProgress(
        downloadId: 1,
        completedFiles: 0,
        totalFiles: 0,
        currentFileProgress: 0.0,
      );

      expect(progress.overallProgress, equals(0.0));
      expect(progress.percentageComplete, equals(0.0));
    });

    test('should format speed correctly', () {
      final progressBytes = DownloadProgress(
        downloadId: 1,
        completedFiles: 1,
        totalFiles: 1,
        currentFileProgress: 0.5,
        speedBps: 512.7,
      );

      final progressKB = DownloadProgress(
        downloadId: 1,
        completedFiles: 1,
        totalFiles: 1,
        currentFileProgress: 0.5,
        speedBps: 1536.0, // 1.5 KB/s
      );

      final progressMB = DownloadProgress(
        downloadId: 1,
        completedFiles: 1,
        totalFiles: 1,
        currentFileProgress: 0.5,
        speedBps: 2097152.0, // 2 MB/s
      );

      expect(progressBytes.formattedSpeed, equals('512.7 B/s'));
      expect(progressKB.formattedSpeed, equals('1.5 KB/s'));
      expect(progressMB.formattedSpeed, equals('2.0 MB/s'));
    });

    test('should format ETA correctly', () {
      final progressSeconds = DownloadProgress(
        downloadId: 1,
        completedFiles: 1,
        totalFiles: 1,
        currentFileProgress: 0.5,
        estimatedTimeRemaining: Duration(seconds: 45),
      );

      final progressMinutes = DownloadProgress(
        downloadId: 1,
        completedFiles: 1,
        totalFiles: 1,
        currentFileProgress: 0.5,
        estimatedTimeRemaining: Duration(minutes: 2, seconds: 30),
      );

      final progressHours = DownloadProgress(
        downloadId: 1,
        completedFiles: 1,
        totalFiles: 1,
        currentFileProgress: 0.5,
        estimatedTimeRemaining: Duration(hours: 1, minutes: 15),
      );

      expect(progressSeconds.formattedETA, equals('45s'));
      expect(progressMinutes.formattedETA, equals('2m 30s'));
      expect(progressHours.formattedETA, equals('1h 15m'));
    });
  });

  group('Event Classes Tests', () {
    test('should create events with timestamps', () {
      final startedEvent = DownloadStartedEvent(1, 'url');
      final completedEvent = DownloadCompletedEvent(1);
      final errorEvent = DownloadErrorEvent(1, 'error');

      expect(startedEvent.timestamp, isA<DateTime>());
      expect(completedEvent.timestamp, isA<DateTime>());
      expect(errorEvent.timestamp, isA<DateTime>());

      // All timestamps should be recent
      final now = DateTime.now();
      expect(startedEvent.timestamp.isAfter(now.subtract(Duration(seconds: 1))),
          isTrue);
      expect(
          completedEvent.timestamp.isAfter(now.subtract(Duration(seconds: 1))),
          isTrue);
      expect(errorEvent.timestamp.isAfter(now.subtract(Duration(seconds: 1))),
          isTrue);
    });

    test('should create engine performance events', () {
      final performanceEvent = EnginePerformanceEvent(
        engineName: 'Gallery-DL',
        downloadTime: Duration(seconds: 30),
        bytesDownloaded: 1048576, // 1 MB
        success: true,
      );

      expect(performanceEvent.engineName, equals('Gallery-DL'));
      expect(performanceEvent.downloadTime, equals(Duration(seconds: 30)));
      expect(performanceEvent.bytesDownloaded, equals(1048576));
      expect(performanceEvent.success, isTrue);

      // Speed calculation: 1MB in 30s = ~0.28 Mbps
      expect(performanceEvent.speedMbps, closeTo(0.28, 0.02));
    });

    test('should create system health events', () {
      final healthEvent = SystemHealthEvent(
        cpuUsage: 45.7,
        memoryUsage: 62.3,
        activeDownloads: 3,
      );

      expect(healthEvent.cpuUsage, equals(45.7));
      expect(healthEvent.memoryUsage, equals(62.3));
      expect(healthEvent.activeDownloads, equals(3));
    });

    test('should create scraper events', () {
      final scraperEvent = ScraperEvent('coomer_scraper', 'Scraping completed');
      final scraperErrorEvent = ScraperErrorEvent(
        'kemono_scraper',
        'https://kemono.party/test',
        'Rate limited',
      );

      expect(scraperEvent.scraperId, equals('coomer_scraper'));
      expect(scraperEvent.message, equals('Scraping completed'));

      expect(scraperErrorEvent.scraperId, equals('kemono_scraper'));
      expect(scraperErrorEvent.url, equals('https://kemono.party/test'));
      expect(scraperErrorEvent.error, equals('Rate limited'));
    });
  });
}

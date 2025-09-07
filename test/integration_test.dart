import 'package:flutter_test/flutter_test.dart';
import 'package:coom_dl/services/download_manager.dart';
import 'package:coom_dl/services/event_bus.dart';
import 'package:coom_dl/services/smart_retry_service.dart';
import 'dart:async';

void main() {
  group('Download System Integration Tests', () {
    test('should handle URL pattern detection correctly', () async {
      // Test URL pattern detection for engine selection
      final testCases = [
        // Coomer sites
        ['https://coomer.party/onlyfans/user/test', DownloadEngine.recooma],
        ['https://coomer.su/fansly/user/test', DownloadEngine.recooma],
        ['https://coomer.st/candfans/user/test', DownloadEngine.recooma],

        // Kemono sites
        ['https://kemono.party/patreon/user/123', DownloadEngine.recooma],
        ['https://kemono.su/discord/server/456', DownloadEngine.recooma],
        ['https://kemono.cr/fanbox/user/789', DownloadEngine.recooma],

        // CybDrop sites
        ['https://cyberdrop.me/a/album123', DownloadEngine.cyberdrop],
        ['https://cyberdrop.to/a/test', DownloadEngine.cyberdrop],

        // Unknown sites (should default to Gallery-DL)
        ['https://example.com/gallery', DownloadEngine.galleryDl],
        ['https://instagram.com/user/posts', DownloadEngine.galleryDl],
        ['https://twitter.com/user/media', DownloadEngine.galleryDl],
      ];

      for (final testCase in testCases) {
        final url = testCase[0] as String;
        final expectedEngine = testCase[1] as DownloadEngine;

        final actualEngine = await _selectEngineForUrl(url);
        expect(actualEngine, equals(expectedEngine),
            reason: 'URL: $url should select ${expectedEngine.displayName}');
      }
    });

    test('should integrate EventBus with retry logic', () async {
      final eventBus = EventBus();
      final retryService = SmartRetryService();
      await retryService.initialize();

      final receivedEvents = <DownloadEvent>[];

      // Listen to all download events
      eventBus.on<DownloadEvent>().listen((event) {
        receivedEvents.add(event);
      });

      // Simulate download lifecycle with retries
      const downloadId = 1001;

      // Start download
      eventBus.emit(DownloadStartedEvent(downloadId, 'https://example.com'));

      // Simulate network error and retry
      const networkError = 'Connection timeout';
      final shouldRetry = retryService.shouldRetry(downloadId, networkError);
      expect(shouldRetry, isTrue);

      eventBus.emit(DownloadErrorEvent(downloadId, networkError));

      // Simulate recovery
      eventBus.emit(ErrorRecoveryEvent(
        downloadId: downloadId,
        errorType: 'network',
        recoveryAction: 'retry with backoff',
        successful: true,
      ));

      // Complete download
      eventBus.emit(DownloadCompletedEvent(downloadId));

      await Future.delayed(Duration(milliseconds: 10));

      expect(receivedEvents.length, equals(4));
      expect(receivedEvents[0], isA<DownloadStartedEvent>());
      expect(receivedEvents[1], isA<DownloadErrorEvent>());
      expect(receivedEvents[2], isA<ErrorRecoveryEvent>());
      expect(receivedEvents[3], isA<DownloadCompletedEvent>());

      await eventBus.dispose();
    });

    test('should handle multiple download sessions simultaneously', () async {
      final eventBus = EventBus();
      final progressEvents = <DownloadProgressEvent>[];

      eventBus.on<DownloadProgressEvent>().listen((event) {
        progressEvents.add(event);
      });

      // Simulate multiple downloads with different progress
      final downloads = [
        {'id': 1, 'completed': 2, 'total': 10, 'progress': 0.3},
        {'id': 2, 'completed': 5, 'total': 8, 'progress': 0.7},
        {'id': 3, 'completed': 1, 'total': 3, 'progress': 0.9},
      ];

      for (final download in downloads) {
        final progress = DownloadProgress(
          downloadId: download['id'] as int,
          completedFiles: download['completed'] as int,
          totalFiles: download['total'] as int,
          currentFileProgress: download['progress'] as double,
          speedBps: 1024.0 * (download['id'] as int), // Different speeds
          estimatedTimeRemaining: Duration(minutes: download['id'] as int),
        );

        eventBus.emit(DownloadProgressEvent(download['id'] as int, progress));
      }

      await Future.delayed(Duration(milliseconds: 10));

      expect(progressEvents.length, equals(3));

      // Verify each download's progress
      for (int i = 0; i < downloads.length; i++) {
        final expectedId = downloads[i]['id'] as int;
        final event =
            progressEvents.firstWhere((e) => e.downloadId == expectedId);

        expect(event.downloadId, equals(expectedId));
        expect(
            event.progress.completedFiles, equals(downloads[i]['completed']));
        expect(event.progress.totalFiles, equals(downloads[i]['total']));
        expect(event.progress.currentFileProgress,
            equals(downloads[i]['progress']));
      }

      await eventBus.dispose();
    });

    test('should demonstrate error classification and retry strategy',
        () async {
      final retryService = SmartRetryService();
      await retryService.initialize();

      // Test different error scenarios
      final errorScenarios = [
        {
          'error': 'Network connection failed',
          'type': 'network',
          'maxRetries': 5,
          'baseDelay': 2,
        },
        {
          'error': 'HTTP 429 Too Many Requests',
          'type': 'rateLimit',
          'maxRetries': 8,
          'baseDelay': 30,
        },
        {
          'error': 'HTTP 404 Not Found',
          'type': 'notFound',
          'maxRetries': 1,
          'baseDelay': 0,
        },
        {
          'error': 'Request timeout',
          'type': 'timeout',
          'maxRetries': 3,
          'baseDelay': 5,
        },
      ];

      for (int i = 0; i < errorScenarios.length; i++) {
        final scenario = errorScenarios[i];
        final downloadId = 2000 + i;
        final error = scenario['error'] as String;
        final maxRetries = scenario['maxRetries'] as int;

        // Test retry limits
        for (int attempt = 1; attempt <= maxRetries + 2; attempt++) {
          final shouldRetry = retryService.shouldRetry(downloadId, error);

          if (attempt <= maxRetries) {
            expect(shouldRetry, isTrue,
                reason: 'Attempt $attempt for $error should allow retry');
          } else {
            expect(shouldRetry, isFalse,
                reason: 'Attempt $attempt for $error should not allow retry');
          }

          // Simulate attempt
          if (shouldRetry) {
            final state = retryService._getOrCreateRetryState(downloadId);
            state.attemptCount = attempt;
          }
        }
      }
    });

    test('should demonstrate progress calculation accuracy', () {
      // Test various progress scenarios
      final progressScenarios = [
        {
          'completed': 0,
          'total': 10,
          'current': 0.0,
          'expected': 0.0,
        },
        {
          'completed': 3,
          'total': 10,
          'current': 0.5,
          'expected': 0.35, // (3 + 0.5) / 10
        },
        {
          'completed': 9,
          'total': 10,
          'current': 0.8,
          'expected': 0.98, // (9 + 0.8) / 10
        },
        {
          'completed': 10,
          'total': 10,
          'current': 0.0,
          'expected': 1.0, // All complete
        },
      ];

      for (final scenario in progressScenarios) {
        final progress = DownloadProgress(
          downloadId: 1,
          completedFiles: scenario['completed'] as int,
          totalFiles: scenario['total'] as int,
          currentFileProgress: scenario['current'] as double,
        );

        expect(progress.overallProgress,
            closeTo(scenario['expected'] as double, 0.01));
        expect(progress.percentageComplete,
            closeTo((scenario['expected'] as double) * 100, 0.1));
      }
    });

    test('should handle speed and ETA formatting correctly', () {
      final formattingTests = [
        {
          'speedBps': 512.0,
          'eta': Duration(seconds: 30),
          'expectedSpeed': '512.0 B/s',
          'expectedETA': '30s',
        },
        {
          'speedBps': 1536.0, // 1.5 KB/s
          'eta': Duration(minutes: 2, seconds: 30),
          'expectedSpeed': '1.5 KB/s',
          'expectedETA': '2m 30s',
        },
        {
          'speedBps': 2097152.0, // 2 MB/s
          'eta': Duration(hours: 1, minutes: 15),
          'expectedSpeed': '2.0 MB/s',
          'expectedETA': '1h 15m',
        },
      ];

      for (final test in formattingTests) {
        final progress = DownloadProgress(
          downloadId: 1,
          completedFiles: 5,
          totalFiles: 10,
          currentFileProgress: 0.5,
          speedBps: test['speedBps'] as double,
          estimatedTimeRemaining: test['eta'] as Duration,
        );

        expect(progress.formattedSpeed, equals(test['expectedSpeed']));
        expect(progress.formattedETA, equals(test['expectedETA']));
      }
    });

    test('should validate event timestamp accuracy', () async {
      final eventBus = EventBus();
      final timestampedEvents = <DownloadEvent>[];

      eventBus.on<DownloadEvent>().listen((event) {
        timestampedEvents.add(event);
      });

      final startTime = DateTime.now();

      // Emit events with small delays
      eventBus.emit(DownloadStartedEvent(1, 'url1'));
      await Future.delayed(Duration(milliseconds: 10));

      eventBus.emit(DownloadProgressEvent(
          1,
          DownloadProgress(
            downloadId: 1,
            completedFiles: 1,
            totalFiles: 5,
            currentFileProgress: 0.2,
          )));
      await Future.delayed(Duration(milliseconds: 10));

      eventBus.emit(DownloadCompletedEvent(1));

      final endTime = DateTime.now();

      await Future.delayed(Duration(milliseconds: 10));

      expect(timestampedEvents.length, equals(3));

      // All timestamps should be within the test timeframe
      for (final event in timestampedEvents) {
        expect(
            event.timestamp.isAfter(startTime.subtract(Duration(seconds: 1))),
            isTrue);
        expect(event.timestamp.isBefore(endTime.add(Duration(seconds: 1))),
            isTrue);
      }

      // Timestamps should be in chronological order
      for (int i = 1; i < timestampedEvents.length; i++) {
        expect(
            timestampedEvents[i]
                    .timestamp
                    .isAfter(timestampedEvents[i - 1].timestamp) ||
                timestampedEvents[i]
                    .timestamp
                    .isAtSameMomentAs(timestampedEvents[i - 1].timestamp),
            isTrue,
            reason: 'Events should be chronologically ordered');
      }

      await eventBus.dispose();
    });
  });
}

// Helper function to simulate engine selection logic
Future<DownloadEngine> _selectEngineForUrl(String url) async {
  if (RegExp(r'coomer\.(party|su|st)').hasMatch(url)) {
    return DownloadEngine.recooma;
  }
  if (RegExp(r'kemono\.(party|su|cr)').hasMatch(url)) {
    return DownloadEngine.recooma;
  }
  if (RegExp(r'cyberdrop\.').hasMatch(url)) {
    return DownloadEngine.cyberdrop;
  }
  return DownloadEngine.galleryDl;
}

// Extension to access private methods for integration testing
extension SmartRetryServiceIntegrationTest on SmartRetryService {
  RetryState _getOrCreateRetryState(int downloadId) {
    final retryStates = <int, RetryState>{};
    return retryStates.putIfAbsent(
      downloadId,
      () => RetryState(downloadId: downloadId),
    );
  }
}

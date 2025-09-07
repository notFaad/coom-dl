import 'package:flutter_test/flutter_test.dart';
import 'package:coom_dl/services/download_manager.dart';
import 'package:coom_dl/services/event_bus.dart';

void main() {
  group('DownloadEngine Tests', () {
    test('should have correct display names', () {
      expect(DownloadEngine.recooma.displayName, equals('Recooma Engine'));
      expect(DownloadEngine.galleryDl.displayName, equals('Gallery-dl Engine'));
      expect(DownloadEngine.cyberdrop.displayName, equals('Cyberdrop Engine'));
      expect(DownloadEngine.auto.displayName, equals('Auto Select'));
    });

    test('should have correct enum values', () {
      expect(DownloadEngine.values.length, equals(4));
      expect(DownloadEngine.values.contains(DownloadEngine.recooma), isTrue);
      expect(DownloadEngine.values.contains(DownloadEngine.galleryDl), isTrue);
      expect(DownloadEngine.values.contains(DownloadEngine.cyberdrop), isTrue);
      expect(DownloadEngine.values.contains(DownloadEngine.auto), isTrue);
    });
  });

  group('DownloadSession Tests', () {
    test('should create session with required parameters', () {
      final session = DownloadSession(
        downloadId: 1,
        url: 'https://example.com',
        downloadPath: '/downloads',
        engine: DownloadEngine.recooma,
      );

      expect(session.downloadId, equals(1));
      expect(session.url, equals('https://example.com'));
      expect(session.downloadPath, equals('/downloads'));
      expect(session.engine, equals(DownloadEngine.recooma));
      expect(session.isPaused, isFalse);
      expect(session.isCancelled, isFalse);
      expect(session.completedFiles, equals(0));
      expect(session.totalFiles, equals(0));
      expect(session.currentProgress, equals(0.0));
    });

    test('should update session state', () {
      final session = DownloadSession(
        downloadId: 1,
        url: 'https://example.com',
        downloadPath: '/downloads',
        engine: DownloadEngine.recooma,
      );

      session.isPaused = true;
      session.isCancelled = true;
      session.completedFiles = 5;
      session.totalFiles = 10;
      session.currentProgress = 0.7;

      expect(session.isPaused, isTrue);
      expect(session.isCancelled, isTrue);
      expect(session.completedFiles, equals(5));
      expect(session.totalFiles, equals(10));
      expect(session.currentProgress, equals(0.7));
    });

    test('should accept optional callback functions', () {
      bool progressCalled = false;
      bool errorCalled = false;
      bool completeCalled = false;

      final session = DownloadSession(
        downloadId: 1,
        url: 'https://example.com',
        downloadPath: '/downloads',
        engine: DownloadEngine.recooma,
        onProgress: (progress) => progressCalled = true,
        onError: (error) => errorCalled = true,
        onComplete: (id) => completeCalled = true,
      );

      expect(session.onProgress, isNotNull);
      expect(session.onError, isNotNull);
      expect(session.onComplete, isNotNull);

      // Test callbacks
      session.onProgress?.call(DownloadProgress(
        downloadId: 1,
        completedFiles: 1,
        totalFiles: 10,
        currentFileProgress: 0.5,
      ));
      session.onError?.call(DownloadError('test error'));
      session.onComplete?.call(1);

      expect(progressCalled, isTrue);
      expect(errorCalled, isTrue);
      expect(completeCalled, isTrue);
    });
  });

  group('DownloadError Tests', () {
    test('should create error with message and timestamp', () {
      final error = DownloadError('Test error');

      expect(error.message, equals('Test error'));
      expect(error.timestamp, isA<DateTime>());
      expect(error.timestamp.isBefore(DateTime.now().add(Duration(seconds: 1))),
          isTrue);
    });

    test('should create errors with different messages', () {
      final error1 = DownloadError('Network error');
      final error2 = DownloadError('File not found');

      expect(error1.message, equals('Network error'));
      expect(error2.message, equals('File not found'));
      expect(error1.message, isNot(equals(error2.message)));
    });
  });

  group('DownloadStatus Tests', () {
    test('should have all required status values', () {
      expect(DownloadStatus.values.length, equals(6));
      expect(DownloadStatus.values.contains(DownloadStatus.pending), isTrue);
      expect(DownloadStatus.values.contains(DownloadStatus.active), isTrue);
      expect(DownloadStatus.values.contains(DownloadStatus.paused), isTrue);
      expect(DownloadStatus.values.contains(DownloadStatus.completed), isTrue);
      expect(DownloadStatus.values.contains(DownloadStatus.failed), isTrue);
      expect(DownloadStatus.values.contains(DownloadStatus.cancelled), isTrue);
    });
  });
}

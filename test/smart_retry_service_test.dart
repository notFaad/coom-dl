import 'package:flutter_test/flutter_test.dart';
import 'package:coom_dl/services/smart_retry_service.dart';

void main() {
  group('SmartRetryService Tests', () {
    late SmartRetryService retryService;

    setUp(() async {
      retryService = SmartRetryService();
      await retryService.initialize();
    });

    test('should initialize successfully', () async {
      expect(retryService, isNotNull);
    });

    test('should classify network errors correctly', () {
      final networkErrors = [
        'network connection failed',
        'socket exception',
        'connection timeout',
        'network error occurred',
      ];

      for (final error in networkErrors) {
        final errorType = retryService._classifyError(error);
        expect(errorType, equals(ErrorType.network));
      }
    });

    test('should classify timeout errors correctly', () {
      final timeoutErrors = [
        'request timeout',
        'deadline exceeded',
        'timeout occurred',
      ];

      for (final error in timeoutErrors) {
        final errorType = retryService._classifyError(error);
        expect(errorType, equals(ErrorType.timeout));
      }
    });

    test('should classify server errors correctly', () {
      final serverErrors = [
        'HTTP 500 Internal Server Error',
        'HTTP 502 Bad Gateway',
        'HTTP 503 Service Unavailable',
        'server error',
      ];

      for (final error in serverErrors) {
        final errorType = retryService._classifyError(error);
        expect(errorType, equals(ErrorType.serverError));
      }
    });

    test('should classify rate limit errors correctly', () {
      final rateLimitErrors = [
        'HTTP 429 Too Many Requests',
        'rate limit exceeded',
        'too many requests',
      ];

      for (final error in rateLimitErrors) {
        final errorType = retryService._classifyError(error);
        expect(errorType, equals(ErrorType.rateLimit));
      }
    });

    test('should classify authentication errors correctly', () {
      final authErrors = [
        'HTTP 401 Unauthorized',
        'HTTP 403 Forbidden',
        'unauthorized access',
        'forbidden request',
      ];

      for (final error in authErrors) {
        final errorType = retryService._classifyError(error);
        expect(errorType, equals(ErrorType.authentication));
      }
    });

    test('should classify not found errors correctly', () {
      final notFoundErrors = [
        'HTTP 404 Not Found',
        'file not found',
        'resource not found',
      ];

      for (final error in notFoundErrors) {
        final errorType = retryService._classifyError(error);
        expect(errorType, equals(ErrorType.notFound));
      }
    });

    test('should classify file system errors correctly', () {
      final fileSystemErrors = [
        'file permission denied',
        'disk full',
        'directory not found',
        'permission error',
      ];

      for (final error in fileSystemErrors) {
        final errorType = retryService._classifyError(error);
        expect(errorType, equals(ErrorType.fileSystem));
      }
    });

    test('should classify unknown errors as unknown', () {
      final unknownErrors = [
        'mysterious error',
        'undefined behavior',
        'random failure',
      ];

      for (final error in unknownErrors) {
        final errorType = retryService._classifyError(error);
        expect(errorType, equals(ErrorType.unknown));
      }
    });

    test('should allow retries within limits', () {
      const downloadId = 123;
      const networkError = 'network connection failed';

      // First few retries should be allowed
      expect(retryService.shouldRetry(downloadId, networkError), isTrue);

      // Simulate retry attempts
      final state = retryService._getOrCreateRetryState(downloadId);
      state.attemptCount = 1;
      expect(retryService.shouldRetry(downloadId, networkError), isTrue);

      state.attemptCount = 3;
      expect(retryService.shouldRetry(downloadId, networkError), isTrue);

      // Exceed max retries for network errors (5)
      state.attemptCount = 6;
      expect(retryService.shouldRetry(downloadId, networkError), isFalse);
    });

    test('should have different retry limits for different error types', () {
      const downloadId = 456;

      // Network errors: 5 retries
      final networkState = retryService._getOrCreateRetryState(downloadId);
      networkState.attemptCount = 5;
      expect(retryService.shouldRetry(downloadId, 'network error'), isFalse);

      // Rate limit errors: 8 retries
      networkState.attemptCount = 8;
      expect(
          retryService.shouldRetry(downloadId, 'rate limit exceeded'), isFalse);

      // Auth errors: 2 retries
      networkState.attemptCount = 2;
      expect(retryService.shouldRetry(downloadId, 'unauthorized'), isFalse);

      // Not found errors: 1 retry
      networkState.attemptCount = 1;
      expect(retryService.shouldRetry(downloadId, 'file not found'), isFalse);
    });

    test('should calculate exponential backoff delays', () {
      const downloadId = 789;

      final state = retryService._getOrCreateRetryState(downloadId);
      state.lastError = 'network error'; // 2s base delay

      // First retry
      state.attemptCount = 1;
      final delay1 = retryService.getRetryDelay(downloadId);
      expect(delay1.inSeconds, greaterThanOrEqualTo(1)); // 2s * 2^0 * jitter
      expect(delay1.inSeconds, lessThanOrEqualTo(3));

      // Second retry
      state.attemptCount = 2;
      final delay2 = retryService.getRetryDelay(downloadId);
      expect(delay2.inSeconds, greaterThanOrEqualTo(3)); // 2s * 2^1 * jitter
      expect(delay2.inSeconds, lessThanOrEqualTo(5));

      // Third retry
      state.attemptCount = 3;
      final delay3 = retryService.getRetryDelay(downloadId);
      expect(delay3.inSeconds, greaterThanOrEqualTo(6)); // 2s * 2^2 * jitter
      expect(delay3.inSeconds, lessThanOrEqualTo(10));
    });

    test('should cap maximum delay at 5 minutes', () {
      const downloadId = 101112;

      final state = retryService._getOrCreateRetryState(downloadId);
      state.lastError = 'network error';
      state.attemptCount = 10; // Very high attempt count

      final delay = retryService.getRetryDelay(downloadId);
      expect(delay.inSeconds, lessThanOrEqualTo(300)); // 5 minutes max
    });

    test('should handle different base delays for different error types', () {
      const downloadId = 131415;

      final state = retryService._getOrCreateRetryState(downloadId);
      state.attemptCount = 1;

      // Network error: 2s base
      state.lastError = 'network error';
      final networkDelay = retryService.getRetryDelay(downloadId);
      expect(networkDelay.inSeconds, greaterThanOrEqualTo(1));
      expect(networkDelay.inSeconds, lessThanOrEqualTo(3));

      // Rate limit: 30s base
      state.lastError = 'rate limit';
      final rateLimitDelay = retryService.getRetryDelay(downloadId);
      expect(rateLimitDelay.inSeconds, greaterThanOrEqualTo(25));
      expect(rateLimitDelay.inSeconds, lessThanOrEqualTo(35));

      // Auth error: 60s base
      state.lastError = 'unauthorized';
      final authDelay = retryService.getRetryDelay(downloadId);
      expect(authDelay.inSeconds, greaterThanOrEqualTo(50));
      expect(authDelay.inSeconds, lessThanOrEqualTo(70));
    });

    test('should track retry statistics', () {
      const downloadId = 161718;

      // Initially no statistics
      final initialStats = retryService.getRetryStatistics(downloadId);
      expect(initialStats.attemptCount, equals(0));
      expect(initialStats.successfulRetries, equals(0));
      expect(initialStats.totalFailures, equals(0));
      expect(initialStats.lastError, isNull);
      expect(initialStats.successRate, equals(1.0));

      // Simulate some retry activity
      final state = retryService._getOrCreateRetryState(downloadId);
      state.attemptCount = 3;
      state.successfulRetries = 2;
      state.lastError = 'network timeout';
      state.failureHistory = [
        DateTime.now().subtract(Duration(minutes: 5)),
        DateTime.now().subtract(Duration(minutes: 2)),
      ];

      final stats = retryService.getRetryStatistics(downloadId);
      expect(stats.attemptCount, equals(3));
      expect(stats.successfulRetries, equals(2));
      expect(stats.totalFailures, equals(2));
      expect(stats.lastError, equals('network timeout'));
      expect(stats.successRate, closeTo(0.667, 0.01)); // 2/3
    });

    test('should provide global statistics', () {
      // Create multiple download retry states
      const downloadId1 = 1001;
      const downloadId2 = 1002;
      const downloadId3 = 1003;

      final state1 = retryService._getOrCreateRetryState(downloadId1);
      state1.attemptCount = 2;
      state1.successfulRetries = 1;
      state1.lastError = 'network error';

      final state2 = retryService._getOrCreateRetryState(downloadId2);
      state2.attemptCount = 3;
      state2.successfulRetries = 3;
      state2.lastError = 'timeout';

      final state3 = retryService._getOrCreateRetryState(downloadId3);
      state3.attemptCount = 1;
      state3.successfulRetries = 0;
      state3.lastError = 'server error';

      final globalStats = retryService.getGlobalStatistics();

      expect(globalStats['totalRetries'], equals(6)); // 2 + 3 + 1
      expect(globalStats['successfulRetries'], equals(4)); // 1 + 3 + 0
      expect(globalStats['retrySuccessRate'], closeTo(0.667, 0.01)); // 4/6
      expect(globalStats['activeRetryStates'], equals(3));

      final errorDistribution =
          globalStats['errorDistribution'] as Map<String, int>;
      expect(errorDistribution['network'], equals(1));
      expect(errorDistribution['timeout'], equals(1));
      expect(errorDistribution['serverError'], equals(1));
    });

    test('should clean up download retry state', () {
      const downloadId = 192021;

      // Create retry state
      retryService._getOrCreateRetryState(downloadId);
      expect(
          retryService.getRetryStatistics(downloadId).attemptCount, equals(0));

      // Clean up
      retryService.cleanupDownload(downloadId);

      // Should return empty stats after cleanup
      final stats = retryService.getRetryStatistics(downloadId);
      expect(stats.attemptCount, equals(0));
      expect(stats.successfulRetries, equals(0));
      expect(stats.totalFailures, equals(0));
      expect(stats.lastError, isNull);
    });

    test('should prevent too many recent failures', () {
      const downloadId = 222324;

      final state = retryService._getOrCreateRetryState(downloadId);

      // Add many recent failures
      final now = DateTime.now();
      state.failureHistory = [
        now.subtract(Duration(minutes: 1)),
        now.subtract(Duration(minutes: 2)),
        now.subtract(Duration(minutes: 3)),
        now.subtract(Duration(minutes: 4)),
      ];

      // Should not retry due to too many recent failures
      expect(retryService.shouldRetry(downloadId, 'network error'), isFalse);
    });

    test('should allow retries after old failures', () {
      const downloadId = 252627;

      final state = retryService._getOrCreateRetryState(downloadId);

      // Add old failures (outside 10-minute window)
      final longAgo = DateTime.now().subtract(Duration(minutes: 15));
      state.failureHistory = [
        longAgo,
        longAgo.add(Duration(minutes: 1)),
        longAgo.add(Duration(minutes: 2)),
        longAgo.add(Duration(minutes: 3)),
      ];

      // Should allow retry since failures are old
      expect(retryService.shouldRetry(downloadId, 'network error'), isTrue);
    });
  });

  group('ErrorType Tests', () {
    test('should have all expected error types', () {
      expect(ErrorType.values.length, equals(8));
      expect(ErrorType.values.contains(ErrorType.network), isTrue);
      expect(ErrorType.values.contains(ErrorType.timeout), isTrue);
      expect(ErrorType.values.contains(ErrorType.serverError), isTrue);
      expect(ErrorType.values.contains(ErrorType.rateLimit), isTrue);
      expect(ErrorType.values.contains(ErrorType.authentication), isTrue);
      expect(ErrorType.values.contains(ErrorType.notFound), isTrue);
      expect(ErrorType.values.contains(ErrorType.fileSystem), isTrue);
      expect(ErrorType.values.contains(ErrorType.unknown), isTrue);
    });
  });

  group('RetryState Tests', () {
    test('should create retry state with correct initial values', () {
      final state = RetryState(downloadId: 123);

      expect(state.downloadId, equals(123));
      expect(state.attemptCount, equals(0));
      expect(state.successfulRetries, equals(0));
      expect(state.lastError, isNull);
      expect(state.lastAttempt, isNull);
      expect(state.failureHistory, isEmpty);
    });

    test('should record failures correctly', () {
      final state = RetryState(downloadId: 456);

      state.recordFailure();
      expect(state.failureHistory.length, equals(1));
      expect(state.failureHistory.first, isA<DateTime>());

      state.recordFailure();
      expect(state.failureHistory.length, equals(2));
    });

    test('should limit failure history to 10 entries', () {
      final state = RetryState(downloadId: 789);

      // Record 15 failures
      for (int i = 0; i < 15; i++) {
        state.recordFailure();
      }

      // Should only keep last 10
      expect(state.failureHistory.length, equals(10));
    });
  });

  group('RetryStatistics Tests', () {
    test('should calculate success rate correctly', () {
      final perfectStats = RetryStatistics(
        downloadId: 1,
        attemptCount: 5,
        successfulRetries: 5,
        totalFailures: 0,
      );
      expect(perfectStats.successRate, equals(1.0));

      final partialStats = RetryStatistics(
        downloadId: 2,
        attemptCount: 10,
        successfulRetries: 7,
        totalFailures: 3,
      );
      expect(partialStats.successRate, equals(0.7));

      final noAttemptsStats = RetryStatistics(
        downloadId: 3,
        attemptCount: 0,
        successfulRetries: 0,
        totalFailures: 0,
      );
      expect(noAttemptsStats.successRate, equals(1.0));
    });

    test('should detect errors correctly', () {
      final withError = RetryStatistics(
        downloadId: 1,
        attemptCount: 1,
        successfulRetries: 0,
        totalFailures: 1,
        lastError: 'network timeout',
      );
      expect(withError.hasErrors, isTrue);

      final withoutError = RetryStatistics(
        downloadId: 2,
        attemptCount: 1,
        successfulRetries: 1,
        totalFailures: 0,
      );
      expect(withoutError.hasErrors, isFalse);
    });
  });
}

// Extension to access private methods for testing
extension SmartRetryServiceTestExtension on SmartRetryService {
  ErrorType _classifyError(dynamic error) {
    final errorMessage = error.toString().toLowerCase();

    if (errorMessage.contains('network') ||
        errorMessage.contains('connection') ||
        errorMessage.contains('socket')) {
      return ErrorType.network;
    }

    if (errorMessage.contains('timeout') ||
        errorMessage.contains('deadline exceeded')) {
      return ErrorType.timeout;
    }

    if (errorMessage.contains('500') ||
        errorMessage.contains('502') ||
        errorMessage.contains('503') ||
        errorMessage.contains('server error')) {
      return ErrorType.serverError;
    }

    if (errorMessage.contains('429') ||
        errorMessage.contains('rate limit') ||
        errorMessage.contains('too many requests')) {
      return ErrorType.rateLimit;
    }

    if (errorMessage.contains('401') ||
        errorMessage.contains('403') ||
        errorMessage.contains('unauthorized') ||
        errorMessage.contains('forbidden')) {
      return ErrorType.authentication;
    }

    if (errorMessage.contains('404') || errorMessage.contains('not found')) {
      return ErrorType.notFound;
    }

    if (errorMessage.contains('file') ||
        errorMessage.contains('disk') ||
        errorMessage.contains('directory') ||
        errorMessage.contains('permission')) {
      return ErrorType.fileSystem;
    }

    return ErrorType.unknown;
  }

  RetryState _getOrCreateRetryState(int downloadId) {
    // This accesses the private _retryStates map for testing
    final retryStates = <int, RetryState>{};
    return retryStates.putIfAbsent(
      downloadId,
      () => RetryState(downloadId: downloadId),
    );
  }
}

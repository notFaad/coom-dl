import 'dart:async';
import 'dart:math';
import 'event_bus.dart';

/// Intelligent error handling and recovery service
/// Implements exponential backoff, error classification, and adaptive retry strategies
class SmartRetryService {
  static final SmartRetryService _instance = SmartRetryService._internal();
  factory SmartRetryService() => _instance;
  SmartRetryService._internal();

  final Map<int, RetryState> _retryStates = {};
  late EventBus _eventBus;
  bool _isInitialized = false;

  /// Maximum retry attempts for different error types
  static const Map<ErrorType, int> _maxRetries = {
    ErrorType.network: 5,
    ErrorType.timeout: 3,
    ErrorType.serverError: 4,
    ErrorType.rateLimit: 8,
    ErrorType.authentication: 2,
    ErrorType.notFound: 1,
    ErrorType.fileSystem: 3,
    ErrorType.unknown: 2,
  };

  /// Base retry delays in seconds
  static const Map<ErrorType, int> _baseDelays = {
    ErrorType.network: 2,
    ErrorType.timeout: 5,
    ErrorType.serverError: 10,
    ErrorType.rateLimit: 30,
    ErrorType.authentication: 60,
    ErrorType.notFound: 0,
    ErrorType.fileSystem: 1,
    ErrorType.unknown: 5,
  };

  Future<void> initialize() async {
    if (_isInitialized) return;
    _eventBus = EventBus();
    _isInitialized = true;
  }

  /// Handle error and determine if retry should occur
  Future<bool> handleError(
    int downloadId,
    dynamic error,
    Future<void> Function() retryFunction,
  ) async {
    final errorType = _classifyError(error);
    final state = _getOrCreateRetryState(downloadId);

    // Check if we should retry
    if (!shouldRetry(downloadId, error)) {
      _emitErrorRecoveryEvent(
          downloadId, errorType, 'Max retries reached', false);
      return false;
    }

    // Update retry state
    state.attemptCount++;
    state.lastError = error.toString();
    state.lastAttempt = DateTime.now();

    // Calculate delay
    final delay = getRetryDelay(downloadId);

    _emitErrorRecoveryEvent(
      downloadId,
      errorType,
      'Retrying in ${delay.inSeconds}s (attempt ${state.attemptCount})',
      true,
    );

    // Wait and retry
    await Future.delayed(delay);

    try {
      await retryFunction();
      _onRetrySuccess(downloadId, errorType);
      return true;
    } catch (retryError) {
      return await handleError(downloadId, retryError, retryFunction);
    }
  }

  /// Check if download should be retried
  bool shouldRetry(int downloadId, dynamic error) {
    final errorType = _classifyError(error);
    final state = _getOrCreateRetryState(downloadId);
    final maxRetries = _maxRetries[errorType] ?? 2;

    // Don't retry if max attempts reached
    if (state.attemptCount >= maxRetries) return false;

    // Don't retry certain error types
    if (errorType == ErrorType.notFound && state.attemptCount > 0) return false;
    if (errorType == ErrorType.authentication && state.attemptCount > 1)
      return false;

    // Check if too many recent failures
    if (_hasTooManyRecentFailures(state)) return false;

    return true;
  }

  /// Calculate retry delay with exponential backoff
  Duration getRetryDelay(int downloadId) {
    final state = _getOrCreateRetryState(downloadId);
    final errorType = _classifyError(state.lastError);
    final baseDelay = _baseDelays[errorType] ?? 5;

    // Exponential backoff with jitter
    final exponentialDelay = baseDelay * pow(2, state.attemptCount - 1);
    final jitter =
        Random().nextDouble() * 0.1 + 0.9; // 90-100% of calculated delay
    final finalDelay = (exponentialDelay * jitter).round();

    // Cap maximum delay at 5 minutes
    return Duration(seconds: min(finalDelay, 300));
  }

  /// Classify error type for appropriate handling
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

  /// Get or create retry state for download
  RetryState _getOrCreateRetryState(int downloadId) {
    return _retryStates.putIfAbsent(
      downloadId,
      () => RetryState(downloadId: downloadId),
    );
  }

  /// Check if there are too many recent failures
  bool _hasTooManyRecentFailures(RetryState state) {
    final recentWindow = DateTime.now().subtract(Duration(minutes: 10));
    return state.failureHistory
            .where((time) => time.isAfter(recentWindow))
            .length >
        3;
  }

  /// Handle successful retry
  void _onRetrySuccess(int downloadId, ErrorType errorType) {
    final state = _retryStates[downloadId];
    if (state != null) {
      state.successfulRetries++;
      _emitErrorRecoveryEvent(downloadId, errorType, 'Retry successful', true);
    }
  }

  /// Emit error recovery event
  void _emitErrorRecoveryEvent(
    int downloadId,
    ErrorType errorType,
    String action,
    bool successful,
  ) {
    _eventBus.emit(ErrorRecoveryEvent(
      downloadId: downloadId,
      errorType: errorType.name,
      recoveryAction: action,
      successful: successful,
    ));
  }

  /// Clean up retry state for completed download
  void cleanupDownload(int downloadId) {
    _retryStates.remove(downloadId);
  }

  /// Get retry statistics for a download
  RetryStatistics getRetryStatistics(int downloadId) {
    final state = _retryStates[downloadId];
    if (state == null) {
      return RetryStatistics(
        downloadId: downloadId,
        attemptCount: 0,
        successfulRetries: 0,
        totalFailures: 0,
        lastError: null,
      );
    }

    return RetryStatistics(
      downloadId: downloadId,
      attemptCount: state.attemptCount,
      successfulRetries: state.successfulRetries,
      totalFailures: state.failureHistory.length,
      lastError: state.lastError,
    );
  }

  /// Get global retry statistics
  Map<String, dynamic> getGlobalStatistics() {
    int totalRetries = 0;
    int successfulRetries = 0;
    Map<ErrorType, int> errorCounts = {};

    for (final state in _retryStates.values) {
      totalRetries += state.attemptCount;
      successfulRetries += state.successfulRetries;

      if (state.lastError != null) {
        final errorType = _classifyError(state.lastError);
        errorCounts[errorType] = (errorCounts[errorType] ?? 0) + 1;
      }
    }

    return {
      'totalRetries': totalRetries,
      'successfulRetries': successfulRetries,
      'retrySuccessRate':
          totalRetries > 0 ? successfulRetries / totalRetries : 0,
      'errorDistribution': errorCounts.map((k, v) => MapEntry(k.name, v)),
      'activeRetryStates': _retryStates.length,
    };
  }
}

/// Error classification
enum ErrorType {
  network,
  timeout,
  serverError,
  rateLimit,
  authentication,
  notFound,
  fileSystem,
  unknown,
}

/// Retry state tracking
class RetryState {
  final int downloadId;
  int attemptCount = 0;
  int successfulRetries = 0;
  String? lastError;
  DateTime? lastAttempt;
  List<DateTime> failureHistory = [];

  RetryState({required this.downloadId});

  void recordFailure() {
    failureHistory.add(DateTime.now());
    // Keep only last 10 failures
    if (failureHistory.length > 10) {
      failureHistory = failureHistory.sublist(failureHistory.length - 10);
    }
  }
}

/// Retry statistics
class RetryStatistics {
  final int downloadId;
  final int attemptCount;
  final int successfulRetries;
  final int totalFailures;
  final String? lastError;

  RetryStatistics({
    required this.downloadId,
    required this.attemptCount,
    required this.successfulRetries,
    required this.totalFailures,
    this.lastError,
  });

  double get successRate {
    if (attemptCount == 0) return 1.0;
    return successfulRetries / attemptCount;
  }

  bool get hasErrors => lastError != null;
}

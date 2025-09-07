import 'dart:async';

/// Real-time event bus for download progress and error streaming
/// Provides in-memory communication between components
class EventBus {
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  EventBus._internal();

  final Map<Type, StreamController> _controllers = {};
  final Map<Type, Stream> _streams = {};

  /// Emit an event of type T
  void emit<T extends DownloadEvent>(T event) {
    final controller = _getController<T>();
    if (!controller.isClosed) {
      controller.add(event);
    }
  }

  /// Listen to events of type T
  Stream<T> on<T extends DownloadEvent>() {
    return _getStream<T>().cast<T>();
  }

  /// Get or create a stream controller for type T
  StreamController<T> _getController<T extends DownloadEvent>() {
    if (!_controllers.containsKey(T)) {
      _controllers[T] = StreamController<T>.broadcast();
    }
    return _controllers[T] as StreamController<T>;
  }

  /// Get or create a stream for type T
  Stream<T> _getStream<T extends DownloadEvent>() {
    if (!_streams.containsKey(T)) {
      _streams[T] = _getController<T>().stream;
    }
    return _streams[T] as Stream<T>;
  }

  /// Clean up all streams
  Future<void> dispose() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
    _controllers.clear();
    _streams.clear();
  }
}

/// Base class for all download events
abstract class DownloadEvent {
  final DateTime timestamp;
  DownloadEvent() : timestamp = DateTime.now();
}

/// Download Manager Events
class DownloadManagerEvent extends DownloadEvent {
  final String message;
  DownloadManagerEvent(this.message);

  factory DownloadManagerEvent.initialized() =>
      DownloadManagerEvent('Download Manager initialized');
}

/// Download lifecycle events
class DownloadStartedEvent extends DownloadEvent {
  final int downloadId;
  final String url;
  DownloadStartedEvent(this.downloadId, this.url);
}

class DownloadProgressEvent extends DownloadEvent {
  final int downloadId;
  final DownloadProgress progress;
  DownloadProgressEvent(this.downloadId, this.progress);
}

class DownloadCompletedEvent extends DownloadEvent {
  final int downloadId;
  DownloadCompletedEvent(this.downloadId);
}

class DownloadErrorEvent extends DownloadEvent {
  final int downloadId;
  final String error;
  DownloadErrorEvent(this.downloadId, this.error);
}

class DownloadPausedEvent extends DownloadEvent {
  final int downloadId;
  DownloadPausedEvent(this.downloadId);
}

class DownloadResumedEvent extends DownloadEvent {
  final int downloadId;
  DownloadResumedEvent(this.downloadId);
}

class DownloadCancelledEvent extends DownloadEvent {
  final int downloadId;
  DownloadCancelledEvent(this.downloadId);
}

/// Engine performance events
class EnginePerformanceEvent extends DownloadEvent {
  final String engineName;
  final Duration downloadTime;
  final int bytesDownloaded;
  final bool success;

  EnginePerformanceEvent({
    required this.engineName,
    required this.downloadTime,
    required this.bytesDownloaded,
    required this.success,
  });

  double get speedMbps {
    if (downloadTime.inMilliseconds == 0) return 0;
    return (bytesDownloaded * 8) / (downloadTime.inMilliseconds * 1000);
  }
}

/// Scraper events
class ScraperEvent extends DownloadEvent {
  final String scraperId;
  final String message;
  ScraperEvent(this.scraperId, this.message);
}

class ScraperErrorEvent extends DownloadEvent {
  final String scraperId;
  final String url;
  final String error;
  ScraperErrorEvent(this.scraperId, this.url, this.error);
}

/// System health events
class SystemHealthEvent extends DownloadEvent {
  final double cpuUsage;
  final double memoryUsage;
  final int activeDownloads;

  SystemHealthEvent({
    required this.cpuUsage,
    required this.memoryUsage,
    required this.activeDownloads,
  });
}

/// Error recovery events
class ErrorRecoveryEvent extends DownloadEvent {
  final int downloadId;
  final String errorType;
  final String recoveryAction;
  final bool successful;

  ErrorRecoveryEvent({
    required this.downloadId,
    required this.errorType,
    required this.recoveryAction,
    required this.successful,
  });
}

/// Download progress data structure
class DownloadProgress {
  final int downloadId;
  final int completedFiles;
  final int totalFiles;
  final double currentFileProgress;
  final int bytesDownloaded;
  final int totalBytes;
  final double speedBps;
  final Duration estimatedTimeRemaining;

  DownloadProgress({
    required this.downloadId,
    required this.completedFiles,
    required this.totalFiles,
    required this.currentFileProgress,
    this.bytesDownloaded = 0,
    this.totalBytes = 0,
    this.speedBps = 0,
    this.estimatedTimeRemaining = Duration.zero,
  });

  double get overallProgress {
    if (totalFiles == 0) return 0.0;
    return (completedFiles + currentFileProgress) / totalFiles;
  }

  double get percentageComplete => overallProgress * 100;

  String get formattedSpeed {
    if (speedBps < 1024) return '${speedBps.toStringAsFixed(1)} B/s';
    if (speedBps < 1024 * 1024)
      return '${(speedBps / 1024).toStringAsFixed(1)} KB/s';
    return '${(speedBps / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  String get formattedETA {
    if (estimatedTimeRemaining.inSeconds < 60) {
      return '${estimatedTimeRemaining.inSeconds}s';
    } else if (estimatedTimeRemaining.inMinutes < 60) {
      return '${estimatedTimeRemaining.inMinutes}m ${estimatedTimeRemaining.inSeconds % 60}s';
    } else {
      final hours = estimatedTimeRemaining.inHours;
      final minutes = estimatedTimeRemaining.inMinutes % 60;
      return '${hours}h ${minutes}m';
    }
  }
}

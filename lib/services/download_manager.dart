import 'dart:async';
import 'package:isar/isar.dart';
import '../data/models/DlTask.dart';
import '../scrapers/ScraperManager.dart';
import '../services/downloadTaskServices.dart';
import 'event_bus.dart';
import 'smart_retry_service.dart';

/// Download engines available
enum DownloadEngine {
  recooma('Recooma Engine'),
  galleryDl('Gallery-dl Engine'),
  cyberdrop('Cyberdrop Engine'),
  auto('Auto Select'); // Intelligent engine selection

  const DownloadEngine(this.displayName);
  final String displayName;
}

/// Download status enum that matches existing workflow
enum DownloadStatus {
  pending,
  active,
  paused,
  completed,
  failed,
  cancelled,
}

/// Unified Download Manager that coordinates all download engines and scrapers
/// This is the central hub for all download operations
class DownloadManager {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();

  late Isar _isar;
  late EventBus _eventBus;
  late SmartRetryService _retryService;
  late ScraperManager _scraperManager;

  bool _isInitialized = false;
  final Map<int, DownloadSession> _activeSessions = {};

  /// Initialize the download manager
  Future<void> initialize({
    required Isar isar,
    EventBus? eventBus,
    SmartRetryService? retryService,
    ScraperManager? scraperManager,
  }) async {
    if (_isInitialized) return;

    _isar = isar;
    _eventBus = eventBus ?? EventBus();
    _retryService = retryService ?? SmartRetryService();
    _scraperManager = scraperManager ?? ScraperManager();

    await _retryService.initialize();
    await _scraperManager.initialize();

    _isInitialized = true;
    _eventBus.emit(DownloadManagerEvent.initialized());
  }

  /// Start a new download with intelligent engine selection
  Future<int> startDownload({
    required String url,
    required String downloadPath,
    DownloadEngine? preferredEngine,
    Map<String, dynamic>? engineConfig,
    Function(DownloadProgress)? onProgress,
    Function(DownloadError)? onError,
    Function(int downloadId)? onComplete,
  }) async {
    if (!_isInitialized) {
      throw StateError('DownloadManager not initialized');
    }

    // Check for existing active downloads with the same URL to prevent duplication
    final existingActiveTask = await _isar.downloadTasks
        .filter()
        .urlEqualTo(url)
        .and()
        .isDownloadingEqualTo(true)
        .findFirst();

    if (existingActiveTask != null) {
      print(
          'Download already active for URL: $url (Task ID: ${existingActiveTask.id})');
      return existingActiveTask.id; // Return existing task ID
    }

    // Check if there's a queued task for this URL
    final existingQueuedTask = await _isar.downloadTasks
        .filter()
        .urlEqualTo(url)
        .and()
        .isQueueEqualTo(true)
        .findFirst();

    if (existingQueuedTask != null) {
      print(
          'Download already queued for URL: $url (Task ID: ${existingQueuedTask.id})');
      return existingQueuedTask.id; // Return existing task ID
    }

    // Create download task using existing model
    final downloadTask = DownloadTask()
      ..url = url
      ..storagePath = downloadPath
      ..isPaused = false
      ..isQueue = false
      ..isCanceled = false
      ..isCompleted = false
      ..isDownloading = true
      ..isFailed = false;

    await _isar.writeTxn(() async {
      await _isar.downloadTasks.put(downloadTask);
    });

    // Check for duplicate session
    if (_activeSessions.containsKey(downloadTask.id)) {
      print('Session already exists for task ${downloadTask.id}');
      return downloadTask.id;
    }

    // Create download session
    final session = DownloadSession(
      downloadId: downloadTask.id,
      url: url,
      downloadPath: downloadPath,
      engine: preferredEngine ?? await _selectBestEngine(url),
      onProgress: onProgress,
      onError: onError,
      onComplete: onComplete,
    );

    _activeSessions[downloadTask.id] = session;

    // Start download in background
    _executeDownload(session);

    _eventBus.emit(DownloadStartedEvent(downloadTask.id, url));

    return downloadTask.id;
  }

  /// Execute download with coordinated engine and scraper system
  Future<void> _executeDownload(DownloadSession session) async {
    try {
      await _updateDownloadStatus(session.downloadId, isDownloading: true);

      // Check if we have a community scraper for this URL first
      if (_scraperManager.canHandle(session.url)) {
        try {
          // Try scraper with timeout
          await _executeWithScraper(session).timeout(Duration(seconds: 30));
        } catch (e) {
          print('Scraper execution failed or timed out for ${session.url}: $e');
          // Fallback to traditional engines
          await _executeWithEngine(session);
        }
      } else {
        // No scraper available, use traditional engines directly
        await _executeWithEngine(session);
      }
    } catch (error) {
      await _handleDownloadError(session, error);
    }
  }

  /// Execute download using community scraper system
  Future<void> _executeWithScraper(DownloadSession session) async {
    try {
      final result = await _scraperManager.executeScraping(
        url: session.url,
        downloadId: session.downloadId,
        isar: _isar,
        onProgress: (progress) {
          // Handle progress updates from scraper
          session.completedFiles = progress['completed'] ?? 0;
          session.totalFiles = progress['total'] ?? 0;
          session.currentProgress = progress['current_progress'] ?? 0.0;
          _notifyProgress(session);
        },
        onLog: (message) {
          // Log scraper messages (remove print in production)
          // print('Scraper: $message');
        },
        shouldCancel: () => session.isCancelled || session.isPaused,
      );

      if (result['success'] == true) {
        // Scraper results are already stored in database
        await _completeDownload(session);
      } else {
        throw Exception(
            'Scraping failed: ${result['error'] ?? 'Unknown error'}');
      }
    } catch (error) {
      // Fallback to traditional engines if scraper fails
      await _executeWithEngine(session);
    }
  }

  /// Execute download using traditional engines
  Future<void> _executeWithEngine(DownloadSession session) async {
    switch (session.engine) {
      case DownloadEngine.recooma:
        await _executeRecoomaEngine(session);
        break;
      case DownloadEngine.galleryDl:
        await _executeGalleryDlEngine(session);
        break;
      case DownloadEngine.cyberdrop:
        await _executeCyberdropEngine(session);
        break;
      case DownloadEngine.auto:
        // This should have been resolved in _selectBestEngine
        throw StateError('Auto engine should have been resolved');
    }
  }

  /// Intelligent engine selection based on URL and performance metrics
  Future<DownloadEngine> _selectBestEngine(String url) async {
    // URL-based routing
    if (RegExp(r'coomer\.(party|su|st)').hasMatch(url)) {
      return DownloadEngine.recooma;
    }
    if (RegExp(r'kemono\.(party|su|cr)').hasMatch(url)) {
      return DownloadEngine.recooma;
    }
    if (RegExp(r'cyberdrop\.').hasMatch(url)) {
      return DownloadEngine.cyberdrop;
    }

    // Default to gallery-dl for unknown sites
    return DownloadEngine.galleryDl;
  }

  /// Handle download errors with smart retry
  Future<void> _handleDownloadError(
      DownloadSession session, dynamic error) async {
    final shouldRetry = _retryService.shouldRetry(session.downloadId, error);

    if (shouldRetry) {
      final retryDelay = _retryService.getRetryDelay(session.downloadId);
      await Future.delayed(retryDelay);
      await _executeDownload(session);
    } else {
      await _updateDownloadStatus(session.downloadId,
          isFailed: true, isDownloading: false);
      _eventBus.emit(DownloadErrorEvent(session.downloadId, error.toString()));
      session.onError?.call(DownloadError(error.toString()));
      _activeSessions.remove(session.downloadId);
    }
  }

  /// Update download status in database using existing model
  Future<void> _updateDownloadStatus(
    int downloadId, {
    bool? isPaused,
    bool? isCompleted,
    bool? isFailed,
    bool? isDownloading,
    bool? isCanceled,
  }) async {
    await _isar.writeTxn(() async {
      final task = await _isar.downloadTasks.get(downloadId);
      if (task != null) {
        if (isPaused != null) task.isPaused = isPaused;
        if (isCompleted != null) task.isCompleted = isCompleted;
        if (isFailed != null) task.isFailed = isFailed;
        if (isDownloading != null) task.isDownloading = isDownloading;
        if (isCanceled != null) task.isCanceled = isCanceled;
        await _isar.downloadTasks.put(task);
      }
    });
  }

  /// Complete download successfully
  Future<void> _completeDownload(DownloadSession session) async {
    await _updateDownloadStatus(
      session.downloadId,
      isCompleted: true,
      isDownloading: false,
    );
    _eventBus.emit(DownloadCompletedEvent(session.downloadId));
    session.onComplete?.call(session.downloadId);
    _activeSessions.remove(session.downloadId);
  }

  /// Notify progress to listeners
  void _notifyProgress(DownloadSession session) {
    final progress = DownloadProgress(
      downloadId: session.downloadId,
      completedFiles: session.completedFiles,
      totalFiles: session.totalFiles,
      currentFileProgress: session.currentProgress,
    );

    _eventBus.emit(DownloadProgressEvent(session.downloadId, progress));
    session.onProgress?.call(progress);
  }

  /// Engine-specific implementations
  Future<void> _executeRecoomaEngine(DownloadSession session) async {
    // Use the original DownloadTaskServices for backward compatibility
    final downloadTask = await _isar.downloadTasks.get(session.downloadId);
    if (downloadTask == null) {
      throw Exception('Download task not found: ${session.downloadId}');
    }

    try {
      // Import and use the original DownloadTaskServices
      final originalService = DownloadTaskServices(task: downloadTask);

      // Create temporary stream controllers to bridge with the new system
      final logController = StreamController<Map<int, dynamic>>();
      final completeController = StreamController<Map<String, dynamic>>();

      // Listen to original service logs and forward them
      logController.stream.listen((logs) {
        // Convert old log format to new progress format
        for (final entry in logs.entries) {
          final logData = entry.value;
          if (logData is Map<String, dynamic>) {
            session.updateFromLegacyLog(logData);
            _notifyProgress(session);
          }
        }
      });

      // Listen to completion events
      completeController.stream.listen((data) {
        _completeDownload(session);
      });

      // Start the original download
      await originalService.startDownload(
        _isar,
        completeController.sink,
        logController.sink,
        0,
      );
    } catch (error) {
      throw Exception('Recooma engine failed: $error');
    }
  }

  Future<void> _executeGalleryDlEngine(DownloadSession session) async {
    // Implement gallery-dl integration
    throw UnimplementedError('Gallery-dl engine integration pending');
  }

  Future<void> _executeCyberdropEngine(DownloadSession session) async {
    // Implement cyberdrop engine integration
    throw UnimplementedError('Cyberdrop engine integration pending');
  }

  /// Pause download
  Future<void> pauseDownload(int downloadId) async {
    final session = _activeSessions[downloadId];
    if (session != null) {
      session.isPaused = true;
      await _updateDownloadStatus(downloadId,
          isPaused: true, isDownloading: false);
      _eventBus.emit(DownloadPausedEvent(downloadId));
    }
  }

  /// Resume download
  Future<void> resumeDownload(int downloadId) async {
    final session = _activeSessions[downloadId];
    if (session != null) {
      session.isPaused = false;
      await _updateDownloadStatus(downloadId,
          isPaused: false, isDownloading: true);
      _eventBus.emit(DownloadResumedEvent(downloadId));
    }
  }

  /// Cancel download
  Future<void> cancelDownload(int downloadId) async {
    final session = _activeSessions[downloadId];
    if (session != null) {
      session.isCancelled = true;
      await _updateDownloadStatus(downloadId,
          isCanceled: true, isDownloading: false);
      _eventBus.emit(DownloadCancelledEvent(downloadId));
      _activeSessions.remove(downloadId);
    }
  }

  /// Get active downloads
  List<DownloadSession> get activeDownloads => _activeSessions.values.toList();

  /// Clean up resources
  Future<void> dispose() async {
    for (final session in _activeSessions.values) {
      session.isCancelled = true;
    }
    _activeSessions.clear();
    await _eventBus.dispose();
  }
}

/// Download session tracking
class DownloadSession {
  final int downloadId;
  final String url;
  final String downloadPath;
  final DownloadEngine engine;
  final Function(DownloadProgress)? onProgress;
  final Function(DownloadError)? onError;
  final Function(int)? onComplete;

  int completedFiles = 0;
  int totalFiles = 0;
  double currentProgress = 0.0;
  bool isPaused = false;
  bool isCancelled = false;

  DownloadSession({
    required this.downloadId,
    required this.url,
    required this.downloadPath,
    required this.engine,
    this.onProgress,
    this.onError,
    this.onComplete,
  });

  /// Update session progress from legacy log format
  void updateFromLegacyLog(Map<String, dynamic> logData) {
    final status = logData['status'] ?? '';

    if (status == 'ok') {
      completedFiles++;
    } else if (status == 'progress') {
      currentProgress = (logData['progress'] ?? 0.0).toDouble();
    } else if (status == 'total') {
      totalFiles = (logData['total'] ?? 0).toInt();
    }

    // Update overall progress
    if (totalFiles > 0) {
      currentProgress = completedFiles / totalFiles;
    }
  }
}

/// Download error wrapper
class DownloadError {
  final String message;
  final DateTime timestamp;

  DownloadError(this.message) : timestamp = DateTime.now();
}

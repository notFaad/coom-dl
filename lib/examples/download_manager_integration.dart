import 'dart:async';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../services/download_manager.dart';
import '../services/event_bus.dart';

/// Example integration of the new Download Manager with existing UI
/// This shows how to transition from the current CybCrawl system to the unified manager
class DownloadManagerIntegration {
  static late DownloadManager _downloadManager;
  static late EventBus _eventBus;

  /// Initialize the Download Manager (call this in main.dart or app startup)
  static Future<void> initialize(Isar isar) async {
    _downloadManager = DownloadManager();
    _eventBus = EventBus();

    await _downloadManager.initialize(isar: isar);

    // Set up global event listeners
    _setupEventListeners();

    print('Download Manager initialized successfully');
  }

  /// Set up event listeners for real-time updates
  static void _setupEventListeners() {
    // Listen to download progress events
    _eventBus.on<DownloadProgressEvent>().listen((event) {
      print(
          'Download ${event.downloadId} progress: ${event.progress.percentageComplete.toStringAsFixed(1)}%');
      // Update UI with progress
    });

    // Listen to download completion events
    _eventBus.on<DownloadCompletedEvent>().listen((event) {
      print('Download ${event.downloadId} completed!');
      // Show success notification
    });

    // Listen to download error events
    _eventBus.on<DownloadErrorEvent>().listen((event) {
      print('Download ${event.downloadId} failed: ${event.error}');
      // Show error notification
    });

    // Listen to error recovery events
    _eventBus.on<ErrorRecoveryEvent>().listen((event) {
      print(
          'Download ${event.downloadId} recovery: ${event.recoveryAction} (${event.successful ? 'success' : 'failed'})');
      // Update UI with recovery status
    });
  }

  /// Set up event bridge to connect unified system with existing UI components
  static void setupEventBridge({
    required Function(int downloadId, DownloadProgress progress) onProgress,
    required Function(int downloadId) onComplete,
    required Function(int downloadId, String error) onError,
  }) {
    // Bridge progress events
    _eventBus.on<DownloadProgressEvent>().listen((event) {
      onProgress(event.downloadId, event.progress);
    });

    // Bridge completion events
    _eventBus.on<DownloadCompletedEvent>().listen((event) {
      onComplete(event.downloadId);
    });

    // Bridge error events
    _eventBus.on<DownloadErrorEvent>().listen((event) {
      onError(event.downloadId, event.error);
    });

    // Bridge retry events for additional error information
    _eventBus.on<ErrorRecoveryEvent>().listen((event) {
      if (!event.successful) {
        onError(event.downloadId, 'Recovery failed: ${event.recoveryAction}');
      }
    });
  }

  /// Start a download using the new unified manager
  /// This replaces the current CybCrawl.getFileContent calls
  static Future<int> startDownload({
    required String url,
    required String downloadPath,
    DownloadEngine? preferredEngine,
  }) async {
    return await _downloadManager.startDownload(
      url: url,
      downloadPath: downloadPath,
      preferredEngine: preferredEngine,
      onProgress: (progress) {
        // Real-time progress updates
        print(
            'Progress: ${progress.percentageComplete.toStringAsFixed(1)}% - ${progress.formattedSpeed}');
      },
      onError: (error) {
        // Handle download errors
        print('Download error: ${error.message}');
      },
      onComplete: (downloadId) {
        // Handle completion
        print('Download $downloadId completed successfully');
      },
    );
  }

  /// Integration example for the existing addDownload page
  static Widget buildDownloadButton({
    required String url,
    required String downloadPath,
    required VoidCallback onSuccess,
    required Function(String error) onError,
  }) {
    return ElevatedButton(
      onPressed: () async {
        try {
          await startDownload(
            url: url,
            downloadPath: downloadPath,
            preferredEngine: DownloadEngine.auto, // Let the system choose
          );

          onSuccess();

          // Show snackbar with download started
          // ScaffoldMessenger.of(context).showSnackBar(
          //   SnackBar(content: Text('Download started (ID: $downloadId)')),
          // );
        } catch (error) {
          onError(error.toString());
        }
      },
      child: Text('Start Smart Download'),
    );
  }

  /// Get real-time download statistics
  static Map<String, dynamic> getDownloadStatistics() {
    final activeDownloads = _downloadManager.activeDownloads;

    return {
      'active_downloads': activeDownloads.length,
      'total_files_downloading': activeDownloads
          .map((session) => session.totalFiles)
          .fold(0, (sum, files) => sum + files),
      'completed_files': activeDownloads
          .map((session) => session.completedFiles)
          .fold(0, (sum, files) => sum + files),
      'average_progress': activeDownloads.isEmpty
          ? 0.0
          : activeDownloads
                  .map((session) => session.currentProgress)
                  .reduce((a, b) => a + b) /
              activeDownloads.length,
    };
  }

  /// Control downloads
  static Future<void> pauseDownload(int downloadId) async {
    await _downloadManager.pauseDownload(downloadId);
  }

  static Future<void> resumeDownload(int downloadId) async {
    await _downloadManager.resumeDownload(downloadId);
  }

  static Future<void> cancelDownload(int downloadId) async {
    await _downloadManager.cancelDownload(downloadId);
  }

  /// Clean up resources
  static Future<void> dispose() async {
    await _downloadManager.dispose();
  }
}

/// Widget to display real-time download progress
class DownloadProgressWidget extends StatefulWidget {
  final int downloadId;

  const DownloadProgressWidget({super.key, required this.downloadId});

  @override
  State<DownloadProgressWidget> createState() => _DownloadProgressWidgetState();
}

class _DownloadProgressWidgetState extends State<DownloadProgressWidget> {
  DownloadProgress? _progress;
  late StreamSubscription _progressSubscription;

  @override
  void initState() {
    super.initState();
    _setupProgressListener();
  }

  void _setupProgressListener() {
    _progressSubscription = EventBus()
        .on<DownloadProgressEvent>()
        .where((event) => event.downloadId == widget.downloadId)
        .listen((event) {
      setState(() {
        _progress = event.progress;
      });
    });
  }

  @override
  void dispose() {
    _progressSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_progress == null) {
      return const CircularProgressIndicator();
    }

    return Column(
      children: [
        LinearProgressIndicator(
          value: _progress!.overallProgress,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
        const SizedBox(height: 8),
        Text(
          '${_progress!.percentageComplete.toStringAsFixed(1)}% - ${_progress!.completedFiles}/${_progress!.totalFiles} files',
          style: const TextStyle(fontSize: 12),
        ),
        if (_progress!.speedBps > 0)
          Text(
            _progress!.formattedSpeed,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        if (_progress!.estimatedTimeRemaining.inSeconds > 0)
          Text(
            'ETA: ${_progress!.formattedETA}',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
      ],
    );
  }
}

/// Migration guide comments for existing code:
/// 
/// OLD WAY (current):
/// ```dart
/// await CybCrawl.getFileContent(
///   url: url,
///   isar: isar,
///   downloadID: downloadID,
///   onComplete: onComplete,
///   download_type: download_type,
///   onDownloadedAlbum: onDownloadedAlbum,
///   totalAlbums: totalAlbums,
///   onThreadchange: onThreadchange,
///   direct: direct,
///   onError: onError,
///   log: log,
///   jobs: jobs,
///   retry: retry,
/// );
/// ```
/// 
/// NEW WAY (unified):
/// ```dart
/// final downloadId = await DownloadManagerIntegration.startDownload(
///   url: url,
///   downloadPath: downloadPath,
///   preferredEngine: DownloadEngine.recooma, // or auto
/// );
/// ```
/// 
/// BENEFITS:
/// 1. Unified interface for all engines (Recooma, Gallery-DL, CybDrop-DL)
/// 2. Community scraper system integration
/// 3. Smart retry with exponential backoff
/// 4. Real-time event streaming via EventBus
/// 5. Intelligent engine selection based on URL patterns
/// 6. Performance monitoring and metrics
/// 7. Error classification and recovery strategies
/// 8. Memory-efficient in-memory communication
/// 9. Progress tracking with speed and ETA calculations
/// 10. Graceful degradation and fallback mechanisms

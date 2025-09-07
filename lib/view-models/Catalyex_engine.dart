import 'package:coom_dl/scrapers/ScraperManager.dart';
import 'package:coom_dl/services/catalyex_config.dart';
import 'package:coom_dl/scrapers/base/BaseScraper.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:async';
import 'dart:isolate';
import 'dart:collection';

// Function to get platform-specific User-Agent string
String getPlatformUserAgent() {
  if (Platform.isWindows) {
    return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';
  } else if (Platform.isMacOS) {
    return 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';
  } else if (Platform.isLinux) {
    return 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';
  } else {
    // Fallback for other platforms
    return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';
  }
}

// Message classes for isolate communication
class IsolateDownloadTask {
  final int fileIndex;
  final String fileName;
  final String fileUrl;
  final String filePath;
  final Map<String, String> headers;
  final SendPort responsePort;

  IsolateDownloadTask({
    required this.fileIndex,
    required this.fileName,
    required this.fileUrl,
    required this.filePath,
    required this.headers,
    required this.responsePort,
  });
}

class IsolateDownloadProgress {
  final int fileIndex;
  final String fileName;
  final double progress;
  final int bytesReceived;
  final int totalBytes;
  final String
      status; // 'started', 'progress', 'completed', 'skipped', 'failed'
  final String? error;

  IsolateDownloadProgress({
    required this.fileIndex,
    required this.fileName,
    required this.progress,
    required this.bytesReceived,
    required this.totalBytes,
    required this.status,
    this.error,
  });
}

// Isolate entry point for file downloads
void isolateDownloadEntry(List<dynamic> args) async {
  final SendPort responsePort = args[0];
  final ReceivePort receivePort = ReceivePort();

  // Send the receive port back to main isolate
  responsePort.send(receivePort.sendPort);

  bool isPaused = false;
  bool isCancelled = false;

  // Listen for download tasks
  await for (final message in receivePort) {
    if (message is IsolateDownloadTask) {
      // Check if we're paused or cancelled before starting download
      if (!isPaused && !isCancelled) {
        await _performIsolateDownload(message);
      } else {
        // Send back status that download was cancelled/paused
        message.responsePort.send(IsolateDownloadProgress(
          fileIndex: message.fileIndex,
          fileName: message.fileName,
          progress: 0.0,
          bytesReceived: 0,
          totalBytes: 0,
          status: isCancelled ? 'cancelled' : 'paused',
        ));
      }
    } else if (message == 'pause') {
      isPaused = true;
      print('⏸️ Isolate paused');
    } else if (message == 'resume') {
      isPaused = false;
      print('▶️ Isolate resumed');
    } else if (message == 'cancel') {
      isCancelled = true;
      print('🛑 Isolate cancelled');
    } else if (message == 'shutdown') {
      break;
    }
  }
}

// Perform the actual download in isolate
Future<void> _performIsolateDownload(IsolateDownloadTask task) async {
  try {
    // Send started status
    task.responsePort.send(IsolateDownloadProgress(
      fileIndex: task.fileIndex,
      fileName: task.fileName,
      progress: 0.0,
      bytesReceived: 0,
      totalBytes: 0,
      status: 'started',
    ));

    // Check if file should be skipped first
    final shouldSkip = await shouldSkipFile(filePath: task.filePath);
    if (shouldSkip) {
      // Get the actual file size for skipped files
      final file = File(task.filePath);
      int fileSize = 0;
      try {
        if (await file.exists()) {
          fileSize = await file.length();
        }
      } catch (e) {
        // If can't get size, use 0
        fileSize = 0;
      }

      task.responsePort.send(IsolateDownloadProgress(
        fileIndex: task.fileIndex,
        fileName: task.fileName,
        progress: 100.0,
        bytesReceived: fileSize,
        totalBytes: fileSize,
        status: 'skipped',
      ));
      return;
    }

    // Create directory if it doesn't exist
    final file = File(task.filePath);
    await file.parent.create(recursive: true);

    // Configure Dio for this isolate
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
      sendTimeout: const Duration(seconds: 30),
      maxRedirects: 5,
      followRedirects: true,
      headers: {
        'User-Agent': getPlatformUserAgent(),
        'Accept': '*/*',
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive',
        ...task.headers, // Add site-specific headers
      },
    ));

    // Download with retry logic
    const maxRetries = 3;
    int retryCount = 0;
    bool downloadSuccess = false;

    while (retryCount <= maxRetries && !downloadSuccess) {
      try {
        await dio.download(
          task.fileUrl,
          task.filePath,
          onReceiveProgress: (received, total) {
            final fileProgress = total > 0 ? (received / total * 100) : 0.0;
            if (fileProgress % 5 < 1 || fileProgress >= 99) {
              // Update every ~5% or near completion in isolate
              task.responsePort.send(IsolateDownloadProgress(
                fileIndex: task.fileIndex,
                fileName: task.fileName,
                progress: fileProgress,
                bytesReceived: received,
                totalBytes: total,
                status: 'progress',
              ));
            }
          },
        );

        // Get the final file size after successful download
        final file = File(task.filePath);
        final finalSize = await file.length();

        downloadSuccess = true;
        task.responsePort.send(IsolateDownloadProgress(
          fileIndex: task.fileIndex,
          fileName: task.fileName,
          progress: 100.0,
          bytesReceived: finalSize, // Send actual file size
          totalBytes: finalSize,
          status: 'completed',
        ));
      } catch (e) {
        retryCount++;
        if (retryCount <= maxRetries) {
          final waitTime = Duration(seconds: retryCount * 2);
          await Future.delayed(waitTime);
        } else {
          task.responsePort.send(IsolateDownloadProgress(
            fileIndex: task.fileIndex,
            fileName: task.fileName,
            progress: 0.0,
            bytesReceived: 0,
            totalBytes: 0,
            status: 'failed',
            error: e.toString(),
          ));
        }
      }
    }
  } catch (e) {
    task.responsePort.send(IsolateDownloadProgress(
      fileIndex: task.fileIndex,
      fileName: task.fileName,
      progress: 0.0,
      bytesReceived: 0,
      totalBytes: 0,
      status: 'failed',
      error: e.toString(),
    ));
  }
}

// Simple function to check if file exists and skip if it does
Future<bool> shouldSkipFile({
  required String filePath,
}) async {
  final file = File(filePath);

  // If file doesn't exist, don't skip
  if (!await file.exists()) {
    return false;
  }

  try {
    // Get local file size
    final localFileSize = await file.length();

    // Skip if file exists and is larger than 1KB (similar to Recooma logic)
    if (localFileSize > 1000) {
      print(
          '✅ File already exists and appears complete: ${file.path.split('/').last} (${_formatBytes(localFileSize)})');
      return true;
    }

    // If file is too small, re-download it
    print(
        '⚠️ File exists but is too small: ${file.path.split('/').last} (${_formatBytes(localFileSize)}), re-downloading');
    return false;
  } catch (e) {
    // If there's an error checking, don't skip (download the file)
    print(
        '⚠️ Error checking file ${file.path.split('/').last}: $e, proceeding with download');
    return false;
  }
}

// Helper function to format bytes
String _formatBytes(int bytes) {
  if (bytes < 1024) return '${bytes}B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
  if (bytes < 1024 * 1024 * 1024)
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
}

// Utility function to sanitize file and folder names for cross-platform compatibility
String sanitizeFileName(String name) {
  // Characters that are not allowed in file/folder names on Windows and macOS
  final invalidChars = RegExp(r'[<>:"/\\|?*\x00-\x1f]');

  // Replace invalid characters with underscores
  String sanitized = name.replaceAll(invalidChars, '_');

  // Remove trailing dots and spaces (Windows restriction)
  sanitized = sanitized.replaceAll(RegExp(r'[\.\s]+$'), '');

  // Ensure the name isn't empty
  if (sanitized.isEmpty) {
    sanitized = 'unnamed';
  }

  // Limit length to prevent issues with long paths
  if (sanitized.length > 200) {
    sanitized = sanitized.substring(0, 200);
  }

  return sanitized;
}

// Function to determine media type from file extension
String getMediaType(String fileName) {
  final extension = fileName.toLowerCase().split('.').last;

  switch (extension) {
    // Video formats
    case 'mp4':
    case 'avi':
    case 'mov':
    case 'wmv':
    case 'flv':
    case 'webm':
    case 'mkv':
    case 'mpg':
    case 'mpeg':
    case 'm4v':
    case '3gp':
    case '3g2':
    case 'asf':
    case 'rm':
    case 'rmvb':
    case 'vob':
    case 'ogv':
    case 'dv':
    case 'ts':
    case 'mts':
    case 'm2ts':
    case 'mxf':
    case 'roq':
    case 'nsv':
    case 'f4v':
    case 'f4p':
    case 'f4a':
    case 'f4b':
      return 'videos';

    // Image formats
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'gif':
    case 'bmp':
    case 'webp':
    case 'tiff':
    case 'tif':
    case 'svg':
    case 'ico':
    case 'cr2':
    case 'nef':
    case 'orf':
    case 'sr2':
    case 'psd':
    case 'xcf':
    case 'ai':
    case 'eps':
    case 'heic':
    case 'heif':
    case 'avif':
    case 'jxl':
    case 'jfif':
    case 'jp2':
    case 'j2k':
    case 'jpf':
    case 'jpx':
    case 'jpm':
    case 'mj2':
      return 'images';

    // Audio formats
    case 'mp3':
    case 'wav':
    case 'flac':
    case 'aac':
    case 'ogg':
    case 'wma':
    case 'm4a':
    case 'ape':
    case 'aiff':
    case 'au':
    case 'ra':
    case 'amr':
    case 'ac3':
    case 'dts':
    case 'opus':
    case 'vorbis':
    case 'gsm':
    case 'dss':
    case 'msv':
    case 'dvf':
    case 'vox':
    case 'cda':
    case 'snd':
    case 'mp2':
    case 'mpa':
    case '3ga':
    case 'aa':
    case 'aax':
    case 'act':
    case 'alac':
    case 'awb':
    case 'dct':
    case 'iklax':
    case 'ivs':
    case 'm4b':
    case 'm4p':
    case 'mmf':
    case 'movpkg':
    case 'mpc':
    case 'nmf':
    case 'nsf':
    case 'oga':
    case 'mogg':
    case 'raw':
    case 'rf64':
    case 'sln':
    case 'tta':
    case 'voc':
    case 'wv':
    case '8svx':
      return 'audio';

    // Document formats
    case 'txt':
    case 'pdf':
    case 'doc':
    case 'docx':
    case 'xls':
    case 'xlsx':
    case 'ppt':
    case 'pptx':
    case 'odt':
    case 'ods':
    case 'odp':
    case 'rtf':
    case 'tex':
    case 'wpd':
    case 'pages':
    case 'numbers':
    case 'keynote':
    case 'csv':
    case 'xml':
    case 'json':
    case 'yaml':
    case 'yml':
    case 'md':
    case 'markdown':
    case 'html':
    case 'htm':
    case 'css':
    case 'js':
    case 'typescript':
    case 'php':
    case 'py':
    case 'java':
    case 'cpp':
    case 'c':
    case 'h':
    case 'cs':
    case 'swift':
    case 'go':
    case 'rs':
    case 'rb':
    case 'pl':
    case 'sh':
    case 'bat':
    case 'cmd':
      return 'documents';

    // Archive formats
    case 'zip':
    case 'rar':
    case '7z':
    case 'tar':
    case 'gz':
    case 'bz2':
    case 'xz':
    case 'z':
    case 'lz':
    case 'lzma':
    case 'cab':
    case 'iso':
    case 'img':
      return 'archives';

    // Executable formats
    case 'exe':
    case 'msi':
    case 'app':
    case 'deb':
    case 'rpm':
    case 'dmg':
    case 'pkg':
    case 'apk':
    case 'ipa':
    case 'run':
    case 'bin':
    case 'appimage':
    case 'flatpak':
    case 'snap':
      return 'executables';

    default:
      return 'other';
  }
}

// Isolate manager for parallel downloads with queue system
class IsolateDownloadManager {
  final List<SendPort> _isolatePorts = [];
  final List<Isolate> _isolates = [];
  final List<ReceivePort> _isolateReceivePorts = [];
  final List<bool> _isolateAvailability = []; // Track which isolates are free
  final Queue<Map<String, dynamic>> _downloadQueue =
      Queue(); // Queue of pending downloads
  final int _maxIsolates;
  final Function(IsolateDownloadProgress) _onProgress;

  bool _isInitialized = false;
  bool _isPaused = false;
  bool _isCancelled = false;

  IsolateDownloadManager({
    required int maxIsolates,
    required Function(IsolateDownloadProgress) onProgress,
  })  : _maxIsolates = maxIsolates,
        _onProgress = onProgress;

  Future<void> initialize() async {
    if (_isInitialized) return;

    print('🚀 Initializing ${_maxIsolates} download isolates...');

    // Spawn isolates one by one with individual communication channels
    for (int i = 0; i < _maxIsolates; i++) {
      // Create a dedicated receive port for this isolate
      final receivePort = ReceivePort();
      _isolateReceivePorts.add(receivePort);
      _isolateAvailability.add(true); // Initially all isolates are available

      // Listen for messages from this specific isolate
      receivePort.listen((message) {
        if (message is IsolateDownloadProgress) {
          _onProgress(message);

          // If this download completed, mark the isolate as available and process next item
          if (message.status == 'completed' ||
              message.status == 'skipped' ||
              message.status == 'failed') {
            _markIsolateAvailable(i);
            _processNextDownload();
          }
        } else if (message is SendPort) {
          // Store the isolate's send port
          _isolatePorts.add(message);
        }
      });

      // Spawn the isolate with its dedicated receive port
      final isolate = await Isolate.spawn(
        isolateDownloadEntry,
        [receivePort.sendPort],
      );

      _isolates.add(isolate);

      // Wait a moment for the isolate to initialize and send back its port
      await Future.delayed(const Duration(milliseconds: 100));

      print('✅ Isolate ${i + 1} initialized');
    }

    // Wait for all isolates to send their ports
    while (_isolatePorts.length < _maxIsolates) {
      await Future.delayed(const Duration(milliseconds: 10));
    }

    _isInitialized = true;
    print('🎉 All ${_maxIsolates} isolates ready for downloads!');
  }

  void queueDownload({
    required int fileIndex,
    required String fileName,
    required String fileUrl,
    required String filePath,
    required Map<String, String> headers,
  }) {
    if (!_isInitialized) {
      throw StateError('IsolateDownloadManager not initialized');
    }

    if (_isCancelled) {
      print('❌ Download cancelled, not queuing: $fileName');
      return;
    }

    // Add to queue
    _downloadQueue.add({
      'fileIndex': fileIndex,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'filePath': filePath,
      'headers': headers,
    });

    print(
        '📥 Queued download for $fileName (queue size: ${_downloadQueue.length})');

    // Try to process immediately if isolates are available and not paused
    if (!_isPaused) {
      _processNextDownload();
    }
  }

  void _processNextDownload() {
    if (_downloadQueue.isEmpty || _isPaused || _isCancelled) return;

    // Find an available isolate
    final availableIndex =
        _isolateAvailability.indexWhere((available) => available);
    if (availableIndex == -1) {
      // No available isolates, download will be processed when one becomes available
      return;
    }

    // Get next download from queue
    final downloadTask = _downloadQueue.removeFirst();

    // Mark isolate as busy
    _isolateAvailability[availableIndex] = false;

    // Send download task to available isolate
    final isolatePort = _isolatePorts[availableIndex];
    final receivePort = _isolateReceivePorts[availableIndex];

    isolatePort.send(IsolateDownloadTask(
      fileIndex: downloadTask['fileIndex'],
      fileName: downloadTask['fileName'],
      fileUrl: downloadTask['fileUrl'],
      filePath: downloadTask['filePath'],
      headers: downloadTask['headers'],
      responsePort: receivePort.sendPort,
    ));

    print(
        '📤 Sent ${downloadTask['fileName']} to isolate ${availableIndex + 1} (queue: ${_downloadQueue.length} remaining)');
  }

  void _markIsolateAvailable(int isolateIndex) {
    _isolateAvailability[isolateIndex] = true;
    print('✅ Isolate ${isolateIndex + 1} is now available');
  }

  bool get hasQueuedDownloads => _downloadQueue.isNotEmpty;

  bool get hasActiveDownloads =>
      _isolateAvailability.any((available) => !available) ||
      _downloadQueue.isNotEmpty;

  void pause() {
    _isPaused = true;
    print('⏸️ Download paused');

    // Send pause command to all isolates
    for (final port in _isolatePorts) {
      try {
        port.send('pause');
      } catch (e) {
        print('⚠️ Error sending pause to isolate: $e');
      }
    }
  }

  void resume() {
    _isPaused = false;
    print('▶️ Download resumed');

    // Send resume command to all isolates
    for (final port in _isolatePorts) {
      try {
        port.send('resume');
      } catch (e) {
        print('⚠️ Error sending resume to isolate: $e');
      }
    }

    // Continue processing queue
    _processNextDownload();
  }

  void cancel() {
    _isCancelled = true;
    print('🛑 Download cancelled');

    // Clear the queue
    _downloadQueue.clear();

    // Send cancel command to all isolates
    for (final port in _isolatePorts) {
      try {
        port.send('cancel');
      } catch (e) {
        print('⚠️ Error sending cancel to isolate: $e');
      }
    }
  }

  bool get isPaused => _isPaused;
  bool get isCancelled => _isCancelled;

  Future<void> shutdown() async {
    if (!_isInitialized) {
      print('⚠️ Isolates already shut down, skipping...');
      return;
    }

    print('🔒 Shutting down isolates...');

    // Send shutdown message to all isolates
    for (final port in _isolatePorts) {
      try {
        port.send('shutdown');
      } catch (e) {
        print('⚠️ Error sending shutdown to isolate: $e');
      }
    }

    // Give isolates a moment to shut down gracefully
    await Future.delayed(const Duration(milliseconds: 100));

    // Kill all isolates
    for (final isolate in _isolates) {
      isolate.kill();
    }

    // Close all receive ports
    for (final receivePort in _isolateReceivePorts) {
      receivePort.close();
    }

    _isolates.clear();
    _isolatePorts.clear();
    _isolateReceivePorts.clear();
    _isolateAvailability.clear();
    _downloadQueue.clear();
    _isInitialized = false;

    print('✅ All isolates shut down');
  }
}

// Global progress manager to handle concurrent download updates
class ThreadProgress {
  int fileIndex;
  String fileName;
  double progress;
  int bytesReceived;
  int totalBytes;
  bool isCompleted;

  ThreadProgress({
    required this.fileIndex,
    required this.fileName,
    required this.progress,
    required this.bytesReceived,
    required this.totalBytes,
    this.isCompleted = false,
  });
}

class DownloadProgressManager {
  // Remove singleton pattern - make it instance-based to prevent conflicts
  DownloadProgressManager();

  // Global progress tracking (independent)
  int _totalFiles = 0;
  int _completedFiles = 0;
  int _skippedFiles = 0; // Track skipped files
  int _totalBytesDownloaded = 0; // Total bytes downloaded so far

  // Individual thread tracking (separate)
  final Map<int, ThreadProgress> _threadProgress = {};
  Timer? _statusTimer;
  DateTime? _lastUpdateTime; // Add rate limiting

  Function(String)? _onProgressUpdate;
  Function(String)? _onConsoleUpdate;

  // Public getter for completion tracking
  int get completedFiles => _completedFiles;
  int get totalFiles => _totalFiles;
  int get skippedFiles => _skippedFiles;
  bool get isComplete => _completedFiles >= _totalFiles;

  void initialize(int totalFiles, Function(String)? onProgressUpdate,
      Function(String)? onConsoleUpdate,
      {int estimatedTotalSize = 0}) {
    print(
        '🔄 ProgressManager: Initializing with $totalFiles files (previous: $_totalFiles)');
    _threadProgress.clear();
    _totalFiles = totalFiles;
    _completedFiles = 0;
    _skippedFiles = 0; // Reset skipped files counter
    _totalBytesDownloaded = 0;
    _onProgressUpdate = onProgressUpdate;
    _onConsoleUpdate = onConsoleUpdate;

    // Set up a timer to send status updates at regular intervals
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _sendStatusUpdate();
    });
    print('📊 ProgressManager: Initialized successfully');
  } // Called when a file starts downloading

  void markFileStarted(int fileIndex, String fileName) {
    _threadProgress[fileIndex] = ThreadProgress(
      fileIndex: fileIndex,
      fileName: fileName,
      progress: 0.0,
      bytesReceived: 0,
      totalBytes: 0,
    );
    print('Thread-${fileIndex + 1}: Started $fileName');
  }

  // Called during file download (for thread status only)
  void updateThreadProgress(
      int fileIndex, double progress, int bytesReceived, int totalBytes) {
    if (_threadProgress.containsKey(fileIndex) &&
        !_threadProgress[fileIndex]!.isCompleted) {
      _threadProgress[fileIndex]!.progress = progress.clamp(0.0, 100.0);
      _threadProgress[fileIndex]!.bytesReceived = bytesReceived;
      _threadProgress[fileIndex]!.totalBytes = totalBytes;

      // Update total bytes downloaded - sum all current bytes from active threads
      _totalBytesDownloaded = _threadProgress.values
          .map((t) => t.bytesReceived)
          .fold(0, (sum, bytes) => sum + bytes);

      // Log thread progress (separate from main progress) - reduced frequency
      if (progress % 10 < 1) {
        // Only log every ~10%
        print(
            'Thread-${fileIndex + 1}: ${_threadProgress[fileIndex]!.fileName} (${progress.toStringAsFixed(1)}%)');
      }
    }
  }

  // Called when a file completes (affects main progress)
  void markFileCompleted(int fileIndex) {
    if (_threadProgress.containsKey(fileIndex) &&
        !_threadProgress[fileIndex]!.isCompleted) {
      _threadProgress[fileIndex]!.isCompleted = true;
      _threadProgress[fileIndex]!.progress = 100.0;
      _completedFiles++;

      // Recalculate total bytes including completed files
      _totalBytesDownloaded = _threadProgress.values
          .map((t) => t.bytesReceived)
          .fold(0, (sum, bytes) => sum + bytes);

      print(
          '✅ Completed: ${_threadProgress[fileIndex]!.fileName} | Total bytes: ${_formatBytes(_totalBytesDownloaded)}');
      _sendStatusUpdate();
    }
  }

  // Called when a file is skipped (affects main progress)
  void markFileSkipped(int fileIndex, String fileName,
      {int bytesReceived = 0}) {
    _threadProgress[fileIndex] = ThreadProgress(
      fileIndex: fileIndex,
      fileName: fileName,
      progress: 100.0,
      bytesReceived: bytesReceived,
      totalBytes: bytesReceived,
      isCompleted: true,
    );
    _skippedFiles++;
    _completedFiles++; // Count skipped files as completed for progress calculation

    // Recalculate total bytes including skipped files
    _totalBytesDownloaded = _threadProgress.values
        .map((t) => t.bytesReceived)
        .fold(0, (sum, bytes) => sum + bytes);

    print(
        '⏭️ Skipped: $fileName | File size: ${_formatBytes(bytesReceived)} | Total bytes: ${_formatBytes(_totalBytesDownloaded)}');
    _sendStatusUpdate();
  }

  void _sendStatusUpdate() {
    if (_totalFiles == 0) return;

    // Rate limiting - only send updates every 500ms max
    final now = DateTime.now();
    if (_lastUpdateTime != null &&
        now.difference(_lastUpdateTime!).inMilliseconds < 500) {
      return;
    }
    _lastUpdateTime = now;

    // Calculate simple progress based on completed files only
    final globalProgress = (_completedFiles / _totalFiles) * 100.0;

    // Get active threads info
    final activeThreads =
        _threadProgress.values.where((t) => !t.isCompleted).toList();

    // Debug: Log current state occasionally
    if (_completedFiles % 5 == 0 || globalProgress % 10 < 1) {
      print(
          '📊 Progress Debug: $_completedFiles/$_totalFiles (${globalProgress.toStringAsFixed(1)}%) | Active: ${activeThreads.length} | Bytes: $_totalBytesDownloaded');
    }

    // Build thread status string (limit to prevent UI overflow)
    final threadStatusList = <String>[];
    for (final thread in activeThreads.take(5)) {
      // Limit to 5 threads for UI space
      final threadId = thread.fileIndex + 1;
      final fileName = thread.fileName.length > 25
          ? '${thread.fileName.substring(0, 25)}...'
          : thread.fileName;
      threadStatusList.add(
          'Thread-$threadId: $fileName (${thread.progress.toStringAsFixed(1)}%)');
    }
    if (activeThreads.length > 5) {
      threadStatusList.add('... and ${activeThreads.length - 5} more threads');
    }

    // Send main progress update with thread info
    if (_onProgressUpdate != null) {
      final threadInfo = threadStatusList.join('|');
      final downloadedFiles = _completedFiles - _skippedFiles;

      // Updated format: PROGRESS:globalProgress:currentBytes:activeThreads:0.0:downloadedFiles:skippedFiles:totalFiles:threadInfo
      _onProgressUpdate!(
          'PROGRESS:${globalProgress.toStringAsFixed(1)}:$_totalBytesDownloaded:${activeThreads.length}:0.0:$downloadedFiles:$_skippedFiles:$_totalFiles:$threadInfo');
    }

    // Send console status update
    if (_onConsoleUpdate != null) {
      final downloadedFiles = _completedFiles - _skippedFiles;
      // Always show current downloaded bytes, regardless of estimation
      final sizeInfo = '${_formatBytes(_totalBytesDownloaded)}';

      final status =
          '📥 ${globalProgress.toStringAsFixed(1)}% | Downloaded: $downloadedFiles | Skipped: $_skippedFiles | Total: $_completedFiles/$_totalFiles | Size: $sizeInfo | Active threads: ${activeThreads.length}';
      _onConsoleUpdate!(status);

      // Also log individual thread status (limited) - reduced frequency
      for (final threadStatus in threadStatusList.take(2)) {
        // Limit console output to 2 threads
        _onConsoleUpdate!(threadStatus);
      }
    }

    // Stop sending updates only when all downloads are truly complete AND no active threads
    if (_completedFiles >= _totalFiles && activeThreads.isEmpty) {
      _statusTimer?.cancel();
      print(
          '📊 Progress tracking complete: $_completedFiles/$_totalFiles files');
    }
  }

  void reset() {
    _statusTimer?.cancel();
    _statusTimer = null;
    _threadProgress.clear();
    _totalFiles = 0;
    _completedFiles = 0;
    _skippedFiles = 0; // Reset skipped files counter
    _totalBytesDownloaded = 0;
    _lastUpdateTime = null; // Reset rate limiting
    _onProgressUpdate = null;
    _onConsoleUpdate = null;
  }
}

class CatalyexEngine {
  //Catalyex Download engine - Connects to existing ScraperManager
  late ScraperManager _scraperManager;
  IsolateDownloadManager? _currentDownloadManager;
  bool _isPaused = false;
  bool _isCancelled = false;

  CatalyexEngine() {
    print('[Catalyex] Creating ScraperManager...');
    _scraperManager = ScraperManager();
    print('[Catalyex] ScraperManager created successfully');
  }

  // Pause the current download
  void pause() {
    _isPaused = true;
    _currentDownloadManager?.pause();
    print('[Catalyex] Download paused');
  }

  // Resume the current download
  void resume() {
    _isPaused = false;
    _currentDownloadManager?.resume();
    print('[Catalyex] Download resumed');
  }

  // Cancel the current download
  void cancel() {
    _isCancelled = true;
    _currentDownloadManager?.cancel();
    print('[Catalyex] Download cancelled');
  }

  // Check if download is paused
  bool get isPaused => _isPaused;

  // Check if download is cancelled
  bool get isCancelled => _isCancelled;

  Future<void> download(
      {required Function() CB1,
      required Function(String) CB2,
      required Function() CB3,
      required Function() CB4,
      required Function(String) CB5,
      required Function(String) CB6,
      required Function(String) CB7,
      required Function(String) CB8,
      required Function(String) CB9,
      required Function() CB10,
      required Function() CB11,
      required Function() CB12,
      required Function() CB13,
      required Function() CB14,
      required String URL,
      required String outputfolder,
      required String dirname,
      required String nameformat,
      required Map settingMap,
      bool Debug = false,
      var links_config = ""}) async {
    print('🚀🚀🚀 [CATALYEX ENGINE] Starting download for URL: $URL');
    print('[Catalyex] Method started - checking parameters...');
    print('[Catalyex] settingMap type: ${settingMap.runtimeType}');
    print('[Catalyex] links_config type: ${links_config.runtimeType}');
    print('[Catalyex] Using existing ScraperManager');
    print('[Catalyex] Output folder: $outputfolder');
    print('[Catalyex] Directory name: $dirname');

    // Reset state for new download
    _isPaused = false;
    _isCancelled = false;
    _currentDownloadManager = null;

    try {
      CB1(); // Start callback
      CB2('🚀 Catalyex Engine Starting...');

      // Check if cancelled before starting
      if (_isCancelled) {
        CB2('❌ Download cancelled before starting');
        CB4(); // Error callback
        return;
      }

      // Use the existing ScraperManager to get scraper for URL
      print('[Catalyex] About to call getScraperForUrl...');
      final scraper = _scraperManager.getScraperForUrl(URL);
      print('[Catalyex] getScraperForUrl completed');

      if (scraper != null) {
        print('[Catalyex] Found scraper: ${scraper.displayName}');
        CB2('✅ Found scraper: ${scraper.displayName}');

        // Create a proper ScrapingRequest
        print('[Catalyex] Creating ScrapingRequest...');
        final request = ScrapingRequest(
          url: URL,
          config: Map<String, dynamic>.from(settingMap),
          onProgress: (progress) {
            print('[Catalyex] Progress callback called');
            CB2('📊 ${progress.statusMessage}');
          },
          onLog: (log) {
            print('[Catalyex] Log callback called');
            CB7(log);
          },
          shouldCancel: () => false, // TODO: integrate with cancel system
        );
        print('[Catalyex] ScrapingRequest created successfully');

        // Use scraper to get content info
        print('[Catalyex] About to call scraper.scrape...');
        final contentInfo = await scraper.scrape(request);
        print('[Catalyex] scraper.scrape completed');

        print('[Catalyex] Content found: ${contentInfo.creatorName}');
        CB2('📁 Content: ${contentInfo.creatorName}');

        // Set task name and total number of files found
        final taskName = contentInfo.creatorName.isNotEmpty
            ? contentInfo.creatorName
            : (contentInfo.folderName.isNotEmpty
                ? contentInfo.folderName
                : 'CNEX Task');
        final totalFiles = contentInfo.downloadItems.length;

        // Call CB9 to update task info (name and total files)
        CB9('TASK_INFO:$taskName:$totalFiles');

        // Notify that scraping is complete and downloading is starting
        CB2('🎉 Found $totalFiles files. Starting download...');

        // Start actual download process
        await _startDownload(
            contentInfo: contentInfo,
            outputFolder: outputfolder,
            dirname: dirname,
            nameFormat: nameformat,
            settingMap: settingMap,
            callbacks: {
              'onProgress': CB2,
              'onComplete': CB3,
              'onError': CB4,
              'onFileStart': CB5,
              'onFileComplete': CB6,
              'onLog': CB7,
              'onStatus': CB8,
              'onUpdate': CB9,
              'onLogEntry': (Map<String, dynamic> logEntry, int totalFetched) {
                // Send log entry in the format the DownloadTaskServices expects
                // This is what updates the download widget progress
                CB9('LOG_ENTRY:${logEntry['status']}:${logEntry['size'] ?? 0}:$totalFetched');
              },
              'onProgressUpdate': (String progressData) {
                // Send real-time progress updates for smooth progress bars
                CB9(progressData);
              },
            });
      } else {
        CB4(); // Error callback
        CB2('❌ No scraper found for URL');
      }
    } catch (e) {
      print('[Catalyex] Error: $e');
      CB4(); // Error callback
      CB2('💥 Error: $e');
    }
  }

  Future<void> _startDownload({
    required ScrapingResult contentInfo,
    required String outputFolder,
    required String dirname,
    required String nameFormat,
    required Map settingMap,
    required Map<String, Function> callbacks,
  }) async {
    callbacks['onProgress']!('🔧 Starting Catalyex isolate-based download...');

    // Get download items from scraping result
    final downloadItems = contentInfo.downloadItems;

    if (downloadItems.isEmpty) {
      callbacks['onError']!();
      callbacks['onProgress']!('❌ No download items found');
      return;
    }

    callbacks['onProgress']!(
        '📥 Found ${downloadItems.length} files to download');

    // Initialize the global progress manager without size estimation
    final progressManager = DownloadProgressManager();
    print(
        '🔄 Creating NEW progress manager instance for ${downloadItems.length} files');
    progressManager.initialize(
      downloadItems.length,
      (progressData) {
        if (callbacks.containsKey('onProgressUpdate')) {
          callbacks['onProgressUpdate']!(progressData);
        }
      },
      (consoleUpdate) {
        callbacks['onProgress']!(consoleUpdate);
      },
      estimatedTotalSize: 0, // No size estimation
    );

    // Use Catalyex optimizations from config
    final config =
        CatalyexConfig.getOptimizedSettings(downloadItems.first.link ?? '');
    final maxThreads = config['maxThreads'] ?? CatalyexConfig.DEFAULT_THREADS;

    callbacks['onProgress']!(
        '⚡ Using $maxThreads isolates for true parallel downloads');

    // Initialize isolate manager
    final isolateManager = IsolateDownloadManager(
      maxIsolates:
          math.min<int>(maxThreads as int, 4), // Limit to 4 max isolates
      onProgress: (progress) {
        // Handle progress updates from isolates
        switch (progress.status) {
          case 'started':
            progressManager.markFileStarted(
                progress.fileIndex, progress.fileName);
            callbacks['onProgress']!('🚀 Started: ${progress.fileName}');
            break;
          case 'progress':
            progressManager.updateThreadProgress(
              progress.fileIndex,
              progress.progress,
              progress.bytesReceived,
              progress.totalBytes,
            );
            break;
          case 'completed':
            // Update final progress with actual file size
            progressManager.updateThreadProgress(
              progress.fileIndex,
              100.0,
              progress.bytesReceived,
              progress.totalBytes,
            );
            progressManager.markFileCompleted(progress.fileIndex);
            callbacks['onProgress']!('✅ Completed: ${progress.fileName}');
            break;
          case 'skipped':
            progressManager.markFileSkipped(
                progress.fileIndex, progress.fileName,
                bytesReceived: progress.bytesReceived);
            callbacks['onProgress']!(
                '⏭️ Skipped: ${progress.fileName} (already exists)');
            break;
          case 'failed':
            callbacks['onProgress']!(
                '❌ Failed: ${progress.fileName} - ${progress.error}');
            // Still mark as completed to continue progress
            progressManager.markFileCompleted(progress.fileIndex);
            break;
          case 'cancelled':
            callbacks['onProgress']!('🛑 Cancelled: ${progress.fileName}');
            // Mark as completed to continue progress
            progressManager.markFileCompleted(progress.fileIndex);
            break;
          case 'paused':
            callbacks['onProgress']!('⏸️ Paused: ${progress.fileName}');
            break;
        }
      },
    );

    // Track if we've already shut down due to cancellation
    bool shutdownDueToCancellation = false;

    try {
      // Initialize all isolates
      await isolateManager.initialize();

      // Store reference for pause/cancel functionality
      _currentDownloadManager = isolateManager;

      callbacks['onProgress']!(
          '🚀 Starting parallel downloads with ${maxThreads} isolates...');

      // Get creator name for directory structure
      final creatorName = contentInfo.creatorName;

      // Check user preference for folder organization from settingMap
      final organizeByMediaType =
          settingMap['organizeByMediaType'] ?? true; // Default to organized

      // Send all download tasks to isolates
      for (int fileIndex = 0; fileIndex < downloadItems.length; fileIndex++) {
        // Check for cancellation
        if (_isCancelled) {
          callbacks['onProgress']!('❌ Download cancelled');
          break;
        }

        final item = downloadItems[fileIndex];
        final fileName = item.downloadName ?? 'file_$fileIndex';
        final fileUrl = item.link ?? '';

        if (fileUrl.isEmpty) {
          callbacks['onProgress']!('⚠️ Skipping file ${fileIndex + 1}: No URL');
          progressManager.markFileCompleted(fileIndex);
          continue;
        }

        // Calculate file path
        final sanitizedCreator = sanitizeFileName(
            creatorName.isNotEmpty ? creatorName : 'Unknown_Creator');
        final sanitizedFileName = sanitizeFileName(fileName);

        final String filePath;
        if (organizeByMediaType) {
          final mediaType = getMediaType(sanitizedFileName);
          filePath =
              '$outputFolder/$sanitizedCreator/$mediaType/$sanitizedFileName';
        } else {
          filePath = '$outputFolder/$sanitizedCreator/$sanitizedFileName';
        }

        // Set appropriate headers based on the domain
        Map<String, String> headers = {};
        final uri = Uri.parse(fileUrl);
        if (uri.host.contains("coomer") || uri.host.contains("kemono")) {
          headers = {"Accept": "text/css"};
        } else if (uri.host.contains("erome")) {
          headers = {"Referer": "https://www.erome.com/"};
        }

        // Queue download task to isolate manager
        isolateManager.queueDownload(
          fileIndex: fileIndex,
          fileName: fileName,
          fileUrl: fileUrl,
          filePath: filePath,
          headers: headers,
        );
      }

      // Wait for all downloads to complete by monitoring progress and queue
      int lastCompletedCount = 0;
      int stableCount = 0;

      while (!progressManager.isComplete || isolateManager.hasActiveDownloads) {
        await Future.delayed(const Duration(milliseconds: 500));

        // Check for cancellation
        if (_isCancelled) {
          callbacks['onProgress']!(
              '❌ Download cancelled by user - completing with downloaded files');
          callbacks['onProgress']!(
              '🔒 Shutting down isolates due to cancellation...');

          // Immediately shutdown isolates when cancelled
          await isolateManager.shutdown();
          progressManager.reset();
          shutdownDueToCancellation = true;

          callbacks['onProgress']!('✅ Isolates shut down due to cancellation');
          break;
        }

        // Check if progress is truly stalled (no change for 30 seconds AND no active downloads)
        if (progressManager.completedFiles == lastCompletedCount) {
          stableCount++;
          // Only consider it stalled if no progress AND no active downloads for 60 iterations (30 seconds)
          if (stableCount > 60 && !isolateManager.hasActiveDownloads) {
            print(
                '⚠️ Download appears stalled with no active downloads, checking completion...');
            // Force completion check if we seem truly stuck
            if (progressManager.completedFiles >= downloadItems.length * 0.95) {
              print(
                  '📊 Most files completed and no active downloads, finishing...');
              break;
            } else {
              print(
                  '📊 Still have ${downloadItems.length - progressManager.completedFiles} files remaining, continuing...');
              stableCount = 0; // Reset counter and continue waiting
            }
          }
        } else {
          lastCompletedCount = progressManager.completedFiles;
          stableCount = 0;
        }

        // Safety timeout - much longer now (5 minutes for large downloads)
        if (stableCount > 600) {
          // 600 * 500ms = 5 minutes
          print('⏰ Maximum timeout reached (5 minutes), forcing completion...');
          break;
        }
      }

      callbacks['onProgress']!(
          '🎉 All downloads completed, shutting down isolates...');

      // Send final 100% progress update to ensure UI shows completion
      if (callbacks.containsKey('onProgressUpdate')) {
        final downloadedFiles =
            progressManager.completedFiles - progressManager.skippedFiles;
        callbacks['onProgressUpdate']!(
            'PROGRESS:100.0:0:0:0.0:$downloadedFiles:${progressManager.skippedFiles}:${progressManager.totalFiles}:All downloads complete');
      }
    } finally {
      // Clean up isolates only if not already shut down due to cancellation
      if (!shutdownDueToCancellation) {
        await isolateManager.shutdown();
        progressManager.reset();
      }
    }

    callbacks['onComplete']!();
    if (_isCancelled) {
      callbacks['onProgress']!(
          '🎉 Catalyex download completed (cancelled but keeping downloaded files)');
    } else {
      callbacks['onProgress']!(
          '🎉 Catalyex isolate download completed successfully!');
    }
  }
}

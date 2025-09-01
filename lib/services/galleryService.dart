import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:watcher/watcher.dart';

class GalleryService {
  static GalleryService? _instance;
  static GalleryService get instance => _instance ??= GalleryService._();

  GalleryService._();

  final Map<String, StreamSubscription> _watchers = {};
  final Map<String, List<File>> _cachedFiles = {};
  final StreamController<String> _fileChangeController =
      StreamController<String>.broadcast();

  // Supported media file extensions
  final List<String> supportedExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
    '.bmp',
    '.tiff',
    '.mp4',
    '.webm',
    '.mov',
    '.avi',
    '.mkv',
    '.m4v',
    '.flv'
  ];

  Stream<String> get fileChanges => _fileChangeController.stream;

  /// Start watching a directory for file changes
  Future<void> startWatching(String directoryPath) async {
    if (_watchers.containsKey(directoryPath)) {
      return; // Already watching
    }

    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      print('Gallery Service: Directory does not exist: $directoryPath');
      return;
    }

    try {
      // Initial scan
      await _scanDirectory(directoryPath);

      // Start watching for changes
      final watcher = DirectoryWatcher(directoryPath);
      final subscription = watcher.events.listen(
        (event) {
          print(
              'Gallery Service: File event in $directoryPath: ${event.type} - ${event.path}');
          _handleFileEvent(directoryPath, event);
        },
        onError: (error) {
          print('Gallery Service: Watcher error for $directoryPath: $error');
        },
      );

      _watchers[directoryPath] = subscription;
      print('Gallery Service: Started watching $directoryPath');
    } catch (e) {
      print('Gallery Service: Failed to start watching $directoryPath: $e');
    }
  }

  /// Stop watching a directory
  void stopWatching(String directoryPath) {
    final subscription = _watchers.remove(directoryPath);
    subscription?.cancel();
    _cachedFiles.remove(directoryPath);
    print('Gallery Service: Stopped watching $directoryPath');
  }

  /// Get cached media files for a directory
  List<File> getMediaFiles(String directoryPath) {
    return _cachedFiles[directoryPath] ?? [];
  }

  /// Watch directory and return stream of file changes
  Stream<List<FileSystemEntity>> watchDirectory(String directoryPath) async* {
    // Start watching if not already watching
    if (!_watchers.containsKey(directoryPath)) {
      await startWatching(directoryPath);
    }

    // Yield initial files
    yield getMediaFiles(directoryPath).cast<FileSystemEntity>();

    // Listen for changes and yield updates
    await for (String changedPath in fileChanges) {
      if (changedPath == directoryPath) {
        yield getMediaFiles(directoryPath).cast<FileSystemEntity>();
      }
    }
  }

  /// Force refresh files in a directory
  Future<void> refreshDirectory(String directoryPath) async {
    await _scanDirectory(directoryPath);
    _fileChangeController.add(directoryPath);
  }

  /// Scan directory for media files (recursively)
  Future<void> _scanDirectory(String directoryPath) async {
    try {
      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        _cachedFiles[directoryPath] = [];
        return;
      }

      final mediaFiles = <File>[];

      // Recursively scan directory and subdirectories
      await for (var entity in directory.list(recursive: true)) {
        if (entity is File) {
          final extension = path.extension(entity.path).toLowerCase();
          if (supportedExtensions.contains(extension)) {
            mediaFiles.add(entity);
          }
        }
      }

      // Sort by modification time (newest first)
      mediaFiles
          .sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      _cachedFiles[directoryPath] = mediaFiles;
      print(
          'Gallery Service: Found ${mediaFiles.length} media files in $directoryPath (including subdirectories)');
    } catch (e) {
      print('Gallery Service: Error scanning directory $directoryPath: $e');
      _cachedFiles[directoryPath] = [];
    }
  }

  /// Handle file system events
  void _handleFileEvent(String directoryPath, WatchEvent event) {
    final extension = path.extension(event.path).toLowerCase();

    // Only process supported media files
    if (!supportedExtensions.contains(extension)) {
      return;
    }

    switch (event.type) {
      case ChangeType.ADD:
      case ChangeType.MODIFY:
        // Refresh the directory on file add/modify
        _scanDirectory(directoryPath).then((_) {
          _fileChangeController.add(directoryPath);
        });
        break;
      case ChangeType.REMOVE:
        // Refresh the directory on file remove
        _scanDirectory(directoryPath).then((_) {
          _fileChangeController.add(directoryPath);
        });
        break;
    }
  }

  /// Check if a file is an image
  bool isImageFile(File file) {
    final imageExtensions = [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.webp',
      '.bmp',
      '.tiff'
    ];
    return imageExtensions.contains(path.extension(file.path).toLowerCase());
  }

  /// Check if a file is a video
  bool isVideoFile(File file) {
    final videoExtensions = [
      '.mp4',
      '.webm',
      '.mov',
      '.avi',
      '.mkv',
      '.m4v',
      '.flv'
    ];
    return videoExtensions.contains(path.extension(file.path).toLowerCase());
  }

  /// Get file size as a formatted string
  String getFileSize(File file) {
    try {
      final bytes = file.lengthSync();
      if (bytes < 1024) return '${bytes} B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      if (bytes < 1024 * 1024 * 1024)
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Dispose of all watchers
  void dispose() {
    for (final subscription in _watchers.values) {
      subscription.cancel();
    }
    _watchers.clear();
    _cachedFiles.clear();
    _fileChangeController.close();
  }
}

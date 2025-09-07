import 'dart:convert';
import 'package:coom_dl/data/models/DlTask.dart';
import 'package:coom_dl/utils/FileSizeConverter.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:isar/isar.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:hive/hive.dart';
import 'package:coom_dl/view-models/Catalyex_engine.dart';

import '../constant/appcolors.dart';
import 'MiniPerformanceChart.dart';

class DownloadWidget extends StatefulWidget {
  final DownloadTask task;
  final Isar isar;
  final Map<String, dynamic> downloadinfo;
  const DownloadWidget(
      {Key? key,
      required this.task,
      required this.isar,
      required this.downloadinfo})
      : super(key: key);

  @override
  _DownloadWidgetState createState() => _DownloadWidgetState();
}

class _DownloadWidgetState extends State<DownloadWidget> {
  bool _paused = false;

  // Static map to store last known progress for each task to prevent glitchy resets
  static Map<int, Map<String, dynamic>> _lastKnownProgress = {};

  // Static set to track which tasks have already shown completion toasts
  static Set<int> _completedTaskToasts = {};
  static Set<int> _failedTaskToasts = {};
  static Set<int> _startedTaskToasts = {};

  // Rotating arrow indicator for threads
  static const List<String> _arrowChars = [
    "⠋",
    "⠙",
    "⠚",
    "⠒",
    "⠂",
    "⠂",
    "⠒",
    "⠲",
    "⠴",
    "⠦",
    "⠖",
    "⠒",
    "⠐",
    "⠐",
    "⠒",
    "⠓",
    "⠋"
  ];
  static Map<int, int> _arrowIndexes = {}; // Per-task arrow position

  // Get current arrow for this task and advance to next position
  String _getNextArrow() {
    final taskId = widget.task.id;
    final currentIndex = _arrowIndexes[taskId] ?? 0;
    final nextIndex = (currentIndex + 1) % _arrowChars.length;
    _arrowIndexes[taskId] = nextIndex;
    return _arrowChars[currentIndex];
  }

  // Check if Catalyex engine is currently selected
  bool _isCatalyexEngine() {
    final settingsBox = Hive.box('settings');
    final selectedEngine = settingsBox.get('engine', defaultValue: 0);
    return selectedEngine == 1; // 1 = Catalyex, 0 = Recooma
  }

  // Toast notification utilities
  static void _showDownloadToast({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
    Duration duration = const Duration(seconds: 3),
  }) {
    Get.showSnackbar(
      GetSnackBar(
        title: title,
        message: message,
        backgroundColor: color.withOpacity(0.9),
        duration: duration,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(10),
        borderRadius: 8,
        icon: Icon(icon, color: Colors.white, size: 24),
        maxWidth: 400,
        isDismissible: true,
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }

  static void _showCompletionToast(
      String taskName, int totalFiles, String totalSize) {
    _showDownloadToast(
      title: "Download Complete! 🎉",
      message: "$taskName\\n$totalFiles files • $totalSize",
      icon: Icons.check_circle,
      color: Colors.green,
      duration: const Duration(seconds: 4),
    );
  }

  static void _showFailureToast(String taskName, String error) {
    _showDownloadToast(
      title: "Download Failed ❌",
      message: "$taskName\\nError: $error",
      icon: Icons.error,
      color: Colors.red,
      duration: const Duration(seconds: 5),
    );
  }

  static void _showProgressToast(String taskName, double progress) {
    _showDownloadToast(
      title: "Download Progress",
      message: "$taskName\\n${progress.toStringAsFixed(1)}% complete",
      icon: Icons.download,
      color: Colors.blue,
      duration: const Duration(seconds: 2),
    );
  }

  static void _showStartToast(String taskName) {
    _showDownloadToast(
      title: "Download Started 🚀",
      message: "Starting download: $taskName",
      icon: Icons.play_arrow,
      color: Colors.blue,
      duration: const Duration(seconds: 2),
    );
  }

  // Check download status and show appropriate toasts
  void _checkAndShowStatusToasts() {
    final taskId = widget.task.id;
    final taskName = widget.task.name ?? "Unknown";

    // Check for download start
    if (widget.task.isDownloading ?? false) {
      if (!_startedTaskToasts.contains(taskId)) {
        _startedTaskToasts.add(taskId);
        _showStartToast(taskName);
      }
    }

    // Check for completion
    if (widget.task.isCompleted ?? false) {
      if (!_completedTaskToasts.contains(taskId)) {
        _completedTaskToasts.add(taskId);

        // Get total files and size info
        final totalFiles = widget.task.totalNum ?? 0;
        final downloadInfo = widget.downloadinfo;
        final totalSize = downloadInfo["size"] ?? 0;
        final formattedSize =
            FileSizeConverter.getFileSizeString(bytes: totalSize);

        _showCompletionToast(taskName, totalFiles, formattedSize);
      }
    }

    // Check for failure
    if (widget.task.isFailed ?? false) {
      if (!_failedTaskToasts.contains(taskId)) {
        _failedTaskToasts.add(taskId);
        _showFailureToast(taskName, "Download failed");
      }
    }

    // Reset states if task status changes
    if (!(widget.task.isDownloading ?? false)) {
      _startedTaskToasts.remove(taskId);
    }
    if (!(widget.task.isCompleted ?? false)) {
      _completedTaskToasts.remove(taskId);
    }
    if (!(widget.task.isFailed ?? false)) {
      _failedTaskToasts.remove(taskId);
    }
  }

  // Extract subdomain from URL
  String _extractSiteName(String url) {
    try {
      Uri uri = Uri.parse(url);
      String host = uri.host.toLowerCase();

      // Remove 'www.' if present
      if (host.startsWith('www.')) {
        host = host.substring(4);
      }

      // Extract subdomain (first part before first dot)
      List<String> parts = host.split('.');
      if (parts.isNotEmpty) {
        return parts.first;
      }
      return 'unknown';
    } catch (e) {
      return 'unknown';
    }
  }

  // Open Gallery Window for this download
  Future<void> _openGalleryWindow() async {
    try {
      final window = await DesktopMultiWindow.createWindow(jsonEncode({
        'name': 'gallery',
        'downloadId': widget.task.id,
        'downloadName': widget.task.name,
        'downloadPath': '${widget.task.storagePath}/${widget.task.name}',
      }));

      window
        ..setFrame(const Offset(100, 100) & const Size(800, 600))
        ..center()
        ..setTitle('Gallery - ${widget.task.name}')
        ..show();
    } catch (e) {
      print('Failed to open gallery window: $e');
      // Fallback: Show dialog for now
      Get.dialog(AlertDialog(
        backgroundColor: Appcolors.appAccentColor,
        title: Text('Gallery Feature',
            style: TextStyle(
                color: Appcolors.appPrimaryColor, fontWeight: FontWeight.w500)),
        content: Text(
            'Gallery window coming soon!\nDownload ID: ${widget.task.id}',
            style: TextStyle(color: Appcolors.appPrimaryColor)),
        actions: [
          TextButton(
              onPressed: () => Get.back(),
              child:
                  Text('OK', style: TextStyle(color: Appcolors.appLogoColor)))
        ],
      ));
    }
  }

  // Get gradient colors based on site name
  List<Color> _getSiteGradient(String siteName) {
    switch (siteName.toLowerCase()) {
      case 'coomer':
        return [
          const Color(0xFF6B46C1), // Purple
          const Color(0xFF9333EA), // Lighter purple
        ];
      case 'kemono':
        return [
          const Color(0xFF0891B2), // Cyan
          const Color(0xFF0EA5E9), // Light blue
        ];
      case 'erome':
        return [
          const Color(0xFFDC2626), // Red
          const Color(0xFFEF4444), // Light red
        ];
      case 'fapello':
        return [
          const Color(0xFF059669), // Green
          const Color(0xFF10B981), // Light green
        ];
      default:
        return [
          Appcolors.appAccentColor,
          Appcolors.appAccentColor.withOpacity(0.7),
        ];
    }
  }

  // Create gradient thumbnail with site name
  Widget _buildSiteThumbnail() {
    String siteName = _extractSiteName(widget.task.url);
    List<Color> gradientColors = _getSiteGradient(siteName);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_download_rounded,
              color: Colors.white.withOpacity(0.9),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              siteName.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withOpacity(0.95),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Clean up progress tracking when task is completed or widget is disposed
    if ((widget.task.isCompleted ?? false) || (widget.task.isFailed ?? false)) {
      _lastKnownProgress.remove(widget.task.id);
      _arrowIndexes.remove(widget.task.id); // Clean up arrow rotation state
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check for completion or failure and show toast if needed
    _checkAndShowStatusToasts();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Appcolors.appAccentColor.withOpacity(0.2),
            width: 1,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Appcolors.appSecondaryColor.withOpacity(0.3),
              Appcolors.appSecondaryColor.withOpacity(0.1),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Appcolors.appAccentColor.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        height: 120,
        child: Row(
          children: [
            // image
            Container(
              width: 100,
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Appcolors.appBackgroundColor.withOpacity(0.6),
                  border: Border.all(
                    color: Appcolors.appAccentColor.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: _buildSiteThumbnail(),
                ),
              ),
            ),
            // Download information
            Expanded(
                child: ClipRect(
                    child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              children: [
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: SizedBox(
                          width: 200,
                          child: Text(
                            overflow: TextOverflow.ellipsis,
                            "${widget.task.name ?? "No Name"}",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Appcolors.appPrimaryColor,
                                fontSize: 22),
                          )),
                    ),
                    SizedBox(
                        width: 90,
                        height: 25,
                        child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Appcolors.appAccentColor.withOpacity(0.1),
                              border: Border.all(
                                color:
                                    Appcolors.appAccentColor.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Center(child: Builder(builder: (context) {
                              if (widget.task.isDownloading ?? false) {
                                return MiniPerformanceChart(
                                  key: ValueKey('perf_${widget.task.id}'),
                                  downloadInfo: widget.downloadinfo,
                                  isDownloading:
                                      widget.task.isDownloading ?? false,
                                  downloadedBytes: widget.task.downloadedBytes,
                                );
                              } else if (widget.task.tag != null) {
                                return Text("${widget.task.tag}",
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Appcolors.appPrimaryColor,
                                        fontSize: 9));
                              } else {
                                return Text("No Tag",
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Appcolors.appPrimaryColor,
                                        fontSize: 9));
                              }
                            })))),
                    const Spacer(),
                    Container(
                      margin: const EdgeInsets.all(6),
                      padding: const EdgeInsets.all(4),
                      height: 38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Appcolors.appAccentColor.withOpacity(0.1),
                        border: Border.all(
                          color: Appcolors.appAccentColor.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (widget.task.totalNum != null &&
                              (widget.task.isDownloading ?? false)) ...[
                            IconButton(
                                style: IconButton.styleFrom(
                                    hoverColor: Appcolors.appPrimaryColor
                                        .withOpacity(0.2),
                                    foregroundColor: Appcolors.appPrimaryColor,
                                    backgroundColor: Appcolors.appAccentColor
                                        .withOpacity(0.1),
                                    side: BorderSide(
                                      color: Appcolors.appAccentColor
                                          .withOpacity(0.2),
                                      width: 1,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    )),
                                onPressed: () async {
                                  // Check which engine is being used
                                  final isCatalyex = _isCatalyexEngine();

                                  if (isCatalyex) {
                                    // Handle Catalyex engine pause/resume
                                    if (_paused) {
                                      CatalyexEngine().resume();
                                      print(
                                          "🎯 Catalyex: Resumed task ${widget.task.id}");
                                    } else {
                                      CatalyexEngine().pause();
                                      print(
                                          "🎯 Catalyex: Paused task ${widget.task.id}");
                                    }
                                  } else {
                                    // Handle traditional engine (Recooma) pause/resume
                                    await widget.isar.writeTxn(() async {
                                      DownloadTask? temp = await widget
                                          .isar.downloadTasks
                                          .where()
                                          .idEqualTo(widget.task.id)
                                          .findFirst();
                                      if (temp != null) {
                                        temp.isPaused = !temp.isPaused!;
                                        await widget.isar.downloadTasks
                                            .put(temp);
                                      }
                                    });
                                  }

                                  setState(() {
                                    _paused = !_paused;
                                  });
                                },
                                icon: _paused
                                    ? const Icon(
                                        Icons.play_arrow,
                                        size: 11,
                                      )
                                    : const Icon(
                                        Icons.pause,
                                        size: 11,
                                      )),
                            const SizedBox(
                              width: 10,
                            ),
                          ],
                          if ((widget.task.totalNum != null &&
                                  (widget.task.isDownloading ?? false)) ||
                              (widget.task.isCompleted ?? false)) ...[
                            IconButton(
                                style: IconButton.styleFrom(
                                    hoverColor: Appcolors.appPrimaryColor
                                        .withOpacity(0.2),
                                    foregroundColor: Appcolors.appPrimaryColor,
                                    backgroundColor: Appcolors.appAccentColor
                                        .withOpacity(0.1),
                                    side: BorderSide(
                                      color: Appcolors.appAccentColor
                                          .withOpacity(0.2),
                                      width: 1,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    )),
                                onPressed: () async {
                                  // Open Download Directory

                                  await launchUrlString(
                                          "file://${widget.task.storagePath}/${widget.task.name}/")
                                      .onError((error, stackTrace) {
                                    Get.dialog(AlertDialog(
                                      icon: Icon(
                                        Icons.error,
                                        color: Colors.red[400],
                                      ),
                                      backgroundColor: Appcolors.appAccentColor,
                                      title: Text(
                                          "Failed to open ${widget.task.storagePath}/${widget.task.name}/",
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.red[400],
                                              fontWeight: FontWeight.w500)),
                                    ));
                                    return Future.error("");
                                  });
                                },
                                icon: Center(
                                    child: const Icon(
                                  Icons.folder_rounded,
                                  size: 14,
                                ))),
                            const SizedBox(
                              width: 10,
                            ),
                            // Gallery Button
                            IconButton(
                                style: IconButton.styleFrom(
                                    hoverColor:
                                        Colors.purple[400]!.withOpacity(0.2),
                                    foregroundColor: Colors.purple[400],
                                    backgroundColor:
                                        Colors.purple[400]!.withOpacity(0.1),
                                    side: BorderSide(
                                      color:
                                          Colors.purple[400]!.withOpacity(0.2),
                                      width: 1,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    )),
                                onPressed: () async {
                                  // Open Gallery Window
                                  await _openGalleryWindow();
                                },
                                icon: const Icon(
                                  Icons.photo_library_rounded,
                                  size: 14,
                                )),
                            const SizedBox(
                              width: 10,
                            ),
                            IconButton(
                                style: IconButton.styleFrom(
                                    hoverColor:
                                        Colors.red[400]!.withOpacity(0.2),
                                    foregroundColor: Colors.red[400],
                                    backgroundColor:
                                        Colors.red[400]!.withOpacity(0.1),
                                    side: BorderSide(
                                      color: Colors.red[400]!.withOpacity(0.2),
                                      width: 1,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    )),
                                onPressed: () async {
                                  // Check which engine is being used
                                  final isCatalyex = _isCatalyexEngine();

                                  if (isCatalyex) {
                                    // Handle Catalyex engine cancel
                                    CatalyexEngine().cancel();
                                    print(
                                        "🎯 Catalyex: Cancelled task ${widget.task.id}");
                                  }

                                  // Mark download as completed instead of just cancelled
                                  var tmp = await widget.isar.downloadTasks
                                      .filter()
                                      .idEqualTo(widget.task.id)
                                      .findFirst();

                                  if (tmp != null) {
                                    tmp.isCanceled = true;
                                    tmp.isCompleted = true; // Mark as completed
                                    tmp.isDownloading =
                                        false; // Stop downloading state
                                    print(
                                        "🎯 Marking task ${widget.task.id} as completed after cancellation");

                                    await widget.isar.writeTxn(() async {
                                      await widget.isar.downloadTasks.put(tmp);
                                    });
                                  }
                                },
                                icon: const Icon(
                                  Icons.delete_forever,
                                  size: 14,
                                )),
                          ]
                        ],
                      ),
                    )
                  ],
                ),

                // Download information
                Flexible(
                    child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 0),
                      child: () {
                        if (widget.task.totalNum == null &&
                            (widget.task.isDownloading ?? false)) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: Colors.blue[400]!.withOpacity(0.1),
                              border: Border.all(
                                color: Colors.blue[400]!.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                        Colors.blue[400]),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "SCRAPING",
                                      style: TextStyle(
                                        color: Colors.blue[400],
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      "Analyzing page content...",
                                      style: TextStyle(
                                        color: Appcolors.appPrimaryColor
                                            .withOpacity(0.8),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        } else if ((widget.task.isQueue ?? false) ||
                            (widget.task.isCompleted ?? false) ||
                            (widget.task.isFailed ?? false)) {
                          return Text(
                            overflow: TextOverflow.ellipsis,
                            () {
                              if (widget.task.isQueue ?? false) {
                                return "[Queue] Download in Queue";
                              } else if ((widget.task.isCompleted ?? false)) {
                                return "(OK) Download completed";
                              } else if ((widget.task.isFailed ?? false)) {
                                return "[CNEX_DL_FAIL]: Download Failed";
                              } else {
                                return "[CNEX_DB_ERROR]: DB Services Failed, please re-open cnex";
                              }
                            }(),
                            style: TextStyle(
                                color: Appcolors.appPrimaryColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w500),
                          );
                        } else {
                          final total = widget.task.totalNum ?? 0;
                          final current = widget.downloadinfo["total"] ?? 0;
                          final ok = widget.downloadinfo["ok"] ?? 0;
                          final fail = widget.downloadinfo["fail"] ?? 0;
                          final retries = widget.downloadinfo["retries"] ?? 0;
                          final size = widget.downloadinfo["size"] ?? 0;

                          // Enhanced progress data from Catalyex
                          final rawOverallProgress =
                              widget.downloadinfo["overallProgress"] ?? 0.0;
                          final rawFileProgress =
                              widget.downloadinfo["fileProgress"] ?? 0.0;
                          final totalFiles =
                              widget.downloadinfo["totalFiles"] ?? total;
                          final currentBytes =
                              widget.downloadinfo["currentBytes"] ?? size;
                          final totalBytes =
                              widget.downloadinfo["totalBytes"] ?? 0;

                          // Store current progress if it's meaningful or if we have size data
                          // Store aggressively to prevent resets - any progress or completed files
                          if (rawOverallProgress > 0 ||
                              rawFileProgress > 0 ||
                              size > 0 ||
                              totalBytes > 0 ||
                              current > 0 ||
                              ok > 0 ||
                              currentBytes > 0) {
                            _lastKnownProgress[widget.task.id] = {
                              "overallProgress": rawOverallProgress,
                              "fileProgress": rawFileProgress,
                              "totalFiles": totalFiles,
                              "currentBytes": currentBytes,
                              "totalBytes": totalBytes,
                              "size": size, // Store the size to prevent reset
                              "current": current,
                              "ok": ok,
                            };
                          }

                          // Use last known progress if current progress is 0 but we have stored data
                          final storedProgress =
                              _lastKnownProgress[widget.task.id];

                          // More intelligent fallback - only use stored when current values are truly reset
                          final effectiveSize = size > 0
                              ? size
                              : (storedProgress != null &&
                                      storedProgress["size"] > 0
                                  ? storedProgress["size"]
                                  : 0);
                          final effectiveCurrent = current > 0
                              ? current
                              : (storedProgress != null &&
                                      storedProgress["current"] > 0
                                  ? storedProgress["current"]
                                  : 0);
                          final effectiveTotalBytes = totalBytes > 0
                              ? totalBytes
                              : (storedProgress != null &&
                                      storedProgress["totalBytes"] > 0
                                  ? storedProgress["totalBytes"]
                                  : 0);
                          final effectiveOverallProgress =
                              rawOverallProgress > 0
                                  ? rawOverallProgress
                                  : (storedProgress != null &&
                                          storedProgress["overallProgress"] > 0
                                      ? storedProgress["overallProgress"]
                                      : 0.0);

                          // Choose display size: use actual downloaded size (including skipped files)
                          // This represents the total size of files that are actually on the device
                          final displaySize =
                              effectiveSize; // This is the sum of all downloaded + skipped files

                          // Use enhanced progress for calculation, fallback to legacy calculation
                          final displayProgress = effectiveOverallProgress > 0
                              ? effectiveOverallProgress.toStringAsFixed(1)
                              : (total > 0
                                  ? ((effectiveCurrent / total) * 100)
                                      .toStringAsFixed(1)
                                  : "0.0");

                          // Format byte sizes
                          String formatBytes(int bytes) {
                            if (bytes < 1024) return "${bytes}B";
                            if (bytes < 1024 * 1024)
                              return "${(bytes / 1024).toStringAsFixed(1)}KB";
                            if (bytes < 1024 * 1024 * 1024)
                              return "${(bytes / 1024 / 1024).toStringAsFixed(1)}MB";
                            return "${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)}GB";
                          }

                          return Container(
                            width: 300, // Constrain the container width
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: Colors.green[400]!.withOpacity(0.1),
                              border: Border.all(
                                color: Colors.green[400]!.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.download,
                                        color: Colors.green[400], size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      "DOWNLOADING",
                                      style: TextStyle(
                                        color: Colors.green[400],
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "$displayProgress%",
                                      style: TextStyle(
                                        color: Colors.green[400],
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 2,
                                  children: [
                                    Text(
                                      "${totalFiles > 0 ? effectiveCurrent : effectiveCurrent}/${totalFiles > 0 ? totalFiles : total} files",
                                      style: TextStyle(
                                        color: Appcolors.appPrimaryColor
                                            .withOpacity(0.8),
                                        fontSize: 10,
                                        height: 1.0,
                                      ),
                                    ),
                                    // Show byte progress if available
                                    if (totalBytes > 0)
                                      Text(
                                        "${formatBytes(currentBytes)}/${formatBytes(totalBytes)}",
                                        style: TextStyle(
                                          color: Colors.cyan[400],
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          height: 1.0,
                                        ),
                                      ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 3, vertical: 0),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(3),
                                        color:
                                            Colors.green[400]!.withOpacity(0.1),
                                      ),
                                      child: Text(
                                        "✓$ok",
                                        style: TextStyle(
                                          color: Colors.green[400],
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          height: 1.0,
                                        ),
                                      ),
                                    ),
                                    if (fail > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 3, vertical: 0),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(3),
                                          color:
                                              Colors.red[400]!.withOpacity(0.1),
                                        ),
                                        child: Text(
                                          "✗$fail",
                                          style: TextStyle(
                                            color: Colors.red[400],
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            height: 1.0,
                                          ),
                                        ),
                                      ),
                                    if (retries > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 3, vertical: 0),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(3),
                                          color: Colors.orange[400]!
                                              .withOpacity(0.1),
                                        ),
                                        child: Text(
                                          "↻$retries",
                                          style: TextStyle(
                                            color: Colors.orange[400],
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            height: 1.0,
                                          ),
                                        ),
                                      ),
                                    Text(
                                      "Total: ${FileSizeConverter.getFileSizeString(bytes: displaySize)}",
                                      style: TextStyle(
                                        color: Colors.cyan[400],
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        height: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }
                      }(),
                    )
                  ],
                )),
                // Show thread status information as a separate section
                if (widget.task.isDownloading ?? false) ...[
                  Builder(builder: (context) {
                    final activeThreads =
                        widget.downloadinfo["activeThreads"] ?? 0;
                    final threadInfo = widget.downloadinfo["threadInfo"] ?? "";

                    if (activeThreads > 0) {
                      // Get the next arrow in the circular sequence for this update
                      final rotatingArrow = _getNextArrow();

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: [
                            // Rotating arrow indicator
                            Text(
                              rotatingArrow,
                              style: TextStyle(
                                color: Appcolors.appLogoColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Threads: $activeThreads",
                              style: TextStyle(
                                color: Colors.blue[400],
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            // Show only the most recent thread activity
                            if (threadInfo.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  threadInfo.split('|').last.trim(),
                                  style: TextStyle(
                                    color: Colors.blue[300],
                                    fontSize: 7,
                                    fontFamily: 'monospace',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }
                    return Container();
                  }),
                ],
                if (widget.task.totalNum != null &&
                    (widget.task.isDownloading ?? false)) ...[
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: Appcolors.appAccentColor.withOpacity(0.1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (() {
                          // Get effective progress to prevent resets
                          final rawOverallProgress =
                              widget.downloadinfo["overallProgress"] ?? 0.0;
                          final storedProgress =
                              _lastKnownProgress[widget.task.id];
                          final effectiveOverallProgress =
                              rawOverallProgress > 0
                                  ? rawOverallProgress
                                  : (storedProgress != null &&
                                          storedProgress["overallProgress"] > 0
                                      ? storedProgress["overallProgress"]
                                      : 0.0);

                          if (effectiveOverallProgress > 0) {
                            return (effectiveOverallProgress / 100)
                                .clamp(0.0, 1.0);
                          }

                          // Fallback to legacy calculation with effective values
                          final current = widget.downloadinfo["total"] ?? 0;
                          final effectiveCurrent = current > 0
                              ? current
                              : (storedProgress != null &&
                                      storedProgress["current"] > 0
                                  ? storedProgress["current"]
                                  : 0);
                          final total = widget.task.totalNum ?? 0;
                          if (total == 0) return 0.0;
                          return (effectiveCurrent / total).clamp(0.0, 1.0);
                        })(),
                        backgroundColor: Colors.transparent,
                        color: Appcolors.appPrimaryColor,
                      ),
                    ),
                  ),
                ]
              ],
            )))
          ],
        ),
      ),
    );
  }
}

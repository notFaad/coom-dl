import 'dart:convert';
import 'package:coom_dl/data/models/DlTask.dart';
import 'package:coom_dl/utils/FileSizeConverter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:isar/isar.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';

import '../constant/appcolors.dart';
import 'MiniPerformanceChart.dart';

class DownloadWidget extends StatefulWidget {
  DownloadTask task;
  Isar isar;
  Map<String, dynamic> downloadinfo;
  DownloadWidget(
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
  Widget build(BuildContext context) {
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
        height: 100,
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
                child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
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
                                fontSize: 21),
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
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.all(5),
                      height: 40,
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
                                  // Pause Download Button
                                  await widget.isar.writeTxn(() async {
                                    DownloadTask? temp = await widget
                                        .isar.downloadTasks
                                        .where()
                                        .idEqualTo(widget.task.id)
                                        .findFirst();
                                    if (temp != null) {
                                      temp.isPaused = !temp.isPaused!;

                                      await widget.isar.downloadTasks.put(temp);
                                    }
                                  });

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
                                  // Stop and Delete download
                                  var tmp = await widget.isar.downloadTasks
                                      .filter()
                                      .idEqualTo(widget.task.id)
                                      .findFirst();

                                  tmp!.isCanceled = true;
                                  await widget.isar.writeTxn(() async {
                                    await widget.isar.downloadTasks.put(tmp);
                                  });
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

                const Spacer(),
                // Download information
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 1),
                      child: () {
                        if (widget.task.totalNum == null &&
                            (widget.task.isDownloading ?? false)) {
                          return const Text(
                            overflow: TextOverflow.ellipsis,
                            "Contacting Crawler...",
                            style: TextStyle(
                                color: Appcolors.appPrimaryColor, fontSize: 11),
                          )
                              .animate(
                            onPlay: (controller) =>
                                controller.repeat(reverse: false),
                          )
                              .shimmer(
                                  duration: const Duration(
                                      seconds: 1, milliseconds: 200),
                                  colors: [
                                Appcolors.appLogoColor,
                                Appcolors.appPrimaryColor
                              ]);
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
                                fontSize: 14,
                                fontWeight: FontWeight.w500),
                          );
                        } else {
                          return Text(
                            overflow: TextOverflow.ellipsis,
                            "[ ${widget.downloadinfo["total"] ?? 0} / ${widget.task.totalNum ?? 0} ] | OK: ${widget.downloadinfo["ok"] ?? 0} | FAIL: ${widget.downloadinfo["fail"] ?? 0} | RETRY: ${widget.downloadinfo["retries"] ?? 0} | ${(() {
                              final total = widget.task.totalNum ?? 0;
                              final current = widget.downloadinfo["total"] ?? 0;
                              if (total == 0) return "0.0";
                              return ((current / total) * 100)
                                  .toStringAsFixed(1);
                            })()} % | ${FileSizeConverter.getFileSizeString(bytes: widget.downloadinfo["size"] ?? 0)}",
                            style: TextStyle(
                                color: Appcolors.appPrimaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                          )
                              .animate(
                            onPlay: (controller) =>
                                controller.repeat(reverse: false),
                          )
                              .shimmer(
                                  duration: const Duration(
                                      seconds: 4, milliseconds: 0),
                                  colors: [
                                Colors.green[200]!,
                                Appcolors.appLogoColor
                              ]);
                        }
                      }(),
                    )
                  ],
                ),
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
                          final total = widget.task.totalNum ?? 0;
                          final current = widget.downloadinfo['total'] ?? 0;
                          if (total == 0) return 0.0;
                          return (current / total).clamp(0.0, 1.0);
                        })(),
                        backgroundColor: Colors.transparent,
                        color: Appcolors.appPrimaryColor,
                      ),
                    ),
                  ),
                ]
              ],
            ))
          ],
        ),
      ),
    );
  }
}

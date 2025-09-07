import 'dart:async';
import 'dart:ui';

import 'package:coom_dl/data/models/DlTask.dart';
import 'package:coom_dl/data/models/Link.dart';
import 'package:coom_dl/downloader/coomercrawl.dart';
import 'package:coom_dl/view-models/Catalyex_engine.dart';
import 'package:get/get.dart';
import 'package:isar/isar.dart';
import 'package:hive/hive.dart';

class DownloadTaskServices {
  DownloadTask task;
  List<List<dynamic>> logger = [];
  DownloadTaskServices({required this.task});

  Future<void> startDownload(
    Isar isar,
    StreamSink singleComplete,
    StreamSink SendLogs,
    int type,
  ) async {
    // Check engine setting
    Box settingsBox = Hive.box("settings");
    Map settingMap = settingsBox.toMap();
    int selectedEngine = settingMap['eng'] ?? 0;

    print("🎯 DOWNLOAD TASK SERVICE: Using engine $selectedEngine");

    if (selectedEngine == 3) {
      // Use Catalyex Engine
      print("🚀 DOWNLOAD TASK SERVICE: Starting Catalyex Engine");
      await _startCatalyexDownload(isar, singleComplete, SendLogs, type);
      return;
    }

    // Use default CybCrawl (Recooma Engine)
    print("🚀 DOWNLOAD TASK SERVICE: Using CybCrawl (Recooma Engine)");

    int completed = 0;
    int size = 0;
    int fail = 0;
    int fetch = 0;
    int retryCount = 0;
    await CybCrawl.getFileContent(
      downloadID: task.id,
      url: task.url,
      isar: isar,
      onError: () {
        IsolateNameServer.removePortNameMapping("sub");
        IsolateNameServer.removePortNameMapping("send");
        IsolateNameServer.removePortNameMapping("single");
        isar.writeTxn(() async {
          DownloadTask? temp =
              await isar.downloadTasks.where().idEqualTo(task.id).findFirst();
          if (temp != null) {
            temp.isFailed = true;
            temp.isCanceled = false;
            temp.isDownloading = false;
            temp.isPaused = false;
            temp.isCompleted = false;
            await isar.downloadTasks.put(temp);
          }
        });
      },
      onComplete: () async {
        await isar.downloadTasks.where().idEqualTo(task.id).findFirst().then(
            (temp) async {
          if (temp != null) {
            int completedLinks = 0;
            int failedLinks = 0;
            int totalFetched = 0;
            int totalRetries = 0;
            List<Links> linksList = [];
            for (int i = 0; i < logger.length; i++) {
              Map<String, dynamic> logEntry = logger[i][0];
              String status = logEntry['status'] ?? '';

              if (status == "ok") {
                completedLinks++;
                if (logEntry.containsKey('id')) {
                  try {
                    var link = temp.links
                        .firstWhere((element) => element.id == logEntry['id']);
                    link.isCompleted = true;
                    linksList.add(link);
                  } catch (e) {
                    print(
                        'Link not found for completed status: ${logEntry['id']}');
                  }
                }
              } else if (status == "fail" || status == "error") {
                failedLinks++;
                if (logEntry.containsKey('id')) {
                  try {
                    var link = temp.links
                        .firstWhere((element) => element.id == logEntry['id']);
                    link.isFailure = true;
                    linksList.add(link);
                  } catch (e) {
                    print(
                        'Link not found for failed status: ${logEntry['id']}');
                  }
                }
              } else if (status == "retry") {
                totalRetries++;
                // Don't count retries as separate downloads
              } else if (status == "skip") {
                // Count skipped files as completed
                completedLinks++;
                if (logEntry.containsKey('id')) {
                  try {
                    var link = temp.links
                        .firstWhere((element) => element.id == logEntry['id']);
                    link.isCompleted = true;
                    link.skipped = true;
                    linksList.add(link);
                  } catch (e) {
                    print(
                        'Link not found for skipped status: ${logEntry['id']}');
                  }
                }
              }

              // Update total fetched from the counter (second element in array)
              if (i == logger.length - 1) {
                totalFetched = logger[i][1];
              }
            }

            temp.numFetched = totalFetched;
            temp.numCompleted = completedLinks;
            temp.numFailed = failedLinks;
            temp.numRetries = totalRetries;
            temp.isCompleted = true;
            temp.isDownloading = false;
            temp.links.clear();
            temp.links.addAllIf(linksList.isNotEmpty, linksList);

            await isar.writeTxn(() async {
              if (linksList.isNotEmpty) {
                await isar.links.putAll(linksList);
                await temp.links.save();
              }
              await isar.downloadTasks.put(temp);
            });
          }
        }, onError: (e) {});

        //send to stream
        singleComplete.add({"": ""});
      },
      download_type: type,
      onDownloadedAlbum: (value) async {
        print("onDownloadValue $value");
      },
      totalAlbums: (value) async {
        DownloadTask? temp =
            await isar.downloadTasks.where().idEqualTo(task.id).findFirst();
        if (temp != null) {
          temp.totalNum = value[0];
          temp.name = value[1];
        }
        await isar.writeTxn(() async {
          if (temp != null) {
            await isar.downloadTasks.put(temp);
          }
        });
      },
      onThreadchange: (value) {},
      direct: task.storagePath,
      log: (val) {
        //TO MEM
        fetch = val[1];
        String status = val[0]['status'] ?? '';

        // Debug logging
        print('Download Log Entry: ${val[0]}');

        if (status == "ok") {
          completed++;
          size += val[0]['size'] as int;
        } else if (status == "fail" || status == "error") {
          fail++;
          print('FAIL detected: $fail total fails');
        } else if (status == "retry") {
          retryCount++;
          print('RETRY detected: $retryCount total retries');
        } else if (status == "skip") {
          completed++; // Count skipped as completed
        }

        logger.add(val);
        //send to stream
        Map<String, dynamic> logData = {
          "ok": completed,
          "fail": fail,
          "size": size,
          "total": fetch,
          "retries": retryCount
        };

        print({task.id: logData});
        SendLogs.add({task.id: logData});
// TODO: REWRITE TO MEM FETCHING
      },
      jobs: 4,
      retry: 6,
    ).onError((error, stackTrace) {
      try {
        IsolateNameServer.removePortNameMapping("sub");
        IsolateNameServer.removePortNameMapping("send");
        IsolateNameServer.removePortNameMapping("single");
      } catch (e) {}
      return Future.error(error.toString());
    });
  }

  Future<void> _startCatalyexDownload(
    Isar isar,
    StreamSink singleComplete,
    StreamSink SendLogs,
    int type,
  ) async {
    print("🚀🚀🚀 CATALYEX: Starting download for URL: ${task.url}");

    // Initialize counters for progress tracking
    int completed = 0;
    int failed = 0;
    int totalSize = 0;

    try {
      // Create a simple callback system for Catalyex
      await CatalyexEngine().download(
        CB1: () {
          print("Catalyex: Download started");
        },
        CB2: (String message) {
          // Reduce verbosity - only print non-repetitive messages
          if (!message.contains('📥') && !message.contains('%')) {
            print("Catalyex Progress: $message");
            SendLogs.add({
              task.id: {"status": "progress", "message": message}
            });
          }
        },
        CB3: () {
          print("Catalyex: Download completed");
          // Mark task as completed
          isar.writeTxn(() async {
            DownloadTask? temp =
                await isar.downloadTasks.where().idEqualTo(task.id).findFirst();
            if (temp != null) {
              temp.isCompleted = true;
              temp.isDownloading = false;
              temp.isFailed = false;
              await isar.downloadTasks.put(temp);
            }
          });
          singleComplete.add({"": ""});
        },
        CB4: () {
          print("Catalyex: Download error");
          // Mark task as failed
          isar.writeTxn(() async {
            DownloadTask? temp =
                await isar.downloadTasks.where().idEqualTo(task.id).findFirst();
            if (temp != null) {
              temp.isFailed = true;
              temp.isDownloading = false;
              temp.isCompleted = false;
              await isar.downloadTasks.put(temp);
            }
          });
        },
        CB5: (String filename) {
          print("Catalyex: Starting file $filename");
        },
        CB6: (String filename) {
          print("Catalyex: Completed file $filename");
        },
        CB7: (String log) {
          print("Catalyex Log: $log");
        },
        CB8: (String status) {
          print("Catalyex Status: $status");
        },
        CB9: (String update) {
          // Reduce verbosity - only print non-PROGRESS updates to avoid spam
          if (!update.startsWith('PROGRESS:')) {
            print("Catalyex Update: $update");
          }
          // Handle task info updates (name and total files)
          if (update.startsWith('TASK_INFO:')) {
            final parts = update.split(':');
            if (parts.length >= 3) {
              final taskName = parts[1];
              final totalFiles = int.tryParse(parts[2]) ?? 0;

              // Update task with name and total files
              isar.writeTxn(() async {
                DownloadTask? temp = await isar.downloadTasks
                    .where()
                    .idEqualTo(task.id)
                    .findFirst();
                if (temp != null) {
                  temp.name = taskName;
                  temp.totalNum = totalFiles;
                  await isar.downloadTasks.put(temp);
                }
              });
            }
          }
          // Handle real-time progress updates for smooth progress bars
          else if (update.startsWith('PROGRESS:')) {
            final parts = update.split(':');
            if (parts.length >= 8) {
              final overallProgress = double.tryParse(parts[1]) ?? 0.0;
              final currentBytes = int.tryParse(parts[2]) ?? 0;
              final activeThreads = int.tryParse(parts[3]) ?? 0;
              final fileProgress = double.tryParse(parts[4]) ?? 0.0;
              final downloadedFiles = int.tryParse(parts[5]) ?? 0;
              final skippedFiles = int.tryParse(parts[6]) ?? 0;
              final totalFiles = int.tryParse(parts[7]) ?? 0;
              // Join all remaining parts for threadInfo since it may contain colons
              final threadInfo =
                  parts.length > 8 ? parts.sublist(8).join(':') : '';

              // Calculate estimated total size using multiple approaches
              int estimatedTotalBytes = 0;

              // Approach 1: Use percentage-based calculation if we have meaningful progress
              if (overallProgress > 5.0 && currentBytes > 0) {
                estimatedTotalBytes =
                    (currentBytes / (overallProgress / 100.0)).round();
              }

              // Approach 2: Use average file size if we have completed files but low progress
              if (estimatedTotalBytes == 0 &&
                  (downloadedFiles + skippedFiles) > 0 &&
                  currentBytes > 0) {
                final completedFiles = downloadedFiles + skippedFiles;
                final averageFileSize = (currentBytes / completedFiles).round();
                estimatedTotalBytes = averageFileSize * totalFiles;
              }

              // Approach 3: If still no estimate and we have some data, use a conservative estimate
              if (estimatedTotalBytes == 0 && totalSize > 0 && completed > 0) {
                final averageCompletedFileSize =
                    (totalSize / completed).round();
                estimatedTotalBytes = averageCompletedFileSize * totalFiles;
              }

              // Send real-time progress update
              SendLogs.add({
                task.id: {
                  "ok": downloadedFiles,
                  "fail": failed,
                  "skipped": skippedFiles, // Add skipped files to progress data
                  "size":
                      currentBytes, // Use currentBytes which includes all files (downloaded + skipped)
                  "total": downloadedFiles +
                      skippedFiles, // Current completed (downloaded + skipped)
                  "retries": 0,
                  "overallProgress": overallProgress,
                  "fileProgress": fileProgress,
                  "totalFiles": totalFiles,
                  "currentBytes": currentBytes,
                  "totalBytes": estimatedTotalBytes, // Use estimated total size
                  "activeThreads": activeThreads,
                  "threadInfo": threadInfo
                }
              });

              // Debug print to check values and estimation
              print(
                  "Size Estimation Debug - Progress: $overallProgress%, Current: ${(currentBytes / 1024 / 1024).toStringAsFixed(1)}MB, Estimated: ${(estimatedTotalBytes / 1024 / 1024).toStringAsFixed(1)}MB");
              print(
                  "Progress Debug - Downloaded: $downloadedFiles, Skipped: $skippedFiles, Total: $totalFiles");
            }
          }
          // Handle log entries for download progress
          else if (update.startsWith('LOG_ENTRY:')) {
            final parts = update.split(':');
            if (parts.length >= 4) {
              final status = parts[1];
              final fileSize = int.tryParse(parts[2]) ?? 0;
              final currentIndex = int.tryParse(parts[3]) ?? 0;

              // Update counters
              if (status == 'ok') {
                completed++;
                totalSize += fileSize;
              } else if (status == 'fail') {
                failed++;
              }

              // Note: Don't send progress update here as it conflicts with the enhanced PROGRESS: format
              // The PROGRESS: updates above already handle the progress reporting with more detail
            }
          }
        },
        CB10: () {},
        CB11: () {},
        CB12: () {},
        CB13: () {},
        CB14: () {},
        URL: task.url,
        outputfolder: task.storagePath,
        dirname:
            "", // Remove catalyex_download folder - files go directly into organized structure
        nameformat: "%filename%",
        settingMap: Hive.box("settings").toMap(),
        Debug: false,
        links_config: Hive.box("links").toMap(),
      );
    } catch (e) {
      print("🚀🚀🚀 CATALYEX ERROR: $e");
      // Mark task as failed
      isar.writeTxn(() async {
        DownloadTask? temp =
            await isar.downloadTasks.where().idEqualTo(task.id).findFirst();
        if (temp != null) {
          temp.isFailed = true;
          temp.isDownloading = false;
          temp.isCompleted = false;
          await isar.downloadTasks.put(temp);
        }
      });
    }
  }
}

import 'dart:async';
import 'dart:ui';

import 'package:coom_dl/data/models/DlTask.dart';
import 'package:coom_dl/data/models/Link.dart';
import 'package:coom_dl/downloader/coomercrawl.dart';
import 'package:get/get.dart';
import 'package:isar/isar.dart';

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
    int completed = 0;
    int size = 0;
    int fail = 0;
    int fetch = 0;
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
            List<Links> linksList = [];
            for (int i = 0; i < logger.length; i++) {
              if (logger[i][0]['status'] == "ok") {
                completedLinks++;
                var link = temp.links
                    .firstWhere((element) => element.id == logger[i][0]['id']);
                link.isCompleted = true;
                linksList.add(link);
              } else if (logger[i][0]['status'] == "fail") {
                failedLinks++;
                var link = temp.links
                    .firstWhere((element) => element.id == logger[i][0]['id']);
                link.isFailure = true;
                linksList.add(link);
              }
              if (i == logger.length - 1) {
                totalFetched = logger[i][1];
              }
            }

            temp.numFetched = totalFetched;
            temp.numCompleted = completedLinks;
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
        if (val[0]['status'] == "ok") {
          completed++;
          size += val[0]['size'] as int;
        } else if (val[0]['status'] == "fail") {
          fail++;
        }

        logger.add(val);
        //send to stream
        print({
          task.id: {"ok": completed, "fail": fail, "size": size, "total": fetch}
        });
        SendLogs.add({
          task.id: {"ok": completed, "fail": fail, "size": size, "total": fetch}
        });
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
}

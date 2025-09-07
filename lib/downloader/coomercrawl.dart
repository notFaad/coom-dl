import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:coom_dl/crawlers/KemonoCoomer.dart';
import 'package:coom_dl/crawlers/eromeCrawl.dart';
import 'package:coom_dl/crawlers/fapelloCrawler.dart';
import 'package:coom_dl/data/models/DlTask.dart';
import 'package:coom_dl/data/models/Link.dart';
import 'package:coom_dl/data/models/download.dart';
import 'package:coom_dl/neocrawler/coomer_crawler.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:html/dom.dart' as dom;
import 'package:isar/isar.dart';
import 'package:system_info2/system_info2.dart';
import 'package:uuid/uuid.dart';

class CybCrawl {
  CybCrawl();

  static Future<void> getFileContent({
    required String url,
    required Isar isar,
    required int downloadID,
    required onComplete,
    required int download_type,
    required onDownloadedAlbum,
    required totalAlbums,
    required onThreadchange,
    required direct,
    required Function() onError,
    required Function(List<dynamic> value) log,
    required int jobs,
    required int retry,
  }) async {
    dom.Document html;
    http.Response response;
    bool isPaused = false;
    bool isContinue = true;
    Map? contents = null;
    print("Started");
    try {
      if (RegExp(r'^((https:\/\/)|(https:\/\/www\.))?coomer\.(party|su|st){1}\/(onlyfans|fansly|candfans){1}\/user{1}\/.+$')
              .hasMatch(url) ||
          RegExp(r'^((https:\/\/)|(https:\/\/www\.))?kemono\.(party|su|cr){1}\/.+$')
              .hasMatch(url)) {
        contents = await NeoCoomer.init(
          url: url,
        );
      } else {
        contents = null;
      }

      if (contents == null) {
        onError();
        return Future.error("Unsupported Link");
      }
    } catch (e) {
      onError();
      return Future.error(e);
    }
    // TODO: REWRITE TO MEM FETCHING
    List<Links> links = [];
    try {
      List<DownloadItem> scrapedItems = contents['downloads'];

      for (int i = 0; i < scrapedItems.length; i++) {
        links.add(Links()
          ..filename = scrapedItems[i].downloadName
          ..isCompleted = false
          ..skipped = false
          ..type = scrapedItems[i].mimeType
          ..isFailure = false
          ..url = scrapedItems[i].link);
      }
      await isar.writeTxn(() async {
        await isar.links.putAll(links);
      });
      var atom =
          await isar.downloadTasks.where().idEqualTo(downloadID).findFirst();
      atom!.links.addAll(links);
      await isar.writeTxn(() async {
        await atom.links.save();
      });
    } catch (e) {
      onError();
      return Future.error("Failed Storing Links to DB $e");
    }

    var isPausedWatcher = isar.downloadTasks
        .where()
        .idEqualTo(downloadID)
        .isPausedProperty()
        .watch(fireImmediately: true)
        .listen(
      (event) {
        isPaused = event.first!;
        print(isPaused);
      },
    );

    var isCanceledWatcher = isar.downloadTasks
        .where()
        .idEqualTo(downloadID)
        .isCanceledProperty()
        .watch(fireImmediately: true)
        .listen(
      (event) {
        isContinue = !(event.first ?? false);
        print("isContinue: $isContinue");
      },
    );
    try {
      await totalAlbums([contents!['count'] ?? 1, "${contents!['folder']}"]);
    } catch (e) {
      onError();
      return Future.error("Crawler is Empty");
    }
    int threads_used = 0;
    ReceivePort port = new ReceivePort();
    int totalDownloaded = 0;
    if (IsolateNameServer.lookupPortByName("send") == null)
      IsolateNameServer.registerPortWithName(port.sendPort, "send");
    Map<String, dynamic> wrt = {};
    port.listen((message) async {
      totalDownloaded++;
      threads_used--;

      // Enhanced completion logging
      if (message is Map && message.containsKey('thread_id')) {
        Map<String, dynamic> logData = {
          'title': 'THREAD_COMPLETE',
          'status': 'COMPLETED',
          'm':
              '${message['thread_id']} completed download: ${message['filename'] ?? "unknown"}',
          'thread_id': message['thread_id'],
          'success': message['success'] ?? true,
          'timestamp': DateTime.now().toIso8601String(),
          'total_completed': totalDownloaded,
          'active_threads': threads_used
        };

        IsolateNameServer.lookupPortByName("single")?.send(logData);
        IsolateNameServer.lookupPortByName("debug_monitor")?.send(logData);
      }
    });
    ReceivePort logger2 = ReceivePort();
    IsolateNameServer.registerPortWithName(logger2.sendPort, "single");

    logger2.listen((message) async {
      log([message, totalDownloaded]);
      wrt.addEntries(
          {"${DateTime.now().millisecondsSinceEpoch}": message}.entries);
    });

    bool pauselocker = false;
    List<Isolate> isoList = [];
    IsolateNameServer.lookupPortByName("single")?.send({
      'title': 'DOWNLOAD_TYPE',
      'status': 'DL_ENGINE_PARAM',
      'm': 'DOWNLOADING MODE: ${() {
        if (download_type == 0) {
          return "ALL MEDIA";
        } else if (download_type == 1) {
          return "VIDEO MEDIA";
        } else if (download_type == 2) {
          return "PICTURE MEDIA";
        } else {
          return "MISC MEDIA";
        }
      }()}'
    });
    for (var i = 0; i < links.length; i++) {
      if ((threads_used < jobs) && isContinue && !isPaused) {
        pauselocker = false;

        // Enhanced logging for thread and URL tracking
        String threadId = "Thread-${threads_used + 1}";
        String fileName = links[i].filename ?? "unknown_file";
        String url = links[i].url ?? "unknown_url";

        IsolateNameServer.lookupPortByName("single")?.send({
          'title': 'THREAD_START',
          'status': 'DOWNLOADING',
          'm': '$threadId starting download: $fileName',
          'url': url,
          'thread_id': threadId,
          'file_index': i,
          'timestamp': DateTime.now().toIso8601String()
        });

        // Send to debug monitor if enabled
        IsolateNameServer.lookupPortByName("debug_monitor")?.send({
          'title': 'THREAD_START',
          'status': 'DOWNLOADING',
          'm': '$threadId starting download: $fileName',
          'url': url,
          'thread_id': threadId,
          'file_index': i,
          'timestamp': DateTime.now().toIso8601String()
        });

        threads_used++;

        onThreadchange(threads_used);
        Isolate? iso;
        try {
          iso = await Isolate.spawn(
            creator_parallel_download,
            [
              port.sendPort,
              links[i],
              direct.toString(),
              retry,
              () {
                // isDownloadVideos: true for All Media (0) or Videos Only (1)
                if (download_type == 0) {
                  return true; // All Media
                } else if (download_type == 1) {
                  return true; // Videos Only
                } else {
                  return false; // Pictures/Misc Only
                }
              }(),
              () {
                // isDownloadPictures: true for All Media (0) or Pictures Only (2)
                if (download_type == 0) {
                  return true; // All Media
                } else if (download_type == 2) {
                  return true; // Pictures Only
                } else {
                  return false; // Videos/Misc Only
                }
              }(),
              () {
                // isDownloadMisc: true for All Media (0) or Misc Only (3)
                if (download_type == 0) {
                  return true; // All Media
                } else if (download_type == 3) {
                  return true; // Misc Only
                } else {
                  return false; // Videos/Pictures Only
                }
              }(),
              contents['folder'],
              links[i].id
            ],
          );
          isoList.add(iso);
          print(isoList.length);
        } catch (e) {
          onError();
          return Future.error("This Device is not supported");
        }
      } else if (!isContinue) {
        await Future.delayed(Duration(milliseconds: 400));
        break;
      } else if (isContinue && isPaused) {
        if (pauselocker == false) {
          for (int j = 0; j < isoList.length; j++) {
            isoList[j].kill();
          }
          int diff = i - isoList.length;
          i = i - diff;
          threads_used = 0;
          if (i < 0) {
            i = 1;
          }
        }
        pauselocker = true;
        i--;

        await Future.delayed(const Duration(milliseconds: 300));
      } else {
        onThreadchange(threads_used);

        await Future.delayed(const Duration(milliseconds: 300));

        i--; // try the content again
      }
    }

    while (threads_used != 0 && isContinue) {
      onThreadchange(threads_used);
      await Future.delayed(const Duration(seconds: 1));
    }
    for (int i = 0; i < isoList.length; i++) {
      isoList[i].kill();
    }
    File logger = File("$direct/${contents['folder']}/COOMCRWL_ENGINE_LOG.txt");
    await logger.create(recursive: true);
    var writter = logger.openWrite();
    writter.write(wrt.toString());
    await writter.close();
    IsolateNameServer.removePortNameMapping("sub");
    IsolateNameServer.removePortNameMapping("send");
    IsolateNameServer.removePortNameMapping("single");
    isPausedWatcher.cancel();
    isCanceledWatcher.cancel();
    port.close();
    totalDownloaded = 0;
    threads_used = 0;
    onComplete();
  }

  static Future<void> Post_Download(Uri imageURL, String? downloadName,
      String creator, String type, String dire, int re, int downloadID) async {
    bool backup = false;
    String file_name = "";
    String path = "$dire/${creator}/${() {
      return type;
    }()}";
    var uuid = const Uuid().v4();
    String backupPath = "$dire/${uuid}/$creator/";
    bool done = false;
    int retry_count = 0;

    if (imageURL.host.contains("download.php")) {
      Map<String, String> headers = {};
      if (imageURL.host.contains("coomer") ||
          imageURL.host.contains("kemono")) {
        headers = {"Accept": "text/css"};
      }
      http.Response r = await http.head(imageURL, headers: headers);
      file_name = r.headers["Content-Disposition"] ?? "";
    }

    if (imageURL.host.contains("download.php")) {
      path = "$dire/${creator}/Videos";
      downloadName = file_name
          .split(';')
          .where((n) => n.contains('filename='))
          .first
          .replaceAll('filename=', '')
          .replaceAll('"', "")
          .trim();
      print("CHANGED to $downloadName");
    }

    while (!done && retry_count <= re) {
      if (retry_count == re) {
        IsolateNameServer.lookupPortByName("single")?.send({
          'title': '$downloadName',
          'status': 'fail',
          'id': downloadID,
          'message': "Failed to download after $re retries"
        });
        break;
      }
      Directory directory = await Directory(path)
          .create(recursive: true)
          .onError((error, stackTrace) async {
        print("Error Directory");
        backup = true;
        return await Directory(backupPath).create(recursive: true);
      });

      File? f;
      File? log;
      String dioPath;
      if (!backup) {
        f = File("$path/$downloadName");
        dioPath = "$path/$downloadName";
      } else {
        f = File("$backupPath/$downloadName");
        dioPath = "$backupPath/$downloadName";
      }

      if (f.existsSync()) {
        if (!(await f.length() < 1000)) {
          //Skip
          // TODO: HIVE Skipping to Global box.

          // store.add({"title": "$downloadName", "status": "skip"});
          IsolateNameServer.lookupPortByName("single")?.send(
              {'title': '$downloadName', 'status': 'skip', "id": downloadID});
          return Future.error("File already exits");
        } else {
          IsolateNameServer.lookupPortByName("single")?.send({
            'title': '$downloadName',
            'status': 'retry',
            'id': downloadID,
            'retry_count': retry_count + 1,
            'finalsize': 162,
            'size': await f.length(),
            'message': 'Retrying download due to incomplete file'
          });
        }
      }
      http.BaseRequest connection = http.Request('GET', imageURL);
      var dio = Dio();
      if (imageURL.host.contains("erome")) {
        //Solves Erome 405 not allowed Error:
        dio.options.headers = {"Referer": "https://www.erome.com/"};
      } else if (imageURL.host.contains("coomer") ||
          imageURL.host.contains("kemono")) {
        //Solves Coomer/Kemono DDoS guard protection:
        dio.options.headers = {"Accept": "text/css"};
      }

      // Creates a HTTP dependent stream to directly inject bytes to ioSink instead of MEM.
      IsolateNameServer.lookupPortByName("single")?.send({
        'title': '$downloadName',
        'status': 'starting',
        'm': 'Fetching..',
        'id': downloadID,
      });
      var download_response = await dio.downloadUri(
        imageURL,
        dioPath,
      );

      /** 
       * Pre 0.75 method
      var incoming = await http.Client().send(connection);
      await f.create().whenComplete(() => print("File created"));
      var sink = f.openWrite();*/

      /**
       * HTTP contents are streamed to an IOSINK, and then to a file.
       * Instead of writing the whole responseBytes to MEM which can crash the program if file size is larger than the user's RAM CAP.
       */
      //TODO Add file_size with the regular dio request.
      // await incoming.stream.pipe(sink);
      // print("Stream Done");
      if (await f.length() <
          int.parse(download_response.headers['Content-Length']![0])) {
        // TODO TIMEOUT
        // store.add({"title": "$downloadName", "status": "error"});
        await f.delete(recursive: true);
        IsolateNameServer.lookupPortByName("single")?.send({
          'title': '$downloadName',
          'status': 'error',
          'id': downloadID,
          "retry": retry_count + 1
        });
        retry_count++;
      } else {
        // TODO DOWNLOADED
        // store.add({"title": "$downloadName", "status": "ok"});
        IsolateNameServer.lookupPortByName("single")?.send({
          'title': '$downloadName',
          'status': 'ok',
          'id': downloadID,
          "attempt": (retry_count),
          'size': await f.length()
        });
        done = true;
      }
      // await store.close();
      // pre 0.75
      // await sink.flush();
      //await sink.close();
    }
  }

  @pragma('vm:entry-point')
  static Future<void> creator_parallel_download(List<dynamic> args) async {
    SendPort sender = args[0];
    Links downloads = args[1];
    String dire = args[2];
    int rere = args[3];
    bool isDownloadVideos = args[4];
    bool isDownloadPictures = args[5];
    bool isDownloadMisc = args[6];
    String folder = args[7];
    int? downloadID = args[8];
    bool isDownloadable = true;
    try {
      //print(
      // "https://coomer.su${contents_a[i].children[0].attributes['href']}");

      if (!isDownloadVideos) {
        if (downloads.type! == "Videos") {
          isDownloadable = false;
        }
      }
      if (!isDownloadPictures) {
        if (downloads.type! == "Photos") {
          isDownloadable = false;
        }
      }
      if (!isDownloadMisc) {
        if (downloads.type! == "Misc") {
          isDownloadable = false;
        }
      }

      if (isDownloadable) {
        try {
          await Post_Download(Uri.parse(downloads.url!), downloads.filename,
              folder, downloads.type!, dire, rere, downloadID!);
        } catch (e) {}
      }
      IsolateNameServer.lookupPortByName("send")?.send([true]);
    } catch (e) {
      print("$e");
      IsolateNameServer.lookupPortByName("send")?.send([false]);
      return Future.error("Error");
    }

    print("Done");
  }
  //JPi4AFCQ
}

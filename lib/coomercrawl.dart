import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:coom_dl/crawlers/KemonoCoomer.dart';
import 'package:coom_dl/crawlers/eromeCrawl.dart';
import 'package:coom_dl/crawlers/fapelloCrawler.dart';
import 'package:coom_dl/data/models/download.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:html/dom.dart' as dom;
import 'package:system_info2/system_info2.dart';
import 'package:uuid/uuid.dart';

class CybCrawl {
  CybCrawl();

  Future<void> getFileContent(
      {required String url,
      required onComplete,
      required Function(Map<dynamic, dynamic> value) scrap,
      required int download_type,
      required onDownloadedAlbum,
      required totalAlbums,
      required onThreadchange,
      required direct,
      required Function(Map<dynamic, dynamic> value) log,
      required bool Function() isContinue,
      required int jobs,
      required int retry,
      required Map links_config,
      required typer}) async {
    dom.Document html;
    http.Response response;
    if (typer == null) {
      return Future.error("Failed Retrieving Content!");
    }

    //print(response.body);

    //Crawl the iframe of saint.to
    // Decode the html inside to an html page. then get the download button.

    /*
    totalAlbums([
      () {
        if (typer > 2 && typer != 6) {
          return 1;
        } else {
          return contents_a.length;
        }
      }(),
      "${typer > 2 && typer != 6 ? url.toString().split("/").last : creator_html!.innerHtml}"
    ]);
    */
    Map? contents = null;
    try {
      if (url.contains("coomer.party") ||
          url.contains("coomer.su") ||
          url.contains("kemono.su") ||
          url.contains("kemono.party")) {
        contents = await KemonoCoomerCrawler()
            .init(url: url, links_config: links_config, scrape_logg: scrap);
      } else if (url.contains("erome.com")) {
        contents =
            await EromeCrawler().init(url: url, links_config: links_config);
      } else if (url.contains("fapello.su") || url.contains("fapello.com")) {
        contents =
            await FapelloCrawler().init(url: url, links_config: links_config);
      } else {
        contents = null;
      }

      if (contents == null) {
        Future.error("Unsupported Link");
      }
    } catch (e) {
      return Future.error(e);
    }
    totalAlbums([
      () {
        if (typer > 2 && typer != 6) {
          return 1;
        } else {
          return contents!['count'];
        }
      }(),
      "${contents!['folder']}"
    ]);
    int threads_used = 0;
    ReceivePort port = new ReceivePort();
    int totalDownloaded = 0;
    IsolateNameServer.registerPortWithName(port.sendPort, "send");

    Map<String, dynamic> wrt = {};
    port.listen((message) {
      print("port 1 done");
      totalDownloaded++;
      onDownloadedAlbum(totalDownloaded);
      threads_used--;
    });
    ReceivePort logger2 = ReceivePort();
    IsolateNameServer.registerPortWithName(logger2.sendPort, "single");

    logger2.listen((message) {
      print("SINGLE DOWNLOADED");
      log(message);
      wrt.addEntries(
          {"${DateTime.now().millisecondsSinceEpoch}": message}.entries);
    });
    List<Isolate> isoList = [];
    print("hello");
    print(threads_used);
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
    for (var i = 0; i < contents!['downloads'].length; i++) {
      if ((threads_used < jobs) && isContinue()) {
        print("$threads_used/$jobs");
        threads_used++;
        print(threads_used);
        onThreadchange(threads_used);
        Isolate? iso;
        try {
          iso = await Isolate.spawn(
            creator_parallel_download,
            [
              port.sendPort,
              contents['downloads'][i],
              direct.toString(),
              retry,
              () {
                if (download_type == 0) {
                  return true;
                } else if (download_type == 1) {
                  return true;
                } else {
                  return false;
                }
              }(),
              () {
                if (download_type == 0) {
                  return true;
                } else if (download_type == 2) {
                  return true;
                } else {
                  return false;
                }
              }(),
              () {
                if (download_type == 0) {
                  return true;
                } else if (download_type == 3) {
                  return true;
                } else {
                  return false;
                }
              }(),
              contents['folder']
            ],
          );
          isoList.add(iso);
        } catch (e) {
          print("Engine Error");
          return Future.error(
              "Cannot Isolate Thread in this Device [Engine configs not supported Error]");
        }
      } else if (!isContinue() && typer < 3) {
        break;
      } else if (!isContinue() && typer >= 3) {
        IsolateNameServer.lookupPortByName("break")!.send(true);
        await Future.delayed(Duration(seconds: 1));
        break;
      } else {
        onThreadchange(threads_used);
        await Future.delayed(const Duration(milliseconds: 300));
        i--;
      }
    }

    while (threads_used != 0 && isContinue()) {
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
    port.close();
    totalDownloaded = 0;
    threads_used = 0;
    onComplete("${contents['creator']}");
  }

  static Future<void> Post_Download(
    Uri imageURL,
    String? downloadName,
    String creator,
    String type,
    String dire,
    int re,
  ) async {
    print("POST__DOWNLOAD CREATOR: $creator");
    print("Media Downloader");
    print(imageURL);
    bool backup = false;
    String path = "$dire/${creator}/${() {
      return type;
    }()}";
    var uuid = const Uuid().v4();
    String backupPath = "$dire/${uuid}/$creator/";
    bool done = false;
    int retry_count = 0;
    http.Response r = await http.head(imageURL);
    int file_size = int.parse(r.headers["content-length"] ?? "1");
    String file_name = r.headers["Content-Disposition"] ?? "";

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

    print(path);
    while (!done && retry_count <= re) {
      if (retry_count == re) {
        IsolateNameServer.lookupPortByName("single")?.send({
          'title': '$downloadName',
          'status': 'fail',
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
      if (!backup) {
        f = File("$path/$downloadName");
        log = File("$path/DEBUG_logs/logs.txt");
      } else {
        f = File("$backupPath/$downloadName");
        log = File("$backupPath/DEBUG_logs/logs.txt");
      }

      if (f.existsSync()) {
        if (!(await f.length() < file_size)) {
          //Skip
          // TODO: HIVE Skipping to Global box.

          // store.add({"title": "$downloadName", "status": "skip"});
          IsolateNameServer.lookupPortByName("single")
              ?.send({'title': '$downloadName', 'status': 'skip'});
          return Future.error("File already exits");
        } else {
          IsolateNameServer.lookupPortByName("single")?.send({
            'title': '$downloadName',
            'status': 'retry',
            "finalsize": file_size,
            "size": await f.length()
          });
        }
      }
      http.BaseRequest connection = http.Request('GET', imageURL);
      if (imageURL.host.contains("erome")) {
        //Solves Erome 405 not allowed Error:
        connection.headers.addAll({"Referer": "https://www.erome.com/"});
      }

      // Creates a HTTP dependent stream to directly inject bytes to ioSink instead of MEM.
      IsolateNameServer.lookupPortByName("single")?.send(
          {'title': '$downloadName', 'status': 'starting', 'm': 'Fetching..'});
      var incoming = await http.Client().send(connection);
      await f.create().whenComplete(() => print("File created"));
      var sink = f.openWrite();

      /**
       * HTTP contents are streamed to an IOSINK, and then to a file.
       * Instead of writing the whole responseBytes to MEM which can crash the program if file size is larger than the user's RAM CAP.
       */
      await incoming.stream.pipe(sink);
      print("Stream Done");
      if (await f.length() < file_size) {
        // TODO TIMEOUT
        // store.add({"title": "$downloadName", "status": "error"});
        await f.delete(recursive: true);
        IsolateNameServer.lookupPortByName("single")?.send({
          'title': '$downloadName',
          'status': 'error',
          "retry": retry_count + 1
        });
        retry_count++;
      } else {
        // TODO DOWNLOADED
        // store.add({"title": "$downloadName", "status": "ok"});
        IsolateNameServer.lookupPortByName("single")?.send({
          'title': '$downloadName',
          'status': 'ok',
          "attempt": (retry_count),
          'size': await f.length()
        });
        done = true;
      }
      // await store.close();
      await sink.flush();
      await sink.close();
    }
  }

  @pragma('vm:entry-point')
  static Future<void> creator_parallel_download(List<dynamic> args) async {
    SendPort sender = args[0];
    DownloadItem downloads = args[1];
    String dire = args[2];
    int rere = args[3];
    bool isDownloadVideos = args[4];
    bool isDownloadPictures = args[5];
    bool isDownloadMisc = args[6];
    String folder = args[7];
    bool isDownloadable = true;
    try {
      //print(
      // "https://coomer.su${contents_a[i].children[0].attributes['href']}");

      if (!isDownloadVideos) {
        if (downloads.mimeType! == "Videos") {
          isDownloadable = false;
        }
      }
      if (!isDownloadPictures) {
        if (downloads.mimeType! == "Photos") {
          isDownloadable = false;
        }
      }
      if (!isDownloadMisc) {
        if (downloads.mimeType! == "Misc") {
          isDownloadable = false;
        }
      }

      if (isDownloadable) {
        try {
          await Post_Download(Uri.parse(downloads.link!),
              downloads.downloadName, folder, downloads.mimeType!, dire, rere);
        } catch (e) {}
      }
      IsolateNameServer.lookupPortByName("send")?.send([true]);
    } catch (e) {
      print("$e");
      IsolateNameServer.lookupPortByName("send")?.send([false]);
      return Future.error("Error");
    }

    print("done");
  }
  //JPi4AFCQ
}

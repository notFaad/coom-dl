import 'dart:async';

import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/dom.dart' as dom;
import 'package:system_info2/system_info2.dart';
import 'package:uuid/uuid.dart';

class CybCrawl {
  CybCrawl();

  Future<void> getFileContent(
      {required url,
      required onComplete,
      required onDownloadedAlbum,
      required totalAlbums,
      required onThreadchange,
      required direct,
      required Function(Map<String, dynamic> value) log,
      required bool Function() isContinue,
      required typer}) async {
    dom.Document html;
    http.Response response;
    if (typer == null) {
      return Future.error("Failed Retrieving Content!");
    }
    try {
      response = await http.get(Uri.parse(url));
    } catch (e) {
      print(e.toString());
      return Future.error("Failed Retrieving Content!");
    }

    html = dom.Document.html(response.body);
    //print(response.body);
    var creator_html = html.querySelector('span[itemprop="name"]');
    print(creator_html!.innerHtml.toString());
    var contents_a = html.querySelectorAll("section > div > div > article");
    var nextPage = html.querySelector("div > menu > a.next");
    print(nextPage);
    while (nextPage != null) {
      try {
        response = await http.get(Uri.parse(
            "${typer == 0 ? "https://coomer.su" : "https://kemono.su"}${nextPage.attributes['href']}"));
        html = dom.Document.html(response.body);
        contents_a
            .addAll(html.querySelectorAll("section > div > div > article"));
        nextPage = html.querySelector("div > menu > a.next");
      } catch (e) {
        return Future.error("Error getting next page");
      }
    }
    print("no next page");
    print(contents_a.length);
    if (contents_a.isEmpty) {
      return Future.error("Page Doesn't Exist");
    }
    totalAlbums([contents_a.length, creator_html.innerHtml]);

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
      wrt.addEntries({
        "<LOGGED AT ${DateTime.now().millisecondsSinceEpoch} MS/>": message
      }.entries);
    });
    List<Isolate> isoList = [];
    print("hello");
    print(threads_used);
    for (var i = 0; i < contents_a.length; i++) {
      if ((threads_used < SysInfo.cores.length) && isContinue()) {
        print("$threads_used/4");
        threads_used++;
        print(threads_used);
        onThreadchange(threads_used);
        Isolate? iso;
        iso = await Isolate.spawn(
          creator_parallel_download,
          [
            port.sendPort,
            "${typer == 0 ? "https://coomer.su" : "https://kemono.su"}${contents_a[i].children[0].attributes['href']}",
            creator_html.innerHtml,
            threads_used,
            direct.toString(),
          ],
        );
        isoList.add(iso);
      } else if (!isContinue()) {
        break;
      } else {
        onThreadchange(threads_used);
        print("queue");
        await Future.delayed(const Duration(milliseconds: 300));
        i--;
      }
    }

    while (threads_used != 0 && isContinue()) {
      print("Waiting for others to finish");
      onThreadchange(threads_used);
      await Future.delayed(const Duration(seconds: 1));
    }
    for (int i = 0; i < isoList.length; i++) {
      isoList[i].kill();
    }
    File logger =
        File("$direct/${creator_html.innerHtml}/COOM-DL_ENGINE_LOG.txt");
    await logger.create(recursive: true);
    var writter = logger.openWrite();
    writter.write(wrt.toString());
    await writter.close();

    IsolateNameServer.removePortNameMapping("send");
    IsolateNameServer.removePortNameMapping("single");
    port.close();
    totalDownloaded = 0;
    threads_used = 0;
    onComplete(creator_html.innerHtml);
  }

  static Future<void> Post_Download(
    Uri imageURL,
    String? downloadName,
    String creator,
    String type,
    String dire,
  ) async {
    print("Media Downloader");
    print(imageURL);
    bool backup = false;
    String path = "$dire/$creator/$type";
    var uuid = const Uuid().v4();
    String backupPath = "$dire/${uuid}/$type";

    await Directory(path)
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
      log = File("$dire/$creator/logs.txt");
    } else {
      f = File("$backupPath/$downloadName");
      log = File("$dire/${uuid}/logs.txt");
    }

    if (f.existsSync()) {
      if (!(await f.length() <= 162)) {
        //Skip
        // TODO: HIVE Skipping to Global box.

        // store.add({"title": "$downloadName", "status": "skip"});
        IsolateNameServer.lookupPortByName("single")
            ?.send({'title': '$downloadName', 'status': 'skip'});
        return Future.error("File already exits");
      }
      // Retry
      // TODO Hive retry to Global box.
      // store.add({"title": "$downloadName", "status": "retry"});
      IsolateNameServer.lookupPortByName("single")
          ?.send({'title': '$downloadName', 'status': 'retry'});
    }
    var incoming = await http.Client().send(http.Request('GET', imageURL));
    await f.create().whenComplete(() => print("File created"));
    var sink = f.openWrite();

    await incoming.stream.pipe(sink);
    print("Stream Done");
    if (await f.length() <= 162) {
      // TODO TIMEOUT
      // store.add({"title": "$downloadName", "status": "error"});
      IsolateNameServer.lookupPortByName("single")
          ?.send({'title': '$downloadName', 'status': 'error'});
    } else {
      // TODO DOWNLOADED
      // store.add({"title": "$downloadName", "status": "ok"});
      IsolateNameServer.lookupPortByName("single")
          ?.send({'title': '$downloadName', 'status': 'ok'});
    }
    // await store.close();
    await sink.flush();
    await sink.close();
  }

  @pragma('vm:entry-point')
  static Future<void> creator_parallel_download(List<dynamic> args) async {
    SendPort sender = args[0];
    String URL = args[1];
    String creator = args[2];
    int thread = args[3];
    String dire = args[4];
    print("THREAD: $thread OCCUPIED");
    try {
      await http.get(Uri.parse(URL)).then((value) async {
        //print(
        // "https://coomer.su${contents_a[i].children[0].attributes['href']}");

        var interalHtml = dom.Document.html(value.body);
        var contents_images = interalHtml.querySelectorAll(
            "div.post__thumbnail a"); //post__attachment-link
        var contents_vids =
            interalHtml.querySelectorAll("a.post__attachment-link");

        if (contents_images.isNotEmpty) {
          for (int j = 0; j < contents_images.length; j++) {
            try {
              await Post_Download(
                Uri.parse("${contents_images[j].attributes['href']}"),
                "${contents_images[j].attributes['download']}",
                creator,
                "Photos",
                dire,
              );
            } catch (e) {
              print(e);
              continue;
            }
          }
        }
        if (contents_vids.isNotEmpty) {
          for (int v = 0; v < contents_vids.length; v++) {
            try {
              await Post_Download(
                Uri.parse("${contents_vids[v].attributes['href']}"),
                "${contents_vids[v].attributes['download']}",
                creator,
                "Videos",
                dire,
              );
            } catch (e) {
              print(e);
              continue;
            }
          }
        }
      });
      IsolateNameServer.lookupPortByName("send")?.send([true]);
    } catch (e) {
      print("Error Fetching Images and videos");
      IsolateNameServer.lookupPortByName("send")?.send([false]);
      return Future.error("Error");
    }

    print("done");
  }

  //JPi4AFCQ
}

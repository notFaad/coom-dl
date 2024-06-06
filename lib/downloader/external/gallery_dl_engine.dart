import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

class GalleryDlEngine {
  Future<void> download(
      {required String url,
      required dir,
      isCon,
      required Box historyBox}) async {
    List<String> args = url.split(',');
    //osascript -e 'tell application "Terminal" to do script "cd /tmp;pwd"'
    //start "" cmd /k gallery-dl https://coomer.party/onlyfans/user/player2tiff -d Z:\Cyberdrop\coom.party

    /*          ${() {
                    String arg = "";
                    for (int i = 1; i < args.length; i++) {
                      arg += " ${args[i]} ";
                    }
                    return arg;
                  }()} -d $dir  ${args[0]}' */
    try {
      Process? p;
      if (Platform.isMacOS) {
        p = await Process.start(
                'osascript',
                [
                  '-e',
                  'tell application "Terminal" to do script "gallery-dl ${() {
                    String arg = "";
                    for (int i = 1; i < args.length; i++) {
                      arg += " ${args[i]} ";
                    }
                    return arg;
                  }()} -D $dir  ${args[0]}"'
                ],
                workingDirectory: dir)
            .onError((error, stackTrace) {
          throw const ProcessException("", []);
        });
      } else {
        p = await Process.start(
                'start',
                [
                  'cmd.exe',
                  '/k',
                  'gallery-dl${() {
                    String arg = "";
                    for (int i = 1; i < args.length; i++) {
                      arg += " ${args[i]} ";
                    }
                    return arg;
                  }()} -d $dir  ${args[0]}'
                ],
                runInShell: true,
                workingDirectory: dir)
            .onError((error, stackTrace) {
          throw ProcessException("${error.toString()}", []);
        });
      }
      p.stdout.transform(utf8.decoder).forEach(print);
      p.stderr.transform(utf8.decoder).forEach(print);

      while (await p.exitCode != 0 && isCon) {
        await Future.delayed(Duration(seconds: 1));
      }
      var start_time = DateFormat.yMd().add_jm().format(DateTime.now());
      await historyBox.add({
        "creator": "Gallery-dl",
        "start": "${start_time}",
        "end": "Unknown",
        "size": "Unknown"
      });

      print("Killed");
      p.kill();
    } catch (e) {
      print(e);
      return Future.error("[gallery-dl][error]: gallery-dl is not installed");
    }
  }
}

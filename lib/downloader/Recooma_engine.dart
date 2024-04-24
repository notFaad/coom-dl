import 'package:coom_dl/coomercrawl.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:window_manager/window_manager.dart';

class RecoomaEngine {
  //Recooma Download engine by notFaad (Coom-dl Default Engine)
  Future<void> download(
      {required Function() CB1,
      required Function(dynamic, dynamic) CB2,
      required Function() CB3,
      required Function() CB4,
      required Function(dynamic) CB5,
      required Function(dynamic) CB6,
      required Function(dynamic) CB7,
      required Function(dynamic) CB8,
      required Function(dynamic) CB9,
      required Function(dynamic) onscrape,
      required clink,
      required BuildContext context,
      required Function() CB10,
      required Function() CB11,
      required Function() CB12,
      required Function() CB13,
      required Function() CB14,
      required String creator,
      required String size,
      required bool Function() getCanceled,
      required String Function() percentage,
      required String Function() getFileSize,
      required String? url,
      required String directory,
      required bool Debug,
      required Map links_config,
      required Map settingMap,
      required int currentOption,
      required Box historyBox}) async {
    int downloadsize = 0;
    //CB1
    CB1();
    List<String> s = url!.split("\n");
    for (int i = 0; i < s.length; i++) {
      // Empty lines validators
      if (s[i].trim().isEmpty) {
        s.removeAt(i);
      }
    }
    String mem_dir = directory!.trim();
    for (int i = 0; i < s.length; i++) {
      //CB2
      CB2(i, s);
      bool ok = false;
      int? typer = null;
      // W.I.P
      // Erome
      // Lovefap
      // Fapello
      // DirtyShip
      // Eroprofile

      if (RegExp(r'^https:\/\/+').hasMatch(s[i].trim())) {
        // COOMER Creator
        typer = 0;
        ok = true;
      } else {
        // UNKNOWN LINK.
        ok = false;
      }
      print(typer);
      if (ok && typer != null) {
        //CB3
        CB3();
        var start_time = DateFormat.yMd().add_jm().format(DateTime.now());
        //CB4
        CB4();
        await new CybCrawl()
            .getFileContent(
                jobs: settingMap['job'],
                links_config: links_config,
                retry: settingMap['retry'],
                download_type: currentOption,
                isContinue: () {
                  var new_value = !getCanceled();
                  return new_value;
                },
                typer: typer,
                direct: mem_dir,
                url: s[i].trim(),
                onThreadchange: (value) {
                  //CB5
                  CB5(value);
                },
                scrap: (value) {
                  // TODO
                  onscrape(value);
                },
                log: (Map<dynamic, dynamic> values) {
                  //CB6
                  CB6(values);
                },
                onComplete: (value) async {
                  //CB7
                  CB7(value);
                  var end_time =
                      DateFormat.yMd().add_jm().format(DateTime.now());
                  String downloadSize = getFileSize();
                  await historyBox.add({
                    "creator": "${creator}",
                    "start": "${start_time}",
                    "end": "${end_time}",
                    "size": "${getFileSize()} | ${percentage()}"
                  });

                  await windowManager.setProgressBar(0);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    backgroundColor: Colors.green.withAlpha(65),
                    content: Text(
                      "Success: Finished creator download",
                      style: TextStyle(color: Colors.grey.shade300),
                    ),
                    duration: const Duration(seconds: 2),
                  ));
                },
                onDownloadedAlbum: (int value) async {
                  //CB8
                  CB8(value);
                },
                totalAlbums: (List<dynamic> value) {
                  //CB9
                  CB9(value);
                })
            .then((value) async {
          //CB10
          CB10();
        }).onError((error, stackTrace) {
          print("$error AT $stackTrace");
          //OnError
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: Colors.red.withAlpha(120),
            content: Text(
              "An Error has occurred ${() {
                if (settingMap['debug']) {
                  return error.toString();
                } else {
                  return s[i].trim();
                }
              }()}",
              style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
            ),
            duration: Duration(seconds: () {
              if (settingMap['debug']) {
                return 30;
              } else {
                return 4;
              }
            }()),
          ));
          //CB11
          CB11();
          return Future.delayed(const Duration(seconds: 3));
        });
        //CB12
        CB12();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.red.withAlpha(120),
          content: Text(
            "Error: Unknown Link! [$clink]- ${s[i]}",
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade300),
          ),
          duration: const Duration(seconds: 4),
        ));
      }
      //CB13
      CB13();
    }
    //CB14
    CB14();
  }
}

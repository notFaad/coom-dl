import 'package:coom_dl/downloader/coomercrawl.dart';
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
      required bool isStandardPhoto,
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

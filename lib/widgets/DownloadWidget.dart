import 'dart:io';

import 'package:coom_dl/data/models/DlTask.dart';
import 'package:coom_dl/utils/FileSizeConverter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:isar/isar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../constant/appcolors.dart';

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
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: Container(
        decoration: BoxDecoration(
            color: Appcolors.appNaigationColor.withAlpha(80),
            boxShadow: [
              BoxShadow(
                  color: Appcolors.appAccentColor.withAlpha(80),
                  blurRadius: 0,
                  blurStyle: BlurStyle.outer,
                  offset: const Offset(2, 2),
                  spreadRadius: 0.5)
            ],
            borderRadius: BorderRadius.circular(5)),
        height: 100,
        child: Row(
          children: [
            // image
            Column(
              children: [
                Container(
                    margin: const EdgeInsets.all(5),
                    padding: const EdgeInsets.all(5),
                    width: 90,
                    height: 90,
                    color: Appcolors.appBackgroundColor.withAlpha(80),
                    child: () {
                      if (widget.task.pathToThumbnail == null) {
                        return Image.asset(
                          'assets/Cnex.png',
                          fit: BoxFit.fitWidth,
                        );
                      } else {
                        return Image.file(
                          File(
                              "/Users/saadal-ageel/coom-dl/coomdl/assets/logo.png"),
                          fit: BoxFit.cover,
                        );
                      }
                    }()),
              ],
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
                            color: Appcolors.appBackgroundColor.withAlpha(50),
                            child: Center(
                                child: Text(
                                    "${widget.task.tag ?? "No Tag"}", // <- Site match here
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Appcolors.appPrimaryColor,
                                        fontSize: 9))))),
                    const Spacer(),
                    Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.all(5),
                      height: 40,
                      color: Appcolors.appBackgroundColor.withAlpha(50),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (widget.task.totalNum != null &&
                              (widget.task.isDownloading ?? false)) ...[
                            IconButton(
                                style: IconButton.styleFrom(
                                    hoverColor: Appcolors.appPrimaryColor,
                                    foregroundColor: Appcolors.appAccentColor,
                                    backgroundColor:
                                        Appcolors.appNaigationColor),
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
                                    hoverColor: Appcolors.appPrimaryColor,
                                    foregroundColor: Appcolors.appAccentColor,
                                    backgroundColor:
                                        Appcolors.appNaigationColor),
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
                            IconButton(
                                style: IconButton.styleFrom(
                                    hoverColor: Colors.red[400],
                                    foregroundColor: Appcolors.appAccentColor,
                                    backgroundColor:
                                        Appcolors.appNaigationColor),
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
                            "[ ${widget.downloadinfo["total"]} / ${widget.task.totalNum} ] | OK: ${widget.downloadinfo["ok"]} | FAIL: ${widget.downloadinfo["fail"]} | ${((widget.downloadinfo["total"] / widget.task.totalNum) * 100).toStringAsFixed(1)} % | ${FileSizeConverter.getFileSizeString(bytes: widget.downloadinfo["size"])}",
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
                          ;
                        }
                      }(),
                    )
                  ],
                ),
                if (widget.task.totalNum != null &&
                    (widget.task.isDownloading ?? false)) ...[
                  SizedBox(
                      height: 7.5,
                      width: double.infinity,
                      child: LinearProgressIndicator(
                        value: (widget.downloadinfo['total'] /
                            widget.task.totalNum),
                        backgroundColor: Appcolors.appLogoColor,
                        color: Appcolors.appPrimaryColor,
                      ))
                ]
              ],
            ))
          ],
        ),
      ),
    );
  }
}

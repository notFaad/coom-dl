import 'dart:async';

import 'package:coom_dl/constant/appcolors.dart';
import 'package:coom_dl/data/models/DlTask.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:isar/isar.dart';

class AddDownload extends StatefulWidget {
  Isar isar;
  StreamSink<dynamic> addDownload;

  AddDownload({Key? key, required Isar this.isar, required this.addDownload})
      : super(key: key);

  @override
  _AddDownloadState createState() => _AddDownloadState();
}

class _AddDownloadState extends State<AddDownload> {
  String? url;
  String? directory;
  int currentOption = 0;
  TextEditingController input = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white.withAlpha(5),
        leading: IconButton(
            style: IconButton.styleFrom(
                shape: BeveledRectangleBorder(
                    borderRadius: BorderRadius.circular(3.5)),
                backgroundColor: Appcolors.appNaigationColor.withAlpha(30)),
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Appcolors.appPrimaryColor,
              size: 21,
            )),
        title: const Text(
          "CNEX: add Task",
          style: TextStyle(
              color: Appcolors.appPrimaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 18),
        ),
      ),
      backgroundColor: Appcolors.appBackgroundColor,
      body: Column(
        children: [
          Container(
              height: MediaQuery.of(context).size.height * 0.80,
              margin: EdgeInsets.all(15),
              decoration: BoxDecoration(
                  color: Appcolors.appAccentColor.withAlpha(40),
                  border: Border(
                      bottom: BorderSide(
                          color: Appcolors.appLogoColor.withAlpha(120),
                          style: BorderStyle.solid,
                          width: 5,
                          strokeAlign: BorderSide.strokeAlignOutside),
                      left: BorderSide(
                          color: Appcolors.appLogoColor.withAlpha(120),
                          style: BorderStyle.solid,
                          width: 5,
                          strokeAlign: BorderSide.strokeAlignOutside)),
                  borderRadius: BorderRadius.circular(5)),
              child: Column(children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: 5, top: 5),
                      child: Text("URL: ",
                          style: TextStyle(
                              color: Appcolors.appPrimaryColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                Flexible(
                    child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 5, horizontal: 5),
                  child: TextFormField(
                    controller: input,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (value) {
                      if (value != null) {
                        if (value.isNotEmpty && GetUtils.isURL(value.trim())) {
                          return null;
                        } else {
                          return "Input must be a single url! Example: Https://example.com/example";
                        }
                      }
                    },
                    onChanged: (value) {
                      if (value.isNotEmpty && GetUtils.isURL(value.trim())) {
                        setState(() {
                          url = value;
                        });
                      } else {
                        setState(() {
                          url = null;
                        });
                      }
                    },
                    maxLines: 1,
                    style: const TextStyle(
                        color: Appcolors.appTextColor, fontSize: 11),
                    decoration: const InputDecoration(
                        contentPadding: EdgeInsets.all(5),
                        border: OutlineInputBorder(),
                        hintText:
                            "One url ex: https://www.example.com/example/",
                        hintStyle: TextStyle(
                            color: Appcolors.appTextColor, fontSize: 11)),
                  ),
                )),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: 5, top: 5),
                      child: Text("Download Directory:",
                          style: TextStyle(
                              color: Appcolors.appPrimaryColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                Row(mainAxisAlignment: MainAxisAlignment.start, children: [
                  Padding(
                    child: Container(
                      alignment: Alignment.center,
                      width: MediaQuery.of(context).size.width * 0.5,
                      height: 30,
                      decoration: BoxDecoration(
                          color: Appcolors.appAccentColor.withAlpha(50),
                          borderRadius: BorderRadius.circular(5)),
                      child: Text(
                        directory ?? "No Directory Picked",
                        style: const TextStyle(
                            color: Appcolors.appPrimaryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  Flexible(
                      child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: SizedBox(
                        height: 30,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 0),
                          child: FilledButton.icon(
                            style: ButtonStyle(backgroundColor:
                                MaterialStateProperty.resolveWith((states) {
                              return Appcolors.appAccentColor;
                            })),
                            icon: const Icon(
                              size: 14,
                              Icons.folder,
                              color: Appcolors.appPrimaryColor,
                            ),
                            onHover: (value) {},
                            onPressed: () async {
                              final String? directoryPath =
                                  await getDirectoryPath();
                              if (directoryPath == null) {
                                // Operation was canceled by the user.
                                return;
                              } else {
                                setState(() {
                                  directory = directoryPath;
                                });
                              }
                            },
                            label: const Text(
                              "Browse",
                              style: TextStyle(
                                  color: Appcolors.appPrimaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        )),
                  )),
                ]),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: 5, top: 5),
                      child: Text("Media Type:",
                          style: TextStyle(
                              color: Appcolors.appPrimaryColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    SizedBox(
                        width: 170,
                        height: 40,
                        child: ListTile(
                          title: const Text(
                            "All Media",
                            style: TextStyle(
                                color: Appcolors.appTextColor, fontSize: 11),
                          ),
                          leading: Radio(
                              activeColor: Appcolors.appPrimaryColor,
                              value: 0,
                              groupValue: currentOption,
                              onChanged: (value) {
                                setState(() {
                                  currentOption = value!;
                                });
                              }),
                        )),
                    SizedBox(
                        width: 200,
                        height: 40,
                        child: ListTile(
                          title: const Text("Videos Only",
                              style: TextStyle(
                                  color: Appcolors.appTextColor, fontSize: 11)),
                          leading: Radio(
                              activeColor: Appcolors.appPrimaryColor,
                              value: 1,
                              groupValue: currentOption,
                              onChanged: (value) {
                                setState(() {
                                  currentOption = value!;
                                });
                              }),
                        )),
                    SizedBox(
                        width: 200,
                        height: 40,
                        child: ListTile(
                          title: const Text("Images Only",
                              style: TextStyle(
                                  color: Appcolors.appTextColor, fontSize: 11)),
                          leading: Radio(
                              activeColor: Appcolors.appPrimaryColor,
                              value: 2,
                              groupValue: currentOption,
                              onChanged: (value) {
                                setState(() {
                                  currentOption = value!;
                                });
                              }),
                        )),
                    SizedBox(
                        width: 200,
                        height: 40,
                        child: ListTile(
                          title: const Text("Miscellaneous (Zip,Rar,etc..)",
                              style: TextStyle(
                                  color: Appcolors.appTextColor, fontSize: 11)),
                          leading: Radio(
                              activeColor: Appcolors.appPrimaryColor,
                              value: 3,
                              groupValue: currentOption,
                              onChanged: (value) {
                                setState(() {
                                  currentOption = value!;
                                });
                              }),
                        )),
                  ],
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Divider(
                    color: Appcolors.appNaigationColor,
                  ),
                ),
                if (url != null && directory != null) ...[
                  Expanded(
                      child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                          onPressed: () async {
                            //new Download logic
                            widget.addDownload
                                .add({"url": url, "path": directory});
                            Navigator.pop(context);
                          },
                          icon: Icon(Icons.download_rounded),
                          label: Text("Download"))
                    ],
                  ))
                ]
              ])),
        ],
      ),
    );
  }
}

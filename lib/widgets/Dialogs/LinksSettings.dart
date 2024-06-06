import 'dart:convert';
import 'dart:typed_data';

import 'package:coom_dl/constant/appcolors.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:json_editor_flutter/json_editor_flutter.dart';
import 'package:uuid/uuid.dart';

class LinksSettings {
  static void showLinkModal(
      BuildContext context, Function callback, Box LinksBox) async {
    Map changedMap = {};
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            padding: const EdgeInsets.all(20),
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            color: Appcolors.appBackgroundColor,
            child: Column(
              children: [
                Flexible(
                    child: Container(
                        color: Appcolors.appBackgroundColor,
                        height: 300,
                        child: JsonEditor(
                          enableKeyEdit: false,
                          enableMoreOptions: false,
                          themeColor: Appcolors.appAccentColor,
                          editors: const [Editors.tree],
                          onChanged: (value) {
                            changedMap = value;
                          },
                          json: json.encode(LinksBox.toMap()),
                        ))),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 20, horizontal: 50),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton(
                          onPressed: () async {
                            await LinksBox.putAll(changedMap);
                            Navigator.of(context).pop();
                            callback();
                          },
                          child: const Text("Save & Close")),
                      const SizedBox(
                        width: 10,
                      ),
                      Column(
                        children: [
                          SizedBox(
                            width: 90,
                            height: 25,
                            child: TextButton.icon(
                                onPressed: () async {
                                  const XTypeGroup typeGroup = XTypeGroup(
                                    label: 'CDL File',
                                    extensions: <String>['cdl'],
                                  );
                                  final XFile? file = await openFile(
                                      acceptedTypeGroups: <XTypeGroup>[
                                        typeGroup
                                      ]);
                                  if (file == null) {
                                    return;
                                  }
                                  String res = await file!
                                      .readAsString()
                                      .onError((error, stackTrace) => "");
                                  changedMap = jsonDecode(res);
                                  await LinksBox.putAll(changedMap);
                                  Navigator.of(context).pop();
                                  callback();
                                },
                                icon: const Icon(
                                  Icons.file_upload,
                                  size: 14,
                                ),
                                label: const Text(
                                  "Load",
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400),
                                )),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 90,
                            height: 25,
                            child: TextButton.icon(
                                onPressed: () async {
                                  const XTypeGroup typeGroup = XTypeGroup(
                                    label: 'CDL file',
                                    extensions: <String>['cdl'],
                                  );
                                  String fileName =
                                      'COOMDL_SAVE-${const Uuid().v1().toString()}.cdl';
                                  final FileSaveLocation? result =
                                      await getSaveLocation(
                                          suggestedName: fileName,
                                          acceptedTypeGroups: [typeGroup]);
                                  if (result == null) {
                                    // Operation was canceled by the user.
                                    return;
                                  }

                                  final Uint8List fileData = Uint8List.fromList(
                                      changedMap.isEmpty
                                          ? jsonEncode(LinksBox.toMap())
                                              .codeUnits
                                          : jsonEncode(changedMap).codeUnits);

                                  final XFile textFile =
                                      XFile.fromData(fileData, name: fileName);
                                  await textFile.saveTo("${result.path}.cdl");
                                },
                                icon: const Icon(
                                  Icons.offline_share,
                                  size: 14,
                                ),
                                label: const Text(
                                  "Export",
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400),
                                )),
                          )
                        ],
                      )
                    ],
                  ),
                )

                // Add more widgets as needed
              ],
            ),
          ),
        );
      },
    );
  }
}

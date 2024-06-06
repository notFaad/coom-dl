import 'package:coom_dl/constant/appcolors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

class EngineSettings {
  static void ShowEngineModal(
      BuildContext context, Function callback, Box settingsBox) async {
    Map<dynamic, dynamic> settings = settingsBox.toMap();
    String jobs_holder = settings['job'].toString();
    String retry_holder = settings['retry'].toString();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width / 2,
            color: Appcolors.appBackgroundColor,
            padding: const EdgeInsets.all(5),
            child: Column(
              children: [
                const Text(
                  'Coom-dl Settings',
                  style: TextStyle(
                      color: Appcolors.appTextColor,
                      fontWeight: FontWeight.bold),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 5),
                  child: Divider(),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  child: Wrap(
                    children: [
                      const Text(
                        "[IGNORE] Developer Mode",
                        style: TextStyle(
                            color: Appcolors.appTextColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      SizedBox(
                        width: 90,
                        height: 22,
                        child: FilledButton(
                            onPressed: () async {
                              await settingsBox.put(
                                  "debug", !settings['debug']);

                              Navigator.of(context).pop();
                              callback();
                            },
                            child: Text(
                              "${() {
                                if (settings['debug']) {
                                  return "Turn off";
                                } else {
                                  return "Turn on";
                                }
                              }()}",
                              style: const TextStyle(fontSize: 11),
                            )),
                      )
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 5),
                  child: Divider(),
                ),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                            color: Appcolors.appTextColor.withAlpha(20),
                            width: 150,
                            height: 30,
                            child: const Center(
                              child: Text(
                                "Number of jobs(1-9)",
                                style: TextStyle(
                                    color: Appcolors.appTextColor,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12),
                              ),
                            )),
                        const SizedBox(
                          width: 5,
                        ),
                        Flexible(
                            child: TextField(
                          onChanged: (value) async {
                            if (value.isNotEmpty) {
                              jobs_holder = value;
                            } else {
                              jobs_holder = settings['job'].toString();
                            }
                          },
                          style: const TextStyle(
                              color: Appcolors.appTextColor,
                              fontWeight: FontWeight.w500,
                              fontSize: 12),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r"^([1-9]){1}$"))
                          ],
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.all(2),
                              prefix: const Text('>>'),
                              hintText: "${settings['job']}",
                              hintStyle: const TextStyle(
                                  color: Appcolors.appTextColor, fontSize: 12)),
                        ))
                      ],
                    ),
                  ),
                ),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                            color: Appcolors.appTextColor.withAlpha(20),
                            width: 150,
                            height: 30,
                            child: const Center(
                              child: Text(
                                "Download fail retries(1-9)",
                                style: TextStyle(
                                    color: Appcolors.appTextColor,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 11),
                              ),
                            )),
                        const SizedBox(
                          width: 5,
                        ),
                        Flexible(
                            child: TextField(
                          onChanged: (value) {
                            if (value.isNotEmpty) {
                              retry_holder = value;
                            } else {
                              retry_holder = settings['retry'].toString();
                            }
                          },
                          style: const TextStyle(
                              color: Appcolors.appTextColor,
                              fontWeight: FontWeight.w500,
                              fontSize: 12),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r"^([1-9]){1}$"))
                          ],
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.all(2),
                              prefix: const Text('>>'),
                              hintText: "${settings['retry']}",
                              hintStyle: const TextStyle(
                                  color: Appcolors.appTextColor, fontSize: 12)),
                        ))
                      ],
                    ),
                  ),
                ),

                const Text(
                  textAlign: TextAlign.center,
                  "Note: Recommended(jobs/retires):\n- [5/6] (<1% fail)\n- [n>6/n<=3] (60-99% fail,not recommended)\n 'The higher the job the more it consumes RAM and fails'",
                  style: TextStyle(
                      color: Appcolors.appTextColor,
                      fontSize: 12,
                      fontStyle: FontStyle.italic),
                ),
                const Spacer(),
                Flexible(
                    child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  child: FilledButton(
                      onPressed: () async {
                        await settingsBox.put("job", int.parse(jobs_holder));
                        await settingsBox.put("retry", int.parse(retry_holder));
                        await settingsBox.put("eng", settings['eng']);
                        Navigator.of(context).pop();
                        callback();
                      },
                      child: const Text("Save and close")),
                ))
                // Add more widgets as needed
              ],
            ),
          ),
        );
      },
    );
  }
}

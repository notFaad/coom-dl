import 'package:coom_dl/constant/appcolors.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class HistoryDialog {
  void showHistoryModal(BuildContext context, Box historyBox) {
    var history = historyBox.toMap();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width / 2,
            color: Appcolors.appBackgroundColor,
            padding: EdgeInsets.all(5),
            child: Column(
              children: [
                Text(
                  'Download History',
                  style: TextStyle(
                      color: Colors.grey.shade300, fontWeight: FontWeight.bold),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 5),
                  child: Divider(),
                ),
                //scrollable widget
                if (history.isNotEmpty) ...[
                  Flexible(
                      child: SingleChildScrollView(
                          reverse: true,
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: history.length,
                            itemBuilder: (context, index) {
                              return Container(
                                color: Appcolors.appSecondaryColor,
                                padding: EdgeInsets.all(5),
                                margin: EdgeInsets.symmetric(
                                    horizontal: 30, vertical: 5),
                                child: Column(
                                  children: [
                                    Text(
                                        "Creator: ${history[index]['creator']}${() {
                                          if (index == history.length - 1) {
                                            return " (Lastest)";
                                          } else {
                                            return "";
                                          }
                                        }()}",
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Appcolors.appPrimaryColor)),
                                    Text(
                                        "Started At: ${history[index]['start']}",
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange.shade700)),
                                    Text("Ended At: ${history[index]['end']}",
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange.shade700)),
                                    Text(
                                        "Download Size: ${history[index]['size']}",
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade500))
                                  ],
                                ),
                              );
                            },
                          )))
                ] else ...[
                  Center(
                    child: Text(
                      "No Download History Found.",
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Appcolors.appPrimaryColor),
                    ),
                  )
                ]
                // Add more widgets as needed
              ],
            ),
          ),
        );
      },
    );
  }
}

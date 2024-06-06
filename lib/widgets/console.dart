import 'package:coom_dl/constant/appcolors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class Console extends StatefulWidget {
  List<Map<dynamic, dynamic>> logg;
  ScrollController scrollController;
  Function({required int bytes, int decimals}) getFileSizeString;
  Map<dynamic, dynamic> settingMap;
  Console(
      {Key? key,
      required this.logg,
      required this.scrollController,
      required this.getFileSizeString,
      required this.settingMap})
      : super(key: key);

  @override
  _ConsoleState createState() => _ConsoleState();
}

class _ConsoleState extends State<Console> {
  @override
  Widget build(BuildContext context) {
    var logg = widget.logg;
    var scrollController = widget.scrollController;
    var getFileSizeString = widget.getFileSizeString;
    var settingMap = widget.settingMap;
    return Flexible(
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: 200,
        color: Appcolors.appAccentColor.withOpacity(0.05),
        margin: const EdgeInsets.symmetric(horizontal: 30),
        child: ListView.builder(
            controller: scrollController,
            shrinkWrap: true,
            itemCount: logg.length,
            itemBuilder: (context, index) {
              TextStyle style1;
              if (logg[index]['status'] == "ok") {
                style1 = const TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold);
              } else if (logg[index]['status'] == "error" ||
                  logg[index]['status'] == "scrap") {
                style1 = const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold);
              } else if (logg[index]['status'] == "skip") {
                style1 = TextStyle(
                  color: Colors.cyan.shade600,
                  fontSize: 10,
                );
              } else if (logg[index]['status'] == "retry") {
                style1 = const TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold);
              } else if (logg[index]['status'] == "fail") {
                style1 = TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.bold);
              } else {
                style1 = TextStyle(
                  color: Colors.pink.shade300,
                  fontSize: 10,
                );
              }
              return Container(
                      margin: const EdgeInsets.symmetric(vertical: 1),
                      color: Appcolors.appAccentColor.withOpacity(0.25),
                      child: Text(
                        overflow: TextOverflow.ellipsis,
                        "- Result: ${logg[index]['status']}${() {
                          if (logg[index]['status'] == "ok") {
                            return " | -S: 💯✅ ${getFileSizeString(bytes: logg[index]['size'] as int)} | Failed Attempts: ${logg[index]['attempt']}";
                          } else if (logg[index]['status'] == "skip") {
                            return " | -M: 📂 File is already downloaded in Directory";
                          } else if (logg[index]['status'] == "error") {
                            return " | -R: 🔁 Timeout to Host Retrying[${logg[index]['retry']}/${settingMap['retry']}] ";
                          } else if (logg[index]['status'] == "retry") {
                            return " | -M: 🩺 File is Corrupted | ${getFileSizeString(bytes: logg[index]['size'])} of ${getFileSizeString(bytes: logg[index]['finalsize'])}";
                          } else if (logg[index]['status'] == 'fail') {
                            return "| ❌ ${logg[index]['status']} ${() {
                              if (logg[index]['m'] != null) {
                                return " | ${logg[index]['m']}";
                              } else {
                                return "";
                              }
                            }()}";
                          } else if (logg[index]['status'] == 'scrap') {
                            return "| ${logg[index]['m']}";
                          } else {
                            return " | ⌚ -M: ${logg[index]['m'] ?? "no message"} |";
                          }
                        }()} | ${logg[index]['title'] ?? ""}",
                        style: style1,
                      ))
                  .animate()
                  .fadeIn(duration: const Duration(milliseconds: 250));
            }),
      ).animate().fadeIn(duration: const Duration(milliseconds: 400)),
    );
  }
}

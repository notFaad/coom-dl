import 'package:flutter/material.dart';

class DownloadStatus extends StatelessWidget {
  int threads;
  int downloaded;
  int total;
  Map settingMap;
  String Size;
  int done_count;
  int fail_count;
  int skip_count;

  int failed_links_count;
  DownloadStatus(
      {Key? key,
      required this.Size,
      required this.done_count,
      required this.downloaded,
      required this.fail_count,
      required this.failed_links_count,
      required this.settingMap,
      required this.skip_count,
      required this.threads,
      required this.total})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text.rich(TextSpan(
        text:
            "- Fetched: [$downloaded/$total] | Jobs: [$threads/${settingMap['job']}] ",
        style: TextStyle(
            color: Colors.grey.shade300,
            fontSize: 12,
            fontWeight: FontWeight.bold),
        children: [
          TextSpan(
              text: " | ${Size} ",
              style: TextStyle(
                  color: Colors.cyan.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          TextSpan(
              text: "| DL: ${done_count} ",
              style: TextStyle(
                  color: Colors.green.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          TextSpan(
              text: "| Fail: ${fail_count} ",
              style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          TextSpan(
              text: "| S: ${skip_count} ",
              style: TextStyle(
                  color: Colors.orange.shade500,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          TextSpan(
              text: "| Crawl Fail: ${failed_links_count} ",
              style: TextStyle(
                  color: Colors.purple.shade400,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          TextSpan(
              text: " | ${((downloaded / total) * 100).toStringAsFixed(1)} %",
              style: TextStyle(color: Color(0xFFFF785A), fontSize: 12))
        ]));
  }
}

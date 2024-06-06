import 'dart:convert';
import 'dart:io';
import 'package:coom_dl/data/models/download.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class NeoCoomer {
  static var APIURL = "https://coomer.su/api/v1";

  static Future<Map<String, dynamic>> init({required url}) async {
    Uri parsed_url = Uri.parse(url);
    List<DownloadItem> download_file = [];
    if (RegExp(r'^((https:\/\/)|(https:\/\/www\.))?coomer\.(party|su){1}\/(onlyfans|fansly|candfans){1}\/user{1}\/.+$')
            .hasMatch(url) ||
        RegExp(r'^((https:\/\/)|(https:\/\/www\.))?kemono\.(party|su){1}\/.+$')
            .hasMatch(url)) {
      if (RegExp(
              r'^((https:\/\/)|(https:\/\/www\.))?kemono\.(party|su){1}\/.+$')
          .hasMatch(url)) {
        APIURL = "https://kemono.su/api/v1";
      }
      if (!RegExp(r'(post)\/\d+$').hasMatch(url)) {
        print(parsed_url.query);
        print("$APIURL${parsed_url.path}");

        var res = await http.get(Uri.parse("$APIURL${parsed_url.path}${() {
          if (parsed_url.query.isEmpty) {
            return "?o=0";
          } else {
            return "?${parsed_url.query}";
          }
        }()}"));
        List content = jsonDecode(res.body);
        print(content.length);
        int nextquery = parsed_url.query.isEmpty
            ? 50
            : int.parse(parsed_url.queryParameters['o']!) + 50;

        List temp;
        while (true) {
          await Future.delayed(const Duration(milliseconds: 600));

          var res = await http
              .get(Uri.parse("$APIURL${parsed_url.path}?o=$nextquery"));
          temp = jsonDecode(res.body);
          if (temp.isEmpty) {
            break;
          } else {
            content.addAll(temp);
            nextquery += 50;
          }
        }

        for (var element in content) {
          List tempAttachments = element['attachments'];
          Map temFile = element['file'];
          if (temFile.isNotEmpty) {
            download_file.add(DownloadItem(
                downloadName: element['file']['name'],
                link: "https://c1.coomer.su/data${element['file']['path']}"));
          }
          if (tempAttachments.isNotEmpty) {
            for (var e in tempAttachments) {
              download_file.add(DownloadItem(
                  downloadName: e['name'],
                  link: "https://c1.coomer.su/data${e['path']}"));
            }
          }
        }

        return {
          "creator": content.first['user'] ?? const Uuid().v1(),
          "downloads": download_file,
          "count": download_file.length,
          "folder":
              content.first['user'].replaceAll(r'[\\\/:"*?<>|]+', "_").trim() ??
                  const Uuid().v1()
        };
      } else {
        print("POST");
        var res = await http.get(Uri.parse("$APIURL${parsed_url.path}"));
        print(res.statusCode);
        print(Uri.parse("$APIURL${parsed_url.path}").path);
        if (res.statusCode == 200) {
          Map content = jsonDecode(res.body);
          print(content.length);
          if (content.isNotEmpty) {
            Map files = content['file'];
            List attachments = content['attachments'];
            if (files.isNotEmpty) {
              download_file.add(DownloadItem(
                  downloadName: files['name'],
                  link: "https://c1.coomer.su/data${files['path']}"));
            }
            if (attachments.isNotEmpty) {
              for (var e in attachments) {
                download_file.add(DownloadItem(
                    downloadName: e['name'],
                    link: "https://c1.coomer.su/data${e['path']}"));
              }
            }

            return {
              "creator": content['user'] ?? const Uuid().v1(),
              "downloads": download_file,
              "count": download_file.length,
              "folder":
                  ("(Post ${content['published'].toString().split('T').first}) ${content['user']}")
                          .replaceAll(r'[\\\/:"*?<>|]+', "_")
                          .trim() ??
                      const Uuid().v1()
            };
          } else {
            return Future.error("Content is Empty");
          }
        } else {
          return Future.error("Error ${res.statusCode} HTTP");
        }
      }
    } else {
      return Future.error("Unsupported Coomer/Kemono Link");
    }
  }
}

/* 
return {
      "creator": creator_html?.innerHtml,
      "downloads": downloaditems,
      "count": downloaditems.length,
      "Folder name": folder
    };
*/
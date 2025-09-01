import 'dart:convert';
import 'package:coom_dl/data/models/download.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class NeoCoomer {
  static var APIURL = "https://coomer.st/api/v1";
  static var DATAURL = "https://coomer.st/data";

  static Future<Map<String, dynamic>> init({required url}) async {
    Uri parsed_url = Uri.parse(url);
    List<DownloadItem> download_file = [];
    if (RegExp(r'^((https:\/\/)|(https:\/\/www\.))?coomer\.(party|su|st){1}\/(onlyfans|fansly|candfans){1}\/user{1}\/.+$')
            .hasMatch(url) ||
        RegExp(r'^((https:\/\/)|(https:\/\/www\.))?kemono\.(party|su|cr){1}\/.+$')
            .hasMatch(url)) {
      if (RegExp(
              r'^((https:\/\/)|(https:\/\/www\.))?kemono\.(party|su|cr){1}\/.+$')
          .hasMatch(url)) {
        APIURL = "https://kemono.cr/api/v1";
        DATAURL = "https://kemono.cr/data";
      }
      if (!RegExp(r'(post)\/\d+$').hasMatch(url)) {
        print(parsed_url.query);
        print("$APIURL${parsed_url.path}");

        var res = await http.get(
            Uri.parse("$APIURL${parsed_url.path}/posts${() {
              if (parsed_url.query.isEmpty) {
                return "";
              } else {
                return "?${parsed_url.query}";
              }
            }()}"),
            headers: {'Accept': 'text/css'});

        print("Response status: ${res.statusCode}");
        print("Response body length: ${res.body.length}");

        var responseData = jsonDecode(res.body);

        // Check if the response is an error object
        if (responseData is Map && responseData.containsKey('error')) {
          return Future.error("API Error: ${responseData['error']}");
        }

        // Ensure we have a List response
        if (responseData is! List) {
          return Future.error(
              "Unexpected API response format: expected List, got ${responseData.runtimeType}");
        }

        List content = responseData;
        print(content.length);
        int nextquery = parsed_url.query.isEmpty
            ? 50
            : int.parse(parsed_url.queryParameters['o']!) + 50;

        List temp;
        while (true) {
          await Future.delayed(const Duration(milliseconds: 600));

          var res = await http.get(
              Uri.parse("$APIURL${parsed_url.path}/posts?o=$nextquery"),
              headers: {'Accept': 'text/css'});

          var responseData = jsonDecode(res.body);

          // Check if the response is an error object
          if (responseData is Map && responseData.containsKey('error')) {
            print("API Error in pagination: ${responseData['error']}");
            break;
          }

          // Ensure we have a List response
          if (responseData is! List) {
            print(
                "Unexpected pagination response format: expected List, got ${responseData.runtimeType}");
            break;
          }

          temp = responseData;
          if (temp.isEmpty) {
            break;
          } else {
            content.addAll(temp);
            nextquery += 50;
          }
        }

        for (var element in content) {
          // Safely handle attachments
          List? tempAttachments = element['attachments'] as List?;
          Map? temFile = element['file'] as Map?;

          // Add main file if it exists
          if (temFile != null && temFile.isNotEmpty) {
            String? fileName = temFile['name'];
            String? filePath = temFile['path'];
            if (fileName != null && filePath != null) {
              download_file.add(DownloadItem(
                  downloadName: fileName, link: "$DATAURL$filePath"));
            }
          }

          // Add attachments if they exist
          if (tempAttachments != null && tempAttachments.isNotEmpty) {
            for (var e in tempAttachments) {
              if (e is Map) {
                String? attachmentName = e['name'];
                String? attachmentPath = e['path'];
                if (attachmentName != null && attachmentPath != null) {
                  download_file.add(DownloadItem(
                      downloadName: attachmentName,
                      link: "$DATAURL$attachmentPath"));
                }
              }
            }
          }
        }

        return {
          "creator": content.first['user'] ?? const Uuid().v1(),
          "downloads": download_file,
          "count": download_file.length,
          "folder": (content.first['user']
                  ?.replaceAll(r'[\\\/:"*?<>|]+', "_")
                  .trim()) ??
              const Uuid().v1()
        };
      } else {
        print("SINGLE POST");
        // Single post URL transformation
        // From: /onlyfans/user/username/post/123456
        // To:   /api/v1/onlyfans/user/username/post/123456
        String singlePostPath = parsed_url.path;
        print("Requesting: $APIURL$singlePostPath");
        var res = await http.get(Uri.parse("$APIURL$singlePostPath"),
            headers: {'Accept': 'text/css'});
        print("Response status: ${res.statusCode}");
        print("Full URL: ${Uri.parse("$APIURL$singlePostPath")}");
        if (res.statusCode == 200) {
          Map content = jsonDecode(res.body);
          print(content.length);
          if (content.isNotEmpty) {
            // For single posts, the data is nested under 'post'
            Map? postData = content['post'];
            if (postData == null) {
              return Future.error("No post data found");
            }

            Map? files = postData['file'];
            List? attachments =
                postData['attachments']; // Attachments are nested under 'post'

            if (files != null && files.isNotEmpty) {
              download_file.add(DownloadItem(
                  downloadName: files['name'],
                  link: "$DATAURL${files['path']}"));
            }
            if (attachments != null && attachments.isNotEmpty) {
              for (var e in attachments) {
                download_file.add(DownloadItem(
                    downloadName: e['name'], link: "$DATAURL${e['path']}"));
              }
            }

            String username = postData['user'] ?? const Uuid().v1();
            String publishedDate =
                postData['published']?.toString().split('T').first ?? 'unknown';

            return {
              "creator": username,
              "downloads": download_file,
              "count": download_file.length,
              "folder": ("(Post $publishedDate) $username")
                  .replaceAll(r'[\\\/:"*?<>|]+', "_")
                  .trim()
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

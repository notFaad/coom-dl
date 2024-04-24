import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:html/dom.dart' as dom;
import 'package:puppeteer/puppeteer.dart';

import '../data/models/download.dart';

class FapelloCrawler {
  Future<Map<String, dynamic>> init(
      {required url, required links_config}) async {
    try {
      Map<String, dynamic> siteContents = await _getSiteContent(url: url);
      return siteContents;
    } catch (e) {
      return Future.error("Error Fetching site content");
    }
  }

  Future<Map<String, dynamic>> _getSiteContent({required url}) async {
    dom.Document html;
    http.Response response;
    List<DownloadItem> links = [];
    int pagescount = 0;
    var browser = await puppeteer.launch();

    // Open a new tab
    var myPage = await browser.newPage();

    // Go to a page and wait to be fully loaded

    try {
      response = await http.get(Uri.parse(url));
    } catch (e) {
      print(e.toString());
      return Future.error("Connection Timeout to Site [User Connection error]");
    }

    html = dom.Document.html(response.body);
    dom.Element? creator_html = null;
    dom.Element? nextPage = null;
    List<dom.Element> contents_a = [];
    List<dom.Element> contents_images = [];
    List<dom.Element> contents_vids = [];
    List<dom.Element> holder = [];
    Map end_map = {};
    String folder = "Error";
    if (RegExp(r'^((https:\/\/)|(https:\/\/www\.))?fapello\.(com|su){1}\/.+$')
        .hasMatch(url)) {
      creator_html = html.querySelector('div > h2');
      nextPage = html.querySelector('div.next_page > a');
      contents_a = html.querySelectorAll("#content > div > a:not([rel])");
      var iframe =
          html.querySelectorAll("#content > div > a[rel] > div > iframe");

      contents_a.addAll(iframe);
      pagescount = int.parse(
          (html.querySelector("div.showmore")?.attributes['data-max']) ?? "0");
      folder =
          " ${creator_html?.innerHtml.replaceAll(r'[\\\/:"*?<>|]+', "_").trim()} (Fapello Model)";
      if (url.toString()[url.toString().length - 1] == "/") {
        url = url.toString().substring(0, url.toString().length - 1);
      }
      for (int i = 2; i < pagescount; i++) {
        try {
          print("$url/page-$i/");
          response = await http.get(Uri.parse("$url/page-$i/"));
          html = dom.Document.html(response.body);
          contents_a
              .addAll(html.querySelectorAll("#content > div > a:not([rel])"));

          var iframe =
              html.querySelectorAll("#content > div > a[rel] > div > iframe");
          contents_a.addAll(iframe);

          for (int i = 0; i < contents_a.length; i++) {
            print("$i-VIDEOS = ${contents_a[i].attributes['src']}");
            print("$i-IMAGES = ${contents_a[i].attributes['href']}");
          }
        } catch (e) {
          return Future.error("Error getting next page");
        }
      }
    } else {
      return Future.error("Link is not Fapello");
    }

    if (contents_a.isEmpty) {
      return Future.error("Error Fetching Content LIST EMPTY");
    }

    if (contents_images.isEmpty && contents_vids.isEmpty) {
      //Creator -> getAlbum
      try {
        for (int i = 0; i < contents_a.length; i++) {
          if (contents_a[i].attributes['href'] != null) {
            response = await http
                .get(Uri.parse("${contents_a[i].attributes['href']}"));

            html = dom.Document.html(response.body);
            contents_images.addAll(
                html.querySelectorAll('div > a.uk-align-center > img[alt]'));
            holder.addAll(html.querySelectorAll(
                'div > a.uk-align-center > img[alt]')); //images
            contents_vids.addAll(html.querySelectorAll('div > video > source'));
            holder.addAll(html.querySelectorAll('div > video > source'));
          } else if (/*contents_a[i].attributes['src'] != null */ false) {
            try {
              await myPage.goto('${contents_a[i].attributes['src']}',
                  wait: Until.networkIdle);
              html = dom.Document.html(await myPage.content ??
                  ""); //plyr__controls__item plyr__control
              response = await http.get(Uri.parse(html
                  .querySelector(
                      'a[class="plyr__controls__item plyr__control"]')!
                  .attributes['href']!));
              html = dom.Document.html(response.body);
              var res_head = await http.head(Uri.parse(
                  html.querySelector('div > a')!.attributes['href']!));

              var file_name = res_head.headers['content-disposition']!
                  .split(';')
                  .where((n) => n.contains('filename='))
                  .first
                  .replaceAll('filename=', '')
                  .replaceAll('"', "")
                  .trim();
              print(file_name);
              end_map.addEntries({
                i: {
                  "url": html.querySelector('div > a')!.attributes['href'],
                  "name": file_name
                }
              }.entries);
            } catch (e) {
              print("Fapello IFRAME ERROR: $e");
            }
          } else {
            continue;
          }
        }
      } catch (e) {
        print("Crawling Fapello Error: $e");
      }
      contents_a.clear();
      contents_a.addAll(holder);
      holder.clear();
    }

    contents_a.forEach((element) {
      if (element.attributes['src'] != null) {
        //contents_images[j].attributes['data-src'].toString().split("/").last.split("?").first
        links.add(DownloadItem(
            downloadName: element.attributes['src']
                .toString()
                .split("/")
                .last
                .split("?")
                .first,
            link: element.attributes['src']!));
      } else if (element.attributes['href'] != null) {
        links.add(DownloadItem(
            downloadName: element.attributes['href']
                .toString()
                .split("/")
                .last
                .split("?")
                .first,
            link: element.attributes['href']!));
      }
    });
    end_map.forEach((key, value) {
      print(value);
      links.add(DownloadItem(
          downloadName: end_map[key]['name'], link: end_map[key]['url']));
    });

    await browser.close();
//CRAWL REPORT BACK TO COOMCRWL ENGINE
    return {
      "creator": creator_html?.innerHtml,
      "img": contents_images,
      "vid": contents_vids,
      "misc": [],
      "downloads": links,
      "count": links.length,
      "folder": folder
    };
  }
}

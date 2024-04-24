import 'package:http/http.dart' as http;
import 'package:html/dom.dart' as dom;

import '../data/models/download.dart';

class EromeCrawler {
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
    try {
      response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        return Future.error("Unable to reach site");
      }
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
    String folder = "Error";
    if (RegExp(r'^((https:\/\/)|(https:\/\/www\.))?erome\.com\/\w+$')
        .hasMatch(url)) {
      creator_html = html.querySelector('h1.username');
      nextPage = html.querySelector('a[rel="next"]');
      contents_a = html.querySelectorAll("a.album-link");
      folder =
          " ${creator_html?.innerHtml.replaceAll(r'[\\\/:"*?<>|]+', "_")} (Erome Creator)";
    } else if (RegExp(
            r'^((https:\/\/)|(https:\/\/www\.))?erome\.com\/a{1}\/\w+$')
        .hasMatch(url)) {
      creator_html =
          html.querySelector('div[class="col-sm-12 page-content"] > h1');
      contents_a = html.querySelectorAll('img[class="img-front lasyload"]');
      contents_images =
          html.querySelectorAll('img[class="img-front lasyload"]');
      contents_vids = html.querySelectorAll(
          'div[class="media-group"] > div[class="video-lg"] > video > source');
      contents_a.addAll(html.querySelectorAll(
          'div[class="media-group"] > div[class="video-lg"] > video > source'));
      folder =
          " ${creator_html?.innerHtml.replaceAll(r'[\\\/:"*?<>|]+', "_")} (Erome Album)";
    } else {
      return Future.error("Link is not Erome");
    }
    while (nextPage != null) {
      try {
        response = await http
            .get(Uri.parse("https://erome.com${nextPage.attributes['href']}"));
        if (response.statusCode != 200) {
          return Future.error("Unable to reach site");
        }
        html = dom.Document.html(response.body);
        nextPage = html.querySelector('a[rel="next"]');
        contents_a.addAll(html.querySelectorAll("a.album-link"));
      } catch (e) {
        continue;
      }
    }
    if (contents_a.isEmpty) {
      return Future.error("Error Fetching Content");
    }

    if (contents_images.isEmpty && contents_vids.isEmpty) {
      //Creator -> getAlbum
      for (int i = 0; i < contents_a.length; i++) {
        response =
            await http.get(Uri.parse("${contents_a[i].attributes['href']}"));
        html = dom.Document.html(response.body);
        contents_images
            .addAll(html.querySelectorAll('img[class="img-front lasyload"]'));
        holder.addAll(
            html.querySelectorAll('img[class="img-front lasyload"]')); //images
        contents_vids.addAll(html.querySelectorAll(
            'div[class="media-group"] > div[class="video-lg"] > video > source'));
        holder.addAll(html.querySelectorAll(
            'div[class="media-group"] > div[class="video-lg"] > video > source'));
      }
      contents_a.clear();
      contents_a.addAll(holder);
      holder.clear();
    }

    contents_a.forEach((element) {
      if (element.attributes['data-src'] != null) {
        //contents_images[j].attributes['data-src'].toString().split("/").last.split("?").first
        links.add(DownloadItem(
            downloadName: element.attributes['data-src']
                .toString()
                .split("/")
                .last
                .split("?")
                .first,
            link: element.attributes['data-src']!));
      } else if (element.attributes['src'] != null) {
        links.add(DownloadItem(
            downloadName: element.attributes['src']
                .toString()
                .split("/")
                .last
                .split("?")
                .first,
            link: element.attributes['src']!));
      }
    });

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

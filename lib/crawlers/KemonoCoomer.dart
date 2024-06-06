import 'package:coom_dl/data/models/download.dart';
import 'package:http/http.dart' as http;
import 'package:html/dom.dart' as dom;
import 'package:uuid/uuid.dart';

/*
OLD KEMONO COOMER CRAWLER
NOT BEING USED!
SEE "lib/neocrawler/coomer_crawler.dart" FOR THE NEW ONE

*/
class KemonoCoomerCrawler {
  Future<Map<String, dynamic>> init(
      {required url, required links_config, required scrape_logg}) async {
    try {
      Map<String, dynamic> siteContents = await _getSiteContent(
          url: url, linksconfig: links_config, scrape_logg: scrape_logg);
      return siteContents;
    } catch (e) {
      return Future.error("$e");
    }
  }

  Future<Map<String, dynamic>> _getSiteContent(
      {required url, required linksconfig, required scrape_logg}) async {
    dom.Document html;
    http.Response response;
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
    List<dom.Element> contents_misc = [];
    List<dom.Element> holder = [];
    List<DownloadItem> downloaditems = [];
    String? link = "";
    String folder = "Error";
    if (RegExp(
            r'^((https:\/\/)|(https:\/\/www\.))?coomer\.(party|su){1}\/(onlyfans|fansly){1}\/user{1}\/.+$')
        .hasMatch(url)) {
      //Coomer
      if (!RegExp(r'(post)\/\d+$').hasMatch(url)) {
        // Full Creator scrape
        creator_html = html.querySelector(linksconfig["coomer"]["creator"]);
        nextPage = html.querySelector(linksconfig["coomer"]["nextpage"]);
        contents_a = html.querySelectorAll(linksconfig["coomer"]["album"]);
        folder =
            " ${creator_html?.innerHtml.replaceAll(r'[\\\/:"*?<>|]+', "_")} (Coomer Creator)";
        link = "https://coomer.su";
      } else {
        //Post scrape
        creator_html =
            html.querySelector(linksconfig["coomer"]["creator-single"]);
        contents_a = html.querySelectorAll(linksconfig["coomer"]["image"]);
        contents_images = html.querySelectorAll(linksconfig["coomer"]["image"]);
        contents_vids = html.querySelectorAll(linksconfig["coomer"]["video"]);
        contents_a
            .addAll(html.querySelectorAll(linksconfig["coomer"]["video"]));
        var published = html.querySelector(linksconfig["coomer"]["date"]);
        print(published?.text.replaceAll(r':', "_").trim());
        folder =
            "[${published?.text.replaceAll(r':', "_").trim()}] ${creator_html?.innerHtml.replaceAll(r'[\\\/:"*?<>|]+', "_").trim()} (Coomer Post)";
      }
    } else if (RegExp(
            r'^((https:\/\/)|(https:\/\/www\.))?kemono\.(party|su){1}\/.+$')
        .hasMatch(url)) {
      //Kemono
      if (!RegExp(r'(post)\/\d+$').hasMatch(url)) {
        creator_html = html.querySelector(linksconfig["coomer"]["creator"]);
        nextPage = html.querySelector(linksconfig["coomer"]["nextpage"]);
        contents_a = html.querySelectorAll(linksconfig["coomer"]["album"]);
        folder =
            "${creator_html?.innerHtml.replaceAll(r'[\\\/:"*?<>|]+', "_")} (Kemono Creator)";
        link = "https://kemono.su";
      } else {
        creator_html =
            html.querySelector(linksconfig["coomer"]["creator-single"]);
        contents_a = html.querySelectorAll(linksconfig["coomer"]["image"]);
        contents_images = html.querySelectorAll(linksconfig["coomer"]["image"]);
        contents_vids = html.querySelectorAll(linksconfig["coomer"]["video"]);
        contents_a
            .addAll(html.querySelectorAll(linksconfig["coomer"]["video"]));
        //post__published
        folder =
            "[${const Uuid().v1().substring(0, 7)}] ${creator_html?.innerHtml.replaceAll(r'[\\\/:"*?<>|]+', "_").trim()} (Kemono Post)";
      }
    } else {
      return Future.error("Wrong Kemono/Coomer site format");
    }
    int retry = 0;
    while (nextPage != null) {
      await Future.delayed(const Duration(milliseconds: 400));
      try {
        response =
            await http.get(Uri.parse("$link${nextPage.attributes['href']}"));

        if (response.statusCode != 200) {
          // TODO Failed scrap log.
          retry++;
          scrape_logg({
            "status": "fail response",
            "m": "Failed response at $link${nextPage.attributes['href']}"
          });
          if (retry >= 2) {
            break;
          }
          continue;
        } else {
          scrape_logg({
            "status": "scrap",
            "m": "Visiting: $link${nextPage.attributes['href']}",
            "rr": retry
          });

          html = dom.Document.html(response.body);
          if (html.querySelector(linksconfig["coomer"]["nextpage"]) ==
              nextPage) {
            break;
          }
          nextPage = html.querySelector(linksconfig["coomer"]["nextpage"]);

          contents_a
              .addAll(html.querySelectorAll(linksconfig["coomer"]["album"]));
          if (nextPage == null) {
            break;
          }
        }
      } catch (e) {
        print(e);
        continue;
      }
    }
    if (contents_a.isEmpty) {
      return Future.error("Error Fetching Content");
    }

    if (contents_images.isEmpty && contents_vids.isEmpty) {
      //Creator -> getAlbum
      for (int i = 0; i < contents_a.length; i++) {
        await Future.delayed(const Duration(milliseconds: 400));
        response = await http.get(
            Uri.parse("$link${contents_a[i].children[0].attributes['href']}"));
        if (response.statusCode != 200) {
          scrape_logg({
            "status": "fail",
            "link": "$link${contents_a[i].children[0].attributes['href']}",
            "m":
                "Failed Crawl at $link${contents_a[i].children[0].attributes['href']}"
          });
        } else {
          scrape_logg({
            "status": "scrap",
            "m":
                "Crawling: $link${contents_a[i].children[0].attributes['href']}"
          });
        }
        html = dom.Document.html(response.body);
        contents_images
            .addAll(html.querySelectorAll(linksconfig["coomer"]["image"]));
        holder.addAll(
            html.querySelectorAll(linksconfig["coomer"]["image"])); //images
        contents_vids
            .addAll(html.querySelectorAll(linksconfig["coomer"]["video"]));
        holder.addAll(html.querySelectorAll(linksconfig["coomer"]["video"]));
      }
      contents_a.clear();
      contents_a.addAll(holder);
      holder.clear();
    }
    contents_a.forEach((element) {
      if (element.attributes['src'] != null) {
        downloaditems.add(DownloadItem(
            downloadName: element.attributes['download'],
            link: element.attributes['src']!));
      } else if (element.attributes['href'] != null) {
        downloaditems.add(DownloadItem(
            downloadName: element.attributes['download'],
            link: element.attributes['href']!));
      }
    });
    return {
      "creator": creator_html?.innerHtml,
      "img": contents_images,
      "vid": contents_vids,
      "misc": [],
      "downloads": downloaditems,
      "count": downloaditems.length,
      "folder": folder
    };
  }
}

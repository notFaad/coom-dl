class DownloadItem {
//Downloaded Content
  String? link;
  String? downloadName;
  String? mimeType;

  DownloadItem(
      {required this.downloadName, required this.link, this.mimeType}) {
    String ext = downloadName!.split(".").last;
    Map vids = {
      1: "3g2",
      2: "3gp",
      3: "asf",
      4: "avi",
      5: "flv",
      6: "mkv",
      7: "mov",
      8: "mp4",
      9: "mpeg",
      10: "mpg",
      11: "ogv",
      12: "rm",
      13: "swf",
      14: "vob",
      15: "webm",
      16: "wmv",
      17: "m4v",
      18: "ts",
      19: "m2ts",
      20: "divx",
      21: "xvid",
      22: "mts",
      23: "flv",
      24: "f4v",
      25: "h264",
      26: "h265",
      27: "mxf",
      28: "rmvb",
      29: "mov",
      30: "ogm",
      31: "mp3"
    };

    Map imgs = {
      1: "jpg",
      2: "jpeg",
      3: "png",
      4: "gif",
      5: "bmp",
      6: "tiff",
      7: "webp",
      8: "raw",
      9: "heif",
      10: "svg",
      11: "ico"
    };
    if (vids.containsValue(ext)) {
      this.mimeType = "Videos";
    } else if (imgs.containsValue(ext)) {
      this.mimeType = "Photos";
    } else {
      this.mimeType = "Misc";
    }
  }
}

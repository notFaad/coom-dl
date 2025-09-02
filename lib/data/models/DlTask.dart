// ignore_for_file: file_names

import 'package:coom_dl/data/models/Link.dart';
import 'package:isar/isar.dart';
part "DlTask.g.dart";

@collection
class DownloadTask {
  Id id = Isar.autoIncrement;

  late final String url;
  late final String storagePath;

  String? pathToThumbnail;

  String? name;

  String? tag; // Renders next to the name in the UI (Optional)

  //number of the total files fetched from crawler
  int? totalNum;

  int downloadedBytes = 0;
  final links = IsarLinks<Links>();
  //number of downloaded files
  int numFetched = 0;

  //number of OK downloaded files
  int numCompleted = 0;

  bool? isCanceled;
  bool? isQueue;
  bool? isPaused;
  //number of failed files
  int numFailed = 0;

  //number of retry attempts
  int numRetries = 0;

  //is the task completed?
  bool? isCompleted;

  bool? isDownloading;

  //did the task fail?
  bool? isFailed;
}

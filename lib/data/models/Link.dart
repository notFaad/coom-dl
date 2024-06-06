import 'package:isar/isar.dart';

part "Link.g.dart";

@collection
class Links {
  Id id = Isar.autoIncrement;
  /*
  [url] ex: https://coomer.su/onlyfans/creatorA/CNEX.mp4, 

  [filename] ex: CNEX.mp4 , 

  [Type] Either (Videos,Photos,Misc) 

  These Params must be generated from the Crawler.

  [isCompleted] did the link get downloaded?
  [isFailure] did the link failed?

  */
  String? url;
  String? filename;
  String? type;
  bool? isCompleted;
  bool? skipped;
  bool? isFailure;
}

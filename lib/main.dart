import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:coom_dl/constant/appcolors.dart';
import 'package:coom_dl/data/models/DlTask.dart';
import 'package:coom_dl/data/models/Link.dart';
import 'package:coom_dl/data/models/extention.dart';
import 'package:coom_dl/pages/addDownload.dart';
import 'package:coom_dl/pages/downloadsPage.dart';
import 'package:coom_dl/pages/settingsPage.dart';
import 'package:coom_dl/services/downloadTaskServices.dart';
import 'package:coom_dl/view-models/Recooma_engine.dart';
import 'package:coom_dl/downloader/external/cyberdrop_dl_engine.dart';
import 'package:coom_dl/downloader/external/gallery_dl_engine.dart';
import 'package:coom_dl/neocrawler/coomer_crawler.dart';
import 'package:coom_dl/utils/FileSizeConverter.dart';
import 'package:coom_dl/widgets/Dialogs/EngineSettings.dart';
import 'package:coom_dl/widgets/Dialogs/History_dialog.dart';
import 'package:coom_dl/widgets/Dialogs/LinksSettings.dart';
import 'package:coom_dl/widgets/console.dart';
import 'package:coom_dl/widgets/download_status.dart';
import 'package:coom_dl/widgets/navigationtab.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:html/dom.dart' as html;
import 'package:coom_dl/downloader/coomercrawl.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:isar/isar.dart';
import 'package:json_editor_flutter/json_editor_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:system_info2/system_info2.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Must add this line.
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    center: true,
    titleBarStyle: TitleBarStyle.normal,
  );
  double current_version = 0.75;
  bool hasNewVersion = false;
  double? newV = 0;

  await http
      .get(Uri.parse("https://api.github.com/repos/notfaad/coom-dl/tags"))
      .then((value) {
    List<dynamic> rel = jsonDecode(value.body);
    rel.forEach((element) {
      try {
        if (double.parse(element['name']) > current_version &&
            double.parse(element['name']) > newV!) {
          hasNewVersion = true;
          newV = double.parse(element['name']);
        }
      } catch (e) {}
    });
  }).onError((error, stackTrace) {
    hasNewVersion = false;
  });

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setSize(const Size(800, 500));
    if (Platform.isWindows) {
      await windowManager.setIcon("../assets/logo.png");
    }
    // await windowManager.setMaximumSize(const Size(800, 500));
    // await windowManager.setMinimumSize(const Size(800, 500));
    await windowManager.setTitle("CNEX 0.84 beta | by notFaad");
    //  await windowManager.setMaximizable(false);
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    await windowManager.setPreventClose(true);
    await windowManager.show();
    await windowManager.focus();
  });
  bool isExist = false;
  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
    [DownloadTaskSchema, LinksSchema, ExtentionSchema],
    directory: dir.path,
  );
  runApp(MyApp(
    out_of_date: hasNewVersion,
    version: newV,
    isar: isar,
  ));
}

class MyApp extends StatefulWidget {
  MyApp(
      {super.key,
      required this.out_of_date,
      required this.version,
      required this.isar});
  bool out_of_date;
  double? version;
  Isar isar;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WindowListener {
  int navigationSelectionIndex = 0;
  StreamController<Map<String, dynamic>> addDownloadListner =
      StreamController<Map<String, dynamic>>();
  StreamController<Map<String, dynamic>> downloadCompleteListner =
      StreamController<Map<String, dynamic>>();
  StreamController<Map<int, dynamic>> downloadLogListner =
      StreamController<Map<int, dynamic>>();
  List<DownloadTask> queue = [];
  Map<int, dynamic> logs = {};

  // This widget is the root of your application.
  @override
  void onWindowClose() async {
    // do something
    bool _isPreventClose = await windowManager.isPreventClose();
    if (_isPreventClose) {
      Get.dialog(AlertDialog(
        backgroundColor: Appcolors.appNaigationColor,
        title: const Text(
          'Are you sure you want to exit CNEX?',
          style: TextStyle(
              fontSize: 16,
              color: Appcolors.appAccentColor,
              fontWeight: FontWeight.w500),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            child: const Text('No'),
            onPressed: () {
              Get.back();
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.exit_to_app),
            label: const Text('Yes'),
            onPressed: () async {
              List<DownloadTask> downloading = await widget.isar.downloadTasks
                  .where()
                  .filter()
                  .isDownloadingEqualTo(true)
                  .findAll();
              List<DownloadTask> queuing = await widget.isar.downloadTasks
                  .where()
                  .filter()
                  .isQueueEqualTo(true)
                  .findAll();
              if (downloading.isNotEmpty) {
                for (int i = 0; i < downloading.length; i++) {
                  await widget.isar.writeTxn(() async {
                    await widget.isar.downloadTasks.delete(downloading[i].id);
                  });
                }
              }
              if (queuing.isNotEmpty) {
                for (int i = 0; i < queuing.length; i++) {
                  await widget.isar.writeTxn(() async {
                    await widget.isar.downloadTasks.delete(queuing[i].id);
                  });
                }
              }
              await windowManager.destroy();
            },
          ),
        ],
      ));
    }
  }

  @override
  void initState() {
    // automatic queue downloader
    windowManager.addListener(this);
    widget.isar.downloadTasks
        .filter()
        .isDownloadingEqualTo(true)
        .watch(fireImmediately: true)
        .listen((event) async {
      List<DownloadTask> queue = await widget.isar.downloadTasks
          .where()
          .filter()
          .isQueueEqualTo(true)
          .findAll();

      if (event.isEmpty && queue.isNotEmpty) {
        var downloadtask = queue.first;
        var temp = await widget.isar.downloadTasks
            .where()
            .idEqualTo(downloadtask.id)
            .findFirst();
        temp!.isQueue = false;
        temp.isDownloading = true;
        await widget.isar.writeTxn(() async {
          await widget.isar.downloadTasks.put(temp);
        });

        new DownloadTaskServices(task: temp)
            .startDownload(widget.isar, downloadCompleteListner.sink,
                downloadLogListner.sink, 0)
            .then((value) {}, onError: (error, s) {
          print(error);
          print(s);
          Get.showSnackbar(GetSnackBar(
            borderRadius: 5,
            animationDuration: Durations.long3,
            backgroundColor: Colors.red[500]!,
            duration: Durations.extralong3,
            message: "Error Occured, $error",
            overlayBlur: 1.5,
            overlayColor: Appcolors.appLogoColor.withAlpha(30),
          ));
        });
      }
    });

    super.initState();
    downloadLogListner.stream.listen((event) {
      setState(() {
        logs = event;
      });
    });

    downloadCompleteListner.stream.listen((event) async {
      var length = 1;
      if (length == 0 && queue.isNotEmpty) {}
    });
    addDownloadListner.stream.listen((event) {
      // Every download instruction is listened from this.
      var downloadtask = DownloadTask()
        ..name = "CNEX Task"
        ..isCanceled = false
        ..isCompleted = false
        ..isFailed = false
        ..isPaused = false
        ..url = event['url']
        ..storagePath = event['path'];
      widget.isar.writeTxn(() async {
        var length = await widget.isar.downloadTasks
            .filter()
            .isDownloadingEqualTo(true)
            .count();
        if (length == 0) {
          downloadtask.isDownloading = true;
          downloadtask.isQueue = false;
        } else {
          downloadtask.isDownloading = false;
          downloadtask.isQueue = true;
        }
        await widget.isar.downloadTasks
            .put(downloadtask)
            .onError((error, stackTrace) {
          print(error.toString());
          print(stackTrace.toString());
          return Future.value(null);
        });
      }).then(
        onError: (value) {
          print(value);
          Get.showSnackbar(GetSnackBar(
            borderRadius: 5,
            animationDuration: Durations.long3,
            backgroundColor: Colors.red[600]!,
            duration: Durations.extralong3,
            message: "Error Adding Task",
            overlayBlur: 1.5,
            overlayColor: Appcolors.appLogoColor.withAlpha(30),
          ));
        },
        (value) async {
          var length = await widget.isar.downloadTasks
              .filter()
              .isDownloadingEqualTo(true)
              .and()
              .not()
              .idEqualTo(downloadtask.id)
              .count();
          print("{@PARAM: [length]} VALUE: $length");
          if (length == 0) {
            new DownloadTaskServices(task: downloadtask)
                .startDownload(widget.isar, downloadCompleteListner.sink,
                    downloadLogListner.sink, 0)
                .then((value) {}, onError: (error, s) {
              print(error);
              print(s);
              Get.showSnackbar(GetSnackBar(
                borderRadius: 5,
                animationDuration: Durations.long3,
                backgroundColor: Colors.red[600]!,
                duration: const Duration(seconds: 5, milliseconds: 200),
                message: "Error Occured, $error",
                overlayBlur: 1.5,
                overlayColor: Appcolors.appLogoColor.withAlpha(30),
              ));
            });
            Get.showSnackbar(GetSnackBar(
              borderRadius: 5,
              animationDuration: Durations.long3,
              backgroundColor: Colors.green[600]!,
              duration: Durations.extralong3,
              message: "Download Started",
              overlayBlur: 1.2,
              overlayColor: Appcolors.appLogoColor.withAlpha(30),
            ));
          } else {
            queue.add(downloadtask);
            Get.showSnackbar(GetSnackBar(
              borderRadius: 5,
              animationDuration: Durations.long3,
              backgroundColor: Colors.green[600]!,
              duration: Durations.extralong1,
              message: "Download Added in Queue",
              overlayBlur: 1.2,
              overlayColor: Appcolors.appLogoColor.withAlpha(30),
            ));
          }
        },
      );
    });
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();

    addDownloadListner.close();
    downloadCompleteListner.close();
    downloadLogListner.close();
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
        title: 'CNEX',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          // This is the theme of your application.
          primaryColor: Appcolors.appLogoColor,
          hoverColor: Appcolors.appLogoColor,
          focusColor: Appcolors.appLogoColor,
          splashColor: Appcolors.appLogoColor,
          indicatorColor: Appcolors.appLogoColor,
          highlightColor: Appcolors.appLogoColor.withAlpha(100),
          toggleButtonsTheme: const ToggleButtonsThemeData(
              selectedColor: Appcolors.appAccentColor,
              hoverColor: Appcolors.appAccentColor,
              selectedBorderColor: Appcolors.appLogoColor),
          textSelectionTheme: const TextSelectionThemeData(
              cursorColor: Appcolors.appAccentColor,
              selectionColor: Appcolors.appPrimaryColor,
              selectionHandleColor: Appcolors.appPrimaryColor),

          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7.5)),
                foregroundColor: Appcolors.appTextColor,
                backgroundColor: Appcolors.appAccentColor
                // Change the text color
                // Change the button background color
                ),
          ),

          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7.5)),
                foregroundColor: Appcolors.appBackgroundColor,
                backgroundColor: Appcolors.appPrimaryColor),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7.5)),
                foregroundColor: Appcolors.appBackgroundColor,
                backgroundColor: Appcolors.appPrimaryColor),
          ),
          iconButtonTheme: IconButtonThemeData(
              style: IconButton.styleFrom(
                  foregroundColor: Appcolors.appTextColor,
                  backgroundColor: Appcolors.appAccentColor)),

          colorScheme: ColorScheme.fromSeed(seedColor: Colors.grey.shade300),

          useMaterial3: true,
        ),
        home: Scaffold(
          floatingActionButton: navigationSelectionIndex == 0
              ? IconButton.filled(
                  style: const ButtonStyle(),
                  onPressed: () {
                    Get.to(AddDownload(
                      isar: widget.isar,
                      addDownload: addDownloadListner.sink,
                    ));
                  },
                  tooltip: "New Download Task",
                  icon: const Icon(
                    color: Appcolors.appPrimaryColor,
                    Icons.add,
                    size: 24,
                  ))
              : null,
          backgroundColor: Appcolors.appBackgroundColor,
          body: Row(
            children: [
              Navigationtab(
                currentSelectionIndex: navigationSelectionIndex,
                callbackOnChange: (index) {
                  if (index != navigationSelectionIndex) {
                    setState(() {
                      navigationSelectionIndex = index;
                    });
                  }
                },
              ),
              Flexible(child: Center(
                child: () {
                  switch (navigationSelectionIndex) {
                    case 0:
                      return DownloadsPage(
                        downloadlog: logs,
                        isar: widget.isar,
                      );
                    case 1:
                      return const Offstage();
                    case 2:
                      return SettingsPage(isar: widget.isar);
                    case 3:
                      return const Offstage(); //not implemented 1,3
                    default:
                      return const Offstage();
                  }
                }(),
              ) /* MyHomePage(
                hasNextVersion: widget.out_of_date,
                new_version: widget.version,
              ) */
                  ),
            ],
          ),
        ) /* MyHomePage(
        hasNextVersion: out_of_date,
        new_version: version,
      ),
      */
        );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage(
      {super.key, required this.hasNextVersion, required this.new_version});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final bool hasNextVersion;
  final double? new_version;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

List<int> options = [0, 1, 2, 3];

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  TextEditingController input = TextEditingController();
  // ignore: avoid_init_to_null
  String? directory = null;
  String? url = null;
  int total = 0;
  int downloaded = 0;
  int downloadSize = 0;
  String progress = "0 %";
  bool isCrawled = false;
  bool isLoading = false;
  int currentOption = options[0];
  Box settingsBox = Hive.box("settings");
  Map settingMap = Hive.box("settings").toMap();
  Box historyBox = Hive.box("history");
  Box LinksBox = Hive.box("links");
  bool isDone = false;
  int clink = 0;
  int totalLinks = 0;
  int totalalbums = 0;
  int downloadAlbums = 0;
  dynamic creator = UniqueKey().toString();
  bool cancel = false;
  int done_count = 0;
  int fail_count = 0;
  int skip_count = 0;
  int threads = 0;
  bool Debug = true;
  List<Map<dynamic, dynamic>> logg = [];
  List<Map<dynamic, dynamic>> scrap_logg = [];
  List<String> downloadedCreators = [];
  ScrollController _scrollController = ScrollController();
  ScrollController _scrollControllerr = ScrollController();
  int scrap_fail = 0;
  int coomerPhotoOptions = 0;

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        if (widget.hasNextVersion) ...[
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "New Version Avaliable! | ${widget.new_version}",
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Appcolors.appAccentColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 13),
                ),
                const SizedBox(width: 10),
                TextButton(
                    onPressed: () {
                      launchUrl(Uri.parse(
                          "https://github.com/notfaad/coom-dl/releases/latest"));
                    },
                    child: const Text("Update! 💜",
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold))),
              ],
            ),
          )
        ] else ...[
          const SizedBox(height: 5),
        ],
        if (!isLoading) ...[
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Padding(
              child: Container(
                alignment: Alignment.center,
                width: MediaQuery.of(context).size.width * 0.3,
                height: 30,
                decoration: BoxDecoration(
                    color: Appcolors.appAccentColor.withAlpha(50),
                    borderRadius: BorderRadius.circular(5)),
                child: Text(
                  directory ?? "No Directory Picked",
                  style: const TextStyle(
                      color: Appcolors.appPrimaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      overflow: TextOverflow.ellipsis),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            Flexible(
                child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: SizedBox(
                  height: 30,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: FilledButton.icon(
                      style: ButtonStyle(backgroundColor:
                          MaterialStateProperty.resolveWith((states) {
                        return Appcolors.appAccentColor;
                      })),
                      icon: const Icon(
                        size: 14,
                        Icons.folder,
                        color: Appcolors.appPrimaryColor,
                      ),
                      onHover: (value) {},
                      onPressed: () async {
                        final String? directoryPath = await getDirectoryPath();
                        if (directoryPath == null) {
                          // Operation was canceled by the user.
                          return;
                        } else {
                          setState(() {
                            directory = directoryPath;
                          });
                        }
                      },
                      label: const Text(
                        "Browse",
                        style: TextStyle(
                            color: Appcolors.appPrimaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  )),
            )),
          ]),
          Flexible(
              child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.025),
            child: TextField(
              controller: input,
              onChanged: (value) {
                if (value.isNotEmpty) {
                  setState(() {
                    url = value;
                  });
                } else {
                  setState(() {
                    url = null;
                  });
                }
              },
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  setState(() {
                    url = value;
                  });
                } else {
                  setState(() {
                    url = null;
                  });
                }
              },
              maxLines: null,
              style:
                  const TextStyle(color: Appcolors.appTextColor, fontSize: 11),
              decoration: InputDecoration(
                  contentPadding: const EdgeInsets.all(5),
                  border: const OutlineInputBorder(),
                  hintText: () {
                    if (settingMap['eng'] == 0) {
                      return "[CoomCRWL:Engine]\nInput one Link per Line.\nCheck 'Links' section for supported links\n New Design and improved engine\n";
                    } else if (settingMap['eng'] == 1) {
                      return "[Gallery-dl:Engine]\nInput one Link per Line.\nTo add more args use ',' \nwww.example.com,-u 'username',-p 'password'\nDO NOT USE (-D or -d) and make sure the LINK goes first\n";
                    } else {
                      return "[Cyberdrop-dl:Engine]\nInput one Link per Line.\nTo add more args use ',' \nwww.example.com,--exclude-audio,--gofile-api-key <KEY>\nDO NOT USE (-o) and make sure the LINK goes first\n";
                    }
                  }(),
                  hintStyle: const TextStyle(
                      color: Appcolors.appPrimaryColor, fontSize: 11)),
            ),
          )),
          if (settingMap['eng'] == 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                    width: 100,
                    height: 40,
                    child: ListTile(
                      title: const Text(
                        "All",
                        style: TextStyle(
                            color: Appcolors.appTextColor, fontSize: 11),
                      ),
                      leading: Radio(
                          activeColor: Appcolors.appPrimaryColor,
                          value: options[0],
                          groupValue: currentOption,
                          onChanged: (value) {
                            setState(() {
                              currentOption = value!;
                            });
                          }),
                    )),
                SizedBox(
                    width: 150,
                    height: 40,
                    child: ListTile(
                      title: const Text("Videos",
                          style: TextStyle(
                              color: Appcolors.appTextColor, fontSize: 11)),
                      leading: Radio(
                          activeColor: Appcolors.appPrimaryColor,
                          value: options[1],
                          groupValue: currentOption,
                          onChanged: (value) {
                            setState(() {
                              currentOption = value!;
                            });
                          }),
                    )),
                SizedBox(
                    width: 160,
                    height: 40,
                    child: ListTile(
                      title: const Text("Pictures",
                          style: TextStyle(
                              color: Appcolors.appTextColor, fontSize: 11)),
                      leading: Radio(
                          activeColor: Appcolors.appPrimaryColor,
                          value: options[2],
                          groupValue: currentOption,
                          onChanged: (value) {
                            setState(() {
                              currentOption = value!;
                            });
                          }),
                    )),
                SizedBox(
                    width: 150,
                    height: 40,
                    child: ListTile(
                      title: const Text("Misc.(Zip,etc..)",
                          style: TextStyle(
                              color: Appcolors.appTextColor, fontSize: 11)),
                      leading: Radio(
                          activeColor: Appcolors.appPrimaryColor,
                          value: options[3],
                          groupValue: currentOption,
                          onChanged: (value) {
                            setState(() {
                              currentOption = value!;
                            });
                          }),
                    )),
              ],
            ),
            if (currentOption == options[0] || currentOption == options[2]) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Flexible(
                      child: SizedBox(
                          height: 30,
                          child: ListTile(
                            title: const Text(
                              "[Slower] High Quality Picture (Coomer/Kemono)",
                              style: TextStyle(
                                  color: Appcolors.appTextColor, fontSize: 10),
                            ),
                            leading: Radio(
                                activeColor: Appcolors.appPrimaryColor,
                                value: 0,
                                groupValue: coomerPhotoOptions,
                                onChanged: (value) {
                                  setState(() {
                                    coomerPhotoOptions = value!;
                                  });
                                }),
                          ))),
                  Flexible(
                      child: SizedBox(
                          height: 30,
                          child: ListTile(
                            title: const Text(
                                "[Faster]- Standard Quality Picture (Coomer/Kemono)",
                                style: TextStyle(
                                    color: Appcolors.appTextColor,
                                    fontSize: 10)),
                            leading: Radio(
                                activeColor: Appcolors.appPrimaryColor,
                                value: 1,
                                groupValue: coomerPhotoOptions,
                                onChanged: (value) {
                                  setState(() {
                                    coomerPhotoOptions = value!;
                                  });
                                }),
                          ))),
                ],
              ),
            ]
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            child: Divider(
              color: Colors.grey.shade300,
            ),
          ),
          const SizedBox(
            height: 5,
          ),
          if (isDone) ...[
            Container(
              color: Colors.green.shade900,
              height: 20,
              child: Text(
                " Done!😎 (${downloadedCreators.length}) Link/s Thanks for using Coom-DL <3 ",
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
              ),
            )
          ],
        ],
        if (isLoading && isCrawled) ...[
          Text.rich(TextSpan(children: [
            TextSpan(
                text: "[$clink/$totalLinks]",
                style: const TextStyle(
                  color: Appcolors.appPrimaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                )),
            TextSpan(
                text: " $creator",
                style: const TextStyle(
                  color: Appcolors.appTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ))
          ])),
          const SizedBox(
            height: 20,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text("DOWNLOADS:",
                style: TextStyle(
                  color: Appcolors.appTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                )),
          ),
          Console(
            logg: logg,
            scrollController: _scrollController,
            getFileSizeString: FileSizeConverter.getFileSizeString,
            settingMap: settingMap,
          ),
        ],
        const SizedBox(
          height: 20,
        ),
        if (!isLoading && !isCrawled) ...[
          FilledButton(
              onPressed: directory != null && url != null && !isLoading
                  ? () async {
                      if (settingMap['eng'] == 0) {
                        await RecoomaEngineDownload(downloaded, total);
                      } else if (settingMap['eng'] == 1) {
                        await GalleryDlEngine()
                            .download(
                                url: url!,
                                dir: directory,
                                historyBox: historyBox)
                            .onError((error, stackTrace) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            backgroundColor: Colors.red.withAlpha(120),
                            content: Text(
                              "$error",
                              style: TextStyle(
                                  color: Colors.grey.shade300, fontSize: 12),
                            ),
                            duration: Duration(seconds: () {
                              if (settingMap['debug']) {
                                return 15;
                              } else {
                                return 4;
                              }
                            }()),
                          ));
                        });
                      } else if (settingMap['eng'] == 2) {
                        await CyberDropDownloaderEngine().download(
                            url: url!, dir: directory, historyBox: historyBox);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          backgroundColor: Colors.red.withAlpha(120),
                          content: Text(
                            "Engine Configs: [CyberdropDownloader:notimplemented]",
                            style: TextStyle(
                                color: Colors.grey.shade300, fontSize: 12),
                          ),
                          duration: Duration(seconds: () {
                            if (settingMap['debug']) {
                              return 30;
                            } else {
                              return 4;
                            }
                          }()),
                        ));
                      }
                    }
                  : null,
              child: Text(
                "Download",
                style: TextStyle(color: Colors.grey[220]),
              )),
        ],
        if (settingMap['debug']) ...[
          FilledButton(
              onPressed: () async {
                var res = await Dio().downloadUri(
                    Uri.parse(
                        "https://c1.coomer.su/data/46/cf/46cfd9368249e5e10492b7d5a6d9ad973c9e1b68d147d373da27de04ee553d28.jpg?f=1834x2448_d88ed7baea5a0943f3a772c8240285a6.jpg"),
                    "Z:\\Cyberdrop\\coom.party\\helloquqco\\12.jpg");
                print(res.headers.map);
              },
              child: const Text("Test"))
        ],
        const SizedBox(
          height: 20,
        ),
        if (isLoading && isCrawled) ...[
          DownloadStatus(
              failed_links_count: scrap_fail,
              Size: FileSizeConverter.getFileSizeString(
                  bytes: downloadSize, decimals: 2),
              done_count: done_count,
              downloaded: downloaded,
              fail_count: fail_count,
              settingMap: settingMap,
              skip_count: skip_count,
              threads: threads,
              total: total),
          const SizedBox(
            height: 20,
          ),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: LinearProgressIndicator(
                value: (downloaded / total),
                minHeight: 5,
                color: const Color.fromARGB(255, 163, 0, 141),
              )),
          const SizedBox(
            height: 10,
          ),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      cancel = true;
                    });
                  },
                  child:
                      Text(clink == totalLinks ? "Cancel" : "Skip to Next"))),
          const SizedBox(
            height: 10,
          ),
        ] else if (isLoading && !isCrawled) ...[
          const Text(
                  "Crawling Content Please Wait...(This Could Take a Minute)",
                  style: TextStyle(
                      color: Color.fromARGB(255, 207, 3, 248), fontSize: 14))
              .animate(onPlay: (controller) => controller.repeat())
              .shimmer(duration: 1000.ms, colors: [
            Appcolors.appSecondaryColor,
            Appcolors.appPrimaryColor
          ]),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text("CRAWLS:",
                style: TextStyle(
                  color: Appcolors.appTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                )),
          ),
          Console(
            logg: scrap_logg,
            scrollController: _scrollControllerr,
            getFileSizeString: FileSizeConverter.getFileSizeString,
            settingMap: settingMap,
          ),
          // uses `Animate.defaultDuration`
          // inherits duration from fadeIn
          // runs after the above w/new duration,
        ]
      ],
    ));

    // This trailing comma makes auto-formatting nicer for build methods.
  }

  // ignore: non_constant_identifier_names
  Future<void> RecoomaEngineDownload(int d, int t) async {
    await RecoomaEngine().download(
        isStandardPhoto: coomerPhotoOptions == 1 ? true : false,
        links_config: LinksBox.toMap(),
        creator: creator,
        getCanceled: () {
          return cancel;
        },
        clink: clink,
        context: context,
        Debug: Debug,
        directory: directory!,
        historyBox: historyBox,
        settingMap: settingMap,
        currentOption: currentOption,
        size: FileSizeConverter.getFileSizeString(
            bytes: downloadSize, decimals: 2),
        percentage: () {
          //Format Percentage after downloading.
          return "${((downloaded / total) * 100).toStringAsFixed(1)} %";
        },
        onscrape: (v) {
          setState(() {
            if (v['status'] == "fail") {
              scrap_fail++;
            }
            scrap_logg.add(v);
            print(scrap_logg);
            // _scrollControllerr
            //  .jumpTo(_scrollControllerr.position.maxScrollExtent);
          });
        },
        CB1: () {
          setState(() {
            total = 0; //Logic
            isDone = false;
            downloadedCreators.clear();
            downloaded = 0; //Logic
            totalalbums = 0; //UI View
            cancel = false;
            downloadAlbums = 0; //UI View
          });
        },
        CB2: (i, s) {
          setState(() {
            clink = i + 1;
            totalLinks = s.length;
            downloaded = 0;
            cancel = false;
          });
        },
        CB3: () {
          setState(() {
            isDone = false;
          });
        },
        CB4: () {
          setState(() {
            isLoading = true;
            //oneTime = true;
          });
        },
        CB5: (value) {
          setState(() {
            threads = value;
          });
        },
        CB6: (values) {
          setState(() {
            if (values['status'] == "ok") {
              done_count++;
            } else if (values['status'] == "skip") {
              skip_count++;
            } else if (values['status'] == "fail") {
              fail_count++;
            }
            logg.add(values);
            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
            if (values.containsKey('size')) {
              try {
                downloadSize += int.parse(values['size'].toString());
                // ignore: empty_catches
              } catch (e) {}
            }
          });

          // await windows
        },
        getFileSize: () {
          return FileSizeConverter.getFileSizeString(
              bytes: downloadSize, decimals: 1);
        },
        CB7: (value) {
          setState(() {
            downloadedCreators.add(value);
            creator = value;
          });
        },
        CB8: (value) {
          setState(() {
            downloadAlbums++;
            downloaded = value;
          });
        },
        CB9: (value) {
          setState(() {
            totalalbums += value[0] as int;
            total = value[0];
            creator = value[1];
            isCrawled = true;
            scrap_logg.clear();
          });
        },
        CB10: () {
          setState(() {
            isDone = true;
          });
        },
        CB11: () {
          setState(() {
            url = null;
            directory = null;
            isLoading = false;
            input.clear();
          });
        },
        CB12: () {
          setState(() {
            logg.clear();

            done_count = 0;
            fail_count = 0;
            skip_count = 0;
            isCrawled = false;
            downloaded = 0;
            total = 0;
          });
        },
        CB13: () {
          setState(() {
            downloadSize = 0;
          });
        },
        CB14: () {
          setState(() {
            isLoading = false;
            url = null;
            directory = null;
            threads = 0;
            downloaded = 0;
            logg.clear();
            Debug = true;
            input.clear();
          });
        },
        url: url);
  }
}

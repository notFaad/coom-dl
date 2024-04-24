import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:coom_dl/constant/appcolors.dart';
import 'package:coom_dl/downloader/Recooma_engine.dart';
import 'package:coom_dl/downloader/external/cyberdrop_dl_engine.dart';
import 'package:coom_dl/downloader/external/gallery_dl_engine.dart';
import 'package:coom_dl/widgets/Dialogs/History_dialog.dart';
import 'package:coom_dl/widgets/console.dart';
import 'package:coom_dl/widgets/download_status.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:html/dom.dart' as html;
import 'package:coom_dl/coomercrawl.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
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
  double current_version = 0.72;
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
    await windowManager.setSize(const Size(700, 500));
    if (Platform.isWindows) {
      await windowManager.setIcon("../assets/logo.png");
    }
    // await windowManager.setMaximumSize(const Size(700, 500));
    await windowManager.setMinimumSize(const Size(700, 500));
    await windowManager.setTitle("Coom-Dl 0.72 beta | by notFaad");
    // await windowManager.setMaximizable(false);
    await windowManager.show();
    await windowManager.focus();
  });
  bool isExist = false;
  final Directory appDocumentsDir = await getApplicationDocumentsDirectory();
  if (!(await Hive.boxExists("settings",
      path: "${appDocumentsDir.path.toString()}/coom-dl"))) {
    var b = await Hive.openBox("settings",
        path: "${appDocumentsDir.path.toString()}/coom-dl");

    await b.put("debug", false);
    await b.put("job", 5);
    await b.put("retry", 6);
    await b.put("eng", 0);
  } else {
    await Hive.openBox("settings",
        path: "${appDocumentsDir.path.toString()}/coom-dl");
  }
  if (!await Hive.boxExists("links",
      path: "${appDocumentsDir.path.toString()}/coom-dl")) {
    var l = await Hive.openBox("links",
        path: "${appDocumentsDir.path.toString()}/coom-dl");
    Map<dynamic, dynamic> links = {
      "coomer": {
        "image": "div.post__thumbnail > figure > a",
        "album": "section > div > div > article",
        "video": "a.post__attachment-link",
        "misc": "coomdl:notimplemented",
        "creator": 'span[itemprop="name"]',
        "creator-single": 'a[class="post__user-name"]',
        "nextpage": "div > menu > a.next",
        "date": "div.post__published"
      }
    };
    await l.putAll(links);
  } else {
    await Hive.openBox("links",
        path: "${appDocumentsDir.path.toString()}/coom-dl");
  }

  await Hive.openBox("history",
      path: "${appDocumentsDir.path.toString()}/coom-dl");

  print(SysInfo.cores.length);
  runApp(MyApp(
    out_of_date: hasNewVersion,
    version: newV,
  ));
}

class MyApp extends StatelessWidget {
  MyApp({super.key, required this.out_of_date, required this.version});
  bool out_of_date;
  double? version;
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'coom-dl',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // This is the theme of your application.
        textSelectionTheme: const TextSelectionThemeData(
            cursorColor: Appcolors.appAccentColor,
            selectionColor: Appcolors.appPrimaryColor,
            selectionHandleColor: Appcolors.appPrimaryColor),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7.5)),
              foregroundColor: Appcolors.appTextColor,
              backgroundColor: Appcolors.appSecondaryColor
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
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a blue toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.

        colorScheme: ColorScheme.fromSeed(seedColor: Colors.grey.shade300),

        useMaterial3: true,
      ),
      home: MyHomePage(
        hasNextVersion: out_of_date,
        new_version: version,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage(
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
  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  String getFileSizeString({required int bytes, int decimals = 0}) {
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    if (bytes == 0) return '0 ${suffixes[0]}';
    var i = (log(bytes) / log(1024)).floor();
    return "${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}";
  }

  void _showListModal(BuildContext context, Function callback) async {
    Map changedMap = {};
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            padding: const EdgeInsets.all(20),
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            color: Appcolors.appBackgroundColor,
            child: Column(
              children: [
                Flexible(
                    child: Container(
                        color: Appcolors.appBackgroundColor,
                        height: 300,
                        child: JsonEditor(
                          enableKeyEdit: false,
                          enableMoreOptions: false,
                          themeColor: Appcolors.appAccentColor,
                          editors: const [Editors.tree],
                          onChanged: (value) {
                            changedMap = value;
                          },
                          json: json.encode(LinksBox.toMap()),
                        ))),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 20, horizontal: 50),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton(
                          onPressed: () async {
                            await LinksBox.putAll(changedMap);
                            Navigator.of(context).pop();
                            callback();
                          },
                          child: const Text("Save & Close")),
                      const SizedBox(
                        width: 10,
                      ),
                      Column(
                        children: [
                          SizedBox(
                            width: 90,
                            height: 25,
                            child: TextButton.icon(
                                onPressed: () async {
                                  const XTypeGroup typeGroup = XTypeGroup(
                                    label: 'CDL File',
                                    extensions: <String>['cdl'],
                                  );
                                  final XFile? file = await openFile(
                                      acceptedTypeGroups: <XTypeGroup>[
                                        typeGroup
                                      ]);
                                  if (file == null) {
                                    return;
                                  }
                                  String res = await file!
                                      .readAsString()
                                      .onError((error, stackTrace) => "");
                                  changedMap = jsonDecode(res);
                                  await LinksBox.putAll(changedMap);
                                  Navigator.of(context).pop();
                                  callback();
                                },
                                icon: const Icon(
                                  Icons.file_upload,
                                  size: 14,
                                ),
                                label: const Text(
                                  "Load",
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400),
                                )),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 90,
                            height: 25,
                            child: TextButton.icon(
                                onPressed: () async {
                                  const XTypeGroup typeGroup = XTypeGroup(
                                    label: 'CDL file',
                                    extensions: <String>['cdl'],
                                  );
                                  String fileName =
                                      'COOMDL_SAVE-${const Uuid().v1().toString()}.cdl';
                                  final FileSaveLocation? result =
                                      await getSaveLocation(
                                          suggestedName: fileName,
                                          acceptedTypeGroups: [typeGroup]);
                                  if (result == null) {
                                    // Operation was canceled by the user.
                                    return;
                                  }

                                  final Uint8List fileData = Uint8List.fromList(
                                      changedMap.isEmpty
                                          ? jsonEncode(LinksBox.toMap())
                                              .codeUnits
                                          : jsonEncode(changedMap).codeUnits);

                                  final XFile textFile =
                                      XFile.fromData(fileData, name: fileName);
                                  await textFile.saveTo("${result.path}.cdl");
                                },
                                icon: const Icon(
                                  Icons.offline_share,
                                  size: 14,
                                ),
                                label: const Text(
                                  "Export",
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400),
                                )),
                          )
                        ],
                      )
                    ],
                  ),
                )

                // Add more widgets as needed
              ],
            ),
          ),
        );
      },
    );
  }

  void _showModal(BuildContext context, Function callback) async {
    Map<dynamic, dynamic> settings = settingsBox.toMap();
    String jobs_holder = settings['job'].toString();
    String retry_holder = settings['retry'].toString();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width / 2,
            color: Appcolors.appBackgroundColor,
            padding: const EdgeInsets.all(5),
            child: Column(
              children: [
                const Text(
                  'Coom-dl Settings',
                  style: TextStyle(
                      color: Appcolors.appTextColor,
                      fontWeight: FontWeight.bold),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 5),
                  child: Divider(),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  child: Wrap(
                    children: [
                      const Text(
                        "[IGNORE] Developer Mode",
                        style: TextStyle(
                            color: Appcolors.appTextColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      SizedBox(
                        width: 90,
                        height: 22,
                        child: FilledButton(
                            onPressed: () async {
                              await settingsBox.put(
                                  "debug", !settings['debug']);

                              Navigator.of(context).pop();
                              callback();
                            },
                            child: Text(
                              "${() {
                                if (settings['debug']) {
                                  return "Turn off";
                                } else {
                                  return "Turn on";
                                }
                              }()}",
                              style: const TextStyle(fontSize: 11),
                            )),
                      )
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 5),
                  child: Divider(),
                ),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                            color: Appcolors.appTextColor.withAlpha(20),
                            width: 150,
                            height: 30,
                            child: const Center(
                              child: Text(
                                "Number of jobs(1-9)",
                                style: TextStyle(
                                    color: Appcolors.appTextColor,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12),
                              ),
                            )),
                        const SizedBox(
                          width: 5,
                        ),
                        Flexible(
                            child: TextField(
                          onChanged: (value) async {
                            if (value.isNotEmpty) {
                              jobs_holder = value;
                            } else {
                              jobs_holder = settings['job'].toString();
                            }
                          },
                          style: const TextStyle(
                              color: Appcolors.appTextColor,
                              fontWeight: FontWeight.w500,
                              fontSize: 12),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r"^([1-9]){1}$"))
                          ],
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.all(2),
                              prefix: const Text('>>'),
                              hintText: "${settings['job']}",
                              hintStyle: const TextStyle(
                                  color: Appcolors.appTextColor, fontSize: 12)),
                        ))
                      ],
                    ),
                  ),
                ),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                            color: Appcolors.appTextColor.withAlpha(20),
                            width: 150,
                            height: 30,
                            child: const Center(
                              child: Text(
                                "Download fail retries(1-9)",
                                style: TextStyle(
                                    color: Appcolors.appTextColor,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 11),
                              ),
                            )),
                        const SizedBox(
                          width: 5,
                        ),
                        Flexible(
                            child: TextField(
                          onChanged: (value) {
                            if (value.isNotEmpty) {
                              retry_holder = value;
                            } else {
                              retry_holder = settings['retry'].toString();
                            }
                          },
                          style: const TextStyle(
                              color: Appcolors.appTextColor,
                              fontWeight: FontWeight.w500,
                              fontSize: 12),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r"^([1-9]){1}$"))
                          ],
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.all(2),
                              prefix: const Text('>>'),
                              hintText: "${settings['retry']}",
                              hintStyle: const TextStyle(
                                  color: Appcolors.appTextColor, fontSize: 12)),
                        ))
                      ],
                    ),
                  ),
                ),

                const Text(
                  textAlign: TextAlign.center,
                  "Note: Recommended(jobs/retires):\n- [5/6] (<1% fail)\n- [n>6/n<=3] (60-99% fail,not recommended)\n 'The higher the job the more it consumes RAM and fails'",
                  style: TextStyle(
                      color: Appcolors.appTextColor,
                      fontSize: 12,
                      fontStyle: FontStyle.italic),
                ),
                const Spacer(),
                Flexible(
                    child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  child: FilledButton(
                      onPressed: () async {
                        await settingsBox.put("job", int.parse(jobs_holder));
                        await settingsBox.put("retry", int.parse(retry_holder));
                        await settingsBox.put("eng", settings['eng']);
                        Navigator.of(context).pop();
                        callback();
                      },
                      child: const Text("Save and close")),
                ))
                // Add more widgets as needed
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    // ^((https:\/\/)|(https:\/\/www\.))?coomer\.(party|su){1}\/(onlyfans|fansly){1}\/user{1}\/.+$ REGEX
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      backgroundColor: Appcolors.appBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Appcolors.appBackgroundColor,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(
          () {
            if (isCrawled) {
              return "Coom-dl: Downloading... 😄";
            } else {
              return "Coom-dl:  by notFaad  |  Made with 💖";
            }
          }(),
          style: const TextStyle(
            color: Appcolors.appTextColor,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        leading: Image.asset("assets/logo.png", height: 120),
        leadingWidth: 120,
        actions: [
          TextButton(
              onPressed: () {
                launchUrl(Uri.parse("https://www.buymeacoffee.com/notfaad"));
              },
              child: const Text("Support Me <3",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
          IconButton(
              onPressed: () {
                launchUrl(Uri.parse("https://github.com/notFaad/coom-dl"));
              },
              icon: const Icon(
                FontAwesomeIcons.github,
                color: Appcolors.appTextColor,
              ))
        ],
      ),

      body: Center(
          child:
              // Center is a layout widget. It takes a single child and positions it
              // in the middle of the parent.
              Column(
        // Column is also a layout widget. It takes a list of children and
        // arranges them vertically. By default, it sizes itself to fit its
        // children horizontally, and tries to be as tall as its parent.
        //
        // Column has various properties to control how it sizes itself and
        // how it positions its children. Here we use mainAxisAlignment to
        // center the children vertically; the main axis here is the vertical
        // axis because Columns are vertical (the cross axis would be
        // horizontal).
        //
        // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
        // action in the IDE, or press "p" in the console), to see the
        // wireframe for each widget.
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
            const SizedBox(height: 1),
          ],
          if (!isLoading) ...[
            Container(
              height: 30,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    const Padding(
                      padding: EdgeInsets.only(right: 5, left: 10),
                      child: Text("Engine: ",
                          style: TextStyle(
                              color: Appcolors.appPrimaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                    SizedBox(
                        width: 100,
                        height: 40,
                        child: SizedBox(
                          width: 220,
                          height: 70,
                          child: DropdownButton(
                            value: settingMap['eng'],
                            dropdownColor: Colors.black12.withAlpha(140),
                            items: [
                              const DropdownMenuItem(
                                  value: 0,
                                  child: Text(
                                    "CoomCRWL",
                                  )),
                              const DropdownMenuItem(
                                  value: 1,
                                  child: Text(
                                    "Gallery-dl",
                                  )),
                              const DropdownMenuItem(
                                  value: 2,
                                  child: Text(
                                    "CyberdropDL",
                                  ))
                            ],
                            onChanged: (val) async {
                              settingMap['eng'] = val;
                              await settingsBox.put("eng", settingMap['eng']);
                              setState(() {});
                            },
                            style: const TextStyle(
                                color: Appcolors.appTextColor, fontSize: 12),
                          ),
                        ))
                  ]),
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: TextButton(
                          onPressed: () async {
                            _showModal(context, () async {
                              var mapper = await settingsBox.toMap();
                              setState(() {
                                settingMap = mapper;
                              });
                            });
                          },
                          child: const Text("Engine Config"),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: TextButton(
                          onPressed: () async {
                            HistoryDialog()
                                .showHistoryModal(context, historyBox);
                          },
                          child: const Text("History"),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: TextButton(
                          onPressed: () async {
                            _showListModal(context, () {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(
                                content: Text(
                                  "Links Saved",
                                  style: TextStyle(
                                      color: Appcolors.appPrimaryColor),
                                ),
                                backgroundColor: Colors.green,
                              ));
                            });
                          },
                          child: const Text("Links Config."),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (!isLoading) ...[
            Row(mainAxisAlignment: MainAxisAlignment.start, children: [
              Flexible(
                  child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: SizedBox(
                    height: 30,
                    width: MediaQuery.of(context).size.width * 0.5,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width * 0.05),
                      child: FilledButton.icon(
                        style: ButtonStyle(backgroundColor:
                            MaterialStateProperty.resolveWith((states) {
                          return Appcolors.appAccentColor;
                        })),
                        icon: const Icon(
                          Icons.folder,
                          color: Appcolors.appPrimaryColor,
                        ),
                        onHover: (value) {},
                        onPressed: () async {
                          final String? directoryPath =
                              await getDirectoryPath();
                          if (directoryPath == null) {
                            // Operation was canceled by the user.
                            return;
                          } else {
                            setState(() {
                              directory = directoryPath;
                            });
                          }
                        },
                        label: Text(
                          directory ?? "Pick a Directory",
                          style: const TextStyle(
                              color: Appcolors.appPrimaryColor,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    )),
              )),
              /* Padding(
                padding: const EdgeInsets.only(left: 20, right: 20),
                child: TextButton(
                  onPressed: url != null && url!.isNotEmpty
                      ? () async {
                          const XTypeGroup typeGroup = XTypeGroup(
                            label: 'txt file',
                            extensions: <String>['txt'],
                          );
                          String fileName =
                              'COOMDL_SAVE-${const Uuid().v1().toString()}.txt';
                          final FileSaveLocation? result =
                              await getSaveLocation(
                                  suggestedName: fileName,
                                  acceptedTypeGroups: [typeGroup]);
                          if (result == null) {
                            // Operation was canceled by the user.
                            return;
                          }

                          final Uint8List fileData =
                              Uint8List.fromList(url!.codeUnits);

                          final XFile textFile =
                              XFile.fromData(fileData, name: fileName);
                          await textFile.saveTo("${result.path}.txt");
                        }
                      : null,
                  child: const Text("Save as .txt"),
                ),
              ), */

              /* Padding(
                padding: const EdgeInsets.only(left: 20, right: 20),
                child: TextButton(
                  onPressed: () async {
                    const XTypeGroup typeGroup = XTypeGroup(
                      label: 'Text files',
                      extensions: <String>['txt'],
                    );
                    final XFile? file = await openFile(
                        acceptedTypeGroups: <XTypeGroup>[typeGroup]);
                    if (file == null) {
                      return;
                    }
                    String res = await file!
                        .readAsString()
                        .onError((error, stackTrace) => "");
                    setState(() {
                      input.value = TextEditingValue(text: res);
                      url = res;
                    });
                  },
                  child: const Text("Load .txt file"),
                ),
              ) */
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
                style: const TextStyle(
                    color: Appcolors.appTextColor, fontSize: 11),
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
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 5),
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
              getFileSizeString: getFileSizeString,
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
                                  return 30;
                                } else {
                                  return 4;
                                }
                              }()),
                            ));
                          });
                        } else if (settingMap['eng'] == 2) {
                          await CyberDropDownloaderEngine().download(
                              url: url!,
                              dir: directory,
                              historyBox: historyBox);
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
          const SizedBox(
            height: 20,
          ),
          if (isLoading && isCrawled) ...[
            DownloadStatus(
                Size: getFileSizeString(bytes: downloadSize, decimals: 2),
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
                  color: const Color.fromARGB(255, 238, 22, 209),
                )),
            const SizedBox(
              height: 10,
            ),
            Padding(
                child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        cancel = true;
                      });
                    },
                    child: Text(
                        "${clink == totalLinks ? "Finish" : "Skip to Next"}")),
                padding: const EdgeInsets.symmetric(horizontal: 30)),
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
              getFileSizeString: getFileSizeString,
              settingMap: settingMap,
            ),
            // uses `Animate.defaultDuration`
            // inherits duration from fadeIn
            // runs after the above w/new duration,
          ]
        ],
      )),

      // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  Future<void> RecoomaEngineDownload(int d, int t) async {
    await RecoomaEngine().download(
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
        size: getFileSizeString(bytes: downloadSize, decimals: 2),
        percentage: () {
          //Format Percentage after downloading.
          return "${((downloaded / total) * 100).toStringAsFixed(1)} %";
        },
        onscrape: (v) {
          setState(() {
            scrap_logg.add(v);
            print(scrap_logg);
            _scrollControllerr
                .jumpTo(_scrollControllerr.position.maxScrollExtent);
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
          return getFileSizeString(bytes: downloadSize, decimals: 1);
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

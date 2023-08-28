import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:coom_dl/coomercrawl.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:system_info2/system_info2.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Must add this line.
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    center: true,
    titleBarStyle: TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setSize(const Size(700, 500));
    await windowManager.setIcon("logo.png");
    await windowManager.setMaximumSize(const Size(700, 500));
    await windowManager.setMinimumSize(const Size(700, 500));
    await windowManager.setTitle("Coom-Dl 0.43 beta | by notFaad");
    await windowManager.setMaximizable(false);
    await windowManager.show();
    await windowManager.focus();
  });

  print(SysInfo.cores.length);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'coom-dl',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // This is the theme of your application.
        //
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
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  TextEditingController input = TextEditingController();
  // ignore: avoid_init_to_null
  String? directory = null;
  String? url = null;
  int total = 0;
  int downloaded = 0;
  String progress = "0 %";
  bool isCrawled = false;
  bool isLoading = false;
  bool isDone = false;
  int clink = 0;
  int totalLinks = 0;
  int totalalbums = 0;
  int downloadAlbums = 0;
  dynamic creator = UniqueKey().toString();
  bool cancel = false;
  int threads = 0;
  bool Debug = true;
  List<Map<String, dynamic>> log = [];
  ScrollController _scrollController = ScrollController();
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

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    // ^((https:\/\/)|(https:\/\/www\.))?coomer\.(party|su){1}\/(onlyfans|fansly){1}\/user{1}\/.+$ REGEX
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        centerTitle: true,
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Colors.grey[900],
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: const Text(
          "The fastest Coomer | kemono Party Downloader by notFaad.",
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              fontStyle: FontStyle.italic),
        ),
        leading: Image.asset("assets/logo.png"),
        leadingWidth: 120,
        actions: [
          IconButton(
              onPressed: () {
                launchUrl(Uri.parse("https://github.com/notFaad/coom-dl"));
              },
              icon: Icon(
                FontAwesomeIcons.github,
                color: Colors.grey.shade300,
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (isDone) ...[
            Text(
              "Downloaded $totalLinks ${totalLinks == 1 ? "Link" : "Links"}, and $downloadAlbums of $totalalbums Albums! You can download again",
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.green.shade500,
                  fontWeight: FontWeight.w500,
                  fontSize: 14),
            )
          ],
          if (!isLoading) ...[
            Flexible(
                child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width / 10),
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
                style: TextStyle(color: Colors.grey.shade300, fontSize: 14),
                decoration: InputDecoration(
                    contentPadding: const EdgeInsets.all(5),
                    border: const OutlineInputBorder(),
                    hintText:
                        "input one Coomer or kemono.party/su Creator/Artist page link per line only!\nexample:\nhttps://coomer.party/onlyfans/user/xxxxx\nKemono.su/fanbox/Artist/xxxx\n",
                    hintStyle:
                        TextStyle(color: Colors.grey.shade300, fontSize: 14)),
              ),
            )),
            const SizedBox(
              height: 5,
            ),
            Flexible(
                child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.of(context).size.width / 4),
                    child: InkWell(
                      mouseCursor: MaterialStateMouseCursor.clickable,
                      hoverColor: Colors.grey.shade300.withOpacity(0.2),
                      child: TextField(
                        enabled: false,
                        readOnly: true,
                        mouseCursor: SystemMouseCursors.click,
                        decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            hintText: directory ?? "Click to Pick a Directory",
                            hintStyle: TextStyle(color: Colors.grey.shade300),
                            prefixIcon: Icon(
                              Icons.folder,
                              color: Colors.grey.shade300,
                            )),
                      ),
                      onTap: () async {
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
                    )))
          ],
          if (isLoading && isCrawled) ...[
            const SizedBox(
              height: 10,
            ),
            ElevatedButton(
                onPressed: () {
                  setState(() {
                    Debug = !Debug;
                  });
                },
                child: Text((() {
                  if (!Debug) {
                    return "Turn on Logs";
                  } else {
                    return "Turn off Logs";
                  }
                }())))
          ],
          const SizedBox(
            height: 20,
          ),
          if (Debug && isLoading && isCrawled) ...[
            Flexible(
                child: Container(
              width: MediaQuery.of(context).size.width,
              color: Colors.grey.shade800.withAlpha(90),
              height: 200,
              margin: const EdgeInsets.symmetric(horizontal: 50),
              child: ListView.builder(
                  controller: _scrollController,
                  shrinkWrap: true,
                  itemCount: log.length,
                  itemBuilder: (context, index) {
                    TextStyle style1;
                    if (log.elementAt(index)['status'] == "ok") {
                      style1 = const TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold);
                    } else if (log.elementAt(index)['status'] == "error") {
                      style1 = const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold);
                    } else if (log.elementAt(index)['status'] == "skip") {
                      style1 = const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold);
                    } else {
                      style1 = const TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold);
                    }
                    return Text(
                      "${log.elementAt(index)['title']} | Result: ${log.elementAt(index)['status']}",
                      style: style1,
                    );
                  }),
            ))
          ],
          const SizedBox(
            height: 20,
          ),
          ElevatedButton(
              onPressed: directory != null && url != null && !isLoading
                  ? () async {
                      setState(() {
                        total = 0; //Logic
                        downloaded = 0; //Logic
                        totalalbums = 0; //UI View
                        cancel = false;
                        downloadAlbums = 0; //UI View
                      });
                      List<String> s = url!.split("\n");
                      for (int i = 0; i < s.length; i++) {
                        if (s[i].trim().isEmpty) {
                          s.removeAt(i);
                        }
                      }
                      String mem_dir = directory!.trim();
                      for (int i = 0; i < s.length; i++) {
                        setState(() {
                          clink = i + 1;
                          totalLinks = s.length;
                          downloaded = 0;
                          cancel = false;
                        });
                        bool ok = false;
                        int? typer = null;
                        // W.I.P
                        // Erome
                        // Lovefap
                        // Fapello
                        // DirtyShip
                        // Eroprofile
                        if (RegExp(
                                r'^((https:\/\/)|(https:\/\/www\.))?coomer\.(party|su){1}\/(onlyfans|fansly){1}\/user{1}\/.+$')
                            .hasMatch(s[i].trim())) {
                          typer = 0;
                          ok = true;
                        } else if (RegExp(
                                r'^((https:\/\/)|(https:\/\/www\.))?kemono\.(party|su){1}\/.+$')
                            .hasMatch(s[i].trim())) {
                          typer = 1;
                          ok = true;
                        } else {
                          ok = false;
                        }

                        if (ok && typer != null) {
                          setState(() {
                            isDone = false;
                          });

                          setState(() {
                            isLoading = true;
                            //oneTime = true;
                          });
                          await new CybCrawl()
                              .getFileContent(
                                  isContinue: () {
                                    var new_value = !cancel;
                                    return new_value;
                                  },
                                  typer: typer,
                                  direct: mem_dir,
                                  url: s[i].trim(),
                                  onThreadchange: (value) {
                                    setState(() {
                                      threads = value;
                                    });
                                  },
                                  log: (dynamic value) {
                                    setState(() {
                                      log.add(value);
                                      _scrollController.jumpTo(_scrollController
                                          .position.maxScrollExtent);
                                    });
                                  },
                                  onComplete: (value) async {
                                    setState(() {
                                      creator = value;
                                    });
                                    await windowManager.setProgressBar(0);
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                      backgroundColor:
                                          Colors.green.withAlpha(65),
                                      content: Text(
                                        "Success: Finished creator download",
                                        style: TextStyle(
                                            color: Colors.grey.shade300),
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ));
                                  },
                                  onDownloadedAlbum: (int value) async {
                                    setState(() {
                                      downloadAlbums++;
                                      downloaded = value;
                                    });
                                    await windowManager
                                        .setProgressBar(downloaded / total);
                                  },
                                  totalAlbums: (List<dynamic> value) {
                                    setState(() {
                                      totalalbums += value[0] as int;
                                      total = value[0];
                                      creator = value[1];
                                      isCrawled = true;
                                    });
                                  })
                              .then((value) async {
                            setState(() {
                              isDone = true;
                            });
                          }).onError((error, stackTrace) {
                            print("$error AT $stackTrace");
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              backgroundColor: Colors.red.withAlpha(120),
                              content: Text(
                                "Error: Error has occurred at ${s[i].trim()}",
                                style: TextStyle(color: Colors.grey.shade300),
                              ),
                              duration: const Duration(seconds: 4),
                            ));
                            setState(() {
                              url = null;
                              directory = null;
                              isLoading = false;
                              input.clear();
                            });
                            return Future.delayed(const Duration(seconds: 3));
                          });
                          setState(() {
                            log.clear();
                            isCrawled = false;
                            downloaded = 0;
                            total = 0;
                          });
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            backgroundColor: Colors.red.withAlpha(120),
                            content: Text(
                              "Error: Unknown Link! [$clink]- ${s[i]}",
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey.shade300),
                            ),
                            duration: const Duration(seconds: 4),
                          ));
                        }
                      }
                      setState(() {
                        isLoading = false;
                        url = null;
                        directory = null;
                        threads = 0;
                        downloaded = 0;
                        log.clear();
                        Debug = true;
                        input.clear();
                      });
                    }
                  : null,
              child: Text(
                "Download",
                style: TextStyle(color: Colors.grey[220]),
              )),
          const SizedBox(
            height: 20,
          ),
          if (!isLoading) ...[
            Text(
              "ENGINE PARAMS INFO:\nEngine jobs = CPU Cores(${SysInfo.cores.length}) x (1)Job per Core \nOS: ${SysInfo.operatingSystemName} ${SysInfo.operatingSystemVersion}\nEngine State: ${() {
                if (directory != null && url != null) {
                  if (directory!.isNotEmpty && url!.isNotEmpty) {
                    return "Ready to Download";
                  } else {
                    return "Waiting input...";
                  }
                } else {
                  return "Waiting input...";
                }
              }()}",
              style: TextStyle(
                  color: Colors.grey.shade300,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            )
          ],
          if (isLoading && isCrawled) ...[
            Text(
              "- [$clink/$totalLinks] | Creator: [$creator] | Downloaded: [$downloaded/$total]  Jobs: [$threads/${SysInfo.cores.length}] | ${((downloaded / total) * 100).toStringAsFixed(1)} %",
              style: TextStyle(
                  color: Colors.grey.shade300, fontWeight: FontWeight.bold),
            ),
            const SizedBox(
              height: 20,
            ),
            Padding(
                child: LinearProgressIndicator(
                  value: (downloaded / total),
                  minHeight: 5,
                  color: Colors.blue,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 30)),
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
            Center(
              child: CircularProgressIndicator(
                color: Colors.blue.shade400,
              ),
            ),
          ]
        ],
      )),

      // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

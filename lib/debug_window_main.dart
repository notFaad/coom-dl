import 'package:flutter/material.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'pages/debugMonitor.dart';
import 'constant/appcolors.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (args.firstOrNull == 'multi_window') {
    final windowId = int.parse(args[1]);
    runApp(DebugMonitorWindow(windowId: windowId));
  } else {
    // This shouldn't be called directly, but just in case
    runApp(const MaterialApp(
        home: Scaffold(body: Center(child: Text('Debug Monitor')))));
  }
}

class DebugMonitorWindow extends StatefulWidget {
  final int windowId;

  const DebugMonitorWindow({Key? key, required this.windowId})
      : super(key: key);

  @override
  _DebugMonitorWindowState createState() => _DebugMonitorWindowState();
}

class _DebugMonitorWindowState extends State<DebugMonitorWindow> {
  bool _hiveInitialized = false;

  @override
  void initState() {
    super.initState();
    _initHive();
  }

  Future<void> _initHive() async {
    if (!Hive.isAdapterRegistered(0)) {
      try {
        final appDocumentDir = await getApplicationDocumentsDirectory();
        final hiveDir = Directory('${appDocumentDir.path}/hive_db');
        if (!await hiveDir.exists()) {
          await hiveDir.create(recursive: true);
        }

        if (!Hive.isBoxOpen('settings')) {
          await Hive.openBox('settings', path: hiveDir.path);
        }

        setState(() {
          _hiveInitialized = true;
        });
      } catch (e) {
        print('Hive initialization error in debug window: $e');
        setState(() {
          _hiveInitialized = true; // Continue anyway
        });
      }
    } else {
      setState(() {
        _hiveInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hiveInitialized) {
      return MaterialApp(
        title: 'Debug Monitor - Loading',
        theme: ThemeData.dark(),
        home: const Scaffold(
          backgroundColor: Appcolors.appBackgroundColor,
          body: Center(
            child: CircularProgressIndicator(
              color: Appcolors.appAccentColor,
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'Debug Monitor',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Appcolors.appBackgroundColor,
        primaryColor: Appcolors.appPrimaryColor,
        colorScheme: ColorScheme.dark(
          primary: Appcolors.appPrimaryColor,
          secondary: Appcolors.appAccentColor,
          surface: Appcolors.appSecondaryColor,
          background: Appcolors.appBackgroundColor,
        ),
      ),
      home: const DebugMonitorPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

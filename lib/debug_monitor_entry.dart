import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';

import 'constant/appcolors.dart';
import 'pages/debugMonitor.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // No Hive initialization here - the debug monitor will work independently
  print('Debug monitor window starting...');

  if (args.isNotEmpty) {
    final windowId = int.parse(args.first);
    WindowController.fromWindowId(windowId).setTitle('Debug Monitor');
  }

  runApp(const DebugMonitorApp());
}

class DebugMonitorApp extends StatelessWidget {
  const DebugMonitorApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Debug Monitor',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        scaffoldBackgroundColor: Appcolors.appBackgroundColor,
        brightness: Brightness.dark,
      ),
      home: const DebugMonitorPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

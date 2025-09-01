import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'constant/appcolors.dart';
import 'pages/galleryViewer.dart';

void main(List<String> args) {
  runApp(GalleryApp(args));
}

class GalleryApp extends StatefulWidget {
  final List<String> args;

  const GalleryApp(this.args, {Key? key}) : super(key: key);

  @override
  State<GalleryApp> createState() => _GalleryAppState();
}

class _GalleryAppState extends State<GalleryApp> with WidgetsBindingObserver {
  Map<String, dynamic> windowData = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Parse arguments from the main window
    if (widget.args.isNotEmpty) {
      try {
        windowData = jsonDecode(widget.args.first);
      } catch (e) {
        print('Failed to parse gallery window arguments: $e');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Prevent automatic window closure during lifecycle changes
    print('Gallery window lifecycle state: $state');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gallery - ${windowData['downloadName'] ?? 'Unknown'}',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color.fromARGB(255, 13, 13, 13),
        primaryColor: Appcolors.appPrimaryColor,
        cardColor: Appcolors.appAccentColor,
        dividerColor: Appcolors.appPrimaryColor.withOpacity(0.1),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
        ),
        iconTheme: IconThemeData(color: Appcolors.appPrimaryColor),
      ),
      home: GalleryViewer(
        downloadId: windowData['downloadId'] ?? 0,
        downloadName: windowData['downloadName'] ?? 'Unknown Download',
        downloadPath: windowData['downloadPath'] ?? '',
      ),
    );
  }
}

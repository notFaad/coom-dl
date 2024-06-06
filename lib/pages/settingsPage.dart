import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

class SettingsPage extends StatefulWidget {
  Isar isar;
  SettingsPage({Key? key, required this.isar}) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5, horizontal: 5),
      child: Container(
        child: Column(
          children: [],
        ),
      ),
    );
  }
}

import 'package:coom_dl/constant/appcolors.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class Navigationtab extends StatefulWidget {
  int currentSelectionIndex;
  Function(int) callbackOnChange;
  Navigationtab(
      {Key? key,
      required this.currentSelectionIndex,
      required this.callbackOnChange})
      : super(key: key);
  @override
  _NavigationtabState createState() => _NavigationtabState();
}

class _NavigationtabState extends State<Navigationtab> {
  @override
  Widget build(BuildContext context) {
    return NavigationRail(
        extended: false,
        backgroundColor: Appcolors.appPrimaryColor.withAlpha(8),
        leading: Image.asset(
          "assets/logo.png",
          height: 30,
          width: 60,
          fit: BoxFit.fitWidth,
        ),
        labelType: NavigationRailLabelType.all,
        unselectedIconTheme:
            const IconThemeData(color: Appcolors.appPrimaryColor, size: 20),
        selectedIconTheme:
            const IconThemeData(color: Appcolors.appNaigationColor, size: 28),
        selectedLabelTextStyle: const TextStyle(
            fontSize: 11,
            color: Appcolors.appNaigationColor,
            fontWeight: FontWeight.bold),
        unselectedLabelTextStyle: const TextStyle(
            fontSize: 11,
            color: Appcolors.appPrimaryColor,
            fontWeight: FontWeight.w100),
        indicatorColor: Colors.transparent,
        indicatorShape: Border(
          left: BorderSide(
              width: 4,
              style: BorderStyle.solid,
              color: const Color.fromARGB(255, 95, 53, 211)),
        ),
        destinations: const [
          NavigationRailDestination(
              icon: Tooltip(
                child: Icon(Icons.download),
                message: "Downloads",
              ),
              label: Offstage()),
          NavigationRailDestination(
              icon: Tooltip(
                child: Icon(Icons.folder_off),
                message: "Manager (Soon)",
              ),
              label: Offstage()),
          NavigationRailDestination(
              icon: Tooltip(
                child: Icon(Icons.settings),
                message: "Settings",
              ),
              label: Offstage()),
          NavigationRailDestination(
              icon: Tooltip(
                child: Icon(Icons.extension_off_rounded),
                message: "Extensions (Soon)",
              ),
              label: Offstage())
        ],
        onDestinationSelected: (val) => widget.callbackOnChange(val),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              child: TextButton(
                  onPressed: () {
                    launchUrl(
                        Uri.parse("https://www.buymeacoffee.com/notfaad"));
                  },
                  child: const Text("Support CNEX",
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold))),
            ),
            const SizedBox(
              height: 5,
            ),
            IconButton(
                onPressed: () {
                  launchUrl(Uri.parse("https://github.com/notFaad/coom-dl"));
                },
                icon: const Icon(
                  FontAwesomeIcons.github,
                  color: Appcolors.appTextColor,
                )),
          ],
        ),
        selectedIndex: widget.currentSelectionIndex);
  }
}

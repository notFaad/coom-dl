import 'dart:async';

import 'package:coom_dl/constant/appcolors.dart';
import 'package:coom_dl/data/models/DlTask.dart';
import 'package:coom_dl/widgets/DownloadWidget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:isar/isar.dart';

class DownloadsPage extends StatefulWidget {
  Isar isar;
  Map<int, dynamic> downloadlog;
  DownloadsPage({Key? key, required this.isar, required this.downloadlog})
      : super(key: key);

  @override
  _DownloadsPageState createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  late StreamSubscription listen;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    listen = widget.isar.downloadTasks
        .where()
        .watch(fireImmediately: true)
        .listen((event) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    listen.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        child: DefaultTabController(
            length: 3,
            child: Container(
              height: MediaQuery.of(context).size.height,
              child: Column(
                children: [
                  TabBar(
                      dividerColor: Appcolors.appAccentColor,
                      dividerHeight: 1,
                      unselectedLabelColor: Appcolors.appPrimaryColor,
                      labelColor: Appcolors.appLogoColor,
                      indicatorColor: Appcolors.appLogoColor,
                      tabAlignment: TabAlignment.fill,
                      isScrollable: false,
                      indicatorWeight: 0.2,
                      automaticIndicatorColorAdjustment: true,
                      overlayColor: MaterialStateProperty.resolveWith(
                          (states) => Appcolors.appPrimaryColor.withAlpha(20)),
                      tabs: const [
                        SizedBox(
                          height: 35,
                          child: Tooltip(
                            child: Tab(icon: Icon(Icons.download)),
                            message: "Current downloads/Queue",
                          ),
                        ),
                        SizedBox(
                            height: 35,
                            child: Tab(
                              icon: Tooltip(
                                child: Icon(Icons.download_done_rounded),
                                message: "Completed Downloads",
                              ),
                            )),
                        SizedBox(
                            height: 35,
                            child: Tab(
                              icon: Tooltip(
                                child: Icon(Icons.cancel_rounded),
                                message: "Failed Downloads",
                              ),
                            ))
                      ]),
                  Container(
                      height: MediaQuery.of(context).size.height - 50,
                      child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: TabBarView(children: [
                            FutureBuilder(
                              future: widget.isar.downloadTasks
                                  .where()
                                  .filter()
                                  .isDownloadingEqualTo(true)
                                  .or()
                                  .isQueueEqualTo(true)
                                  .and()
                                  .isFailedEqualTo(false)
                                  .findAll(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  List<DownloadTask> tasks = snapshot.data!;
                                  if (tasks.isNotEmpty) {
                                    return ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: tasks.length,
                                        itemBuilder: (content, index) {
                                          if (widget.downloadlog.isNotEmpty) {
                                            if (widget.downloadlog.keys.first ==
                                                tasks[index].id) {
                                              return DownloadWidget(
                                                isar: widget.isar,
                                                task: tasks[index],
                                                downloadinfo: widget
                                                    .downloadlog.values.first,
                                              );
                                            } else {
                                              return DownloadWidget(
                                                isar: widget.isar,
                                                task: tasks[index],
                                                downloadinfo: const {},
                                              );
                                            }
                                          } else {
                                            return DownloadWidget(
                                              isar: widget.isar,
                                              task: tasks[index],
                                              downloadinfo: const {},
                                            );
                                          }
                                        });
                                  } else {
                                    return const Center(
                                        child: Text(
                                      "No Downloads Active",
                                      style: TextStyle(
                                          color: Appcolors.appPrimaryColor,
                                          fontWeight: FontWeight.w400),
                                    ));
                                  }
                                } else if (snapshot.hasError) {
                                  return const Center(
                                    child: Text(
                                      "Download Database Error! \n(if you see this it means Isar Database is not responding, relaunch the app)",
                                      style: TextStyle(
                                          color: Appcolors.appPrimaryColor),
                                    ),
                                  );
                                } else {
                                  return Offstage();
                                }
                                ;
                              },
                            ),
                            FutureBuilder(
                              future: widget.isar.downloadTasks
                                  .where(sort: Sort.desc)
                                  .anyId()
                                  .filter()
                                  .isCompletedEqualTo(true)
                                  .findAll(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  List<DownloadTask> tasks = snapshot.data!;
                                  if (tasks.isNotEmpty) {
                                    return ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: tasks.length,
                                        itemBuilder: (content, index) {
                                          if (widget.downloadlog.isNotEmpty) {
                                            if (widget.downloadlog.keys.first ==
                                                tasks[index].id) {
                                              return DownloadWidget(
                                                isar: widget.isar,
                                                task: tasks[index],
                                                downloadinfo: widget
                                                    .downloadlog.values.first,
                                              );
                                            } else {
                                              return DownloadWidget(
                                                isar: widget.isar,
                                                task: tasks[index],
                                                downloadinfo: const {},
                                              );
                                            }
                                          } else {
                                            return DownloadWidget(
                                              isar: widget.isar,
                                              task: tasks[index],
                                              downloadinfo: const {},
                                            );
                                          }
                                        });
                                  } else {
                                    return const Center(
                                        child: Text(
                                      "No completed downloads found",
                                      style: TextStyle(
                                          color: Appcolors.appPrimaryColor,
                                          fontWeight: FontWeight.w400),
                                    ));
                                  }
                                } else if (snapshot.hasError) {
                                  return const Center(
                                    child: Text(
                                      "Download Database Error! \n(if you see this it means Isar Database is not responding, relaunch the app)",
                                      style: TextStyle(
                                          color: Appcolors.appPrimaryColor),
                                    ),
                                  );
                                } else {
                                  return Offstage();
                                }
                                ;
                              },
                            ),
                            FutureBuilder(
                              future: widget.isar.downloadTasks
                                  .where()
                                  .filter()
                                  .isFailedEqualTo(true)
                                  .findAll(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  List<DownloadTask> tasks = snapshot.data!;
                                  if (tasks.isNotEmpty) {
                                    return ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: tasks.length,
                                        itemBuilder: (content, index) {
                                          if (widget.downloadlog.isNotEmpty) {
                                            if (widget.downloadlog.keys.first ==
                                                tasks[index].id) {
                                              return DownloadWidget(
                                                isar: widget.isar,
                                                task: tasks[index],
                                                downloadinfo: widget
                                                    .downloadlog.values.first,
                                              );
                                            } else {
                                              return DownloadWidget(
                                                isar: widget.isar,
                                                task: tasks[index],
                                                downloadinfo: const {},
                                              );
                                            }
                                          } else {
                                            return DownloadWidget(
                                              isar: widget.isar,
                                              task: tasks[index],
                                              downloadinfo: const {},
                                            );
                                          }
                                        });
                                  } else {
                                    return const Center(
                                        child: Text(
                                      "No Failed Downloads Found",
                                      style: TextStyle(
                                          color: Appcolors.appPrimaryColor,
                                          fontWeight: FontWeight.w400),
                                    ));
                                  }
                                } else if (snapshot.hasError) {
                                  return const Center(
                                    child: Text(
                                      "Download Database Error! \n(if you see this it means Isar Database is not responding, relaunch the app)",
                                      style: TextStyle(
                                          color: Appcolors.appPrimaryColor),
                                    ),
                                  );
                                } else {
                                  return Offstage();
                                }
                                ;
                              },
                            ),
                          ])))
                ],
              ),
            )));
  }
}

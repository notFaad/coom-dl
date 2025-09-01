import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../constant/appcolors.dart';

class DebugMonitorPage extends StatefulWidget {
  const DebugMonitorPage({Key? key}) : super(key: key);

  @override
  _DebugMonitorPageState createState() => _DebugMonitorPageState();
}

class _DebugMonitorPageState extends State<DebugMonitorPage> {
  List<Map<String, dynamic>> logs = [];
  Map<String, Map<String, dynamic>> activeThreads = {};
  int totalCompleted = 0;
  int activeThreadCount = 0;
  late ReceivePort logReceiver;
  late StreamSubscription logSubscription;
  bool isDebugEnabled = false;

  @override
  void initState() {
    super.initState();
    _initializeDebugMonitor();
    _checkDebugMode();
  }

  void _checkDebugMode() {
    // In the separate debug window, always enable debug mode
    setState(() {
      isDebugEnabled = true;
    });
  }

  void _initializeDebugMonitor() {
    // Register port for receiving debug logs
    logReceiver = ReceivePort();
    if (IsolateNameServer.lookupPortByName("debug_monitor") == null) {
      IsolateNameServer.registerPortWithName(
          logReceiver.sendPort, "debug_monitor");
    }

    logSubscription = logReceiver.listen((message) {
      if (mounted && message is Map<String, dynamic>) {
        setState(() {
          _processLogMessage(message);
        });
      }
    });
  }

  void _processLogMessage(Map<String, dynamic> message) {
    // Add to logs
    logs.insert(0, {
      ...message,
      'id': DateTime.now().millisecondsSinceEpoch,
    });

    // Keep only last 100 logs
    if (logs.length > 100) {
      logs.removeLast();
    }

    // Process thread information
    String? threadId = message['thread_id'];
    String status = message['status'] ?? 'UNKNOWN';

    if (threadId != null) {
      switch (status) {
        case 'DOWNLOADING':
          activeThreads[threadId] = {
            'thread_id': threadId,
            'status': 'DOWNLOADING',
            'filename': message['m']?.toString().split(': ').last ?? 'Unknown',
            'url': message['url'] ?? 'Unknown',
            'start_time': DateTime.now(),
            'file_index': message['file_index'] ?? 0,
          };
          break;
        case 'COMPLETED':
          activeThreads.remove(threadId);
          totalCompleted = message['total_completed'] ?? totalCompleted;
          break;
      }
    }

    activeThreadCount = message['active_threads'] ?? activeThreads.length;
  }

  Widget _buildThreadCard(String threadId, Map<String, dynamic> threadInfo) {
    Duration? runningTime;
    if (threadInfo['start_time'] != null) {
      runningTime = DateTime.now().difference(threadInfo['start_time']);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Appcolors.appAccentColor.withOpacity(0.3),
          width: 1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Appcolors.appSecondaryColor.withOpacity(0.2),
            Appcolors.appSecondaryColor.withOpacity(0.1),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  threadId,
                  style: TextStyle(
                    color: Appcolors.appTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                if (runningTime != null)
                  Text(
                    '${runningTime.inSeconds}s',
                    style: TextStyle(
                      color: Appcolors.appTextColor.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              threadInfo['filename'] ?? 'Unknown file',
              style: TextStyle(
                color: Appcolors.appTextColor.withOpacity(0.9),
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Index: ${threadInfo['file_index'] ?? 'N/A'}',
              style: TextStyle(
                color: Appcolors.appTextColor.withOpacity(0.6),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogEntry(Map<String, dynamic> log) {
    Color statusColor;
    IconData statusIcon;

    switch (log['status']) {
      case 'DOWNLOADING':
        statusColor = Colors.blue;
        statusIcon = Icons.download;
        break;
      case 'COMPLETED':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'ERROR':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Appcolors.appBackgroundColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
        border: BorderDirectional(
          start: BorderSide(
            color: statusColor,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            statusIcon,
            color: statusColor,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log['m'] ?? 'Unknown message',
                  style: TextStyle(
                    color: Appcolors.appTextColor,
                    fontSize: 12,
                  ),
                ),
                if (log['timestamp'] != null)
                  Text(
                    DateTime.parse(log['timestamp'])
                        .toLocal()
                        .toString()
                        .split('.')
                        .first,
                    style: TextStyle(
                      color: Appcolors.appTextColor.withOpacity(0.5),
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isDebugEnabled) {
      return Scaffold(
        backgroundColor: Appcolors.appBackgroundColor,
        appBar: AppBar(
          title: const Text('Debug Monitor'),
          backgroundColor: Appcolors.appBackgroundColor,
          foregroundColor: Appcolors.appTextColor,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bug_report_outlined,
                size: 64,
                color: Appcolors.appTextColor.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Debug Mode Disabled',
                style: TextStyle(
                  color: Appcolors.appTextColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enable debug mode in settings to monitor downloads',
                style: TextStyle(
                  color: Appcolors.appTextColor.withOpacity(0.7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Appcolors.appBackgroundColor,
      appBar: AppBar(
        title: const Text('Debug Monitor'),
        backgroundColor: Appcolors.appBackgroundColor,
        foregroundColor: Appcolors.appTextColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              setState(() {
                logs.clear();
              });
            },
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: Row(
        children: [
          // Left panel - Active threads
          Expanded(
            flex: 1,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: Appcolors.appAccentColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Appcolors.appSecondaryColor.withOpacity(0.1),
                      border: Border(
                        bottom: BorderSide(
                          color: Appcolors.appAccentColor.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Engine Status',
                          style: TextStyle(
                            color: Appcolors.appTextColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text(
                                  '$activeThreadCount',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Active',
                                  style: TextStyle(
                                    color:
                                        Appcolors.appTextColor.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Text(
                                  '$totalCompleted',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Completed',
                                  style: TextStyle(
                                    color:
                                        Appcolors.appTextColor.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: activeThreads.length,
                      itemBuilder: (context, index) {
                        String threadId = activeThreads.keys.elementAt(index);
                        Map<String, dynamic> threadInfo =
                            activeThreads[threadId]!;
                        return _buildThreadCard(threadId, threadInfo);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Right panel - Logs
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Appcolors.appSecondaryColor.withOpacity(0.1),
                    border: Border(
                      bottom: BorderSide(
                        color: Appcolors.appAccentColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Download Logs',
                        style: TextStyle(
                          color: Appcolors.appTextColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${logs.length} entries',
                        style: TextStyle(
                          color: Appcolors.appTextColor.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      return _buildLogEntry(logs[index]);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    logSubscription.cancel();
    logReceiver.close();
    IsolateNameServer.removePortNameMapping("debug_monitor");
    super.dispose();
  }
}

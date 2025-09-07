import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:isar/isar.dart';
import '../data/models/DlTask.dart';
import '../widgets/DownloadWidget.dart';

/// Test page to simulate various download error scenarios
class DownloadErrorTestPage extends StatefulWidget {
  final Isar isar;

  const DownloadErrorTestPage({Key? key, required this.isar}) : super(key: key);

  @override
  _DownloadErrorTestPageState createState() => _DownloadErrorTestPageState();
}

class _DownloadErrorTestPageState extends State<DownloadErrorTestPage> {
  List<DownloadTask> testTasks = [];

  @override
  void initState() {
    super.initState();
    _createTestTasks();
  }

  void _createTestTasks() {
    // Test Case 1: Network Error
    final networkErrorTask = DownloadTask()
      ..url = "https://invalid-domain-that-doesnt-exist.com/user/test"
      ..name = "Network Error Test"
      ..storagePath = "/tmp/test"
      ..isFailed = true
      ..isDownloading = false
      ..numFailed = 15
      ..numCompleted = 0
      ..totalNum = 15
      ..tag = "ERROR";

    // Test Case 2: Partial Failure
    final partialFailureTask = DownloadTask()
      ..url = "https://erome.com/a/test123"
      ..name = "Partial Failure Test"
      ..storagePath = "/tmp/test"
      ..isFailed = false
      ..isDownloading = false
      ..numFailed = 5
      ..numCompleted = 10
      ..totalNum = 15
      ..tag = "PARTIAL";

    // Test Case 3: Database Error
    final dbErrorTask = DownloadTask()
      ..url = "https://coomer.st/onlyfans/user/test"
      ..name = "Database Error Test"
      ..storagePath = "/tmp/test"
      ..isFailed = true
      ..isDownloading = false
      ..numFailed = 0
      ..numCompleted = 0
      ..totalNum = 0
      ..tag = "DB_ERROR";

    // Test Case 4: Connection Timeout
    final timeoutTask = DownloadTask()
      ..url = "https://very-slow-site.com/user/test"
      ..name = "Connection Timeout Test"
      ..storagePath = "/tmp/test"
      ..isFailed = true
      ..isDownloading = false
      ..numFailed = 8
      ..numCompleted = 2
      ..totalNum = 10
      ..tag = "TIMEOUT";

    // Test Case 5: Unauthorized Access
    final unauthorizedTask = DownloadTask()
      ..url = "https://private-site.com/user/test"
      ..name = "Unauthorized Access Test"
      ..storagePath = "/tmp/test"
      ..isFailed = true
      ..isDownloading = false
      ..numFailed = 3
      ..numCompleted = 0
      ..totalNum = 3
      ..tag = "401";

    testTasks = [
      networkErrorTask,
      partialFailureTask,
      dbErrorTask,
      timeoutTask,
      unauthorizedTask,
    ];
  }

  Map<String, dynamic> _generateErrorInfo(DownloadTask task) {
    return {
      "completed": task.numCompleted,
      "fail": task.numFailed,
      "total": task.totalNum ?? 0,
      "size": "0 MB",
      "percentage": task.numCompleted > 0
          ? "${((task.numCompleted / (task.totalNum ?? 1)) * 100).toStringAsFixed(1)}%"
          : "0%",
      "speed": "0 MB/s",
      "eta": task.isFailed == true ? "Failed" : "Unknown",
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('Download Error Testing'),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🧪 Error Handling Test Scenarios',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'These test cases simulate various error conditions in download cards:',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: testTasks.length,
                itemBuilder: (context, index) {
                  final task = testTasks[index];
                  final downloadInfo = _generateErrorInfo(task);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Test ${index + 1}: ${task.name}',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DownloadWidget(
                          task: task,
                          isar: widget.isar,
                          downloadinfo: downloadInfo,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showErrorSimulationDialog(),
              icon: const Icon(Icons.bug_report),
              label: const Text('Simulate Live Error'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorSimulationDialog() {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Simulate Download Error',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildErrorButton(
              'Network Connection Error',
              Icons.wifi_off,
              Colors.red,
              () => _simulateNetworkError(),
            ),
            _buildErrorButton(
              'File Permission Error',
              Icons.lock,
              Colors.orange,
              () => _simulatePermissionError(),
            ),
            _buildErrorButton(
              'Disk Space Error',
              Icons.storage,
              Colors.purple,
              () => _simulateDiskSpaceError(),
            ),
            _buildErrorButton(
              'Invalid URL Error',
              Icons.link_off,
              Colors.blue,
              () => _simulateInvalidUrlError(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorButton(
      String text, IconData icon, Color color, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            Get.back();
            onPressed();
          },
          icon: Icon(icon),
          label: Text(text),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }

  void _simulateNetworkError() {
    Get.showSnackbar(GetSnackBar(
      icon: const Icon(Icons.wifi_off, color: Colors.white),
      title: "Network Error Simulated",
      message: "Connection failed: Unable to reach server",
      backgroundColor: Colors.red[600]!,
      duration: const Duration(seconds: 3),
    ));
  }

  void _simulatePermissionError() {
    Get.showSnackbar(GetSnackBar(
      icon: const Icon(Icons.lock, color: Colors.white),
      title: "Permission Error Simulated",
      message: "Access denied: Cannot write to directory",
      backgroundColor: Colors.orange[600]!,
      duration: const Duration(seconds: 3),
    ));
  }

  void _simulateDiskSpaceError() {
    Get.showSnackbar(GetSnackBar(
      icon: const Icon(Icons.storage, color: Colors.white),
      title: "Disk Space Error Simulated",
      message: "Insufficient storage space available",
      backgroundColor: Colors.purple[600]!,
      duration: const Duration(seconds: 3),
    ));
  }

  void _simulateInvalidUrlError() {
    Get.showSnackbar(GetSnackBar(
      icon: const Icon(Icons.link_off, color: Colors.white),
      title: "Invalid URL Error Simulated",
      message: "URL format is invalid or unsupported",
      backgroundColor: Colors.blue[600]!,
      duration: const Duration(seconds: 3),
    ));
  }
}

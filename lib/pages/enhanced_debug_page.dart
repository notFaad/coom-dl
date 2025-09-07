import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:coom_dl/data/models/DlTask.dart';
import 'package:coom_dl/widgets/DownloadWidget.dart';
import 'package:coom_dl/utils/error_testing_utils.dart';
import 'package:coom_dl/services/developer_mode_service.dart';
import 'package:coom_dl/pages/performance_test_page.dart';
import 'package:isar/isar.dart';

/// Enhanced debug page with error testing and developer mode features
class EnhancedDebugPage extends StatefulWidget {
  final Isar isar;

  const EnhancedDebugPage({Key? key, required this.isar}) : super(key: key);

  @override
  State<EnhancedDebugPage> createState() => _EnhancedDebugPageState();
}

class _EnhancedDebugPageState extends State<EnhancedDebugPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final DeveloperModeService _devService = Get.put(DeveloperModeService());
  List<DownloadTask> testTasks = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _generateTestTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _generateTestTasks() {
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
      ..numFailed = 8
      ..numCompleted = 2
      ..totalNum = 10
      ..tag = "DB_ERROR";

    // Test Case 4: Timeout Error
    final timeoutTask = DownloadTask()
      ..url = "https://fapello.com/user/timeout-test"
      ..name = "Timeout Error Test"
      ..storagePath = "/tmp/test"
      ..isFailed = true
      ..isDownloading = false
      ..numFailed = 20
      ..numCompleted = 0
      ..totalNum = 20
      ..tag = "TIMEOUT";

    // Test Case 5: Authorization Error
    final unauthorizedTask = DownloadTask()
      ..url = "https://onlyfans.com/user/private"
      ..name = "Authorization Error Test"
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
      "size": 0, // Use integer for bytes
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
        title: const Text('Debug & Performance Suite'),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        actions: [
          // Secret tap area to enable developer mode
          GestureDetector(
            onTap: () => _devService.handleSecretTap(),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Obx(() => Icon(
                    _devService.isDeveloperMode
                        ? Icons.developer_mode
                        : Icons.help_outline,
                    color: _devService.isDeveloperMode
                        ? Colors.green
                        : Colors.grey,
                  )),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(
              icon: Icon(Icons.bug_report),
              text: 'Error Testing',
            ),
            Obx(() => Tab(
                  icon: Icon(
                      _devService.isDeveloperMode ? Icons.speed : Icons.lock),
                  text: 'Performance',
                )),
            Obx(() => Tab(
                  icon: Icon(_devService.isDeveloperMode
                      ? Icons.developer_board
                      : Icons.lock),
                  text: 'Developer',
                )),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildErrorTestingTab(),
          Obx(() => _devService.isDeveloperMode
              ? PerformanceTestPage(isar: widget.isar)
              : _buildLockedTab('Performance Testing',
                  'Advanced performance testing and metrics')),
          Obx(() => _devService.isDeveloperMode
              ? _buildDeveloperTab()
              : _buildLockedTab('Developer Mode',
                  'Advanced debugging and development tools')),
        ],
      ),
    );
  }

  Widget _buildErrorTestingTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.science, color: Colors.green),
              SizedBox(width: 8),
              Text(
                'Error Handling Test Scenarios',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'These test cases simulate various error conditions in download cards:',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _createRealErrorTasks(),
            icon: const Icon(Icons.science),
            label: const Text('Create Real Error Tasks'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[600],
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _cleanupErrorTasks(),
            icon: const Icon(Icons.cleaning_services),
            label: const Text('Cleanup Test Tasks'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedTab(String title, String description) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[700]!),
            ),
            child: const Column(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(height: 8),
                Text(
                  'Tap the ? icon in the top-right corner 7 times to unlock developer mode',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeveloperTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.developer_board, color: Colors.green),
              SizedBox(width: 8),
              Text(
                'Developer Controls',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Developer Mode Status
          Card(
            color: const Color(0xFF1A1A1A),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.settings, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        'Developer Mode Status',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green[700],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'ENABLED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Advanced debugging features are now available. Use these tools carefully as they may affect app performance.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Quick Actions
          Card(
            color: const Color(0xFF1A1A1A),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.flash_on, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(
                        'Quick Actions',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _devService.togglePerformanceTesting(),
                        icon: Obx(() => Icon(
                            _devService.isPerformanceTestingEnabled
                                ? Icons.stop
                                : Icons.play_arrow)),
                        label: Obx(() => Text(
                            _devService.isPerformanceTestingEnabled
                                ? 'Disable Testing'
                                : 'Enable Testing')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[600],
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _devService.resetMetrics(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset Metrics'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _devService.disableDeveloperMode(),
                        icon: const Icon(Icons.lock),
                        label: const Text('Lock Developer Mode'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Live Metrics Preview
          Expanded(
            child: Card(
              color: const Color(0xFF1A1A1A),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.analytics, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Live Performance Overview',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Obx(() {
                        final stats = _devService.getPerformanceStats();
                        return GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 2,
                          children: [
                            _buildMetricCard(
                                'Active Downloads',
                                '${stats['active_downloads']}',
                                Icons.download,
                                Colors.orange),
                            _buildMetricCard(
                                'Success Rate',
                                '${stats['success_rate']}%',
                                Icons.check_circle,
                                Colors.green),
                            _buildMetricCard(
                                'Memory Usage',
                                '${stats['memory_usage_mb']} MB',
                                Icons.memory,
                                Colors.purple),
                            _buildMetricCard(
                                'Error Rate',
                                '${stats['error_injection_rate']}%',
                                Icons.error,
                                Colors.red),
                          ],
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showErrorSimulationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Simulate Download Error',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will simulate a live error on a running download task. Continue?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ErrorTestingUtils.simulateDownloadError(
                errorType: 'network_error',
                isar: widget.isar,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600]),
            child: const Text('Simulate Error'),
          ),
        ],
      ),
    );
  }

  Future<void> _createRealErrorTasks() async {
    await ErrorTestingUtils.createAllErrorScenarios(isar: widget.isar);
    Get.snackbar(
      '✅ Error Tasks Created',
      'Check your downloads page to see the test error tasks.',
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _cleanupErrorTasks() async {
    await ErrorTestingUtils.cleanupErrorTests(isar: widget.isar);
    Get.snackbar(
      '🧹 Cleanup Complete',
      'All test error tasks have been removed.',
      duration: const Duration(seconds: 2),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:coom_dl/services/developer_mode_service.dart';
import 'package:coom_dl/utils/error_testing_utils.dart';
import 'package:isar/isar.dart';

class PerformanceTestPage extends StatefulWidget {
  final Isar isar;

  const PerformanceTestPage({Key? key, required this.isar}) : super(key: key);

  @override
  State<PerformanceTestPage> createState() => _PerformanceTestPageState();
}

class _PerformanceTestPageState extends State<PerformanceTestPage> {
  final DeveloperModeService _devService = Get.find<DeveloperModeService>();
  bool _isStressTesting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('Performance Testing Suite'),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_devService.isPerformanceTestingEnabled
                ? Icons.bug_report
                : Icons.bug_report_outlined),
            onPressed: () => _devService.togglePerformanceTesting(),
            tooltip: 'Toggle Performance Testing',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Performance Metrics Card
            _buildMetricsCard(),
            const SizedBox(height: 16),

            // Control Panel
            _buildControlPanel(),
            const SizedBox(height: 16),

            // Test Actions
            _buildTestActions(),
            const SizedBox(height: 16),

            // Live Performance Chart
            Expanded(child: _buildPerformanceChart()),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsCard() {
    return Obx(() {
      final stats = _devService.getPerformanceStats();

      return Card(
        color: const Color(0xFF1A1A1A),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.analytics, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text(
                    'Live Performance Metrics',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (_devService.isPerformanceTestingEnabled)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[700],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'TESTING ACTIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricItem(
                      'Active Downloads',
                      '${stats['active_downloads']}',
                      Colors.orange,
                      Icons.download,
                    ),
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      'Success Rate',
                      '${stats['success_rate']}%',
                      Colors.green,
                      Icons.check_circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricItem(
                      'Memory Usage',
                      '${stats['memory_usage_mb']} MB',
                      Colors.purple,
                      Icons.memory,
                    ),
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      'Error Rate',
                      '${stats['error_injection_rate']}%',
                      Colors.red,
                      Icons.error,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildMetricItem(
      String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
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
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Card(
      color: const Color(0xFF1A1A1A),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.tune, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Performance Controls',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Error Injection Rate Slider
            Obx(() => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Error Injection Rate: ${(_devService.errorInjectionRate * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.white),
                    ),
                    Slider(
                      value: _devService.errorInjectionRate,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      activeColor: Colors.red,
                      onChanged: (value) =>
                          _devService.setErrorInjectionRate(value),
                    ),
                  ],
                )),

            const SizedBox(height: 8),

            // Max Concurrent Downloads
            Obx(() => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Max Concurrent Downloads: ${_devService.maxConcurrentDownloads}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    Slider(
                      value: _devService.maxConcurrentDownloads.toDouble(),
                      min: 1,
                      max: 50,
                      divisions: 49,
                      activeColor: Colors.orange,
                      onChanged: (value) =>
                          _devService.setMaxConcurrentDownloads(value.toInt()),
                    ),
                  ],
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildTestActions() {
    return Card(
      color: const Color(0xFF1A1A1A),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.science, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Stress Testing',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed:
                      _isStressTesting ? null : () => _startStressTest('light'),
                  icon: const Icon(Icons.speed),
                  label: const Text('Light Load (10 tasks)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isStressTesting
                      ? null
                      : () => _startStressTest('medium'),
                  icon: const Icon(Icons.flash_on),
                  label: const Text('Medium Load (25 tasks)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[600],
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed:
                      _isStressTesting ? null : () => _startStressTest('heavy'),
                  icon: const Icon(Icons.warning),
                  label: const Text('Heavy Load (50 tasks)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _devService.resetMetrics(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset Metrics'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[600],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            if (_isStressTesting)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.yellow[900]?.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.yellow),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.yellow),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Stress test running... Monitor performance metrics above.',
                        style: TextStyle(color: Colors.yellow),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceChart() {
    return Card(
      color: const Color(0xFF1A1A1A),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.timeline, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Performance Timeline',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Placeholder for performance chart
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0A0A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.show_chart, size: 48, color: Colors.grey[600]),
                      const SizedBox(height: 8),
                      Text(
                        'Real-time performance chart\nwould be displayed here',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Obx(() => Text(
                            'Active: ${_devService.activeDownloads} | '
                            'Success: ${_devService.totalSuccesses} | '
                            'Errors: ${_devService.totalErrors}',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          )),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startStressTest(String intensity) async {
    setState(() {
      _isStressTesting = true;
    });

    int taskCount;
    switch (intensity) {
      case 'light':
        taskCount = 10;
        break;
      case 'medium':
        taskCount = 25;
        break;
      case 'heavy':
        taskCount = 50;
        break;
      default:
        taskCount = 10;
    }

    Get.snackbar(
      '🧪 Stress Test',
      'Starting $intensity stress test with $taskCount download tasks...',
      duration: const Duration(seconds: 2),
    );

    // Create multiple test downloads with some being real errors
    for (int i = 0; i < taskCount; i++) {
      await Future.delayed(const Duration(milliseconds: 100));

      // Record download started for metrics
      _devService.recordDownloadStarted();

      // Simulate some finishing after a delay
      Future.delayed(Duration(seconds: 2 + (i % 5)), () {
        if (_devService.shouldInjectError()) {
          _devService.recordDownloadError();
        } else {
          _devService.recordDownloadSuccess();
        }
      });
    }

    // Also create some real failed tasks in the database
    await ErrorTestingUtils.createAllErrorScenarios(isar: widget.isar);

    // End stress test after a delay
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _isStressTesting = false;
        });

        Get.snackbar(
          '✅ Stress Test Complete',
          'Check performance metrics for results.',
          duration: const Duration(seconds: 2),
        );
      }
    });
  }
}

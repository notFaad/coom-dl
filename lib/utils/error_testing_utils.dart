import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../data/models/DlTask.dart';

/// Quick error testing utilities
class ErrorTestingUtils {
  /// Simulate various download errors for testing
  static void simulateDownloadError({
    required String errorType,
    required Isar isar,
  }) {
    switch (errorType) {
      case 'network':
        _showErrorSnackbar(
          'Network Error Simulated',
          'Connection failed: Unable to reach server',
          Colors.red[600]!,
          Icons.wifi_off,
        );
        break;

      case 'permission':
        _showErrorSnackbar(
          'Permission Error Simulated',
          'Access denied: Cannot write to directory',
          Colors.orange[600]!,
          Icons.lock,
        );
        break;

      case 'disk_space':
        _showErrorSnackbar(
          'Disk Space Error Simulated',
          'Insufficient storage space available',
          Colors.purple[600]!,
          Icons.storage,
        );
        break;

      case 'invalid_url':
        _showErrorSnackbar(
          'Invalid URL Error Simulated',
          'URL format is invalid or unsupported',
          Colors.blue[600]!,
          Icons.link_off,
        );
        break;

      case 'timeout':
        _showErrorSnackbar(
          'Connection Timeout Simulated',
          'Request timed out after 30 seconds',
          Colors.yellow[700]!,
          Icons.access_time,
        );
        break;

      case 'auth_failed':
        _showErrorSnackbar(
          'Authentication Failed',
          'Invalid credentials or session expired',
          Colors.pink[600]!,
          Icons.security,
        );
        break;

      default:
        _showErrorSnackbar(
          'Unknown Error Simulated',
          'An unexpected error occurred',
          Colors.grey[600]!,
          Icons.error,
        );
    }
  }

  /// Create a failed download task for testing
  static Future<DownloadTask> createFailedTask({
    required Isar isar,
    required String url,
    required String errorType,
  }) async {
    final task = DownloadTask()
      ..url = url
      ..name = "Error Test: $errorType"
      ..storagePath = "/tmp/test_errors"
      ..isFailed = true
      ..isDownloading = false
      ..numFailed = _getFailCountForErrorType(errorType)
      ..numCompleted = _getSuccessCountForErrorType(errorType)
      ..totalNum = _getFailCountForErrorType(errorType) +
          _getSuccessCountForErrorType(errorType)
      ..tag = errorType.toUpperCase();

    // Store in database for real testing
    await isar.writeTxn(() async {
      await isar.downloadTasks.put(task);
    });

    return task;
  }

  /// Create multiple error scenarios at once
  static Future<List<DownloadTask>> createAllErrorScenarios({
    required Isar isar,
  }) async {
    final tasks = <DownloadTask>[];

    final errorTypes = [
      'network',
      'permission',
      'disk_space',
      'invalid_url',
      'timeout',
      'auth_failed',
    ];

    for (final errorType in errorTypes) {
      final task = await createFailedTask(
        isar: isar,
        url: _getTestUrlForErrorType(errorType),
        errorType: errorType,
      );
      tasks.add(task);
    }

    _showErrorSnackbar(
      'Error Test Suite Created',
      'Created ${tasks.length} test scenarios for error handling',
      Colors.green[600]!,
      Icons.science,
    );

    return tasks;
  }

  /// Clean up all test error tasks
  static Future<void> cleanupErrorTests({required Isar isar}) async {
    await isar.writeTxn(() async {
      final testTasks = await isar.downloadTasks
          .filter()
          .nameStartsWith("Error Test:")
          .findAll();

      final ids = testTasks.map((task) => task.id).toList();
      await isar.downloadTasks.deleteAll(ids);
    });

    _showErrorSnackbar(
      'Test Cleanup Complete',
      'All error test scenarios have been removed',
      Colors.blue[600]!,
      Icons.cleaning_services,
    );
  }

  // Helper methods
  static void _showErrorSnackbar(
      String title, String message, Color color, IconData icon) {
    Get.showSnackbar(GetSnackBar(
      icon: Icon(icon, color: Colors.white),
      title: title,
      message: message,
      backgroundColor: color,
      duration: const Duration(seconds: 4),
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(16),
      borderRadius: 8,
    ));
  }

  static int _getFailCountForErrorType(String errorType) {
    switch (errorType) {
      case 'network':
        return 15;
      case 'permission':
        return 8;
      case 'disk_space':
        return 12;
      case 'invalid_url':
        return 3;
      case 'timeout':
        return 7;
      case 'auth_failed':
        return 5;
      default:
        return 10;
    }
  }

  static int _getSuccessCountForErrorType(String errorType) {
    switch (errorType) {
      case 'network':
        return 0; // Total failure
      case 'permission':
        return 2; // Partial success
      case 'disk_space':
        return 0; // Total failure
      case 'invalid_url':
        return 0; // Total failure
      case 'timeout':
        return 3; // Partial success
      case 'auth_failed':
        return 0; // Total failure
      default:
        return 1;
    }
  }

  static String _getTestUrlForErrorType(String errorType) {
    switch (errorType) {
      case 'network':
        return 'https://nonexistent-domain-12345.com/user/test';
      case 'permission':
        return 'https://erome.com/a/permission-test';
      case 'disk_space':
        return 'https://coomer.st/onlyfans/user/disk-test';
      case 'invalid_url':
        return 'invalid-url-format';
      case 'timeout':
        return 'https://httpstat.us/504';
      case 'auth_failed':
        return 'https://private-site.com/user/test';
      default:
        return 'https://test-error.com/unknown';
    }
  }
}

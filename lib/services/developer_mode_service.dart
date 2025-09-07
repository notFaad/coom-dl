import 'package:get/get.dart';

/// Service to manage developer mode features and settings
class DeveloperModeService extends GetxController {
  static DeveloperModeService get instance => Get.find<DeveloperModeService>();

  // Developer mode state
  final RxBool _isDeveloperMode = false.obs;
  bool get isDeveloperMode => _isDeveloperMode.value;

  // Performance testing settings
  final RxBool _isPerformanceTestingEnabled = false.obs;
  bool get isPerformanceTestingEnabled => _isPerformanceTestingEnabled.value;

  final RxDouble _errorInjectionRate = 0.0.obs;
  double get errorInjectionRate => _errorInjectionRate.value;

  final RxInt _maxConcurrentDownloads = 10.obs;
  int get maxConcurrentDownloads => _maxConcurrentDownloads.value;

  // Performance metrics
  final RxInt _activeDownloads = 0.obs;
  int get activeDownloads => _activeDownloads.value;

  final RxDouble _memoryUsageMB = 0.0.obs;
  double get memoryUsageMB => _memoryUsageMB.value;

  final RxInt _totalErrors = 0.obs;
  int get totalErrors => _totalErrors.value;

  final RxInt _totalSuccesses = 0.obs;
  int get totalSuccesses => _totalSuccesses.value;

  // Secret tap counter for enabling developer mode
  final RxInt _secretTapCount = 0.obs;
  static const int _requiredTaps = 7;

  @override
  void onInit() {
    super.onInit();
    _startPerformanceMonitoring();
  }

  /// Handle secret tap to enable developer mode
  void handleSecretTap() {
    if (_isDeveloperMode.value) return;

    _secretTapCount.value++;

    if (_secretTapCount.value >= _requiredTaps) {
      enableDeveloperMode();
      Get.snackbar(
        '🚀 Developer Mode',
        'Developer features unlocked! Check debug tab for advanced tools.',
        duration: const Duration(seconds: 3),
      );
    } else {
      final remaining = _requiredTaps - _secretTapCount.value;
      if (remaining <= 3) {
        Get.snackbar(
          '🔓 Secret Mode',
          '$remaining more taps to unlock developer features...',
          duration: const Duration(seconds: 1),
        );
      }
    }
  }

  /// Enable developer mode
  void enableDeveloperMode() {
    _isDeveloperMode.value = true;
  }

  /// Disable developer mode
  void disableDeveloperMode() {
    _isDeveloperMode.value = false;
    _isPerformanceTestingEnabled.value = false;
    _errorInjectionRate.value = 0.0;
  }

  /// Toggle performance testing
  void togglePerformanceTesting() {
    _isPerformanceTestingEnabled.value = !_isPerformanceTestingEnabled.value;

    if (_isPerformanceTestingEnabled.value) {
      Get.snackbar(
        '⚡ Performance Testing',
        'Performance testing enabled. Downloads may behave unexpectedly.',
        duration: const Duration(seconds: 2),
      );
    }
  }

  /// Set error injection rate (0.0 to 1.0)
  void setErrorInjectionRate(double rate) {
    _errorInjectionRate.value = rate.clamp(0.0, 1.0);
  }

  /// Set max concurrent downloads for testing
  void setMaxConcurrentDownloads(int max) {
    _maxConcurrentDownloads.value = max.clamp(1, 100);
  }

  /// Check if an error should be injected
  bool shouldInjectError() {
    if (!_isPerformanceTestingEnabled.value ||
        _errorInjectionRate.value == 0.0) {
      return false;
    }

    final random = DateTime.now().millisecondsSinceEpoch % 100;
    return random < (_errorInjectionRate.value * 100);
  }

  /// Record download started
  void recordDownloadStarted() {
    _activeDownloads.value++;
  }

  /// Record download completed successfully
  void recordDownloadSuccess() {
    _activeDownloads.value--;
    _totalSuccesses.value++;
  }

  /// Record download failed
  void recordDownloadError() {
    _activeDownloads.value--;
    _totalErrors.value++;
  }

  /// Reset performance metrics
  void resetMetrics() {
    _totalErrors.value = 0;
    _totalSuccesses.value = 0;
    _activeDownloads.value = 0;
  }

  /// Start monitoring performance metrics
  void _startPerformanceMonitoring() {
    // Update memory usage every 2 seconds
    Stream.periodic(const Duration(seconds: 2)).listen((_) {
      _updateMemoryUsage();
    });
  }

  /// Update memory usage (simplified estimation)
  void _updateMemoryUsage() {
    // This is a simplified estimation - in a real app you'd use platform channels
    // to get actual memory usage from the system
    final baseMemory = 50.0; // Base app memory
    final downloadMemory =
        _activeDownloads.value * 2.5; // ~2.5MB per active download
    _memoryUsageMB.value = baseMemory + downloadMemory;
  }

  /// Get performance summary
  Map<String, dynamic> getPerformanceStats() {
    final total = _totalSuccesses.value + _totalErrors.value;
    final successRate = total > 0 ? (_totalSuccesses.value / total * 100) : 0.0;

    return {
      'active_downloads': _activeDownloads.value,
      'total_completed': _totalSuccesses.value,
      'total_errors': _totalErrors.value,
      'success_rate': successRate.toStringAsFixed(1),
      'memory_usage_mb': _memoryUsageMB.value.toStringAsFixed(1),
      'error_injection_rate':
          (_errorInjectionRate.value * 100).toStringAsFixed(1),
    };
  }
}

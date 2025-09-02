import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../constant/appcolors.dart';

class MiniPerformanceChart extends StatefulWidget {
  final Map<String, dynamic> downloadInfo;
  final bool isDownloading;
  final int downloadedBytes;

  const MiniPerformanceChart({
    Key? key,
    required this.downloadInfo,
    required this.isDownloading,
    required this.downloadedBytes,
  }) : super(key: key);

  @override
  State<MiniPerformanceChart> createState() => _MiniPerformanceChartState();
}

class _MiniPerformanceChartState extends State<MiniPerformanceChart> {
  Timer? _updateTimer;
  double _currentSpeed = 0.0;
  int _lastBytes = 0;
  DateTime _lastUpdateTime = DateTime.now();
  int _lastRetryCount = 0;
  bool _showRetryIndicator = false;

  @override
  void initState() {
    super.initState();
    _lastBytes =
        (widget.downloadInfo["size"] as int?) ?? widget.downloadedBytes;
    _lastUpdateTime = DateTime.now();

    if (widget.isDownloading) {
      _startMetricsCollection();
    }
  }

  @override
  void didUpdateWidget(MiniPerformanceChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update speed when download info changes
    if (widget.downloadInfo != oldWidget.downloadInfo) {
      _updateSpeed();
    }

    if (widget.isDownloading && !oldWidget.isDownloading) {
      _startMetricsCollection();
    } else if (!widget.isDownloading && oldWidget.isDownloading) {
      _stopMetricsCollection();
    }
  }

  void _startMetricsCollection() {
    _updateTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        _updateSpeed();
      }
    });
  }

  void _stopMetricsCollection() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  void _updateSpeed() {
    final now = DateTime.now();
    final timeDiff = now.difference(_lastUpdateTime).inMilliseconds;

    if (timeDiff > 100) {
      // Only update if at least 100ms have passed
      // Get current bytes from download info instead of widget.downloadedBytes
      final currentBytes =
          (widget.downloadInfo["size"] as int?) ?? widget.downloadedBytes;
      final bytesDiff = currentBytes - _lastBytes;
      final speedBytesPerSecond = (bytesDiff * 1000) / timeDiff;

      // Check for retry events
      final currentRetryCount = widget.downloadInfo["retries"] ?? 0;
      final retryIndicator = currentRetryCount > _lastRetryCount;

      setState(() {
        // Only update speed if there's meaningful data transfer
        if (bytesDiff > 0) {
          _currentSpeed = max(0.0, speedBytesPerSecond);
        } else if (timeDiff > 2000) {
          // If no data transfer for 2 seconds, reset speed to 0
          _currentSpeed = 0.0;
        }
        _lastBytes = currentBytes;
        _lastUpdateTime = now;
        _lastRetryCount = currentRetryCount;
        _showRetryIndicator = retryIndicator;
      });

      // Auto-hide retry indicator after 2 seconds
      if (retryIndicator) {
        Timer(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _showRetryIndicator = false;
            });
          }
        });
      }
    }
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '${bytesPerSecond.toInt()}B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)}K/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)}M/s';
    }
  }

  Color _getSpeedColor() {
    final speedMBps = _currentSpeed / (1024 * 1024);
    if (speedMBps > 5) return Colors.green;
    if (speedMBps > 1) return Colors.orange;
    return Colors.red;
  }

  @override
  void dispose() {
    _stopMetricsCollection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final retryCount = widget.downloadInfo["retries"] ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Speed text with retry indicator
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatSpeed(_currentSpeed),
              style: TextStyle(
                color: _getSpeedColor(),
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_showRetryIndicator || retryCount > 0) ...[
              const SizedBox(width: 2),
              Icon(
                Icons.refresh,
                size: 8,
                color: _showRetryIndicator ? Colors.orange : Colors.grey,
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        // Mini bandwidth bar with retry color overlay
        Container(
          width: 40,
          height: 2,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(1),
            color: Appcolors.appAccentColor.withOpacity(0.2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(1),
            child: LinearProgressIndicator(
              value: _currentSpeed > 0
                  ? min(_currentSpeed / (10 * 1024 * 1024), 1.0)
                  : 0.0,
              backgroundColor: Colors.transparent,
              color: _showRetryIndicator ? Colors.orange : _getSpeedColor(),
            ),
          ),
        ),
      ],
    );
  }
}

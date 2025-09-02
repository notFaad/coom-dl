import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../constant/appcolors.dart';

class PerformanceMetrics extends StatefulWidget {
  final Map<String, dynamic> downloadInfo;
  final bool isDownloading;
  final int totalFiles;
  final int downloadedBytes;

  const PerformanceMetrics({
    Key? key,
    required this.downloadInfo,
    required this.isDownloading,
    required this.totalFiles,
    required this.downloadedBytes,
  }) : super(key: key);

  @override
  State<PerformanceMetrics> createState() => _PerformanceMetricsState();
}

class _PerformanceMetricsState extends State<PerformanceMetrics> {
  Timer? _updateTimer;
  double _currentSpeed = 0.0;
  int _lastBytes = 0;
  DateTime _lastUpdateTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _lastBytes = widget.downloadedBytes;
    _lastUpdateTime = DateTime.now();

    if (widget.isDownloading) {
      _startMetricsCollection();
    }
  }

  @override
  void didUpdateWidget(PerformanceMetrics oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isDownloading && !oldWidget.isDownloading) {
      _startMetricsCollection();
    } else if (!widget.isDownloading && oldWidget.isDownloading) {
      _stopMetricsCollection();
    }

    if (widget.isDownloading) {
      _updateSpeed();
    }
  }

  void _startMetricsCollection() {
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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

    if (timeDiff > 0) {
      final bytesDiff = widget.downloadedBytes - _lastBytes;
      final speedBytesPerSecond = (bytesDiff * 1000) / timeDiff;

      setState(() {
        _currentSpeed = speedBytesPerSecond;
        _lastBytes = widget.downloadedBytes;
        _lastUpdateTime = now;
      });
    }
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '${bytesPerSecond.toInt()} B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
  }

  String _getETA() {
    if (!widget.isDownloading || _currentSpeed <= 0) return '--';

    final totalBytes = (widget.downloadInfo['size'] ?? 0) as int;
    final remainingBytes = totalBytes - widget.downloadedBytes;

    if (remainingBytes <= 0) return '00:00';

    final secondsRemaining = remainingBytes / _currentSpeed;
    final minutes = (secondsRemaining / 60).floor();
    final seconds = (secondsRemaining % 60).floor();

    if (minutes > 99) return '99:59';
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _stopMetricsCollection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isDownloading) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      height: 8, // Reduced from 12 to 8
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Speed
          Text(
            _formatSpeed(_currentSpeed),
            style: TextStyle(
              color: _getSpeedColor(),
              fontSize: 7,
              fontWeight: FontWeight.w500,
            ),
          ),
          // Bandwidth bar in center
          Expanded(
            child: Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(0.5),
                color: Appcolors.appAccentColor.withOpacity(0.1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(0.5),
                child: LinearProgressIndicator(
                  value: _currentSpeed > 0
                      ? min(_currentSpeed / (10 * 1024 * 1024), 1.0)
                      : 0.0,
                  backgroundColor: Colors.transparent,
                  color: _getSpeedColor(),
                ),
              ),
            ),
          ),
          // ETA
          Text(
            _getETA(),
            style: TextStyle(
              color: Appcolors.appPrimaryColor,
              fontSize: 7,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getSpeedColor() {
    final speedMBps = _currentSpeed / (1024 * 1024);
    if (speedMBps > 5) return Colors.green;
    if (speedMBps > 1) return Colors.orange;
    return Colors.red;
  }
}

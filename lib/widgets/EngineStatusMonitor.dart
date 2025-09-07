import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../constant/appcolors.dart';
import '../utils/FileSizeConverter.dart';

class EngineStatusMonitor extends StatefulWidget {
  final Map<String, dynamic> engineStats;
  final bool isActive;
  final String engineName;
  final List<Map<String, dynamic>>? recentLogs;

  const EngineStatusMonitor({
    Key? key,
    required this.engineStats,
    required this.isActive,
    required this.engineName,
    this.recentLogs,
  }) : super(key: key);

  @override
  State<EngineStatusMonitor> createState() => _EngineStatusMonitorState();
}

class _EngineStatusMonitorState extends State<EngineStatusMonitor>
    with TickerProviderStateMixin {
  late AnimationController _statusController;
  late AnimationController _metricsController;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _statusController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _metricsController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    if (widget.isActive) {
      _statusController.repeat();
      _metricsController.forward();
    }

    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.isActive) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(EngineStatusMonitor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _statusController.repeat();
        _metricsController.forward();
      } else {
        _statusController.stop();
        _metricsController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _statusController.dispose();
    _metricsController.dispose();
    _updateTimer?.cancel();
    super.dispose();
  }

  Widget _buildEngineHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.isActive
                ? Colors.green[400]!.withOpacity(0.1)
                : Colors.grey[400]!.withOpacity(0.1),
            widget.isActive
                ? Colors.green[600]!.withOpacity(0.05)
                : Colors.grey[600]!.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: widget.isActive
              ? Colors.green[400]!.withOpacity(0.2)
              : Colors.grey[400]!.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Engine status indicator
          AnimatedBuilder(
            animation: _statusController,
            builder: (context, child) {
              return Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isActive
                      ? Colors.green[400]!.withOpacity(
                          0.8 + (sin(_statusController.value * 2 * pi) * 0.2))
                      : Colors.grey[400],
                  boxShadow: widget.isActive
                      ? [
                          BoxShadow(
                            color: Colors.green[400]!.withOpacity(0.3),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ]
                      : [],
                ),
              );
            },
          ),
          const SizedBox(width: 12),

          // Engine name and status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.engineName,
                  style: TextStyle(
                    color: Appcolors.appPrimaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.isActive ? 'ACTIVE' : 'IDLE',
                  style: TextStyle(
                    color:
                        widget.isActive ? Colors.green[400] : Colors.grey[400],
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),

          // Quick stats
          if (widget.isActive && widget.engineStats['speed'] != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.blue[400]!.withOpacity(0.1),
                border: Border.all(
                  color: Colors.blue[400]!.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Text(
                '${_formatSpeed(widget.engineStats['speed'])}',
                style: TextStyle(
                  color: Colors.blue[400],
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    if (!widget.isActive) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _metricsController,
      builder: (context, child) {
        return Transform.scale(
          scale: _metricsController.value,
          child: Opacity(
            opacity: _metricsController.value,
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                childAspectRatio: 2.5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  _buildMetricCard(
                    'Active Threads',
                    '${widget.engineStats['activeThreads'] ?? 0}',
                    Icons.settings,
                    Colors.blue[400]!,
                  ),
                  _buildMetricCard(
                    'Queue Size',
                    '${widget.engineStats['queueSize'] ?? 0}',
                    Icons.queue,
                    Colors.orange[400]!,
                  ),
                  _buildMetricCard(
                    'Success Rate',
                    '${_calculateSuccessRate()}%',
                    Icons.trending_up,
                    Colors.green[400]!,
                  ),
                  _buildMetricCard(
                    'Downloaded',
                    FileSizeConverter.getFileSizeString(
                      bytes: widget.engineStats['downloadedBytes'] ?? 0,
                    ),
                    Icons.download_done,
                    Colors.cyan[400]!,
                  ),
                  _buildMetricCard(
                    'Errors',
                    '${widget.engineStats['errors'] ?? 0}',
                    Icons.error_outline,
                    Colors.red[400]!,
                  ),
                  _buildMetricCard(
                    'Uptime',
                    _formatUptime(widget.engineStats['uptime'] ?? 0),
                    Icons.timer,
                    Colors.purple[400]!,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withOpacity(0.1),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(
              color: Appcolors.appPrimaryColor.withOpacity(0.7),
              fontSize: 9,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    if (widget.recentLogs == null || widget.recentLogs!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Appcolors.appAccentColor.withOpacity(0.05),
        border: Border.all(
          color: Appcolors.appAccentColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.history,
                color: Appcolors.appPrimaryColor,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Recent Activity',
                style: TextStyle(
                  color: Appcolors.appPrimaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...widget.recentLogs!.take(3).map((log) => _buildLogEntry(log)),
        ],
      ),
    );
  }

  Widget _buildLogEntry(Map<String, dynamic> log) {
    final status = log['status'] ?? 'unknown';
    Color statusColor;
    IconData statusIcon;

    switch (status.toLowerCase()) {
      case 'ok':
      case 'success':
        statusColor = Colors.green[400]!;
        statusIcon = Icons.check_circle;
        break;
      case 'fail':
      case 'error':
        statusColor = Colors.red[400]!;
        statusIcon = Icons.error;
        break;
      case 'retry':
        statusColor = Colors.orange[400]!;
        statusIcon = Icons.refresh;
        break;
      case 'skip':
        statusColor = Colors.blue[400]!;
        statusIcon = Icons.skip_next;
        break;
      default:
        statusColor = Colors.grey[400]!;
        statusIcon = Icons.info;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 12),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              log['message'] ?? 'Unknown activity',
              style: TextStyle(
                color: Appcolors.appPrimaryColor.withOpacity(0.8),
                fontSize: 10,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          Text(
            _formatTime(log['timestamp']),
            style: TextStyle(
              color: Appcolors.appPrimaryColor.withOpacity(0.5),
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  String _formatSpeed(dynamic speed) {
    if (speed == null) return '0 B/s';
    final bytes = speed is int ? speed : (speed as double).toInt();
    return '${FileSizeConverter.getFileSizeString(bytes: bytes)}/s';
  }

  String _calculateSuccessRate() {
    final ok = widget.engineStats['ok'] ?? 0;
    final total = widget.engineStats['total'] ?? 0;
    if (total == 0) return '0';
    return ((ok / total) * 100).toStringAsFixed(1);
  }

  String _formatUptime(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${(seconds / 60).floor()}m';
    return '${(seconds / 3600).floor()}h';
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    if (timestamp is DateTime) {
      final now = DateTime.now();
      final diff = now.difference(timestamp);
      if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      return '${diff.inHours}h ago';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          _buildEngineHeader(),
          _buildMetricsGrid(),
          _buildRecentActivity(),
        ],
      ),
    );
  }
}

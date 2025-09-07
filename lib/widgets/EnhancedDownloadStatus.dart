import 'dart:async';
import 'package:flutter/material.dart';
import '../constant/appcolors.dart';
import '../utils/FileSizeConverter.dart';

enum DownloadPhase {
  initializing,
  scraping,
  analyzing,
  downloading,
  completed,
  failed,
  paused
}

class EnhancedDownloadStatus extends StatefulWidget {
  final Map<String, dynamic> downloadInfo;
  final bool isDownloading;
  final String? currentFileName;
  final DownloadPhase phase;
  final String? statusMessage;
  final Map<String, dynamic>? errorDetails;

  const EnhancedDownloadStatus({
    Key? key,
    required this.downloadInfo,
    required this.isDownloading,
    this.currentFileName,
    this.phase = DownloadPhase.initializing,
    this.statusMessage,
    this.errorDetails,
  }) : super(key: key);

  @override
  State<EnhancedDownloadStatus> createState() => _EnhancedDownloadStatusState();
}

class _EnhancedDownloadStatusState extends State<EnhancedDownloadStatus>
    with TickerProviderStateMixin {
  late AnimationController _phaseController;
  late AnimationController _pulseController;
  Timer? _statusUpdateTimer;

  @override
  void initState() {
    super.initState();
    _phaseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    if (widget.isDownloading) {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(EnhancedDownloadStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDownloading != oldWidget.isDownloading) {
      if (widget.isDownloading) {
        _pulseController.repeat();
      } else {
        _pulseController.stop();
      }
    }
  }

  @override
  void dispose() {
    _phaseController.dispose();
    _pulseController.dispose();
    _statusUpdateTimer?.cancel();
    super.dispose();
  }

  Color _getPhaseColor() {
    switch (widget.phase) {
      case DownloadPhase.initializing:
        return Colors.blue[400]!;
      case DownloadPhase.scraping:
        return Colors.purple[400]!;
      case DownloadPhase.analyzing:
        return Colors.orange[400]!;
      case DownloadPhase.downloading:
        return Colors.green[400]!;
      case DownloadPhase.completed:
        return Colors.green[600]!;
      case DownloadPhase.failed:
        return Colors.red[400]!;
      case DownloadPhase.paused:
        return Colors.grey[400]!;
    }
  }

  IconData _getPhaseIcon() {
    switch (widget.phase) {
      case DownloadPhase.initializing:
        return Icons.settings;
      case DownloadPhase.scraping:
        return Icons.search;
      case DownloadPhase.analyzing:
        return Icons.analytics;
      case DownloadPhase.downloading:
        return Icons.download;
      case DownloadPhase.completed:
        return Icons.check_circle;
      case DownloadPhase.failed:
        return Icons.error;
      case DownloadPhase.paused:
        return Icons.pause_circle;
    }
  }

  String _getPhaseDescription() {
    switch (widget.phase) {
      case DownloadPhase.initializing:
        return 'Initializing download engine...';
      case DownloadPhase.scraping:
        return 'Scraping content from source...';
      case DownloadPhase.analyzing:
        return 'Analyzing found media files...';
      case DownloadPhase.downloading:
        return 'Downloading media files...';
      case DownloadPhase.completed:
        return 'Download completed successfully';
      case DownloadPhase.failed:
        return 'Download failed';
      case DownloadPhase.paused:
        return 'Download paused';
    }
  }

  Widget _buildPhaseIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: _getPhaseColor().withOpacity(0.1),
        border: Border.all(
          color: _getPhaseColor().withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: widget.isDownloading
                    ? 1.0 + (_pulseController.value * 0.2)
                    : 1.0,
                child: Icon(
                  _getPhaseIcon(),
                  color: _getPhaseColor(),
                  size: 16,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Text(
            widget.phase.name.toUpperCase(),
            style: TextStyle(
              color: _getPhaseColor(),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedProgress() {
    final total = widget.downloadInfo['total'] ?? 0;
    final ok = widget.downloadInfo['ok'] ?? 0;
    final fail = widget.downloadInfo['fail'] ?? 0;
    final retries = widget.downloadInfo['retries'] ?? 0;
    final size = widget.downloadInfo['size'] ?? 0;

    return Column(
      children: [
        // Main progress bar
        Container(
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: Appcolors.appAccentColor.withOpacity(0.1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: total > 0 ? (ok / total) : 0.0,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation(_getPhaseColor()),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Detailed stats
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            _buildStatChip('OK', ok, Colors.green[400]!),
            if (fail > 0) _buildStatChip('FAIL', fail, Colors.red[400]!),
            if (retries > 0)
              _buildStatChip('RETRY', retries, Colors.orange[400]!),
            _buildStatChip(
                'SIZE',
                FileSizeConverter.getFileSizeString(bytes: size),
                Colors.blue[400]!),
          ],
        ),
      ],
    );
  }

  Widget _buildStatChip(String label, dynamic value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCurrentFileInfo() {
    if (widget.currentFileName == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Appcolors.appAccentColor.withOpacity(0.05),
        border: Border.all(
          color: Appcolors.appAccentColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.file_download,
            size: 14,
            color: Appcolors.appPrimaryColor.withOpacity(0.7),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Downloading: ${widget.currentFileName}',
              style: TextStyle(
                color: Appcolors.appPrimaryColor.withOpacity(0.8),
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorDetails() {
    if (widget.errorDetails == null || widget.phase != DownloadPhase.failed) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.red[50]?.withOpacity(0.1),
        border: Border.all(color: Colors.red[300]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, size: 14, color: Colors.red[400]),
              const SizedBox(width: 6),
              Text(
                'Error Details:',
                style: TextStyle(
                  color: Colors.red[400],
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.errorDetails!['message'] ?? 'Unknown error occurred',
            style: TextStyle(
              color: Colors.red[300],
              fontSize: 10,
            ),
          ),
          if (widget.errorDetails!['code'] != null) ...[
            const SizedBox(height: 2),
            Text(
              'Error Code: ${widget.errorDetails!['code']}',
              style: TextStyle(
                color: Colors.red[300]?.withOpacity(0.7),
                fontSize: 9,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Appcolors.appAccentColor.withOpacity(0.2),
          width: 1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Appcolors.appSecondaryColor.withOpacity(0.1),
            Appcolors.appSecondaryColor.withOpacity(0.05),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phase indicator and description
          Row(
            children: [
              _buildPhaseIndicator(),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.statusMessage ?? _getPhaseDescription(),
                  style: TextStyle(
                    color: Appcolors.appPrimaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress and stats
          if (widget.phase == DownloadPhase.downloading ||
              widget.phase == DownloadPhase.completed)
            _buildDetailedProgress(),

          // Current file info
          _buildCurrentFileInfo(),

          // Error details
          _buildErrorDetails(),
        ],
      ),
    );
  }
}

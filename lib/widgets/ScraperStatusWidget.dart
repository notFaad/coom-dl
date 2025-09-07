import 'dart:async';
import 'package:flutter/material.dart';
import '../constant/appcolors.dart';

enum ScrapingPhase {
  connecting,
  fetching,
  parsing,
  analyzing,
  filtering,
  completed,
  failed
}

class ScraperStatusWidget extends StatefulWidget {
  final ScrapingPhase phase;
  final String? currentUrl;
  final Map<String, dynamic>? scrapingStats;
  final String? statusMessage;
  final List<Map<String, dynamic>>? recentActions;
  final bool isActive;

  const ScraperStatusWidget({
    Key? key,
    required this.phase,
    this.currentUrl,
    this.scrapingStats,
    this.statusMessage,
    this.recentActions,
    this.isActive = false,
  }) : super(key: key);

  @override
  State<ScraperStatusWidget> createState() => _ScraperStatusWidgetState();
}

class _ScraperStatusWidgetState extends State<ScraperStatusWidget>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;
  Timer? _animationTimer;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    if (widget.isActive) {
      _pulseController.repeat();
      _progressController.repeat();
    }
  }

  @override
  void didUpdateWidget(ScraperStatusWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _pulseController.repeat();
        _progressController.repeat();
      } else {
        _pulseController.stop();
        _progressController.stop();
      }
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    _animationTimer?.cancel();
    super.dispose();
  }

  Color _getPhaseColor() {
    switch (widget.phase) {
      case ScrapingPhase.connecting:
        return Colors.blue[400]!;
      case ScrapingPhase.fetching:
        return Colors.purple[400]!;
      case ScrapingPhase.parsing:
        return Colors.orange[400]!;
      case ScrapingPhase.analyzing:
        return Colors.cyan[400]!;
      case ScrapingPhase.filtering:
        return Colors.amber[400]!;
      case ScrapingPhase.completed:
        return Colors.green[400]!;
      case ScrapingPhase.failed:
        return Colors.red[400]!;
    }
  }

  IconData _getPhaseIcon() {
    switch (widget.phase) {
      case ScrapingPhase.connecting:
        return Icons.link;
      case ScrapingPhase.fetching:
        return Icons.cloud_download;
      case ScrapingPhase.parsing:
        return Icons.code;
      case ScrapingPhase.analyzing:
        return Icons.analytics;
      case ScrapingPhase.filtering:
        return Icons.filter_list;
      case ScrapingPhase.completed:
        return Icons.check_circle;
      case ScrapingPhase.failed:
        return Icons.error;
    }
  }

  String _getPhaseDescription() {
    switch (widget.phase) {
      case ScrapingPhase.connecting:
        return 'Establishing connection to source...';
      case ScrapingPhase.fetching:
        return 'Fetching page content and metadata...';
      case ScrapingPhase.parsing:
        return 'Parsing HTML and extracting links...';
      case ScrapingPhase.analyzing:
        return 'Analyzing found media files...';
      case ScrapingPhase.filtering:
        return 'Applying media type filters...';
      case ScrapingPhase.completed:
        return 'Scraping completed successfully';
      case ScrapingPhase.failed:
        return 'Scraping failed';
    }
  }

  Widget _buildPhaseIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: _getPhaseColor().withOpacity(0.15),
        border: Border.all(
          color: _getPhaseColor().withOpacity(0.4),
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
                scale: widget.isActive
                    ? 1.0 + (_pulseController.value * 0.3)
                    : 1.0,
                child: Icon(
                  _getPhaseIcon(),
                  color: _getPhaseColor(),
                  size: 14,
                ),
              );
            },
          ),
          const SizedBox(width: 6),
          Text(
            widget.phase.name.toUpperCase(),
            style: TextStyle(
              color: _getPhaseColor(),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrapingProgress() {
    return AnimatedBuilder(
      animation: _progressController,
      builder: (context, child) {
        return Container(
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: Appcolors.appAccentColor.withOpacity(0.1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: widget.isActive ? null : 1.0,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation(_getPhaseColor()),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScrapingStats() {
    if (widget.scrapingStats == null) return const SizedBox.shrink();

    final stats = widget.scrapingStats!;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        _buildStatBadge('Found', stats['found'] ?? 0, Colors.blue[400]!),
        _buildStatBadge('Videos', stats['videos'] ?? 0, Colors.purple[400]!),
        _buildStatBadge('Images', stats['images'] ?? 0, Colors.green[400]!),
        if (stats['errors'] != null && stats['errors'] > 0)
          _buildStatBadge('Errors', stats['errors'], Colors.red[400]!),
      ],
    );
  }

  Widget _buildStatBadge(String label, dynamic value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCurrentUrl() {
    if (widget.currentUrl == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: Appcolors.appAccentColor.withOpacity(0.05),
        border: Border.all(
          color: Appcolors.appAccentColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.link,
            size: 12,
            color: Appcolors.appPrimaryColor.withOpacity(0.6),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Source: ${widget.currentUrl}',
              style: TextStyle(
                color: Appcolors.appPrimaryColor.withOpacity(0.7),
                fontSize: 9,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActions() {
    if (widget.recentActions == null || widget.recentActions!.isEmpty) {
      return const SizedBox.shrink();
    }

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity:',
            style: TextStyle(
              color: Appcolors.appPrimaryColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          ...widget.recentActions!
              .take(3)
              .map((action) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: _getActionColor(action['type']),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            action['message'] ?? 'Unknown action',
                            style: TextStyle(
                              color: Appcolors.appPrimaryColor.withOpacity(0.7),
                              fontSize: 9,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ],
      ),
    );
  }

  Color _getActionColor(String? type) {
    switch (type) {
      case 'success':
        return Colors.green[400]!;
      case 'warning':
        return Colors.orange[400]!;
      case 'error':
        return Colors.red[400]!;
      default:
        return Colors.blue[400]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _getPhaseColor().withOpacity(0.2),
          width: 1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getPhaseColor().withOpacity(0.08),
            _getPhaseColor().withOpacity(0.03),
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
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.statusMessage ?? _getPhaseDescription(),
                  style: TextStyle(
                    color: Appcolors.appPrimaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Progress bar
          _buildScrapingProgress(),

          const SizedBox(height: 8),

          // Stats
          _buildScrapingStats(),

          // Current URL
          _buildCurrentUrl(),

          // Recent actions
          _buildRecentActions(),
        ],
      ),
    );
  }
}

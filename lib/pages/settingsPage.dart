import 'package:coom_dl/constant/appcolors.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:get/get.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'dart:convert';
import 'debugMonitor.dart';

class SettingsPage extends StatefulWidget {
  final Box settingsBox;
  final Box historyBox;
  final Box linksBox;

  SettingsPage({
    Key? key,
    required this.settingsBox,
    required this.historyBox,
    required this.linksBox,
  }) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Map<dynamic, dynamic> settings;

  @override
  void initState() {
    super.initState();
    settings = widget.settingsBox.toMap();
    _initializeDefaultSettings();
  }

  void _initializeDefaultSettings() {
    if (!settings.containsKey('eng')) {
      widget.settingsBox.put('eng', 0);
    }
    if (!settings.containsKey('job')) {
      widget.settingsBox.put('job', 5);
    }
    if (!settings.containsKey('retry')) {
      widget.settingsBox.put('retry', 3);
    }
    if (!settings.containsKey('debugMode')) {
      widget.settingsBox.put('debugMode', false);
    }
    settings = widget.settingsBox.toMap();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Appcolors.appBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Settings',
          style: TextStyle(
              color: Appcolors.appTextColor,
              fontSize: 24,
              fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Appcolors.appTextColor),
        toolbarHeight: 80,
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.green.withOpacity(0.2),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                SizedBox(width: 8),
                Text('Auto-Save Enabled',
                    style: TextStyle(color: Colors.green, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Use single column layout on smaller screens
            if (constraints.maxWidth < 800) {
              return SingleChildScrollView(
                child: Column(
                  children: [
                    _buildEngineSection(),
                    const SizedBox(height: 16),
                    _buildPerformanceSection(),
                    const SizedBox(height: 16),
                    _buildDebugSection(),
                    const SizedBox(height: 16),
                    _buildSystemInfoSection(),
                  ],
                ),
              );
            }
            // Use two-column layout on larger screens
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column - Main Settings
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildEngineSection(),
                        const SizedBox(height: 16),
                        _buildPerformanceSection(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Right Column - Additional Settings
                Expanded(
                  flex: 1,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildDebugSection(),
                        const SizedBox(height: 16),
                        _buildSystemInfoSection(),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEngineSection() {
    return _buildGlassyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Download Engine'),
          const SizedBox(height: 12),
          _buildEngineSelector(),
        ],
      ),
    );
  }

  Widget _buildPerformanceSection() {
    return _buildGlassyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Performance Settings'),
          const SizedBox(height: 12),
          _buildJobsSlider(),
          const SizedBox(height: 12),
          _buildRetrySlider(),
        ],
      ),
    );
  }

  Widget _buildDebugSection() {
    return _buildGlassyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Debug Mode'),
          const SizedBox(height: 12),
          _buildDebugSwitch(),
          if (settings['debugMode'] == true) ...[
            const SizedBox(height: 12),
            _buildMonitorButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildGlassyCard({required Widget child}) {
    return Container(
      width: double.infinity,
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
            Appcolors.appSecondaryColor.withOpacity(0.3),
            Appcolors.appSecondaryColor.withOpacity(0.1),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Appcolors.appAccentColor.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: child,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Appcolors.appPrimaryColor,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildEngineSelector() {
    final engines = ['Recooma Engine', 'Gallery-dl Engine', 'Cyberdrop Engine'];
    return Column(
      children: engines.asMap().entries.map((entry) {
        int index = entry.key;
        String engine = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: (settings['eng'] ?? 0) == index
                  ? Appcolors.appPrimaryColor.withOpacity(0.5)
                  : Appcolors.appAccentColor.withOpacity(0.1),
              width: 1,
            ),
            color: (settings['eng'] ?? 0) == index
                ? Appcolors.appAccentColor.withOpacity(0.1)
                : Colors.transparent,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              setState(() {
                widget.settingsBox.put('eng', index);
                settings = widget.settingsBox.toMap();
              });
              _showAutoSaveNotification('Engine updated');
            },
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Radio<int>(
                    value: index,
                    groupValue: settings['eng'] ?? 0,
                    activeColor: Appcolors.appPrimaryColor,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    onChanged: (value) {
                      setState(() {
                        widget.settingsBox.put('eng', value);
                        settings = widget.settingsBox.toMap();
                      });
                      _showAutoSaveNotification('Engine updated');
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      engine,
                      style: const TextStyle(
                        color: Appcolors.appTextColor,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildJobsSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Concurrent Jobs: ${settings['job'] ?? 5}',
          style: const TextStyle(color: Appcolors.appTextColor, fontSize: 14),
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Appcolors.appPrimaryColor,
            inactiveTrackColor: Appcolors.appSecondaryColor.withOpacity(0.3),
            thumbColor: Appcolors.appLogoColor,
            overlayColor: Appcolors.appPrimaryColor.withOpacity(0.2),
            trackHeight: 4,
          ),
          child: Slider(
            value: (settings['job'] ?? 5).toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            onChanged: (value) {
              setState(() {
                widget.settingsBox.put('job', value.toInt());
                settings = widget.settingsBox.toMap();
              });
              _showAutoSaveNotification(
                  'Concurrent jobs updated to ${value.toInt()}');
            },
          ),
        ),
        const Text(
          'Recommended: 4-6 jobs for optimal performance',
          style: TextStyle(
              color: Appcolors.appTextColor,
              fontSize: 10,
              fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _buildRetrySlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Retry Attempts: ${settings['retry'] ?? 3}',
          style: const TextStyle(color: Appcolors.appTextColor, fontSize: 14),
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Appcolors.appPrimaryColor,
            inactiveTrackColor: Appcolors.appSecondaryColor.withOpacity(0.3),
            thumbColor: Appcolors.appLogoColor,
            overlayColor: Appcolors.appPrimaryColor.withOpacity(0.2),
            trackHeight: 4,
          ),
          child: Slider(
            value: (settings['retry'] ?? 3).toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            onChanged: (value) {
              setState(() {
                widget.settingsBox.put('retry', value.toInt());
                settings = widget.settingsBox.toMap();
              });
              _showAutoSaveNotification(
                  'Retry attempts updated to ${value.toInt()}');
            },
          ),
        ),
        const Text(
          'Number of times to retry failed downloads',
          style: TextStyle(
              color: Appcolors.appTextColor,
              fontSize: 10,
              fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _buildDebugSwitch() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Appcolors.appAccentColor.withOpacity(0.1),
          width: 1,
        ),
        color: Appcolors.appAccentColor.withOpacity(0.05),
      ),
      child: SwitchListTile(
        dense: true,
        title: const Text('Debug Mode',
            style: TextStyle(color: Appcolors.appTextColor, fontSize: 14)),
        subtitle: const Text('Enable detailed logging',
            style: TextStyle(color: Appcolors.appTextColor, fontSize: 11)),
        value: settings['debugMode'] ?? false,
        activeColor: Appcolors.appPrimaryColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        onChanged: (value) {
          setState(() {
            widget.settingsBox.put('debugMode', value);
            settings = widget.settingsBox.toMap();
          });
          _showAutoSaveNotification(
              'Debug mode ${value ? 'enabled' : 'disabled'}');
        },
      ),
    );
  }

  Widget _buildSystemInfoSection() {
    return _buildGlassyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('System Information'),
          const SizedBox(height: 12),
          _buildInfoRow('Settings Storage', 'Hive Database'),
          _buildInfoRow('Current Engine', _getCurrentEngineName()),
          _buildInfoRow('Active Jobs', '${settings['job'] ?? 5}'),
          _buildInfoRow('Debug Status',
              settings['debugMode'] == true ? 'Enabled' : 'Disabled'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Appcolors.appAccentColor.withOpacity(0.1),
              border:
                  Border.all(color: Appcolors.appAccentColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: Appcolors.appPrimaryColor, size: 14),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Settings auto-save on change',
                    style: TextStyle(
                      color: Appcolors.appTextColor,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Appcolors.appTextColor,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Appcolors.appAccentColor.withOpacity(0.1),
            ),
            child: Text(
              value,
              style: const TextStyle(
                color: Appcolors.appPrimaryColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrentEngineName() {
    final engines = ['Recooma Engine', 'Gallery-dl Engine', 'Cyberdrop Engine'];
    final currentEngine = settings['eng'] ?? 0;
    if (currentEngine >= 0 && currentEngine < engines.length) {
      return engines[currentEngine];
    }
    return 'Unknown';
  }

  void _showAutoSaveNotification(String message) {
    Get.showSnackbar(
      GetSnackBar(
        backgroundColor: Colors.green.withOpacity(0.8),
        message: message,
        duration: const Duration(seconds: 1),
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(10),
        borderRadius: 8,
        icon: const Icon(Icons.check_circle, color: Colors.white, size: 20),
        maxWidth: 300,
      ),
    );
  }

  Widget _buildMonitorButton() {
    return Container(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          try {
            final window = await DesktopMultiWindow.createWindow(jsonEncode({
              'route': '/debug_monitor',
              'title': 'Debug Monitor',
            }));

            window
              ..setFrame(const Offset(100, 100) & const Size(1200, 800))
              ..setTitle('COOM-DL Debug Monitor')
              ..show();

            _showAutoSaveNotification('Debug monitor window opened');
          } catch (e) {
            // Fallback to normal navigation if multi-window fails
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DebugMonitorPage(),
              ),
            );
          }
        },
        icon: const Icon(Icons.monitor_heart, size: 18),
        label: const Text('Open Debug Monitor'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Appcolors.appAccentColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

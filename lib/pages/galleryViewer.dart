import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../constant/appcolors.dart';
import '../services/galleryService.dart';

// Enhanced Gallery View Mode Enum
enum GalleryViewMode { grid, list, details }

// File Selection Model
class FileSelectionModel {
  final Set<String> selectedFiles = <String>{};
  bool isSelectionMode = false;

  void toggleSelection(String filePath) {
    if (selectedFiles.contains(filePath)) {
      selectedFiles.remove(filePath);
    } else {
      selectedFiles.add(filePath);
    }
    if (selectedFiles.isEmpty) {
      isSelectionMode = false;
    }
  }

  void selectAll(List<File> files) {
    selectedFiles.clear();
    selectedFiles.addAll(files.map((f) => f.path));
    isSelectionMode = true;
  }

  void clearSelection() {
    selectedFiles.clear();
    isSelectionMode = false;
  }
}

// Gallery Statistics Model
class GalleryStats {
  int totalFiles = 0;
  int imageFiles = 0;
  int videoFiles = 0;
  int otherFiles = 0;
  int totalSize = 0;
  DateTime? oldestFile;
  DateTime? newestFile;

  void calculate(List<File> files) {
    totalFiles = files.length;
    imageFiles = 0;
    videoFiles = 0;
    otherFiles = 0;
    totalSize = 0;
    oldestFile = null;
    newestFile = null;

    for (var file in files) {
      try {
        var stat = file.statSync();
        totalSize += stat.size;

        if (oldestFile == null || stat.modified.isBefore(oldestFile!)) {
          oldestFile = stat.modified;
        }
        if (newestFile == null || stat.modified.isAfter(newestFile!)) {
          newestFile = stat.modified;
        }

        String ext = path.extension(file.path).toLowerCase();
        if (['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'].contains(ext)) {
          imageFiles++;
        } else if ([
          '.mp4',
          '.avi',
          '.mov',
          '.wmv',
          '.flv',
          '.webm',
          '.m4v',
          '.mkv'
        ].contains(ext)) {
          videoFiles++;
        } else {
          otherFiles++;
        }
      } catch (e) {
        otherFiles++;
      }
    }
  }

  String get formattedSize => _formatBytes(totalSize);

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (log(bytes) / log(1024)).floor();
    return ((bytes / pow(1024, i)).toStringAsFixed(1)) + ' ' + suffixes[i];
  }
}

class GalleryViewer extends StatefulWidget {
  final int downloadId;
  final String downloadName;
  final String downloadPath;

  const GalleryViewer({
    Key? key,
    required this.downloadId,
    required this.downloadName,
    required this.downloadPath,
  }) : super(key: key);

  @override
  State<GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<GalleryViewer>
    with TickerProviderStateMixin {
  late GalleryService _galleryService;
  List<File> _allFiles = [];
  List<File> _filteredFiles = [];
  StreamSubscription<String>? _filesSubscription;
  bool _isLoading = true;

  // Enhanced State Management
  final FileSelectionModel _selection = FileSelectionModel();
  final GalleryStats _stats = GalleryStats();
  GalleryViewMode _viewMode = GalleryViewMode.grid;

  // Search and Filter
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _fileTypeFilter = 'all'; // all, images, videos, others
  DateTime? _dateFilterStart;
  DateTime? _dateFilterEnd;

  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Focus Node for Keyboard Navigation
  final FocusNode _focusNode = FocusNode();
  int _currentIndex = 0;

  // Fullscreen Controller
  PageController? _fullscreenController;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    print('Gallery: Initializing gallery for ${widget.downloadPath}');
    _galleryService = GalleryService.instance;

    // Initialize Animation Controllers
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _initializeGallery();
    _searchController.addListener(_onSearchChanged);

    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  void _initializeGallery() async {
    try {
      // Start watching the directory
      await _galleryService.startWatching(widget.downloadPath);

      // Listen for file changes with error handling
      _filesSubscription = _galleryService.fileChanges
          .where((changedPath) => changedPath == widget.downloadPath)
          .listen(
        (_) {
          if (mounted) {
            try {
              _updateMediaFiles();
            } catch (e) {
              print('Gallery: Error updating media files: $e');
            }
          }
        },
        onError: (error) {
          print('Gallery: File change listener error: $error');
        },
      );

      // Initial load
      _updateMediaFiles();
    } catch (e) {
      print('Gallery: Error initializing gallery: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateMediaFiles() {
    try {
      final files = _galleryService.getMediaFiles(widget.downloadPath);
      if (mounted) {
        setState(() {
          _allFiles = files;
          _applyFilters();
          _stats.calculate(_filteredFiles);
          _isLoading = false;
          // Reset selected index if current selection is out of bounds
          if (_currentIndex >= _filteredFiles.length &&
              _filteredFiles.isNotEmpty) {
            _currentIndex = 0;
          }
        });
      }
    } catch (e) {
      print('Gallery: Error in _updateMediaFiles: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _applyFilters();
    });
  }

  void _applyFilters() {
    _filteredFiles = _allFiles.where((file) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        String fileName = path.basename(file.path).toLowerCase();
        if (!fileName.contains(_searchQuery)) return false;
      }

      // File type filter
      if (_fileTypeFilter != 'all') {
        String ext = path.extension(file.path).toLowerCase();
        switch (_fileTypeFilter) {
          case 'images':
            if (!['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp']
                .contains(ext)) return false;
            break;
          case 'videos':
            if (![
              '.mp4',
              '.avi',
              '.mov',
              '.wmv',
              '.flv',
              '.webm',
              '.m4v',
              '.mkv'
            ].contains(ext)) return false;
            break;
          case 'others':
            if ([
              '.jpg',
              '.jpeg',
              '.png',
              '.gif',
              '.bmp',
              '.webp',
              '.mp4',
              '.avi',
              '.mov',
              '.wmv',
              '.flv',
              '.webm',
              '.m4v',
              '.mkv'
            ].contains(ext)) return false;
            break;
        }
      }

      // Date filter
      if (_dateFilterStart != null || _dateFilterEnd != null) {
        try {
          var stat = file.statSync();
          if (_dateFilterStart != null &&
              stat.modified.isBefore(_dateFilterStart!)) return false;
          if (_dateFilterEnd != null && stat.modified.isAfter(_dateFilterEnd!))
            return false;
        } catch (e) {
          return false;
        }
      }

      return true;
    }).toList();

    _stats.calculate(_filteredFiles);
  }

  // Keyboard Navigation
  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowRight:
          _navigateToNext();
          break;
        case LogicalKeyboardKey.arrowLeft:
          _navigateToPrevious();
          break;
        case LogicalKeyboardKey.space:
        case LogicalKeyboardKey.enter:
          if (_filteredFiles.isNotEmpty &&
              _currentIndex < _filteredFiles.length) {
            _openFile(_filteredFiles[_currentIndex]);
          }
          break;
        case LogicalKeyboardKey.escape:
          if (_isFullscreen) {
            _exitFullscreen();
          } else {
            Navigator.of(context).pop();
          }
          break;
        case LogicalKeyboardKey.delete:
          if (_selection.isSelectionMode) {
            _deleteSelectedFiles();
          }
          break;
        case LogicalKeyboardKey.keyA:
          // Check for Cmd+A (macOS) or Ctrl+A (others) for select all
          bool hasModifier = RawKeyboard.instance.keysPressed
                  .contains(LogicalKeyboardKey.metaLeft) ||
              RawKeyboard.instance.keysPressed
                  .contains(LogicalKeyboardKey.metaRight) ||
              RawKeyboard.instance.keysPressed
                  .contains(LogicalKeyboardKey.controlLeft) ||
              RawKeyboard.instance.keysPressed
                  .contains(LogicalKeyboardKey.controlRight);
          if (hasModifier) {
            _selection.selectAll(_filteredFiles);
            setState(() {});
          }
          break;
      }
    }
  }

  void _navigateToNext() {
    if (_filteredFiles.isNotEmpty) {
      setState(() {
        _currentIndex = (_currentIndex + 1) % _filteredFiles.length;
      });
    }
  }

  void _navigateToPrevious() {
    if (_filteredFiles.isNotEmpty) {
      setState(() {
        _currentIndex =
            (_currentIndex - 1 + _filteredFiles.length) % _filteredFiles.length;
      });
    }
  }

  // File Operations
  void _openFile(File file) async {
    String ext = path.extension(file.path).toLowerCase();

    if (['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'].contains(ext)) {
      _openImageFullscreen(file.path);
    } else if (['.mp4', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v', '.mkv']
        .contains(ext)) {
      _openVideoPlayer(file.path);
    } else {
      // Open other file types with system default app
      try {
        if (Platform.isMacOS) {
          await Process.start('open', [file.path]);
        } else if (Platform.isWindows) {
          await Process.start('start', [file.path], runInShell: true);
        } else if (Platform.isLinux) {
          await Process.start('xdg-open', [file.path]);
        }
      } catch (e) {
        print('Error opening file with system app: $e');
      }
    }
  }

  void _openImageFullscreen(String imagePath) {
    List<String> imagePaths = _filteredFiles
        .where((f) => ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp']
            .contains(path.extension(f.path).toLowerCase()))
        .map((f) => f.path)
        .toList();

    if (imagePaths.isEmpty) return;

    int actualIndex = imagePaths.indexWhere((p) => p == imagePath);
    if (actualIndex == -1) actualIndex = 0;

    setState(() {
      _isFullscreen = true;
    });

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: _FullscreenImageViewer(
              imagePaths: imagePaths,
              initialIndex: actualIndex,
              onClose: () {
                setState(() {
                  _isFullscreen = false;
                });
                Navigator.of(context).pop();
              },
            ),
          );
        },
      ),
    );
  }

  void _openVideoPlayer(String videoPath) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(videoPath: videoPath),
      ),
    );
  }

  // Batch Operations
  void _deleteSelectedFiles() async {
    if (_selection.selectedFiles.isEmpty) return;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Appcolors.appAccentColor,
        title: Text('Delete Files',
            style: TextStyle(color: Appcolors.appPrimaryColor)),
        content: Text(
          'Are you sure you want to delete ${_selection.selectedFiles.length} selected files?',
          style: TextStyle(color: Appcolors.appPrimaryColor.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel',
                style: TextStyle(
                    color: Appcolors.appPrimaryColor.withOpacity(0.7))),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      for (String filePath in _selection.selectedFiles) {
        try {
          await File(filePath).delete();
        } catch (e) {
          print('Error deleting file $filePath: $e');
        }
      }
      _selection.clearSelection();
      _updateMediaFiles();
    }
  }

  void _copySelectedFiles() async {
    if (_selection.selectedFiles.isEmpty) return;

    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      for (String filePath in _selection.selectedFiles) {
        try {
          File sourceFile = File(filePath);
          String fileName = path.basename(filePath);
          String destinationPath = path.join(selectedDirectory, fileName);
          await sourceFile.copy(destinationPath);
        } catch (e) {
          print('Error copying file $filePath: $e');
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${_selection.selectedFiles.length} files copied successfully'),
          backgroundColor: Appcolors.appLogoColor,
        ),
      );
    }
  }

  void _shareSelectedFiles() async {
    if (_selection.selectedFiles.isEmpty) return;

    List<XFile> xFiles =
        _selection.selectedFiles.map((path) => XFile(path)).toList();

    try {
      await Share.shareXFiles(xFiles);
    } catch (e) {
      print('Error sharing files: $e');
    }
  }

  // Statistics Dialog
  void _showStatistics() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Appcolors.appAccentColor,
        title: Text('Gallery Statistics',
            style: TextStyle(color: Appcolors.appPrimaryColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatItem('Total Files', '${_stats.totalFiles}'),
            _StatItem('Images', '${_stats.imageFiles}'),
            _StatItem('Videos', '${_stats.videoFiles}'),
            _StatItem('Other Files', '${_stats.otherFiles}'),
            _StatItem('Total Size', _stats.formattedSize),
            if (_stats.oldestFile != null)
              _StatItem('Oldest File', _formatDate(_stats.oldestFile!)),
            if (_stats.newestFile != null)
              _StatItem('Newest File', _formatDate(_stats.newestFile!)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child:
                Text('Close', style: TextStyle(color: Appcolors.appLogoColor)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        _handleKeyEvent(event);
        return KeyEventResult.handled;
      },
      child: Scaffold(
        backgroundColor: Color.fromARGB(255, 13, 13, 13),
        appBar: AppBar(
          backgroundColor: Appcolors.appAccentColor.withOpacity(0.1),
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gallery - ${widget.downloadName}',
                style:
                    TextStyle(color: Appcolors.appPrimaryColor, fontSize: 16),
              ),
              Text(
                '${_filteredFiles.length} files${_selection.isSelectionMode ? ' (${_selection.selectedFiles.length} selected)' : ''}',
                style: TextStyle(
                    color: Appcolors.appPrimaryColor.withOpacity(0.7),
                    fontSize: 12),
              ),
            ],
          ),
          actions: [
            // View Mode Toggle
            IconButton(
              onPressed: () {
                setState(() {
                  switch (_viewMode) {
                    case GalleryViewMode.grid:
                      _viewMode = GalleryViewMode.list;
                      break;
                    case GalleryViewMode.list:
                      _viewMode = GalleryViewMode.details;
                      break;
                    case GalleryViewMode.details:
                      _viewMode = GalleryViewMode.grid;
                      break;
                  }
                });
              },
              icon: Icon(
                _viewMode == GalleryViewMode.grid
                    ? Icons.grid_view
                    : _viewMode == GalleryViewMode.list
                        ? Icons.list
                        : Icons.table_chart,
                color: Appcolors.appLogoColor,
              ),
            ),
            // Statistics
            IconButton(
              onPressed: _showStatistics,
              icon: Icon(Icons.analytics, color: Appcolors.appLogoColor),
            ),
            // Batch Operations Menu
            if (_selection.isSelectionMode)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Appcolors.appLogoColor),
                color: Appcolors.appAccentColor,
                onSelected: (value) {
                  switch (value) {
                    case 'copy':
                      _copySelectedFiles();
                      break;
                    case 'delete':
                      _deleteSelectedFiles();
                      break;
                    case 'share':
                      _shareSelectedFiles();
                      break;
                    case 'selectAll':
                      _selection.selectAll(_filteredFiles);
                      setState(() {});
                      break;
                    case 'clearSelection':
                      _selection.clearSelection();
                      setState(() {});
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'copy',
                    child: Text('Copy Selected',
                        style: TextStyle(color: Appcolors.appPrimaryColor)),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete Selected',
                        style: TextStyle(color: Colors.red)),
                  ),
                  PopupMenuItem(
                    value: 'share',
                    child: Text('Share Selected',
                        style: TextStyle(color: Appcolors.appPrimaryColor)),
                  ),
                  PopupMenuItem(
                    value: 'selectAll',
                    child: Text('Select All',
                        style: TextStyle(color: Appcolors.appPrimaryColor)),
                  ),
                  PopupMenuItem(
                    value: 'clearSelection',
                    child: Text('Clear Selection',
                        style: TextStyle(
                            color: Appcolors.appPrimaryColor.withOpacity(0.7))),
                  ),
                ],
              ),
          ],
        ),
        body: Column(
          children: [
            // Search and Filter Bar
            Container(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Appcolors.appAccentColor.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Appcolors.appLogoColor.withOpacity(0.3)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: Appcolors.appPrimaryColor),
                      decoration: InputDecoration(
                        hintText: 'Search files...',
                        hintStyle: TextStyle(
                            color: Appcolors.appPrimaryColor.withOpacity(0.5)),
                        prefixIcon:
                            Icon(Icons.search, color: Appcolors.appLogoColor),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged();
                                },
                                icon: Icon(Icons.clear,
                                    color: Appcolors.appPrimaryColor
                                        .withOpacity(0.7)),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  // Filter Chips
                  Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _FilterChip('All', 'all', _fileTypeFilter),
                              _FilterChip('Images', 'images', _fileTypeFilter),
                              _FilterChip('Videos', 'videos', _fileTypeFilter),
                              _FilterChip('Others', 'others', _fileTypeFilter),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _showDateFilter,
                        icon: Icon(
                          Icons.date_range,
                          color: (_dateFilterStart != null ||
                                  _dateFilterEnd != null)
                              ? Appcolors.appLogoColor
                              : Appcolors.appPrimaryColor.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Gallery Content
            Expanded(
              child: AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: _buildGalleryContent(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _FilterChip(String label, String value, String currentValue) {
    bool isSelected = currentValue == value;
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : Appcolors.appPrimaryColor.withOpacity(0.7),
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _fileTypeFilter = value;
            _applyFilters();
          });
        },
        backgroundColor: Appcolors.appAccentColor.withOpacity(0.3),
        selectedColor: Appcolors.appLogoColor,
        checkmarkColor: Colors.white,
        side: BorderSide(
          color: isSelected
              ? Appcolors.appLogoColor
              : Appcolors.appLogoColor.withOpacity(0.3),
        ),
      ),
    );
  }

  void _showDateFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Appcolors.appAccentColor,
        title: Text('Date Filter',
            style: TextStyle(color: Appcolors.appPrimaryColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Start Date',
                  style: TextStyle(color: Appcolors.appPrimaryColor)),
              subtitle: Text(
                _dateFilterStart?.toString().split(' ')[0] ?? 'Not set',
                style: TextStyle(
                    color: Appcolors.appPrimaryColor.withOpacity(0.7)),
              ),
              trailing:
                  Icon(Icons.calendar_today, color: Appcolors.appLogoColor),
              onTap: () async {
                DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: _dateFilterStart ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() {
                    _dateFilterStart = picked;
                    _applyFilters();
                  });
                }
              },
            ),
            ListTile(
              title: Text('End Date',
                  style: TextStyle(color: Appcolors.appPrimaryColor)),
              subtitle: Text(
                _dateFilterEnd?.toString().split(' ')[0] ?? 'Not set',
                style: TextStyle(
                    color: Appcolors.appPrimaryColor.withOpacity(0.7)),
              ),
              trailing:
                  Icon(Icons.calendar_today, color: Appcolors.appLogoColor),
              onTap: () async {
                DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: _dateFilterEnd ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() {
                    _dateFilterEnd = picked;
                    _applyFilters();
                  });
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _dateFilterStart = null;
                _dateFilterEnd = null;
                _applyFilters();
              });
              Navigator.of(context).pop();
            },
            child: Text('Clear',
                style: TextStyle(
                    color: Appcolors.appPrimaryColor.withOpacity(0.7))),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child:
                Text('Done', style: TextStyle(color: Appcolors.appLogoColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Appcolors.appLogoColor),
            SizedBox(height: 16),
            Text(
              'Loading gallery...',
              style: TextStyle(color: Appcolors.appPrimaryColor),
            ),
          ],
        ),
      );
    }

    if (_filteredFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library,
                size: 64, color: Appcolors.appPrimaryColor.withOpacity(0.5)),
            SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No files match your search'
                  : 'No media files found',
              style: TextStyle(color: Appcolors.appPrimaryColor, fontSize: 16),
            ),
            if (_searchQuery.isNotEmpty) ...[
              SizedBox(height: 8),
              Text(
                'Try adjusting your search or filters',
                style: TextStyle(
                    color: Appcolors.appPrimaryColor.withOpacity(0.7),
                    fontSize: 14),
              ),
            ],
          ],
        ),
      );
    }

    switch (_viewMode) {
      case GalleryViewMode.grid:
        return _buildGridView();
      case GalleryViewMode.list:
        return _buildListView();
      case GalleryViewMode.details:
        return _buildDetailsView();
    }
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: _filteredFiles.length,
      itemBuilder: (context, index) {
        File file = _filteredFiles[index];
        bool isSelected = _selection.selectedFiles.contains(file.path);
        bool isCurrent = index == _currentIndex;

        return _buildFileCard(file, isSelected, isCurrent, index);
      },
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _filteredFiles.length,
      itemBuilder: (context, index) {
        File file = _filteredFiles[index];
        bool isSelected = _selection.selectedFiles.contains(file.path);
        bool isCurrent = index == _currentIndex;

        return _buildFileListTile(file, isSelected, isCurrent, index);
      },
    );
  }

  Widget _buildDetailsView() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: DataTable(
        columns: [
          DataColumn(
              label: Text('Name',
                  style: TextStyle(color: Appcolors.appPrimaryColor))),
          DataColumn(
              label: Text('Type',
                  style: TextStyle(color: Appcolors.appPrimaryColor))),
          DataColumn(
              label: Text('Size',
                  style: TextStyle(color: Appcolors.appPrimaryColor))),
          DataColumn(
              label: Text('Modified',
                  style: TextStyle(color: Appcolors.appPrimaryColor))),
          DataColumn(
              label: Text('Actions',
                  style: TextStyle(color: Appcolors.appPrimaryColor))),
        ],
        rows: _filteredFiles.asMap().entries.map((entry) {
          File file = entry.value;
          bool isSelected = _selection.selectedFiles.contains(file.path);

          return DataRow(
            selected: isSelected,
            cells: [
              DataCell(
                Text(
                  path.basename(file.path),
                  style: TextStyle(color: Appcolors.appPrimaryColor),
                ),
                onTap: () => _openFile(file),
              ),
              DataCell(
                Text(
                  _getFileTypeLabel(file.path),
                  style: TextStyle(
                      color: Appcolors.appPrimaryColor.withOpacity(0.8)),
                ),
              ),
              DataCell(
                Text(
                  _galleryService.getFileSize(file),
                  style: TextStyle(
                      color: Appcolors.appPrimaryColor.withOpacity(0.8)),
                ),
              ),
              DataCell(
                Text(
                  _getFileDate(file),
                  style: TextStyle(
                      color: Appcolors.appPrimaryColor.withOpacity(0.8)),
                ),
              ),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _openFile(file),
                      icon: Icon(Icons.open_in_new,
                          color: Appcolors.appLogoColor, size: 16),
                    ),
                    IconButton(
                      onPressed: () {
                        _selection.toggleSelection(file.path);
                        _selection.isSelectionMode = true;
                        setState(() {});
                      },
                      icon: Icon(
                        isSelected
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        color: isSelected
                            ? Appcolors.appLogoColor
                            : Appcolors.appPrimaryColor.withOpacity(0.7),
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFileCard(File file, bool isSelected, bool isCurrent, int index) {
    String ext = path.extension(file.path).toLowerCase();
    bool isImage = _galleryService.isImageFile(file);

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
        if (_selection.isSelectionMode) {
          _selection.toggleSelection(file.path);
          setState(() {});
        } else {
          _openFile(file);
        }
      },
      onLongPress: () {
        _selection.toggleSelection(file.path);
        _selection.isSelectionMode = true;
        setState(() {});
      },
      child: Container(
        decoration: BoxDecoration(
          color: Appcolors.appAccentColor.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrent
                ? Appcolors.appLogoColor
                : isSelected
                    ? Appcolors.appLogoColor.withOpacity(0.6)
                    : Appcolors.appLogoColor.withOpacity(0.1),
            width: isCurrent ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            // File Preview
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                child: isImage
                    ? Image.file(
                        file,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildFileIcon(ext),
                      )
                    : _buildFileIcon(ext),
              ),
            ),
            // Selection Overlay
            if (isSelected)
              Container(
                decoration: BoxDecoration(
                  color: Appcolors.appLogoColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child:
                      Icon(Icons.check_circle, color: Colors.white, size: 32),
                ),
              ),
            // File Type Badge
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  ext.toUpperCase().replaceFirst('.', ''),
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            // File Name
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Text(
                  path.basename(file.path),
                  style: TextStyle(color: Colors.white, fontSize: 10),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileListTile(
      File file, bool isSelected, bool isCurrent, int index) {
    bool isImage = _galleryService.isImageFile(file);

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Appcolors.appAccentColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent
              ? Appcolors.appLogoColor
              : isSelected
                  ? Appcolors.appLogoColor.withOpacity(0.6)
                  : Appcolors.appLogoColor.withOpacity(0.1),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Appcolors.appLogoColor.withOpacity(0.1),
          ),
          child: isImage
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    file,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildFileIcon(path.extension(file.path)),
                  ),
                )
              : _buildFileIcon(path.extension(file.path)),
        ),
        title: Text(
          path.basename(file.path),
          style: TextStyle(color: Appcolors.appPrimaryColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${_getFileTypeLabel(file.path)} • ${_galleryService.getFileSize(file)}',
          style: TextStyle(color: Appcolors.appPrimaryColor.withOpacity(0.8)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Icon(Icons.check_circle, color: Appcolors.appLogoColor),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios,
                color: Appcolors.appPrimaryColor.withOpacity(0.7), size: 16),
          ],
        ),
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
          if (_selection.isSelectionMode) {
            _selection.toggleSelection(file.path);
            setState(() {});
          } else {
            _openFile(file);
          }
        },
        onLongPress: () {
          _selection.toggleSelection(file.path);
          _selection.isSelectionMode = true;
          setState(() {});
        },
      ),
    );
  }

  Widget _buildFileIcon(String ext) {
    IconData iconData;
    Color iconColor;

    if (['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'].contains(ext)) {
      iconData = Icons.image;
      iconColor = Colors.green;
    } else if (['.mp4', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v', '.mkv']
        .contains(ext)) {
      iconData = Icons.play_circle_fill;
      iconColor = Colors.red;
    } else {
      iconData = Icons.insert_drive_file;
      iconColor = Appcolors.appPrimaryColor.withOpacity(0.7);
    }

    return Center(
      child: Icon(iconData, size: 32, color: iconColor),
    );
  }

  String _getFileTypeLabel(String filePath) {
    String ext = path.extension(filePath).toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'].contains(ext)) {
      return 'Image';
    } else if (['.mp4', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v', '.mkv']
        .contains(ext)) {
      return 'Video';
    } else {
      return 'File';
    }
  }

  String _getFileDate(File file) {
    try {
      DateTime modified = file.statSync().modified;
      return '${modified.day}/${modified.month}/${modified.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  void _exitFullscreen() {
    setState(() {
      _isFullscreen = false;
    });
  }

  @override
  void dispose() {
    print('Gallery: Disposing gallery for ${widget.downloadPath}');

    try {
      _filesSubscription?.cancel();
    } catch (e) {
      print('Gallery: Error canceling file subscription: $e');
    }

    try {
      _galleryService.stopWatching(widget.downloadPath);
    } catch (e) {
      print('Gallery: Error stopping gallery service: $e');
    }

    try {
      _searchController.dispose();
      _focusNode.dispose();
      _fadeController.dispose();
      _slideController.dispose();
      _fullscreenController?.dispose();
    } catch (e) {
      print('Gallery: Error disposing controllers: $e');
    }

    print('Gallery: Dispose completed for ${widget.downloadPath}');
    super.dispose();
  }
}

// Statistics Item Widget
class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  TextStyle(color: Appcolors.appPrimaryColor.withOpacity(0.8))),
          Text(value,
              style: TextStyle(
                  color: Appcolors.appPrimaryColor,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// Fullscreen Image Viewer
class _FullscreenImageViewer extends StatefulWidget {
  final List<String> imagePaths;
  final int initialIndex;
  final VoidCallback onClose;

  const _FullscreenImageViewer({
    required this.imagePaths,
    required this.initialIndex,
    required this.onClose,
  });

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  late PageController _pageController;
  int _currentIndex = 0;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    // Request focus for keyboard navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowRight:
        case LogicalKeyboardKey.arrowDown:
          _navigateToNext();
          break;
        case LogicalKeyboardKey.arrowLeft:
        case LogicalKeyboardKey.arrowUp:
          _navigateToPrevious();
          break;
        case LogicalKeyboardKey.escape:
          widget.onClose();
          break;
        case LogicalKeyboardKey.space:
          _navigateToNext();
          break;
      }
    }
  }

  void _navigateToNext() {
    if (_currentIndex < widget.imagePaths.length - 1) {
      _pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _navigateToPrevious() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        _handleKeyEvent(event);
        return KeyEventResult.handled;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PhotoViewGallery.builder(
              pageController: _pageController,
              itemCount: widget.imagePaths.length,
              builder: (context, index) {
                return PhotoViewGalleryPageOptions(
                  imageProvider: FileImage(File(widget.imagePaths[index])),
                  initialScale: PhotoViewComputedScale.contained,
                  minScale: PhotoViewComputedScale.contained * 0.5,
                  maxScale: PhotoViewComputedScale.covered * 3,
                  heroAttributes:
                      PhotoViewHeroAttributes(tag: widget.imagePaths[index]),
                );
              },
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              backgroundDecoration: BoxDecoration(color: Colors.black),
              loadingBuilder: (context, event) => Center(
                child: CircularProgressIndicator(
                  color: Appcolors.appLogoColor,
                  value: event == null
                      ? 0
                      : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
                ),
              ),
            ),
            // Left Navigation Arrow
            if (_currentIndex > 0)
              Positioned(
                left: 20,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: _navigateToPrevious,
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            // Right Navigation Arrow
            if (_currentIndex < widget.imagePaths.length - 1)
              Positioned(
                right: 20,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: _navigateToNext,
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            // Keyboard Instructions (appears briefly)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '← → Arrow keys to navigate • ESC to close • Space for next',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            // Top Controls
            Positioned(
              top: 40,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: widget.onClose,
                      icon: Icon(Icons.close, color: Colors.white, size: 28),
                    ),
                    Text(
                      '${_currentIndex + 1} / ${widget.imagePaths.length}',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    IconButton(
                      onPressed: () async {
                        await Share.shareXFiles(
                            [XFile(widget.imagePaths[_currentIndex])]);
                      },
                      icon: Icon(Icons.share, color: Colors.white, size: 28),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom Info
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  path.basename(widget.imagePaths[_currentIndex]),
                  style: TextStyle(color: Colors.white, fontSize: 14),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ), // Close Scaffold body Stack
      ), // Close Scaffold
    ); // Close Focus widget
  }

  @override
  void dispose() {
    _pageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

// System Video Player Screen (opens with system default player)
class VideoPlayerScreen extends StatefulWidget {
  final String videoPath;

  const VideoPlayerScreen({required this.videoPath, Key? key})
      : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-open with system player when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openWithSystemPlayer();
    });
  }

  void _openWithSystemPlayer() async {
    try {
      if (Platform.isMacOS) {
        await Process.start('open', [widget.videoPath]);
      } else if (Platform.isWindows) {
        await Process.start('start', [widget.videoPath], runInShell: true);
      } else if (Platform.isLinux) {
        await Process.start('xdg-open', [widget.videoPath]);
      }

      // After opening system player, pop this screen
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Error opening video with system player: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: Text(
          path.basename(widget.videoPath),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await Share.shareXFiles([XFile(widget.videoPath)]);
            },
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: 'Share video',
          ),
          IconButton(
            onPressed: _openWithSystemPlayer,
            icon: const Icon(Icons.open_in_new, color: Colors.white),
            tooltip: 'Open with system player',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_file_outlined,
              size: 120,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Video Player',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              path.basename(widget.videoPath),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _openWithSystemPlayer,
              icon: const Icon(Icons.play_arrow, size: 28),
              label: const Text('Open with System Player',
                  style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Appcolors.appLogoColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Opens video in your default video player app\n✅ Supports all video formats\n✅ Works on macOS and Windows',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

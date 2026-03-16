import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/consistent_gesture_handler.dart';
import '../widgets/human_error_handler.dart';
import '../services/smart_cache_manager.dart';

/// FIXED: Download Manager Screen dengan proper header
///
/// Fixes:
/// - Header tidak double
/// - Proper layout untuk download items
/// - Consistent UI dengan app theme
class DownloadManagerScreen extends StatefulWidget {
  const DownloadManagerScreen({super.key});

  @override
  State<DownloadManagerScreen> createState() => _DownloadManagerScreenState();
}

class _DownloadManagerScreenState extends State<DownloadManagerScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<DownloadItem> _downloads = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDownloads();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDownloads() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Simulate loading downloads from cache/storage
      await Future.delayed(const Duration(milliseconds: 500));

      // TODO: Load actual downloads from storage
      setState(() {
        _downloads = _getMockDownloads();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      // FIXED: Single app bar - no double header
      appBar: AppBar(
        title: Text(
          'Downloads',
          style: AppTheme.titleStyle.copyWith(color: AppTheme.primaryTextColor),
        ),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.primaryTextColor,
        elevation: AppTheme.smElevation,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryTextColor,
          labelStyle: AppTheme.captionStyle.copyWith(
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelColor: AppTheme.secondaryTextColor,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.clear_all, color: AppTheme.primaryTextColor),
            onPressed: _clearCompleted,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildActiveDownloads(), _buildCompletedDownloads()],
      ),
    );
  }

  Widget _buildActiveDownloads() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
        ),
      );
    }

    final activeDownloads = _downloads.where((d) => !d.isCompleted).toList();

    if (activeDownloads.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.download_outlined,
              size: 64,
              color: AppTheme.secondaryTextColor,
            ),
            const SizedBox(height: AppTheme.smSpacing),
            Text(
              'No active downloads',
              style: AppTheme.bodyStyle.copyWith(
                color: AppTheme.secondaryTextColor,
              ),
            ),
            const SizedBox(height: AppTheme.smSpacing),
            Text(
              'Start downloading from post details',
              style: AppTheme.captionStyle.copyWith(
                color: AppTheme.secondaryTextColor,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.mdPadding),
      itemCount: activeDownloads.length,
      itemBuilder: (context, index) =>
          _buildDownloadItem(activeDownloads[index]),
    );
  }

  Widget _buildCompletedDownloads() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
        ),
      );
    }

    final completedDownloads = _downloads.where((d) => d.isCompleted).toList();

    if (completedDownloads.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.task_alt_outlined,
              size: 64,
              color: AppTheme.secondaryTextColor,
            ),
            const SizedBox(height: AppTheme.smSpacing),
            Text(
              'No completed downloads',
              style: AppTheme.bodyStyle.copyWith(
                color: AppTheme.secondaryTextColor,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.mdPadding),
      itemCount: completedDownloads.length,
      itemBuilder: (context, index) =>
          _buildDownloadItem(completedDownloads[index]),
    );
  }

  Widget _buildDownloadItem(DownloadItem download) {
    return Card(
      color: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.mdRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.mdPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File info
            Row(
              children: [
                // File icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: download.isVideo
                        ? Colors.red.withOpacity(0.2)
                        : Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(AppTheme.smRadius),
                  ),
                  child: Icon(
                    download.isVideo ? Icons.videocam : Icons.image,
                    color: download.isVideo ? Colors.red : Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppTheme.mdSpacing),

                // File details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        download.fileName,
                        style: AppTheme.bodyStyle.copyWith(
                          color: AppTheme.primaryTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: AppTheme.xsSpacing),
                      Text(
                        download.fileSize,
                        style: AppTheme.captionStyle.copyWith(
                          color: AppTheme.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // Status icon
                Icon(
                  download.isCompleted
                      ? Icons.check_circle
                      : download.isDownloading
                      ? Icons.downloading
                      : Icons.schedule,
                  color: download.isCompleted
                      ? AppTheme.successColor
                      : download.isDownloading
                      ? AppTheme.primaryColor
                      : AppTheme.secondaryTextColor,
                  size: 24,
                ),
              ],
            ),

            const SizedBox(height: AppTheme.smSpacing),

            // Progress bar (for active downloads)
            if (!download.isCompleted) ...[
              LinearProgressIndicator(
                value: download.progress,
                backgroundColor: AppTheme.cardColor,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: AppTheme.xsSpacing),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(download.progress * 100).toInt()}%',
                    style: AppTheme.captionStyle.copyWith(
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                  Text(
                    download.speed,
                    style: AppTheme.captionStyle.copyWith(
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ],

            // Action buttons
            const SizedBox(height: AppTheme.smSpacing),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!download.isCompleted) ...[
                  // Pause/Resume button
                  IconButton(
                    icon: Icon(
                      download.isPaused ? Icons.play_arrow : Icons.pause,
                      color: AppTheme.primaryColor,
                    ),
                    onPressed: () => _togglePauseResume(download),
                  ),

                  // Cancel button
                  IconButton(
                    icon: Icon(Icons.close, color: AppTheme.errorColor),
                    onPressed: () => _cancelDownload(download),
                  ),
                ] else ...[
                  // Open button
                  IconButton(
                    icon: Icon(Icons.open_in_new, color: AppTheme.primaryColor),
                    onPressed: () => _openFile(download),
                  ),

                  // Delete button
                  IconButton(
                    icon: Icon(Icons.delete, color: AppTheme.errorColor),
                    onPressed: () => _deleteFile(download),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _togglePauseResume(DownloadItem download) {
    HapticFeedback.lightImpact();
    setState(() {
      download.isPaused = !download.isPaused;
      download.isDownloading = !download.isPaused;
    });

    // TODO: Implement actual pause/resume logic
  }

  void _cancelDownload(DownloadItem download) {
    HapticFeedback.mediumImpact();
    setState(() {
      _downloads.remove(download);
    });

    // TODO: Implement actual cancel logic
  }

  void _openFile(DownloadItem download) {
    HapticFeedback.lightImpact();
    // TODO: Implement open file logic
  }

  void _deleteFile(DownloadItem download) {
    HapticFeedback.heavyImpact();
    setState(() {
      _downloads.remove(download);
    });

    // TODO: Implement actual file deletion
  }

  void _clearCompleted() {
    HapticFeedback.mediumImpact();
    setState(() {
      _downloads.removeWhere((d) => d.isCompleted);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Completed downloads cleared'),
        backgroundColor: AppTheme.successColor,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.smRadius),
        ),
      ),
    );
  }

  List<DownloadItem> _getMockDownloads() {
    return [
      DownloadItem(
        id: '1',
        fileName: 'video_001.mp4',
        fileSize: '125.4 MB',
        isVideo: true,
        progress: 0.75,
        speed: '2.5 MB/s',
        isDownloading: true,
        isPaused: false,
        isCompleted: false,
      ),
      DownloadItem(
        id: '2',
        fileName: 'image_gallery_001.zip',
        fileSize: '45.2 MB',
        isVideo: false,
        progress: 1.0,
        speed: '0 B/s',
        isDownloading: false,
        isPaused: false,
        isCompleted: true,
      ),
      DownloadItem(
        id: '3',
        fileName: 'video_002.mp4',
        fileSize: '89.7 MB',
        isVideo: true,
        progress: 0.25,
        speed: '1.8 MB/s',
        isDownloading: true,
        isPaused: false,
        isCompleted: false,
      ),
    ];
  }
}

/// Download item model
class DownloadItem {
  final String id;
  final String fileName;
  final String fileSize;
  final bool isVideo;
  double progress;
  String speed;
  bool isDownloading;
  bool isPaused;
  bool isCompleted;

  DownloadItem({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.isVideo,
    required this.progress,
    required this.speed,
    required this.isDownloading,
    required this.isPaused,
    required this.isCompleted,
  });
}

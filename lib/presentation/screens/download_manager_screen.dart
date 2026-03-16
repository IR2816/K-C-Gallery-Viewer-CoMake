import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/download_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_state_widgets.dart';

const _kDownloadFolderPath = '/storage/emulated/0/Download/KC Download';

class DownloadManagerScreen extends StatefulWidget {
  const DownloadManagerScreen({super.key});

  @override
  State<DownloadManagerScreen> createState() => _DownloadManagerScreenState();
}

class _DownloadManagerScreenState extends State<DownloadManagerScreen> {
  List<FileSystemEntity> _downloadedFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDownloadedFiles();
  }

  Future<void> _loadDownloadedFiles() async {
    setState(() => _isLoading = true);
    try {
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory(_kDownloadFolderPath);
      } else {
        final base = await getDownloadsDirectory();
        if (base != null) dir = Directory('${base.path}/KC Download');
      }

      if (dir != null && await dir.exists()) {
        final files = await dir.list().toList();
        setState(() {
          _downloadedFiles = files.whereType<File>().toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _downloadedFiles = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading downloads: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        title: const Text('Download Manager'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.green.withValues(alpha: 0.8),
                Colors.green.withValues(alpha: 0.6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        actions: [
          IconButton(
            onPressed: _loadDownloadedFiles,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<DownloadProvider>(
        builder: (context, downloadProvider, child) {
          final activeDownloads = downloadProvider.activeDownloads;

          if (_isLoading) {
            return Column(
              children: [
                if (activeDownloads.isNotEmpty)
                  _buildActiveDownloadsSection(
                    activeDownloads,
                    downloadProvider,
                  ),
                const Expanded(child: AppSkeletonList()),
              ],
            );
          }

          return Column(
            children: [
              // Active Downloads Section
              if (activeDownloads.isNotEmpty)
                _buildActiveDownloadsSection(activeDownloads, downloadProvider),

              // Completed Downloads Section
              Expanded(
                child: _downloadedFiles.isEmpty
                    ? _buildEmptyState()
                    : _buildFileList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActiveDownloadsSection(
    List<DownloadItem> activeDownloads,
    DownloadProvider downloadProvider,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.download_for_offline, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Text(
                'Active Downloads (${activeDownloads.length})',
                style: AppTheme.titleStyle.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (activeDownloads.isNotEmpty)
                TextButton(
                  onPressed: () {
                    for (final download in activeDownloads) {
                      downloadProvider.cancelDownload(download.id);
                    }
                  },
                  child: const Text(
                    'Cancel All',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...activeDownloads.map(
            (download) => _buildActiveDownloadItem(download, downloadProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveDownloadItem(
    DownloadItem download,
    DownloadProvider downloadProvider,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getStatusIcon(download.status),
                color: _getStatusColor(download.status),
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  download.name,
                  style: AppTheme.bodyStyle.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (download.status == DownloadStatus.downloading)
                Text(
                  '${(download.progress * 100).toInt()}%',
                  style: AppTheme.captionStyle.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (download.status == DownloadStatus.pending)
                IconButton(
                  onPressed: () => downloadProvider.cancelDownload(download.id),
                  icon: const Icon(Icons.cancel, color: Colors.red, size: 16),
                  tooltip: 'Cancel',
                ),
            ],
          ),

          if (download.status == DownloadStatus.downloading) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: download.progress,
              backgroundColor: Colors.grey.withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatFileSize(download.downloadedBytes),
                  style: AppTheme.captionStyle.copyWith(
                    color: AppTheme.getOnSurfaceColor(
                      context,
                    ).withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  download.totalBytes > 0
                      ? _formatFileSize(download.totalBytes)
                      : 'Unknown size',
                  style: AppTheme.captionStyle.copyWith(
                    color: AppTheme.getOnSurfaceColor(
                      context,
                    ).withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],

          if (download.status == DownloadStatus.failed &&
              download.errorMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              download.errorMessage!,
              style: AppTheme.captionStyle.copyWith(color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getStatusIcon(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.pending:
        return Icons.schedule;
      case DownloadStatus.downloading:
        return Icons.downloading;
      case DownloadStatus.completed:
        return Icons.check_circle;
      case DownloadStatus.failed:
        return Icons.error;
      case DownloadStatus.cancelled:
        return Icons.cancel;
    }
  }

  Color _getStatusColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.pending:
        return Colors.orange;
      case DownloadStatus.downloading:
        return Colors.green;
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.failed:
        return Colors.red;
      case DownloadStatus.cancelled:
        return Colors.grey;
    }
  }

  Widget _buildEmptyState() {
    return AppEmptyState(
      icon: Icons.download_outlined,
      title: 'No downloaded files yet',
      message: 'Download files from posts to see them here',
      actionLabel: 'Back to Posts',
      onAction: () => Navigator.pop(context),
      accentColor: Colors.green,
    );
  }

  Widget _buildFileList() {
    return Column(
      children: [
        // Header with count
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.folder, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Text(
                '${_downloadedFiles.length} files',
                style: AppTheme.captionStyle.copyWith(
                  color: AppTheme.getOnSurfaceColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                'KC_Gallery_Downloads',
                style: AppTheme.captionStyle.copyWith(
                  color: AppTheme.getOnSurfaceColor(
                    context,
                  ).withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),

        // File list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _downloadedFiles.length,
            itemBuilder: (context, index) {
              final file = _downloadedFiles[index] as File;
              return _buildFileCard(file, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFileCard(File file, int index) {
    final fileName = file.path.split('/').last;
    final fileSize = file.lengthSync();
    final lastModified = file.lastModifiedSync();
    final isImage = _isImageFile(fileName);
    final isVideo = _isVideoFile(fileName);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isImage
                ? Colors.blue.withValues(alpha: 0.1)
                : isVideo
                ? Colors.red.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isImage
                ? Icons.image
                : isVideo
                ? Icons.videocam
                : Icons.insert_drive_file,
            color: isImage
                ? Colors.blue
                : isVideo
                ? Colors.red
                : Colors.grey,
            size: 24,
          ),
        ),
        title: Text(
          fileName,
          style: AppTheme.bodyStyle.copyWith(
            color: AppTheme.getOnSurfaceColor(context),
            fontWeight: FontWeight.w500,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.storage,
                  size: 12,
                  color: AppTheme.getOnSurfaceColor(
                    context,
                  ).withValues(alpha: 0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatFileSize(fileSize),
                  style: AppTheme.captionStyle.copyWith(
                    color: AppTheme.getOnSurfaceColor(
                      context,
                    ).withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.schedule,
                  size: 12,
                  color: AppTheme.getOnSurfaceColor(
                    context,
                  ).withValues(alpha: 0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDate(lastModified),
                  style: AppTheme.captionStyle.copyWith(
                    color: AppTheme.getOnSurfaceColor(
                      context,
                    ).withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _openFile(file),
              icon: Icon(Icons.open_in_new, color: Colors.green, size: 20),
              tooltip: 'Open',
            ),
            IconButton(
              onPressed: () => _deleteFile(file, index),
              icon: Icon(Icons.delete_outline, color: Colors.red, size: 20),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }

  bool _isImageFile(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension);
  }

  bool _isVideoFile(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    return ['mp4', 'avi', 'mov', 'mkv', 'webm', 'flv'].contains(extension);
  }

  String _formatFileSize(int bytes) {
    if (bytes == 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    int unitIndex = 0;
    double size = bytes.toDouble();

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    return '${size.toStringAsFixed(unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _openFile(File file) async {
    try {
      // Try using url_launcher with file URI first (works for some file types)
      final uri = Uri.file(file.path);
      bool launched = false;
      try {
        if (await canLaunchUrl(uri)) {
          launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {}

      if (!launched && mounted) {
        // Fallback: show share dialog with path info
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File saved at: ${file.path}'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(label: 'Copy Path', onPressed: () {}),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteFile(File file, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text(
          'Are you sure you want to delete ${file.path.split('/').last}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await file.delete();
        setState(() {
          _downloadedFiles.removeAt(index);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting file: $e')));
        }
      }
    }
  }
}

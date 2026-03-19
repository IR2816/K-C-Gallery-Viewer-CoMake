//video_player_screen.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../widgets/app_video_player.dart';
import '../theme/app_theme.dart';
import '../providers/download_provider.dart';

/// Dedicated Video Player Screen untuk Post Detail
///
/// Optimized untuk single video playback dengan:
/// - Full screen video player
/// - Proper video controls
/// - Loading states
/// - Error handling
/// - Back navigation
class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String videoName;
  final String apiSource;

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.videoName,
    required this.apiSource,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  bool _isLoading = true;
  String? _error;
  int _reloadToken = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final isCoomer =
        widget.apiSource.toLowerCase() == 'coomer' ||
        widget.videoUrl.toLowerCase().contains('coomer.');

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Base background
          Positioned.fill(child: Container(color: Colors.black)),

          // Video Player fills the whole screen
          Positioned.fill(
            child: ClipRect(
              child: AppVideoPlayer(
                key: ValueKey('video-${widget.videoUrl}-$_reloadToken'),
                url: widget.videoUrl,
                apiSource: widget.apiSource,
                width: screenSize.width,
                height: screenSize.height,
                autoplay: true,
                showControls: true,
                showLoading: true,
                showError: false,
                onLoadingChanged: (loading) {
                  if (!mounted) return;
                  setState(() => _isLoading = loading);
                },
                onError: (error) {
                  if (!mounted) return;
                  setState(() {
                    _error = error;
                    _isLoading = false;
                  });
                },
              ),
            ),
          ),

          // UI overlays stay on top of the constrained video
          if (_error == null)
            Align(
              alignment: Alignment.topCenter,
              child: _buildTopBar(isCoomer),
            ),
          if (_error == null)
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildMediaInfoCard(),
            ),

          // Loading overlay
          if (_isLoading) _buildLoadingOverlay(),

          // Error overlay
          if (_error != null) _buildErrorOverlay(),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: tooltip ?? '',
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isCoomer) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            _buildIconButton(
              icon: Icons.arrow_back,
              onTap: () => Navigator.pop(context),
              tooltip: 'Back',
            ),
            const SizedBox(width: 10),
            Expanded(child: _buildSourceChip(isCoomer)),
            const SizedBox(width: 10),
            _buildIconButton(
              icon: Icons.download,
              onTap: _downloadVideo,
              tooltip: 'Download Video',
            ),
            const SizedBox(width: 10),
            _buildIconButton(
              icon: Icons.share,
              onTap: _shareVideo,
              tooltip: 'Share Video',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceChip(bool isCoomer) {
    final sourceLabel = isCoomer ? 'COOMER' : 'KEMONO';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.play_circle_fill, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Text(
            '$sourceLabel VIDEO',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaInfoCard() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        14,
        0,
        14,
        40 + MediaQuery.of(context).padding.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          // Add a subtle shadow for better readability
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.movie, color: Colors.white70, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _getCleanVideoName(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 16),
            Text(
              'Loading video...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.92),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Failed to load video',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _retryLoading,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCleanVideoName() {
    // Clean video name untuk display
    final name = widget.videoName;
    if (name.length <= 30) return name;

    // Truncate jika terlalu panjang
    return '${name.substring(0, 27)}...';
  }

  Future<void> _downloadVideo() async {
    final url = widget.videoUrl;
    final fileName = widget.videoName.isEmpty ? 'video.mp4' : widget.videoName;

    try {
      Directory? downloadsDirectory;
      if (Platform.isAndroid) {
        downloadsDirectory = Directory(
          '/storage/emulated/0/Download/KC Download',
        );
      } else {
        final dir = await getDownloadsDirectory();
        if (dir != null) {
          downloadsDirectory = Directory('${dir.path}/KC Download');
        }
      }

      if (downloadsDirectory == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not access Downloads directory'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (!await downloadsDirectory.exists()) {
        await downloadsDirectory.create(recursive: true);
      }

      final savePath = '${downloadsDirectory.path}/$fileName';

      if (!mounted) return;
      // Route through DownloadProvider so progress shows in Download Manager
      context.read<DownloadProvider>().addDownload(
        name: fileName,
        url: url,
        savePath: savePath,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download started: $fileName — check Download Manager'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _shareVideo() async {
    try {
      // Copy video URL to clipboard
      await Clipboard.setData(ClipboardData(text: widget.videoUrl));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video link copied to clipboard!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share video: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _retryLoading() {
    setState(() {
      _isLoading = true;
      _error = null;
      _reloadToken++;
    });
  }
}

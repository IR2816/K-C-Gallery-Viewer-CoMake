import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/api_source.dart';
import 'video_player_screen.dart';
import '../../utils/logger.dart';
import '../widgets/app_video_player.dart';
import '../providers/download_provider.dart';
import '../providers/settings_provider.dart';

class FullscreenMediaViewer extends StatefulWidget {
  final List<Map<String, dynamic>> mediaItems;
  final int initialIndex;
  final ApiSource apiSource;

  /// Optional post context used when "Organize by Creator" is enabled.
  final String? postCreator;
  final String? postDate;
  final String? postTitle;

  const FullscreenMediaViewer({
    super.key,
    required this.mediaItems,
    required this.initialIndex,
    required this.apiSource,
    this.postCreator,
    this.postDate,
    this.postTitle,
  });

  @override
  State<FullscreenMediaViewer> createState() => _FullscreenMediaViewerState();
}

class _FullscreenMediaViewerState extends State<FullscreenMediaViewer>
    with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentIndex = 0;
  bool _showUI = true;

  // Animation for showing/hiding the overlay UI
  late AnimationController _uiController;
  late Animation<double> _uiAnimation;

  // Drag-to-dismiss tracking
  double _dragOffsetY = 0;

  // Dot indicator sizing constants
  static const double _activeDotWidth = 18.0;
  static const double _inactiveDotSize = 7.0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    _uiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1.0, // start visible
    );
    _uiAnimation = CurvedAnimation(
      parent: _uiController,
      curve: Curves.easeInOut,
    );

    _scheduleAutoHide();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _uiController.dispose();
    super.dispose();
  }

  // ─── UI visibility ────────────────────────────────────────────────────────

  void _scheduleAutoHide() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _showUI) _hideUI();
    });
  }

  void _showUIWithAutoHide() {
    if (!_showUI) {
      setState(() => _showUI = true);
      _uiController.forward();
    }
    _scheduleAutoHide();
  }

  void _hideUI() {
    if (!mounted) return;
    setState(() => _showUI = false);
    _uiController.reverse();
  }

  void _toggleUI() {
    if (_showUI) {
      _hideUI();
    } else {
      _showUIWithAutoHide();
    }
  }

  // ─── Navigation ───────────────────────────────────────────────────────────

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
  }

  void _close() => Navigator.pop(context);

  // ─── Actions ──────────────────────────────────────────────────────────────

  Future<void> _shareMedia(Map<String, dynamic> mediaItem) async {
    final url = (mediaItem['url'] ?? '').toString();
    if (url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Media link copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        // Vertical drag to dismiss (swipe down)
        onVerticalDragUpdate: (details) {
          setState(() => _dragOffsetY += details.delta.dy);
        },
        onVerticalDragEnd: (details) {
          // Only dismiss on a clear downward swipe (positive Y = downward).
          final vel = details.primaryVelocity ?? 0;
          if (_dragOffsetY > 80 || (vel > 600)) {
            Navigator.pop(context);
          } else {
            setState(() => _dragOffsetY = 0);
          }
        },
        onTap: _toggleUI,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: Matrix4.translationValues(0, _dragOffsetY, 0),
          child: Stack(
            children: [
              _buildMediaArea(),
              _buildTopScrim(),
              _buildBottomScrim(),
              _buildOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  // Top gradient scrim for readability
  Widget _buildTopScrim() => Positioned(
    top: 0,
    left: 0,
    right: 0,
    height: 130,
    child: IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.55),
              Colors.transparent,
            ],
          ),
        ),
      ),
    ),
  );

  // Bottom gradient scrim for readability
  Widget _buildBottomScrim() => Positioned(
    bottom: 0,
    left: 0,
    right: 0,
    height: 130,
    child: IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.6),
              Colors.transparent,
            ],
          ),
        ),
      ),
    ),
  );

  // ─── Media area ───────────────────────────────────────────────────────────

  Widget _buildMediaArea() {
    final imageItems = widget.mediaItems
        .where((m) => m['type'] != 'video')
        .toList();

    // If all items are images, use the optimized PhotoViewGallery
    if (imageItems.length == widget.mediaItems.length) {
      return PhotoViewGallery.builder(
        pageController: _pageController,
        itemCount: widget.mediaItems.length,
        onPageChanged: _onPageChanged,
        scrollPhysics: const BouncingScrollPhysics(),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        builder: (context, index) {
          final item = widget.mediaItems[index];
          final imageUrl = (item['url'] ?? '').toString();
          AppLogger.debug(
            '🔍 DEBUG: FullscreenMediaViewer loading image: $imageUrl',
          );
          return PhotoViewGalleryPageOptions(
            imageProvider: CachedNetworkImageProvider(
              imageUrl,
              headers: _buildImageHeaders(imageUrl),
            ),
            initialScale: PhotoViewComputedScale.contained,
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 4.0,
            heroAttributes: PhotoViewHeroAttributes(tag: imageUrl),
            errorBuilder: (context, error, stackTrace) {
              AppLogger.debug(
                '🔍 DEBUG: FullscreenMediaViewer image load error: $error',
              );
              AppLogger.debug('🔍 DEBUG: Failed URL was: $imageUrl');
              return _buildImageError(imageUrl);
            },
          );
        },
        loadingBuilder: (context, event) => Center(
          child: SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              value: (event == null || event.expectedTotalBytes == null)
                  ? null
                  : event.cumulativeBytesLoaded /
                        event.expectedTotalBytes!,
              strokeWidth: 3,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
    }

    // Mixed images + videos — fall back to PageView
    return PageView.builder(
      controller: _pageController,
      onPageChanged: _onPageChanged,
      itemCount: widget.mediaItems.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final item = widget.mediaItems[index];
        if (item['type'] == 'video') return _buildVideoPlayer(item);

        final imageUrl = (item['url'] ?? '').toString();
        return PhotoView(
          imageProvider: CachedNetworkImageProvider(
            imageUrl,
            headers: _buildImageHeaders(imageUrl),
          ),
          initialScale: PhotoViewComputedScale.contained,
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 4.0,
          heroAttributes: PhotoViewHeroAttributes(tag: imageUrl),
          loadingBuilder: (context, event) => Center(
            child: SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                value: (event == null || event.expectedTotalBytes == null)
                    ? null
                    : event.cumulativeBytesLoaded /
                          event.expectedTotalBytes!,
                strokeWidth: 3,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
          errorBuilder: (context, error, stackTrace) =>
              _buildImageError(imageUrl),
        );
      },
    );
  }

  Widget _buildImageError(String imageUrl) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 56),
          const SizedBox(height: 12),
          const Text(
            'Failed to load image',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              imageUrl,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Returns CDN-appropriate HTTP headers for [url] so both Coomer and Kemono
  /// media load correctly (both CDNs require a matching Referer/Origin).
  static Map<String, String>? _buildImageHeaders(String url) {
    if (url.contains('coomer.st')) {
      return const {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'image/avif,image/webp,image/*,*/*;q=0.8',
        'Referer': 'https://coomer.st/',
        'Origin': 'https://coomer.st',
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive',
      };
    }
    if (url.contains('kemono.cr') || url.contains('kemono.su')) {
      return const {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'image/avif,image/webp,image/*,*/*;q=0.8',
        'Referer': 'https://kemono.cr/',
        'Origin': 'https://kemono.cr',
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive',
      };
    }
    return null;
  }

  Widget _buildVideoPlayer(Map<String, dynamic> mediaItem) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaSize = MediaQuery.sizeOf(context);
        final width =
            constraints.hasBoundedWidth && constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : mediaSize.width;
        final height =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : mediaSize.height;

        return Container(
          color: Colors.black,
          child: AppVideoPlayer(
            url: mediaItem['url'],
            apiSource: widget.apiSource.name,
            width: width,
            height: height,
            autoplay: true,
            showControls: true,
            showLoading: true,
            showError: true,
          ),
        );
      },
    );
  }

  // ─── Overlay ──────────────────────────────────────────────────────────────

  Widget _buildOverlay() {
    final currentMedia = widget.mediaItems[_currentIndex];
    final isVideo = currentMedia['type'] == 'video';
    final isCoomerVideo = isVideo && widget.apiSource == ApiSource.coomer;

    if (isCoomerVideo) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _uiAnimation,
      child: Stack(
        children: [
          _buildTopBar(currentMedia),
          _buildBottomBar(currentMedia),
        ],
      ),
    );
  }

  // ─── Top bar ──────────────────────────────────────────────────────────────

  Widget _buildTopBar(Map<String, dynamic> mediaItem) {
    final isVideo = mediaItem['type'] == 'video';
    final rawName = mediaItem['name'];
    final title = rawName != null
        ? _getFileName(rawName.toString())
        : (isVideo ? 'Video' : 'Image');

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              // Close
              _glassButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: _close,
              ),
              const SizedBox(width: 10),
              // Title
              Expanded(
                child: _glassPill(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Download
              _glassButton(
                icon: Icons.download_rounded,
                onTap: () => _downloadMedia(mediaItem),
              ),
              const SizedBox(width: 8),
              // Share / copy link
              _glassButton(
                icon: Icons.link_rounded,
                onTap: () => _shareMedia(mediaItem),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Bottom bar ───────────────────────────────────────────────────────────

  Widget _buildBottomBar(Map<String, dynamic> mediaItem) {
    final isVideo = mediaItem['type'] == 'video';
    final total = widget.mediaItems.length;

    if (isVideo || total <= 1) return const SizedBox.shrink();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dot indicators (max 20 dots; beyond that show text counter)
              if (total <= 20) _buildDotIndicators(total),
              // Numeric counter
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _glassPill(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Text(
                    '${_currentIndex + 1} / $total',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDotIndicators(int total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i == _currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? _activeDotWidth : _inactiveDotSize,
          height: _inactiveDotSize,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  // ─── Reusable glass widgets ───────────────────────────────────────────────

  Widget _glassButton({
    required IconData icon,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(
                alpha: enabled ? 0.18 : 0.06,
              ),
            ),
          ),
          child: Icon(
            icon,
            color: enabled ? Colors.white : Colors.white38,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _glassPill({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 10,
    ),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  // ─── Utilities ────────────────────────────────────────────────────────────

  String _getFileName(String fullFileName) {
    final parts = fullFileName.split('/');
    return parts.isNotEmpty ? parts.last : fullFileName;
  }

  /// Open video player dari gallery
  // ignore: unused_element
  void _openVideoPlayer(Map<String, dynamic> mediaItem) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          videoUrl: mediaItem['url'],
          videoName: mediaItem['name'] ?? 'Video',
          apiSource: widget.apiSource.name,
        ),
      ),
    );
  }

  Future<void> _downloadMedia(Map<String, dynamic> mediaItem) async {
    final url = (mediaItem['url'] ?? '').toString();
    if (url.isEmpty) return;

    final fileName = _getFileName(
      (mediaItem['name'] ?? url).toString(),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting download: $fileName…'),
        backgroundColor: const Color(0xFF1565C0),
        behavior: SnackBarBehavior.floating,
      ),
    );

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
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      if (!await downloadsDirectory.exists()) {
        await downloadsDirectory.create(recursive: true);
      }

      // Optionally organize into {creator}/{date}_{title}/ subfolders.
      Directory saveDir = downloadsDirectory;
      final settings = context.read<SettingsProvider>();
      if (settings.organizeDownloads &&
          widget.postCreator != null &&
          widget.postDate != null &&
          widget.postTitle != null) {
        final sub = Directory(
          '${downloadsDirectory.path}/${widget.postCreator}/${widget.postDate}_${widget.postTitle}',
        );
        if (!await sub.exists()) {
          await sub.create(recursive: true);
        }
        saveDir = sub;
      }

      final savePath = '${saveDir.path}/$fileName';

      // Use the correct CDN referer so the download provider sends the right
      // anti-hotlink header (fixes Kemono downloads that previously got 403).
      final referer = widget.apiSource == ApiSource.coomer
          ? 'https://coomer.st/'
          : 'https://kemono.cr/';

      if (!mounted) return;
      // Route through DownloadProvider so progress shows in Download Manager
      context.read<DownloadProvider>().addDownload(
        name: fileName,
        url: url,
        savePath: savePath,
        referer: referer,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download queued: $fileName — check Download Manager'),
          backgroundColor: const Color(0xFF1565C0),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

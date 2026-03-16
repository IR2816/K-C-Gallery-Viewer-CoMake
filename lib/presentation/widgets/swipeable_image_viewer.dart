import 'package:flutter/material.dart';
import 'package:kc_gallery_viewer/domain/entities/post.dart';
import 'package:kc_gallery_viewer/domain/entities/api_source.dart';
import 'package:kc_gallery_viewer/presentation/widgets/image_viewer_final.dart';
import 'package:kc_gallery_viewer/utils/logger.dart';

/// 🎯 SwipeableImageViewer - Gambar bisa swipe untuk lihat semua media
///
/// Fitur:
/// - Swipe antar gambar/video
/// - Page indicators
/// - Support mixed media (images & videos)
/// - Fullscreen dengan proper navigation
class SwipeableImageViewer extends StatefulWidget {
  final Post post;
  final ApiSource apiSource;
  final int initialIndex;

  const SwipeableImageViewer({
    super.key,
    required this.post,
    required this.apiSource,
    this.initialIndex = 0,
  });

  @override
  State<SwipeableImageViewer> createState() => _SwipeableImageViewerState();
}

class _SwipeableImageViewerState extends State<SwipeableImageViewer> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  late List<MediaItem> _mediaItems;

  @override
  void initState() {
    super.initState();
    _prepareMediaItems();
    _currentIndex = widget.initialIndex;

    // Jump to initial index
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients && _currentIndex < _mediaItems.length) {
        _pageController.jumpToPage(_currentIndex);
      }
    });
  }

  void _prepareMediaItems() {
    _mediaItems = [];

    // Add thumbnail if available
    final thumbnailUrl = widget.post.getThumbnailUrl(widget.apiSource);
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      _mediaItems.add(
        MediaItem(type: MediaType.image, path: thumbnailUrl, isThumbnail: true),
      );
    }

    // Add files if available
    for (final file in widget.post.file) {
      if (file.path.isNotEmpty) {
        final isVideo = _isVideoFile(file.path);
        _mediaItems.add(
          MediaItem(
            type: isVideo ? MediaType.video : MediaType.image,
            path: file.path,
            isThumbnail: false,
          ),
        );
      }
    }

    // Add attachments
    for (final attachment in widget.post.attachments) {
      if (attachment.path.isNotEmpty) {
        final isVideo = _isVideoFile(attachment.path);
        _mediaItems.add(
          MediaItem(
            type: isVideo ? MediaType.video : MediaType.image,
            path: attachment.path,
            isThumbnail: false,
          ),
        );
      }
    }

    AppLogger.info(
      'SwipeableImageViewer: Prepared ${_mediaItems.length} media items',
      tag: 'ImageViewer',
    );
  }

  bool _isVideoFile(String path) {
    final extension = path.toLowerCase().split('.').last;
    return ['mp4', 'webm', 'mov', 'avi', 'mkv', 'm3u8'].contains(extension);
  }

  @override
  Widget build(BuildContext context) {
    if (_mediaItems.isEmpty) {
      return _buildEmptyState();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1}/${_mediaItems.length}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser, color: Colors.white),
            onPressed: _openCurrentInBrowser,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content with swipe
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemCount: _mediaItems.length,
            itemBuilder: (context, index) {
              final mediaItem = _mediaItems[index];
              return _buildMediaItem(mediaItem);
            },
          ),

          // Page indicators
          if (_mediaItems.length > 1) _buildPageIndicator(),
        ],
      ),
    );
  }

  Widget _buildMediaItem(MediaItem mediaItem) {
    return Container(
      color: Colors.black,
      child: Center(
        child: ImageViewerFinal(
          url: mediaItem.path,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.contain,
          isThumbnail: false, // Always show original in fullscreen
          apiSource: widget.apiSource.name,
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          _mediaItems.length,
          (index) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: index == _currentIndex ? 12 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: index == _currentIndex ? Colors.white : Colors.white38,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('No Media', style: TextStyle(color: Colors.white)),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 64, color: Colors.white54),
            SizedBox(height: 16),
            Text(
              'No media available',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCurrentInBrowser() {
    if (_currentIndex < _mediaItems.length) {
      final mediaItem = _mediaItems[_currentIndex];
      AppLogger.info(
        'Opening media in browser: ${mediaItem.path}',
        tag: 'ImageViewer',
      );
      // TODO: Implement url_launcher
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class MediaItem {
  final MediaType type;
  final String path;
  final bool isThumbnail;

  MediaItem({
    required this.type,
    required this.path,
    required this.isThumbnail,
  });
}

enum MediaType { image, video }

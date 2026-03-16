import 'package:flutter/material.dart';

// Domain
import 'package:kc_gallery_viewer/domain/entities/post.dart';
import 'package:kc_gallery_viewer/domain/entities/api_source.dart';

// Widgets
import 'package:kc_gallery_viewer/widgets/optimized_media_loader.dart';
import 'package:kc_gallery_viewer/utils/logger.dart';

/// Swipeable Media Gallery for Post Detail
/// Allows swiping between multiple images/videos in a post
class SwipeableMediaGallery extends StatefulWidget {
  final Post post;
  final String? apiSource;
  final Function(int)? onPageChanged;

  const SwipeableMediaGallery({
    super.key,
    required this.post,
    this.apiSource,
    this.onPageChanged,
  });

  @override
  State<SwipeableMediaGallery> createState() => _SwipeableMediaGalleryState();
}

class _SwipeableMediaGalleryState extends State<SwipeableMediaGallery> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  late List<MediaItem> _mediaItems;

  @override
  void initState() {
    super.initState();
    _prepareMediaItems();
  }

  void _prepareMediaItems() {
    _mediaItems = [];

    // Add thumbnail if available
    final thumbnailUrl = widget.post.getThumbnailUrl(
      widget.apiSource == 'kemono' ? ApiSource.kemono : ApiSource.coomer,
    );
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
      'SwipeableGallery: Prepared ${_mediaItems.length} media items',
      tag: 'Gallery',
    );
  }

  bool _isVideoFile(String path) {
    final extension = path.toLowerCase().split('.').last;
    return ['mp4', 'webm', 'mov', 'avi', 'mkv'].contains(extension);
  }

  @override
  Widget build(BuildContext context) {
    if (_mediaItems.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // Main media viewer with swipe
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
              widget.onPageChanged?.call(index);
            },
            itemCount: _mediaItems.length,
            itemBuilder: (context, index) {
              final mediaItem = _mediaItems[index];
              return _buildMediaItem(mediaItem);
            },
          ),
        ),

        // Page indicator
        if (_mediaItems.length > 1) _buildPageIndicator(),
      ],
    );
  }

  Widget _buildMediaItem(MediaItem mediaItem) {
    return Container(
      color: Colors.black,
      child: Center(
        child: AutoMediaWidget(
          mediaPath: mediaItem.path,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.contain,
          isThumbnail: false, // Always show original media in gallery
          apiSource: widget.apiSource,
          // Tambahkan post untuk swipeable viewer
          post: widget.post,
          errorWidget: _buildMediaErrorWidget(mediaItem),
        ),
      ),
    );
  }

  Widget _buildMediaErrorWidget(MediaItem mediaItem) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              mediaItem.type == MediaType.video
                  ? Icons.videocam_off
                  : Icons.broken_image,
              size: 64,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            Text(
              mediaItem.type == MediaType.video
                  ? 'Video unavailable'
                  : 'Image unavailable',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_currentIndex + 1}/${_mediaItems.length}',
              style: const TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.black54,
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
    return Container(
      color: Colors.black,
      child: const Center(
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

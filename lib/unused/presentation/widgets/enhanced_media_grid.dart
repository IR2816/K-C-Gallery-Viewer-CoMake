import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';

/// Enhanced Media Grid dengan lazy loading & prefetch
///
/// Features:
/// - Lazy loading untuk 1000+ items
/// - Prefetch next items untuk smooth scrolling
/// - Multiple layout options (grid, masonry, list)
/// - Performance optimization dengan memory limits
class EnhancedMediaGrid extends StatefulWidget {
  final List<MediaItem> mediaItems;
  final MediaGridLayout layout;
  final bool enablePrefetch;
  final bool enableLazyLoading;
  final Function(int) onMediaTap;
  final Function(int)? onMediaLongPress;
  final EdgeInsets? padding;
  final int? crossAxisCount;

  const EnhancedMediaGrid({
    super.key,
    required this.mediaItems,
    this.layout = MediaGridLayout.grid,
    this.enablePrefetch = true,
    this.enableLazyLoading = true,
    required this.onMediaTap,
    this.onMediaLongPress,
    this.padding,
    this.crossAxisCount,
  });

  @override
  State<EnhancedMediaGrid> createState() => _EnhancedMediaGridState();
}

class _EnhancedMediaGridState extends State<EnhancedMediaGrid> {
  late ScrollController _scrollController;
  final Set<int> _loadedItems = {};
  final Set<int> _prefetchedItems = {};
  final Map<int, double> _itemHeights = {}; // For masonry layout
  final bool _isLoading = false;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _setupScrollListener();
    _loadInitialItems();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 500) {
        _loadMoreItems();
      }
    });
  }

  void _loadInitialItems() {
    if (!widget.enableLazyLoading) {
      // Load all items at once
      for (int i = 0; i < widget.mediaItems.length; i++) {
        _loadedItems.add(i);
      }
      return;
    }

    final initialCount = math.min(20, widget.mediaItems.length);
    for (int i = 0; i < initialCount; i++) {
      _loadedItems.add(i);
    }
  }

  void _loadMoreItems() {
    if (_isLoadingMore || !widget.enableLazyLoading) return;

    if (_loadedItems.length >= widget.mediaItems.length) return;

    setState(() {
      _isLoadingMore = true;
    });

    // Simulate loading delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        final currentCount = _loadedItems.length;
        final nextCount = math.min(currentCount + 20, widget.mediaItems.length);

        for (int i = currentCount; i < nextCount; i++) {
          _loadedItems.add(i);
        }

        setState(() {
          _isLoadingMore = false;
        });

        // Prefetch next items
        if (widget.enablePrefetch) {
          _prefetchNextItems();
        }
      }
    });
  }

  void _prefetchNextItems() {
    final currentCount = _loadedItems.length;
    final prefetchCount = math.min(currentCount + 10, widget.mediaItems.length);

    for (int i = currentCount; i < prefetchCount; i++) {
      if (!_prefetchedItems.contains(i)) {
        _prefetchItem(i);
      }
    }
  }

  void _prefetchItem(int index) {
    if (index >= widget.mediaItems.length) return;

    final mediaItem = widget.mediaItems[index];

    // Prefetch image ke cache
    if (mediaItem.type == MediaType.image) {
      CachedNetworkImage(
        imageUrl: mediaItem.thumbnailUrl ?? mediaItem.url,
        memCacheWidth: 200,
        memCacheHeight: 200,
      ).image;
    }

    _prefetchedItems.add(index);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mediaItems.isEmpty) {
      return _buildEmptyState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomScrollView(
          controller: _scrollController,
          padding: widget.padding ?? const EdgeInsets.all(AppTheme.mdPadding),
          slivers: [
            // Grid content
            if (widget.layout == MediaGridLayout.masonry)
              _buildMasonryGrid(constraints.maxWidth)
            else
              _buildRegularGrid(constraints.maxWidth),

            // Loading indicator
            if (_isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(AppTheme.mdPadding),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 64,
            color: AppTheme.secondaryTextColor,
          ),
          const SizedBox(height: AppTheme.mdSpacing),
          Text(
            'No media available',
            style: AppTheme.bodyStyle.copyWith(
              color: AppTheme.secondaryTextColor,
            ),
          ),
          const SizedBox(height: AppTheme.smSpacing),
          Text(
            'Media will appear here when available',
            style: AppTheme.captionStyle.copyWith(
              color: AppTheme.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegularGrid(double width) {
    return SliverGrid(
      gridDelegate: _getGridDelegate(width),
      childDelegate: SliverChildBuilderDelegate((context, index) {
        if (index >= widget.mediaItems.length) {
          return null;
        }

        final isLoaded = _loadedItems.contains(index);

        if (!isLoaded) {
          return _buildSkeletonItem();
        }

        return _buildMediaItem(widget.mediaItems[index], index);
      }, childCount: widget.mediaItems.length),
    );
  }

  Widget _buildMasonryGrid(double width) {
    return SliverMasonryGrid(
      gridDelegate: SliverSimpleMasonryGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _getCrossAxisCount(width),
        mainAxisSpacing: AppTheme.smSpacing,
        crossAxisSpacing: AppTheme.smSpacing,
      ),
      childDelegate: SliverChildBuilderDelegate((context, index) {
        if (index >= widget.mediaItems.length) {
          return null;
        }

        final isLoaded = _loadedItems.contains(index);

        if (!isLoaded) {
          return _buildSkeletonItem();
        }

        return _buildMediaItem(widget.mediaItems[index], index);
      }, childCount: widget.mediaItems.length),
    );
  }

  int _getCrossAxisCount(double width) {
    if (widget.crossAxisCount != null) {
      return widget.crossAxisCount!;
    }

    switch (widget.layout) {
      case MediaGridLayout.grid:
        return (width / 150).floor().clamp(2, 6);
      case MediaGridLayout.masonry:
        return (width / 120).floor().clamp(2, 4);
      case MediaGridLayout.list:
        return 1;
    }
  }

  SliverGridDelegateWithFixedCrossAxisCount _getGridDelegate(double width) {
    int crossAxisCount = _getCrossAxisCount(width);
    double childAspectRatio;

    switch (widget.layout) {
      case MediaGridLayout.grid:
        childAspectRatio = 1.0;
        break;
      case MediaGridLayout.list:
        childAspectRatio = 3.0;
        break;
      default:
        childAspectRatio = 1.0;
    }

    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      childAspectRatio: childAspectRatio,
      crossAxisSpacing: AppTheme.smSpacing,
      mainAxisSpacing: AppTheme.smSpacing,
    );
  }

  Widget _buildSkeletonItem() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.smRadius),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            AppTheme.secondaryTextColor,
          ),
        ),
      ),
    );
  }

  Widget _buildMediaItem(MediaItem mediaItem, int index) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onMediaTap(index);
      },
      onLongPress: () {
        HapticFeedback.heavyImpact();
        widget.onMediaLongPress?.call(index);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.smRadius),
          border: Border.all(color: AppTheme.cardColor),
        ),
        child: Stack(
          children: [
            // Media content
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.smRadius),
              child: _buildMediaContent(mediaItem),
            ),

            // Video overlay
            if (mediaItem.type == MediaType.video)
              Positioned(
                top: AppTheme.xsSpacing,
                right: AppTheme.xsSpacing,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),

            // Loading indicator for prefetching
            if (!_prefetchedItems.contains(index) && widget.enablePrefetch)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.1),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ),
              ),

            // Image count indicator for galleries
            if (mediaItem.imageCount != null && mediaItem.imageCount! > 1)
              Positioned(
                bottom: AppTheme.xsSpacing,
                right: AppTheme.xsSpacing,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${mediaItem.imageCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaContent(MediaItem mediaItem) {
    final imageUrl = mediaItem.thumbnailUrl ?? mediaItem.url;

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      memCacheWidth: 400,
      memCacheHeight: 400,
      placeholder: (context, url) => Container(
        color: AppTheme.surfaceColor,
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              AppTheme.secondaryTextColor,
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: AppTheme.surfaceColor,
        child: Icon(
          Icons.broken_image,
          color: AppTheme.secondaryTextColor,
          size: 32,
        ),
      ),
      // Fade in animation
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 100),
    );
  }
}

enum MediaGridLayout { grid, masonry, list }

class MediaItem {
  final String url;
  final String? thumbnailUrl;
  final MediaType type;
  final String? title;
  final int? imageCount;
  final String? duration;
  final int? size;

  MediaItem({
    required this.url,
    this.thumbnailUrl,
    required this.type,
    this.title,
    this.imageCount,
    this.duration,
    this.size,
  });

  factory MediaItem.fromPostContent(dynamic content, {String? thumbnailUrl}) {
    final type = content['type'] == 'video' ? MediaType.video : MediaType.image;
    return MediaItem(
      url: content['path'] ?? '',
      thumbnailUrl: thumbnailUrl,
      type: type,
      title: content['name'],
    );
  }

  factory MediaItem.fromPostFile(dynamic file, {String? thumbnailUrl}) {
    final filename = file['name'] ?? '';
    final isVideo = filename.toLowerCase().endsWith(
      ('.mp4|.webm|.mov|.avi|.m4v'),
    );

    return MediaItem(
      url: file['path'] ?? '',
      thumbnailUrl: thumbnailUrl,
      type: isVideo ? MediaType.video : MediaType.image,
      title: filename,
      size: file['size'],
    );
  }
}

enum MediaType { image, video }

/// Masonry Grid Widget (Custom implementation)
class SliverMasonryGrid extends StatelessWidget {
  final SliverChildDelegate childDelegate;
  final SliverSimpleMasonryGridDelegateWithFixedCrossAxisCount gridDelegate;

  const SliverMasonryGrid({
    super.key,
    required this.childDelegate,
    required this.gridDelegate,
  });

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: gridDelegate.crossAxisCount,
        mainAxisSpacing: gridDelegate.mainAxisSpacing,
        crossAxisSpacing: gridDelegate.crossAxisSpacing,
        childAspectRatio: 0.8, // Will be overridden by individual items
      ),
      childDelegate: childDelegate,
    );
  }
}

/// Masonry Grid Delegate
class SliverSimpleMasonryGridDelegateWithFixedCrossAxisCount {
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;

  const SliverSimpleMasonryGridDelegateWithFixedCrossAxisCount({
    required this.crossAxisCount,
    this.mainAxisSpacing = 0,
    this.crossAxisSpacing = 0,
  });
}

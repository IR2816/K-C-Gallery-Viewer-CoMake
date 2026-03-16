import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../domain/entities/post.dart';
import '../../domain/entities/api_source.dart';
import '../../presentation/providers/posts_provider.dart';
import '../../presentation/providers/smart_bookmark_provider.dart';
import '../../presentation/providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/media_resolver.dart';
import 'fullscreen_media_viewer.dart';
import 'video_player_screen.dart';
import 'creator_detail_screen.dart';
import '../../data/models/bookmark_model.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;
  final ApiSource apiSource;
  final bool isFromSavedPosts;

  const PostDetailScreen({
    super.key,
    required this.post,
    required this.apiSource,
    this.isFromSavedPosts = false,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen>
    with TickerProviderStateMixin {
  // Core Controllers
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;

  // State Management
  final bool _showFullText = false;
  int _currentMediaIndex = 0;
  bool _isLoading = false;
  String? _error;
  bool _showAllMedia = false; // NEW: State untuk expand/collapse all media

  // Full post data from single post API
  Post? _fullPost;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Load full post data only if not from saved posts
    if (!widget.isFromSavedPosts) {
      _loadFullPost();
    } else {
      // For saved posts, use the post directly as it's already complete
      setState(() {
        _fullPost = widget.post;
        _isLoading = false;
      });
    }
  }

  /// Load full post data from single post API
  Future<void> _loadFullPost({bool isRefresh = false}) async {
    // Don't show loading for refresh, only for initial load
    if (!isRefresh) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final postsProvider = context.read<PostsProvider>();

      // Add retry mechanism for Coomer domain issues
      int retryCount = 0;
      const maxRetries = 3;

      while (retryCount <= maxRetries) {
        try {
          await postsProvider.loadSinglePost(
            widget.post.service,
            widget.post.user,
            widget.post.id,
            apiSource: widget.apiSource, // Pass correct API source
          );

          // If successful, break the retry loop
          break;
        } catch (e) {
          retryCount++;
          print('🔍 DEBUG: Load attempt $retryCount failed: $e');

          if (retryCount > maxRetries) {
            rethrow; // Re-throw if max retries exceeded
          }

          // Wait before retry with exponential backoff
          await Future.delayed(Duration(milliseconds: 500 * retryCount));
        }
      }

      // Get the full post from provider
      final fullPost = postsProvider.posts.firstWhere(
        (p) => p.id == widget.post.id,
        orElse: () => widget.post,
      );

      setState(() {
        _fullPost = fullPost;
        _isLoading = false;
        _error = null; // Clear error on successful refresh
      });

      // DEBUG: Print full post information
      print('=== DEBUG: FULL POST INFORMATION ===');
      print('Full post content length: ${_fullPost?.content.length}');
      print('Full post attachments count: ${_fullPost?.attachments.length}');
      print('Full post files count: ${_fullPost?.file.length}');
      print('=== END FULL POST DEBUG ===');

      // Show success message for refresh
      if (isRefresh) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post refreshed successfully'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _fullPost = widget.post; // Fallback to original post
      });

      print('=== DEBUG: LOAD FULL POST ERROR ===');
      print('Error: $e');
      print('=== END ERROR DEBUG ===');

      // Show error message for refresh
      if (isRefresh) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh: $e'),
            backgroundColor: AppTheme.errorColor,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _loadFullPost(isRefresh: true),
            ),
          ),
        );
      }
    }
  }

  /// Get current post (full post if available, otherwise original post)
  Post get _currentPost => _fullPost ?? widget.post;

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // BUILD METHOD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.apiSource == ApiSource.kemono ? 'Kemono' : 'Coomer',
          style: AppTheme.titleStyle.copyWith(color: AppTheme.primaryTextColor),
        ),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.primaryTextColor,
        elevation: 0,
        actions: [
          // Refresh Button (NEW)
          if (!widget.isFromSavedPosts) // Only show for non-saved posts
            IconButton(
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryColor,
                      ),
                    )
                  : const Icon(Icons.refresh, color: AppTheme.primaryTextColor),
              onPressed: _isLoading
                  ? null
                  : () => _loadFullPost(isRefresh: true),
              tooltip: 'Refresh Post',
            ),

          // Bookmark Button
          Consumer<SmartBookmarkProvider>(
            builder: (context, bookmarkProvider, child) {
              final isBookmarked = bookmarkProvider.isBookmarkedByType(
                BookmarkType.post,
                widget.post.id,
              );
              return IconButton(
                icon: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: isBookmarked
                      ? AppTheme.primaryColor
                      : AppTheme.primaryTextColor,
                ),
                onPressed: () => _toggleBookmark(bookmarkProvider),
                tooltip: isBookmarked ? 'Remove from Saved' : 'Save Post',
              );
            },
          ),

          // Download Button
          IconButton(
            icon: Icon(Icons.download, color: AppTheme.primaryTextColor),
            onPressed: _downloadPost,
            tooltip: 'Download in Browser',
          ),

          // Share Button
          IconButton(
            icon: Icon(Icons.share, color: AppTheme.primaryTextColor),
            onPressed: _sharePost,
            tooltip: 'Share Post',
          ),
        ],
      ),
      body: widget.isFromSavedPosts
          ? SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Creator + Title + Meta (HEADER)
                  _buildCreatorHeader(),

                  // MEDIA SECTION (FOCUS)
                  _buildMediaSection(),

                  // CONTENT SECTION
                  _buildPostContent(),

                  // TAGS SECTION
                  _buildTagsSection(),

                  // ACTIONS SECTION
                  _buildActionArea(),
                ],
              ),
            )
          : _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppTheme.errorColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading post',
                    style: AppTheme.titleStyle.copyWith(
                      color: AppTheme.errorColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: AppTheme.captionStyle.copyWith(
                      color: AppTheme.secondaryTextColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _loadFullPost(isRefresh: true),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _loadFullPost(isRefresh: true),
              child: SingleChildScrollView(
                controller: _scrollController,
                physics:
                    const AlwaysScrollableScrollPhysics(), // Enable pull-to-refresh
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Creator + Title + Meta (HEADER)
                    _buildCreatorHeader(),

                    // MEDIA SECTION (FOCUS)
                    _buildMediaSection(),

                    // CONTENT SECTION
                    _buildPostContent(),

                    // TAGS SECTION
                    _buildTagsSection(),

                    // ACTIONS SECTION
                    _buildActionArea(),
                  ],
                ),
              ),
            ),
    );
  }

  // 🎯 WIDGET BUILDERS

  /// Build Creator Header - Minimal & Clean
  Widget _buildCreatorHeader() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.mdPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Creator Name + Service Badge
          Row(
            children: [
              // Creator Name (Tappable)
              GestureDetector(
                onTap: () => _navigateToCreatorDetail(),
                child: Text(
                  _currentPost.user,
                  style: AppTheme.titleStyle.copyWith(
                    color: AppTheme.primaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Service Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getServiceColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getServiceColor().withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  _getServiceDisplayName(),
                  style: TextStyle(
                    color: _getServiceColor(),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Post Title (2-3 lines max)
          if (_currentPost.title.isNotEmpty)
            Text(
              _currentPost.title,
              style: AppTheme.titleStyle.copyWith(
                color: AppTheme.primaryTextColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

          // Date
          const SizedBox(height: 4),
          Text(
            _formatDate(_currentPost.published),
            style: AppTheme.bodyStyle.copyWith(
              color: AppTheme.secondaryTextColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Build Media Section - Progressive Disclosure dengan Expand/Collapse
  Widget _buildMediaSection() {
    // Collect and sort media items
    final mediaItems = _collectAndSortMedia();

    if (mediaItems.isEmpty) {
      return const SizedBox.shrink();
    }

    // Progressive disclosure logic
    const maxPreviewItems = 6;
    final hasManyItems = mediaItems.length > maxPreviewItems;
    final displayItems = _showAllMedia
        ? mediaItems // Show all when expanded
        : (hasManyItems
              ? mediaItems.take(maxPreviewItems).toList()
              : mediaItems); // Show preview when collapsed

    return Container(
      padding: const EdgeInsets.all(AppTheme.mdPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Modern Header with count
          _buildMediaHeader(mediaItems.length),
          const SizedBox(height: AppTheme.mdSpacing),

          // Media Grid (preview or all)
          _buildMediaGrid(displayItems, mediaItems.length),

          // Expand/Collapse button untuk post besar
          if (hasManyItems) ...[
            const SizedBox(height: AppTheme.mdSpacing),
            _buildExpandCollapseButton(mediaItems.length),
          ],
        ],
      ),
    );
  }

  /// Collect and sort media items dengan smart prioritization
  List<Map<String, dynamic>> _collectAndSortMedia() {
    final mediaItems = <Map<String, dynamic>>[];

    print('🔍 DEBUG: Collecting media from post');
    print('🔍 DEBUG: Attachments count = ${_currentPost.attachments.length}');
    print('🔍 DEBUG: File count = ${_currentPost.file.length}');

    // Collect from attachments
    for (final attachment in _currentPost.attachments) {
      if (_isMediaFile(attachment.name)) {
        final fullUrl = _buildFullUrl(attachment.path);
        mediaItems.add({
          'url': fullUrl,
          'name': attachment.name,
          'type': _getMediaType(attachment.name),
        });
        print('🔍 DEBUG: Added attachment media: ${attachment.name}');
      }
    }

    // Collect from file (FIX: Handle List<PostFile>)
    for (final file in _currentPost.file) {
      if (_isMediaFile(file.name)) {
        final fullUrl = _buildFullUrl(file.path);
        mediaItems.add({
          'url': fullUrl,
          'name': file.name,
          'type': _getMediaType(file.name),
        });
        print('🔍 DEBUG: Added file media: ${file.name}');
      }
    }

    print('🔍 DEBUG: Total media items collected = ${mediaItems.length}');

    // Smart sorting: prioritize images, limit videos in preview
    final sortedItems = _sortMediaForPreview(mediaItems);
    print('🔍 DEBUG: Final sorted media items = ${sortedItems.length}');

    return sortedItems;
  }

  /// Smart media sorting untuk optimal preview
  List<Map<String, dynamic>> _sortMediaForPreview(
    List<Map<String, dynamic>> mediaItems,
  ) {
    final images = <Map<String, dynamic>>[];
    final videos = <Map<String, dynamic>>[];

    // Separate images and videos
    for (final item in mediaItems) {
      if (item['type'] == 'video') {
        videos.add(item);
      } else {
        images.add(item);
      }
    }

    // Prioritize images for preview, keep videos limited
    final sortedItems = <Map<String, dynamic>>[];
    sortedItems.addAll(images); // All images first

    // Add max 2 videos to preview (video berat)
    if (videos.isNotEmpty) {
      sortedItems.addAll(videos.take(2));
      // Remaining videos will be in full gallery
      sortedItems.addAll(videos.skip(2));
    }

    return sortedItems;
  }

  /// Build modern media header
  Widget _buildMediaHeader(int totalItems) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.1),
            AppTheme.primaryColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.photo_library_outlined,
            color: AppTheme.primaryColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Media ($totalItems)',
            style: AppTheme.titleStyle.copyWith(
              color: AppTheme.primaryTextColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (_isCoomerService())
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Tooltip(
                message: 'Coomer CDN - May load slower',
                child: Icon(
                  Icons.speed,
                  color: Colors.orange.withOpacity(0.7),
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build media grid (preview or all items)
  Widget _buildMediaGrid(
    List<Map<String, dynamic>> displayItems,
    int totalItems,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: MasonryGridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: _getGridColumns(displayItems.length, totalItems),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          itemCount: displayItems.length,
          itemBuilder: (context, index) {
            final mediaItem = displayItems[index];
            final isVideo = mediaItem['type'] == 'video';

            return _buildMediaItem(mediaItem, index, isVideo, totalItems);
          },
        ),
      ),
    );
  }

  /// Build single media item (preview or full view)
  Widget _buildMediaItem(
    Map<String, dynamic> mediaItem,
    int index,
    bool isVideo,
    int totalItems,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Optimized media thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: _getMediaHeight(index, totalItems),
              width: double.infinity,
              child: _buildOptimizedMediaThumbnail(mediaItem, isVideo),
            ),
          ),

          // Video overlay
          if (isVideo)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withOpacity(0.4), Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.play_circle_filled,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),

          // Tap handler
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openMediaItem(mediaItem, index, isVideo),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build expand/collapse button
  Widget _buildExpandCollapseButton(int totalItems) {
    final isExpanded = _showAllMedia;
    final remainingItems = totalItems - 6; // Items hidden in preview

    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.1),
            AppTheme.primaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleShowAllMedia(),
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isExpanded
                      ? 'Show less media'
                      : 'Show all media ($totalItems)',
                  style: AppTheme.titleStyle.copyWith(
                    color: AppTheme.primaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!isExpanded && remainingItems > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '+$remainingItems',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Get grid columns based on item count and state
  int _getGridColumns(int displayCount, int totalCount) {
    if (_showAllMedia) {
      // When showing all media, use more columns for better layout
      if (displayCount <= 4) return 2;
      if (displayCount <= 9) return 3;
      return 4; // Max 4 columns untuk many items
    } else {
      // Preview mode - max 3 columns
      if (displayCount <= 2) return 2;
      if (displayCount <= 4) return 2;
      return 3;
    }
  }

  /// Get media height untuk visual variety
  double _getMediaHeight(int index, int totalItems) {
    if (_showAllMedia) {
      // More variety when showing all items
      final heights = [100, 120, 110, 130, 115, 125, 105, 135, 140];
      return heights[index % heights.length].toDouble();
    } else {
      // Preview heights
      final heights = [120, 140, 130, 150, 125, 135];
      return heights[index % heights.length].toDouble();
    }
  }

  /// Build Post Content - Text + Links
  Widget _buildPostContent() {
    final hasContent = _currentPost.content.isNotEmpty;

    if (!hasContent) {
      return const SizedBox.shrink();
    }

    // Clean HTML tags from content
    final cleanContent = _cleanHtmlContent(_currentPost.content);

    return Container(
      padding: const EdgeInsets.all(AppTheme.mdPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Content',
            style: AppTheme.titleStyle.copyWith(
              color: AppTheme.primaryTextColor,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          // Use Linkify for clickable links
          Linkify(
            text: cleanContent,
            style: AppTheme.bodyStyle.copyWith(
              color: AppTheme.primaryTextColor,
              fontSize: 14,
              height: 1.4,
            ),
            linkStyle: TextStyle(
              color: Colors.blue,
              decoration: TextDecoration.underline,
            ),
            onOpen: (link) async {
              if (await canLaunchUrl(Uri.parse(link.url))) {
                await launchUrl(
                  Uri.parse(link.url),
                  mode: LaunchMode.externalApplication,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  /// Build Action Area - Minimal & Clear
  Widget _buildActionArea() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.mdPadding),
      child: Row(
        children: [
          // Bookmark
          IconButton(
            onPressed: () {
              final bookmarkProvider = context.read<SmartBookmarkProvider>();
              _toggleBookmark(bookmarkProvider);
            },
            icon: Icon(
              _currentPost.saved ? Icons.bookmark : Icons.bookmark_border,
              color: _currentPost.saved
                  ? AppTheme.primaryColor
                  : AppTheme.secondaryTextColor,
            ),
          ),

          // Share
          IconButton(
            onPressed: _sharePost,
            icon: Icon(Icons.share, color: AppTheme.secondaryTextColor),
          ),

          // Open in Browser
          IconButton(
            onPressed: _downloadPost,
            icon: Icon(
              Icons.open_in_browser,
              color: AppTheme.secondaryTextColor,
            ),
          ),

          const Spacer(),

          // More options
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('More options coming soon!')),
              );
            },
            icon: Icon(Icons.more_vert, color: AppTheme.secondaryTextColor),
          ),
        ],
      ),
    );
  }

  /// Toggle show all media state
  void _toggleShowAllMedia() {
    setState(() {
      _showAllMedia = !_showAllMedia;
    });

    // Scroll to media section when expanding
    if (_showAllMedia) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    }

    // Save scroll position
    _saveScrollPosition();
  }

  /// Add current post to history
  void _addToHistory() async {
    try {
      final historyProvider = context.read<SmartHistoryProvider>();
      await historyProvider.addToHistory(
        type: 'post',
        itemId: widget.post.id,
        title: widget.post.title.isNotEmpty
            ? widget.post.title
            : 'Post ${widget.post.id}',
        creatorId: widget.post.user,
        creatorName: widget.post.user,
        metadata: {
          'service': widget.post.service,
          'apiSource': widget.apiSource.name,
          'published': widget.post.published.toIso8601String(),
          'mediaCount': _collectAndSortMedia().length,
        },
      );
    } catch (e) {
      debugPrint('Error adding to history: $e');
    }
  }

  /// Restore scroll position
  void _restoreScrollPosition() async {
    try {
      final scrollProvider = context.read<ScrollMemoryProvider>();
      final position = scrollProvider.getScrollPosition(
        'post_detail_${widget.post.id}',
      );

      if (position != null && position.offset > 0) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(position.offset);
          }
        });
      }

      // Restore media position
      final mediaPosition = scrollProvider.getMediaPosition(widget.post.id);
      if (mediaPosition != null) {
        setState(() {
          _currentMediaIndex = mediaPosition.mediaIndex;
        });
      }
    } catch (e) {
      debugPrint('Error restoring scroll position: $e');
    }
  }

  /// Save scroll position
  void _saveScrollPosition() async {
    try {
      final scrollProvider = context.read<ScrollMemoryProvider>();
      if (_scrollController.hasClients) {
        await scrollProvider.saveScrollPosition(
          screenKey: 'post_detail_${widget.post.id}',
          offset: _scrollController.offset,
          maxScrollExtent: _scrollController.position.maxScrollExtent,
          creatorId: widget.post.user,
          postId: widget.post.id,
        );
      }
    } catch (e) {
      debugPrint('Error saving scroll position: $e');
    }
  }

  /// Save media position when media index changes
  void _saveMediaPosition(int mediaIndex) async {
    try {
      final scrollProvider = context.read<ScrollMemoryProvider>();
      await scrollProvider.saveMediaPosition(
        postId: widget.post.id,
        mediaIndex: mediaIndex,
        creatorId: widget.post.user,
        scrollOffset: _scrollController.offset,
      );
    } catch (e) {
      debugPrint('Error saving media position: $e');
    }
  }

  /// Clean HTML tags from content
  String _cleanHtmlContent(String content) {
    try {
      // Parse HTML and extract text
      final document = html_parser.parse(content);
      String cleanText = document.body?.text ?? content;

      // Clean up extra whitespace
      cleanText = cleanText.replaceAll(RegExp(r'\s+'), ' ').trim();

      return cleanText;
    } catch (e) {
      // Fallback to original content if parsing fails
      print('Error cleaning HTML: $e');
      return content;
    }
  }

  /// Helper Methods
  bool _isCoomerService() {
    return _currentPost.service == 'onlyfans' ||
        _currentPost.service == 'fansly' ||
        _currentPost.service == 'candfans';
  }

  String _getServiceDisplayName() {
    switch (_currentPost.service.toLowerCase()) {
      case 'patreon':
        return 'Patreon';
      case 'fanbox':
        return 'Fanbox';
      case 'fantia':
        return 'Fantia';
      case 'onlyfans':
        return 'OnlyFans';
      case 'fansly':
        return 'Fansly';
      case 'candfans':
        return 'CandFans';
      default:
        return _currentPost.service.toUpperCase();
    }
  }

  Color _getServiceColor() {
    switch (_currentPost.service.toLowerCase()) {
      case 'patreon':
        return Colors.orange;
      case 'fanbox':
        return Colors.blue;
      case 'fantia':
        return Colors.purple;
      case 'onlyfans':
        return Colors.pink;
      case 'fansly':
        return Colors.teal;
      case 'candfans':
        return Colors.red;
      default:
        return AppTheme.primaryColor;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day} ${_getMonthName(date.month)} ${date.year}';
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  int _getCrossAxisCount(int mediaCount) {
    if (mediaCount == 1) return 1;
    if (mediaCount <= 3) return 2;
    if (mediaCount <= 6) return 3;
    return 4;
  }

  String _getMediaType(String filename) {
    final name = filename.toLowerCase();
    if (name.endsWith('.mp4') ||
        name.endsWith('.webm') ||
        name.endsWith('.mov') ||
        name.endsWith('.m3u8')) {
      return 'video';
    }
    return 'image';
  }

  bool _isMediaFile(String filename) {
    final name = filename.toLowerCase();
    return name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.gif') ||
        name.endsWith('.webp') ||
        name.endsWith('.mp4') ||
        name.endsWith('.webm') ||
        name.endsWith('.mov') ||
        name.endsWith('.m3u8');
  }

  String _buildFullUrl(String path) {
    if (path.startsWith('http')) {
      return path; // Already full URL
    }

    // Determine domain based on service
    String domain;
    if (_currentPost.service == 'onlyfans' ||
        _currentPost.service == 'fansly' ||
        _currentPost.service == 'candfans') {
      // Use CDN rotation for Coomer reliability
      domain = 'https://n2.coomer.st'; // Primary CDN
    } else {
      domain = 'https://kemono.cr'; // Kemono services
    }

    return '$domain/data$path';
  }

  /// Post Header with Creator Info
  Widget _buildPostHeader() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.mdPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Creator Info
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.cardColor,
                child: Text(
                  _currentPost.user.isNotEmpty
                      ? _currentPost.user[0].toUpperCase()
                      : '?',
                  style: AppTheme.bodyStyle.copyWith(
                    color: AppTheme.primaryTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.mdSpacing),

              // Creator Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Creator Name
                    Text(
                      _currentPost.user.isNotEmpty
                          ? _currentPost.user
                          : 'Unknown Creator',
                      style: AppTheme.titleStyle.copyWith(
                        color: AppTheme.primaryTextColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // Service Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: widget.apiSource == ApiSource.kemono
                            ? AppTheme.primaryColor.withOpacity(0.1)
                            : Colors.pink.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _currentPost.service.toUpperCase(),
                        style: AppTheme.captionStyle.copyWith(
                          color: widget.apiSource == ApiSource.kemono
                              ? AppTheme.primaryColor
                              : Colors.pink,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.mdSpacing),

          // Post Title
          Text(
            _currentPost.title.isNotEmpty
                ? _currentPost.title
                : 'Untitled Post',
            style: AppTheme.titleStyle.copyWith(
              color: AppTheme.primaryTextColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: AppTheme.smSpacing),

          // Post Metadata
          Row(
            children: [
              // Published Date
              Icon(
                Icons.schedule,
                size: 16,
                color: AppTheme.secondaryTextColor,
              ),
              const SizedBox(width: 4),
              Text(
                _formatDate(_currentPost.published),
                style: AppTheme.captionStyle.copyWith(
                  color: AppTheme.secondaryTextColor,
                ),
              ),

              const SizedBox(width: AppTheme.mdSpacing),

              // Post ID
              Icon(Icons.tag, size: 16, color: AppTheme.secondaryTextColor),
              const SizedBox(width: 4),
              Text(
                'ID: ${_currentPost.id}',
                style: AppTheme.captionStyle.copyWith(
                  color: AppTheme.secondaryTextColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostBody() {
    final contentText = _currentPost.content;
    if (contentText.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppTheme.mdPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Text(
            'Content',
            style: AppTheme.titleStyle.copyWith(
              color: AppTheme.primaryTextColor,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: AppTheme.mdSpacing),

          // Simple text display without PostBodyText
          Text(
            contentText,
            style: AppTheme.bodyStyle.copyWith(
              color: AppTheme.primaryTextColor,
              fontSize: 16,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// Build Tags Section
  Widget _buildTagsSection() {
    return Consumer<TagFilterProvider>(
      builder: (context, tagFilter, child) {
        return Container(
          padding: const EdgeInsets.all(AppTheme.mdPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Title
              Text(
                'Tags',
                style: AppTheme.titleStyle.copyWith(
                  color: AppTheme.primaryTextColor,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: AppTheme.mdSpacing),

              // Tags Wrap
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _currentPost.tags.map((tag) {
                  final isBlocked = tagFilter.isTagBlocked(tag);
                  return ActionChip(
                    label: Text(
                      '#$tag',
                      style: AppTheme.captionStyle.copyWith(
                        color: isBlocked ? Colors.white : AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    backgroundColor: isBlocked
                        ? AppTheme.errorColor
                        : AppTheme.surfaceColor,
                    onPressed: () {
                      _handleTagTap(tag);
                    },
                    pressElevation: 2,
                    tooltip: isBlocked
                        ? 'Blocked tag - Tap to search'
                        : 'Tap to search for #$tag',
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build Raw Links Section
  Widget _buildRawLinksSection() {
    final rawLinks = _extractRawLinks();

    if (rawLinks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.mdPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Raw Links',
                style: AppTheme.titleStyle.copyWith(
                  color: AppTheme.primaryTextColor,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.mdSpacing),

          // List of raw links with download buttons
          ...rawLinks.asMap().entries.map((entry) {
            final index = entry.key;
            final link = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Link URL
                    SelectableText(
                      link,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Action buttons
                    Row(
                      children: [
                        // Copy link button
                        IconButton(
                          onPressed: () => _copyToClipboard(link),
                          icon: Icon(
                            Icons.copy,
                            size: 16,
                            color: AppTheme.primaryColor,
                          ),
                          tooltip: 'Copy Link',
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Download in browser button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _downloadLinkInBrowser(link),
                            icon: Icon(Icons.download, size: 16),
                            label: Text(
                              'Download',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              minimumSize: Size(0, 32),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Extract raw links from post content
  List<String> _extractRawLinks() {
    final content = _currentPost.content;
    final links = <String>[];

    print('=== DEBUG: Extracting links from content ===');
    print('Content length: ${content.length}');
    print('Full content:');
    print(content);
    print('=== END CONTENT ===');

    // Use a single, more precise pattern for URLs
    final urlPattern = RegExp(r'''https?://[^\s<>"']+''', caseSensitive: false);

    final matches = urlPattern.allMatches(content);

    print('=== URL PATTERN MATCHES ===');
    for (final match in matches) {
      String url = match.group(0)!;
      print('Raw match: $url');

      // Clean the URL
      url = _cleanUrl(url);

      // Only add if it's a valid URL and not already in the list
      if (_isValidUrl(url) && !links.contains(url)) {
        links.add(url);
        print('Added cleaned URL: $url');
      } else {
        print('Skipped invalid or duplicate URL: $url');
      }
    }
    print('=== END URL MATCHES ===');

    print('=== FINAL RESULTS ===');
    print('Final links count: ${links.length}');
    for (int i = 0; i < links.length; i++) {
      print('Final Link $i: ${links[i]}');
    }
    print('=== END DEBUG ===');

    return links;
  }

  /// Clean URL by removing trailing punctuation and HTML artifacts
  String _cleanUrl(String url) {
    // Remove trailing punctuation
    url = url.replaceAll(RegExp(r'[.,;:!?)\]}]+$'), '');

    // Remove HTML entities and artifacts
    url = url.replaceAll(RegExp(r'''["'\'>]'''), '');

    // Remove HTML closing tags
    url = url.replaceAll(RegExp(r'</[^>]*>$'), '');

    return url.trim();
  }

  /// Check if URL is valid and complete
  bool _isValidUrl(String url) {
    if (url.isEmpty) return false;

    // Check if it's a proper URL
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAbsolutePath) return false;

    // Check if it has a proper domain
    if (!url.contains('://') || url.length < 10) return false;

    // Check if it's not just a partial URL
    if (url.endsWith('.com') || url.endsWith('.org') || url.endsWith('.net')) {
      return false; // Incomplete URL
    }

    return true;
  }

  // 🎯 HELPER METHODS

  /// Copy link to clipboard
  void _copyToClipboard(String link) async {
    try {
      await Clipboard.setData(ClipboardData(text: link));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Link copied to clipboard!'),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to copy link: $e'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  /// Download link in browser
  void _downloadLinkInBrowser(String link) async {
    try {
      if (await canLaunchUrl(Uri.parse(link))) {
        await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening link in browser...'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      } else {
        throw Exception('Cannot launch browser');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open browser: $e'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  /// Handle tag tap - navigate to tag search
  void _handleTagTap(String tag) {
    // TODO: Navigate to tag search screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Search for #$tag (coming soon)'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Navigate to creator detail
  void _navigateToCreatorDetail() {
    // Create a Creator object from post data
    final creator = Creator(
      id: _currentPost.user, // Use creator name as ID for navigation
      name: _currentPost.user,
      service: _currentPost.service,
      indexed: 0, // Default value
      updated: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      avatar: '', // No avatar available in post data
    );

    // Determine ApiSource from service
    ApiSource apiSource;
    switch (_currentPost.service.toLowerCase()) {
      case 'patreon':
      case 'fanbox':
      case 'fantia':
        apiSource = ApiSource.kemono;
        break;
      case 'onlyfans':
      case 'fansly':
      case 'candfans':
        apiSource = ApiSource.coomer;
        break;
      default:
        apiSource = ApiSource.kemono; // Default fallback
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CreatorDetailScreen(creator: creator, apiSource: apiSource),
      ),
    );
  }

  /// Toggle bookmark untuk post
  void _toggleBookmark(SmartBookmarkProvider bookmarkProvider) {
    final isBookmarked = bookmarkProvider.isBookmarkedByType(
      BookmarkType.post,
      widget.post.id,
    );

    if (isBookmarked) {
      // Remove bookmark
      final bookmark = bookmarkProvider.getBookmarkByType(
        BookmarkType.post,
        widget.post.id,
      );
      if (bookmark != null) {
        bookmarkProvider.removeBookmark(bookmark.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from Saved'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } else {
      // Add bookmark
      bookmarkProvider.addBookmarkWithParams(
        type: BookmarkType.post,
        targetId: widget.post.id,
        target: widget.post,
        title: widget.post.title.isNotEmpty
            ? _cleanHtmlContent(widget.post.title)
            : 'Post by ${widget.post.user}',
        creatorName: widget.post.user,
        creatorService: widget.post.service, // Save service info
        creatorId: widget.post.user,
        apiSource:
            widget.apiSource.name, // Save API source: 'kemono' or 'coomer'
        domain: widget.apiSource == ApiSource.kemono
            ? 'kemono.cr'
            : 'coomer.st', // Save domain
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Added to Saved'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  /// Download post
  void _downloadPost() async {
    try {
      // Build the post URL for browser
      final postUrl = _getPostUrl();

      if (await canLaunchUrl(Uri.parse(postUrl))) {
        await launchUrl(
          Uri.parse(postUrl),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open post: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  /// Get post URL for browser
  String _getPostUrl() {
    final domain = widget.apiSource == ApiSource.kemono
        ? 'https://kemono.cr'
        : 'https://coomer.st';

    return '$domain/${widget.post.service}/user/${widget.post.user}/post/${widget.post.id}';
  }

  /// Share post
  void _sharePost() async {
    try {
      final postUrl = _getPostUrl();
      await Clipboard.setData(ClipboardData(text: postUrl));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Post link copied to clipboard!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share post: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  /// Build optimized media thumbnail untuk Post Detail
  Widget _buildOptimizedMediaThumbnail(
    Map<String, dynamic> mediaItem,
    bool isVideo,
  ) {
    // Untuk video, gunakan placeholder dengan optimasi
    if (isVideo) {
      return _buildVideoThumbnail(mediaItem);
    }

    // Untuk gambar, gunakan optimized cached network image
    return _buildOptimizedImage(mediaItem['url']);
  }

  /// Build video thumbnail dengan placeholder
  Widget _buildVideoThumbnail(Map<String, dynamic> mediaItem) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey[800]!, Colors.grey[900]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Video icon
          const Center(
            child: Icon(
              Icons.play_circle_outline,
              color: Colors.white54,
              size: 48,
            ),
          ),

          // Video info
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Row(
              children: [
                // Video badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Video',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const Spacer(),

                // File size (jika ada)
                if (mediaItem['name'] != null)
                  Expanded(
                    child: Text(
                      _getFileName(mediaItem['name']),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 9,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build optimized image dengan caching
  Widget _buildOptimizedImage(String imageUrl) {
    return Image.network(
      imageUrl,
      width: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;

        // Show placeholder while loading
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Icon(
              Icons.image_not_supported,
              color: Colors.white54,
              size: 32,
            ),
          ),
        );
      },
      // Optimasi cache untuk Post Detail
      cacheWidth: 400, // Lebih besar untuk detail view
      cacheHeight: 600, // Tapi masih optimized
    );
  }

  /// Get clean file name
  String _getFileName(String fullFileName) {
    final parts = fullFileName.split('/');
    return parts.isNotEmpty ? parts.last : fullFileName;
  }

  /// Smart media item handler - bedakan video dan image
  void _openMediaItem(Map<String, dynamic> mediaItem, int index, bool isVideo) {
    print('🔍 DEBUG: Opening media item');
    print('🔍 DEBUG: Media type = ${isVideo ? 'video' : 'image'}');
    print('🔍 DEBUG: Media name = ${mediaItem['name']}');
    print('🔍 DEBUG: Media URL = ${mediaItem['url']}');

    // Save media position before opening
    _saveMediaPosition(index);

    if (isVideo) {
      print('🔍 DEBUG: Opening video player');
      _openVideoPlayer(mediaItem);
    } else {
      print('🔍 DEBUG: Opening fullscreen viewer');
      _openFullscreenViewer(index);
    }
  }

  /// Open fullscreen viewer untuk individual image
  void _openFullscreenViewer(int initialIndex) {
    // Collect all media items for proper indexing
    final allMediaItems = _collectAndSortMedia();

    if (allMediaItems.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullscreenMediaViewer(
          mediaItems: allMediaItems,
          initialIndex: initialIndex,
          apiSource: widget.apiSource,
        ),
      ),
    );
  }

  /// Open video player dengan optimasi
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
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../domain/entities/post.dart';
import '../../domain/entities/api_source.dart';
import '../../presentation/providers/posts_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/media_resolver.dart';
import 'fullscreen_media_viewer.dart';
import 'video_player_screen.dart';
import 'creator_detail_screen.dart';
import '../../data/models/bookmark_model.dart';

/// DEFINITIVE Post Detail Screen - Final Design Implementation
///
/// Follows the definitive design specification:
/// - Media preview max 6 items
/// - Fullscreen viewer for all media
/// - Text collapse
/// - Minimal AppBar
/// - Clean header
/// - Small tags
/// - Remember scroll position
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
  bool _isLoading = false;
  String? _error;
  bool _showAllMedia = false;

  // Cache media items to prevent infinite loop
  List<Map<String, dynamic>>? _cachedMediaItems;

  // Full post data from single post API
  Post? _fullPost;

  /// Get current post (full post if loaded, otherwise widget post)
  Post get _currentPost => _fullPost ?? widget.post;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Load full post data only if not from saved posts
    if (!widget.isFromSavedPosts) {
      _loadFullPost();
    } else {
      // For saved posts, use the widget post directly
      setState(() {
        _fullPost = widget.post;
        _isLoading = false;
      });
    }
  }

  /// Load full post data from provider
  Future<void> _loadFullPost() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final postsProvider = context.read<PostsProvider>();

      // Get the full post from provider
      final fullPost = postsProvider.posts.firstWhere(
        (p) => p.id == widget.post.id,
        orElse: () => widget.post,
      );

      setState(() {
        _fullPost = fullPost;
        _isLoading = false;
        _error = null;
        _cachedMediaItems = null; // Clear cache when post updates
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load post: $e';
        _isLoading = false;
      });
    }
  }

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
          // Refresh Button
          if (!widget.isFromSavedPosts)
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
              onPressed: _isLoading ? null : () => _loadFullPost(),
              tooltip: 'Refresh Post',
            ),
        ],
      ),
      body: _isLoading
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
                    onPressed: () => _loadFullPost(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _buildPostContent(),
    );
  }

  /// Build post content with final layout structure
  Widget _buildPostContent() {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Post Header
          _buildPostHeader(),

          // 2. Media Section (Preview - Max 6)
          _buildMediaSection(),

          // 3. Post Content (Text + Links)
          _buildPostContentSection(),

          // 4. Tags
          _buildTagsSection(),

          // 5. Actions / Footer
          _buildActionsSection(),

          const SizedBox(height: 32), // Bottom padding
        ],
      ),
    );
  }

  /// Build Post Header - Final Design (Clean, Information Only)
  Widget _buildPostHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Creator name (tap → Creator Detail)
          GestureDetector(
            onTap: _navigateToCreator,
            child: Row(
              children: [
                Text(
                  _currentPost.user,
                  style: AppTheme.titleStyle.copyWith(
                    color: Colors.blue,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                // Service badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getServiceColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.post.service.toUpperCase(),
                    style: TextStyle(
                      color: _getServiceColor(),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Post title (max 2-3 lines)
          Text(
            _currentPost.title,
            style: AppTheme.titleStyle.copyWith(
              color: AppTheme.primaryTextColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 8),

          // Publish date
          Text(
            _formatDate(_currentPost.published.toString().split(' ')[0]),
            style: AppTheme.bodyStyle.copyWith(
              color: AppTheme.secondaryTextColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Build Media Section - Final Design (Preview Max 6)
  Widget _buildMediaSection() {
    // Collect and sort media items
    final mediaItems = _collectAndSortMedia();

    if (mediaItems.isEmpty) {
      return const SizedBox.shrink();
    }

    const maxPreviewItems = 6;
    final hasManyItems = mediaItems.length > maxPreviewItems;
    final displayItems = _showAllMedia
        ? mediaItems // Show all when expanded
        : mediaItems
              .take(maxPreviewItems)
              .toList(); // Show preview when collapsed

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Media count header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Media (${mediaItems.length})',
                  style: AppTheme.titleStyle.copyWith(
                    color: AppTheme.primaryTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Media Grid (2 columns, thumbnail only)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: MasonryGridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              itemCount: displayItems.length,
              itemBuilder: (context, index) {
                final mediaItem = displayItems[index];
                final isVideo = mediaItem['type'] == 'video';

                return _buildMediaThumbnail(mediaItem, isVideo, index);
              },
            ),
          ),

          // "View all media" button if has many items
          if (hasManyItems && !_showAllMedia)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showAllMedia = true;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '+ ${mediaItems.length - maxPreviewItems} more',
                        style: AppTheme.bodyStyle.copyWith(
                          color: AppTheme.primaryTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.expand_more,
                        color: AppTheme.primaryTextColor,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // "Show less" button if expanded
          if (hasManyItems && _showAllMedia)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showAllMedia = false;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.expand_less,
                        color: AppTheme.primaryTextColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Show less',
                        style: AppTheme.bodyStyle.copyWith(
                          color: AppTheme.primaryTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Collect and sort media items with caching to prevent infinite loop
  List<Map<String, dynamic>> _collectAndSortMedia() {
    // Return cached items if available
    if (_cachedMediaItems != null) {
      print(
        '🔍 DEBUG: Using cached media items (${_cachedMediaItems!.length})',
      );
      return _cachedMediaItems!;
    }

    final mediaItems = <Map<String, dynamic>>[];

    print('🔍 DEBUG: Collecting media from post (CACHE MISS)');
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
    print('🔍 DEBUG: Caching media items for future use');

    // Cache the result
    _cachedMediaItems = mediaItems;

    return mediaItems;
  }

  /// Build Media Thumbnail - Final Design (Thumbnail Only, Tap → Fullscreen)
  Widget _buildMediaThumbnail(
    Map<String, dynamic> mediaItem,
    bool isVideo,
    int index,
  ) {
    return GestureDetector(
      onTap: () => _openFullscreenViewer(index),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              // Thumbnail
              SizedBox(
                height: 200,
                width: double.infinity,
                child: isVideo
                    ? _buildVideoThumbnail(mediaItem)
                    : _buildImageThumbnail(mediaItem['url']),
              ),

              // Video overlay (only for videos)
              if (isVideo)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.play_circle_filled,
                        color: Colors.white,
                        size: 48,
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

  /// Build video thumbnail with improved styling
  Widget _buildVideoThumbnail(Map<String, dynamic> mediaItem) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[300]!, Colors.grey[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Video icon
          const Center(
            child: Icon(
              Icons.play_circle_outline,
              color: Colors.white70,
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

                // File name
                if (mediaItem['name'] != null)
                  Expanded(
                    child: Text(
                      _getFileName(mediaItem['name']),
                      style: const TextStyle(
                        color: Colors.white70,
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

  /// Build image thumbnail with improved styling
  Widget _buildImageThumbnail(String imageUrl) {
    return Image.network(
      imageUrl,
      width: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(
              Icons.image_not_supported,
              color: Colors.grey,
              size: 32,
            ),
          ),
        );
      },
    );
  }

  /// Build post content with HTML rendering
  Widget _buildPostContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Content',
            style: AppTheme.titleStyle.copyWith(
              color: AppTheme.primaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          _buildContentWidget(),
        ],
      ),
    );
  }

  /// Get clean content (HTML to plain text)
  String _getCleanContent() {
    final content = _currentPost.content;

    // Clean HTML tags and entities
    String cleanContent = content
        .replaceAll(RegExp(r'<p[^>]*>'), '') // Remove p tags
        .replaceAll(RegExp(r'</p>'), '\n\n') // Replace with line breaks
        .replaceAll(RegExp(r'<br[^>]*>'), '\n') // Replace br with line break
        .replaceAll(RegExp(r'<div[^>]*>'), '') // Remove div tags
        .replaceAll(RegExp(r'</div>'), '\n') // Replace with line break
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove remaining HTML
        .replaceAll(RegExp(r'&nbsp;'), ' ') // Replace entities
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .trim();

    // Truncate if not showing full text
    if (!_showFullText && cleanContent.length > 500) {
      return '${cleanContent.substring(0, 500)}...';
    }

    return cleanContent;
  }

  /// Build action area
  Widget _buildActionArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _sharePost,
              icon: const Icon(Icons.share),
              label: const Text('Share'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _downloadPost,
              icon: const Icon(Icons.download),
              label: const Text('Download'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[600],
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build Tags Section - Final Design (Small Chips, Not Dominant)
  Widget _buildTagsSection() {
    final tags = _currentPost.tags;

    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tags header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'Tags',
              style: AppTheme.titleStyle.copyWith(
                color: AppTheme.primaryTextColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Tags chips (wrap)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: tags.map((tag) => _buildTagChip(tag)).toList(),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Build individual tag chip
  Widget _buildTagChip(String tag) {
    return GestureDetector(
      onTap: () => _searchTag(tag),
      onLongPress: () => _blockTag(tag),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          tag,
          style: AppTheme.bodyStyle.copyWith(
            color: Colors.grey[700],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// Build Actions Section - Final Design (Minimal & Clear)
  Widget _buildActionsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _sharePost,
              icon: const Icon(Icons.share, size: 18),
              label: const Text('Share'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _openInBrowser,
              icon: const Icon(Icons.open_in_browser, size: 18),
              label: const Text('Open'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: BorderSide(color: AppTheme.primaryColor),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Navigate to creator detail
  void _navigateToCreator() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatorDetailScreen(
          creatorName: _currentPost.user,
          service: widget.post.service,
          apiSource: widget.apiSource,
        ),
      ),
    );
  }

  /// Search tag
  void _searchTag(String tag) {
    // TODO: Implement tag search
    print('🔍 DEBUG: Searching tag: $tag');
  }

  /// Block tag
  void _blockTag(String tag) {
    // TODO: Implement tag blocking
    print('🔍 DEBUG: Blocking tag: $tag');
  }

  /// Open in browser
  void _openInBrowser() async {
    try {
      final postUrl = _getPostUrl();
      final uri = Uri.parse(postUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('🔍 DEBUG: Error opening browser: $e');
    }
  }

  /// Get post URL
  String _getPostUrl() {
    if (widget.apiSource == ApiSource.kemono) {
      return 'https://kemono.party/${widget.post.service}/user/${_currentPost.user}/post/${_currentPost.id}';
    } else {
      return 'https://coomer.party/${widget.post.service}/onlyfans/user/${_currentPost.user}/post/${_currentPost.id}';
    }
  }

  /// Open fullscreen viewer
  void _openFullscreenViewer(int initialIndex) {
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

  /// Open video player
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

  /// Navigate to creator detail
  void _navigateToCreatorDetail() {
    // Implementation would go here
  }

  /// Share post
  void _sharePost() async {
    try {
      final postUrl = _getPostUrl();
      await Clipboard.setData(ClipboardData(text: postUrl));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post link copied to clipboard!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share post: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Download post
  void _downloadPost() async {
    try {
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

  /// Get post URL
  String _getPostUrl() {
    final domain = widget.apiSource == ApiSource.kemono
        ? 'https://kemono.cr'
        : 'https://coomer.st';

    return '$domain/${widget.post.service}/user/${widget.post.user}/post/${widget.post.id}';
  }

  /// Get service display name
  String _getServiceDisplayName() {
    switch (widget.post.service) {
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
      default:
        return widget.post.service.toUpperCase();
    }
  }

  /// Get service color
  Color _getServiceColor() {
    switch (widget.post.service) {
      case 'patreon':
        return Colors.red;
      case 'fanbox':
        return Colors.blue;
      case 'fantia':
        return Colors.purple;
      case 'onlyfans':
        return Colors.pink.shade300;
      case 'fansly':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  /// Format date
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  /// Get clean file name
  String _getFileName(String fullFileName) {
    final parts = fullFileName.split('/');
    return parts.isNotEmpty ? parts.last : fullFileName;
  }

  /// Check if file is media file
  bool _isMediaFile(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return _isImageFile(extension) || _isVideoFile(extension);
  }

  /// Check if file is image
  bool _isImageFile(String extension) {
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension);
  }

  /// Check if file is video
  bool _isVideoFile(String extension) {
    return ['mp4', 'webm', 'avi', 'mov', 'mkv'].contains(extension);
  }

  /// Get media type
  String _getMediaType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return _isVideoFile(extension) ? 'video' : 'image';
  }

  /// Build full URL
  String _buildFullUrl(String path) {
    if (path.startsWith('http')) {
      return path;
    }

    final domain = widget.apiSource == ApiSource.kemono
        ? 'https://kemono.cr'
        : 'https://coomer.st';

    return '$domain$path';
  }
}

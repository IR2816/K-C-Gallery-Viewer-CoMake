import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:html/parser.dart' as html_parser;

// Domain
import '../../domain/entities/creator.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/api_source.dart';

// Providers
import '../providers/posts_provider.dart';
import '../providers/creators_provider.dart';
import '../providers/smart_bookmark_provider.dart';

// Theme
import '../theme/app_theme.dart';

// Widgets
import '../widgets/media_resolver.dart';

// Screens
import 'post_detail_screen.dart';
import 'fullscreen_media_viewer.dart';

/// Creator Detail Screen - Personal Dashboard for Content
/// 
/// Design Principles:
/// - Content > decoration
/// - Lightweight scrolling
/// - State preservation (scroll position)
/// - Media as highlight, not long text
/// - Portal to content, not social profile
class CreatorDetailScreen extends StatefulWidget {
  final Creator creator;
  final ApiSource apiSource;

  const CreatorDetailScreen({
    super.key, 
    required this.creator,
    required this.apiSource,
  });

  @override
  State<CreatorDetailScreen> createState() => _CreatorDetailScreenState();
}

class _CreatorDetailScreenState extends State<CreatorDetailScreen> 
    with TickerProviderStateMixin {
  
  // Core Controllers
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;
  final ScrollController _postsScrollController = ScrollController();
  final ScrollController _mediaScrollController = ScrollController();
  
  // State Management (SIMPLIFIED - Single Source of Truth)
  double _postsScrollOffset = 0.0;
  double _mediaScrollOffset = 0.0;
  bool _isBookmarked = false;
  
  // Media cache (performance optimization)
  List<Map<String, dynamic>> _cachedMediaItems = [];
  bool _mediaCacheBuilt = false;

  // State preservation
  @override
  bool get wantKeepAlive => true; // Preserve tab state

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadCreatorPosts();
    _checkBookmarkStatus();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _scrollController.dispose();
    _postsScrollController.dispose();
    _mediaScrollController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    // Save current scroll position
    if (_tabController.indexIsChanging) return;
    
    if (_tabController.previousIndex == 0) {
      _postsScrollOffset = _postsScrollController.offset;
    } else if (_tabController.previousIndex == 1) {
      _mediaScrollOffset = _mediaScrollController.offset;
    }
    
    // Restore scroll position after tab change
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_tabController.index == 0 && _postsScrollOffset > 0) {
        _postsScrollController.animateTo(
          _postsScrollOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else if (_tabController.index == 1 && _mediaScrollOffset > 0) {
        _mediaScrollController.animateTo(
          _mediaScrollOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // SIMPLIFIED - Single responsibility: just trigger provider
  Future<void> _loadCreatorPosts() async {
    try {
      print('🔍 DEBUG: Loading posts for creator: ${widget.creator.name}');
      
      final postsProvider = Provider.of<PostsProvider>(context, listen: false);
      postsProvider.clearPosts();
      
      await postsProvider.loadCreatorPosts(
        widget.creator.service,
        widget.creator.id,
        refresh: true,
      );
      
      // Build media cache after posts load
      _buildMediaCache();
      
      print('🔍 DEBUG: Posts loaded successfully');
    } catch (e) {
      print('🔍 DEBUG: Error loading posts: $e');
      // Error handling done by provider, no local state needed
    }
  }

  // PERFORMANCE OPTIMIZATION - Cache media items
  void _buildMediaCache() {
    if (_mediaCacheBuilt) return;
    
    final postsProvider = Provider.of<PostsProvider>(context, listen: false);
    _cachedMediaItems = [];
    
    for (final post in postsProvider.posts) {
      // Add attachments
      for (final attachment in post.attachments) {
        if (_isImageFile(attachment.name)) {
          _cachedMediaItems.add({
            'type': 'image',
            'url': _buildFullUrl(attachment.path, widget.apiSource),
            'name': attachment.name,
            'postId': post.id,
          });
        }
      }
      
      // Add files
      for (final file in post.file) {
        if (_isImageFile(file.name)) {
          _cachedMediaItems.add({
            'type': 'image',
            'url': _buildFullUrl(file.path, widget.apiSource),
            'name': file.name,
            'postId': post.id,
          });
        }
      }
    }
    
    _mediaCacheBuilt = true;
    print('🔍 DEBUG: Media cache built with ${_cachedMediaItems.length} items');
  }

  bool _isImageFile(String filename) {
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    return imageExtensions.any((ext) => filename.toLowerCase().endsWith(ext));
  }

  // FIXED - Use ApiSource instead of service string
  String _buildFullUrl(String path, ApiSource apiSource) {
    if (path.startsWith('http')) {
      return path;
    }
    
    final domain = apiSource == ApiSource.coomer 
        ? 'https://n2.coomer.st' 
        : 'https://kemono.cr';
    
    return '$domain/data$path';
  }

  Future<void> _checkBookmarkStatus() async {
    final bookmarkProvider = Provider.of<SmartBookmarkProvider>(context, listen: false);
    final isBookmarked = bookmarkProvider.isBookmarkedByType(BookmarkType.creator, widget.creator.id);
    if (mounted) {
      setState(() {
        _isBookmarked = isBookmarked;
      });
    }
  }

  void _toggleBookmark(SmartBookmarkProvider bookmarkProvider) {
    final isBookmarked = bookmarkProvider.isBookmarkedByType(BookmarkType.creator, widget.creator.id);
    
    if (isBookmarked) {
      // Remove bookmark
      final bookmark = bookmarkProvider.getBookmarkByType(BookmarkType.creator, widget.creator.id);
      if (bookmark != null) {
        bookmarkProvider.removeBookmark(bookmark.id);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Removed from Saved'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } else {
      // Add bookmark
      bookmarkProvider.addBookmarkWithParams(
        type: BookmarkType.creator,
        targetId: widget.creator.id,
        target: widget.creator,
        title: widget.creator.name,
        creatorId: widget.creator.id,
        creatorName: widget.creator.name,
        creatorService: widget.creator.service,
        creatorAvatar: widget.creator.avatar,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Added to Saved'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  Future<void> _openInBrowser() async {
    final url = widget.apiSource == ApiSource.kemono
        ? 'https://kemono.cr/${widget.creator.service}/user/${widget.creator.id}'
        : 'https://coomer.st/${widget.creator.service}/user/${widget.creator.id}';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  void _navigateToPostDetail(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(
          post: post,
          apiSource: widget.apiSource,
        ),
      ),
    );
  }

  void _openMediaViewer(List<Map<String, dynamic>> mediaItems, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullscreenMediaViewer(
          mediaItems: mediaItems,
          initialIndex: initialIndex,
          apiSource: widget.apiSource,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getAllMediaItems() {
    final mediaItems = <Map<String, dynamic>>[];
    
    for (final post in _posts) {
      // Add from attachments
      for (final attachment in post.attachments) {
        if (_isMediaFile(attachment.name)) {
          final fullUrl = _buildFullUrl(attachment.path);
          mediaItems.add({
            'url': fullUrl,
            'name': attachment.name,
            'type': _getMediaType(attachment.name),
            'post': post,
          });
        }
      }
      
      // Add from file
      for (final file in post.file) {
        if (_isMediaFile(file.name)) {
          final fullUrl = _buildFullUrl(file.path);
          mediaItems.add({
            'url': fullUrl,
            'name': file.name,
            'type': _getMediaType(file.name),
            'post': post,
          });
        }
      }
    }
    
    return mediaItems;
  }

  bool _isMediaFile(String filename) {
    final name = filename.toLowerCase();
    return name.endsWith('.jpg') ||
           name.endsWith('.jpeg') ||
           name.endsWith('.png') ||
           name.endsWith('.gif') ||
           name.endsWith('.webp') ||
           name.endsWith('.mp4') ||
  String _getServiceDisplayName() {
    switch (widget.creator.service.toLowerCase()) {
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
        return widget.creator.service.toUpperCase();
    }
  }

  Color getServiceColor() {
    switch (widget.creator.service.toLowerCase()) {
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

  String formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day} ${getMonthName(date.month)} ${date.year}';
    }
  }

  String getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  /// Clean HTML tags from content
  String cleanHtmlContent(String content) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Consumer<PostsProvider>(
        builder: (context, postsProvider, _) {
          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              buildCompactSliverAppBar(),
              
              // Simple Tabs
              buildTabs(),
              
              // Tab Content - Single Source of Truth
              SliverFillRemaining(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    buildPostsTab(postsProvider),
                    buildMediaTab(postsProvider),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget buildCompactSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 80, // COMPACT - utility header, not hero header
      pinned: true,
      floating: false,
      backgroundColor: AppTheme.surfaceColor,
      foregroundColor: AppTheme.primaryTextColor,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        // Bookmark Button (only main action in AppBar)
        Consumer<SmartBookmarkProvider>(
          builder: (context, bookmarkProvider, child) {
            final isBookmarked = bookmarkProvider.isBookmarkedByType(BookmarkType.creator, widget.creator.id);
            return IconButton(
              icon: Icon(
                isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: isBookmarked ? AppTheme.primaryColor : AppTheme.primaryTextColor,
              ),
              onPressed: () => _toggleBookmark(bookmarkProvider),
              tooltip: isBookmarked ? 'Remove Bookmark' : 'Add Bookmark',
            );
          },
        ),
        
        // Open in Browser (utility action)
        IconButton(
          icon: const Icon(Icons.open_in_browser),
          onPressed: _openCreatorInBrowser,
          tooltip: 'Open in Browser',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.creator.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor.withOpacity(0.8),
                AppTheme.primaryColor.withOpacity(0.4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildTabs() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _TabBarDelegate(
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.article_outlined),
              text: 'Posts',
            ),
            Tab(
              icon: Icon(Icons.photo_library_outlined),
              text: 'Media',
            ),
          ],
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.secondaryTextColor,
          indicatorColor: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120, // Compact header
      pinned: true,
      floating: false,
      backgroundColor: AppTheme.surfaceColor,
      foregroundColor: AppTheme.primaryTextColor,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        // Bookmark Button
        Consumer<SmartBookmarkProvider>(
          builder: (context, bookmarkProvider, child) {
            final isBookmarked = bookmarkProvider.isBookmarkedByType(BookmarkType.creator, widget.creator.id);
            return IconButton(
              icon: Icon(
                isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: isBookmarked ? AppTheme.primaryColor : AppTheme.primaryTextColor,
              ),
              onPressed: () => _toggleBookmark(bookmarkProvider),
              tooltip: isBookmarked ? 'Remove from Saved' : 'Save Creator',
            );
          },
        ),
        
        // Refresh button
        IconButton(
          onPressed: _loadCreatorDetails,
          icon: _isLoading 
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryColor,
                  ),
                )
              : const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.creator.name,
              style: AppTheme.titleStyle.copyWith(
                color: AppTheme.primaryTextColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: getServiceColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getServiceDisplayName(),
                    style: TextStyle(
                      color: getServiceColor(),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_posts.length} posts',
                  style: AppTheme.captionStyle.copyWith(
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
      ),
    );
  }

  Widget buildQuickActions() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Refresh button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _loadCreatorDetails,
                icon: _isLoading 
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryColor,
                        ),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: Text(_isLoading ? 'Refreshing...' : 'Refresh'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Bookmark/Follow
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  final bookmarkProvider = context.read<SmartBookmarkProvider>();
                  _toggleBookmark(bookmarkProvider);
                },
                icon: Icon(
                  _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  size: 18,
                ),
                label: Text(_isBookmarked ? 'Bookmarked' : 'Bookmark'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isBookmarked ? AppTheme.primaryColor : AppTheme.surfaceColor,
                  foregroundColor: _isBookmarked ? Colors.white : AppTheme.primaryTextColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Open in Browser
            IconButton(
              onPressed: _openInBrowser,
              icon: const Icon(Icons.open_in_browser),
              tooltip: 'Open in Browser',
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTabs() {
    return SliverToBoxAdapter(
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Posts'),
          Tab(text: 'Media'),
        ],
        labelColor: AppTheme.primaryColor,
        unselectedLabelColor: AppTheme.secondaryTextColor,
        indicatorColor: AppTheme.primaryColor,
      ),
    );
  }

  // SIMPLIFIED - Single Source of Truth from PostsProvider
  Widget buildPostsTab(PostsProvider postsProvider) {
    if (postsProvider.isLoading && postsProvider.posts.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    if (postsProvider.error != null && postsProvider.posts.isEmpty) {
      return Center(
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
              'Error loading posts',
              style: AppTheme.titleStyle.copyWith(color: AppTheme.errorColor),
            ),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Text(
                postsProvider.error!,
                style: AppTheme.captionStyle.copyWith(color: AppTheme.errorColor),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadCreatorPosts(),
              child: const Text('Retry'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Go Back',
                style: TextStyle(color: AppTheme.secondaryTextColor),
              ),
            ),
          ],
        ),
      );
    }

    if (postsProvider.posts.isEmpty && !postsProvider.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 64,
              color: AppTheme.secondaryTextColor,
            ),
            const SizedBox(height: 16),
            Text(
              'No posts yet',
              style: AppTheme.titleStyle.copyWith(color: AppTheme.secondaryTextColor),
            ),
            const SizedBox(height: 8),
            Text(
              'This creator hasn\'t posted anything yet',
              style: AppTheme.captionStyle.copyWith(color: AppTheme.secondaryTextColor),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Simple header info (no fake pagination)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.article_outlined,
                size: 20,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${postsProvider.posts.length} posts${postsProvider.hasMore ? ' • Loading more...' : ' • All loaded'}',
                  style: AppTheme.captionStyle.copyWith(
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Posts list - Pull to refresh
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: handleScrollNotification,
            child: RefreshIndicator(
              onRefresh: () => _loadCreatorPosts(),
              child: ListView.builder(
                controller: _postsScrollController,
                padding: const EdgeInsets.all(16),
                itemCount: postsProvider.posts.length + (postsProvider.isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == postsProvider.posts.length && postsProvider.isLoading) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(color: AppTheme.primaryColor),
                      ),
                    );
                  }
                  
                  final post = postsProvider.posts[index];
                  return buildPostCard(post);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  // SIMPLIFIED Media Tab - Grid layout, no Masonry
  Widget buildMediaTab(PostsProvider postsProvider) {
    if (postsProvider.isLoading && postsProvider.posts.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    if (postsProvider.error != null && postsProvider.posts.isEmpty) {
      return Center(
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
              'Error loading media',
              style: AppTheme.titleStyle.copyWith(color: AppTheme.errorColor),
            ),
            const SizedBox(height: 8),
            Text(
              postsProvider.error!,
              style: AppTheme.captionStyle.copyWith(color: AppTheme.errorColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadCreatorPosts(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_cachedMediaItems.isEmpty && !postsProvider.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: AppTheme.secondaryTextColor,
            ),
            const SizedBox(height: 16),
            Text(
              'No media yet',
              style: AppTheme.titleStyle.copyWith(color: AppTheme.secondaryTextColor),
            ),
            const SizedBox(height: 8),
            Text(
              'This creator hasn\'t posted any media yet',
              style: AppTheme.captionStyle.copyWith(color: AppTheme.secondaryTextColor),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadCreatorPosts(),
      child: GridView.builder(
        controller: _mediaScrollController,
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.0, // Consistent aspect ratio
        ),
        itemCount: _cachedMediaItems.length,
        itemBuilder: (context, index) {
          final mediaItem = _cachedMediaItems[index];
          return buildMediaGridItem(mediaItem);
        },
      ),
    );
  }

  // SIMPLIFIED Media Grid Item - No shadow, consistent ratio
  Widget buildMediaGridItem(Map<String, dynamic> mediaItem) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          mediaItem['url'],
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[800],
              child: const Center(
                child: Icon(
                  Icons.broken_image,
                  color: Colors.white54,
                  size: 32,
                ),
              ),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Colors.grey[800],
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  bool handleScrollNotification(ScrollNotification scrollInfo) {
    final postsProvider = Provider.of<PostsProvider>(context, listen: false);
    
    if (scrollInfo is ScrollEndNotification && 
        postsProvider.hasMore && 
        !postsProvider.isLoading &&
        scrollInfo.metrics.extentAfter < 500) {
      // Trigger load more in provider
      postsProvider.loadCreatorPosts(
        widget.creator.service,
        widget.creator.id,
        refresh: false,
      );
      return true;
    }
    return false;
  }

  Widget buildPostCard(Post post) {
    final hasMedia = post.attachments.isNotEmpty || post.file.isNotEmpty;
    final mediaCount = post.attachments.length + post.file.length;
    final hasVideo = post.attachments.any((a) => _getMediaType(a.name) == 'video') ||
                   post.file.any((f) => _getMediaType(f.name) == 'video');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppTheme.surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _navigateToPostDetail(post),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Post header with media indicator
              Row(
                children: [
                  if (hasMedia)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: hasVideo ? Colors.red.withOpacity(0.1) : AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasVideo ? Icons.videocam : Icons.photo,
                            size: 14,
                            color: hasVideo ? Colors.red : AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$mediaCount ${hasVideo ? 'videos' : 'photos'}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: hasVideo ? Colors.red : AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  Text(
                    formatDate(post.published),
                    style: AppTheme.captionStyle.copyWith(
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Post title (clean HTML)
              if (post.title.isNotEmpty)
                Text(
                  cleanHtmlContent(post.title),
                  style: AppTheme.titleStyle.copyWith(
                    color: AppTheme.primaryTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              
              // Post content preview (clean HTML + clickable links)
              if (post.content.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Linkify(
                    text: cleanHtmlContent(post.content).length > 100 
                        ? '${cleanHtmlContent(post.content).substring(0, 100)}...'
                        : cleanHtmlContent(post.content),
                    style: AppTheme.bodyStyle.copyWith(
                      color: AppTheme.secondaryTextColor,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    linkStyle: TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    onOpen: (link) async {
                      if (await canLaunchUrl(Uri.parse(link.url))) {
                        await launchUrl(
                          Uri.parse(link.url),
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildMediaTab() {
    final mediaItems = _getAllMediaItems();

    if (mediaItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: AppTheme.secondaryTextColor,
            ),
            const SizedBox(height: 16),
            Text(
              'No media yet',
              style: AppTheme.titleStyle.copyWith(color: AppTheme.secondaryTextColor),
            ),
            const SizedBox(height: 8),
            Text(
              'This creator hasn\'t posted any photos or videos',
              style: AppTheme.captionStyle.copyWith(color: AppTheme.secondaryTextColor),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCreatorDetails,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: MasonryGridView.count(
          controller: _mediaScrollController,
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          itemCount: mediaItems.length,
          itemBuilder: (context, index) {
            final mediaItem = mediaItems[index];
            final isVideo = mediaItem['type'] == 'video';
            
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Media thumbnail dengan optimasi
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: getMediaHeight(isVideo, index),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                        ),
                        child: buildOptimizedMediaThumbnail(mediaItem, isVideo),
                      ),
                    ),
                    
                    // Video overlay
                    if (isVideo)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withOpacity(0.4),
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
                    
                    // Tap to view
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _openMediaViewer(mediaItems, index),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  double getMediaHeight(bool isVideo, int index) {
    if (isVideo) {
      return 200; // Consistent height for videos
    } else {
      // Varied heights for images (Pinterest effect)
      final heights = [180, 220, 200, 240, 190, 210, 230, 200];
      return heights[index % heights.length].toDouble();
    }
  }

  Widget buildOptimizedMediaThumbnail(Map<String, dynamic> mediaItem, bool isVideo) {
    // Untuk video, jangan load WebView di Media tab (lag!)
    if (isVideo) {
      return buildVideoPlaceholder();
    }
    
    // Untuk gambar, gunakan cached network image dengan optimasi
    return buildOptimizedImage(mediaItem['url']);
  }

  Widget buildVideoPlaceholder() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Video icon
          const Center(
            child: Icon(
              Icons.play_circle_outline,
              color: Colors.white54,
              size: 48,
            ),
          ),
          // Video indicator
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
          ),
        ],
      ),
    );
  }

  Widget buildOptimizedImage(String imageUrl) {
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
      // Optimasi cache
      cacheWidth: 200, // Resize untuk thumbnail
    );
  }
}

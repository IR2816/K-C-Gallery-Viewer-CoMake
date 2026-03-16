import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/high_impact_features.dart';
import '../widgets/consistent_gesture_handler.dart';

/// Enhanced Bookmark Manager Screen dengan search & management
/// 
/// Features:
/// - Search dalam bookmark creators & posts
/// - Sort by date, name, service
/// - Quick actions (remove, navigate)
/// - Empty states dengan clear CTAs
class EnhancedBookmarkScreen extends StatefulWidget {
  const EnhancedBookmarkScreen({super.key});

  @override
  State<EnhancedBookmarkScreen> createState() => _EnhancedBookmarkScreenState();
}

class _EnhancedBookmarkScreenState extends State<EnhancedBookmarkScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<BookmarkedCreator> _bookmarkedCreators = [];
  List<BookmarkedPost> _bookmarkedPosts = [];
  List<BookmarkedCreator> _filteredCreators = [];
  List<BookmarkedPost> _filteredPosts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  BookmarkSortOption _sortOption = BookmarkSortOption.date;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBookmarks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookmarks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final creators = await BookmarkManager.getBookmarkedCreators();
      final posts = await BookmarkManager.getBookmarkedPosts();
      
      final creatorList = creators.entries.map((entry) {
        final data = entry.value;
        return BookmarkedCreator(
          id: entry.key,
          name: data['creatorName'] ?? 'Unknown',
          service: data['service'] ?? '',
          avatarUrl: data['avatarUrl'],
          bookmarkedAt: DateTime.fromMillisecondsSinceEpoch(data['bookmarkedAt']),
        );
      }).toList();

      final postList = posts.entries.map((entry) {
        final data = entry.value;
        return BookmarkedPost(
          id: entry.key,
          title: data['title'] ?? 'Untitled',
          creatorName: data['creatorName'] ?? 'Unknown',
          thumbnailUrl: data['thumbnailUrl'],
          bookmarkedAt: DateTime.fromMillisecondsSinceEpoch(data['bookmarkedAt']),
        );
      }).toList();

      setState(() {
        _bookmarkedCreators = creatorList;
        _bookmarkedPosts = postList;
        _applyFiltersAndSort();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFiltersAndSort() {
    // Filter by search query
    _filteredCreators = _bookmarkedCreators.where((creator) {
      final query = _searchQuery.toLowerCase();
      return creator.name.toLowerCase().contains(query) ||
             creator.service.toLowerCase().contains(query);
    }).toList();

    _filteredPosts = _bookmarkedPosts.where((post) {
      final query = _searchQuery.toLowerCase();
      return post.title.toLowerCase().contains(query) ||
             post.creatorName.toLowerCase().contains(query);
    }).toList();

    // Apply sorting
    _sortBookmarks();
  }

  void _sortBookmarks() {
    switch (_sortOption) {
      case BookmarkSortOption.name:
        _filteredCreators.sort((a, b) => a.name.compareTo(b.name));
        _filteredPosts.sort((a, b) => a.title.compareTo(b.title));
        break;
      case BookmarkSortOption.service:
        _filteredCreators.sort((a, b) => a.service.compareTo(b.service));
        break;
      case BookmarkSortOption.date:
      default:
        _filteredCreators.sort((a, b) => b.bookmarkedAt.compareTo(a.bookmarkedAt));
        _filteredPosts.sort((a, b) => b.bookmarkedAt.compareTo(a.bookmarkedAt));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Search and filter section
          _buildSearchAndFilter(),
          
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCreatorsTab(),
                _buildPostsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        _isSearching ? 'Search Bookmarks' : 'Bookmarks',
        style: AppTheme.titleStyle.copyWith(
          color: AppTheme.primaryTextColor,
        ),
      ),
      backgroundColor: AppTheme.surfaceColor,
      foregroundColor: AppTheme.primaryTextColor,
      elevation: AppTheme.smElevation,
      actions: [
        if (!_isSearching)
          IconButton(
            icon: Icon(Icons.search, color: AppTheme.primaryTextColor),
            onPressed: _toggleSearch,
          ),
        if (_isSearching)
          IconButton(
            icon: Icon(Icons.close, color: AppTheme.primaryTextColor),
            onPressed: _toggleSearch,
          ),
        PopupMenuButton<BookmarkSortOption>(
          icon: Icon(Icons.sort, color: AppTheme.primaryTextColor),
          onSelected: (option) {
            setState(() {
              _sortOption = option;
              _applyFiltersAndSort();
            });
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: BookmarkSortOption.date,
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 20),
                  const SizedBox(width: AppTheme.smSpacing),
                  Text('Sort by Date'),
                  if (_sortOption == BookmarkSortOption.date)
                    Padding(
                      padding: const EdgeInsets.only(left: AppTheme.smSpacing),
                      child: Icon(Icons.check, color: AppTheme.primaryColor),
                    ),
                ],
              ),
            ),
            PopupMenuItem(
              value: BookmarkSortOption.name,
              child: Row(
                children: [
                  Icon(Icons.sort_by_alpha, size: 20),
                  const SizedBox(width: AppTheme.smSpacing),
                  Text('Sort by Name'),
                  if (_sortOption == BookmarkSortOption.name)
                    Padding(
                      padding: const EdgeInsets.only(left: AppTheme.smSpacing),
                      child: Icon(Icons.check, color: AppTheme.primaryColor),
                    ),
                ],
              ),
            ),
            PopupMenuItem(
              value: BookmarkSortOption.service,
              child: Row(
                children: [
                  Icon(Icons.category, size: 20),
                  const SizedBox(width: AppTheme.smSpacing),
                  Text('Sort by Service'),
                  if (_sortOption == BookmarkSortOption.service)
                    Padding(
                      padding: const EdgeInsets.only(left: AppTheme.smSpacing),
                      child: Icon(Icons.check, color: AppTheme.primaryColor),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: AppTheme.primaryColor,
        labelColor: AppTheme.primaryTextColor,
        unselectedLabelColor: AppTheme.secondaryTextColor,
        labelStyle: AppTheme.captionStyle.copyWith(fontWeight: FontWeight.w600),
        tabs: [
          Tab(
            text: 'Creators',
            child: Stack(
              children: [
                const Text('Creators'),
                if (_filteredCreators.length != _bookmarkedCreators.length)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Tab(
            text: 'Posts',
            child: Stack(
              children: [
                const Text('Posts'),
                if (_filteredPosts.length != _bookmarkedPosts.length)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    if (!_isSearching) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppTheme.mdPadding),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          bottom: BorderSide(color: AppTheme.cardColor),
        ),
      ),
      child: TextField(
        autofocus: true,
        style: AppTheme.bodyStyle.copyWith(
          color: AppTheme.primaryTextColor,
        ),
        decoration: InputDecoration(
          hintText: 'Search bookmarks...',
          hintStyle: AppTheme.captionStyle.copyWith(
            color: AppTheme.secondaryTextColor,
          ),
          filled: true,
          fillColor: AppTheme.cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.mdRadius),
            borderSide: BorderSide.none,
          ),
          prefixIcon: Icon(Icons.search, color: AppTheme.secondaryTextColor),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: AppTheme.secondaryTextColor),
                  onPressed: _clearSearch,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppTheme.mdPadding,
            vertical: AppTheme.smPadding,
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _applyFiltersAndSort();
          });
        ),
      ),
    )
  }

  Widget _buildCreatorsTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
        ),
      );
    }

    if (_filteredCreators.isEmpty) {
      return _buildEmptyState(
        icon: Icons.person_outline,
        title: _searchQuery.isNotEmpty ? 'No creators found' : 'No bookmarked creators',
        subtitle: _searchQuery.isNotEmpty 
            ? 'Try different search terms'
            : 'Bookmark creators to see them here',
        actionLabel: 'Browse Creators',
        onAction: _browseCreators,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.mdPadding),
      itemCount: _filteredCreators.length,
      itemBuilder: (context, index) => _buildCreatorCard(_filteredCreators[index]),
    );
  }

  Widget _buildPostsTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
        ),
      );
    }

    if (_filteredPosts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.bookmark_outline,
        title: _searchQuery.isNotEmpty ? 'No posts found' : 'No bookmarked posts',
        subtitle: _searchQuery.isNotEmpty 
            ? 'Try different search terms'
            : 'Bookmark posts to see them here',
        actionLabel: 'Browse Posts',
        onAction: _browsePosts,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.mdPadding),
      itemCount: _filteredPosts.length,
      itemBuilder: (context, index) => _buildPostCard(_filteredPosts[index]),
    );
  }

  Widget _buildCreatorCard(BookmarkedCreator creator) {
    return SwipeableCard(
      onSwipeRight: () => _navigateToCreator(creator),
      onSwipeLeft: () => _removeBookmark(creator.id, 'creator'),
      swipeRightColor: AppTheme.primaryColor,
      swipeLeftColor: AppTheme.errorColor,
      swipeRightIcon: Icon(Icons.open_in_new, color: Colors.white),
      swipeLeftIcon: Icon(Icons.bookmark, color: Colors.white),
      child: Card(
        color: AppTheme.surfaceColor,
        margin: const EdgeInsets.only(bottom: AppTheme.smSpacing),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.mdRadius),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(AppTheme.mdPadding),
          leading: Hero(
            tag: 'creator_${creator.id}',
            child: CircleAvatar(
              backgroundImage: creator.avatarUrl != null 
                  ? NetworkImage(creator.avatarUrl!)
                  : null,
              backgroundColor: AppTheme.cardColor,
              child: creator.avatarUrl == null
                  ? Text(
                      creator.name.isNotEmpty ? creator.name[0].toUpperCase() : '?',
                      style: AppTheme.bodyStyle.copyWith(
                        color: AppTheme.primaryTextColor,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
          title: Text(
            creator.name,
            style: AppTheme.bodyStyle.copyWith(
              color: AppTheme.primaryTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppTheme.xsSpacing),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.xsPadding,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _getServiceColor(creator.service),
                      borderRadius: BorderRadius.circular(AppTheme.xsRadius),
                    ),
                    child: Text(
                      creator.service.toUpperCase(),
                      style: AppTheme.captionStyle.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.smSpacing),
                  Text(
                    'Bookmarked ${_formatDate(creator.bookmarkedAt)}',
                    style: AppTheme.captionStyle.copyWith(
                      color: AppTheme.secondaryTextColor,
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
                icon: Icon(Icons.open_in_new, color: AppTheme.primaryColor),
                onPressed: () => _navigateToCreator(creator),
                tooltip: 'View Creator',
              ),
              IconButton(
                icon: Icon(Icons.bookmark, color: AppTheme.primaryColor),
                onPressed: () => _removeBookmark(creator.id, 'creator'),
                tooltip: 'Remove Bookmark',
              ),
            ],
          ),
          onTap: () => _navigateToCreator(creator),
        ),
      ),
    );
  }

  Widget _buildPostCard(BookmarkedPost post) {
    return SwipeableCard(
      onSwipeRight: () => _navigateToPost(post),
      onSwipeLeft: () => _removeBookmark(post.id, 'post'),
      swipeRightColor: AppTheme.primaryColor,
      swipeLeftColor: AppTheme.errorColor,
      swipeRightIcon: Icon(Icons.open_in_new, color: Colors.white),
      swipeLeftIcon: Icon(Icons.bookmark, color: Colors.white),
      child: Card(
        color: AppTheme.surfaceColor,
        margin: const EdgeInsets.only(bottom: AppTheme.smSpacing),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.mdRadius),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(AppTheme.mdPadding),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.smRadius),
            child: post.thumbnailUrl != null
                ? Image.network(
                    post.thumbnailUrl!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 56,
                      height: 56,
                      color: AppTheme.cardColor,
                      child: Icon(Icons.image, color: AppTheme.secondaryTextColor),
                    ),
                  )
                : Container(
                    width: 56,
                    height: 56,
                    color: AppTheme.cardColor,
                    child: Icon(Icons.image, color: AppTheme.secondaryTextColor),
                  ),
          ),
          title: Text(
            post.title,
            style: AppTheme.bodyStyle.copyWith(
              color: AppTheme.primaryTextColor,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppTheme.xsSpacing),
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: AppTheme.secondaryTextColor),
                  const SizedBox(width: AppTheme.xsSpacing),
                  Text(
                    post.creatorName,
                    style: AppTheme.captionStyle.copyWith(
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.xsSpacing),
              Row(
                children: [
                  Icon(Icons.bookmark, size: 16, color: AppTheme.secondaryTextColor),
                  const SizedBox(width: AppTheme.xsSpacing),
                  Text(
                    'Bookmarked ${_formatDate(post.bookmarkedAt)}',
                    style: AppTheme.captionStyle.copyWith(
                      color: AppTheme.secondaryTextColor,
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
                icon: Icon(Icons.open_in_new, color: AppTheme.primaryColor),
                onPressed: () => _navigateToPost(post),
                tooltip: 'View Post',
              ),
              IconButton(
                icon: Icon(Icons.bookmark, color: AppTheme.primaryColor),
                onPressed: () => _removeBookmark(post.id, 'post'),
                tooltip: 'Remove Bookmark',
              ),
            ],
          ),
          onTap: () => _navigateToPost(post),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: AppTheme.secondaryTextColor,
          ),
          const SizedBox(height: AppTheme.mdSpacing),
          Text(
            title,
            style: AppTheme.titleStyle.copyWith(
              color: AppTheme.secondaryTextColor,
            ),
          ),
          const SizedBox(height: AppTheme.smSpacing),
          Text(
            subtitle,
            style: AppTheme.captionStyle.copyWith(
              color: AppTheme.secondaryTextColor,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppTheme.lgSpacing),
            ConsistentButton(
              text: actionLabel,
              icon: Icons.explore,
              type: ButtonType.primary,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchQuery = '';
        _applyFiltersAndSort();
      }
    });
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _applyFiltersAndSort();
    });
  }

  Future<void> _removeBookmark(String id, String type) async {
    HapticFeedback.lightImpact();
    
    bool success = false;
    if (type == 'creator') {
      // Extract service and creatorId from id
      final parts = id.split('_');
      if (parts.length >= 2) {
        success = await BookmarkManager.bookmarkCreator(
          service: parts[0],
          creatorId: parts[1],
          creatorName: '',
        );
      }
    } else {
      success = await BookmarkManager.bookmarkPost(
        postId: id,
        title: '',
        creatorName: '',
      );
    }

    if (success && mounted) {
      setState(() {
        if (type == 'creator') {
          _bookmarkedCreators.removeWhere((c) => c.id == id);
        } else {
          _bookmarkedPosts.removeWhere((p) => p.id == id);
        }
        _applyFiltersAndSort();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed from bookmarks'),
          backgroundColor: AppTheme.successColor,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.smRadius),
          ),
        ),
      );
    }
  }

  void _navigateToCreator(BookmarkedCreator creator) {
    HapticFeedback.lightImpact();
    // TODO: Navigate to creator profile
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigating to ${creator.name}...'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  void _navigateToPost(BookmarkedPost post) {
    HapticFeedback.lightImpact();
    // TODO: Navigate to post detail
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening ${post.title}...'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  void _browseCreators() {
    HapticFeedback.lightImpact();
    // TODO: Navigate to creator browse
    Navigator.of(context).pop();
  }

  void _browsePosts() {
    HapticFeedback.lightImpact();
    // TODO: Navigate to post browse
    Navigator.of(context).pop();
  }

  Color _getServiceColor(String service) {
    switch (service.toLowerCase()) {
      case 'fanbox':
        return Colors.blue[600]!;
      case 'patreon':
        return Colors.orange[600]!;
      case 'fantia':
        return Colors.purple[600]!;
      case 'afdian':
        return Colors.green[600]!;
      case 'boosty':
        return Colors.red[600]!;
      case 'fansly':
        return Colors.pink[600]!;
      default:
        return Colors.grey[600]!;
    }
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
}

enum BookmarkSortOption {
  date,
  name,
  service,
}

class BookmarkedCreator {
  final String id;
  final String name;
  final String service;
  final String? avatarUrl;
  final DateTime bookmarkedAt;

  BookmarkedCreator({
    required this.id,
    required this.name,
    required this.service,
    this.avatarUrl,
    required this.bookmarkedAt,
  });
}

class BookmarkedPost {
  final String id;
  final String title;
  final String creatorName;
  final String? thumbnailUrl;
  final DateTime bookmarkedAt;

  BookmarkedPost({
    required this.id,
    required this.title,
    required this.creatorName,
    this.thumbnailUrl,
    required this.bookmarkedAt,
  });
}

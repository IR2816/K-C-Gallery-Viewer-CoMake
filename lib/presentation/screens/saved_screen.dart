import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/creators_provider.dart';
import '../providers/posts_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tag_filter_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_state_widgets.dart';
import '../widgets/skeleton_loader.dart';
import 'creator_detail_screen.dart';
import 'post_detail_screen.dart';
import '../../domain/entities/api_source.dart';
import '../../domain/entities/creator.dart';
import '../../domain/entities/post.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Auto-refresh when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAllData();
    });

    // Listen for tab changes and refresh
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;

      if (_tabController.index == 0) {
        // Posts tab - refresh saved posts
        _refreshSavedPosts();
      } else if (_tabController.index == 1) {
        // Creators tab - refresh favorite creators
        _refreshFavoriteCreators();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshAllData() {
    _refreshSavedPosts();
    _refreshFavoriteCreators();
  }

  void _refreshSavedPosts() {
    context.read<PostsProvider>().loadSavedPosts(refresh: true);
  }

  void _refreshFavoriteCreators() {
    context.read<CreatorsProvider>().loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFFFB300).withValues(alpha: 0.14),
                Colors.transparent,
              ],
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.bookmarks_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: const Text(
                    'Collections',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                      color: Colors.white,
                      letterSpacing: -1.0,
                    ),
                  ),
                ),
                Text(
                  'Saved posts and creators',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.getSecondaryTextColor(
                      context,
                      opacity: 0.76,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: _refreshAllData,
            child: Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: AppTheme.getCardColor(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.getBorderColor(context)),
              ),
              child: Icon(
                Icons.refresh_rounded,
                size: 16,
                color: AppTheme.getSecondaryTextColor(context),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _buildSegmentedControl(),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.getBackgroundGradient(context),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -130,
              right: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFB300).withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              top: 80,
              left: -70,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF8C00).withValues(alpha: 0.05),
                ),
              ),
            ),
            TabBarView(
              controller: _tabController,
              children: const [SavedPostsTab(), FavoriteCreatorsTab()],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        return Container(
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppTheme.getBorderColor(context, opacity: 0.6),
            ),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              _buildSegmentTab(0, 'Posts', Icons.photo_library_rounded),
              _buildSegmentTab(1, 'Creators', Icons.people_alt_rounded),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSegmentTab(int index, String label, IconData icon) {
    final isSelected = _tabController.index == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _tabController.animateTo(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(11),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? Colors.white
                    : AppTheme.getSecondaryTextColor(context),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : AppTheme.getSecondaryTextColor(context),
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SavedPostsTab extends StatefulWidget {
  const SavedPostsTab({super.key});

  @override
  State<SavedPostsTab> createState() => _SavedPostsTabState();
}

class _SavedPostsTabState extends State<SavedPostsTab>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  String _sortBy = 'savedAt'; // 'savedAt', 'title', 'creator'
  bool _needsRefresh = false;

  @override
  bool get wantKeepAlive => true; // Preserve state when switching tabs

  @override
  void initState() {
    super.initState();

    // Always refresh when tab is opened to prevent state contamination
    _loadSavedPosts(refresh: true);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent * 0.8) {
        context.read<PostsProvider>().loadSavedPosts();
      }
    });

    // Listen for changes from other parts of the app
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupProviderListener();
    });
  }

  void _setupProviderListener() {
    // Listen to provider changes for auto-refresh
    context.read<PostsProvider>().addListener(_onProviderChanged);
  }

  void _onProviderChanged() {
    if (mounted && _needsRefresh) {
      setState(() {
        _needsRefresh = false;
      });
      _loadSavedPosts(refresh: true);
    }
  }

  Future<void> _loadSavedPosts({bool refresh = false}) async {
    await context.read<PostsProvider>().loadSavedPosts(refresh: refresh);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    context.read<PostsProvider>().removeListener(_onProviderChanged);
    super.dispose();
  }

  List<Post> _getFilteredAndSortedPosts(
    List<Post> posts, {
    required bool hideNsfw,
    required Set<String> blockedTags,
  }) {
    var filtered = posts.where((post) {
      final titleMatch = post.title.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final creatorMatch = post.user.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      return titleMatch || creatorMatch;
    }).toList();

    if (hideNsfw) {
      filtered = filtered.where((post) => !_isNsfwPost(post)).toList();
    }

    if (blockedTags.isNotEmpty) {
      filtered = filtered
          .where((post) => !_hasBlockedTags(post, blockedTags))
          .toList();
    }

    // Sort
    switch (_sortBy) {
      case 'title':
        filtered.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'creator':
        filtered.sort((a, b) => a.user.compareTo(b.user));
        break;
      case 'savedAt':
        // Keep original order (most recent first)
        break;
    }

    return filtered;
  }

  bool _isNsfwPost(Post post) {
    if (post.tags.isEmpty) return false;
    final tags = post.tags.map((t) => t.toLowerCase()).toList();
    return tags.any(
      (tag) =>
          tag.contains('nsfw') ||
          tag.contains('r18') ||
          tag.contains('adult') ||
          tag.contains('explicit') ||
          tag.contains('18+'),
    );
  }

  bool _hasBlockedTags(Post post, Set<String> blockedTags) {
    if (post.tags.isEmpty || blockedTags.isEmpty) return false;
    return blockedTags.any(
      (blockedTag) => post.tags.any(
        (postTag) => postTag.toLowerCase().contains(blockedTag),
      ),
    );
  }

  // ignore: unused_element
  String _getServiceDisplayName(String service) {
    switch (service.toLowerCase()) {
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
        return service.toUpperCase();
    }
  }

  Color _getServiceColor(String service) {
    switch (service.toLowerCase()) {
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

  String _buildFullUrl(String path, String service) {
    if (path.startsWith('http')) {
      return path;
    }

    String domain;
    if (service == 'onlyfans' || service == 'fansly' || service == 'candfans') {
      domain = 'https://n2.coomer.st';
    } else {
      domain = 'https://kemono.cr';
    }

    return '$domain/data$path';
  }

  Map<String, dynamic>? _getFirstMedia(Post post) {
    // Check attachments first
    for (final attachment in post.attachments) {
      if (attachment.name.toLowerCase().endsWith('.jpg') ||
          attachment.name.toLowerCase().endsWith('.jpeg') ||
          attachment.name.toLowerCase().endsWith('.png') ||
          attachment.name.toLowerCase().endsWith('.gif') ||
          attachment.name.toLowerCase().endsWith('.webp')) {
        return {
          'url': _buildFullUrl(attachment.path, post.service),
          'name': attachment.name,
          'type': 'image',
        };
      }
    }

    // Check files
    for (final file in post.file) {
      if (file.name.toLowerCase().endsWith('.jpg') ||
          file.name.toLowerCase().endsWith('.jpeg') ||
          file.name.toLowerCase().endsWith('.png') ||
          file.name.toLowerCase().endsWith('.gif') ||
          file.name.toLowerCase().endsWith('.webp')) {
        return {
          'url': _buildFullUrl(file.path, post.service),
          'name': file.name,
          'type': 'image',
        };
      }
    }

    return null;
  }

  Widget _buildSavedPostCard(Post post) {
    final media = _getFirstMedia(post);
    final settings = context.read<SettingsProvider>();
    final imageFit = settings.imageFitMode;
    final serviceColor = _getServiceColor(post.service);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.getBorderColor(context, opacity: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.2
                  : 0.08,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PostDetailScreen(
                    post: post,
                    apiSource: settings.defaultApiSource,
                    isFromSavedPosts: true,
                  ),
                ),
              );
            },
            onLongPress: () => _showPostOptions(post),
            child: Row(
              children: [
                // Immersive Thumbnail
                Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(18),
                          bottomLeft: Radius.circular(18),
                        ),
                      ),
                      child: media != null
                          ? CachedNetworkImage(
                              imageUrl: media['url'],
                              fit: imageFit,
                              placeholder: (context, url) =>
                                  _buildPlaceholder(),
                              errorWidget: (context, url, error) =>
                                  _buildPlaceholder(),
                            )
                          : _buildPlaceholder(),
                    ),
                    // Service Indicator on Image
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: serviceColor.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          _getServiceIcon(post.service),
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ),
                  ],
                ),

                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.title.isNotEmpty ? post.title : 'Untitled Post',
                          style: TextStyle(
                            color: AppTheme.getPrimaryTextColor(context),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 8,
                              backgroundColor: serviceColor.withValues(
                                alpha: 0.2,
                              ),
                              child: Text(
                                post.user.isNotEmpty
                                    ? post.user[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: serviceColor,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                post.user,
                                style: TextStyle(
                                  color: AppTheme.getSecondaryTextColor(
                                    context,
                                    opacity: 0.78,
                                  ),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Action Menu
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: AppTheme.getSecondaryTextColor(
                      context,
                      opacity: 0.45,
                    ),
                    size: 20,
                  ),
                  onSelected: (value) {
                    if (value == 'remove') {
                      context.read<PostsProvider>().toggleSavePost(post);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'remove',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Remove',
                            style: TextStyle(
                              color: Colors.redAccent.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getServiceIcon(String service) {
    switch (service.toLowerCase()) {
      case 'patreon':
        return Icons.local_activity_rounded;
      case 'fanbox':
        return Icons.pix_rounded;
      case 'fantia':
        return Icons.favorite_rounded;
      default:
        return Icons.public_rounded;
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AppTheme.getElevatedSurfaceColor(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.image_not_supported,
        color: AppTheme.getSecondaryTextColor(context, opacity: 0.45),
        size: 24,
      ),
    );
  }

  Widget _buildEmptyState() {
    return const AppEmptyState(
      icon: Icons.bookmark_outline,
      title: 'No saved posts yet',
      message: 'Save posts to view them later',
    );
  }

  Widget _buildFilteredEmptyState() {
    return const AppEmptyState(
      icon: Icons.filter_alt_off,
      title: 'No posts match your filters',
      message: 'Try clearing search or adjusting filters in Settings',
    );
  }

  void _showPostOptions(Post post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.getSurfaceColor(context),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.article, color: Colors.white),
                    title: const Text(
                      'View Post',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      final settings = context.read<SettingsProvider>();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostDetailScreen(
                            post: post,
                            apiSource: settings.defaultApiSource,
                            isFromSavedPosts: true,
                          ),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text(
                      'Remove from Saved',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      context.read<PostsProvider>().toggleSavePost(post);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Post removed')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Consumer<PostsProvider>(
      builder: (context, provider, _) {
        if (provider.isLoadingSavedPosts && provider.savedPosts.isEmpty) {
          return const AppSkeletonList();
        }

        final settings = context.watch<SettingsProvider>();
        final tagFilter = context.watch<TagFilterProvider>();
        final filteredPosts = _getFilteredAndSortedPosts(
          provider.savedPosts,
          hideNsfw: settings.hideNsfw,
          blockedTags: tagFilter.blacklist,
        );
        final hasActiveFilters =
            _searchQuery.isNotEmpty ||
            settings.hideNsfw ||
            tagFilter.blacklist.isNotEmpty;

        return Column(
          children: [
            // Modernized Search Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.getCardColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _searchController.text.isNotEmpty
                      ? AppTheme.primaryColor.withValues(alpha: 0.4)
                      : AppTheme.getBorderColor(context, opacity: 0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: Theme.of(context).brightness == Brightness.dark
                          ? 0.15
                          : 0.06,
                    ),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(
                    const Duration(milliseconds: 300),
                    () {
                      if (!mounted) return;
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  );
                },
                style: TextStyle(
                  color: AppTheme.getPrimaryTextColor(context),
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Search collection...',
                  hintStyle: TextStyle(
                    color: AppTheme.getSecondaryTextColor(
                      context,
                      opacity: 0.6,
                    ),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: _searchController.text.isNotEmpty
                        ? AppTheme.primaryColor
                        : AppTheme.getSecondaryTextColor(context),
                    size: 20,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            // Sort options
            if (filteredPosts.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      '${filteredPosts.length} posts',
                      style: TextStyle(
                        color: AppTheme.getSecondaryTextColor(context),
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.sort,
                        color: AppTheme.getSecondaryTextColor(context),
                        size: 20,
                      ),
                      onSelected: (value) {
                        setState(() {
                          _sortBy = value;
                        });
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'savedAt',
                          child: Text('Saved Date'),
                        ),
                        const PopupMenuItem(
                          value: 'title',
                          child: Text('Title A-Z'),
                        ),
                        const PopupMenuItem(
                          value: 'creator',
                          child: Text('Creator Name'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadSavedPosts(refresh: true),
                color: AppTheme.getOnSurfaceColor(context),
                child: filteredPosts.isEmpty
                    ? (provider.savedPosts.isNotEmpty && hasActiveFilters
                          ? _buildFilteredEmptyState()
                          : _buildEmptyState())
                    : ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.only(
                          bottom: AppTheme.getBottomContentPadding(context),
                        ),
                        itemCount:
                            filteredPosts.length +
                            (provider.hasMoreSavedPosts ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == filteredPosts.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: PostGridSkeleton(),
                              ),
                            );
                          }
                          return _buildSavedPostCard(filteredPosts[index]);
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class FavoriteCreatorsTab extends StatefulWidget {
  const FavoriteCreatorsTab({super.key});

  @override
  State<FavoriteCreatorsTab> createState() => _FavoriteCreatorsTabState();
}

class _FavoriteCreatorsTabState extends State<FavoriteCreatorsTab>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _creatorIdController = TextEditingController();
  Timer? _searchDebounce;
  ApiSource _selectedApiSource = ApiSource.kemono;
  String _selectedService = 'patreon';
  String _searchQuery = '';
  String _sortBy = 'lastUpdated'; // 'lastUpdated', 'name', 'pinned'
  bool _needsRefresh = false;

  @override
  bool get wantKeepAlive => true; // Preserve state when switching tabs

  @override
  void initState() {
    super.initState();

    // Always refresh when tab is opened to prevent state contamination
    _loadCreators(refresh: true);

    // Listen for changes from other parts of the app
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupProviderListener();
    });
  }

  void _setupProviderListener() {
    // Listen to provider changes for auto-refresh
    context.read<CreatorsProvider>().addListener(_onProviderChanged);
  }

  void _onProviderChanged() {
    if (mounted && _needsRefresh) {
      setState(() {
        _needsRefresh = false;
      });
      _loadCreators(refresh: true);
    }
  }

  Future<void> _loadCreators({bool refresh = false}) async {
    await context.read<CreatorsProvider>().loadFavorites();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _creatorIdController.dispose();
    _searchDebounce?.cancel();
    context.read<CreatorsProvider>().removeListener(_onProviderChanged);
    super.dispose();
  }

  /// Auto-detect ApiSource based on creator service
  ApiSource _detectApiSourceForCreator(Creator creator) {
    const coomerServices = {'onlyfans', 'fansly', 'candfans'};

    if (coomerServices.contains(creator.service.toLowerCase())) {
      return ApiSource.coomer;
    }

    return ApiSource.kemono;
  }

  List<Creator> _getFilteredAndSortedCreators(List<Creator> creators) {
    var filtered = creators.where((creator) {
      return creator.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    // Sort
    switch (_sortBy) {
      case 'name':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'lastUpdated':
        filtered.sort((a, b) => b.updated.compareTo(a.updated));
        break;
      case 'pinned':
        // Pinned creators would go first (if implemented)
        break;
    }

    return filtered;
  }

  Color _getServiceColor(String service) {
    switch (service.toLowerCase()) {
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

  String _buildCreatorBannerUrl(Creator creator) {
    final apiSource = _detectApiSourceForCreator(creator);
    final base = apiSource == ApiSource.coomer
        ? 'https://img.coomer.st'
        : 'https://img.kemono.cr';
    return '$base/banners/${creator.service}/${creator.id}';
  }

  String _buildCreatorIconUrl(Creator creator) {
    if (creator.avatar.isNotEmpty) return creator.avatar;
    final apiSource = _detectApiSourceForCreator(creator);
    final base = apiSource == ApiSource.coomer
        ? 'https://img.coomer.st'
        : 'https://img.kemono.cr';
    return '$base/icons/${creator.service}/${creator.id}';
  }

  Map<String, String>? _getCoomerHeaders(String url) {
    final isCoomerDomain =
        url.contains('coomer.st') || url.contains('img.coomer.st');
    if (!isCoomerDomain) return null;
    return const {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      'Accept': 'image/avif,image/webp,image/*,*/*;q=0.8',
      'Referer': 'https://coomer.st/',
      'Origin': 'https://coomer.st',
      'Accept-Language': 'en-US,en;q=0.9',
      'Accept-Encoding': 'gzip, deflate, br',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
    };
  }

  Widget _buildCreatorCard(Creator creator) {
    final serviceColor = _getServiceColor(creator.service);
    final bannerUrl = _buildCreatorBannerUrl(creator);
    final iconUrl = _buildCreatorIconUrl(creator);
    final favoritesText = creator.fans != null
        ? '${creator.fans} favorites'
        : '${creator.indexed} posts';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 115,
          child: Stack(
            children: [
              // Banner Background
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: bannerUrl,
                  httpHeaders: _getCoomerHeaders(bannerUrl),
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: serviceColor.withValues(alpha: 0.1)),
                  errorWidget: (context, url, error) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          serviceColor.withValues(alpha: 0.4),
                          Colors.black,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
              ),
              // Gradient Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.2),
                        Colors.black.withValues(alpha: 0.85),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              // Service Badge & Remove Button
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: serviceColor.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        creator.service.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _removeCreator(creator),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: const Icon(
                          Icons.bookmark_remove_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content (Avatar + Text)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreatorDetailScreen(
                          creator: creator,
                          apiSource: _detectApiSourceForCreator(creator),
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: iconUrl,
                              httpHeaders: _getCoomerHeaders(iconUrl),
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => Center(
                                child: Text(
                                  creator.name.isNotEmpty
                                      ? creator.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                creator.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                favoritesText,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white60,
                          size: 16,
                        ),
                      ],
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

  Widget _buildEmptyState() {
    return AppEmptyState(
      icon: Icons.person_outline,
      title: 'You haven\'t saved any creators yet',
      message: 'Save creators to follow their updates easily',
      actionLabel: 'Add Creator',
      onAction: _showAddCreatorDialog,
    );
  }

  // ignore: unused_element
  void _showCreatorOptions(Creator creator) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.getSurfaceColor(context),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person, color: Colors.white),
                    title: const Text(
                      'View Creator',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreatorDetailScreen(
                            creator: creator,
                            apiSource: _detectApiSourceForCreator(creator),
                          ),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text(
                      'Remove from Saved',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      context.read<CreatorsProvider>().toggleFavorite(creator);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Creator removed')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCreatorDialog() {
    final rootContext = context;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Creator'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // API Source Selector
                  DropdownButtonFormField<ApiSource>(
                    initialValue: _selectedApiSource,
                    decoration: const InputDecoration(
                      labelText: 'API Source',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: ApiSource.kemono,
                        child: Text('Kemono'),
                      ),
                      DropdownMenuItem(
                        value: ApiSource.coomer,
                        child: Text('Coomer'),
                      ),
                    ],
                    onChanged: (ApiSource? value) {
                      if (value != null) {
                        setDialogState(() {
                          _selectedApiSource = value;
                          // Auto-select appropriate service
                          _selectedService = value == ApiSource.coomer
                              ? 'onlyfans'
                              : 'patreon';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  // Service Selector
                  DropdownButtonFormField<String>(
                    initialValue: _selectedService,
                    decoration: const InputDecoration(
                      labelText: 'Service',
                      border: OutlineInputBorder(),
                    ),
                    items: _selectedApiSource == ApiSource.kemono
                        ? const [
                            DropdownMenuItem(
                              value: 'patreon',
                              child: Text('Patreon'),
                            ),
                            DropdownMenuItem(
                              value: 'fanbox',
                              child: Text('Pixiv Fanbox'),
                            ),
                            DropdownMenuItem(
                              value: 'fantia',
                              child: Text('Fantia'),
                            ),
                            DropdownMenuItem(
                              value: 'afdian',
                              child: Text('Afdian'),
                            ),
                            DropdownMenuItem(
                              value: 'boosty',
                              child: Text('Boosty'),
                            ),
                            DropdownMenuItem(
                              value: 'gumroad',
                              child: Text('Gumroad'),
                            ),
                            DropdownMenuItem(
                              value: 'subscribestar',
                              child: Text('SubscribeStar'),
                            ),
                            DropdownMenuItem(
                              value: 'dlsite',
                              child: Text('DLsite'),
                            ),
                          ]
                        : const [
                            DropdownMenuItem(
                              value: 'onlyfans',
                              child: Text('OnlyFans'),
                            ),
                            DropdownMenuItem(
                              value: 'fansly',
                              child: Text('Fansly'),
                            ),
                            DropdownMenuItem(
                              value: 'candfans',
                              child: Text('CandFans'),
                            ),
                          ],
                    onChanged: (String? value) {
                      if (value != null) {
                        setDialogState(() {
                          _selectedService = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  // Creator ID Input
                  TextField(
                    controller: _creatorIdController,
                    decoration: const InputDecoration(
                      labelText: 'Creator ID',
                      hintText: 'Enter creator ID (e.g., 235641)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.text,
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final creatorId = _creatorIdController.text.trim();
                if (creatorId.isNotEmpty) {
                  // Get provider and scaffold messenger before popping dialog
                  final provider = rootContext.read<CreatorsProvider>();
                  final scaffoldMessenger = ScaffoldMessenger.of(rootContext);
                  final navigator = Navigator.of(rootContext);
                  Navigator.of(context).pop();

                  // Search for the creator by ID
                  await provider.searchCreators(
                    creatorId,
                    apiSource: _selectedApiSource,
                    service: _selectedService,
                  );

                  if (!mounted) {
                    return;
                  }

                  // After search, if we found exactly one creator, favorite them and save their details
                  if (provider.creators.length == 1) {
                    final creator = provider.creators.first;
                    // Make sure the creator is favorited and save their details
                    if (!creator.favorited) {
                      await provider.toggleFavorite(creator);
                    }

                    if (!mounted) {
                      return;
                    }
                    // Show success message
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Creator added to favorites'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    // Navigate to creator detail
                    navigator.push(
                      MaterialPageRoute(
                        builder: (_) => CreatorDetailScreen(
                          creator: creator,
                          apiSource: _detectApiSourceForCreator(creator),
                        ),
                      ),
                    );
                  } else if (provider.error != null) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Error: ${provider.error}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } else if (provider.creators.isEmpty) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Creator not found'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Consumer<CreatorsProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const AppSkeletonList();
        }

        final filteredCreators = _getFilteredAndSortedCreators(
          provider.creators,
        );

        return Column(
          children: [
            // Modernized Search Bar for Creators
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.getCardColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _searchController.text.isNotEmpty
                      ? AppTheme.primaryColor.withValues(alpha: 0.4)
                      : AppTheme.getBorderColor(context, opacity: 0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: Theme.of(context).brightness == Brightness.dark
                          ? 0.15
                          : 0.06,
                    ),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(
                    const Duration(milliseconds: 300),
                    () {
                      if (!mounted) return;
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  );
                },
                style: TextStyle(
                  color: AppTheme.getPrimaryTextColor(context),
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Search creators...',
                  hintStyle: TextStyle(
                    color: AppTheme.getSecondaryTextColor(
                      context,
                      opacity: 0.6,
                    ),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: _searchController.text.isNotEmpty
                        ? AppTheme.primaryColor
                        : AppTheme.getSecondaryTextColor(context),
                    size: 20,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            // Sort options
            if (filteredCreators.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      '${filteredCreators.length} creators',
                      style: TextStyle(
                        color: AppTheme.getSecondaryTextColor(context),
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.sort,
                        color: AppTheme.getSecondaryTextColor(context),
                        size: 20,
                      ),
                      onSelected: (value) {
                        setState(() {
                          _sortBy = value;
                        });
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'lastUpdated',
                          child: Text('Last Updated'),
                        ),
                        const PopupMenuItem(
                          value: 'name',
                          child: Text('Name A-Z'),
                        ),
                        const PopupMenuItem(
                          value: 'pinned',
                          child: Text('Pinned'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadCreators(refresh: true),
                color: AppTheme.getOnSurfaceColor(context),
                child: filteredCreators.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: EdgeInsets.only(
                          bottom: AppTheme.getBottomContentPadding(context),
                        ),
                        itemCount: filteredCreators.length,
                        itemBuilder: (context, index) {
                          return _buildCreatorCard(filteredCreators[index]);
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _removeCreator(Creator creator) async {
    try {
      final creatorsProvider = context.read<CreatorsProvider>();
      await creatorsProvider.toggleFavorite(creator);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('${creator.name} removed from saved'),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Failed to remove creator: $e'),
            ],
          ),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

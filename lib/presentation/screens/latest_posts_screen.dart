import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/api_source.dart';
import '../../domain/entities/creator.dart';
import '../providers/posts_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tag_filter_provider.dart';
import '../providers/post_search_provider.dart';
import '../providers/creator_quick_access_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_state_widgets.dart';
import 'post_detail_screen.dart';
import 'creator_detail_screen.dart';
import 'download_manager_screen.dart';
import '../widgets/post_card.dart';
import '../widgets/skeleton_loader.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

/// Latest Posts Screen - Quick Update Feed
class LatestPostsScreen extends StatefulWidget {
  const LatestPostsScreen({super.key});

  @override
  State<LatestPostsScreen> createState() => _LatestPostsScreenState();
}

class _LatestPostsScreenState extends State<LatestPostsScreen>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  SettingsProvider? _settingsProvider;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  List<Post> _posts = [];
  String? _error;
  bool _hasMore = true;
  bool _isSwitchingSource = false;
  bool _isFadingPage = false;
  String _selectedService = 'kemono';
  List<String> _blockedTags = [];
  TagFilterProvider? _tagFilterProvider;
  int _currentPage = 1;
  static const int _pageSize = 24;

  // Post search state
  late PostSearchProvider _postSearchProvider;
  late TextEditingController _postSearchController;
  late FocusNode _postSearchFocusNode;
  Timer? _postSearchDebounce;

  // Memory management simplified (Image cache naturally manages its own memory)
  @override
  bool get wantKeepAlive => _posts.length < 100; // Limit keep alive to prevent memory bloat

  @override
  void initState() {
    super.initState();
    _loadInitialPosts();
    _loadFilterState();
    _settingsProvider = context.read<SettingsProvider>();
    _tagFilterProvider = context.read<TagFilterProvider>();
    _postSearchProvider = context.read<PostSearchProvider>();

    // Initialize search controllers
    _postSearchController = TextEditingController();
    _postSearchFocusNode = FocusNode();

    _settingsProvider?.addListener(_onSettingsChanged);
    _tagFilterProvider?.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settingsProvider?.removeListener(_onSettingsChanged);
    _tagFilterProvider?.removeListener(_onSettingsChanged);
    _scrollController.dispose();

    // Clean up search resources
    _postSearchController.dispose();
    _postSearchFocusNode.dispose();
    _postSearchDebounce?.cancel();

    // Clean up image cache to free memory
    PaintingBinding.instance.imageCache.clear();

    // Clear posts list to free memory
    _posts.clear();
    super.dispose();
  }

  Future<void> _onSettingsChanged() async {
    if (!mounted) return;
    final postsProvider = context.read<PostsProvider>();
    final newService = _settingsProvider?.defaultApiSource.name ?? 'kemono';
    final shouldReload = newService != _selectedService;

    if (shouldReload) {
      if (_isSwitchingSource) return;

      setState(() {
        _isSwitchingSource = true;
        _selectedService = newService;
        _blockedTags = _tagFilterProvider?.blacklist.toList() ?? [];
        _posts = [];
        _currentPage = 1;
        // Reset search when switching service
        _postSearchProvider.clearSearch();
        _postSearchController.clear();
      });

      HapticFeedback.lightImpact();
      await _loadInitialPosts();

      if (mounted) {
        setState(() {
          _isSwitchingSource = false;
        });
      }
    } else {
      setState(() {
        _blockedTags = _tagFilterProvider?.blacklist.toList() ?? [];
        _posts = _getFilteredPosts(postsProvider.posts);
      });
    }
  }

  Future<void> _loadFilterState() async {
    final tagFilter = context.read<TagFilterProvider>();
    final settings = context.read<SettingsProvider>();

    setState(() {
      _selectedService = settings.defaultApiSource.name;
      _blockedTags = tagFilter.blacklist.toList();
    });
  }

  Future<void> _loadInitialPosts() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _hasMore = true;
      _isLoadingMore = false;
      _currentPage = 1;
    });

    try {
      final postsProvider = context.read<PostsProvider>();
      await postsProvider.loadLatestPosts(
        refresh: true,
        apiSource: _currentApiSource,
      );

      if (mounted) {
        setState(() {
          _posts = _getFilteredPosts(postsProvider.posts);
          _isLoading = false;
          _hasMore = postsProvider.hasMore;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final postsProvider = context.read<PostsProvider>();
      await postsProvider.loadMorePosts();

      if (mounted) {
        final newPosts = _getFilteredPosts(postsProvider.posts);
        final existingIds = _posts.map((p) => p.id).toSet();
        final uniqueNewPosts = newPosts
            .where((p) => !existingIds.contains(p.id))
            .toList();
        final hasMoreFromProvider = postsProvider.hasMore;

        setState(() {
          if (uniqueNewPosts.isNotEmpty) {
            _posts.addAll(uniqueNewPosts);
          }
          _isLoadingMore = false;
          _hasMore = hasMoreFromProvider;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _error = e.toString();
        });
      }
    }
  }

  List<Post> _getFilteredPosts(List<Post> posts) {
    final hideNsfw = context.read<SettingsProvider>().hideNsfw;
    final shouldFilterTags = _blockedTags.isNotEmpty;

    // First apply NSFW and tag blacklist filters
    List<Post> filteredPosts = posts;
    if (hideNsfw || shouldFilterTags) {
      filteredPosts = posts.where((post) {
        if (hideNsfw && _isNsfwPost(post)) return false;
        if (!shouldFilterTags) return true;
        final lowerPostTags = post.tags.map((t) => t.toLowerCase()).toList();
        return !_blockedTags.any(
          (blockedTag) => lowerPostTags.any(
            (postTag) => postTag.contains(blockedTag),
          ),
        );
      }).toList();
    }

    // Then apply post search filters (title + tags)
    final searchFiltered = _postSearchProvider.getFilteredPosts(
      filteredPosts,
      blacklistedTags: _blockedTags,
    );

    return searchFiltered;
  }

  bool _isNsfwPost(Post post) {
    if (post.tags.isEmpty) return false;
    return post.tags.any((tag) {
      final lower = tag.toLowerCase();
      return lower.contains('nsfw') ||
          lower.contains('r18') ||
          lower.contains('adult') ||
          lower.contains('explicit') ||
          lower.contains('18+');
    });
  }

  ApiSource get _currentApiSource =>
      ApiSource.values.firstWhere((a) => a.name == _selectedService);

  void _navigateToPostDetail(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PostDetailScreen(post: post, apiSource: _currentApiSource),
      ),
    );
  }

  void _navigateToCreatorDetail(Creator creator) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CreatorDetailScreen(creator: creator, apiSource: _currentApiSource),
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildFilterBottomSheet(),
    );
  }

  // ignore: unused_element
  String _cleanHtmlContent(String content) {
    try {
      final cleanText = content
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      return cleanText;
    } catch (e) {
      return content;
    }
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

  // ignore: unused_element
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day} ${_getMonthName(date.month)}';
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

  // ignore: unused_element
  String _normalizeTitle(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  // ignore: unused_element
  int _getTitleMaxLines({
    required int textLength,
    required int columnCount,
    required bool isCompact,
  }) {
    int lines;
    if (isCompact) {
      lines = columnCount == 1 ? 3 : 2;
    } else {
      lines = columnCount == 1 ? 4 : (columnCount == 2 ? 3 : 2);
    }

    if (columnCount == 1 && textLength > 140) {
      lines += 1;
    }

    return lines.clamp(1, 5);
  }

  // ignore: unused_element
  double _getTitleFontSize({
    required int textLength,
    required int columnCount,
    required bool isCompact,
  }) {
    double size = isCompact ? 13 : 14;
    if (columnCount >= 3) {
      size -= 1;
    }
    if (textLength > 140) {
      size -= 1;
    }
    if (textLength > 200) {
      size -= 1;
    }
    return size.clamp(11, 16);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: _buildTopAppBar(),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.getBackgroundColor(context),
                    AppTheme.getBackgroundColor(
                      context,
                    ).withValues(alpha: 0.98),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -130,
            left: -70,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 20,
            right: -90,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.secondaryAccent.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          RefreshIndicator(
            onRefresh: _loadInitialPosts,
            child: Column(
              children: [
                _buildFilterInfoBar(),
                _buildRecentCreatorsCarousel(),
                if (_posts.isNotEmpty && !_isLoading) _buildStoriesRow(),
                Expanded(
                  child: _isSwitchingSource
                      ? _buildSwitchingSourceIndicator()
                      : AnimatedOpacity(
                          opacity: _isFadingPage ? 0.0 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          child: _buildPostList(),
                        ),
                ),
                if (_posts.isNotEmpty && !_isSwitchingSource) _buildPaginationBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildTopAppBar() {
    return AppBar(
      toolbarHeight: 84,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryColor.withValues(alpha: 0.16),
              Colors.transparent,
            ],
          ),
        ),
      ),
      titleSpacing: 16,
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (bounds) =>
                AppTheme.primaryGradient.createShader(bounds),
            child: const Text(
              'Feed',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 34,
                color: Colors.white,
                letterSpacing: -1.2,
                height: 1,
              ),
            ),
          ),
          Text(
            'Latest drops from creators',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.getSecondaryTextColor(
                context,
              ).withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
      actions: [
        _buildTopActionButton(
          icon: Icons.download_rounded,
          onTap: _showDownloadManager,
          accentColor: AppTheme.secondaryAccent,
        ),
        _buildTopActionButton(
          icon: Icons.refresh_rounded,
          onTap: _loadInitialPosts,
          accentColor: _isLoading ? AppTheme.primaryColor : null,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryColor,
                  ),
                )
              : null,
        ),
        _buildTopActionButton(
          icon: Icons.tune_rounded,
          onTap: _showFilterBottomSheet,
          accentColor: _blockedTags.isNotEmpty ? AppTheme.primaryColor : null,
          margin: const EdgeInsets.only(right: 16),
        ),
      ],
    );
  }

  Widget _buildTopActionButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? accentColor,
    Widget? child,
    EdgeInsetsGeometry margin = const EdgeInsets.only(right: 8),
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = accentColor ?? AppTheme.getSecondaryTextColor(context);
    final isActive = accentColor != null;
    final bgColor = AppTheme.getElevatedSurfaceColorContext(
      context,
    ).withValues(alpha: isDark ? 0.84 : 0.6);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        margin: margin,
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  colors: [
                    activeColor.withValues(alpha: 0.24),
                    activeColor.withValues(alpha: 0.14),
                  ],
                )
              : null,
          color: isActive ? null : bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? activeColor.withValues(alpha: 0.45)
                : AppTheme.getBorderColor(context),
          ),
          boxShadow: [
            BoxShadow(
              color: (isActive ? activeColor : Colors.black).withValues(
                alpha: isDark ? (isActive ? 0.2 : 0.25) : 0.08,
              ),
              blurRadius: 12,
              spreadRadius: -6,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child:
              child ??
              Icon(
                icon,
                size: 20,
                color: isActive
                    ? activeColor
                    : AppTheme.getSecondaryTextColor(context),
              ),
        ),
      ),
    );
  }

  Widget _buildFilterInfoBar() {
    final services = [
      {'id': 'kemono', 'label': 'Kemono'},
      {'id': 'coomer', 'label': 'Coomer'},
    ];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(
          context,
        ).withValues(alpha: isDark ? 0.82 : 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.getBorderColor(context, opacity: 0.85),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            spreadRadius: -10,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Service selector row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppTheme.getCardColor(
                      context,
                    ).withValues(alpha: isDark ? 0.75 : 0.5),
                    borderRadius: BorderRadius.circular(AppTheme.pillRadius),
                    border: Border.all(
                      color: AppTheme.getBorderColor(context, opacity: 0.8),
                    ),
                  ),
                  child: Row(
                    children: services.map((s) {
                      final sid = s['id']!;
                      return Expanded(
                        child: _buildServiceToggle(id: sid, label: s['label']!),
                      );
                    }).toList(),
                  ),
                ),
              ),
              if (_blockedTags.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.warningColor.withValues(alpha: 0.34),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.block_rounded,
                        size: 14,
                        color: AppTheme.warningColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_blockedTags.length}',
                        style: const TextStyle(
                          color: AppTheme.warningColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          // Post search bar
          const SizedBox(height: 8),
          _buildPostSearchBar(),
        ],
      ),
    );
  }

  Widget _buildPostSearchBar() {
    final resultCount = _postSearchProvider.resultCount;
    final hasSearchQuery = _postSearchProvider.searchQuery.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context).withValues(alpha: isDark ? 0.6 : 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.getBorderColor(context, opacity: 0.6),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            size: 18,
            color: AppTheme.getSecondaryTextColor(context, opacity: 0.6),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _postSearchController,
              focusNode: _postSearchFocusNode,
              onChanged: (query) {
                _postSearchDebounce?.cancel();
                _postSearchDebounce =
                    Timer(const Duration(milliseconds: 350), () {
                  _postSearchProvider.setSearchQuery(query);

                  setState(() {
                    final postsProvider = context.read<PostsProvider>();
                    _posts = _getFilteredPosts(postsProvider.posts);
                  });
                });
              },
              decoration: InputDecoration(
                hintText: 'Search posts by title...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                hintStyle: TextStyle(
                  color:
                      AppTheme.getSecondaryTextColor(context, opacity: 0.5),
                ),
              ),
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.getOnSurfaceColor(context),
              ),
              textInputAction: TextInputAction.done,
            ),
          ),
          if (hasSearchQuery) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$resultCount',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                _postSearchController.clear();
                _postSearchProvider.clearSearch();
                _postSearchFocusNode.unfocus();
                setState(() {
                  final postsProvider = context.read<PostsProvider>();
                  _posts = _getFilteredPosts(postsProvider.posts);
                });
              },
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: AppTheme.getSecondaryTextColor(context, opacity: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildServiceToggle({required String id, required String label}) {
    final isSelected = id == _selectedService;
    final serviceColor = _getServiceColor(id);

    return GestureDetector(
      onTap: () async {
        if (isSelected) return;
        setState(() => _selectedService = id);
        await _loadInitialPosts();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    serviceColor.withValues(alpha: 0.95),
                    serviceColor.withValues(alpha: 0.72),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(AppTheme.pillRadius),
          border: Border.all(
            color: isSelected
                ? serviceColor.withValues(alpha: 0.95)
                : Colors.transparent,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: serviceColor.withValues(alpha: 0.35),
                    blurRadius: 12,
                    spreadRadius: -8,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : AppTheme.getSecondaryTextColor(context),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Horizontal carousel of recently-viewed creators from local storage.
  Widget _buildRecentCreatorsCarousel() {
    return Consumer<CreatorQuickAccessProvider>(
      builder: (context, quickAccess, _) {
        final recents = quickAccess.getRecentCreators(limit: 8);
        if (recents.isEmpty) return const SizedBox.shrink();

        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.history_rounded,
                      size: 14,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Recently Viewed',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.getSecondaryTextColor(context),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: recents.length,
                  itemBuilder: (context, index) {
                    return _buildRecentCreatorItem(
                      recents[index],
                      quickAccess,
                      isDark,
                    );
                  },
                ),
              ),
              Divider(
                height: 8,
                thickness: 0.5,
                color: AppTheme.getBorderColor(context).withValues(alpha: 0.4),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentCreatorItem(
    Creator creator,
    CreatorQuickAccessProvider quickAccess,
    bool isDark,
  ) {
    final domain = (creator.service == 'fansly' ||
            creator.service == 'onlyfans' ||
            creator.service == 'candfans')
        ? 'https://coomer.st'
        : 'https://kemono.cr';
    final avatarUrl =
        '$domain/data/avatars/${creator.service}/${creator.id}/avatar.jpg';
    final isFavorite = quickAccess.isFavorite(creator.id);

    return GestureDetector(
      onTap: () => _navigateToCreatorDetail(creator),
      onLongPress: () async {
        HapticFeedback.mediumImpact();
        await quickAccess.toggleFavoriteCreator(creator);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              quickAccess.isFavorite(creator.id)
                  ? '★ Added "${creator.name}" to favorites'
                  : 'Removed "${creator.name}" from favorites',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: SizedBox(
          width: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.topRight,
                children: [
                  // Story ring avatar
                  Container(
                    width: 56,
                    height: 56,
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isFavorite
                          ? const LinearGradient(
                              colors: [Color(0xFFFFD740), Color(0xFFFF8C00)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : AppTheme.storyRingGradient,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? AppTheme.darkBackgroundColor
                            : AppTheme.lightBackgroundColor,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: avatarUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: 112,
                          memCacheHeight: 112,
                          placeholder: (context, url) => Container(
                            color: AppTheme.darkElevatedSurfaceColor,
                            child: Center(
                              child: Text(
                                creator.name.isNotEmpty
                                    ? creator.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppTheme.darkElevatedSurfaceColor,
                            child: Center(
                              child: Text(
                                creator.name.isNotEmpty
                                    ? creator.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (isFavorite)
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD740),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? AppTheme.darkBackgroundColor
                              : AppTheme.lightBackgroundColor,
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        color: Colors.white,
                        size: 9,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                creator.name,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.getPrimaryTextColor(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Horizontal stories row showing recently active unique creators
  Widget _buildStoriesRow() {
    // Deduplicate creators from current page posts (preserve insertion order)
    final seen = <String>{};
    final creators = <Post>[];
    for (final post in _posts.take(50)) {
      final key = '${post.service}:${post.user}';
      if (seen.add(key)) {
        creators.add(post);
        if (creators.length >= 20) break;
      }
    }
    if (creators.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 100,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTheme.getBorderColor(context).withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: creators.length,
        itemBuilder: (context, index) {
          final post = creators[index];
          return _buildStoryItem(post, isDark);
        },
      ),
    );
  }

  Widget _buildStoryItem(Post post, bool isDark) {
    final domain =
        (post.service == 'fansly' ||
                post.service == 'onlyfans' ||
                post.service == 'candfans')
            ? 'https://coomer.st'
            : 'https://kemono.cr';
    final avatarUrl =
        '$domain/data/avatars/${post.service}/${post.user}/avatar.jpg';
    final name = post.user;

    return GestureDetector(
      onTap: () {
        final creator = Creator(
          id: post.user,
          name: post.user,
          service: post.service,
          indexed: 0,
          updated: 0,
        );
        _navigateToCreatorDetail(creator);
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: SizedBox(
          width: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Story ring avatar
              Container(
                width: 58,
                height: 58,
                padding: const EdgeInsets.all(2.5),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.storyRingGradient,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark
                        ? AppTheme.darkBackgroundColor
                        : AppTheme.lightBackgroundColor,
                  ),
                  padding: const EdgeInsets.all(2),
                  child: ClipOval(
                    child: Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      cacheWidth: 120,
                      cacheHeight: 120,
                      errorBuilder: (context, url, error) => Container(
                        color: AppTheme.darkElevatedSurfaceColor,
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: AppTheme.primaryLightColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                name,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.getPrimaryTextColor(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDownloadManager() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DownloadManagerScreen()),
    );
  }

  List<Post> _getPagePosts() {
    final startIndex = (_currentPage - 1) * _pageSize;
    if (startIndex >= _posts.length) {
      return const <Post>[];
    }
    final endIndex = (startIndex + _pageSize).clamp(0, _posts.length);
    return _posts.sublist(startIndex, endIndex);
  }

  Future<void> _goToPage(int page) async {
    if (page < 1) return;
    if (page == _currentPage) return;

    if (mounted) {
      setState(() => _isFadingPage = true);
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (!mounted) return;

    setState(() {
      _currentPage = page;
    });

    await _ensurePageLoaded(page);

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 50));
      setState(() => _isFadingPage = false);
    }
  }

  Future<void> _ensurePageLoaded(int page) async {
    final needed = page * _pageSize;
    while (_posts.length < needed && _hasMore) {
      if (_isLoading || _isLoadingMore) return;
      await _loadMorePosts();
    }

    if (!_hasMore && _posts.length < needed && mounted) {
      final lastPage = (_posts.length / _pageSize).ceil().clamp(1, 9999);
      setState(() {
        _currentPage = lastPage;
      });
    }
  }

  Widget _buildSwitchingSourceIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.getSurfaceColorContext(context),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            // The shimmer skeleton will look much better here than a basic spinner
            child: AppSkeleton.circle(size: 32),
          ),
          const SizedBox(height: 24),
          Text(
            'Switching API Source...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.getPrimaryTextColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connecting to ${_currentApiSource.name.toUpperCase()}',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.getSecondaryTextColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostList() {
    if (_isLoading && _posts.isEmpty) {
      final settings = context.watch<SettingsProvider>();
      final int columnCount = settings.latestPostsColumns.clamp(1, 3);
      final bool isSingleColumn = columnCount == 1;
      
      return MasonryGridView.builder(
        padding: isSingleColumn 
            ? const EdgeInsets.symmetric(vertical: 4) 
            : const EdgeInsets.fromLTRB(16, 4, 16, 4),
        gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columnCount,
        ),
        mainAxisSpacing: isSingleColumn ? 32 : 16,
        crossAxisSpacing: isSingleColumn ? 0 : 16,
        itemCount: 6, // Show 6 skeleton items
        itemBuilder: (context, index) => const PostGridSkeleton(),
      );
    }

    if (_error != null) {
      return AppErrorState(
        title: 'Error loading posts',
        message: _error!,
        onRetry: _loadInitialPosts,
      );
    }

    if (_posts.isEmpty && !_isLoading) {
      return _buildEmptyState();
    }

    final settings = context.watch<SettingsProvider>();
    final int columnCount = settings.latestPostsColumns.clamp(1, 3);
    final bool isSingleColumn = columnCount == 1;
    final pagePosts = _getPagePosts();

    if (pagePosts.isEmpty && _isLoadingMore) {
      return MasonryGridView.builder(
        padding: isSingleColumn 
            ? const EdgeInsets.symmetric(vertical: 4) 
            : const EdgeInsets.fromLTRB(16, 4, 16, 4),
        gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columnCount,
        ),
        mainAxisSpacing: isSingleColumn ? 32 : 16,
        crossAxisSpacing: isSingleColumn ? 0 : 16,
        itemCount: 6, // Show 6 skeleton items
        itemBuilder: (context, index) => const PostGridSkeleton(),
      );
    }

    return MasonryGridView.builder(
      controller: _scrollController,
      padding: isSingleColumn 
            ? const EdgeInsets.symmetric(vertical: 12) 
            : const EdgeInsets.fromLTRB(16, 4, 16, 4),
      gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columnCount,
      ),
      mainAxisSpacing: isSingleColumn ? 32 : 16,
      crossAxisSpacing: isSingleColumn ? 0 : 16,
      addAutomaticKeepAlives: false,
      itemCount: pagePosts.length,
      itemBuilder: (context, index) {
        final post = pagePosts[index];
        return RepaintBoundary(
          child: PostCard(
            post: post,
            isSingleColumn: isSingleColumn,
            apiSource: settings.defaultApiSource,
            onTap: () => _navigateToPostDetail(post),
            onCreatorTap: () {
              final creator = Creator(
                id: post.user,
                name: post.user,
                service: post.service,
                indexed: 0,
                updated: 0,
              );
              _navigateToCreatorDetail(creator);
            },
          ),
        );
      },
    );
  }

  // ignore: unused_element
  Widget _buildServiceBadge(String service, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        service.toUpperCase(),
        style: TextStyle(
          color: AppTheme.getOnSurfaceColor(context),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildMediaCountBadge(int mediaCount, bool hasVideo, bool isBlocked) {
    final badgeColor = isBlocked
        ? Colors.red.withValues(alpha: 0.9)
        : AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.65);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasVideo ? Icons.videocam : Icons.image,
            size: 12,
            color: AppTheme.getSurfaceColor(context),
          ),
          const SizedBox(width: 4),
          Text(
            mediaCount.toString(),
            style: TextStyle(
              color: AppTheme.getSurfaceColor(context),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalLoadedPages = (_posts.length / _pageSize).ceil().clamp(1, 9999);
    final canGoPrev = _currentPage > 1;
    final canGoNext = _hasMore || _currentPage < totalLoadedPages;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 108),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.getCardColor(
              context,
            ).withValues(alpha: isDark ? 0.94 : 0.8),
            AppTheme.getElevatedSurfaceColorContext(
              context,
            ).withValues(alpha: isDark ? 0.94 : 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.getBorderColor(context, opacity: 0.9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.1),
            blurRadius: 18,
            spreadRadius: -10,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildPageButton(
            icon: Icons.chevron_left_rounded,
            label: 'Prev',
            enabled: canGoPrev,
            onTap: () => _goToPage(_currentPage - 1),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Page $_currentPage',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoadingMore) ...[
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: AppSkeleton(
                           width: 14, 
                           height: 14, 
                           shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      _hasMore
                          ? '$totalLoadedPages+ loaded'
                          : '$totalLoadedPages total',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.getSecondaryTextColor(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildPageButton(
            icon: Icons.chevron_right_rounded,
            label: _hasMore ? 'Next' : 'End',
            enabled: canGoNext,
            isNext: true,
            onTap: () => _goToPage(_currentPage + 1),
          ),
        ],
      ),
    );
  }

  Widget _buildPageButton({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
    bool isNext = false,
  }) {
    final color = enabled
        ? (isNext ? Colors.white : AppTheme.primaryColor)
        : AppTheme.getSecondaryTextColor(context).withValues(alpha: 0.52);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minWidth: 92),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: enabled && isNext
                ? const LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.primaryDarkColor],
                  )
                : null,
            color: enabled
                ? (isNext
                      ? null
                      : AppTheme.primaryColor.withValues(alpha: 0.15))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: enabled
                  ? (isNext
                        ? AppTheme.primaryColor.withValues(alpha: 0.65)
                        : AppTheme.primaryColor.withValues(alpha: 0.36))
                  : Colors.transparent,
            ),
            boxShadow: enabled && isNext
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.33),
                      blurRadius: 14,
                      spreadRadius: -9,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isNext) ...[
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
              if (isNext) ...[
                const SizedBox(width: 4),
                Icon(icon, color: color, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildSocialActions() {
    final iconColor = AppTheme.getOnSurfaceColor(
      context,
    ).withValues(alpha: 0.6);
    return Row(
      children: [
        Icon(Icons.favorite_border, size: 16, color: iconColor),
        const SizedBox(width: 10),
        Icon(Icons.mode_comment_outlined, size: 16, color: iconColor),
        const SizedBox(width: 10),
        Icon(Icons.bookmark_border, size: 16, color: iconColor),
        const Spacer(),
        Icon(Icons.more_horiz, size: 16, color: iconColor),
      ],
    );
  }

  Widget _buildEmptyState() {
    final isFiltered = _blockedTags.isNotEmpty || _selectedService != 'kemono';

    if (isFiltered) {
      return AppEmptyState(
        icon: Icons.filter_list_off,
        title: 'All posts hidden by filters',
        message: 'Try adjusting your filters',
        actionLabel: 'Manage Filters',
        onAction: _showFilterBottomSheet,
      );
    }

    return const AppEmptyState(
      icon: Icons.article_outlined,
      title: 'No posts yet',
      message: 'Pull down to refresh',
    );
  }

  Widget _buildFilterBottomSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Filter Posts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Service filter
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Service',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: ['kemono', 'coomer'].map((service) {
                    final isSelected = _selectedService == service;
                    return FilterChip(
                      label: Text(service.toUpperCase()),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          // 🚀 NEW: Animasi transisi domain
                          _showDomainTransitionAnimation(
                            _selectedService,
                            service,
                          );

                          setState(() {
                            _selectedService = service;
                          });
                          _loadInitialPosts();
                          Navigator.pop(context);
                        }
                      },
                      backgroundColor: Colors.grey.withValues(alpha: 0.2),
                      selectedColor: AppTheme.primaryColor.withValues(
                        alpha: 0.2,
                      ),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : AppTheme.getOnBackgroundColor(context),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Tag filter info
          if (_blockedTags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Blocked Tags',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_blockedTags.length} tags are blocked',
                    style: TextStyle(
                      color: AppTheme.getOnSurfaceColor(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Show actual blocked tags
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _blockedTags.length,
                      itemBuilder: (context, index) {
                        final tag = _blockedTags[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Icon(
                                Icons.block,
                                size: 16,
                                color: Colors.red[400],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    color: AppTheme.getOnSurfaceColor(context),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _blockedTags.remove(tag);
                                  });
                                  final tagFilter = context
                                      .read<TagFilterProvider>();
                                  tagFilter.removeFromBlacklist(tag);
                                },
                                icon: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ignore: unused_element
  void _showPostOptions(Post post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.getSurfaceColor(context),
          borderRadius: const BorderRadius.only(
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
                    leading: const Icon(Icons.bookmark_border),
                    title: const Text('Bookmark Post'),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Bookmark feature coming soon!'),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('View Creator'),
                    onTap: () {
                      Navigator.pop(context);
                      final creator = Creator(
                        id: post.user,
                        service: post.service,
                        name: post.user,
                        indexed: 0,
                        updated: 0,
                        favorited: false,
                      );
                      _navigateToCreatorDetail(creator);
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

  // ignore: unused_element
  Widget _buildEmptyGridPlaceholder() {
    return Container();
  }

  /// Build full URL from path
  // ignore: unused_element
  String _buildFullUrl(String path, String service) {
    if (path.startsWith('http')) return path;
    final domain =
        (service == 'onlyfans' || service == 'fansly' || service == 'candfans')
        ? 'https://n2.coomer.st'
        : 'https://n2.kemono.cr';
    // Strip leading slash then any existing 'data/' prefix so API paths like
    // '/data/ab/cd/file.jpg' don't produce /data/data/ab/cd/file.jpg.
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final stripped = cleanPath.startsWith('data/') ? cleanPath.substring(5) : cleanPath;
    return '$domain/data/$stripped';
  }

  /// 🚀 NEW: Show domain transition animation
  void _showDomainTransitionAnimation(String fromDomain, String toDomain) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _DomainTransitionOverlay(
        fromDomain: fromDomain,
        toDomain: toDomain,
        onAnimationComplete: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }
}

/// 🚀 NEW: Domain transition animation overlay
class _DomainTransitionOverlay extends StatefulWidget {
  final String fromDomain;
  final String toDomain;
  final VoidCallback onAnimationComplete;

  const _DomainTransitionOverlay({
    required this.fromDomain,
    required this.toDomain,
    required this.onAnimationComplete,
  });

  @override
  State<_DomainTransitionOverlay> createState() =>
      _DomainTransitionOverlayState();
}

class _DomainTransitionOverlayState extends State<_DomainTransitionOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    _rotationAnimation =
        Tween<double>(
          begin: 0.0,
          end: 2 * 3.14159, // Full rotation
        ).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.2, 0.8, curve: Curves.easeInOut),
          ),
        );

    _controller.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        widget.onAnimationComplete();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: RotationTransition(
                  turns: _rotationAnimation,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // From domain (fading out)
                        Positioned.fill(
                          child: FadeTransition(
                            opacity: Tween<double>(begin: 1.0, end: 0.0)
                                .animate(
                                  CurvedAnimation(
                                    parent: _controller,
                                    curve: const Interval(
                                      0.0,
                                      0.4,
                                      curve: Curves.easeOut,
                                    ),
                                  ),
                                ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _getDomainIcon(widget.fromDomain),
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.fromDomain.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // To domain (fading in)
                        Positioned.fill(
                          child: FadeTransition(
                            opacity: Tween<double>(begin: 0.0, end: 1.0)
                                .animate(
                                  CurvedAnimation(
                                    parent: _controller,
                                    curve: const Interval(
                                      0.6,
                                      1.0,
                                      curve: Curves.easeIn,
                                    ),
                                  ),
                                ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _getDomainIcon(widget.toDomain),
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.toDomain.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Transition arrow
                        Positioned.fill(
                          child: FadeTransition(
                            opacity: Tween<double>(begin: 0.0, end: 1.0)
                                .animate(
                                  CurvedAnimation(
                                    parent: _controller,
                                    curve: const Interval(
                                      0.3,
                                      0.7,
                                      curve: Curves.easeInOut,
                                    ),
                                  ),
                                ),
                            child: Center(
                              child: Icon(
                                Icons.arrow_forward,
                                color: Colors.white.withValues(alpha: 0.8),
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  IconData _getDomainIcon(String domain) {
    switch (domain.toLowerCase()) {
      case 'kemono':
        return Icons.pets;
      case 'coomer':
        return Icons.face;
      default:
        return Icons.public;
    }
  }
}

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/rendering.dart';
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
import '../widgets/domain_status_badge.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../utils/logger.dart';
import '../../data/utils/domain_resolver.dart';

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
  final bool _isFadingPage = false;
  String _selectedService = 'kemono';
  List<String> _blockedTags = [];
  TagFilterProvider? _tagFilterProvider;

  // Post search state
  late PostSearchProvider _postSearchProvider;
  late TextEditingController _postSearchController;
  late FocusNode _postSearchFocusNode;
  Timer? _postSearchDebounce;
  bool _isSearchDebouncing = false;

  // UI state
  bool _isRecentlyViewedExpanded = true; // Collapsible section state

  // Staggered grid animation key – increment to re-trigger entry animations
  int _gridAnimationEpoch = 0;

  // Track domain values to detect changes
  String _lastKnownKemonoDomain = '';
  String _lastKnownCoomerDomain = '';

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

    // Capture initial domain values for change detection
    if (_settingsProvider != null) {
      _lastKnownKemonoDomain = _settingsProvider!.cleanKemonoDomain;
      _lastKnownCoomerDomain = _settingsProvider!.cleanCoomerDomain;
    }

    // Initialize search controllers
    _postSearchController = TextEditingController();
    _postSearchFocusNode = FocusNode();

    _settingsProvider?.addListener(_onSettingsChanged);
    _tagFilterProvider?.addListener(_onSettingsChanged);
    _scrollController.addListener(_onScrollChanged);
  }

  @override
  void dispose() {
    _settingsProvider?.removeListener(_onSettingsChanged);
    _tagFilterProvider?.removeListener(_onSettingsChanged);
    _scrollController.removeListener(_onScrollChanged);
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

  /// Scroll listener that triggers infinite-scroll loading when the user
  /// scrolls within 200 px of the bottom while scrolling downward.
  /// Also auto-collapses the "Recently Viewed" carousel while scrolling
  /// down, and restores it when the user scrolls back near the top.
  void _onScrollChanged() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;

    // Auto-hide / restore recently viewed
    if (pos.pixels < 60 && !_isRecentlyViewedExpanded) {
      setState(() => _isRecentlyViewedExpanded = true);
    } else if (pos.userScrollDirection == ScrollDirection.reverse &&
        pos.pixels > 80 &&
        _isRecentlyViewedExpanded) {
      setState(() => _isRecentlyViewedExpanded = false);
    }

    if (_isLoadingMore || _isLoading || !_hasMore) return;
    if (pos.pixels >= pos.maxScrollExtent - 200 &&
        pos.userScrollDirection == ScrollDirection.reverse) {
      _loadMorePosts();
    }
  }

  Future<void> _onSettingsChanged() async {
    if (!mounted) return;
    final postsProvider = context.read<PostsProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    
    // Check if the API source in settings has changed from what we're currently using
    final settingsApiSource = settingsProvider.defaultApiSource;
    final currentLoadedApiSource = postsProvider.currentApiSource;
    
    // Determine if we need to reload based on API source change
    final shouldReload = currentLoadedApiSource == null || 
                        currentLoadedApiSource != settingsApiSource;

    if (shouldReload) {
      if (_isSwitchingSource) return;

      setState(() {
        _isSwitchingSource = true;
        _selectedService = settingsApiSource.name;
        _blockedTags = _tagFilterProvider?.blacklist.toList() ?? [];
        _posts = [];
        // Reset search when switching service
        _postSearchProvider.clearSearch();
        _postSearchController.clear();
      });

      AppLogger.debug(
        '🔍 DEBUG: API source changed in settings. Clearing image cache and reloading...',
      );
      HapticFeedback.lightImpact();
      
      // ✅ CLEAR IMAGE CACHE BEFORE LOADING NEW POSTS
      // This prevents old kemono.cr thumbnails from persisting when switching to coomer.st
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      AppLogger.debug('🔍 DEBUG: Image cache cleared for API source change');
      
      await _loadInitialPosts();

      if (mounted) {
        setState(() {
          _isSwitchingSource = false;
          // Bump epoch to trigger staggered thumbnail re-animation
          _gridAnimationEpoch++;
        });
        // Keep domain tracking in sync after reload
        _lastKnownKemonoDomain = settingsProvider.cleanKemonoDomain;
        _lastKnownCoomerDomain = settingsProvider.cleanCoomerDomain;
      }
    } else {
      // API source hasn't changed.
      // Check if only the domain URL changed (triggers thumbnail refresh animation).
      final oldKemono = _lastKnownKemonoDomain;
      final oldCoomer = _lastKnownCoomerDomain;
      final domainChanged =
          settingsProvider.cleanKemonoDomain != oldKemono ||
          settingsProvider.cleanCoomerDomain != oldCoomer;

      _lastKnownKemonoDomain = settingsProvider.cleanKemonoDomain;
      _lastKnownCoomerDomain = settingsProvider.cleanCoomerDomain;

      if (domainChanged) {
        // Show visual feedback for the domain switch
        final fromDomain = postsProvider.currentApiSource == ApiSource.kemono
            ? oldKemono
            : oldCoomer;
        final toDomain = postsProvider.currentApiSource == ApiSource.kemono
            ? settingsProvider.cleanKemonoDomain
            : settingsProvider.cleanCoomerDomain;
        _showDomainTransitionAnimation(fromDomain, toDomain);
      }

      setState(() {
        _blockedTags = _tagFilterProvider?.blacklist.toList() ?? [];
        _posts = _getFilteredPosts(postsProvider.posts);
        if (domainChanged) {
          // Clear cached images so thumbnails reload from the new domain
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
          _gridAnimationEpoch++;
        }
      });

      // Reload posts from the new domain URL
      if (domainChanged) {
        await _loadInitialPosts();
      }
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
    });

    try {
      final postsProvider = context.read<PostsProvider>();
      AppLogger.debug(
        '🔍 DEBUG: _loadInitialPosts - Starting load with API source: $_currentApiSource',
      );
      
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
        AppLogger.debug(
          '🔍 DEBUG: _loadInitialPosts - Loaded ${_posts.length} posts from ${_currentApiSource.name}',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
        AppLogger.error(
          '🔍 DEBUG: _loadInitialPosts - Error loading posts: $e',
          tag: 'LatestPostsScreen',
        );
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
    final apiSource = DomainResolver.apiSourceForService(post.service);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PostDetailScreen(post: post, apiSource: apiSource),
      ),
    );
  }

  void _navigateToCreatorDetail(Creator creator) {
    final apiSource = DomainResolver.apiSourceForService(creator.service);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CreatorDetailScreen(creator: creator, apiSource: apiSource),
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
                // Stories row removed to reduce clutter (Recently Viewed handles creator browsing)
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
      title: Consumer<PostsProvider>(
        builder: (context, postsProvider, _) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                  const SizedBox(width: 12),
                  // Active domain badge – shows current domain with color coding
                  DomainStatusBadge(
                    apiSource: postsProvider.currentApiSource?.name ??
                        'kemono',
                    compact: true,
                  ),
                ],
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
          );
        },
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
    final noResults = hasSearchQuery && !_isSearchDebouncing && resultCount == 0;
    final accentColor = noResults ? Colors.orange : AppTheme.primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(context).withValues(alpha: isDark ? 0.6 : 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasSearchQuery
                  ? accentColor.withValues(alpha: 0.55)
                  : AppTheme.getBorderColor(context, opacity: 0.6),
              width: hasSearchQuery ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              _isSearchDebouncing
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryColor.withValues(alpha: 0.7),
                      ),
                    )
                  : Icon(
                      noResults ? Icons.search_off_rounded : Icons.search_rounded,
                      size: 18,
                      color: noResults
                          ? Colors.orange.withValues(alpha: 0.8)
                          : AppTheme.getSecondaryTextColor(context, opacity: 0.6),
                    ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _postSearchController,
                  focusNode: _postSearchFocusNode,
                  onChanged: (query) {
                    setState(() => _isSearchDebouncing = query.isNotEmpty);
                    _postSearchDebounce?.cancel();
                    _postSearchDebounce =
                        Timer(const Duration(milliseconds: 350), () {
                      _postSearchProvider.setSearchQuery(query);
                      setState(() {
                        _isSearchDebouncing = false;
                        final postsProvider = context.read<PostsProvider>();
                        _posts = _getFilteredPosts(postsProvider.posts);
                      });
                    });
                  },
                  onSubmitted: (_) {
                    // Scroll back to top when search is submitted
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                    _postSearchFocusNode.unfocus();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search loaded posts by title…',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    hintStyle: TextStyle(
                      color: AppTheme.getSecondaryTextColor(context, opacity: 0.5),
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.getOnSurfaceColor(context),
                  ),
                  textInputAction: TextInputAction.search,
                ),
              ),
              if (hasSearchQuery) ...[
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _isSearchDebouncing ? '…' : '$resultCount',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
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
                      _isSearchDebouncing = false;
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
        ),
        if (noResults)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'No results in loaded posts — scroll down to load more',
              style: TextStyle(
                fontSize: 11,
                color: Colors.orange.withValues(alpha: 0.85),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
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
              // Header with collapse button
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isRecentlyViewedExpanded = !_isRecentlyViewedExpanded;
                  });
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
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
                      AnimatedRotation(
                        turns: _isRecentlyViewedExpanded ? 0 : 0.5,
                        duration: const Duration(milliseconds: 250),
                        child: Icon(
                          Icons.expand_less_rounded,
                          size: 18,
                          color:
                              AppTheme.getSecondaryTextColor(context)
                                  .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Collapsible content
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                alignment: Alignment.topCenter,
                child: _isRecentlyViewedExpanded
                    ? SizedBox(
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
                      )
                    : const SizedBox.shrink(),
              ),
              Divider(
                height: 8,
                thickness: 0.5,
                color:
                    AppTheme.getBorderColor(context).withValues(alpha: 0.4),
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
    final settings = context.read<SettingsProvider>();
    final domain = (creator.service == 'fansly' ||
            creator.service == 'onlyfans' ||
            creator.service == 'candfans')
        ? 'https://${settings.cleanCoomerDomain}'
        : 'https://${settings.cleanKemonoDomain}';
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



  void _showDownloadManager() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DownloadManagerScreen()),
    );
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
            : const EdgeInsets.fromLTRB(12, 12, 12, 12),
        gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columnCount,
        ),
        mainAxisSpacing: isSingleColumn ? 32 : 12,
        crossAxisSpacing: isSingleColumn ? 0 : 12,
        itemCount: 6, // Show 6 skeleton items
        itemBuilder: (context, index) => const PostGridSkeleton(),
      );
    }

    if (_error != null) {
      return _buildApiErrorState();
    }

    if (_posts.isEmpty && !_isLoading) {
      return _buildEmptyState();
    }

    final settings = context.watch<SettingsProvider>();
    final int columnCount = settings.latestPostsColumns.clamp(1, 3);
    final bool isSingleColumn = columnCount == 1;

    // Show all loaded posts for infinite scroll; append skeleton rows at
    // the bottom while the next page is being fetched.
    final skeletonCount = _isLoadingMore ? columnCount : 0;
    final totalItemCount = _posts.length + skeletonCount;

    return MasonryGridView.builder(
      controller: _scrollController,
      padding: isSingleColumn 
            ? const EdgeInsets.symmetric(vertical: 12) 
            : const EdgeInsets.fromLTRB(12, 12, 12, 12),
      gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columnCount,
      ),
      mainAxisSpacing: isSingleColumn ? 32 : 12,
      crossAxisSpacing: isSingleColumn ? 0 : 12,
      addAutomaticKeepAlives: false,
      itemCount: totalItemCount,
      itemBuilder: (context, index) {
        // Skeleton placeholder rows at the bottom
        if (index >= _posts.length) {
          return const PostGridSkeleton();
        }
        final post = _posts[index];
        return RepaintBoundary(
          child: _StaggeredFadeItem(
            index: index,
            epoch: _gridAnimationEpoch,
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
    final totalLoaded = _posts.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 108),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
        mainAxisAlignment: MainAxisAlignment.center,
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
            const SizedBox(width: 8),
          ],
          Text(
            _isLoadingMore
                ? 'Loading more…'
                : (_hasMore
                    ? '$totalLoaded loaded · scroll for more'
                    : '$totalLoaded posts · all loaded'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.getSecondaryTextColor(context),
            ),
          ),
        ],
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

  /// Display error message when API is unavailable with option to switch API
  Widget _buildApiErrorState() {
    final isApiUnavailable = _error?.contains('unavailable') ?? false;
    final isRetrying = _error?.contains('retry') ?? false;
    
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Error icon with animation
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: isRetrying 
                      ? AppTheme.warningColor.withValues(alpha: 0.15)
                      : AppTheme.errorColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isRetrying ? Icons.hourglass_top_rounded : Icons.wifi_off_rounded,
                  size: 40,
                  color: isRetrying 
                      ? AppTheme.warningColor
                      : AppTheme.errorColor,
                ),
              ),
              const SizedBox(height: 24),
              
              // Error title
              Text(
                isRetrying ? 'Connecting...' : 'API Unavailable',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // Error message
              Text(
                _error ?? 'Unable to load posts. Please try again.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.getSecondaryTextColor(context),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Action buttons
              if (!isRetrying) ...[
                // Retry button
                GestureDetector(
                  onTap: _loadInitialPosts,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor.withValues(alpha: 0.9),
                          AppTheme.primaryColor.withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Try Again',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Switch API button  
                if (isApiUnavailable)
                  GestureDetector(
                    onTap: () {
                      // Navigate to settings to switch API
                      // You may need to adjust this based on your app's navigation
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Switch API in Settings'),
                          action: SnackBarAction(
                            label: 'Settings',
                            onPressed: () {
                              // Navigate to settings screen
                              // This would be: Navigator.pushNamed(context, '/settings');
                            },
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.getElevatedSurfaceColorContext(context)
                            .withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.getBorderColor(context),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.settings_rounded,
                            color: AppTheme.primaryColor,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Switch API',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
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

/// Staggered fade-in widget for grid items.
///
/// When [epoch] changes, the item restarts its entry animation with a delay
/// proportional to [index] (capped at 15 items to keep it snappy).
class _StaggeredFadeItem extends StatefulWidget {
  final int index;
  final int epoch;
  final Widget child;

  const _StaggeredFadeItem({
    required this.index,
    required this.epoch,
    required this.child,
  });

  @override
  State<_StaggeredFadeItem> createState() => _StaggeredFadeItemState();
}

class _StaggeredFadeItemState extends State<_StaggeredFadeItem>
    with SingleTickerProviderStateMixin {
  static const int _maxStaggeredItems = 14;
  static const int _delayPerItemMs = 40;

  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity =
        Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
        );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _scheduleAnimation();
  }

  @override
  void didUpdateWidget(_StaggeredFadeItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.epoch != widget.epoch) {
      _scheduleAnimation();
    }
  }

  void _scheduleAnimation() {
    if (!mounted) return;
    _ctrl.reset();
    final delay = Duration(
      milliseconds: (widget.index.clamp(0, _maxStaggeredItems) * _delayPerItemMs),
    );
    Future.delayed(delay, () {
      if (mounted) {
        _ctrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

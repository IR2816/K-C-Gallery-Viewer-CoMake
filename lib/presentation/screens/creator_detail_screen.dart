import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

// Domain
import '../../domain/entities/creator.dart';
import '../../domain/entities/post.dart';
import '../widgets/skeleton_loader.dart';
import '../../domain/entities/api_source.dart';
import '../../domain/entities/discord_server.dart';
import '../../domain/repositories/kemono_repository.dart';

// Providers
import '../providers/posts_provider.dart';
import '../providers/creators_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tag_filter_provider.dart';

// Theme
import '../theme/app_theme.dart';

// Screens
import 'post_detail_screen.dart';
import 'fullscreen_media_viewer.dart';
import 'video_player_screen.dart';
import 'discord_channel_list_screen.dart';

/// Creator Detail Screen - Clean & Simple
///
/// Design Principles:
/// - Single source of truth (PostsProvider)
/// - Compact utility header (not hero header)
/// - Simple grid layout for media
/// - No linkify in preview (PostDetail job)
/// - Consistent with PostDetail patterns
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
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  // Core Controllers
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;
  final ScrollController _postsScrollController = ScrollController();
  final ScrollController _mediaScrollController = ScrollController();

  // Minimal State (Single Source of Truth: PostsProvider)
  double _postsScrollOffset = 0.0;
  double _mediaScrollOffset = 0.0;

  // Media cache (performance optimization)
  List<Map<String, dynamic>> _cachedMediaItems = [];
  String? _mediaCacheKey;
  final Map<String, Future<Size>> _imageSizeCache = {};
  Future<List<_LinkedAccount>>? _linkedAccountsFuture;
  late ApiSource _activeApiSource;
  final bool _isSwitchingSource = false;

  // State preservation
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _activeApiSource = widget.apiSource;
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadCreatorPosts();
    _linkedAccountsFuture = _fetchLinkedAccounts();
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
      final postsProvider = Provider.of<PostsProvider>(context, listen: false);
      postsProvider.clearPosts();
      _cachedMediaItems = [];
      _mediaCacheKey = null;

      await postsProvider.loadCreatorPosts(
        widget.creator.service,
        widget.creator.id,
        refresh: true,
        apiSource: _activeApiSource,
      );
    } catch (e) {
      // Error handling done by provider, no local state needed
    }
  }

  Future<List<_LinkedAccount>> _fetchLinkedAccounts() async {
    try {
      final repository = context.read<KemonoRepository>();
      final rawLinks = await repository.getCreatorLinks(
        widget.creator.service,
        widget.creator.id,
        apiSource: _activeApiSource,
      );
      return rawLinks
          .whereType<Map>()
          .map((e) => _LinkedAccount.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // PERFORMANCE OPTIMIZATION
  void _ensureMediaCache(List<Post> visiblePosts) {
    final key = visiblePosts.isEmpty
        ? 'empty'
        : '${visiblePosts.length}|${visiblePosts.last.id}';
    if (_mediaCacheKey == key) return;
    _cachedMediaItems = [];

    for (final post in visiblePosts) {
      // Add attachments
      for (final attachment in post.attachments) {
        if (_isImageFile(attachment.name)) {
          _cachedMediaItems.add({
            'type': 'image',
            'url': _buildFullUrl(attachment.path),
            'thumbnail': _buildThumbnailUrl(attachment.path),
            'name': attachment.name,
            'postId': post.id,
          });
        } else if (_isVideoFile(attachment.name)) {
          _cachedMediaItems.add({
            'type': 'video',
            'url': _buildFullUrl(attachment.path),
            'name': attachment.name,
            'postId': post.id,
            'thumbnail': _buildFullUrl(
              attachment.path.replaceFirst(RegExp(r'\.[^.]+$'), '.jpg'),
            ), // Try to get thumbnail
          });
        }
      }

      // Add files
      for (final file in post.file) {
        if (_isImageFile(file.name)) {
          _cachedMediaItems.add({
            'type': 'image',
            'url': _buildFullUrl(file.path),
            'thumbnail': _buildThumbnailUrl(file.path),
            'name': file.name,
            'postId': post.id,
          });
        } else if (_isVideoFile(file.name)) {
          _cachedMediaItems.add({
            'type': 'video',
            'url': _buildFullUrl(file.path),
            'name': file.name,
            'postId': post.id,
            'thumbnail': _buildFullUrl(
              file.path.replaceFirst(RegExp(r'\.[^.]+$'), '.jpg'),
            ), // Try to get thumbnail
          });
        }
      }
    }

    _mediaCacheKey = key;
  }

  bool _isImageFile(String filename) {
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    return imageExtensions.any((ext) => filename.toLowerCase().endsWith(ext));
  }

  bool _isVideoFile(String filename) {
    final videoExtensions = [
      '.mp4',
      '.avi',
      '.mov',
      '.wmv',
      '.flv',
      '.webm',
      '.mkv',
    ];
    return videoExtensions.any((ext) => filename.toLowerCase().endsWith(ext));
  }

  ApiSource _apiSourceForService(String service) {
    const coomerServices = {'onlyfans', 'fansly', 'candfans'};
    return coomerServices.contains(service.toLowerCase())
        ? ApiSource.coomer
        : ApiSource.kemono;
  }

  String _buildLinkedBannerUrl(String service, String creatorId) {
    final apiSource = _apiSourceForService(service);
    final base = apiSource == ApiSource.coomer
        ? 'https://img.coomer.st'
        : 'https://img.kemono.cr';
    return '$base/banners/$service/$creatorId';
  }

  String _buildLinkedIconUrl(String service, String creatorId) {
    final apiSource = _apiSourceForService(service);
    final base = apiSource == ApiSource.coomer
        ? 'https://img.coomer.st'
        : 'https://img.kemono.cr';
    return '$base/icons/$service/$creatorId';
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

  List<Post> _filterPosts(
    List<Post> posts, {
    required bool hideNsfw,
    required Set<String> blockedTags,
  }) {
    if (!hideNsfw && blockedTags.isEmpty) return posts;

    return posts.where((post) {
      if (hideNsfw && _isNsfwPost(post)) return false;
      if (blockedTags.isEmpty) return true;
      return !blockedTags.any(
        (blockedTag) => post.tags.any(
          (postTag) => postTag.toLowerCase().contains(blockedTag),
        ),
      );
    }).toList();
  }

  Future<Size> _getImageSize(String imageUrl) {
    return _imageSizeCache.putIfAbsent(imageUrl, () {
      final completer = Completer<Size>();
      final image = Image(
        image: CachedNetworkImageProvider(
          imageUrl,
          headers: _getCoomerHeaders(imageUrl),
        ),
      );

      image.image
          .resolve(const ImageConfiguration())
          .addListener(
            ImageStreamListener(
              (info, _) {
                if (!completer.isCompleted) {
                  completer.complete(
                    Size(
                      info.image.width.toDouble(),
                      info.image.height.toDouble(),
                    ),
                  );
                }
              },
              onError: (error, stackTrace) {
                if (!completer.isCompleted) {
                  completer.complete(const Size(1.0, 1.0));
                }
              },
            ),
          );

      return completer.future;
    });
  }

  // FIXED - Use ApiSource instead of service string
  String _buildFullUrl(String path) {
    if (path.startsWith('http')) {
      return path;
    }

    final domain = _activeApiSource == ApiSource.coomer
        ? 'https://n2.coomer.st'
        : 'https://kemono.cr';

    return '$domain/data$path';
  }

  String _buildThumbnailUrl(String path) {
    final clean = path.startsWith('/') ? path : '/$path';
    final base = _activeApiSource == ApiSource.coomer
        ? 'https://img.coomer.st'
        : 'https://img.kemono.cr';
    return '$base/thumbnail/data$clean';
  }

  /// ðŸš€ NEW: Build creator banner URL
  String _buildCreatorBannerUrl({
    required ApiSource apiSource,
    required String service,
    required String creatorId,
  }) {
    final base = apiSource == ApiSource.coomer
        ? 'https://img.coomer.st'
        : 'https://img.kemono.cr';

    return '$base/banners/$service/$creatorId';
  }

  /// ðŸš€ NEW: Build creator icon URL
  String _buildCreatorIconUrl({
    required ApiSource apiSource,
    required String service,
    required String creatorId,
  }) {
    final base = apiSource == ApiSource.coomer
        ? 'https://img.coomer.st'
        : 'https://img.kemono.cr';

    return '$base/icons/$service/$creatorId';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: Consumer<PostsProvider>(
        builder: (context, postsProvider, _) {
          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              // âœ… FIXED: SliverAppBar dengan banner di flexible space
              _buildCompactSliverAppBar(),

              // Simple Tabs
              _buildTabs(),

              // Tab Content - Single Source of Truth
              SliverFillRemaining(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPostsTab(postsProvider),
                    _buildMediaTab(postsProvider),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCompactSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      floating: false,
      backgroundColor: AppTheme.getBackgroundColor(context),
      foregroundColor: AppTheme.getOnSurfaceColor(context),
      elevation: 0,
      scrolledUnderElevation: 0,
      expandedHeight: 238,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (_isSwitchingSource)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: AppSkeleton(
                   width: 18,
                   height: 18,
                   shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        // Bookmark Button
        Consumer<CreatorsProvider>(
          builder: (context, creatorsProvider, child) {
            final isFavorited = creatorsProvider.favoriteCreators.contains(
              widget.creator.id,
            );
            return IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isFavorited ? Icons.bookmark : Icons.bookmark_border,
                  color: isFavorited ? AppTheme.primaryColor : Colors.white,
                  size: 20,
                ),
              ),
              onPressed: () => _toggleBookmark(creatorsProvider),
            );
          },
        ),

        // Open in Browser
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.open_in_browser,
              color: Colors.white,
              size: 20,
            ),
          ),
          onPressed: _openCreatorInBrowser,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 88, bottom: 20, right: 16),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Colors.white70],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(bounds),
          child: Text(
            widget.creator.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: -0.8,
              shadows: [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        background: Stack(
          children: [
            _buildCreatorBanner(),

            // Immersive Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.2),
                    Colors.black.withValues(alpha: 0.8),
                  ],
                  stops: const [0.0, 0.4, 0.6, 1.0],
                ),
              ),
            ),

            // Avatar with glow
            Positioned(left: 16, bottom: 12, child: _buildCreatorAvatar()),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _TabBarDelegate(
        Container(
          color: AppTheme.getBackgroundColor(context),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.getCardColor(context),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: AppTheme.getBorderColor(context, opacity: 0.05),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                indicatorColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: AppTheme.getSecondaryTextColor(context),
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.grid_view_rounded, size: 16),
                        SizedBox(width: 8),
                        Text('POSTS'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_library_rounded, size: 16),
                        SizedBox(width: 8),
                        Text('MEDIA'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ðŸš€ UPDATED: Build creator banner widget (untuk FlexibleSpaceBar)
  Widget _buildCreatorBanner() {
    final bannerUrl = _buildCreatorBannerUrl(
      apiSource: _activeApiSource,
      service: widget.creator.service,
      creatorId: widget.creator.id,
    );

    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: CachedNetworkImage(
        imageUrl: bannerUrl,
        fit: BoxFit.cover,
        // ðŸš€ FIX: Add HTTP headers for Coomer CDN anti-hotlink protection
        httpHeaders: _getCoomerHeaders(bannerUrl),
        errorWidget: (context, url, error) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.1),
                  AppTheme.primaryColor.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Center(
              child: Icon(
                Icons.image,
                size: 48,
                color: AppTheme.secondaryTextColor,
              ),
            ),
          );
        },
        placeholder: (context, url) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.1),
                  AppTheme.primaryColor.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: const AppSkeleton(
              shape: BoxShape.rectangle,
            ),
          );
        },
      ),
    );
  }

  /// 🚀 NEW: Build creator avatar widget
  Widget _buildCreatorAvatar() {
    final iconUrl = _buildCreatorIconUrl(
      apiSource: _activeApiSource,
      service: widget.creator.service,
      creatorId: widget.creator.id,
    );

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 32,
        backgroundColor: AppTheme.getCardColor(context),
        backgroundImage: CachedNetworkImageProvider(
          iconUrl,
          headers: _getCoomerHeaders(iconUrl),
        ),
        onBackgroundImageError: (error, stackTrace) {},
        child: Icon(
          Icons.person,
          color: AppTheme.getSecondaryTextColor(context),
          size: 32,
        ),
      ),
    );
  }

  /// ðŸš€ NEW: Get HTTP headers for Coomer CDN anti-hotlink protection
  Map<String, String>? _getCoomerHeaders(String imageUrl) {
    final isCoomerDomain =
        imageUrl.contains('coomer.st') || imageUrl.contains('img.coomer.st');

    if (isCoomerDomain) {
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

    return null; // No headers needed for non-Coomer domains
  }

  // SIMPLIFIED - Single Source of Truth from PostsProvider
  Widget _buildPostsTab(PostsProvider postsProvider) {
    final settings = context.watch<SettingsProvider>();
    final blockedTags = context.watch<TagFilterProvider>().blacklist;
    final visiblePosts = _filterPosts(
      postsProvider.posts,
      hideNsfw: settings.hideNsfw,
      blockedTags: blockedTags,
    );
    if (postsProvider.isLoading && postsProvider.posts.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        itemBuilder: (context, index) => const Padding(
           padding: EdgeInsets.only(bottom: 16),
           child: PostGridSkeleton(),
        ),
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
              color: AppTheme.getErrorColor(context),
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading posts',
              style: AppTheme.getTitleStyle(
                context,
              ).copyWith(color: AppTheme.getErrorColor(context)),
            ),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Text(
                postsProvider.error!,
                style: AppTheme.getCaptionStyle(
                  context,
                ).copyWith(color: AppTheme.getErrorColor(context)),
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

    if (visiblePosts.isEmpty && !postsProvider.isLoading) {
      final hasActiveFilters = settings.hideNsfw || blockedTags.isNotEmpty;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 64,
              color: AppTheme.getOnSurfaceColor(context),
            ),
            const SizedBox(height: 16),
            Text(
              hasActiveFilters ? 'No posts match your filters' : 'No posts yet',
              style: AppTheme.getTitleStyle(
                context,
              ).copyWith(color: AppTheme.secondaryTextColor),
            ),
            const SizedBox(height: 8),
            Text(
              hasActiveFilters
                  ? 'Try changing filters in Settings'
                  : 'This creator hasn\'t posted anything yet',
              style: AppTheme.getCaptionStyle(
                context,
              ).copyWith(color: AppTheme.secondaryTextColor),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: RefreshIndicator(
        onRefresh: () => _loadCreatorPosts(),
        child: CustomScrollView(
          controller: _postsScrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (_linkedAccountsFuture != null)
              SliverToBoxAdapter(child: _buildLinkedAccountsSection()),

            SliverToBoxAdapter(
              child: _buildCreatorOverviewCard(
                title: 'Post Stream',
                subtitle: _buildPostsSummaryText(
                  visiblePosts.length,
                  postsProvider.posts.length,
                  postsProvider.hasMore,
                ),
                accentColor: _activeApiSource == ApiSource.kemono
                    ? AppTheme.primaryColor
                    : AppTheme.accentColor,
                chips: [
                  _buildOverviewChip(
                    icon: Icons.article_rounded,
                    label: '${visiblePosts.length} visible',
                  ),
                  _buildOverviewChip(
                    icon: Icons.visibility_off_rounded,
                    label:
                        '${(postsProvider.posts.length - visiblePosts.length).clamp(0, 9999)} hidden',
                  ),
                  _buildOverviewChip(
                    icon: postsProvider.hasMore
                        ? Icons.bolt_rounded
                        : Icons.done_all_rounded,
                    label: postsProvider.hasMore
                        ? 'Auto loading'
                        : 'Fully loaded',
                  ),
                ],
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == visiblePosts.length &&
                        postsProvider.isLoading) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: PostGridSkeleton(),
                      );
                    }

                    final post = visiblePosts[index];
                    return _buildPostCard(post);
                  },
                  childCount:
                      visiblePosts.length + (postsProvider.isLoading ? 1 : 0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatorOverviewCard({
    required String title,
    required String subtitle,
    required Color accentColor,
    required List<Widget> chips,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.getCardColor(context).withValues(alpha: 0.96),
            AppTheme.getSurfaceColorContext(context).withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.getBorderColor(context).withValues(alpha: 0.85),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 18,
            spreadRadius: -10,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.28),
                      accentColor.withValues(alpha: 0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                ),
                child: Icon(
                  Icons.dashboard_customize_rounded,
                  size: 20,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppTheme.getPrimaryTextColor(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppTheme.getSecondaryTextColor(
                          context,
                        ).withValues(alpha: 0.95),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  _activeApiSource == ApiSource.kemono ? 'KEMONO' : 'COOMER',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      ),
    );
  }

  Widget _buildOverviewChip({required IconData icon, required String label}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.getElevatedSurfaceColorContext(
          context,
        ).withValues(alpha: isDark ? 0.8 : 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.getBorderColor(
            context,
          ).withValues(alpha: isDark ? 0.75 : 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.getSecondaryTextColor(context)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.getSecondaryTextColor(context),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Media Tab - Masonry layout to respect image aspect ratio
  Widget _buildMediaTab(PostsProvider postsProvider) {
    final settings = context.watch<SettingsProvider>();
    final blockedTags = context.watch<TagFilterProvider>().blacklist;
    final visiblePosts = _filterPosts(
      postsProvider.posts,
      hideNsfw: settings.hideNsfw,
      blockedTags: blockedTags,
    );

    _ensureMediaCache(visiblePosts);
    if (postsProvider.isLoading && postsProvider.posts.isEmpty) {
      // Calculate responsive column count based on screen width
      final screenWidth = MediaQuery.of(context).size.width;
      int columnCount = 2;
      if (screenWidth > 600) columnCount = 3;
      if (screenWidth > 900) columnCount = 4;
      
      return MasonryGridView.builder(
        padding: const EdgeInsets.all(4),
        gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columnCount,
        ),
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        itemCount: 8,
        itemBuilder: (context, index) => AppSkeleton.rounded(
          height: index % 2 == 0 ? 200 : 150,
          borderRadius: 8,
        ),
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
              color: AppTheme.getErrorColor(context),
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading media',
              style: AppTheme.getTitleStyle(
                context,
              ).copyWith(color: AppTheme.getErrorColor(context)),
            ),
            const SizedBox(height: 8),
            Text(
              postsProvider.error!,
              style: AppTheme.getCaptionStyle(
                context,
              ).copyWith(color: AppTheme.getErrorColor(context)),
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
      final hasActiveFilters = settings.hideNsfw || blockedTags.isNotEmpty;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: AppTheme.getOnSurfaceColor(context),
            ),
            const SizedBox(height: 16),
            Text(
              hasActiveFilters
                  ? 'No media matches your filters'
                  : 'No media yet',
              style: AppTheme.getTitleStyle(
                context,
              ).copyWith(color: AppTheme.secondaryTextColor),
            ),
            const SizedBox(height: 8),
            Text(
              hasActiveFilters
                  ? 'Try changing filters in Settings'
                  : 'This creator hasn\'t posted any media yet',
              style: AppTheme.getCaptionStyle(
                context,
              ).copyWith(color: AppTheme.secondaryTextColor),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadCreatorPosts(),
      child: MasonryGridView.count(
        controller: _mediaScrollController,
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        itemCount: _cachedMediaItems.length,
        itemBuilder: (context, index) {
          final mediaItem = _cachedMediaItems[index];
          return _buildMediaGridItem(mediaItem);
        },
      ),
    );
  }

  Widget _buildLinkedAccountsSection() {
    return FutureBuilder<List<_LinkedAccount>>(
      future: _linkedAccountsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final links = snapshot.data ?? const [];
        if (links.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Linked Accounts'),
              const SizedBox(height: 8),
              Column(
                children: links
                    .map((link) => _buildLinkedAccountCard(link))
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTheme.getTitleStyle(
        context,
      ).copyWith(fontWeight: FontWeight.w700),
    );
  }

  Widget _buildLinkedAccountCard(_LinkedAccount link) {
    final serviceColor = _getServiceColor(link.service);
    final bannerUrl = _buildLinkedBannerUrl(link.service, link.id);
    final iconUrl = _buildLinkedIconUrl(link.service, link.id);
    final subtitle = link.publicId != null && link.publicId!.isNotEmpty
        ? '@${link.publicId}'
        : link.name;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.getBorderColor(
            context,
          ).withValues(alpha: isDark ? 0.05 : 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (link.service.toLowerCase() == 'discord') {
                final serverName = link.name.isNotEmpty
                    ? link.name
                    : (link.publicId ?? link.id);
                final server = DiscordServer(
                  id: link.id,
                  name: serverName,
                  indexed: DateTime.now(),
                  updated: DateTime.now(),
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DiscordChannelListScreen(server: server),
                  ),
                );
                return;
              }
              final creator = Creator(
                id: link.id,
                service: link.service,
                name: link.name.isNotEmpty
                    ? link.name
                    : (link.publicId ?? link.id),
                indexed: 0,
                updated: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreatorDetailScreen(
                    creator: creator,
                    apiSource: _apiSourceForService(link.service),
                  ),
                ),
              );
            },
            child: SizedBox(
              height: 100, // Adjusted for premium look
              child: Stack(
                children: [
                  // Banner Background
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: bannerUrl,
                      httpHeaders: _getCoomerHeaders(bannerUrl),
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              serviceColor.withValues(alpha: 0.3),
                              AppTheme.getCardColor(context),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Overlay Gradient
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.black.withValues(alpha: 0.8),
                            Colors.black.withValues(alpha: 0.4),
                            Colors.black.withValues(alpha: 0.1),
                          ],
                          stops: const [0.0, 0.4, 0.8],
                        ),
                      ),
                    ),
                  ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // Icon with glow
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: CachedNetworkImage(
                              imageUrl: iconUrl,
                              httpHeaders: _getCoomerHeaders(iconUrl),
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => Container(
                                color: serviceColor,
                                child: Center(
                                  child: Text(
                                    link.name.isNotEmpty
                                        ? link.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: serviceColor,
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: serviceColor.withValues(
                                        alpha: 0.4,
                                      ),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  link.service.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                link.name.isNotEmpty ? link.name : link.id,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white.withValues(alpha: 0.5),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getServiceColor(String service) {
    switch (service.toLowerCase()) {
      case 'patreon':
        return Colors.orange;
      case 'fanbox':
      case 'pixiv_fanbox':
        return Colors.blue;
      case 'fantia':
        return Colors.purple;
      case 'onlyfans':
        return Colors.pink;
      case 'fansly':
        return Colors.teal;
      case 'candfans':
        return Colors.red;
      case 'gumroad':
        return Colors.green;
      case 'afdian':
        return Colors.teal;
      case 'boosty':
        return Colors.red;
      case 'subscribestar':
        return Colors.amber;
      case 'dlsite':
        return Colors.indigo;
      case 'discord':
        return Colors.blueGrey;
      default:
        return AppTheme.primaryColor;
    }
  }

  // ignore: unused_element
  String _buildPostsHeaderText(int visibleCount, int totalCount, bool hasMore) {
    final status = hasMore ? ' â€¢ Loading more...' : ' â€¢ All loaded';
    if (visibleCount == totalCount) {
      return '$visibleCount posts$status';
    }
    final hiddenCount = totalCount - visibleCount;
    return '$visibleCount posts â€¢ $hiddenCount hidden$status';
  }

  String _buildPostsSummaryText(
    int visibleCount,
    int totalCount,
    bool hasMore,
  ) {
    final status = hasMore ? ' - Loading more...' : ' - All loaded';
    if (visibleCount == totalCount) {
      return '$visibleCount posts$status';
    }
    final hiddenCount = totalCount - visibleCount;
    return '$visibleCount posts - $hiddenCount hidden$status';
  }

  // SIMPLIFIED Media Grid Item - No shadow, consistent ratio
  Widget _buildMediaGridItem(Map<String, dynamic> mediaItem) {
    final isVideo = mediaItem['type'] == 'video';
    return GestureDetector(
      onTap: () {
        final index = _cachedMediaItems.indexWhere(
          (item) => item['url'] == mediaItem['url'],
        );

        if (index != -1) {
          if (isVideo) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VideoPlayerScreen(
                  videoUrl: mediaItem['url'],
                  videoName: mediaItem['name'] ?? 'Video',
                  apiSource: _activeApiSource.name,
                ),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FullscreenMediaViewer(
                  mediaItems: _cachedMediaItems,
                  initialIndex: index,
                  apiSource: _activeApiSource,
                ),
              ),
            );
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 16,
              spreadRadius: -10,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _buildMediaContent(mediaItem),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.42),
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isVideo ? Icons.videocam_rounded : Icons.photo_rounded,
                      color: isVideo
                          ? Colors.redAccent
                          : AppTheme.primaryLightColor,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isVideo ? 'VIDEO' : 'IMAGE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.54),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                child: Icon(
                  isVideo ? Icons.play_arrow_rounded : Icons.fullscreen_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    final index = _cachedMediaItems.indexWhere(
                      (item) => item['url'] == mediaItem['url'],
                    );
                    if (index == -1) return;
                    if (isVideo) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VideoPlayerScreen(
                            videoUrl: mediaItem['url'],
                            videoName: mediaItem['name'] ?? 'Video',
                            apiSource: _activeApiSource.name,
                          ),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FullscreenMediaViewer(
                            mediaItems: _cachedMediaItems,
                            initialIndex: index,
                            apiSource: _activeApiSource,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build media content (image or video thumbnail)
  Widget _buildMediaContent(Map<String, dynamic> mediaItem) {
    final settings = context.watch<SettingsProvider>();
    final imageFit = settings.imageFitMode;
    if (mediaItem['type'] == 'video') {
      // For videos, show thumbnail if available, otherwise show placeholder
      if (mediaItem['thumbnail'] != null) {
        return AspectRatio(
          aspectRatio: 16.0 / 9.0,
          child: CachedNetworkImage(
            imageUrl: mediaItem['thumbnail'],
            fit: BoxFit.cover,
            errorWidget: (context, error, stackTrace) {
              return _buildVideoPlaceholder();
            },
            placeholder: (context, url) {
              return _buildLoadingPlaceholder();
            },
          ),
        );
      } else {
        return AspectRatio(
          aspectRatio: 16.0 / 9.0,
          child: _buildVideoPlaceholder(),
        );
      }
    } else {
      final rawUrl = mediaItem['url'] as String;
      final thumbnailUrl = mediaItem['thumbnail'] as String?;
      final displayUrl =
          settings.loadThumbnails &&
              thumbnailUrl != null &&
              thumbnailUrl.isNotEmpty
          ? thumbnailUrl
          : rawUrl;
      return FutureBuilder<Size>(
        future: _getImageSize(displayUrl),
        builder: (context, snapshot) {
          final aspectRatio = snapshot.hasData
              ? snapshot.data!.width / snapshot.data!.height
              : 1.0;
          final safeRatio = aspectRatio.isFinite && aspectRatio > 0
              ? aspectRatio
              : 1.0;

          return AspectRatio(
            aspectRatio: safeRatio,
            child: CachedNetworkImage(
              imageUrl: displayUrl,
              fit: imageFit,
              errorWidget: (context, error, stackTrace) {
                if (displayUrl != rawUrl) {
                  return CachedNetworkImage(
                    imageUrl: rawUrl,
                    fit: imageFit,
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[800],
                      child: const Center(
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.white54,
                          size: 32,
                        ),
                      ),
                    ),
                  );
                }
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
              placeholder: (context, url) {
                return _buildLoadingPlaceholder();
              },
            ),
          );
        },
      );
    }
  }

  // Build video placeholder
  Widget _buildVideoPlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_circle_outline, color: Colors.white54, size: 32),
            SizedBox(height: 4),
            Text(
              'Video',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // Build loading placeholder
  Widget _buildLoadingPlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: const AppSkeleton(shape: BoxShape.rectangle),
    );
  }

  bool _handleScrollNotification(ScrollNotification scrollInfo) {
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
        apiSource: _activeApiSource,
      );
      return true;
    }
    return false;
  }

  Widget _buildPostCard(Post post) {
    final hasMedia = post.attachments.isNotEmpty || post.file.isNotEmpty;
    final mediaCount = post.attachments.length + post.file.length;
    final serviceColor = _getServiceColor(post.service);
    final preview = _cleanHtmlContent(post.content);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.getCardColor(
              context,
            ).withValues(alpha: isDark ? 0.98 : 0.9),
            AppTheme.getSurfaceColor(
              context,
            ).withValues(alpha: isDark ? 0.94 : 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.getBorderColor(
            context,
          ).withValues(alpha: isDark ? 0.82 : 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
            blurRadius: 18,
            spreadRadius: -10,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToPostDetail(post),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: serviceColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: serviceColor.withValues(alpha: 0.34),
                        ),
                      ),
                      child: Text(
                        post.service.toUpperCase(),
                        style: TextStyle(
                          color: serviceColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatDate(post.published),
                      style: TextStyle(
                        color: AppTheme.getSecondaryTextColor(context),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  post.title.isNotEmpty ? post.title : 'Untitled Post',
                  style: TextStyle(
                    color: AppTheme.getPrimaryTextColor(context),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.25,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (preview.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    preview,
                    style: TextStyle(
                      color: AppTheme.getSecondaryTextColor(
                        context,
                      ).withValues(alpha: 0.95),
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    _buildPostMetaChip(
                      icon: Icons.photo_library_rounded,
                      label: hasMedia ? '$mediaCount media' : 'No media',
                    ),
                    const SizedBox(width: 8),
                    _buildPostMetaChip(
                      icon: Icons.subject_rounded,
                      label: preview.isEmpty ? 'No text' : 'Has text',
                    ),
                    const Spacer(),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.32),
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppTheme.primaryColor,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPostMetaChip({required IconData icon, required String label}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.getElevatedSurfaceColorContext(
          context,
        ).withValues(alpha: isDark ? 0.82 : 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.getBorderColor(
            context,
          ).withValues(alpha: isDark ? 0.72 : 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.getSecondaryTextColor(context)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.getSecondaryTextColor(context),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // HELPER METHODS
  void _toggleBookmark(CreatorsProvider creatorsProvider) async {
    try {
      // Check current state before toggling
      final isCurrentlyFavorited = creatorsProvider.favoriteCreators.contains(
        widget.creator.id,
      );

      // Create creator object for toggle
      final creator = widget.creator.copyWith(favorited: !isCurrentlyFavorited);

      await creatorsProvider.toggleFavorite(creator);
      if (!mounted) return;

      // Check new state after toggling
      final isNowFavorited = creatorsProvider.favoriteCreators.contains(
        widget.creator.id,
      );

      final message = isNowFavorited ? 'Added to Saved' : 'Removed from Saved';
      final backgroundColor = isNowFavorited ? Colors.green : Colors.orange;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isNowFavorited ? Icons.bookmark : Icons.bookmark_border,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(message),
            ],
          ),
          backgroundColor: backgroundColor,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Failed to save creator: $e'),
            ],
          ),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openCreatorInBrowser() async {
    final url = _buildCreatorUrl();
    if (url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  String _buildCreatorUrl() {
    final domain = _activeApiSource == ApiSource.coomer
        ? 'https://n2.coomer.st'
        : 'https://kemono.cr';

    return '$domain/${widget.creator.service}/user/${widget.creator.id}';
  }

  void _navigateToPostDetail(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PostDetailScreen(post: post, apiSource: _activeApiSource),
      ),
    );
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

  /// Clean HTML tags from content (NO LINKIFY)
  String _cleanHtmlContent(String content) {
    try {
      // Parse HTML properly
      final document = html_parser.parse(content);
      String cleanText = document.body?.text ?? content;

      // Clean up extra whitespace and newlines
      cleanText = cleanText.replaceAll(RegExp(r'\s+'), ' ').trim();

      // Remove common HTML entities
      cleanText = cleanText
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&amp;', '&')
          .replaceAll('&quot;', '"')
          .replaceAll('&#39;', "'");

      return cleanText;
    } catch (e) {
      // Fallback: simple regex cleaning
      String cleanText = content.replaceAll(RegExp(r'<[^>]*>'), '');
      cleanText = cleanText.replaceAll(RegExp(r'\s+'), ' ').trim();
      return cleanText;
    }
  }
}

// Helper class for persistent header
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget _child;
  final double _height;

  _TabBarDelegate(this._child, {double height = 70}) : _height = height;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: AppTheme.getSurfaceColor(context), child: _child);
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return false;
  }
}

class _LinkedAccount {
  final String id;
  final String name;
  final String service;
  final String? publicId;
  final int? relationId;

  const _LinkedAccount({
    required this.id,
    required this.name,
    required this.service,
    this.publicId,
    this.relationId,
  });

  factory _LinkedAccount.fromJson(Map<String, dynamic> json) {
    return _LinkedAccount(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      service: json['service']?.toString() ?? '',
      publicId: json['public_id']?.toString(),
      relationId: json['relation_id'] as int?,
    );
  }
}

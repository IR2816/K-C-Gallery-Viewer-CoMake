import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/api_source.dart';
import '../../domain/entities/creator.dart';
import '../../domain/entities/post.dart';
import '../../data/utils/domain_resolver.dart';
import '../controllers/latest_posts_controller.dart';
import '../providers/creator_quick_access_provider.dart';
import '../providers/post_search_provider.dart';
import '../providers/posts_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tag_filter_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_state_widgets.dart';
import '../widgets/domain_status_badge.dart';
import '../widgets/post_grid.dart';
import '../widgets/refresh_wrapper.dart';
import '../widgets/skeleton_loader.dart';
import 'creator_detail_screen.dart';
import 'download_manager_screen.dart';
import 'post_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen entry-point – provides the controller and hands off to the view.
// ─────────────────────────────────────────────────────────────────────────────

class LatestPostsScreen extends StatelessWidget {
  const LatestPostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => LatestPostsController(
        postsProvider: ctx.read<PostsProvider>(),
        settingsProvider: ctx.read<SettingsProvider>(),
        tagFilterProvider: ctx.read<TagFilterProvider>(),
        postSearchProvider: ctx.read<PostSearchProvider>(),
      ),
      child: const _LatestPostsView(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// View – owns UI-only state (scroll, recently-viewed expansion).
// ─────────────────────────────────────────────────────────────────────────────

class _LatestPostsView extends StatefulWidget {
  const _LatestPostsView();

  @override
  State<_LatestPostsView> createState() => _LatestPostsViewState();
}

class _LatestPostsViewState extends State<_LatestPostsView>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  bool _isRecentlyViewedExpanded = true;

  @override
  bool get wantKeepAlive {
    final ctrl = context.read<LatestPostsController>();
    return ctrl.filteredPosts.length < 100;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // React to domain-transition events surfaced by the controller.
    context.read<LatestPostsController>().addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    PaintingBinding.instance.imageCache.clear();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final ctrl = context.read<LatestPostsController>();
    if (ctrl.pendingDomainTransition != null) {
      final t = ctrl.pendingDomainTransition!;
      ctrl.consumeDomainTransition();
      _showDomainTransitionAnimation(t.from, t.to);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;

    // Auto-collapse / restore the recently-viewed carousel.
    if (pos.pixels < 60 && !_isRecentlyViewedExpanded) {
      setState(() => _isRecentlyViewedExpanded = true);
    } else if (pos.userScrollDirection == ScrollDirection.reverse &&
        pos.pixels > 80 &&
        _isRecentlyViewedExpanded) {
      setState(() => _isRecentlyViewedExpanded = false);
    }

    // Infinite scroll.
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      final ctrl = context.read<LatestPostsController>();
      if (ctrl.isInSearchMode) {
        ctrl.loadMoreSearch();
      } else {
        ctrl.loadMore();
      }
    }
  }

  void _navigateToPostDetail(Post post) {
    final apiSource = DomainResolver.apiSourceForService(post.service);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(post: post, apiSource: apiSource),
      ),
    );
  }

  void _navigateToCreatorDetail(Creator creator) {
    final apiSource = DomainResolver.apiSourceForService(creator.service);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CreatorDetailScreen(creator: creator, apiSource: apiSource),
      ),
    );
  }

  void _showDownloadManager() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DownloadManagerScreen()),
    );
  }

  void _showFilterBottomSheet() {
    final ctrl = context.read<LatestPostsController>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => ChangeNotifierProvider.value(
        value: ctrl,
        child: _FilterBottomSheet(
          onServiceSelected: (service) {
            final newSource = ApiSource.values.firstWhere(
              (a) => a.name == service,
              orElse: () => ApiSource.kemono,
            );
            context.read<SettingsProvider>().setDefaultApiSource(newSource);
            Navigator.pop(sheetCtx);
          },
        ),
      ),
    );
  }

  void _showDomainTransitionAnimation(String from, String to) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _DomainTransitionOverlay(
        fromDomain: from,
        toDomain: to,
        onAnimationComplete: entry.remove,
      ),
    );
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ctrl = context.watch<LatestPostsController>();

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: _FeedAppBar(
        isLoading: ctrl.isLoading,
        hasBlockedTags: ctrl.blockedTags.isNotEmpty,
        onRefresh: ctrl.loadInitial,
        onDownloadManager: _showDownloadManager,
        onFilter: _showFilterBottomSheet,
      ),
      body: Stack(
        children: [
          const _FeedBackground(),
          RefreshWrapper(
            onRefresh: ctrl.loadInitial,
            child: Column(
              children: [
                _FilterInfoBar(
                  selectedService: ctrl.selectedService,
                  blockedTagCount: ctrl.blockedTags.length,
                ),
                _RecentCreatorsCarousel(
                  isExpanded: _isRecentlyViewedExpanded,
                  onToggle: () => setState(
                    () =>
                        _isRecentlyViewedExpanded = !_isRecentlyViewedExpanded,
                  ),
                  onCreatorTap: _navigateToCreatorDetail,
                ),
                Expanded(
                  child: ctrl.isSwitchingSource
                      ? _SwitchingSourceIndicator(
                          apiSourceName: ctrl.currentApiSource.name,
                        )
                      : _FeedContent(
                          controller: ctrl,
                          scrollController: _scrollController,
                          onPostTap: _navigateToPostDetail,
                          onCreatorTap: (post) => _navigateToCreatorDetail(
                            creatorStubFromPost(post),
                          ),
                          onFilterTap: _showFilterBottomSheet,
                        ),
                ),
                if ((ctrl.filteredPosts.isNotEmpty || ctrl.isInSearchMode) &&
                    !ctrl.isSwitchingSource)
                  const _PaginationBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets
// ─────────────────────────────────────────────────────────────────────────────

// ── AppBar ──────────────────────────────────────────────────────────────────

class _FeedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isLoading;
  final bool hasBlockedTags;
  final VoidCallback onRefresh;
  final VoidCallback onDownloadManager;
  final VoidCallback onFilter;

  const _FeedAppBar({
    required this.isLoading,
    required this.hasBlockedTags,
    required this.onRefresh,
    required this.onDownloadManager,
    required this.onFilter,
  });

  @override
  Size get preferredSize => const Size.fromHeight(84);

  @override
  Widget build(BuildContext context) {
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
        builder: (_, postsProvider, __) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ShaderMask(
                  shaderCallback: (b) =>
                      AppTheme.primaryGradient.createShader(b),
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
                DomainStatusBadge(
                  apiSource: postsProvider.currentApiSource?.name ?? 'kemono',
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
        ),
      ),
      actions: [
        _ActionButton(
          icon: Icons.download_rounded,
          onTap: onDownloadManager,
          accentColor: AppTheme.secondaryAccent,
        ),
        _ActionButton(
          icon: Icons.refresh_rounded,
          onTap: onRefresh,
          accentColor: isLoading ? AppTheme.primaryColor : null,
          child: isLoading
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
        _ActionButton(
          icon: Icons.tune_rounded,
          onTap: onFilter,
          accentColor: hasBlockedTags ? AppTheme.primaryColor : null,
          margin: const EdgeInsets.only(right: 16),
        ),
      ],
    );
  }
}

// ── Filter / service-toggle bar ─────────────────────────────────────────────

class _FilterInfoBar extends StatelessWidget {
  final String selectedService;
  final int blockedTagCount;

  const _FilterInfoBar({
    required this.selectedService,
    required this.blockedTagCount,
  });

  @override
  Widget build(BuildContext context) {
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
                    children: ['kemono', 'coomer'].map((id) {
                      return Expanded(
                        child: _ServiceToggle(
                          id: id,
                          label: id == 'kemono' ? 'Kemono' : 'Coomer',
                          isSelected: id == selectedService,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              if (blockedTagCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
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
                        '$blockedTagCount',
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
          const SizedBox(height: 8),
          const _PostSearchBar(),
        ],
      ),
    );
  }
}

// ── Service toggle pill ─────────────────────────────────────────────────────

class _ServiceToggle extends StatelessWidget {
  final String id;
  final String label;
  final bool isSelected;

  const _ServiceToggle({
    required this.id,
    required this.label,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final serviceColor = AppTheme.getServiceColor(id);
    return GestureDetector(
      onTap: () async {
        if (isSelected) return;
        final newSource = ApiSource.values.firstWhere(
          (a) => a.name == id,
          orElse: () => ApiSource.kemono,
        );
        await context.read<SettingsProvider>().setDefaultApiSource(newSource);
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
}

// ── Search bar ──────────────────────────────────────────────────────────────

class _PostSearchBar extends StatefulWidget {
  const _PostSearchBar();

  @override
  State<_PostSearchBar> createState() => _PostSearchBarState();
}

class _PostSearchBarState extends State<_PostSearchBar> {
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<LatestPostsController>();
    final hasQuery = ctrl.searchQuery.isNotEmpty;
    final isSearching = ctrl.isSearching;
    final isLoadingMore = ctrl.isLoadingMoreSearch;
    final hasError = ctrl.searchError != null;
    final noResults =
        hasQuery && !isSearching && ctrl.searchResultCount == 0 && !hasError;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final accentColor = hasError
        ? Colors.red
        : noResults
        ? Colors.orange
        : AppTheme.primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(
              context,
            ).withValues(alpha: isDark ? 0.6 : 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasQuery
                  ? accentColor.withValues(alpha: 0.55)
                  : AppTheme.getBorderColor(context, opacity: 0.6),
              width: hasQuery ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              (isSearching || isLoadingMore || ctrl.isSearchDebouncing)
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryColor.withValues(alpha: 0.7),
                      ),
                    )
                  : Icon(
                      hasError
                          ? Icons.error_outline_rounded
                          : noResults
                          ? Icons.search_off_rounded
                          : Icons.search_rounded,
                      size: 18,
                      color: hasError
                          ? Colors.red.withValues(alpha: 0.8)
                          : noResults
                          ? Colors.orange.withValues(alpha: 0.8)
                          : AppTheme.getSecondaryTextColor(
                              context,
                              opacity: 0.6,
                            ),
                    ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _textCtrl,
                  focusNode: _focusNode,
                  onChanged: context
                      .read<LatestPostsController>()
                      .onSearchQueryChanged,
                  onSubmitted: (q) {
                    context.read<LatestPostsController>().submitSearch(q);
                    if (_scrollCtrl != null) {
                      _scrollCtrl!.animateTo(
                        0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                    _focusNode.unfocus();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search posts on server…',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    hintStyle: TextStyle(
                      color: AppTheme.getSecondaryTextColor(
                        context,
                        opacity: 0.5,
                      ),
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.getOnSurfaceColor(context),
                  ),
                  textInputAction: TextInputAction.search,
                ),
              ),
              if (hasQuery) ...[
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    ctrl.isSearchDebouncing || isSearching
                        ? '…'
                        : '${ctrl.searchResultCount}',
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
                    _textCtrl.clear();
                    _focusNode.unfocus();
                    context.read<LatestPostsController>().clearSearch();
                  },
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppTheme.getSecondaryTextColor(
                      context,
                      opacity: 0.6,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              ctrl.searchError ?? 'Search failed',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          )
        else if (noResults)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'No results found for "${ctrl.searchQuery}"',
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

  // Walk up the widget tree to find the nearest ScrollController from
  // _LatestPostsViewState, used to scroll-to-top on search submit.
  ScrollController? get _scrollCtrl {
    try {
      final state = context.findAncestorStateOfType<_LatestPostsViewState>();
      return state?._scrollController;
    } catch (_) {
      return null;
    }
  }
}

// ── Recently-viewed carousel ─────────────────────────────────────────────────

class _RecentCreatorsCarousel extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onToggle;
  final void Function(Creator) onCreatorTap;

  const _RecentCreatorsCarousel({
    required this.isExpanded,
    required this.onToggle,
    required this.onCreatorTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CreatorQuickAccessProvider>(
      builder: (_, quickAccess, __) {
        final recents = quickAccess.getRecentCreators(limit: 8);
        if (recents.isEmpty) return const SizedBox.shrink();

        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
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
                        turns: isExpanded ? 0 : 0.5,
                        duration: const Duration(milliseconds: 250),
                        child: Icon(
                          Icons.expand_less_rounded,
                          size: 18,
                          color: AppTheme.getSecondaryTextColor(
                            context,
                          ).withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                alignment: Alignment.topCenter,
                child: isExpanded
                    ? SizedBox(
                        height: 90,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: recents.length,
                          itemBuilder: (_, i) => _RecentCreatorItem(
                            creator: recents[i],
                            quickAccess: quickAccess,
                            isDark: isDark,
                            onTap: onCreatorTap,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
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
}

class _RecentCreatorItem extends StatelessWidget {
  final Creator creator;
  final CreatorQuickAccessProvider quickAccess;
  final bool isDark;
  final void Function(Creator) onTap;

  const _RecentCreatorItem({
    required this.creator,
    required this.quickAccess,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final isCoomer =
        creator.service == 'fansly' ||
        creator.service == 'onlyfans' ||
        creator.service == 'candfans';
    final domain = isCoomer
        ? 'https://${settings.cleanCoomerDomain}'
        : 'https://${settings.cleanKemonoDomain}';
    final avatarUrl =
        '$domain/data/avatars/${creator.service}/${creator.id}/avatar.jpg';
    final isFavorite = quickAccess.isFavorite(creator.id);

    return GestureDetector(
      onTap: () => onTap(creator),
      onLongPress: () async {
        HapticFeedback.mediumImpact();
        await quickAccess.toggleFavoriteCreator(creator);
        if (!context.mounted) return;
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
                          placeholder: (_, __) =>
                              _AvatarPlaceholder(name: creator.name),
                          errorWidget: (_, __, ___) =>
                              _AvatarPlaceholder(name: creator.name),
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
}

class _AvatarPlaceholder extends StatelessWidget {
  final String name;
  const _AvatarPlaceholder({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.darkElevatedSurfaceColor,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: AppTheme.primaryColor,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// ── Feed content (loading / error / empty / grid) ───────────────────────────

class _FeedContent extends StatelessWidget {
  final LatestPostsController controller;
  final ScrollController scrollController;
  final void Function(Post) onPostTap;
  final void Function(Post) onCreatorTap;
  final VoidCallback onFilterTap;

  const _FeedContent({
    required this.controller,
    required this.scrollController,
    required this.onPostTap,
    required this.onCreatorTap,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final columnCount = settings.latestPostsColumns.clamp(1, 3);
    final apiSource = settings.defaultApiSource;

    // ── Search mode ──────────────────────────────────────────────────────
    if (controller.isInSearchMode) {
      if (controller.isSearching && controller.searchResults.isEmpty) {
        return PostGrid(
          posts: const [],
          apiSource: apiSource,
          columnCount: columnCount,
          isLoading: true,
          onPostTap: (_) {},
          onCreatorTap: (_) {},
        );
      }
      if (!controller.isSearching && controller.searchResults.isEmpty) {
        return AppEmptyState(
          icon: Icons.search_off_rounded,
          title: 'No results for "${controller.searchQuery}"',
          message: 'Try a different keyword',
        );
      }
      return PostGrid(
        posts: controller.searchResults,
        apiSource: apiSource,
        columnCount: columnCount,
        controller: scrollController,
        isLoadingMore: controller.isLoadingMoreSearch,
        animationEpoch: controller.gridAnimationEpoch,
        onPostTap: onPostTap,
        onCreatorTap: onCreatorTap,
      );
    }

    // ── Latest-posts mode ────────────────────────────────────────────────
    if (controller.isLoading && controller.filteredPosts.isEmpty) {
      return PostGrid(
        posts: const [],
        apiSource: apiSource,
        columnCount: columnCount,
        isLoading: true,
        onPostTap: (_) {},
        onCreatorTap: (_) {},
      );
    }

    if (controller.error != null) {
      return _ApiErrorState(
        error: controller.error!,
        onRetry: controller.loadInitial,
      );
    }

    if (controller.filteredPosts.isEmpty) {
      return _EmptyState(
        isFiltered:
            controller.blockedTags.isNotEmpty ||
            controller.selectedService != 'kemono',
        onFilterTap: onFilterTap,
      );
    }

    return PostGrid(
      posts: controller.filteredPosts,
      apiSource: apiSource,
      columnCount: columnCount,
      controller: scrollController,
      isLoadingMore: controller.isLoadingMore,
      animationEpoch: controller.gridAnimationEpoch,
      onPostTap: onPostTap,
      onCreatorTap: onCreatorTap,
    );
  }
}

// ── Pagination bar ───────────────────────────────────────────────────────────

class _PaginationBar extends StatelessWidget {
  const _PaginationBar();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<LatestPostsController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bool showSpinner;
    final String label;

    if (ctrl.isInSearchMode) {
      final count = ctrl.searchResultCount;
      showSpinner = ctrl.isSearching || ctrl.isLoadingMoreSearch;
      label = (ctrl.isSearching && count == 0)
          ? 'Searching…'
          : ctrl.isLoadingMoreSearch
          ? 'Loading more results…'
          : ctrl.searchHasMore
          ? '$count results · scroll for more'
          : '$count results · all loaded';
    } else {
      final total = ctrl.filteredPosts.length;
      showSpinner = ctrl.isLoadingMore;
      label = ctrl.isLoadingMore
          ? 'Loading more…'
          : (ctrl.hasMore
                ? '$total loaded · scroll for more'
                : '$total posts · all loaded');
    }

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
          if (showSpinner) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: AppSkeleton(width: 14, height: 14, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            label,
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
}

// ── Decorative background ────────────────────────────────────────────────────

class _FeedBackground extends StatelessWidget {
  const _FeedBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.getBackgroundColor(context),
                  AppTheme.getBackgroundColor(context).withValues(alpha: 0.98),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -130,
          left: -70,
          child: _GlowOrb(color: AppTheme.primaryColor.withValues(alpha: 0.10)),
        ),
        Positioned(
          top: 20,
          right: -90,
          child: _GlowOrb(
            color: AppTheme.secondaryAccent.withValues(alpha: 0.08),
            size: 240,
          ),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowOrb({required this.color, this.size = 260});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}

// ── Switching-source indicator ───────────────────────────────────────────────

class _SwitchingSourceIndicator extends StatelessWidget {
  final String apiSourceName;
  const _SwitchingSourceIndicator({required this.apiSourceName});

  @override
  Widget build(BuildContext context) {
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
            'Connecting to ${apiSourceName.toUpperCase()}',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.getSecondaryTextColor(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isFiltered;
  final VoidCallback? onFilterTap;
  const _EmptyState({required this.isFiltered, this.onFilterTap});

  @override
  Widget build(BuildContext context) {
    if (isFiltered) {
      return AppEmptyState(
        icon: Icons.filter_list_off,
        title: 'All posts hidden by filters',
        message: 'Try adjusting your filters',
        actionLabel: 'Manage Filters',
        onAction: onFilterTap,
      );
    }
    return const AppEmptyState(
      icon: Icons.article_outlined,
      title: 'No posts yet',
      message: 'Pull down to refresh',
    );
  }
}

// ── API error state ───────────────────────────────────────────────────────────

class _ApiErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ApiErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isRetrying = error.contains('retry');
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
                  isRetrying
                      ? Icons.hourglass_top_rounded
                      : Icons.wifi_off_rounded,
                  size: 40,
                  color: isRetrying
                      ? AppTheme.warningColor
                      : AppTheme.errorColor,
                ),
              ),
              const SizedBox(height: 24),
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
              Text(
                error,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.getSecondaryTextColor(context),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (!isRetrying)
                GestureDetector(
                  onTap: onRetry,
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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
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
            ],
          ),
        ),
      ),
    );
  }
}

// ── AppBar action button ─────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? accentColor;
  final Widget? child;
  final EdgeInsetsGeometry margin;

  const _ActionButton({
    required this.icon,
    required this.onTap,
    this.accentColor,
    this.child,
    this.margin = const EdgeInsets.only(right: 8),
  });

  @override
  Widget build(BuildContext context) {
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
}

// ── Filter bottom sheet ───────────────────────────────────────────────────────

class _FilterBottomSheet extends StatelessWidget {
  final void Function(String service) onServiceSelected;

  const _FilterBottomSheet({required this.onServiceSelected});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<LatestPostsController>();
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
                    final isSelected = ctrl.selectedService == service;
                    return FilterChip(
                      label: Text(service.toUpperCase()),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) onServiceSelected(service);
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
          if (ctrl.blockedTags.isNotEmpty)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Blocked Tags',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${ctrl.blockedTags.length} tags are blocked',
                      style: TextStyle(
                        color: AppTheme.getOnSurfaceColor(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: ctrl.blockedTags.length,
                          itemBuilder: (_, i) {
                            final tag = ctrl.blockedTags[i];
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
                                        color: AppTheme.getOnSurfaceColor(
                                          context,
                                        ),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => context
                                        .read<TagFilterProvider>()
                                        .removeFromBlacklist(tag),
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
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Domain-transition animation overlay (unchanged behaviour, extracted class)
// ─────────────────────────────────────────────────────────────────────────────

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
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );
    _scale = Tween<double>(begin: 0.5, end: 1.2).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );
    _rotation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.2, 0.8, curve: Curves.easeInOut),
      ),
    );
    _ctrl.forward().then(
      (_) => Future.delayed(
        const Duration(milliseconds: 500),
        widget.onAnimationComplete,
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  IconData _iconFor(String domain) {
    switch (domain.toLowerCase()) {
      case 'kemono':
        return Icons.pets;
      case 'coomer':
        return Icons.face;
      default:
        return Icons.public;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: RotationTransition(
                turns: _rotation,
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
                      _DomainLabel(
                        domain: widget.fromDomain,
                        icon: _iconFor(widget.fromDomain),
                        opacity: Tween<double>(begin: 1, end: 0).animate(
                          CurvedAnimation(
                            parent: _ctrl,
                            curve: const Interval(
                              0.0,
                              0.4,
                              curve: Curves.easeOut,
                            ),
                          ),
                        ),
                      ),
                      _DomainLabel(
                        domain: widget.toDomain,
                        icon: _iconFor(widget.toDomain),
                        opacity: Tween<double>(begin: 0, end: 1).animate(
                          CurvedAnimation(
                            parent: _ctrl,
                            curve: const Interval(
                              0.6,
                              1.0,
                              curve: Curves.easeIn,
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: FadeTransition(
                          opacity: Tween<double>(begin: 0, end: 1).animate(
                            CurvedAnimation(
                              parent: _ctrl,
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
          ),
        ),
      ),
    );
  }
}

class _DomainLabel extends StatelessWidget {
  final String domain;
  final IconData icon;
  final Animation<double> opacity;

  const _DomainLabel({
    required this.domain,
    required this.icon,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: FadeTransition(
        opacity: opacity,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 32),
              const SizedBox(height: 4),
              Text(
                domain.toUpperCase(),
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
    );
  }
}

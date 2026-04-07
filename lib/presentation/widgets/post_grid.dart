import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../domain/entities/api_source.dart';
import '../../domain/entities/creator.dart';
import '../../domain/entities/post.dart';
import 'post_card.dart';
import 'skeleton_loader.dart';

/// A reusable masonry-grid that renders [Post] items as [PostCard] widgets.
///
/// Handles three visual states internally:
/// - **Loading** (`posts` is empty, `isLoading` is true): shows skeleton tiles.
/// - **Loaded** (`posts` is non-empty): shows animated [PostCard] tiles, and
///   appends skeleton tiles at the bottom while the next page is loading
///   (`isLoadingMore`).
/// - **Empty** (`posts` is empty, `isLoading` is false): renders nothing
///   (callers should show an [AppEmptyState] above or below).
///
/// All four previously duplicated [MasonryGridView.builder] blocks in
/// `latest_posts_screen.dart` collapse to a single call to this widget.
class PostGrid extends StatelessWidget {
  final List<Post> posts;
  final ApiSource apiSource;
  final int columnCount;
  final ScrollController? controller;

  /// When `true`, appends skeleton tiles at the bottom of the list.
  final bool isLoadingMore;

  /// When `true` and [posts] is empty, renders a full-screen skeleton grid.
  final bool isLoading;

  /// Bumping this triggers entry animations on all currently visible tiles.
  final int animationEpoch;

  final void Function(Post post) onPostTap;
  final void Function(Post post) onCreatorTap;

  const PostGrid({
    super.key,
    required this.posts,
    required this.apiSource,
    required this.columnCount,
    required this.onPostTap,
    required this.onCreatorTap,
    this.controller,
    this.isLoadingMore = false,
    this.isLoading = false,
    this.animationEpoch = 0,
  });

  bool get _isSingleColumn => columnCount == 1;

  EdgeInsets get _padding => _isSingleColumn
      ? const EdgeInsets.symmetric(vertical: 12)
      : const EdgeInsets.fromLTRB(12, 12, 12, 12);

  double get _mainAxisSpacing => _isSingleColumn ? 32 : 12;
  double get _crossAxisSpacing => _isSingleColumn ? 0 : 12;

  static const int _skeletonCount = 6;

  @override
  Widget build(BuildContext context) {
    // Full-screen skeleton when loading initial page.
    if (isLoading && posts.isEmpty) {
      return MasonryGridView.builder(
        padding: _padding,
        gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columnCount,
        ),
        mainAxisSpacing: _mainAxisSpacing,
        crossAxisSpacing: _crossAxisSpacing,
        itemCount: _skeletonCount,
        itemBuilder: (_, __) => const PostGridSkeleton(),
      );
    }

    final skeletonTiles = isLoadingMore ? columnCount : 0;
    final totalCount = posts.length + skeletonTiles;

    return MasonryGridView.builder(
      controller: controller,
      padding: _padding,
      gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columnCount,
      ),
      mainAxisSpacing: _mainAxisSpacing,
      crossAxisSpacing: _crossAxisSpacing,
      addAutomaticKeepAlives: false,
      itemCount: totalCount,
      itemBuilder: (context, index) {
        if (index >= posts.length) return const PostGridSkeleton();

        final post = posts[index];
        return RepaintBoundary(
          child: StaggeredFadeItem(
            index: index,
            epoch: animationEpoch,
            child: PostCard(
              post: post,
              isSingleColumn: _isSingleColumn,
              apiSource: apiSource,
              onTap: () => onPostTap(post),
              onCreatorTap: () => onCreatorTap(post),
            ),
          ),
        );
      },
    );
  }
}

/// Creates a minimal [Creator] stub from a [Post] for navigation purposes.
///
/// When the user taps the creator avatar or name inside a [PostCard], the app
/// navigates to [CreatorDetailScreen] which expects a [Creator] object.  Posts
/// only carry the creator's ID and service, so this helper assembles the
/// smallest valid [Creator] that satisfies the navigation contract.
Creator creatorStubFromPost(Post post) => Creator(
      id: post.user,
      name: post.user,
      service: post.service,
      indexed: 0,
      updated: 0,
    );

/// Staggered fade-in + slide-up animation applied to each grid tile.
///
/// Previously defined as `_StaggeredFadeItem` inside `latest_posts_screen.dart`;
/// now shared across the app via this widget.
class StaggeredFadeItem extends StatefulWidget {
  final int index;
  final int epoch;
  final Widget child;

  const StaggeredFadeItem({
    super.key,
    required this.index,
    required this.epoch,
    required this.child,
  });

  @override
  State<StaggeredFadeItem> createState() => _StaggeredFadeItemState();
}

class _StaggeredFadeItemState extends State<StaggeredFadeItem>
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
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _scheduleAnimation();
  }

  @override
  void didUpdateWidget(StaggeredFadeItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.epoch != widget.epoch) {
      _scheduleAnimation();
    }
  }

  void _scheduleAnimation() {
    if (!mounted) return;
    _ctrl.reset();
    final delay = Duration(
      milliseconds:
          widget.index.clamp(0, _maxStaggeredItems) * _delayPerItemMs,
    );
    Future.delayed(delay, () {
      if (mounted) _ctrl.forward();
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
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

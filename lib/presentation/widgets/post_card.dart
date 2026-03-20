import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Domain
import '../../domain/entities/post.dart';
import '../../domain/entities/api_source.dart';

// Providers
import '../providers/settings_provider.dart';

// Theme
import '../theme/app_theme.dart';

// Widgets
import '../../widgets/optimized_media_loader.dart';

/// PostCard — Social Media Style (Instagram-inspired)
///
/// Layout:
/// ┌──────────────────────────────┐
/// │ [Avatar] Creator  Service  ⋮ │ ← header row
/// │                              │
/// │      [Thumbnail image]       │ ← full-width media
/// │                              │
/// │ ♡  💬  ↗         🔖         │ ← social action row
/// │ Post title (caption)         │
/// │ #tag1 #tag2                  │
/// └──────────────────────────────┘
class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onTap;
  final VoidCallback? onSave;
  final ApiSource apiSource;
  final VoidCallback? onCreatorTap;
  final bool isSingleColumn;

  const PostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onSave,
    required this.apiSource,
    this.onCreatorTap,
    this.isSingleColumn = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkCardColor : AppTheme.lightCardColor;
    final borderColor = isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor;

    return Container(
      decoration: BoxDecoration(
        color: isSingleColumn
            ? (isDark ? AppTheme.darkCardColor : AppTheme.lightCardColor)
            : cardBg,
        borderRadius: isSingleColumn
            ? BorderRadius.zero
            : BorderRadius.circular(AppTheme.mdRadius),
        border: isSingleColumn
            ? Border(
                bottom: BorderSide(
                  color: borderColor.withValues(alpha: 0.6),
                  width: 0.5,
                ),
              )
            : Border.all(color: borderColor, width: 1),
        boxShadow: isSingleColumn ? null : [AppTheme.getCardShadow()],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: isSingleColumn
            ? BorderRadius.zero
            : BorderRadius.circular(AppTheme.mdRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Creator Header Row ──────────────────
            _buildCreatorHeader(context),

            // ── Thumbnail ──────────────────────────
            _buildThumbnail(context),

            // ── Social Actions ─────────────────────
            _buildSocialActions(context),

            // ── Caption ────────────────────────────
            _buildCaption(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatorHeader(BuildContext context) {
    final serviceColor = AppTheme.getServiceColor(post.service);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
      child: Row(
        children: [
          // Story-ring avatar
          GestureDetector(
            onTap: onCreatorTap,
            child: Hero(
              tag: 'creator-avatar-${post.user}-${post.service}',
              child: Container(
                width: 38,
                height: 38,
                padding: const EdgeInsets.all(2),
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
                    child: CachedNetworkImage(
                      imageUrl: _getCreatorAvatarUrl(),
                      fit: BoxFit.cover,
                      memCacheWidth: 80,
                      memCacheHeight: 80,
                      placeholder: (context, url) => _avatarFallback(),
                      errorWidget: (context, url, error) => _avatarFallback(),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Creator name + date
          Expanded(
            child: GestureDetector(
              onTap: onCreatorTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getCreatorDisplayName(),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.getPrimaryTextColor(context),
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: serviceColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          post.service.toUpperCase(),
                          style: TextStyle(
                            color: serviceColor,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _formatDate(post.published),
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppTheme.getSecondaryTextColor(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // More options
          SizedBox(
            width: 36,
            height: 36,
            child: IconButton(
              icon: Icon(
                Icons.more_horiz_rounded,
                color: AppTheme.getSecondaryTextColor(context),
                size: 20,
              ),
              onPressed: () => _showPostOptions(context),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback() {
    final name = _getCreatorDisplayName();
    return Container(
      color: AppTheme.darkElevatedSurfaceColor,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: AppTheme.primaryLightColor,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        final quality = settings.imageQuality;
        
        // Get proper domains from settings based on API source
        final kemonoDomain = settings.cleanKemonoDomain;
        final coomerDomain = settings.cleanCoomerDomain;
        
        final thumbnailUrl = post.getBestThumbnailUrl(
          apiSource,
          quality: quality,
          kemonoDomain: kemonoDomain,
          coomerDomain: coomerDomain,
        );

        // Single column: 1:1 square (Instagram style), Grid: 4:3
        final aspectRatio = isSingleColumn ? 1.0 : 1.25;

        return GestureDetector(
          onDoubleTap: onTap,
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Image
                thumbnailUrl != null
                    ? FallbackImage(
                        imagePath: thumbnailUrl,
                        fit: BoxFit.cover,
                        isThumbnail: true,
                        apiSource: apiSource.name,
                        quality: quality,
                        allowFallback: quality != 'low',
                        domain: apiSource == ApiSource.coomer ? coomerDomain : kemonoDomain,
                        errorWidget: _buildImagePlaceholder(context),
                      )
                    : _buildImagePlaceholder(context),

                // Subtle bottom gradient
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.18),
                        ],
                        stops: const [0, 0.6, 1],
                      ),
                    ),
                  ),
                ),

                // Media count badge (top-right)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _buildMediaBadges(),
                ),

                // Video play button overlay
                if (post.hasVideo && !post.hasImage)
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.8),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImagePlaceholder(BuildContext context) {
    return Container(
      color: AppTheme.getElevatedSurfaceColorContext(context),
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: AppTheme.getSecondaryTextColor(context).withValues(alpha: 0.4),
          size: 40,
        ),
      ),
    );
  }

  Widget _buildMediaBadges() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (post.hasVideo && !post.hasImage)
          _badge(Icons.videocam_rounded, '${post.videoCount}', Colors.redAccent),
        if (post.hasImage && post.hasVideo) ...[
          _badge(
            Icons.photo_library_rounded,
            '${post.imageCount}',
            AppTheme.primaryColor,
          ),
          const SizedBox(width: 4),
          _badge(Icons.videocam_rounded, '${post.videoCount}', Colors.redAccent),
        ],
        if (post.hasImage && !post.hasVideo && post.imageCount > 1)
          _badge(
            Icons.photo_library_rounded,
            '${post.imageCount}',
            AppTheme.primaryColor,
          ),
      ],
    );
  }

  Widget _badge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// Social media style actions bar (like, comment, share, bookmark)
  Widget _buildSocialActions(BuildContext context) {
    final isSaved = post.saved;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isSingleColumn ? 14 : 10,
        10,
        isSingleColumn ? 14 : 10,
        4,
      ),
      child: Row(
        children: [
          // Like / view button
          _actionBtn(
            context: context,
            icon: Icons.favorite_border_rounded,
            onTap: onTap,
          ),
          const SizedBox(width: 16),

          // Comment / open post button
          _actionBtn(
            context: context,
            icon: Icons.chat_bubble_outline_rounded,
            onTap: onTap,
          ),
          const SizedBox(width: 16),

          // Share/external button
          _actionBtn(
            context: context,
            icon: Icons.send_rounded,
            onTap: onTap,
          ),

          const Spacer(),

          // Bookmark
          _actionBtn(
            context: context,
            icon: Icons.bookmark_border_rounded,
            activeIcon: Icons.bookmark_rounded,
            isActive: isSaved,
            activeColor: AppTheme.primaryColor,
            onTap: () {
              HapticFeedback.lightImpact();
              onSave?.call();
            },
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required BuildContext context,
    required IconData icon,
    IconData? activeIcon,
    bool isActive = false,
    Color? activeColor,
    VoidCallback? onTap,
  }) {
    final color = isActive
        ? (activeColor ?? AppTheme.primaryColor)
        : AppTheme.getSecondaryTextColor(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: Icon(
            isActive ? (activeIcon ?? icon) : icon,
            key: ValueKey(isActive),
            color: color,
            size: 24,
          ),
        ),
      ),
    );
  }

  /// Caption area with title and tags
  Widget _buildCaption(BuildContext context) {
    final hasTags = post.tags.isNotEmpty;
    final hasTitle = post.title.isNotEmpty;
    if (!hasTitle && !hasTags) return const SizedBox(height: 8);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isSingleColumn ? 14 : 10,
        2,
        isSingleColumn ? 14 : 10,
        isSingleColumn ? 18 : 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasTitle)
            RichText(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${_getCreatorDisplayName()} ',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.getPrimaryTextColor(context),
                    ),
                  ),
                  TextSpan(
                    text: post.title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.getPrimaryTextColor(context),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          if (hasTags) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: post.tags.take(3).map((tag) {
                return Text(
                  '#$tag',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  void _showPostOptions(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PostOptionsSheet(
        post: post,
        onSave: onSave,
        onView: onTap,
        onCreatorTap: onCreatorTap,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }

  String _getCreatorAvatarUrl() {
    final domain =
        (post.service == 'fansly' ||
                post.service == 'onlyfans' ||
                post.service == 'candfans')
            ? 'https://coomer.st'
            : 'https://kemono.cr';
    return '$domain/data/avatars/${post.service}/${post.user}/avatar.jpg';
  }

  String _getCreatorDisplayName() {
    if (post.user.isNotEmpty) return post.user;
    if (post.service.isNotEmpty) return '${post.service} Creator';
    return 'Unknown Creator';
  }
}

/// Bottom sheet for post quick options
class _PostOptionsSheet extends StatelessWidget {
  final Post post;
  final VoidCallback? onSave;
  final VoidCallback? onView;
  final VoidCallback? onCreatorTap;

  const _PostOptionsSheet({
    required this.post,
    this.onSave,
    this.onView,
    this.onCreatorTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkCardColor : AppTheme.lightCardColor;
    final serviceColor = AppTheme.getServiceColor(post.service);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.getSecondaryTextColor(context).withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(99),
            ),
          ),

          // Post title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Text(
              post.title.isNotEmpty ? post.title : 'Untitled post',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.getPrimaryTextColor(context),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          Divider(
            color: (isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor)
                .withValues(alpha: 0.6),
            height: 16,
          ),

          // Options
          _option(
            context: context,
            icon: Icons.open_in_new_rounded,
            label: 'View Post',
            onTap: () {
              Navigator.pop(context);
              onView?.call();
            },
          ),
          _option(
            context: context,
            icon: Icons.person_outline_rounded,
            label: 'View Creator',
            color: serviceColor,
            onTap: () {
              Navigator.pop(context);
              onCreatorTap?.call();
            },
          ),
          if (onSave != null)
            _option(
              context: context,
              icon: post.saved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              label: post.saved ? 'Unsave Post' : 'Save Post',
              color: AppTheme.primaryColor,
              onTap: () {
                Navigator.pop(context);
                onSave?.call();
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _option({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final itemColor = color ?? AppTheme.getPrimaryTextColor(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: itemColor, size: 22),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: itemColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

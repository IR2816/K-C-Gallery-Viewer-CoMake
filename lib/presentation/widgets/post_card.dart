import 'package:flutter/material.dart';
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

/// PostCard — Social Media Style
///
/// Layout:
/// ┌──────────────────────────────┐
/// │ [Avatar] Creator  ●  Service │ ← header row
/// │                              │
/// │      [Thumbnail image]       │ ← full-width media
/// │                              │
/// │ 🔖 Save  📷 2 IMG  📅 2d ago │ ← action row
/// │ Post title (caption)         │
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
        color: isSingleColumn ? Colors.transparent : cardBg,
        borderRadius: isSingleColumn ? BorderRadius.zero : BorderRadius.circular(AppTheme.mdRadius),
        border: isSingleColumn ? null : Border.all(color: borderColor, width: 1),
        boxShadow: isSingleColumn ? null : [AppTheme.getCardShadow()],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: isSingleColumn ? BorderRadius.zero : BorderRadius.circular(AppTheme.mdRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Creator Header Row ──────────────────
            _buildCreatorHeader(context),

            // ── Thumbnail ──────────────────────────
            _buildThumbnail(context),

            // ── Actions + Caption ──────────────────
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatorHeader(BuildContext context) {
    final serviceColor = AppTheme.getServiceColor(post.service);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // Avatar circle
          GestureDetector(
            onTap: onCreatorTap,
            child: Hero(
              tag: 'creator-${post.user}',
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.getBorderColor(context).withValues(alpha: 0.5),
                    width: 1.5,
                  ),

                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.accentColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(2),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: _getCreatorAvatarUrl(),
                    fit: BoxFit.cover,
                    placeholder: (_, url) => Container(
                      color: AppTheme.darkElevatedSurfaceColor,
                      child: const Icon(Icons.person, size: 16, color: Colors.white70),
                    ),
                    errorWidget: (_, url, error) => Container(
                      color: AppTheme.darkElevatedSurfaceColor,
                      child: const Icon(Icons.person, size: 16, color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Creator name
          Expanded(
            child: GestureDetector(
              onTap: onCreatorTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getCreatorDisplayName(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.getPrimaryTextColor(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _formatDate(post.published),
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.getSecondaryTextColor(context),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Service badge pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: serviceColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.pillRadius),
              border: Border.all(color: serviceColor.withValues(alpha: 0.3), width: 1),
            ),
            child: Text(
              post.service.toUpperCase(),
              style: TextStyle(
                color: serviceColor,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        final quality = settings.imageQuality;
        final thumbnailUrl = post.getBestThumbnailUrl(apiSource, quality: quality);
        
        // Use 1.25 (4:5 vertical) for single column social feed, 1.5 (3:2) for grid
        final aspectRatio = isSingleColumn ? 1.0 : 1.5; 
        
        return AspectRatio(
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
                      allowFallback: quality != 'low', // Disable fallback in Low Quality / Data Saver
                      errorWidget: _buildImagePlaceholder(context),
                    )
                  : _buildImagePlaceholder(context),

              // Gradient overlay bottom
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.35),
                      ],
                      stops: const [0, 0.55, 1],
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

              // Video play button
              if (post.hasVideo && !post.hasImage)
                Center(
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white30, width: 1.5),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImagePlaceholder(BuildContext context) {
    return Container(
      color: AppTheme.getElevatedSurfaceColorContext(context),
      child: Center(
        child: Icon(Icons.image_not_supported_outlined, color: AppTheme.getSecondaryTextColor(context), size: 40),
      ),
    );
  }

  Widget _buildMediaBadges() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (post.hasVideo && !post.hasImage)
          _badge(Icons.videocam_rounded, '${post.videoCount}', Colors.red),
        if (post.hasImage && post.hasVideo) ...[
          _badge(Icons.photo_library_rounded, '${post.imageCount}', AppTheme.primaryColor),
          const SizedBox(width: 4),
          _badge(Icons.videocam_rounded, '${post.videoCount}', Colors.red),
        ],
        if (post.hasImage && !post.hasVideo)
          _badge(Icons.photo_library_rounded, '${post.imageCount}', AppTheme.primaryColor),
      ],
    );
  }

  Widget _badge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 3),
          Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(isSingleColumn ? 16 : 14, 12, isSingleColumn ? 16 : 14, isSingleColumn ? 20 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action row
          Row(
            children: [
              // Save button
              if (onSave != null)
                GestureDetector(
                  onTap: onSave,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      post.saved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                      key: ValueKey(post.saved),
                      color: post.saved ? AppTheme.primaryColor : AppTheme.getSecondaryTextColor(context),
                      size: 22,
                    ),
                  ),
                ),
              const Spacer(),
              // Tags preview
              if (post.tags.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: post.tags.take(2).map((tag) => Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(AppTheme.pillRadius),
                      ),
                      child: Text(
                        '#$tag',
                        style: const TextStyle(
                          color: AppTheme.primaryLightColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )).toList(),
                ),
            ],
          ),

          // Title caption
          if (post.title.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              post.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.getPrimaryTextColor(context),
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
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
    final domain = (post.service == 'fansly' || post.service == 'onlyfans' || post.service == 'candfans')
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

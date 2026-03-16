import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/creator.dart';
import '../providers/creators_provider.dart';
import '../theme/app_theme.dart';

/// CreatorCard — Social Media Profile Card Style
///
/// Layout:
/// ┌────────────────────────────────────┐
/// │  [Story-ring Avatar]  Name          │
/// │                       @service ❤️  │
/// │  ID • Updated date                  │
/// └────────────────────────────────────┘
class CreatorCard extends StatefulWidget {
  final Creator creator;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final bool showServiceBadge;
  final bool showFansCount;
  final bool experimentalBadge;

  const CreatorCard({
    super.key,
    required this.creator,
    this.onTap,
    this.onFavorite,
    this.showServiceBadge = false,
    this.showFansCount = false,
    this.experimentalBadge = false,
  });

  @override
  State<CreatorCard> createState() => _CreatorCardState();
}

class _CreatorCardState extends State<CreatorCard> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 180),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _avatarUrl() {
    final domain = (widget.creator.service == 'fansly' ||
            widget.creator.service == 'onlyfans' ||
            widget.creator.service == 'candfans')
        ? 'https://coomer.st'
        : 'https://kemono.cr';
    return '$domain/data/avatars/${widget.creator.service}/${widget.creator.id}/avatar.jpg';
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    return 'Today';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final serviceColor = AppTheme.getServiceColor(widget.creator.service);

    return Consumer<CreatorsProvider>(
      builder: (context, provider, _) {
        final isFavorite = provider.favoriteCreators.contains(widget.creator.id);

        return GestureDetector(
          onTapDown: (_) => _animController.forward(),
          onTapUp: (_) => _animController.reverse(),
          onTapCancel: () => _animController.reverse(),
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _scaleAnim,
            builder: (context, child) => Transform.scale(
              scale: _scaleAnim.value,
              child: child,
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCardColor : AppTheme.lightCardColor,
                borderRadius: BorderRadius.circular(AppTheme.mdRadius),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
                  width: 1,
                ),
                boxShadow: [AppTheme.getCardShadow()],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    // Story-ring avatar
                    _buildAvatar(serviceColor),

                    const SizedBox(width: 16),

                    // Name + service info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.creator.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppTheme.darkPrimaryTextColor
                                        : AppTheme.lightPrimaryTextColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.experimentalBadge)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.warningColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(AppTheme.pillRadius),
                                  ),
                                  child: const Text(
                                    'EXP',
                                    style: TextStyle(
                                      color: AppTheme.warningColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Service badge + updated
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: serviceColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(AppTheme.pillRadius),
                                ),
                                child: Text(
                                  widget.creator.service.toUpperCase(),
                                  style: TextStyle(
                                    color: serviceColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.update_rounded,
                                size: 11,
                                color: isDark
                                    ? AppTheme.darkSecondaryTextColor
                                    : AppTheme.lightSecondaryTextColor,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _formatDate(
                                  DateTime.fromMillisecondsSinceEpoch(
                                    widget.creator.updated * 1000,
                                  ),
                                ),
                                style: TextStyle(
                                  color: isDark
                                      ? AppTheme.darkSecondaryTextColor
                                      : AppTheme.lightSecondaryTextColor,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 4),

                          // ID row
                          Text(
                            'ID: ${widget.creator.id}',
                            style: TextStyle(
                              color: isDark
                                  ? AppTheme.darkDisabledTextColor
                                  : AppTheme.lightDisabledTextColor,
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Favorite button
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: widget.onFavorite,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isFavorite
                              ? AppTheme.accentColor.withValues(alpha: 0.12)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFavorite ? AppTheme.accentColor : AppTheme.darkSecondaryTextColor,
                          size: 22,
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
    );
  }

  Widget _buildAvatar(Color serviceColor) {
    return Container(
      width: 54,
      height: 54,
      padding: const EdgeInsets.all(2.5),
      decoration: const BoxDecoration(
        gradient: AppTheme.storyRingGradient,
        shape: BoxShape.circle,
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.darkElevatedSurfaceColor,
        ),
        padding: const EdgeInsets.all(2),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: _avatarUrl(),
            fit: BoxFit.cover,
            placeholder: (_, url) => Container(
              color: AppTheme.darkElevatedSurfaceColor,
              child: Center(
                child: Text(
                  widget.creator.name.isNotEmpty
                      ? widget.creator.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            errorWidget: (_, url, error) => Container(
              color: AppTheme.darkElevatedSurfaceColor,
              child: Center(
                child: Text(
                  widget.creator.name.isNotEmpty
                      ? widget.creator.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
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

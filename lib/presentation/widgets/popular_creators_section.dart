import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../providers/popular_creators_provider.dart';
import '../providers/settings_provider.dart';
import '../../domain/entities/api_source.dart';
import '../../domain/entities/creator.dart';
import '../theme/app_theme.dart';
import '../screens/creator_detail_screen.dart';
import 'skeleton_loader.dart';

/// Popular Creators Section with Service Selection
class PopularCreatorsSection extends StatefulWidget {
  const PopularCreatorsSection({super.key});

  @override
  State<PopularCreatorsSection> createState() => _PopularCreatorsSectionState();
}

class _PopularCreatorsSectionState extends State<PopularCreatorsSection> {
  @override
  void initState() {
    super.initState();
    // Load popular creators on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PopularCreatorsProvider>().loadPopularCreators();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PopularCreatorsProvider>(
      builder: (context, popularProvider, _) {
        return Consumer<SettingsProvider>(
          builder: (context, settingsProvider, _) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with Service Selection
                  _buildHeader(popularProvider, settingsProvider),
                  const SizedBox(height: 12),

                  // Popular Creators Content
                  _buildContent(popularProvider),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Get display name with fallback for better UX
  String _getDisplayName(Creator creator) {
    // With the new API, we should get proper names now
    // But still have fallback for safety
    if (creator.name.isNotEmpty &&
        creator.name != 'Unknown' &&
        creator.name.length > 1) {
      // If name is too long, truncate it
      if (creator.name.length > 25) {
        return '${creator.name.substring(0, 22)}...';
      }

      return creator.name;
    }

    // Ultimate fallback
    String servicePrefix = creator.service.isNotEmpty
        ? creator.service.substring(0, 3).toUpperCase()
        : 'CRE';

    String idPart = creator.id.length >= 8
        ? creator.id.substring(0, 8).toUpperCase()
        : creator.id.toUpperCase();

    return '$servicePrefix-$idPart';
  }

  Widget _buildHeader(
    PopularCreatorsProvider popularProvider,
    SettingsProvider settingsProvider,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          // Icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Popular Creators',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: isDark
                        ? AppTheme.darkPrimaryTextColor
                        : AppTheme.lightPrimaryTextColor,
                  ),
                ),
                if (popularProvider.totalItems > 0)
                  Text(
                    '${popularProvider.totalItems} creators',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppTheme.darkSecondaryTextColor
                          : AppTheme.lightSecondaryTextColor,
                    ),
                  ),
              ],
            ),
          ),
          // Service toggle
          _buildServiceToggle(popularProvider),
          const SizedBox(width: 8),
          // Refresh
          GestureDetector(
            onTap: popularProvider.refresh,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkCardColor
                    : AppTheme.lightElevatedSurfaceColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? AppTheme.darkBorderColor
                      : AppTheme.lightBorderColor,
                ),
              ),
              child: Icon(
                Icons.refresh_rounded,
                size: 16,
                color: isDark
                    ? AppTheme.darkSecondaryTextColor
                    : AppTheme.lightSecondaryTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceToggle(PopularCreatorsProvider popularProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkCardColor
            : AppTheme.lightElevatedSurfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.pillRadius),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
        ),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildServiceButton(
            title: 'Kemono',
            isSelected: popularProvider.currentService == ApiSource.kemono,
            onTap: () => popularProvider.switchService(ApiSource.kemono),
          ),
          _buildServiceButton(
            title: 'Coomer',
            isSelected: popularProvider.currentService == ApiSource.coomer,
            onTap: () => popularProvider.switchService(ApiSource.coomer),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceButton({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.primaryGradient : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.pillRadius),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : AppTheme.getSecondaryTextColor(context),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(PopularCreatorsProvider popularProvider) {
    if (popularProvider.isLoading) {
      return _buildLoadingState();
    }

    if (popularProvider.error != null) {
      return _buildErrorState(popularProvider);
    }

    if (popularProvider.popularCreators.isEmpty) {
      return _buildEmptyState();
    }

    return _buildPopularCreatorsGrid(popularProvider);
  }

  Widget _buildLoadingState() {
    final bottomPadding = AppTheme.getBottomContentPadding(context, extra: 0);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.45,
      ),
      child: ListView.builder(
        padding: EdgeInsets.only(left: 4, right: 4, bottom: bottomPadding),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        itemBuilder: (context, index) => const PopularCreatorSkeleton(),
      ),
    );
  }

  Widget _buildErrorState(PopularCreatorsProvider popularProvider) {
    final bottomPadding = AppTheme.getBottomContentPadding(context, extra: 0);
    return Container(
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.of(context).size.height * 0.45, // Match list height
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red.withValues(alpha: 0.7),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'Failed to load popular creators',
              style: AppTheme.bodyStyle.copyWith(
                color: Colors.red.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: popularProvider.refresh,
              child: Text(
                'Tap to retry',
                style: AppTheme.bodyStyle.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final bottomPadding = AppTheme.getBottomContentPadding(context, extra: 0);
    return Container(
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.of(context).size.height * 0.45, // Match list height
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              color: AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.5),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'No popular creators found',
              style: AppTheme.bodyStyle.copyWith(
                color: AppTheme.getOnSurfaceColor(
                  context,
                ).withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularCreatorsGrid(PopularCreatorsProvider popularProvider) {
    final bottomPadding = AppTheme.getBottomContentPadding(context, extra: 0);
    return Container(
      // Use dynamic height to avoid bottom navigation overlap
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.of(context).size.height *
            0.45, // Increased to 45% for list
      ),
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (scrollInfo is ScrollEndNotification) {
            final metrics = scrollInfo.metrics;
            if (metrics.pixels >= metrics.maxScrollExtent - 200) {
              // Load more when 200px from bottom
              _loadMoreCreators(popularProvider);
            }
          }
          return false;
        },
        child: ListView.builder(
          padding: EdgeInsets.only(left: 4, right: 4, bottom: bottomPadding),
          itemCount:
              popularProvider.popularCreators.length +
              (popularProvider.isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            // Show loading indicator at the bottom
            if (index == popularProvider.popularCreators.length &&
                popularProvider.isLoadingMore) {
              return _buildLoadingMoreIndicator();
            }

            final creator = popularProvider.popularCreators[index];
            return _buildCreatorListItem(creator, popularProvider, index);
          },
        ),
      ),
    );
  }

  /// Load more creators when scrolling near bottom
  void _loadMoreCreators(PopularCreatorsProvider popularProvider) {
    if (popularProvider.hasMorePages && !popularProvider.isLoadingMore) {
      popularProvider.loadMorePopularCreators();
    }
  }

  Widget _buildLoadingMoreIndicator() {
    return const Padding(
      padding: EdgeInsets.only(top: 8, bottom: 24),
      child: PopularCreatorSkeleton(),
    );
  }

  Widget _buildCreatorListItem(
    Creator creator,
    PopularCreatorsProvider popularProvider,
    int index,
  ) {
    final bannerUrl = _buildCreatorBannerUrl(
      creator,
      popularProvider.currentService,
    );
    final iconUrl = _buildCreatorIconUrl(
      creator,
      popularProvider.currentService,
    );
    final serviceColor = _getServiceColor(creator.service);
    final idPreview = creator.id.length > 8
        ? creator.id.substring(0, 8).toUpperCase()
        : creator.id.toUpperCase();
    final secondaryText = creator.fans != null
        ? '${_formatFansCount(creator.fans!)} favorites'
        : '${popularProvider.currentService == ApiSource.kemono ? 'Kemono' : 'Coomer'} - ID: $idPreview';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.getBorderColor(context, opacity: 0.72),
          width: 1,
        ),
        boxShadow: [AppTheme.getCardShadow()],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CreatorDetailScreen(
                  creator: creator,
                  apiSource: popularProvider.currentService,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 118,
              child: Stack(
                children: [
                  // Banner
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: bannerUrl,
                      httpHeaders: _getCoomerHeaders(bannerUrl),
                      fit: BoxFit.cover,
                      placeholder: (_, url) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              serviceColor.withValues(alpha: 0.25),
                              AppTheme.getElevatedSurfaceColor(context),
                            ],
                          ),
                        ),
                      ),
                      errorWidget: (_, url, error) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              serviceColor.withValues(alpha: 0.25),
                              AppTheme.getBackgroundColor(context),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Gradient overlay
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.15),
                            Colors.black.withValues(alpha: 0.75),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Rank badge (top-right)
                  Positioned(
                    top: 10,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(
                          AppTheme.pillRadius,
                        ),
                      ),
                      child: Text(
                        '#${index + 1}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  // Service badge (top-left)
                  Positioned(
                    top: 10,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: serviceColor.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(
                          AppTheme.pillRadius,
                        ),
                      ),
                      child: Text(
                        creator.service.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  // Bottom row: story-ring avatar + name
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Row(
                      children: [
                        // Story-ring avatar
                        Container(
                          width: 46,
                          height: 46,
                          padding: const EdgeInsets.all(2.5),
                          decoration: const BoxDecoration(
                            gradient: AppTheme.storyRingGradient,
                            shape: BoxShape.circle,
                          ),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: AppTheme.darkElevatedSurfaceColor,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(1.5),
                            child: ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: iconUrl,
                                httpHeaders: _getCoomerHeaders(iconUrl),
                                fit: BoxFit.cover,
                                errorWidget: (_, url, error) => Center(
                                  child: Text(
                                    creator.name.isNotEmpty
                                        ? creator.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _getDisplayName(creator),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                secondaryText,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white60,
                          size: 20,
                        ),
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

  /// Format fans count for better display
  String _formatFansCount(int fans) {
    if (fans >= 1000000) {
      return '${(fans / 1000000).toStringAsFixed(1)}M';
    } else if (fans >= 1000) {
      return '${(fans / 1000).toStringAsFixed(1)}K';
    }
    return fans.toString();
  }

  String _buildCreatorBannerUrl(Creator creator, ApiSource source) {
    final base = source == ApiSource.coomer
        ? 'https://img.coomer.st'
        : 'https://img.kemono.cr';
    return '$base/banners/${creator.service}/${creator.id}';
  }

  String _buildCreatorIconUrl(Creator creator, ApiSource source) {
    if (creator.avatar.isNotEmpty) return creator.avatar;
    final base = source == ApiSource.coomer
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
}

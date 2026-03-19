import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../domain/entities/creator.dart';
import '../providers/creator_quick_access_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import 'creator_detail_screen.dart';

/// Screen showing locally-favorited creators and recently-viewed creators.
///
/// Features:
/// - Search bar to filter favorites by name
/// - Suggestions from recent creators when search is active
/// - Grid of favorited creators
/// - Long-press to remove from favorites
/// - Tap to open creator detail screen
class FavoriteCreatorsScreen extends StatefulWidget {
  const FavoriteCreatorsScreen({super.key});

  @override
  State<FavoriteCreatorsScreen> createState() => _FavoriteCreatorsScreenState();
}

class _FavoriteCreatorsScreenState extends State<FavoriteCreatorsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _query = '';
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchFocus.removeListener(_onFocusChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _query = _searchController.text;
    });
  }

  void _onFocusChanged() {
    setState(() {
      _showSuggestions = _searchFocus.hasFocus;
    });
  }

  void _openCreator(Creator creator) {
    final settings = context.read<SettingsProvider>();
    final quickAccess = context.read<CreatorQuickAccessProvider>();
    quickAccess.addRecentCreator(creator);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreatorDetailScreen(
          creator: creator,
          apiSource: settings.defaultApiSource,
        ),
      ),
    );
  }

  Future<void> _confirmRemoveFavorite(
    BuildContext context,
    Creator creator,
    CreatorQuickAccessProvider provider,
  ) async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Favorite'),
        content: Text(
          'Remove "${creator.name}" from your favorites?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.removeFavoriteCreator(creator.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: _buildAppBar(isDark),
      body: Consumer<CreatorQuickAccessProvider>(
        builder: (context, provider, _) {
          final favorites = provider.searchFavorites(_query);
          final recent = provider.getRecentCreators(limit: 8);

          return Column(
            children: [
              _buildSearchBar(isDark),
              if (_showSuggestions && _query.isNotEmpty && recent.isNotEmpty)
                _buildSuggestions(recent, isDark),
              Expanded(
                child: favorites.isEmpty
                    ? _buildEmptyState(isDark)
                    : _buildFavoritesGrid(favorites, provider, isDark),
              ),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      toolbarHeight: 64,
      backgroundColor: AppTheme.getBackgroundColor(context),
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Row(
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFFFD740), size: 24),
          const SizedBox(width: 8),
          Text(
            'Favorite Creators',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.getOnSurfaceColor(context),
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.darkElevatedSurfaceColor
              : AppTheme.lightElevatedSurfaceColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
          ),
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          style: TextStyle(
            color: AppTheme.getOnSurfaceColor(context),
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: 'Search favorites…',
            hintStyle: TextStyle(
              color: AppTheme.getSecondaryTextColor(context),
              fontSize: 14,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: AppTheme.getSecondaryTextColor(context),
              size: 20,
            ),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear_rounded,
                      color: AppTheme.getSecondaryTextColor(context),
                      size: 18,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _searchFocus.unfocus();
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions(List<Creator> recent, bool isDark) {
    // Filter suggestions that match the query and aren't already in favorites
    final provider = context.read<CreatorQuickAccessProvider>();
    final suggestions = recent
        .where(
          (c) =>
              c.name.toLowerCase().contains(_query.toLowerCase()) &&
              !provider.isFavorite(c.id),
        )
        .toList();
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardColor : AppTheme.lightCardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Text(
              'Recently Viewed',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.getSecondaryTextColor(context),
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...suggestions.map(
            (creator) => ListTile(
              dense: true,
              leading: _buildSmallAvatar(creator),
              title: Text(
                creator.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getOnSurfaceColor(context),
                ),
              ),
              subtitle: Text(
                creator.service.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.getServiceColor(creator.service),
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: () {
                _searchFocus.unfocus();
                _openCreator(creator);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star_border_rounded,
              size: 64,
              color: AppTheme.getSecondaryTextColor(context),
            ),
            const SizedBox(height: 16),
            Text(
              _query.isEmpty ? 'No favorites yet' : 'No results for "$_query"',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.getOnSurfaceColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _query.isEmpty
                  ? 'Long-press a creator or tap ★ on the creator page to add them here.'
                  : 'Try a different name.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.getSecondaryTextColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesGrid(
    List<Creator> favorites,
    CreatorQuickAccessProvider provider,
    bool isDark,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final creator = favorites[index];
        return _buildCreatorTile(creator, provider, isDark);
      },
    );
  }

  Widget _buildCreatorTile(
    Creator creator,
    CreatorQuickAccessProvider provider,
    bool isDark,
  ) {
    final serviceColor = AppTheme.getServiceColor(creator.service);

    return GestureDetector(
      onTap: () => _openCreator(creator),
      onLongPress: () => _confirmRemoveFavorite(context, creator, provider),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardColor : AppTheme.lightCardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
              blurRadius: 16,
              spreadRadius: -8,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                _buildAvatarWidget(creator, radius: 32),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD740),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? AppTheme.darkCardColor
                          : AppTheme.lightCardColor,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: Colors.white,
                    size: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                creator.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.getOnSurfaceColor(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: serviceColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                creator.service.toUpperCase(),
                style: TextStyle(
                  color: serviceColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarWidget(Creator creator, {double radius = 24}) {
    final avatarUrl = _avatarUrl(creator);
    return Container(
      width: radius * 2,
      height: radius * 2,
      padding: const EdgeInsets.all(2.5),
      decoration: const BoxDecoration(
        gradient: AppTheme.storyRingGradient,
        shape: BoxShape.circle,
      ),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.darkElevatedSurfaceColor,
        ),
        padding: const EdgeInsets.all(2),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: avatarUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: AppTheme.darkElevatedSurfaceColor,
              child: Center(
                child: Text(
                  creator.name.isNotEmpty
                      ? creator.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 16,
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
                    fontSize: 16,
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

  Widget _buildSmallAvatar(Creator creator) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: AppTheme.darkElevatedSurfaceColor,
      child: CachedNetworkImage(
        imageUrl: _avatarUrl(creator),
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: 18,
          backgroundImage: imageProvider,
        ),
        placeholder: (context, url) => Text(
          creator.name.isNotEmpty ? creator.name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: AppTheme.primaryColor,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        errorWidget: (context, url, error) => Text(
          creator.name.isNotEmpty ? creator.name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: AppTheme.primaryColor,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  String _avatarUrl(Creator creator) {
    final domain = (creator.service == 'fansly' ||
            creator.service == 'onlyfans' ||
            creator.service == 'candfans')
        ? 'https://coomer.st'
        : 'https://kemono.cr';
    return '$domain/data/avatars/${creator.service}/${creator.id}/avatar.jpg';
  }
}

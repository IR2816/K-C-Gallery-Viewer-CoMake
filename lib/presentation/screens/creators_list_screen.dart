import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/creators_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/creator_card.dart';
import '../widgets/skeleton_loader.dart';
import '../../domain/entities/api_source.dart';
import '../../domain/entities/creator.dart';
import 'creator_detail_screen.dart';
import 'search_screen_dual.dart';

/// Full creators list with service filtering, pull-to-refresh, and
/// favourites support, backed by [CreatorsProvider].
class CreatorsListScreen extends StatefulWidget {
  const CreatorsListScreen({super.key});

  @override
  State<CreatorsListScreen> createState() => _CreatorsListScreenState();
}

class _CreatorsListScreenState extends State<CreatorsListScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  String _selectedService = 'all';
  String _query = '';

  static const List<Map<String, dynamic>> _services = [
    {'id': 'all', 'label': 'All'},
    {'id': 'patreon', 'label': 'Patreon'},
    {'id': 'fanbox', 'label': 'Fanbox'},
    {'id': 'gumroad', 'label': 'Gumroad'},
    {'id': 'subscribestar', 'label': 'SubscribeStar'},
    {'id': 'fantia', 'label': 'Fantia'},
    {'id': 'afdian', 'label': 'Afdian'},
    {'id': 'boosty', 'label': 'Boosty'},
    {'id': 'dlsite', 'label': 'DLsite'},
    {'id': 'onlyfans', 'label': 'OnlyFans'},
    {'id': 'fansly', 'label': 'Fansly'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCreators();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadCreators({bool refresh = false}) {
    final provider = context.read<CreatorsProvider>();
    if (refresh) provider.clearCreators();
    provider.loadCreators(
      service: _selectedService == 'all' ? null : _selectedService,
    );
  }

  void _onServiceSelected(String serviceId) {
    if (_selectedService == serviceId) return;
    setState(() {
      _selectedService = serviceId;
      _query = '';
      _searchController.clear();
    });
    _loadCreators(refresh: true);
  }

  List<Creator> _filterCreators(List<Creator> creators) {
    if (_query.isEmpty) return creators;
    final lower = _query.toLowerCase();
    return creators
        .where(
          (c) =>
              c.name.toLowerCase().contains(lower) ||
              c.id.toLowerCase().contains(lower),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        toolbarHeight: 72,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.successColor.withValues(alpha: 0.12),
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
              shaderCallback: (bounds) => const LinearGradient(
                colors: [AppTheme.successColor, AppTheme.primaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: const Text(
                'Creators',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                  color: Colors.white,
                  letterSpacing: -0.8,
                  height: 1,
                ),
              ),
            ),
            Text(
              'Follow your favourite artists',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: AppTheme.getSecondaryTextColor(context).withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
        actions: [
          Consumer<SettingsProvider>(
            builder: (context, settings, _) {
              return PopupMenuButton<ApiSource>(
                icon: Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.getElevatedSurfaceColorContext(
                      context,
                    ).withValues(alpha: isDark ? 0.84 : 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.getBorderColor(context),
                    ),
                  ),
                  child: Icon(
                    Icons.swap_horiz_rounded,
                    color: AppTheme.getSecondaryTextColor(context),
                    size: 18,
                  ),
                ),
                tooltip: 'Switch API source',
                onSelected: (source) {
                  settings.setDefaultApiSource(source);
                  _loadCreators(refresh: true);
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: ApiSource.kemono,
                    child: Row(
                      children: [
                        const Icon(Icons.web, size: 18),
                        const SizedBox(width: 8),
                        const Text('Kemono'),
                        if (settings.defaultApiSource == ApiSource.kemono)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.green,
                            ),
                          ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: ApiSource.coomer,
                    child: Row(
                      children: [
                        const Icon(Icons.image, size: 18),
                        const SizedBox(width: 8),
                        const Text('Coomer'),
                        if (settings.defaultApiSource == ApiSource.coomer)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.green,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildServiceFilters(),
          Expanded(child: _buildCreatorList()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.getSurfaceColor(context).withValues(
            alpha: isDark ? 0.85 : 0.7,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.getBorderColor(context)),
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search creators…',
            hintStyle: TextStyle(
              color: AppTheme.getSecondaryTextColor(context).withValues(alpha: 0.6),
              fontSize: 14,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 20,
              color: AppTheme.getSecondaryTextColor(context),
            ),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.cancel_rounded,
                      size: 18,
                      color: AppTheme.getSecondaryTextColor(context),
                    ),
                    onPressed: () {
                      setState(() {
                        _query = '';
                        _searchController.clear();
                      });
                    },
                  )
                : IconButton(
                    icon: Icon(
                      Icons.open_in_new_rounded,
                      size: 18,
                      color: AppTheme.getSecondaryTextColor(context),
                    ),
                    tooltip: 'Advanced search',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SearchScreenDual(),
                      ),
                    ),
                  ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: InputBorder.none,
            isDense: true,
          ),
          style: TextStyle(
            color: AppTheme.getPrimaryTextColor(context),
            fontSize: 14,
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
      ),
    );
  }

  Widget _buildServiceFilters() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        itemCount: _services.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final service = _services[index];
          final selected = _selectedService == service['id'];
          final serviceColor = selected
              ? AppTheme.getServiceColor(service['id'] as String)
              : AppTheme.getSecondaryTextColor(context);
          return GestureDetector(
            onTap: () => _onServiceSelected(service['id'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? serviceColor.withValues(alpha: 0.14)
                    : AppTheme.getSurfaceColor(context).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? serviceColor.withValues(alpha: 0.55)
                      : AppTheme.getBorderColor(context).withValues(alpha: 0.7),
                ),
              ),
              child: Text(
                service['label'] as String,
                style: TextStyle(
                  color: selected
                      ? serviceColor
                      : AppTheme.getSecondaryTextColor(context),
                  fontSize: 12,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCreatorList() {
    return Consumer<CreatorsProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.creators.isEmpty) {
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: 6,
            itemBuilder: (_, __) => const _CreatorCardSkeleton(),
          );
        }

        if (provider.error != null && provider.creators.isEmpty) {
          return _buildError(provider);
        }

        final filtered = _filterCreators(provider.creators);

        if (filtered.isEmpty) {
          return _buildEmpty(provider.creators.isNotEmpty);
        }

        return RefreshIndicator(
          onRefresh: () async => _loadCreators(refresh: true),
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final creator = filtered[index];
              return CreatorCard(
                creator: creator,
                onTap: () => _openCreatorDetail(creator),
                onFavorite: () => provider.toggleFavorite(creator),
              );
            },
          ),
        );
      },
    );
  }

  void _openCreatorDetail(Creator creator) {
    final settings = context.read<SettingsProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatorDetailScreen(
          creator: creator,
          apiSource: settings.defaultApiSource,
        ),
      ),
    );
  }

  Widget _buildError(CreatorsProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load creators',
              style: AppTheme.subtitleStyle.copyWith(
                color: AppTheme.getOnBackgroundColor(context),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              provider.error!,
              textAlign: TextAlign.center,
              style: AppTheme.captionStyle.copyWith(
                color: AppTheme.getOnBackgroundColor(context)
                    .withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _loadCreators(refresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(bool hasFilter) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people_outline,
            size: 48,
            color: AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            hasFilter ? 'No matching creators' : 'No creators found',
            style: AppTheme.bodyStyle.copyWith(
              color: AppTheme.getOnBackgroundColor(context).withValues(alpha: 0.7),
            ),
          ),
          if (hasFilter) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() {
                _query = '';
                _searchController.clear();
              }),
              child: const Text('Clear filter'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Placeholder skeleton card shown while creators are loading.
class _CreatorCardSkeleton extends StatelessWidget {
  const _CreatorCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(AppTheme.mdRadius),
      ),
      child: Row(
        children: [
          AppSkeleton.circle(size: 54),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeleton.rounded(
                  height: 16,
                  width: double.infinity,
                ),
                const SizedBox(height: 8),
                AppSkeleton.rounded(height: 12, width: 120),
                const SizedBox(height: 8),
                AppSkeleton.rounded(height: 10, width: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

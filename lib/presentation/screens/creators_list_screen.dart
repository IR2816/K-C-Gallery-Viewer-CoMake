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
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        title: const Text('Creators'),
        backgroundColor: AppTheme.getSurfaceColor(context),
        foregroundColor: AppTheme.getOnSurfaceColor(context),
        elevation: 0,
        actions: [
          Consumer<SettingsProvider>(
            builder: (context, settings, _) {
              return PopupMenuButton<ApiSource>(
                icon: Icon(
                  Icons.swap_horiz,
                  color: AppTheme.getOnSurfaceColor(context),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Filter creators…',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    setState(() {
                      _query = '';
                      _searchController.clear();
                    });
                  },
                )
              : IconButton(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  tooltip: 'Advanced search',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SearchScreenDual(),
                    ),
                  ),
                ),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: AppTheme.getSurfaceColor(context),
        ),
        onChanged: (value) => setState(() => _query = value),
      ),
    );
  }

  Widget _buildServiceFilters() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _services.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final service = _services[index];
          final selected = _selectedService == service['id'];
          return ChoiceChip(
            label: Text(service['label'] as String),
            selected: selected,
            onSelected: (_) => _onServiceSelected(service['id'] as String),
            selectedColor: AppTheme.primaryColor,
            labelStyle: TextStyle(
              color: selected ? Colors.white : AppTheme.getOnSurfaceColor(context),
              fontSize: 12,
            ),
            backgroundColor: AppTheme.getSurfaceColor(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

// Domain
import '../../domain/entities/discord_server.dart';

// Providers
import '../../providers/discord_search_provider.dart';

// Theme
import '../theme/app_theme.dart';
import '../widgets/app_state_widgets.dart';

// Screens
import 'discord_channel_list_screen.dart';

// Utils

/// 🎯 Discord Search Screen - Search Discord Servers by Name
///
/// Features:
/// - ✅ Search Discord servers by name
/// - ✅ Real-time search with debouncing
/// - ✅ Modern UI consistent with SearchScreenDual
/// - ✅ Error handling and loading states
/// - ✅ Server navigation to channel list
class DiscordSearchScreen extends StatefulWidget {
  const DiscordSearchScreen({super.key});

  @override
  State<DiscordSearchScreen> createState() => _DiscordSearchScreenState();
}

class _DiscordSearchScreenState extends State<DiscordSearchScreen>
    with TickerProviderStateMixin {
  // Controllers
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Animation Controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // State
  Timer? _debounceTimer;
  int _currentPage = 0;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_fadeController);

    // Start animation
    _fadeController.forward();

    // Setup search listener
    _searchController.addListener(_onSearchChanged);

    // Request focus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _fadeController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      final query = _searchController.text;
      if (query.isNotEmpty) {
        _performSearch(query);
      } else {
        _clearSearch();
      }
    });
  }

  Future<void> _performSearch(String query) async {
    final provider = Provider.of<DiscordSearchProvider>(context, listen: false);
    await provider.searchServers(query);
    if (!mounted) return;
    setState(() {
      _currentPage = 0;
    });
  }

  void _clearSearch() {
    final provider = Provider.of<DiscordSearchProvider>(context, listen: false);
    provider.reset();
    setState(() {
      _currentPage = 0;
    });
  }

  void _onServerTap(DiscordServer server) {
    HapticFeedback.lightImpact();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DiscordChannelListScreen(server: server),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? const Color(0xFF1E1F22) : AppTheme.getBackgroundColor(context);
    final appBarColor =
        isDark ? const Color(0xFF2B2D31) : AppTheme.getSurfaceColor(context);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Discord Search',
          style: AppTheme.getTitleStyle(
            context,
          ).copyWith(color: AppTheme.getOnBackgroundColor(context)),
        ),
        backgroundColor: appBarColor,
        foregroundColor: AppTheme.getOnSurfaceColor(context),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: _buildSearchBar(),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Consumer<DiscordSearchProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return _buildLoadingState();
            }

            if (provider.error != null) {
              return _buildErrorState(provider.error!, provider.retry);
            }

            if (provider.hasQuery && !provider.hasResults) {
              return _buildNoResultsState();
            }

            if (provider.hasResults) {
              return _buildSearchResults(provider.searchResults);
            }

            return _buildSuggestionsState();
          },
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldColor =
        isDark ? const Color(0xFF2B2D31) : Theme.of(context).cardColor;

    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: AppTheme.getBodyStyle(
          context,
        ).copyWith(color: AppTheme.getOnSurfaceColor(context)),
        decoration: InputDecoration(
          hintText: 'Search Discord servers...',
          hintStyle: AppTheme.getBodyStyle(context).copyWith(
            color: AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.6),
          ),
          prefixIcon: Icon(
            Icons.search,
            color: AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.6),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.6),
                  ),
                  onPressed: () {
                    _searchController.clear();
                    _clearSearch();
                  },
                )
              : null,
          filled: true,
          fillColor: fieldColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.2),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
          ),
        ),
        onSubmitted: (value) {
          if (value.isNotEmpty) {
            _performSearch(value);
          }
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return const AppSkeletonList();
  }

  Widget _buildErrorState(String error, VoidCallback retry) {
    return AppErrorState(
      title: 'Search Error',
      message: error,
      onRetry: retry,
    );
  }

  Widget _buildNoResultsState() {
    return AppEmptyState(
      icon: Icons.search_off,
      title: 'No Results Found',
      message:
          'No Discord servers found for "${_searchController.text}". Try different keywords or check spelling.',
    );
  }

  Widget _buildSuggestionsState() {
    final provider = Provider.of<DiscordSearchProvider>(context, listen: false);
    final suggestions = provider.getSearchSuggestions();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Popular Searches',
            style: AppTheme.getTitleStyle(context).copyWith(fontSize: 18),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((suggestion) {
              return ActionChip(
                label: Text(suggestion),
                onPressed: () {
                  _searchController.text = suggestion;
                  _performSearch(suggestion);
                },
                backgroundColor: Theme.of(context).cardColor,
                side: BorderSide(
                  color: AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.2),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.discord,
                    size: 64,
                    color: AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Search Discord Servers',
                    style: AppTheme.getTitleStyle(context).copyWith(
                      color: AppTheme.getOnSurfaceColor(
                        context,
                      ).withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Find your favorite Discord servers',
                    style: AppTheme.getBodyStyle(context).copyWith(
                      color: AppTheme.getOnSurfaceColor(
                        context,
                      ).withValues(alpha: 0.5),
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

  Widget _buildSearchResults(List<DiscordServer> results) {
    final pagedResults = _paginateResults(results);

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pagedResults.length,
            itemBuilder: (context, index) {
              final server = pagedResults[index];
              return _buildServerCard(server);
            },
          ),
        ),
        if (results.length > _pageSize)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildPaginationControls(results.length),
          ),
      ],
    );
  }

  Widget _buildServerCard(DiscordServer server) {
    final bannerUrl = _buildDiscordBannerUrl(server.id);
    final iconUrl = _buildDiscordIconUrl(server.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 
              Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.1,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onServerTap(server),
          borderRadius: BorderRadius.circular(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 110,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: bannerUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: const Color(0xFF5865F2).withValues(alpha: 0.2),
                      ),
                      errorWidget: (context, url, error) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF5865F2).withValues(alpha: 0.4),
                              Colors.black.withValues(alpha: 0.6),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.black.withValues(alpha: 0.35),
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5865F2).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'DISCORD',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: iconUrl,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => Center(
                                child: Text(
                                  server.name.isNotEmpty
                                      ? server.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                server.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ID: ${server.id}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: Colors.white70,
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

  List<DiscordServer> _paginateResults(List<DiscordServer> results) {
    if (results.isEmpty) return [];
    final totalPages = (results.length / _pageSize).ceil();
    final safePage =
        _currentPage >= totalPages ? totalPages - 1 : _currentPage;
    if (safePage != _currentPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _currentPage = safePage;
        });
      });
    }
    final start = safePage * _pageSize;
    final end = (start + _pageSize) > results.length
        ? results.length
        : (start + _pageSize);
    return results.sublist(start, end);
  }

  Widget _buildPaginationControls(int totalItems) {
    final totalPages = (totalItems / _pageSize).ceil();
    final canPrev = _currentPage > 0;
    final canNext = _currentPage < totalPages - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: canPrev
                ? () {
                    setState(() {
                      _currentPage -= 1;
                    });
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
            color: canPrev
                ? AppTheme.getOnSurfaceColor(context)
                : AppTheme.secondaryTextColor,
          ),
          Expanded(
            child: Center(
              child: Text(
                'Page ${_currentPage + 1} of $totalPages',
                style: AppTheme.getCaptionStyle(context).copyWith(
                  color: AppTheme.getOnSurfaceColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: canNext
                ? () {
                    setState(() {
                      _currentPage += 1;
                    });
                  }
                : null,
            icon: const Icon(Icons.chevron_right),
            color: canNext
                ? AppTheme.getOnSurfaceColor(context)
                : AppTheme.secondaryTextColor,
          ),
        ],
      ),
    );
  }

  String _buildDiscordBannerUrl(String serverId) {
    return 'https://img.kemono.cr/banners/discord/$serverId';
  }

  String _buildDiscordIconUrl(String serverId) {
    return 'https://img.kemono.cr/icons/discord/$serverId';
  }
}

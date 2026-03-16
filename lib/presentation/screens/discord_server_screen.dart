import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

// Domain
import '../../domain/entities/discord_server.dart';

// Providers
import '../../providers/discord_search_provider.dart';

// Theme
import '../theme/app_theme.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/app_state_widgets.dart';

// Screens
import 'discord_channel_list_screen.dart';

/// Screen untuk menampilkan list Discord servers
class DiscordServerScreen extends StatefulWidget {
  const DiscordServerScreen({super.key});

  @override
  State<DiscordServerScreen> createState() => _DiscordServerScreenState();
}

class _DiscordServerScreenState extends State<DiscordServerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _popularScrollController = ScrollController();
  Timer? _debounceTimer;
  bool _isSearching = false;
  List<DiscordServer> _filteredServers = [];
  List<DiscordServer> _visiblePopularServers = [];
  bool _isLoadingMorePopular = false;
  int _popularTotalCount = 0;
  String? _popularFirstId;
  int _currentPopularPage = 1;

  static const int _popularPageSize = 20;

  @override
  void initState() {
    super.initState();

    // Load popular Discord servers from mbaharip API
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DiscordSearchProvider>().loadPopularServers();
    });

    // Setup search listener
    _searchController.addListener(_onSearchChanged);
    _popularScrollController.addListener(_onPopularScroll);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    _popularScrollController.removeListener(_onPopularScroll);
    _popularScrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final query = _searchController.text.toLowerCase().trim();
      final provider = context.read<DiscordSearchProvider>();

      await provider.searchServers(query);
      if (!mounted) return;

      setState(() {
        _isSearching = query.isNotEmpty;
        _filteredServers = provider.searchResults;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF5865F2).withValues(alpha: 0.16),
                Colors.transparent,
              ],
            ),
          ),
        ),
        title: _isSearching
            ? Container(
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.getCardColor(context).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.getBorderColor(
                      context,
                    ).withValues(alpha: 0.5),
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: TextStyle(
                    color: AppTheme.getPrimaryTextColor(context),
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search Discord servers...',
                    hintStyle: TextStyle(
                      color: AppTheme.getSecondaryTextColor(
                        context,
                      ).withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Colors.indigoAccent,
                      size: 18,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  autofocus: true,
                ),
              )
            : Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7289DA), Color(0xFF5865F2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.indigo.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.discord_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF7289DA), Color(0xFF5865F2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: const Text(
                          'Discord',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 28,
                            color: Colors.white,
                            letterSpacing: -1.0,
                          ),
                        ),
                      ),
                      Text(
                        'Discover active communities',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.getSecondaryTextColor(
                            context,
                          ).withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
        actions: [
          GestureDetector(
            onTap: () {
              if (_isSearching) {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  _filteredServers = [];
                });
              } else {
                setState(() {
                  _isSearching = true;
                });
                _searchFocusNode.requestFocus();
              }
            },
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: _isSearching
                    ? AppTheme.warningColor.withValues(alpha: 0.16)
                    : AppTheme.getCardColor(context).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isSearching
                      ? AppTheme.warningColor.withValues(alpha: 0.35)
                      : AppTheme.getBorderColor(context),
                ),
              ),
              child: Icon(
                _isSearching ? Icons.close_rounded : Icons.search_rounded,
                size: 20,
                color: _isSearching
                    ? AppTheme.warningColor
                    : AppTheme.getOnSurfaceColor(context),
              ),
            ),
          ),
        ],
      ),
      body: Container(
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
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -60,
              child: Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF5865F2).withValues(alpha: 0.09),
                ),
              ),
            ),
            Positioned(
              top: 80,
              left: -70,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF7289DA).withValues(alpha: 0.06),
                ),
              ),
            ),
            Consumer<DiscordSearchProvider>(
              builder: (context, provider, child) {
                if (!_isSearching) {
                  _ensurePopularVisible(provider);
                }
                final servers = _isSearching
                    ? _filteredServers
                    : _getCurrentPopularPageServers();

                if (provider.isLoading &&
                    (_isSearching
                        ? _filteredServers.isEmpty
                        : provider.popularServers.isEmpty)) {
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: 6,
                    itemBuilder: (context, index) => const DiscordMessageSkeleton(),
                  );
                }

                if (provider.error != null) {
                  return _buildErrorState(provider.error!, () {
                    provider.searchServers(''); // Retry with empty search
                  });
                }

                if (servers.isEmpty) {
                  if (_isSearching) {
                    return _buildNoSearchResultsState();
                  } else {
                    return _buildEmptyState();
                  }
                }

                return Column(
                  children: [
                    // Search results info
                    if (_isSearching)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.getSurfaceColor(
                            context,
                          ).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.getBorderColor(
                              context,
                            ).withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search,
                              size: 16,
                              color: AppTheme.getOnSurfaceColor(
                                context,
                              ).withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${servers.length} servers found',
                              style: AppTheme.getCaptionStyle(context).copyWith(
                                color: AppTheme.getOnSurfaceColor(
                                  context,
                                ).withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Server list
                    Expanded(
                      child: _buildServerList(
                        servers,
                        isSearching: _isSearching,
                      ),
                    ),
                    if (!_isSearching && _visiblePopularServers.isNotEmpty)
                      _buildPopularPaginationBar(provider.popularServers),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerList(
    List<DiscordServer> servers, {
    required bool isSearching,
  }) {
    return ListView.builder(
      controller: isSearching ? null : _popularScrollController,
      padding: const EdgeInsets.all(16),
      itemCount: servers.length,
      itemBuilder: (context, index) {
        final server = servers[index];
        return _buildServerCard(server);
      },
    );
  }

  Widget _buildServerCard(DiscordServer server) {
    final bannerUrl = _buildDiscordBannerUrl(server.id);
    final iconUrl = _buildDiscordIconUrl(server.id);
    final updatedText =
        'Updated ${_formatDate(server.updated.millisecondsSinceEpoch ~/ 1000)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 120,
          child: Stack(
            children: [
              // Banner Background
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: bannerUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: Colors.indigo.withValues(alpha: 0.1)),
                  errorWidget: (context, url, error) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.indigo.withValues(alpha: 0.4),
                          Colors.black,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
              ),
              // Gradient Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.2),
                        Colors.black.withValues(alpha: 0.85),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              // Service Badge
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.indigoAccent.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'DISCORD',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              // Content (Avatar + Text)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            DiscordChannelListScreen(server: server),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
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
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
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
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                server.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                updatedText,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white60,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error, VoidCallback onRetry) {
    return AppErrorState(
      title: 'Error loading servers',
      message: error,
      onRetry: onRetry,
    );
  }

  Widget _buildNoSearchResultsState() {
    return AppEmptyState(
      icon: Icons.search_off,
      title: 'No Servers Found',
      message: 'No servers found for "${_searchController.text}"',
      actionLabel: 'Try Advanced Search',
      onAction: () {
        Navigator.pushNamed(context, '/discord-search');
      },
    );
  }

  Widget _buildEmptyState() {
    return const AppEmptyState(
      icon: Icons.dns_outlined,
      title: 'No Discord servers found',
      message: 'Discord servers will appear here when available',
    );
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }

  void _onPopularScroll() {
    if (_isSearching) return;
    if (!_popularScrollController.hasClients) return;
    final threshold = 200.0;
    if (_popularScrollController.position.pixels >=
        _popularScrollController.position.maxScrollExtent - threshold) {
      final provider = context.read<DiscordSearchProvider>();
      _loadMorePopular(provider.popularServers);
    }
  }

  void _ensurePopularVisible(DiscordSearchProvider provider) {
    final list = provider.popularServers;
    final firstId = list.isNotEmpty ? list.first.id : null;
    if (list.isEmpty) {
      if (_visiblePopularServers.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _visiblePopularServers = [];
            _popularTotalCount = 0;
            _popularFirstId = null;
            _isLoadingMorePopular = false;
          });
        });
      }
      return;
    }

    if (list.length != _popularTotalCount ||
        firstId != _popularFirstId ||
        _visiblePopularServers.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _popularTotalCount = list.length;
          _popularFirstId = firstId;
          _visiblePopularServers = list.take(_popularPageSize).toList();
          _currentPopularPage = 1;
          _isLoadingMorePopular = false;
        });
      });
    }
  }

  void _loadMorePopular(List<DiscordServer> allServers) {
    if (_isLoadingMorePopular) return;
    if (_visiblePopularServers.length >= allServers.length) return;

    setState(() {
      _isLoadingMorePopular = true;
    });

    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      final next = allServers
          .skip(_visiblePopularServers.length)
          .take(_popularPageSize)
          .toList();
      if (next.isEmpty) {
        setState(() {
          _isLoadingMorePopular = false;
        });
        return;
      }
      setState(() {
        _visiblePopularServers.addAll(next);
        _isLoadingMorePopular = false;
      });
    });
  }

  // ignore: unused_element
  Widget _buildLoadingMoreIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: AppSkeleton(shape: BoxShape.circle),
        ),
      ),
    );
  }

  List<DiscordServer> _getCurrentPopularPageServers() {
    if (_visiblePopularServers.isEmpty) {
      return const <DiscordServer>[];
    }
    final start = (_currentPopularPage - 1) * _popularPageSize;
    if (start >= _visiblePopularServers.length) {
      return const <DiscordServer>[];
    }
    final end = (start + _popularPageSize).clamp(
      0,
      _visiblePopularServers.length,
    );
    return _visiblePopularServers.sublist(start, end);
  }

  Widget _buildPopularPaginationBar(List<DiscordServer> allServers) {
    final loadedPages = (_visiblePopularServers.length / _popularPageSize)
        .ceil()
        .clamp(1, 9999);
    final totalPages = (allServers.length / _popularPageSize).ceil().clamp(
      1,
      9999,
    );
    final canGoPrev = _currentPopularPage > 1;
    final canGoNext = _currentPopularPage < totalPages;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 104),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.getCardColor(context).withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.94
                  : 0.8,
            ),
            AppTheme.getElevatedSurfaceColorContext(context).withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.94
                  : 0.8,
            ),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.getBorderColor(context).withValues(alpha: 0.9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.25
                  : 0.1,
            ),
            blurRadius: 18,
            spreadRadius: -10,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildPaginationButton(
            icon: Icons.chevron_left_rounded,
            label: 'Prev',
            enabled: canGoPrev,
            onTap: () => _goToPopularPage(_currentPopularPage - 1, allServers),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Page $_currentPopularPage',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isLoadingMorePopular) ...[
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: AppSkeleton(shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      '$loadedPages/$totalPages loaded',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.getSecondaryTextColor(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildPaginationButton(
            icon: Icons.chevron_right_rounded,
            label: 'Next',
            enabled: canGoNext,
            isNext: true,
            onTap: () => _goToPopularPage(_currentPopularPage + 1, allServers),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationButton({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
    bool isNext = false,
  }) {
    final color = enabled
        ? (isNext ? Colors.white : AppTheme.primaryColor)
        : AppTheme.getSecondaryTextColor(context).withValues(alpha: 0.52);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minWidth: 92),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: enabled && isNext
                ? const LinearGradient(
                    colors: [Color(0xFF7289DA), Color(0xFF5865F2)],
                  )
                : null,
            color: enabled
                ? (isNext
                      ? null
                      : AppTheme.primaryColor.withValues(alpha: 0.15))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: enabled
                  ? (isNext
                        ? const Color(0xFF7289DA).withValues(alpha: 0.7)
                        : AppTheme.primaryColor.withValues(alpha: 0.36))
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isNext) ...[
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
              if (isNext) ...[
                const SizedBox(width: 4),
                Icon(icon, color: color, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _goToPopularPage(int page, List<DiscordServer> allServers) {
    if (page < 1) return;
    final totalPages = (allServers.length / _popularPageSize).ceil().clamp(
      1,
      9999,
    );
    if (page > totalPages) return;

    final requiredVisibleCount = page * _popularPageSize;
    if (_visiblePopularServers.length < requiredVisibleCount &&
        _visiblePopularServers.length < allServers.length) {
      _loadMorePopular(allServers);
    }

    setState(() {
      _currentPopularPage = page;
    });
    if (_popularScrollController.hasClients) {
      _popularScrollController.jumpTo(0);
    }
  }

  String _buildDiscordBannerUrl(String serverId) {
    return 'https://img.kemono.cr/banners/discord/$serverId';
  }

  String _buildDiscordIconUrl(String serverId) {
    return 'https://img.kemono.cr/icons/discord/$serverId';
  }
}

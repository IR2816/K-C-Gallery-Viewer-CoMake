import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Domain
import '../../domain/entities/discord_server.dart';
import '../../domain/entities/discord_channel.dart';

// Providers
import '../../providers/discord_provider.dart';
import '../providers/settings_provider.dart';

// Theme
import '../theme/app_theme.dart';
import '../widgets/app_state_widgets.dart';

// Screens
import 'discord_channel_posts_screen.dart';

/// Discord Channel List Screen
/// Shows channels for a specific Discord server with modern UI
class DiscordChannelListScreen extends StatefulWidget {
  final DiscordServer server;

  const DiscordChannelListScreen({super.key, required this.server});

  @override
  State<DiscordChannelListScreen> createState() =>
      _DiscordChannelListScreenState();
}

class _DiscordChannelListScreenState extends State<DiscordChannelListScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  Timer? _searchDebounce;
  String _searchQuery = '';
  String _pendingQuery = '';

  @override
  void initState() {
    super.initState();

    // Animation setup
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    // Load channels for this server
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DiscordProvider>().loadChannels(widget.server.id);
      _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _pendingQuery = query;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = _pendingQuery.toLowerCase();
      });
    });
  }

  void _openChannel(DiscordChannel channel) {
    HapticFeedback.lightImpact();

    if (channel.canOpen) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              DiscordChannelPostsScreen(
                channelId: channel.id,
                channelName: channel.name,
              ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(1.0, 0.0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                  ),
              child: child,
            );
          },
        ),
      );
    } else {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This channel has no posts or cannot be opened',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.orange[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? const Color(0xFF1E1F22) : AppTheme.getBackgroundColor(context);

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Custom App Bar with Server Info
          _buildSliverAppBar(),

          // Search Bar
          SliverToBoxAdapter(child: _buildSearchBar()),

          // Channels List
          Consumer<DiscordProvider>(
            builder: (context, provider, child) {
              if (provider.isLoadingChannels) {
                return SliverFillRemaining(child: _buildLoadingState());
              }

              if (provider.channelsError != null) {
                return SliverFillRemaining(
                  child: _buildErrorState(provider.channelsError!, () {
                    provider.loadChannels(widget.server.id);
                  }),
                );
              }

              final settings = context.watch<SettingsProvider>();
              final channels = _searchQuery.isEmpty
                  ? provider.channels
                  : provider.channels
                      .where((channel) =>
                          channel.name.toLowerCase().contains(_searchQuery))
                      .toList();
              final visibleChannels = settings.hideNsfw
                  ? channels.where((c) => !c.isNsfw).toList()
                  : channels;

              if (visibleChannels.isEmpty) {
                return SliverFillRemaining(
                  child: _searchQuery.isEmpty
                      ? _buildEmptyState()
                      : _buildNoSearchResults(),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final channel = visibleChannels[index];
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0, 0.3),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: _fadeController,
                                curve: Interval(
                                  (index / channels.length) * 0.5,
                                  0.8 + (index / channels.length) * 0.2,
                                  curve: Curves.easeOut,
                                ),
                              ),
                            ),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildChannelCard(channel),
                        ),
                      ),
                    );
                  }, childCount: visibleChannels.length),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    final bannerUrl = _buildDiscordBannerUrl(widget.server.id);
    final iconUrl = _buildDiscordIconUrl(widget.server.id);
    return SliverAppBar(
      expandedHeight: 220,
      floating: false,
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: AppTheme.getBackgroundColor(context),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            // Banner with high-end treatment
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: bannerUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.indigo.withValues(alpha: 0.1)),
                errorWidget: (context, url, error) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.indigo.withValues(alpha: 0.8), Colors.black],
                    ),
                  ),
                ),
              ),
            ),
            // Multi-layer gradient for depth
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.9),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 25,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Server Icon with premium border
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: iconUrl,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => const Icon(Icons.discord_rounded, color: Colors.white, size: 30),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'CHANNEL LIST',
                          style: TextStyle(
                            color: Colors.indigoAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.server.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: () {
            context.read<DiscordProvider>().loadChannels(widget.server.id);
            HapticFeedback.lightImpact();
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _searchQuery.isNotEmpty 
              ? Colors.indigoAccent.withValues(alpha: 0.4) 
              : Theme.of(context).dividerColor.withValues(alpha: 0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        onChanged: _onSearchChanged,
        style: TextStyle(
          color: isDark ? Colors.white : AppTheme.lightPrimaryTextColor,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: 'Search channels...',
          hintStyle: TextStyle(
            color: isDark
                ? Colors.white.withValues(alpha: 0.4)
                : AppTheme.lightSecondaryTextColor.withValues(alpha: 0.6),
          ),
          prefixIcon: Icon(
            Icons.tag_rounded, 
            color: _searchQuery.isNotEmpty ? Colors.indigoAccent : AppTheme.getIconColor(context),
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: isDark ? Colors.white : AppTheme.lightPrimaryTextColor,
                  ),
                  onPressed: () => _onSearchChanged(''),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildChannelCard(DiscordChannel channel) {
    final isDisabled = !channel.canOpen;
    final accentColor = const Color(0xFF5865F2);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (channel.isCategory) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Icon(
              Icons.folder_open,
              size: 16,
              color: AppTheme.getIconColor(context),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                channel.name.toUpperCase(),
                style: AppTheme.getCaptionStyle(context).copyWith(
                  color: AppTheme.getSecondaryTextColor(context),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: channel.canOpen ? () => _openChannel(channel) : null,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accentColor.withValues(alpha: 0.2),
                        accentColor.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                  ),
                  child: Center(
                    child: Text(
                      channel.displayEmoji.isNotEmpty ? channel.displayEmoji : '#',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        channel.name,
                        style: TextStyle(
                          color: isDisabled
                              ? AppTheme.getPrimaryTextColor(context).withValues(alpha: 0.4)
                              : AppTheme.getPrimaryTextColor(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (channel.isNsfw) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
                          ),
                          child: const Text(
                            'NSFW',
                            style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (channel.postCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      channel.postCount > 999
                          ? '${(channel.postCount / 1000).toStringAsFixed(1)}k'
                          : '${channel.postCount}',
                      style: TextStyle(
                        color: accentColor.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                else if (!channel.canOpen)
                  const Icon(Icons.lock_rounded, color: Colors.orangeAccent, size: 16),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const AppSkeletonList(
      itemCount: 6,
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
    );
  }

  Widget _buildErrorState(String error, VoidCallback onRetry) {
    return AppErrorState(
      title: 'Error Loading Channels',
      message: error,
      onRetry: onRetry,
    );
  }

  Widget _buildEmptyState() {
    return const AppEmptyState(
      icon: Icons.chat_bubble_outline,
      title: 'No Channels Found',
      message: 'This server doesn\'t have any channels available.',
    );
  }

  Widget _buildNoSearchResults() {
    return AppEmptyState(
      icon: Icons.search_off,
      title: 'No Channels Found',
      message: 'No channels match "$_searchQuery"',
      actionLabel: 'Clear Search',
      onAction: () => _onSearchChanged(''),
    );
  }

  String _buildDiscordBannerUrl(String serverId) {
    return 'https://img.kemono.cr/banners/discord/$serverId';
  }

  String _buildDiscordIconUrl(String serverId) {
    return 'https://img.kemono.cr/icons/discord/$serverId';
  }
}

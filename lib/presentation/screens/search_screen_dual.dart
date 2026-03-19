import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Domain
import '../../domain/entities/api_source.dart';
import '../../domain/entities/creator.dart';
import '../../domain/entities/discord_server.dart';

// Providers
import '../providers/creator_search_provider.dart';
import '../providers/creators_provider.dart';
import '../providers/settings_provider.dart';

// Services
import '../services/creator_index_manager.dart';

// Data
import '../../data/datasources/creator_index_datasource_impl.dart';
import '../../data/models/creator_search_result.dart';

// Theme
import '../theme/app_theme.dart';

// Screens
import 'creator_detail_screen.dart';
import 'discord_channel_list_screen.dart';

// Widgets
import '../widgets/popular_creators_section.dart';
import '../widgets/skeleton_loader.dart';

// Utils
import '../../utils/logger.dart';

/// 🎯 DUAL SearchScreen - Name Search + ID Search
///
/// Features:
/// - ✅ Tab 1: Search by Name (Creator Index - fast)
/// - ✅ Tab 2: Search by ID (API search - original)
/// - ✅ Seamless switching between modes
/// - ✅ Modern UI with animations
/// - ✅ Error handling for both modes
class SearchScreenDual extends StatefulWidget {
  const SearchScreenDual({super.key});

  @override
  State<SearchScreenDual> createState() => _SearchScreenDualState();
}

class _SearchScreenDualState extends State<SearchScreenDual>
    with TickerProviderStateMixin {
  // Controllers
  final TextEditingController _nameSearchController = TextEditingController();
  final TextEditingController _idSearchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _idFocusNode = FocusNode();

  // Animation Controllers
  late TabController _tabController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Provider Instance
  late CreatorSearchProvider _creatorSearchProvider;

  // State
  ApiSource _selectedApiSource = ApiSource.kemono;
  String _selectedService = 'patreon'; // Default service
  bool _showPopular = true;
  Timer? _nameSearchDebounce;
  Timer? _idSearchDebounce;

  // Service lists
  static const List<Map<String, dynamic>> _kemonoServices = [
    {
      'id': 'patreon',
      'name': 'Patreon',
      'icon': Icons.favorite,
      'color': Colors.orange,
    },
    {
      'id': 'pixiv_fanbox',
      'name': 'Pixiv Fanbox',
      'icon': Icons.palette,
      'color': Colors.blue,
    },
    {
      'id': 'discord',
      'name': 'Discord',
      'icon': Icons.discord,
      'color': Colors.indigo,
    },
    {
      'id': 'fantia',
      'name': 'Fantia',
      'icon': Icons.star,
      'color': Colors.purple,
    },
    {
      'id': 'afdian',
      'name': 'Afdian',
      'icon': Icons.payment,
      'color': Colors.green,
    },
    {
      'id': 'boosty',
      'name': 'Boosty',
      'icon': Icons.rocket_launch,
      'color': Colors.red,
    },
    {
      'id': 'gumroad',
      'name': 'Gumroad',
      'icon': Icons.shopping_cart,
      'color': Colors.brown,
    },
    {
      'id': 'subscribestar',
      'name': 'SubscribeStar',
      'icon': Icons.star_border,
      'color': Colors.teal,
    },
    {
      'id': 'dlsite',
      'name': 'DLsite',
      'icon': Icons.shop,
      'color': Colors.pink,
    },
  ];

  static const List<Map<String, dynamic>> _coomerServices = [
    {
      'id': 'onlyfans',
      'name': 'OnlyFans',
      'icon': Icons.lock,
      'color': Colors.black,
    },
    {
      'id': 'fansly',
      'name': 'Fansly',
      'icon': Icons.person,
      'color': Colors.blue,
    },
    {
      'id': 'candfans',
      'name': 'CandFans',
      'icon': Icons.cake,
      'color': Colors.pink,
    },
  ];

  @override
  void initState() {
    super.initState();

    // Initialize provider instance
    _creatorSearchProvider = CreatorSearchProvider(
      CreatorIndexManager(CreatorIndexDatasourceImpl()),
    );

    _tabController = TabController(length: 2, vsync: this);
    _tabController.index = 1; // Default to "Search by ID" (index 1)
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    // Initialize provider and prepare index
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSearch();
    });

    // Search listeners
    _nameSearchController.addListener(_onNameSearchChanged);
    _idSearchController.addListener(_onIdSearchChanged);

    // Tab listener
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        HapticFeedback.lightImpact();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
    _nameSearchController.dispose();
    _idSearchController.dispose();
    _nameSearchDebounce?.cancel();
    _idSearchDebounce?.cancel();
    _scrollController.dispose();
    _nameFocusNode.dispose();
    _idFocusNode.dispose();
    super.dispose();
  }

  void _initializeSearch() {
    final settingsProvider = context.read<SettingsProvider>();
    _selectedApiSource = settingsProvider.defaultApiSource;

    // Reset service to default for the API source
    _selectedService = _selectedApiSource == ApiSource.coomer
        ? 'onlyfans'
        : 'patreon';

    // Prepare index for current API source
    _creatorSearchProvider.prepareIndex(_selectedApiSource);

    // Start animation
    _fadeController.forward();
  }

  void _onNameSearchChanged() {
    final query = _nameSearchController.text.trim();
    _nameSearchDebounce?.cancel();
    _nameSearchDebounce = Timer(const Duration(milliseconds: 350), () {
      final currentQuery = _nameSearchController.text.trim();
      if (currentQuery != query) return;
      _handleNameQuery(currentQuery);
    });
  }

  void _onIdSearchChanged() {
    final query = _idSearchController.text.trim();
    _idSearchDebounce?.cancel();

    if (query.isEmpty) {
      final creatorsProvider = context.read<CreatorsProvider>();
      creatorsProvider.clearCreators();
      return;
    }

    _idSearchDebounce = Timer(const Duration(milliseconds: 400), () {
      final currentQuery = _idSearchController.text.trim();
      if (currentQuery != query) return;
      if (currentQuery.length < 3) return;

      _searchCreatorsById(currentQuery);
      context.read<SettingsProvider>().addToSearchHistory(currentQuery);
    });
  }

  void _handleNameQuery(String query) {
    if (query.isEmpty) {
      if (!_showPopular) {
        setState(() {
          _showPopular = true;
        });
      }
      _creatorSearchProvider.clearSearch();
      return;
    }

    if (_showPopular) {
      setState(() {
        _showPopular = false;
      });
    }

    _creatorSearchProvider.searchCreatorsByName(query, _selectedApiSource);
  }

  Future<void> _searchCreatorsById(String query) async {
    final creatorsProvider = context.read<CreatorsProvider>();

    try {
      await creatorsProvider.searchCreators(
        query,
        service: _selectedService, // Use selected service
        apiSource: _selectedApiSource,
      );
    } catch (e) {
      AppLogger.error('ID search failed', tag: 'SearchScreenDual', error: e);
    }
  }

  /// 🚀 NEW: Navigate to Discord Search Screen
  // ignore: unused_element
  void _navigateToDiscordSearch() {
    HapticFeedback.lightImpact();

    // Navigate to Discord search screen
    Navigator.pushNamed(context, '/discord-search');

    // Reset service back to default after navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _selectedService = _selectedApiSource == ApiSource.coomer
              ? 'onlyfans'
              : 'patreon';
        });
      }
    });
  }

  Future<void> _switchApiSource(ApiSource apiSource) async {
    if (_selectedApiSource == apiSource) return;

    setState(() {
      _selectedApiSource = apiSource;
      _nameSearchController.clear();
      _idSearchController.clear();
      _showPopular = true;
      // Reset service to default for the new API source
      _selectedService = apiSource == ApiSource.coomer ? 'onlyfans' : 'patreon';
    });

    HapticFeedback.lightImpact();

    // Prepare index for new API source
    await _creatorSearchProvider.switchApiSource(apiSource);

    if (!mounted) {
      return;
    }

    // Update settings
    context.read<SettingsProvider>().setDefaultApiSource(apiSource);
  }

  void _navigateToCreatorDetail(Creator creator, {ApiSource? apiSource}) {
    HapticFeedback.lightImpact();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreatorDetailScreen(
          creator: creator,
          apiSource: apiSource ?? _selectedApiSource,
        ),
      ),
    );
  }

  Future<void> _openDiscordCreatorFromSearch(
    CreatorSearchResult searchResult,
  ) async {
    HapticFeedback.lightImpact();

    final server = DiscordServer(
      id: searchResult.id,
      name: searchResult.name,
      indexed: DateTime.now(),
      updated: DateTime.now(),
    );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DiscordChannelListScreen(server: server),
      ),
    );
  }

  /// Get current service list based on API source
  List<Map<String, dynamic>> _getCurrentServices() {
    return _selectedApiSource == ApiSource.coomer
        ? _coomerServices
        : _kemonoServices;
  }

  Color _surfaceColor(BuildContext context) => AppTheme.getCardColor(context);

  Color _secondaryTextColor(BuildContext context, {double opacity = 1}) {
    return AppTheme.getSecondaryTextColor(context, opacity: opacity);
  }

  Color _primaryTextColor(BuildContext context, {double opacity = 1}) {
    return AppTheme.getPrimaryTextColor(context, opacity: opacity);
  }

  Color _borderColor(BuildContext context, {double opacity = 1}) {
    return AppTheme.getBorderColor(context, opacity: opacity);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _creatorSearchProvider,
      child: Builder(
        builder: (context) {
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
                      AppTheme.primaryColor.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        AppTheme.primaryGradient.createShader(bounds),
                    child: const Text(
                      'Discover',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 32,
                        color: Colors.white,
                        letterSpacing: -1.2,
                        height: 1,
                      ),
                    ),
                  ),
                  Text(
                    'Explore creators and communities',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _secondaryTextColor(context, opacity: 0.74),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: _surfaceColor(context).withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _borderColor(context, opacity: 0.55),
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.help_outline_rounded, size: 20),
                    onPressed: () => _showSearchHelp(context),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    ),
                    dividerColor: Colors.transparent,
                    labelColor: AppTheme.primaryColor,
                    unselectedLabelColor: _secondaryTextColor(context),
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: -0.2,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: -0.2,
                    ),
                    tabs: const [
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_search_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('By Name'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.tag_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('By ID'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            body: Container(
              decoration: BoxDecoration(
                gradient: AppTheme.getBackgroundGradient(context),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _buildApiSourceSelector(context),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildNameSearchTab(context),
                        _buildIdSearchTab(context),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildApiSourceSelector(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _surfaceColor(context).withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _borderColor(context, opacity: 0.55)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.1
                    : 0.05,
              ),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildApiSourceButton(ApiSource.kemono),
            const SizedBox(width: 6),
            _buildApiSourceButton(ApiSource.coomer),
          ],
        ),
      ),
    );
  }

  Widget _buildApiSourceButton(ApiSource apiSource) {
    final isSelected = _selectedApiSource == apiSource;
    final isPreparing = context.select<CreatorSearchProvider, bool>(
      (provider) =>
          provider.preparing && provider.currentApiSource == apiSource,
    );
    final label = apiSource == ApiSource.kemono ? 'Kemono' : 'Coomer';

    return Expanded(
      child: GestureDetector(
        onTap: isPreparing ? null : () => _switchApiSource(apiSource),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            gradient: isSelected ? AppTheme.primaryGradient : null,
            borderRadius: BorderRadius.circular(AppTheme.pillRadius),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isPreparing)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: AppSkeleton(
                    width: 14,
                    height: 14,
                    shape: BoxShape.circle,
                  ),
                )
              else
                Icon(
                  apiSource == ApiSource.kemono
                      ? Icons.star_rounded
                      : Icons.favorite_rounded,
                  size: 14,
                  color: isSelected
                      ? Colors.white
                      : _secondaryTextColor(context),
                ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : _secondaryTextColor(context),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameSearchTab(BuildContext context) {
    return Consumer<CreatorSearchProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: _surfaceColor(context),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _nameSearchController.text.isNotEmpty
                        ? AppTheme.primaryColor.withValues(alpha: 0.8)
                        : _borderColor(context),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (_nameSearchController.text.isNotEmpty
                                  ? AppTheme.primaryColor
                                  : Colors.black)
                              .withValues(
                                alpha:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? 0.15
                                    : 0.08,
                              ),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _nameSearchController,
                  focusNode: _nameFocusNode,
                  onChanged: (_) => _onNameSearchChanged(),
                  style: TextStyle(
                    color: _primaryTextColor(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search creator by name...',
                    hintStyle: TextStyle(
                      color: _secondaryTextColor(context, opacity: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                    prefixIcon: Container(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Icons.search_rounded,
                        color: _nameSearchController.text.isNotEmpty
                            ? AppTheme.primaryColor
                            : _secondaryTextColor(context),
                        size: 24,
                      ),
                    ),
                    suffixIcon: _nameSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () {
                              _nameSearchController.clear();
                              _onNameSearchChanged();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Content
            Expanded(child: _buildNameSearchContent(context, provider)),
          ],
        );
      },
    );
  }

  Widget _buildIdSearchTab(BuildContext context) {
    return Consumer2<CreatorsProvider, SettingsProvider>(
      builder: (context, provider, settingsProvider, _) {
        final currentServices = _getCurrentServices();
        final services = currentServices
            .map((service) => service['id'] as String)
            .toList();
        final history = settingsProvider.searchHistory;

        return Column(
          children: [
            SizedBox(
              height: 56,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: services.length,
                itemBuilder: (context, index) {
                  final service = services[index];
                  final serviceData = currentServices.firstWhere(
                    (item) => item['id'] == service,
                    orElse: () => {
                      'id': service,
                      'name': service,
                      'icon': Icons.hub_rounded,
                    },
                  );
                  final isSelected = _selectedService == service;
                  final serviceColor = _getServiceColor(service);

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        if (_selectedService == service) return;
                        HapticFeedback.selectionClick();
                        setState(() => _selectedService = service);
                        final query = _idSearchController.text.trim();
                        if (query.length >= 3) {
                          _searchCreatorsById(query);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? serviceColor.withValues(alpha: 0.15)
                              : _surfaceColor(context).withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected
                                ? serviceColor.withValues(alpha: 0.85)
                                : _borderColor(context, opacity: 0.6),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              serviceData['icon'] as IconData? ??
                                  Icons.hub_rounded,
                              size: 16,
                              color: isSelected
                                  ? serviceColor
                                  : _secondaryTextColor(context),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              serviceData['name'] as String? ?? service,
                              style: TextStyle(
                                color: isSelected
                                    ? serviceColor
                                    : _secondaryTextColor(context),
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: _surfaceColor(context),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: _idSearchController.text.isNotEmpty
                        ? AppTheme.primaryColor.withValues(alpha: 0.75)
                        : _borderColor(context),
                    width: 1.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (_idSearchController.text.isNotEmpty
                                  ? AppTheme.primaryColor
                                  : Colors.black)
                              .withValues(
                                alpha:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? 0.12
                                    : 0.06,
                              ),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _idSearchController,
                  focusNode: _idFocusNode,
                  style: TextStyle(
                    color: _primaryTextColor(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by creator ID or keyword...',
                    hintStyle: TextStyle(
                      color: _secondaryTextColor(context, opacity: 0.55),
                    ),
                    prefixIcon: const Icon(
                      Icons.tag_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    suffixIcon: _idSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () {
                              _idSearchController.clear();
                              _onIdSearchChanged();
                              setState(() {});
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (value) {
                    final query = value.trim();
                    if (query.length >= 3) {
                      _searchCreatorsById(query);
                      settingsProvider.addToSearchHistory(query);
                    }
                  },
                ),
              ),
            ),
            if (history.isNotEmpty && _idSearchController.text.trim().isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Searches',
                          style: AppTheme.captionStyle.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextButton(
                          onPressed: settingsProvider.clearSearchHistory,
                          child: Text(
                            'Clear',
                            style: AppTheme.captionStyle.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: history.take(6).map((query) {
                        return InputChip(
                          label: Text(query),
                          onPressed: () {
                            _idSearchController.text = query;
                            _onIdSearchChanged();
                            _idFocusNode.unfocus();
                            setState(() {});
                          },
                          onDeleted: () =>
                              settingsProvider.removeFromSearchHistory(query),
                          deleteIcon: Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.65),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Expanded(child: _buildIdSearchContent(context, provider)),
          ],
        );
      },
    );
  }

  Widget _buildNameSearchContent(
    BuildContext context,
    CreatorSearchProvider provider,
  ) {
    // Show loading state
    if (provider.loading) {
      return ListView.builder(
        padding: const EdgeInsets.all(AppTheme.mdPadding),
        itemCount: 4,
        itemBuilder: (context, index) => const PopularCreatorSkeleton(),
      );
    }

    // Show error state
    if (provider.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.xlPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
              const SizedBox(height: AppTheme.mdSpacing),
              Text(
                'Search Error',
                style: AppTheme.titleStyle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppTheme.smSpacing),
              Text(
                provider.error!,
                style: AppTheme.bodyStyle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.lgSpacing),
              ElevatedButton.icon(
                onPressed: () => _onNameSearchChanged(),
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show popular creators if no search query
    if (_showPopular) {
      return _buildPopularCreators(provider);
    }

    // Show search results from mbaharip API
    if (provider.nameSearchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.xlPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: AppTheme.secondaryTextColor,
              ),
              const SizedBox(height: AppTheme.mdSpacing),
              Text(
                'No creators found',
                style: AppTheme.titleStyle.copyWith(
                  color: AppTheme.primaryTextColor,
                ),
              ),
              const SizedBox(height: AppTheme.smSpacing),
              Text(
                'Try different keywords or check spelling',
                style: AppTheme.bodyStyle.copyWith(
                  color: AppTheme.secondaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return _buildNameSearchResults(context, provider);
  }

  Widget _buildIdSearchContent(
    BuildContext context,
    CreatorsProvider provider,
  ) {
    if (provider.isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(AppTheme.mdPadding),
        itemCount: 4,
        itemBuilder: (context, index) => const PopularCreatorSkeleton(),
      );
    }

    if (provider.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.xlPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
              const SizedBox(height: AppTheme.mdSpacing),
              Text(
                'Search Error',
                style: AppTheme.titleStyle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppTheme.smSpacing),
              Text(
                provider.error!,
                style: AppTheme.bodyStyle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.mdSpacing),
              ElevatedButton.icon(
                onPressed: () => _searchCreatorsById(_idSearchController.text),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.creators.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.xlPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(height: AppTheme.mdSpacing),
              Text(
                'No creators found',
                style: AppTheme.titleStyle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppTheme.smSpacing),
              Text(
                'Try different creator ID or check spelling',
                style: AppTheme.bodyStyle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        AppTheme.mdPadding,
        0,
        AppTheme.mdPadding,
        AppTheme.getBottomContentPadding(context),
      ),
      itemCount: provider.creators.length,
      itemBuilder: (context, index) {
        final creator = provider.creators[index];
        return _buildCreatorTile(context, creator, index);
      },
    );
  }

  Widget _buildCreatorTile(BuildContext context, Creator creator, int index) {
    final service = creator.service.toLowerCase();
    final bannerUrl = _buildCreatorBannerUrl(service, creator.id);
    final iconUrl = _buildCreatorIconUrl(service, creator.id);
    final serviceColor = _getServiceColor(creator.service);

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.mdSpacing),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Banner Background
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: bannerUrl,
                httpHeaders: _getCoomerHeaders(bannerUrl),
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: serviceColor.withValues(alpha: 0.1)),
                errorWidget: (context, url, error) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        serviceColor.withValues(alpha: 0.4),
                        Colors.black,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),
            // Dark Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            // Content
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _navigateToCreatorDetail(creator),
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.mdPadding),
                  child: Row(
                    children: [
                      // Creator Icon
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: iconUrl,
                            httpHeaders: _getCoomerHeaders(iconUrl),
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Icon(
                              Icons.person,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.mdSpacing),
                      // Creator Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              creator.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: serviceColor.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    creator.service.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'ID: ${creator.id}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white54,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularCreators(CreatorSearchProvider provider) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          // Use our new PopularCreatorsSection widget
          const PopularCreatorsSection(),
        ],
      ),
    );
  }

  Widget _buildNameSearchResults(
    BuildContext context,
    CreatorSearchProvider provider,
  ) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          if (provider.currentQuery.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(AppTheme.mdPadding),
              child: Row(
                children: [
                  Text(
                    'Results for "${provider.currentQuery}"',
                    style: AppTheme.titleStyle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${provider.nameSearchResults.length} found',
                    style: AppTheme.captionStyle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: provider.nameSearchResults.isEmpty
                ? _buildEmptySearch(context)
                : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(
                      AppTheme.mdPadding,
                      0,
                      AppTheme.mdPadding,
                      AppTheme.getBottomContentPadding(context),
                    ),
                    itemCount: provider.nameSearchResults.length,
                    itemBuilder: (context, index) {
                      final searchResult = provider.nameSearchResults[index];
                      final creator = provider.searchResultToCreator(
                        searchResult,
                      );
                      return _buildCreatorSearchResultTile(
                        context,
                        searchResult,
                        creator,
                        index,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatorSearchResultTile(
    BuildContext context,
    CreatorSearchResult searchResult,
    Creator? creator,
    int index,
  ) {
    final service = searchResult.service.toLowerCase();
    final bannerUrl = _buildCreatorBannerUrl(service, searchResult.id);
    final iconUrl =
        searchResult.avatar != null && searchResult.avatar!.isNotEmpty
        ? searchResult.avatar!
        : _buildCreatorIconUrl(service, searchResult.id);
    final serviceColor = _getServiceColor(searchResult.service);

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.lgSpacing),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 15,
            offset: const Offset(0, 8),
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
                  httpHeaders: _getCoomerHeaders(bannerUrl),
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: serviceColor.withValues(alpha: 0.1)),
                  errorWidget: (context, url, error) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          serviceColor.withValues(alpha: 0.4),
                          Colors.black,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
              ),
              // More complex gradient overlay for better text readability
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.4),
                        Colors.black.withValues(alpha: 0.85),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
              ),
              // Service Badge (Top Right)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: serviceColor.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Text(
                    searchResult.service.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              // Content
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (service == 'discord') {
                      _openDiscordCreatorFromSearch(searchResult);
                      return;
                    }
                    if (creator != null) {
                      HapticFeedback.lightImpact();
                      Navigator.of(
                        context,
                      ).pushNamed('/creator', arguments: creator);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Avatar Container with border
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: CachedNetworkImage(
                              imageUrl: iconUrl,
                              httpHeaders: _getCoomerHeaders(iconUrl),
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => const Icon(
                                Icons.person,
                                color: Colors.white70,
                                size: 30,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Text Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                searchResult.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                searchResult.fans != null
                                    ? '${searchResult.fans} favorites'
                                    : 'ID: ${searchResult.id}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white60,
                          size: 18,
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

  Color _getServiceColor(String service) {
    switch (service.toLowerCase()) {
      case 'patreon':
        return Colors.orange;
      case 'fanbox':
        return Colors.purple;
      case 'discord':
        return Colors.blueGrey;
      case 'fantia':
        return Colors.pink;
      case 'afdian':
        return Colors.teal;
      case 'boosty':
        return Colors.red;
      case 'gumroad':
        return Colors.green;
      case 'subscribestar':
        return Colors.amber;
      case 'dlsite':
        return Colors.indigo;
      case 'onlyfans':
        return Colors.deepPurple;
      case 'fansly':
        return Colors.pink;
      case 'candfans':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  ApiSource _apiSourceForService(String service) {
    const coomerServices = {'onlyfans', 'fansly', 'candfans'};
    return coomerServices.contains(service.toLowerCase())
        ? ApiSource.coomer
        : ApiSource.kemono;
  }

  String _buildCreatorBannerUrl(String service, String creatorId) {
    final apiSource = _apiSourceForService(service);
    final base = apiSource == ApiSource.coomer
        ? 'https://img.coomer.st'
        : 'https://img.kemono.cr';
    return '$base/banners/$service/$creatorId';
  }

  String _buildCreatorIconUrl(String service, String creatorId) {
    final apiSource = _apiSourceForService(service);
    final base = apiSource == ApiSource.coomer
        ? 'https://img.coomer.st'
        : 'https://img.kemono.cr';
    return '$base/icons/$service/$creatorId';
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

  Widget _buildEmptySearch(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.xlPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(height: AppTheme.mdSpacing),
            Text(
              'No creators found',
              style: AppTheme.titleStyle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppTheme.smSpacing),
            Text(
              'Try different keywords or check spelling',
              style: AppTheme.bodyStyle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showSearchHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Search Help'),
        content: const Text(
          'Use "By Name" for indexed creator search, or "By ID" when you already know creator ID and service.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

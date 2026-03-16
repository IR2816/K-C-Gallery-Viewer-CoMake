import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/creators_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/creator_card.dart';
import '../widgets/service_selector.dart';
import '../../data/datasources/kemono_remote_datasource.dart';
import 'creator_detail_screen.dart';

class CreatorsListScreen extends StatefulWidget {
  const CreatorsListScreen({super.key});

  @override
  _CreatorsListScreenState createState() => _CreatorsListScreenState();
}

class _CreatorsListScreenState extends State<CreatorsListScreen>
    with TickerProviderStateMixin {
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  final List<Map<String, dynamic>> _services = [
    {
      'id': 'all',
      'name': 'All Services',
      'icon': Icons.apps,
      'color': Colors.blue,
    },
    {
      'id': 'patreon',
      'name': 'Patreon',
      'icon': Icons.star,
      'color': Colors.orange,
    },
    {
      'id': 'fanbox',
      'name': 'Fanbox',
      'icon': Icons.palette,
      'color': Colors.purple,
    },
    {
      'id': 'gumroad',
      'name': 'Gumroad',
      'icon': Icons.shopping_cart,
      'color': Colors.green,
    },
    {
      'id': 'subscribestar',
      'name': 'SubscribeStar',
      'icon': Icons.star_border,
      'color': Colors.amber,
    },
    {
      'id': 'fantia',
      'name': 'Fantia',
      'icon': Icons.favorite,
      'color': Colors.pink,
    },
    {
      'id': 'afdian',
      'name': 'Afdian',
      'icon': Icons.attach_money,
      'color': Colors.teal,
    },
    {
      'id': 'boosty',
      'name': 'Boosty',
      'icon': Icons.rocket,
      'color': Colors.red,
    },
    {
      'id': 'dlsite',
      'name': 'DLsite',
      'icon': Icons.download,
      'color': Colors.indigo,
    },
    {
      'id': 'dropbox',
      'name': 'Dropbox',
      'icon': Icons.cloud,
      'color': Colors.blue,
    },
    {
      'id': 'onlyfans',
      'name': 'OnlyFans',
      'icon': Icons.lock,
      'color': Colors.deepPurple,
    },
    {
      'id': 'buy_me_a_coffee',
      'name': 'Buy Me a Coffee',
      'icon': Icons.coffee,
      'color': Colors.brown,
    },
    {
      'id': 'discord',
      'name': 'Discord',
      'icon': Icons.chat,
      'color': Colors.blueGrey,
    },
    {
      'id': 'itchio',
      'name': 'Itch.io',
      'icon': Icons.games,
      'color': Colors.lightGreen,
    },
    {
      'id': 'newgrounds',
      'name': 'Newgrounds',
      'icon': Icons.gamepad,
      'color': Colors.blue,
    },
    {
      'id': 'pillowfort',
      'name': 'Pillowfort',
      'icon': Icons.bed,
      'color': Colors.purple,
    },
    {
      'id': 'redgifs',
      'name': 'Redgifs',
      'icon': Icons.video_library,
      'color': Colors.red,
    },
    {
      'id': 'yande.re',
      'name': 'Yande.re',
      'icon': Icons.image,
      'color': Colors.pink,
    },
  ];

  String _selectedService = 'all';

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );
    _fabAnimationController.forward();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kemono Viewer',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor.withOpacity(0.8),
                Theme.of(context).primaryColor.withOpacity(0.6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          // Quick API source switcher
          Consumer<SettingsProvider>(
            builder: (context, settings, _) {
              final isKemono = settings.defaultApiSource == ApiSource.kemono;
              return IconButton(
                icon: Icon(
                  isKemono ? Icons.web : Icons.image,
                  color: Colors.white,
                ),
                tooltip: isKemono ? 'Switch to Coomer' : 'Switch to Kemono',
                onPressed: () {
                  final newSource = isKemono
                      ? ApiSource.coomer
                      : ApiSource.kemono;
                  settings.setApiSource(newSource);
                  context.read<CreatorsProvider>().loadCreators(
                    service: _selectedService == 'all'
                        ? null
                        : _selectedService,
                  );
                },
              );
            },
          ),
          // Detailed API source selector (existing)
          Consumer<SettingsProvider>(
            builder: (context, settingsProvider, _) {
              return PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.white),
                onSelected: (apiSource) {
                  settingsProvider.setDefaultApiSource(apiSource);
                  context.read<CreatorsProvider>().loadCreators(
                    service: _selectedService == 'all'
                        ? null
                        : _selectedService,
                  );
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'kemono',
                    child: Row(
                      children: [
                        Icon(Icons.web, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text('Kemono.su'),
                        if (settingsProvider.defaultApiSource ==
                            ApiSource.kemono)
                          const Icon(Icons.check, color: Colors.green),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'coomer',
                    child: Row(
                      children: [
                        Icon(Icons.image, color: Colors.purple),
                        const SizedBox(width: 8),
                        const Text('Coomer.su'),
                        if (settingsProvider.defaultApiSource ==
                            ApiSource.coomer)
                          const Icon(Icons.check, color: Colors.green),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Service Selector
            ServiceSelector(
              selectedService: _selectedService,
              services: _services,
              onServiceChanged: (serviceId) {
                setState(() {
                  _selectedService = serviceId;
                });
                context.read<CreatorsProvider>().loadCreators(
                  service: serviceId == 'all' ? null : serviceId,
                );
              },
            ),

            // Content
            Expanded(
              child: Consumer<CreatorsProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading && provider.creators.isEmpty) {
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: 6, // Show 6 skeleton items
                      itemBuilder: (context, index) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: _buildSkeletonCard(),
                        );
                      },
                    );
                  }

                  if (provider.error != null && provider.creators.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.red.shade400,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Failed to load creators',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              provider.error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => provider.loadCreators(
                                service: _selectedService == 'all'
                                    ? null
                                    : _selectedService,
                              ),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Try Again'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (provider.creators.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.search_off,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No creators found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try selecting a different service or API source',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      await provider.loadCreators(
                        service: _selectedService == 'all'
                            ? null
                            : _selectedService,
                      );
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: provider.creators.length,
                      itemBuilder: (context, index) {
                        final creator = provider.creators[index];
                        return AnimatedBuilder(
                          animation: _fabAnimationController,
                          builder: (context, child) {
                            final delay = index * 0.1;
                            final animation =
                                Tween<double>(begin: 0.0, end: 1.0).animate(
                                  CurvedAnimation(
                                    parent: _fabAnimationController,
                                    curve: Interval(
                                      delay.clamp(0.0, 1.0),
                                      (delay + 0.3).clamp(0.0, 1.0),
                                      curve: Curves.easeOutCubic,
                                    ),
                                  ),
                                );

                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.0, 0.2),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: CreatorCard(
                                    creator: creator,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              Consumer<SettingsProvider>(
                                                builder:
                                                    (context, settings, _) =>
                                                        CreatorDetailScreen(
                                                          creator: creator,
                                                          apiSource: settings
                                                              .defaultApiSource,
                                                        ),
                                              ),
                                        ),
                                      );
                                    },
                                    onFavorite: () =>
                                        provider.toggleFavorite(creator),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton.extended(
          onPressed: () {
            // Navigate to search screen
            Navigator.pushNamed(context, '/search');
          },
          icon: const Icon(Icons.search),
          label: const Text('Search'),
          backgroundColor: AppTheme.getBackgroundColor(context),
          elevation: 6,
        ),
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 20,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 16,
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 14,
                    width: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'data/datasources/kemono_remote_datasource_impl.dart';
import 'data/datasources/kemono_local_datasource_impl.dart';
import 'data/repositories/kemono_repository_impl.dart';
import 'domain/repositories/kemono_repository.dart';
import 'domain/entities/post.dart';
import 'domain/entities/creator.dart';
import 'presentation/providers/creators_provider.dart';
import 'presentation/providers/posts_provider.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/download_manager.dart';
import 'presentation/providers/tag_filter_provider.dart';
import 'presentation/providers/smart_bookmark_provider.dart';
import 'presentation/providers/smart_history_provider.dart';
import 'presentation/providers/scroll_memory_provider.dart';
import 'presentation/providers/media_filter_provider.dart';
import 'presentation/providers/comments_provider.dart';
import 'presentation/providers/popular_creators_provider.dart';
import 'presentation/providers/data_usage_tracker.dart';
import 'presentation/providers/tracked_http_client.dart';
import 'presentation/providers/download_provider.dart';
import 'presentation/providers/bookmark_provider.dart';
import 'presentation/providers/creator_quick_access_provider.dart';
import 'presentation/providers/search_history_provider.dart';
import 'presentation/providers/post_search_provider.dart';
// 🚀 NEW: Discord imports
import 'providers/discord_provider.dart';
import 'providers/discord_search_provider.dart';
import 'data/services/discord_api_client.dart';
import 'presentation/services/creator_index_manager.dart';
import 'presentation/theme/app_theme.dart';
import 'data/datasources/creator_index_datasource_impl.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/main_navigation_screen.dart';
import 'presentation/screens/search_screen_dual.dart';
import 'presentation/screens/creator_detail_screen.dart';
import 'presentation/screens/post_detail_screen.dart';
import 'presentation/screens/settings_screen.dart';
// 🚀 NEW: Discord screens
import 'presentation/screens/discord_server_screen.dart';
import 'presentation/screens/discord_search_screen.dart';
import 'presentation/screens/discord_api_test_screen.dart';
import 'utils/error_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    // Firebase initialization failed (e.g. missing google-services.json).
    // The app continues without Crashlytics; errors are still logged locally.
    debugPrint('Firebase initialization failed: $e');
  }
  AppErrorHandler.initialize();
  final prefs = await SharedPreferences.getInstance();

  final remoteDataSource = KemonoRemoteDataSourceImpl(); // Will use tracked client automatically
  final localDataSource = KemonoLocalDataSourceImpl(prefs: prefs);
  final repository = KemonoRepositoryImpl(
    remoteDataSource: remoteDataSource,
    localDataSource: localDataSource,
  );

  final themeProvider = ThemeProvider();
  await themeProvider.initialize();

  final settingsProvider = SettingsProvider(repository: repository);
  await settingsProvider.loadSettings();

  final downloadManager = DownloadManager();
  await downloadManager.initialize();

  final tagFilterProvider = TagFilterProvider();
  await tagFilterProvider.initialize();

  final creatorIndexDatasource = CreatorIndexDatasourceImpl();
  final creatorIndexManager = CreatorIndexManager(creatorIndexDatasource);

  runApp(
    MyApp(
      repository: repository,
      sharedPreferences: prefs,
      themeProvider: themeProvider,
      settingsProvider: settingsProvider,
      downloadManager: downloadManager,
      tagFilterProvider: tagFilterProvider,
      creatorIndexManager: creatorIndexManager,
    ),
  );
}

class MyApp extends StatelessWidget {
  final KemonoRepository repository;
  final SharedPreferences sharedPreferences;
  final ThemeProvider themeProvider;
  final SettingsProvider settingsProvider;
  final DownloadManager downloadManager;
  final TagFilterProvider tagFilterProvider;
  final CreatorIndexManager creatorIndexManager;

  const MyApp({
    super.key,
    required this.repository,
    required this.sharedPreferences,
    required this.themeProvider,
    required this.settingsProvider,
    required this.downloadManager,
    required this.tagFilterProvider,
    required this.creatorIndexManager,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<KemonoRepository>.value(value: repository),
        ChangeNotifierProvider(create: (_) => themeProvider),
        ChangeNotifierProvider(create: (_) => downloadManager),
        ChangeNotifierProvider(create: (_) => tagFilterProvider),
        Provider<CreatorIndexManager>.value(value: creatorIndexManager),
        ChangeNotifierProvider.value(value: settingsProvider),
        // Quality of Life providers
        ChangeNotifierProvider(create: (_) => SmartBookmarkProvider()),
        ChangeNotifierProvider(create: (_) => SmartHistoryProvider()),
        ChangeNotifierProvider(create: (_) => ScrollMemoryProvider()),
        ChangeNotifierProvider(create: (_) => MediaFilterProvider()),
        ChangeNotifierProvider(
          create: (_) => CreatorsProvider(
            repository: repository,
            settingsProvider: settingsProvider,
            indexManager: creatorIndexManager,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => PostsProvider(repository: repository, settingsProvider: settingsProvider),
        ),
        ChangeNotifierProvider(create: (_) => CommentsProvider(repository: repository)),
        ChangeNotifierProvider(create: (_) => PopularCreatorsProvider()),
        // Data Usage Tracking
        ChangeNotifierProvider(create: (_) => DataUsageTracker()),
        // Download Provider
        ChangeNotifierProvider(create: (_) => DownloadProvider()),
        // Bookmark Provider
        ChangeNotifierProvider(create: (_) => BookmarkProvider()..initialize()),
        // Creator Quick Access (recent + local favorites)
        ChangeNotifierProvider(create: (_) => CreatorQuickAccessProvider()..initialize()),
        // Search History (tracks searches with frequency)
        ChangeNotifierProvider(create: (_) => SearchHistoryProvider()..initialize()),
        // Post Search (search posts by title + tags)
        ChangeNotifierProvider(create: (_) => PostSearchProvider()),
        // 🚀 NEW: Discord Provider
        ChangeNotifierProvider(create: (_) => DiscordProvider(DiscordApiClient(Dio()))),
        ChangeNotifierProvider(create: (_) => DiscordSearchProvider()),
      ],
      child: Consumer<DataUsageTracker>(
        builder: (context, dataUsageTracker, _) {
          // Initialize TrackedHttpClientFactory with DataUsageTracker
          TrackedHttpClientFactory.initialize(dataUsageTracker);

          return Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return Consumer<SettingsProvider>(
                builder: (context, settingsProvider, _) {
                  return MaterialApp(
                    title: 'KC Gallery Viewer',
                    theme: AppTheme.lightTheme,
                    darkTheme: AppTheme.darkTheme,
                    themeMode: themeProvider.themeMode,
                    debugShowCheckedModeBanner: false,
                    builder: (context, child) {
                      final mediaQuery = MediaQuery.of(context);
                      return MediaQuery(
                        data: mediaQuery.copyWith(
                          textScaler: TextScaler.linear(themeProvider.textScale),
                        ),
                        child: _DataUsageAlertOverlay(child: child ?? const SizedBox.shrink()),
                      );
                    },
                    home: MainNavigationScreen(),
                    onGenerateRoute: (settings) {
                      switch (settings.name) {
                        case '/':
                          return MaterialPageRoute(builder: (context) => MainNavigationScreen());
                        case '/home':
                          return MaterialPageRoute(builder: (context) => const HomeScreen());
                        case '/search':
                          return MaterialPageRoute(builder: (context) => const SearchScreenDual());
                        case '/settings':
                          return MaterialPageRoute(builder: (context) => const SettingsScreen());
                        // 🚀 NEW: Discord routes
                        case '/discord':
                          return MaterialPageRoute(
                            builder: (context) => const DiscordServerScreen(),
                          );
                        case '/discord-search':
                          return MaterialPageRoute(
                            builder: (context) => const DiscordSearchScreen(),
                          );
                        case '/discord-test':
                          return MaterialPageRoute(
                            builder: (context) => const DiscordApiTestScreen(),
                          );
                        case '/post':
                          final Post? post = settings.arguments as Post?;
                          if (post != null) {
                            return MaterialPageRoute(
                              builder: (context) => PostDetailScreen(
                                post: post,
                                apiSource: settingsProvider.defaultApiSource,
                              ),
                            );
                          }
                          return MaterialPageRoute(
                            builder: (context) => const MainNavigationScreen(),
                          );
                        case '/creator':
                          final Creator? creator = settings.arguments as Creator?;
                          if (creator != null) {
                            return MaterialPageRoute(
                              builder: (context) => CreatorDetailScreen(
                                creator: creator,
                                apiSource: settingsProvider.defaultApiSource,
                              ),
                            );
                          }
                          return MaterialPageRoute(
                            builder: (context) => const MainNavigationScreen(),
                          );
                        default:
                          return MaterialPageRoute(builder: (context) => MainNavigationScreen());
                      }
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Listens to [DataUsageTracker] and shows in-app notifications for data
/// usage warnings and critical alerts.
class _DataUsageAlertOverlay extends StatefulWidget {
  final Widget child;

  const _DataUsageAlertOverlay({required this.child});

  @override
  State<_DataUsageAlertOverlay> createState() => _DataUsageAlertOverlayState();
}

class _DataUsageAlertOverlayState extends State<_DataUsageAlertOverlay> {
  DataUsageTracker? _tracker;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tracker = Provider.of<DataUsageTracker>(context, listen: false);
    if (_tracker != tracker) {
      _tracker?.removeListener(_onTrackerUpdate);
      _tracker = tracker;
      _tracker!.addListener(_onTrackerUpdate);
    }
  }

  @override
  void dispose() {
    _tracker?.removeListener(_onTrackerUpdate);
    super.dispose();
  }

  void _onTrackerUpdate() {
    final alert = _tracker?.pendingAlert;
    if (alert == null) return;
    // Clear immediately so a subsequent update does not repeat the same alert.
    _tracker?.clearPendingAlert();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (alert.level == DataUsageAlertLevel.critical) {
        _showCriticalDialog(alert.percentage);
      } else {
        _showWarningSnackBar(alert.percentage);
      }
    });
  }

  void _showWarningSnackBar(double percentage) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '⚠️ Data usage warning: ${percentage.toStringAsFixed(1)}% of daily limit used',
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showCriticalDialog(double percentage) {
    final tracker = _tracker;
    if (tracker == null) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('🚨 Critical Data Usage'),
        content: Text(
          'You have used ${percentage.toStringAsFixed(1)}% of your daily data limit. '
          'Consider enabling Data Saver to reduce usage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Dismiss'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              tracker.updateLimits(tracker.limits.copyWith(autoDataSaver: true));
            },
            child: const Text('Enable Data Saver'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

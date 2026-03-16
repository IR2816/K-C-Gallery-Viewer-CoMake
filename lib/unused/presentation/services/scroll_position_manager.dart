import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

/// Prinsip 3.2: Ingat posisi scroll (ini UX emas)
///
/// Saat user:
/// - Buka post
/// - Kembali ke feed
///
/// ❌ Jangan reset ke atas
/// ✅ Kembalikan ke posisi terakhir
///
/// Efek psikologis: "App ini paham aku"
/// Ini sangat meningkatkan kenyamanan, tanpa biaya.
class ScrollPositionManager {
  static const String _prefix = 'scroll_position_';
  static SharedPreferences? _prefs;
  static final Map<String, double> _memoryCache = {};
  static final Map<String, Timer> _debounceTimers = {};

  /// Initialize manager
  static Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Save scroll position for a specific screen
  static Future<void> savePosition(String screenKey, double position) async {
    await _ensureInitialized();

    // Save to memory cache for instant access
    _memoryCache[screenKey] = position;

    // Save to persistent storage
    await _prefs!.setDouble('$_prefix$screenKey', position);

    debugPrint(
      'ScrollPositionManager: Saved position for $screenKey: $position',
    );
  }

  /// Get scroll position for a specific screen
  static Future<double> getPosition(String screenKey) async {
    await _ensureInitialized();

    // Try memory cache first
    if (_memoryCache.containsKey(screenKey)) {
      return _memoryCache[screenKey]!;
    }

    // Try persistent storage
    final position = _prefs!.getDouble('$_prefix$screenKey') ?? 0.0;
    _memoryCache[screenKey] = position;

    debugPrint(
      'ScrollPositionManager: Loaded position for $screenKey: $position',
    );
    return position;
  }

  /// Save scroll position with controller
  static Future<void> saveControllerPosition(
    String screenKey,
    ScrollController controller,
  ) async {
    if (controller.hasClients) {
      await savePosition(screenKey, controller.offset);
    }
  }

  /// Restore scroll position to controller
  static Future<void> restoreControllerPosition(
    String screenKey,
    ScrollController controller, {
    Duration delay = const Duration(milliseconds: 100),
  }) async {
    final position = await getPosition(screenKey);

    if (position > 0 && controller.hasClients) {
      // Delay to ensure layout is complete
      Future.delayed(delay, () {
        if (controller.hasClients) {
          controller.animateTo(
            position,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          debugPrint(
            'ScrollPositionManager: Restored position for $screenKey: $position',
          );
        }
      });
    }
  }

  /// Clear scroll position for a specific screen
  static Future<void> clearPosition(String screenKey) async {
    await _ensureInitialized();

    _memoryCache.remove(screenKey);
    await _prefs!.remove('$_prefix$screenKey');

    debugPrint('ScrollPositionManager: Cleared position for $screenKey');
  }

  /// Clear all scroll positions
  static Future<void> clearAllPositions() async {
    await _ensureInitialized();

    _memoryCache.clear();

    final keys = _prefs!.getKeys().where((key) => key.startsWith(_prefix));
    for (final key in keys) {
      await _prefs!.remove(key);
    }

    debugPrint('ScrollPositionManager: Cleared all positions');
  }

  /// Get all saved positions
  static Future<Map<String, double>> getAllPositions() async {
    await _ensureInitialized();

    final positions = <String, double>{};
    final keys = _prefs!.getKeys().where((key) => key.startsWith(_prefix));

    for (final key in keys) {
      final screenKey = key.substring(_prefix.length);
      final position = _prefs!.getDouble(key) ?? 0.0;
      positions[screenKey] = position;
    }

    return positions;
  }

  /// Check if position exists for screen
  static Future<bool> hasPosition(String screenKey) async {
    await _ensureInitialized();

    return _memoryCache.containsKey(screenKey) ||
        _prefs!.containsKey('$_prefix$screenKey');
  }

  /// Auto-save scroll position on scroll end
  static void setupAutoSave(
    String screenKey,
    ScrollController controller, {
    Duration debounceTime = const Duration(milliseconds: 500),
  }) {
    controller.addListener(() {
      // Cancel previous timer
      _debounceTimers[screenKey]?.cancel();

      // Start new timer
      _debounceTimers[screenKey] = Timer(debounceTime, () {
        if (controller.hasClients) {
          saveControllerPosition(screenKey, controller);
        }
      });
    });
  }

  /// Setup scroll position management for a screen
  static Widget withScrollMemory({
    required String screenKey,
    required Widget child,
    required ScrollController controller,
    bool autoSave = true,
    Duration autoSaveDelay = const Duration(milliseconds: 500),
  }) {
    return _ScrollMemoryWidget(
      screenKey: screenKey,
      controller: controller,
      autoSave: autoSave,
      autoSaveDelay: autoSaveDelay,
      child: child,
    );
  }

  static Future<void> _ensureInitialized() async {
    if (_prefs == null) {
      await initialize();
    }
  }
}

/// Widget untuk mengelola scroll position memory
class _ScrollMemoryWidget extends StatefulWidget {
  final String screenKey;
  final ScrollController controller;
  final Widget child;
  final bool autoSave;
  final Duration autoSaveDelay;

  const _ScrollMemoryWidget({
    required this.screenKey,
    required this.controller,
    required this.child,
    this.autoSave = true,
    this.autoSaveDelay = const Duration(milliseconds: 500),
  });

  @override
  State<_ScrollMemoryWidget> createState() => _ScrollMemoryWidgetState();
}

class _ScrollMemoryWidgetState extends State<_ScrollMemoryWidget> {
  bool _isRestored = false;

  @override
  void initState() {
    super.initState();
    _setupScrollMemory();
  }

  @override
  void dispose() {
    // Save position when widget is disposed
    if (widget.controller.hasClients) {
      ScrollPositionManager.saveControllerPosition(
        widget.screenKey,
        widget.controller,
      );
    }
    super.dispose();
  }

  void _setupScrollMemory() async {
    // Restore position when widget is first built
    if (!_isRestored) {
      await ScrollPositionManager.restoreControllerPosition(
        widget.screenKey,
        widget.controller,
      );
      _isRestored = true;
    }

    // Setup auto-save if enabled
    if (widget.autoSave) {
      ScrollPositionManager.setupAutoSave(
        widget.screenKey,
        widget.controller,
        debounceTime: widget.autoSaveDelay,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Extension untuk ScrollController
extension ScrollControllerExtension on ScrollController {
  /// Save position with key
  Future<void> savePosition(String key) async {
    await ScrollPositionManager.saveControllerPosition(key, this);
  }

  /// Restore position with key
  Future<void> restorePosition(String key, {Duration? delay}) async {
    await ScrollPositionManager.restoreControllerPosition(
      key,
      this,
      delay: delay ?? const Duration(milliseconds: 100),
    );
  }

  /// Setup auto-save with key
  void setupAutoSave(String key, {Duration? debounceTime}) {
    ScrollPositionManager.setupAutoSave(
      key,
      this,
      debounceTime: debounceTime ?? const Duration(milliseconds: 500),
    );
  }
}

/// Screen keys untuk konsistensi
class ScreenKeys {
  static const String homeFeed = 'home_feed';
  static const String searchResults = 'search_results';
  static const String creatorPosts = 'creator_posts';
  static const String creatorMedia = 'creator_media';
  static const String savedPosts = 'saved_posts';
  static const String savedCreators = 'saved_creators';
  static const String settings = 'settings';

  // Dynamic keys
  static String creatorDetail(String service, String creatorId) {
    return 'creator_${service}_$creatorId';
  }

  static String postDetail(String postId) {
    return 'post_detail_$postId';
  }

  static String searchResultsWithQuery(String query) {
    return 'search_results_${query.hashCode}';
  }
}

/// Utility untuk memudahkan penggunaan di screens
class ScrollMemoryHelper {
  /// Wrap ListView dengan scroll memory
  static Widget listViewWithMemory({
    required String screenKey,
    required List<Widget> children,
    ScrollController? controller,
    EdgeInsets? padding,
    bool autoSave = true,
  }) {
    final scrollController = controller ?? ScrollController();

    return ScrollPositionManager.withScrollMemory(
      screenKey: screenKey,
      controller: scrollController,
      autoSave: autoSave,
      child: ListView.builder(
        controller: scrollController,
        padding: padding,
        itemCount: children.length,
        itemBuilder: (context, index) => children[index],
      ),
    );
  }

  /// Wrap GridView dengan scroll memory
  static Widget gridViewWithMemory({
    required String screenKey,
    required SliverGridDelegate gridDelegate,
    required List<Widget> children,
    ScrollController? controller,
    EdgeInsets? padding,
    bool autoSave = true,
  }) {
    final scrollController = controller ?? ScrollController();

    return ScrollPositionManager.withScrollMemory(
      screenKey: screenKey,
      controller: scrollController,
      autoSave: autoSave,
      child: GridView.builder(
        controller: scrollController,
        padding: padding,
        gridDelegate: gridDelegate,
        itemCount: children.length,
        itemBuilder: (context, index) => children[index],
      ),
    );
  }

  /// Wrap CustomScrollView dengan scroll memory
  static Widget customScrollViewWithMemory({
    required String screenKey,
    required List<Widget> slivers,
    ScrollController? controller,
    bool autoSave = true,
  }) {
    final scrollController = controller ?? ScrollController();

    return ScrollPositionManager.withScrollMemory(
      screenKey: screenKey,
      controller: scrollController,
      autoSave: autoSave,
      child: CustomScrollView(controller: scrollController, slivers: slivers),
    );
  }
}

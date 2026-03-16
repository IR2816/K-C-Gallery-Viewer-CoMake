import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/smart_cache_manager.dart';

/// Prinsip 7: Fitur kecil, dampak besar (tanpa biaya)
///
/// Ini high ROI UX:
/// ⭐ Bookmark creator
/// 🕘 Riwayat terakhir dibuka
/// 🔗 Copy link post
/// 👆 Double-tap zoom image
/// 🌙 Dark mode default (opsional)
///
/// Tidak berat, tapi terasa "niat".
class HighImpactFeatures extends StatefulWidget {
  final Widget child;

  const HighImpactFeatures({super.key, required this.child});

  @override
  State<HighImpactFeatures> createState() => _HighImpactFeaturesState();
}

class _HighImpactFeaturesState extends State<HighImpactFeatures> {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Bookmark manager untuk creators dan posts
class BookmarkManager {
  static const String _bookmarkedCreatorsKey = 'bookmarked_creators';
  static const String _bookmarkedPostsKey = 'bookmarked_posts';
  static SharedPreferences? _prefs;

  static Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Bookmark creator
  static Future<bool> bookmarkCreator({
    required String service,
    required String creatorId,
    required String creatorName,
    String? avatarUrl,
  }) async {
    await initialize();

    final creators = await getBookmarkedCreators();
    final creatorKey = '${service}_$creatorId';

    if (creators.containsKey(creatorKey)) {
      // Unbookmark
      creators.remove(creatorKey);
      await _saveBookmarkedCreators(creators);
      HapticFeedback.lightImpact();
      return false;
    } else {
      // Bookmark
      creators[creatorKey] = {
        'service': service,
        'creatorId': creatorId,
        'creatorName': creatorName,
        'avatarUrl': avatarUrl,
        'bookmarkedAt': DateTime.now().millisecondsSinceEpoch,
      };
      await _saveBookmarkedCreators(creators);
      HapticFeedback.mediumImpact();
      return true;
    }
  }

  /// Check if creator is bookmarked
  static Future<bool> isCreatorBookmarked({
    required String service,
    required String creatorId,
  }) async {
    await initialize();

    final creators = await getBookmarkedCreators();
    final creatorKey = '${service}_$creatorId';
    return creators.containsKey(creatorKey);
  }

  /// Get all bookmarked creators
  static Future<Map<String, Map<String, dynamic>>>
  getBookmarkedCreators() async {
    await initialize();

    final creatorsJson = _prefs?.getString(_bookmarkedCreatorsKey);
    if (creatorsJson == null) return {};

    try {
      final Map<String, dynamic> decoded = Map<String, dynamic>.from(
        Map<String, dynamic>.fromJson(creatorsJson),
      );

      // Convert to proper Map<String, Map<String, dynamic>>
      final creators = <String, Map<String, dynamic>>{};
      for (final entry in decoded.entries) {
        if (entry.value is Map<String, dynamic>) {
          creators[entry.key] = entry.value;
        }
      }
      return creators;
    } catch (e) {
      return {};
    }
  }

  /// Bookmark post
  static Future<bool> bookmarkPost({
    required String postId,
    required String title,
    required String creatorName,
    String? thumbnailUrl,
  }) async {
    await initialize();

    final posts = await getBookmarkedPosts();

    if (posts.containsKey(postId)) {
      // Unbookmark
      posts.remove(postId);
      await _saveBookmarkedPosts(posts);
      HapticFeedback.lightImpact();
      return false;
    } else {
      // Bookmark
      posts[postId] = {
        'postId': postId,
        'title': title,
        'creatorName': creatorName,
        'thumbnailUrl': thumbnailUrl,
        'bookmarkedAt': DateTime.now().millisecondsSinceEpoch,
      };
      await _saveBookmarkedPosts(posts);
      HapticFeedback.mediumImpact();
      return true;
    }
  }

  /// Check if post is bookmarked
  static Future<bool> isPostBookmarked(String postId) async {
    await initialize();

    final posts = await getBookmarkedPosts();
    return posts.containsKey(postId);
  }

  /// Get all bookmarked posts
  static Future<Map<String, Map<String, dynamic>>> getBookmarkedPosts() async {
    await initialize();

    final postsJson = _prefs?.getString(_bookmarkedPostsKey);
    if (postsJson == null) return {};

    try {
      final Map<String, dynamic> decoded = Map<String, dynamic>.from(
        Map<String, dynamic>.fromJson(postsJson),
      );

      final posts = <String, Map<String, dynamic>>{};
      for (final entry in decoded.entries) {
        if (entry.value is Map<String, dynamic>) {
          posts[entry.key] = entry.value;
        }
      }
      return posts;
    } catch (e) {
      return {};
    }
  }

  static Future<void> _saveBookmarkedCreators(
    Map<String, Map<String, dynamic>> creators,
  ) async {
    await _prefs?.setString(_bookmarkedCreatorsKey, creators.toString());
  }

  static Future<void> _saveBookmarkedPosts(
    Map<String, Map<String, dynamic>> posts,
  ) async {
    await _prefs?.setString(_bookmarkedPostsKey, posts.toString());
  }
}

/// History manager untuk recently viewed content
class HistoryManager {
  static const String _viewHistoryKey = 'view_history';
  static const int _maxHistoryItems = 50;
  static SharedPreferences? _prefs;

  static Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Add item to view history
  static Future<void> addToHistory({
    required String type, // 'post' or 'creator'
    required String id,
    required String title,
    String? subtitle,
    String? thumbnailUrl,
    Map<String, dynamic>? metadata,
  }) async {
    await initialize();

    final history = await getViewHistory();
    final itemKey = '${type}_$id';

    // Remove existing entry if present
    history.remove(itemKey);

    // Add new entry at the beginning
    history[itemKey] = {
      'type': type,
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'thumbnailUrl': thumbnailUrl,
      'metadata': metadata ?? {},
      'viewedAt': DateTime.now().millisecondsSinceEpoch,
    };

    // Limit history size
    if (history.length > _maxHistoryItems) {
      final sortedEntries = history.entries.toList()
        ..sort(
          (a, b) => (a.value['viewedAt'] as int).compareTo(
            b.value['viewedAt'] as int,
          ),
        );

      // Remove oldest entries
      final toRemove = sortedEntries.length - _maxHistoryItems;
      for (int i = 0; i < toRemove; i++) {
        history.remove(sortedEntries[i].key);
      }
    }

    await _saveHistory(history);
  }

  /// Get view history
  static Future<Map<String, Map<String, dynamic>>> getViewHistory() async {
    await initialize();

    final historyJson = _prefs?.getString(_viewHistoryKey);
    if (historyJson == null) return {};

    try {
      final Map<String, dynamic> decoded = Map<String, dynamic>.from(
        Map<String, dynamic>.fromJson(historyJson),
      );

      final history = <String, Map<String, dynamic>>{};
      for (final entry in decoded.entries) {
        if (entry.value is Map<String, dynamic>) {
          history[entry.key] = entry.value;
        }
      }
      return history;
    } catch (e) {
      return {};
    }
  }

  /// Get recently viewed posts
  static Future<List<Map<String, dynamic>>> getRecentPosts({
    int limit = 10,
  }) async {
    final history = await getViewHistory();

    final posts =
        history.entries
            .where((entry) => entry.value['type'] == 'post')
            .map((entry) => entry.value)
            .toList()
          ..sort(
            (a, b) => (b['viewedAt'] as int).compareTo(a['viewedAt'] as int),
          );

    return posts.take(limit).toList();
  }

  /// Get recently viewed creators
  static Future<List<Map<String, dynamic>>> getRecentCreators({
    int limit = 10,
  }) async {
    final history = await getViewHistory();

    final creators =
        history.entries
            .where((entry) => entry.value['type'] == 'creator')
            .map((entry) => entry.value)
            .toList()
          ..sort(
            (a, b) => (b['viewedAt'] as int).compareTo(a['viewedAt'] as int),
          );

    return creators.take(limit).toList();
  }

  /// Clear history
  static Future<void> clearHistory() async {
    await initialize();
    await _prefs?.remove(_viewHistoryKey);
  }

  static Future<void> _saveHistory(
    Map<String, Map<String, dynamic>> history,
  ) async {
    await _prefs?.setString(_viewHistoryKey, history.toString());
  }
}

/// Link sharing utility
class LinkSharingHelper {
  static void copyToClipboard(String text, {String? message}) {
    // TODO: Implement actual clipboard functionality
    HapticFeedback.lightImpact();

    // Show feedback
    ScaffoldMessenger.of(
      // This would need context, so for now we'll just print
      // Get the current context somehow or pass it in
      null as BuildContext,
    ).showSnackBar(
      SnackBar(
        content: Text(message ?? 'Link disalin!'),
        backgroundColor: AppTheme.successColor,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.smRadius),
        ),
      ),
    );
  }

  static void shareContent(String content, {String? subject}) {
    HapticFeedback.mediumImpact();

    // TODO: Implement actual sharing functionality
    // Share.share(content, subject: subject);
  }

  static void sharePost({
    required String postId,
    required String title,
    required String creatorName,
    String? url,
  }) {
    final shareText =
        '$title oleh $creatorName\n\n${url ?? 'https://example.com/post/$postId'}';
    shareContent(shareText, subject: title);
  }

  static void shareCreator({
    required String service,
    required String creatorId,
    required String creatorName,
    String? url,
  }) {
    final shareText =
        '$creatorName di $service\n\n${url ?? 'https://example.com/creator/$service/$creatorId'}';
    shareContent(shareText, subject: creatorName);
  }
}

/// Double-tap zoom handler untuk images
class DoubleTapZoomHandler extends StatefulWidget {
  final Widget child;
  final VoidCallback? onDoubleTap;
  final bool enableZoom;

  const DoubleTapZoomHandler({
    super.key,
    required this.child,
    this.onDoubleTap,
    this.enableZoom = true,
  });

  @override
  State<DoubleTapZoomHandler> createState() => _DoubleTapZoomHandlerState();
}

class _DoubleTapZoomHandlerState extends State<DoubleTapZoomHandler> {
  @override
  Widget build(BuildContext context) {
    if (!widget.enableZoom) {
      return widget.child;
    }

    return GestureDetector(onDoubleTap: _handleDoubleTap, child: widget.child);
  }

  void _handleDoubleTap() {
    HapticFeedback.mediumImpact();
    widget.onDoubleTap?.call();
  }
}

/// Quick action button dengan consistent behavior
class QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isActive;
  final Color? activeColor;
  final Color? inactiveColor;

  const QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.isActive = false,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final active = isActive ? activeColor ?? AppTheme.primaryColor : null;
    final inactive = inactiveColor ?? AppTheme.secondaryTextColor;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onPressed?.call();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.mdPadding),
            decoration: BoxDecoration(
              color: isActive
                  ? active?.withOpacity(0.2)
                  : AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.mdRadius),
              border: Border.all(
                color: isActive
                    ? (active ?? AppTheme.primaryColor)
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? (active ?? AppTheme.primaryColor) : inactive,
              size: 24,
            ),
          ),
          const SizedBox(height: AppTheme.xsSpacing),
          Text(
            label,
            style: AppTheme.captionStyle.copyWith(
              color: isActive ? (active ?? AppTheme.primaryColor) : inactive,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating quick actions widget
class FloatingQuickActions extends StatelessWidget {
  final List<QuickActionData> actions;
  final bool showLabels;

  const FloatingQuickActions({
    super.key,
    required this.actions,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppTheme.mdPadding),
      padding: const EdgeInsets.all(AppTheme.smPadding),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.lgRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: actions.map((action) => _buildAction(action)).toList(),
      ),
    );
  }

  Widget _buildAction(QuickActionData action) {
    return QuickActionButton(
      icon: action.icon,
      label: action.label,
      onPressed: action.onPressed,
      isActive: action.isActive,
      activeColor: action.activeColor,
    );
  }
}

class QuickActionData {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isActive;
  final Color? activeColor;

  QuickActionData({
    required this.icon,
    required this.label,
    this.onPressed,
    this.isActive = false,
    this.activeColor,
  });
}

/// Dark mode toggle dengan persistence
class DarkModeManager {
  static const String _darkModeKey = 'dark_mode_enabled';
  static SharedPreferences? _prefs;

  static Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<bool> isDarkModeEnabled() async {
    await initialize();
    return _prefs?.getBool(_darkModeKey) ?? true; // Default to dark mode
  }

  static Future<void> setDarkMode(bool enabled) async {
    await initialize();
    await _prefs?.setBool(_darkModeKey, enabled);
  }

  static Future<void> toggleDarkMode() async {
    final current = await isDarkModeEnabled();
    await setDarkMode(!current);
    HapticFeedback.lightImpact();
  }
}

/// User preferences manager
class UserPreferencesManager {
  static const String _prefix = 'user_pref_';
  static SharedPreferences? _prefs;

  static Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<void> setPreference(String key, dynamic value) async {
    await initialize();

    if (value is String) {
      await _prefs?.setString('$_prefix$key', value);
    } else if (value is int) {
      await _prefs?.setInt('$_prefix$key', value);
    } else if (value is bool) {
      await _prefs?.setBool('$_prefix$key', value);
    } else if (value is double) {
      await _prefs?.setDouble('$_prefix$key', value);
    }
  }

  static Future<T?> getPreference<T>(String key) async {
    await initialize();

    final value = _prefs?.get('$_prefix$key');
    return value as T?;
  }

  static Future<void> setVideoQuality(MediaQuality quality) async {
    await setPreference('video_quality', quality.index);
  }

  static Future<MediaQuality> getVideoQuality() async {
    final qualityIndex = await getPreference<int>('video_quality') ?? 0;
    return MediaQuality.values[qualityIndex];
  }

  static Future<void> setAutoPlay(bool enabled) async {
    await setPreference('auto_play', enabled);
  }

  static Future<bool> getAutoPlay() async {
    return await getPreference<bool>('auto_play') ?? false;
  }

  static Future<void> setImageQuality(String quality) async {
    await setPreference('image_quality', quality);
  }

  static Future<String> getImageQuality() async {
    return await getPreference<String>('image_quality') ?? 'high';
  }
}

enum MediaQuality { auto, low, medium, high, original }

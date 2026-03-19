import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TagFilterProvider with ChangeNotifier {
  final Set<String> _blacklist = {};
  static const String _blacklistKey = 'tag_blacklist';

  Set<String> get blacklist => Set.unmodifiable(_blacklist);

  /// Initialize provider and load blacklist from storage
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedBlacklist = prefs.getStringList(_blacklistKey) ?? [];
      _blacklist.clear();
      _blacklist.addAll(savedBlacklist.map((tag) => tag.toLowerCase().trim()));
      notifyListeners();
      debugPrint('TagFilterProvider: Loaded ${_blacklist.length} blocked tags');
    } catch (e) {
      debugPrint('TagFilterProvider: Failed to load blacklist - $e');
    }
  }

  /// Add tag to blacklist
  Future<void> addToBlacklist(String tag) async {
    final normalizedTag = tag.toLowerCase().trim();
    if (normalizedTag.isNotEmpty && !_blacklist.contains(normalizedTag)) {
      _blacklist.add(normalizedTag);
      await _saveBlacklist();
      notifyListeners();
      debugPrint('TagFilterProvider: Added tag to blacklist: $normalizedTag');
    }
  }

  /// Remove tag from blacklist
  Future<void> removeFromBlacklist(String tag) async {
    final normalizedTag = tag.toLowerCase().trim();
    if (_blacklist.remove(normalizedTag)) {
      await _saveBlacklist();
      notifyListeners();
      debugPrint(
        'TagFilterProvider: Removed tag from blacklist: $normalizedTag',
      );
    }
  }

  /// Clear all blocked tags
  Future<void> clearBlacklist() async {
    if (_blacklist.isNotEmpty) {
      _blacklist.clear();
      await _saveBlacklist();
      notifyListeners();
      debugPrint('TagFilterProvider: Cleared all blocked tags');
    }
  }

  /// Check if post should be blocked based on tags
  bool isPostBlocked(List<String> postTags) {
    if (_blacklist.isEmpty || postTags.isEmpty) return false;

    return postTags.any((tag) {
      final normalizedTag = tag.toLowerCase().trim();
      return _blacklist.contains(normalizedTag);
    });
  }

  /// Filter posts that are not blocked
  List<T> filterPosts<T>(List<T> posts, List<String> Function(T) getTags) {
    if (_blacklist.isEmpty) return posts;

    return posts.where((post) {
      final postTags = getTags(post);
      return !isPostBlocked(postTags);
    }).toList();
  }

  /// Get blocked count for a list of posts
  int getBlockedCount<T>(List<T> posts, List<String> Function(T) getTags) {
    if (_blacklist.isEmpty) return 0;

    return posts.where((post) {
      final postTags = getTags(post);
      return isPostBlocked(postTags);
    }).length;
  }

  /// Check if a specific tag is blocked
  bool isTagBlocked(String tag) {
    final normalizedTag = tag.toLowerCase().trim();
    return _blacklist.contains(normalizedTag);
  }

  /// Save blacklist to persistent storage
  Future<void> _saveBlacklist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_blacklistKey, _blacklist.toList());
    } catch (e) {
      debugPrint('TagFilterProvider: Failed to save blacklist - $e');
    }
  }

  /// Get all blocked tags as sorted list
  List<String> getSortedBlacklist() {
    final sorted = List<String>.from(_blacklist);
    sorted.sort();
    return sorted;
  }

  /// Get statistics about blocked tags
  Map<String, dynamic> getStatistics() {
    return {
      'totalBlocked': _blacklist.length,
      'blockedTags': getSortedBlacklist(),
    };
  }
}

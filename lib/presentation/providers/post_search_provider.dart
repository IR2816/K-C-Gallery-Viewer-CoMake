import 'package:flutter/foundation.dart';
import '../../domain/entities/post.dart';
import '../../utils/logger.dart';

/// Post Search Provider - handles post search by title and tag filtering
class PostSearchProvider extends ChangeNotifier {
  String _searchQuery = '';
  final List<String> _selectedTagFilters = [];
  List<Post> _searchResults = [];
  final bool _isSearching = false;
  String? _error;

  // Getters
  String get searchQuery => _searchQuery;
  List<String> get selectedTagFilters => List.unmodifiable(_selectedTagFilters);
  List<Post> get searchResults => _searchResults;
  bool get isSearching => _isSearching;
  String? get error => _error;
  int get resultCount => _searchResults.length;

  /// Set search query and update results
  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    _error = null;
    notifyListeners();
  }

  /// Toggle a tag filter (add/remove)
  void toggleTagFilter(String tag) {
    if (_selectedTagFilters.contains(tag)) {
      _selectedTagFilters.remove(tag);
    } else {
      _selectedTagFilters.add(tag);
    }
    notifyListeners();
  }

  /// Clear all tag filters
  void clearTagFilters() {
    _selectedTagFilters.clear();
    notifyListeners();
  }

  /// Clear all search (query + tag filters)
  void clearSearch() {
    _searchQuery = '';
    _selectedTagFilters.clear();
    _searchResults.clear();
    _error = null;
    notifyListeners();
  }

  /// Filter posts based on search query and tag filters
  /// [posts] - list of posts to filter
  /// [blacklistedTags] - tags to exclude
  /// Returns filtered list of posts
  List<Post> getFilteredPosts(
    List<Post> posts, {
    List<String> blacklistedTags = const [],
  }) {
    try {
      if (posts.isEmpty) {
        _searchResults = [];
        return [];
      }

      final filtered = posts.where((post) {
        // Title search (case-insensitive, substring)
        if (_searchQuery.isNotEmpty) {
          if (!post.title.toLowerCase().contains(_searchQuery.toLowerCase())) {
            return false;
          }
        }

        // Tag whitelist filter - if any tags selected, post must have at least one
        if (_selectedTagFilters.isNotEmpty) {
          final postTagsLower =
              post.tags.map((t) => t.toLowerCase()).toSet();
          final selectedLower =
              _selectedTagFilters.map((t) => t.toLowerCase()).toSet();

          // Check if post has any of the selected tags
          if (!postTagsLower.any((tag) => selectedLower.contains(tag))) {
            return false;
          }
        }

        // Tag blacklist filter - exclude posts with blacklisted tags
        if (blacklistedTags.isNotEmpty) {
          final postTagsLower =
              post.tags.map((t) => t.toLowerCase()).toList();
          final blacklistedLower =
              blacklistedTags.map((t) => t.toLowerCase()).toSet();

          if (blacklistedLower.any((tag) => postTagsLower.contains(tag))) {
            return false;
          }
        }

        return true;
      }).toList();

      _searchResults = filtered;
      _error = null;
      return filtered;
    } catch (e) {
      AppLogger.error(
        'Error filtering posts: $e',
        tag: 'PostSearch',
      );
      _error = e.toString();
      _searchResults = [];
      return [];
    }
  }
}

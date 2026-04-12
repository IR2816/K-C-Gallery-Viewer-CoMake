import 'package:flutter/foundation.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/api_source.dart';
import '../../domain/repositories/kemono_repository.dart';
import '../../utils/logger.dart';
import 'settings_provider.dart';

/// Post Search Provider - handles post search by title/tag filtering (local)
/// and server-side keyword search with pagination.
class PostSearchProvider extends ChangeNotifier {
  final KemonoRepository repository;
  final SettingsProvider settingsProvider;

  PostSearchProvider({
    required this.repository,
    required this.settingsProvider,
  });

  static const int _searchPageSize = 50;

  // Local filter state
  String _searchQuery = '';
  final List<String> _selectedTagFilters = [];
  List<Post> _searchResults = [];
  String? _error;

  // Server-side search state
  List<Post> _serverSearchResults = [];
  int _searchOffset = 0;
  bool _searchHasMore = true;
  bool _isSearchingServer = false;
  bool _isLoadingMoreSearch = false;
  String? _serverSearchError;

  // Getters – local filter
  String get searchQuery => _searchQuery;
  List<String> get selectedTagFilters => List.unmodifiable(_selectedTagFilters);
  List<Post> get searchResults => _searchResults;
  bool get isSearching => _isSearchingServer;
  String? get error => _error;
  int get resultCount => _serverSearchResults.isNotEmpty
      ? _serverSearchResults.length
      : _searchResults.length;

  // Getters – server search
  List<Post> get serverSearchResults => _serverSearchResults;
  bool get isLoadingMoreSearch => _isLoadingMoreSearch;
  bool get searchHasMore => _searchHasMore;
  String? get serverSearchError => _serverSearchError;

  /// Set search query (for local-filter compatibility kept for other callers).
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

  /// Clear all search state (local + server).
  void clearSearch() {
    _searchQuery = '';
    _selectedTagFilters.clear();
    _searchResults.clear();
    _error = null;
    _serverSearchResults = [];
    _searchOffset = 0;
    _searchHasMore = true;
    _isSearchingServer = false;
    _isLoadingMoreSearch = false;
    _serverSearchError = null;
    notifyListeners();
  }

  /// Perform a server-side search for [query].
  ///
  /// Pass [refresh] = true to start from offset 0.
  /// [apiSource] defaults to [settingsProvider.defaultApiSource].
  Future<void> performServerSearch(
    String query, {
    bool refresh = true,
    ApiSource? apiSource,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      clearSearch();
      return;
    }

    if (_isSearchingServer) return;

    if (refresh) {
      _serverSearchResults = [];
      _searchOffset = 0;
      _searchHasMore = true;
      _serverSearchError = null;
    }

    _searchQuery = trimmed;
    _isSearchingServer = true;
    _serverSearchError = null;
    notifyListeners();

    try {
      final effectiveApiSource = apiSource ?? settingsProvider.defaultApiSource;
      final newPosts = await repository.searchPosts(
        trimmed,
        offset: _searchOffset,
        limit: _searchPageSize,
        apiSource: effectiveApiSource,
      );

      if (newPosts.isEmpty) {
        _searchHasMore = false;
      } else {
        _serverSearchResults.addAll(newPosts);
        _searchOffset += newPosts.length;
        _searchHasMore = newPosts.length >= _searchPageSize;
      }
      _serverSearchError = null;
    } catch (e) {
      _serverSearchError = 'Search failed: ${e.toString()}';
      AppLogger.error(
        'PostSearchProvider: server search error: $e',
        tag: 'PostSearch',
      );
    } finally {
      _isSearchingServer = false;
      notifyListeners();
    }
  }

  /// Load the next page of server-side search results (infinite scroll).
  Future<void> loadMoreSearchResults({ApiSource? apiSource}) async {
    if (_isLoadingMoreSearch || _isSearchingServer || !_searchHasMore) return;
    if (_searchQuery.isEmpty) return;

    _isLoadingMoreSearch = true;
    _serverSearchError = null;
    notifyListeners();

    try {
      final effectiveApiSource = apiSource ?? settingsProvider.defaultApiSource;
      final newPosts = await repository.searchPosts(
        _searchQuery,
        offset: _searchOffset,
        limit: _searchPageSize,
        apiSource: effectiveApiSource,
      );

      if (newPosts.isEmpty) {
        _searchHasMore = false;
      } else {
        _serverSearchResults.addAll(newPosts);
        _searchOffset += newPosts.length;
        _searchHasMore = newPosts.length >= _searchPageSize;
      }
      _serverSearchError = null;
    } catch (e) {
      _serverSearchError = 'Failed to load more results: ${e.toString()}';
      AppLogger.error(
        'PostSearchProvider: load more error: $e',
        tag: 'PostSearch',
      );
    } finally {
      _isLoadingMoreSearch = false;
      notifyListeners();
    }
  }

  /// Filter posts based on search query and tag filters (local, for other screens).
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
          final postTagsLower = post.tags.map((t) => t.toLowerCase()).toSet();
          final selectedLower = _selectedTagFilters
              .map((t) => t.toLowerCase())
              .toSet();

          // Check if post has any of the selected tags
          if (!postTagsLower.any((tag) => selectedLower.contains(tag))) {
            return false;
          }
        }

        // Tag blacklist filter - exclude posts with blacklisted tags
        if (blacklistedTags.isNotEmpty) {
          final postTagsLower = post.tags.map((t) => t.toLowerCase()).toList();
          final blacklistedLower = blacklistedTags
              .map((t) => t.toLowerCase())
              .toSet();

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
      AppLogger.error('Error filtering posts: $e', tag: 'PostSearch');
      _error = e.toString();
      _searchResults = [];
      return [];
    }
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/api_source.dart';
import '../../domain/entities/post.dart';
import '../providers/post_search_provider.dart';
import '../providers/posts_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tag_filter_provider.dart';
import '../../utils/logger.dart';

/// One-shot domain-switch transition event surfaced to the UI.
///
/// The UI consumes this (calls [LatestPostsController.consumeDomainTransition])
/// after showing the animation overlay.
typedef DomainTransition = ({String from, String to});

/// Controller for the Feed / Latest-Posts screen.
///
/// All business logic (loading, pagination, filtering, settings-change
/// reaction, search debouncing) lives here.  The UI layer only:
///   - renders widgets driven by the exposed state getters, and
///   - calls the public action methods.
class LatestPostsController extends ChangeNotifier {
  final PostsProvider _postsProvider;
  final SettingsProvider _settingsProvider;
  final TagFilterProvider _tagFilterProvider;
  final PostSearchProvider _postSearchProvider;

  // ── Loading state ────────────────────────────────────────────────────────
  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMore = true;
  bool isSwitchingSource = false;
  String? error;

  // ── Filter / display state ───────────────────────────────────────────────
  String selectedService;
  List<String> blockedTags;
  int gridAnimationEpoch = 0;

  // ── Domain-transition event (consumed by UI to show overlay) ─────────────
  DomainTransition? pendingDomainTransition;

  // ── Internal ─────────────────────────────────────────────────────────────
  String _lastKnownKemonoDomain;
  String _lastKnownCoomerDomain;

  // Search debounce
  Timer? _searchDebounce;
  bool isSearchDebouncing = false;
  static const _searchDebounceDelay = Duration(milliseconds: 500);

  LatestPostsController({
    required PostsProvider postsProvider,
    required SettingsProvider settingsProvider,
    required TagFilterProvider tagFilterProvider,
    required PostSearchProvider postSearchProvider,
  }) : _postsProvider = postsProvider,
       _settingsProvider = settingsProvider,
       _tagFilterProvider = tagFilterProvider,
       _postSearchProvider = postSearchProvider,
       selectedService = settingsProvider.defaultApiSource.name,
       blockedTags = tagFilterProvider.blacklist.toList(),
       _lastKnownKemonoDomain = settingsProvider.cleanKemonoDomain,
       _lastKnownCoomerDomain = settingsProvider.cleanCoomerDomain {
    _settingsProvider.addListener(_onSettingsChanged);
    _tagFilterProvider.addListener(_onTagsChanged);
    _postSearchProvider.addListener(_onSearchProviderChanged);

    // Kick off the first load immediately.
    loadInitial();
  }

  @override
  void dispose() {
    _settingsProvider.removeListener(_onSettingsChanged);
    _tagFilterProvider.removeListener(_onTagsChanged);
    _postSearchProvider.removeListener(_onSearchProviderChanged);
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ── Computed getters ─────────────────────────────────────────────────────

  ApiSource get currentApiSource =>
      ApiSource.values.firstWhere((a) => a.name == selectedService);

  bool get isInSearchMode => _postSearchProvider.searchQuery.isNotEmpty;

  /// Posts from the feed, filtered by NSFW/tag-blacklist/local-search rules.
  List<Post> get filteredPosts => _applyFilters(_postsProvider.latestPosts);

  // Forward search-provider state so widgets only need one provider.
  List<Post> get searchResults => _postSearchProvider.serverSearchResults;
  bool get isSearching => _postSearchProvider.isSearching;
  bool get isLoadingMoreSearch => _postSearchProvider.isLoadingMoreSearch;
  bool get searchHasMore => _postSearchProvider.searchHasMore;
  String? get searchError => _postSearchProvider.serverSearchError;
  String get searchQuery => _postSearchProvider.searchQuery;

  int get searchResultCount => _postSearchProvider.serverSearchResults.length;

  // ── Public actions ────────────────────────────────────────────────────────

  /// Load (or refresh) the first page of latest posts.
  Future<void> loadInitial() async {
    if (isLoading) return;
    isLoading = true;
    error = null;
    hasMore = true;
    isLoadingMore = false;
    notifyListeners();

    try {
      AppLogger.debug(
        '🔍 LatestPostsController.loadInitial – API: $currentApiSource',
      );
      await _postsProvider.loadLatestPosts(
        refresh: true,
        apiSource: currentApiSource,
      );
      hasMore = _postsProvider.latestPostsHasMore;
      error = null;
    } catch (e) {
      error = e.toString();
      AppLogger.error(
        '🔍 LatestPostsController.loadInitial error: $e',
        tag: 'LatestPostsController',
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Load the next page of latest posts (infinite scroll).
  Future<void> loadMore() async {
    if (isLoadingMore || !hasMore || isLoading) return;
    isLoadingMore = true;
    notifyListeners();

    try {
      await _postsProvider.loadMoreLatestPosts();
      hasMore = _postsProvider.latestPostsHasMore;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Load more server-search results (infinite scroll in search mode).
  void loadMoreSearch() {
    if (_postSearchProvider.isLoadingMoreSearch ||
        _postSearchProvider.isSearching ||
        !_postSearchProvider.searchHasMore)
      return;
    _postSearchProvider.loadMoreSearchResults(apiSource: currentApiSource);
  }

  /// Debounced search trigger called on every keystroke.
  void onSearchQueryChanged(String query) {
    isSearchDebouncing = query.isNotEmpty;
    notifyListeners();
    _searchDebounce?.cancel();

    if (query.trim().isEmpty) {
      _postSearchProvider.clearSearch();
      isSearchDebouncing = false;
      notifyListeners();
      return;
    }

    _searchDebounce = Timer(_searchDebounceDelay, () => _doSearch(query));
  }

  /// Immediate search (on keyboard "search" key).
  void submitSearch(String query) {
    _searchDebounce?.cancel();
    isSearchDebouncing = false;
    notifyListeners();
    if (query.trim().isNotEmpty) {
      _doSearch(query);
    }
  }

  /// Clear the current search query and results.
  void clearSearch() {
    _searchDebounce?.cancel();
    _postSearchProvider.clearSearch();
    isSearchDebouncing = false;
    notifyListeners();
  }

  /// Call after the UI has displayed [pendingDomainTransition].
  void consumeDomainTransition() {
    pendingDomainTransition = null;
    // No notify – the overlay has already been shown.
  }

  // ── Internal listeners ────────────────────────────────────────────────────

  void _onSearchProviderChanged() => notifyListeners();

  void _onTagsChanged() {
    blockedTags = _tagFilterProvider.blacklist.toList();
    notifyListeners();
  }

  Future<void> _onSettingsChanged() async {
    final settingsApiSource = _settingsProvider.defaultApiSource;
    // Compare against the API source used for the *feed* (latestPostsApiSource),
    // NOT currentApiSource.  currentApiSource is also overwritten whenever
    // creator or search posts are loaded, so using it here caused spurious feed
    // reloads after visiting a creator whose service lives on a different source
    // (e.g. an OnlyFans creator triggering a "coomer" source, then any setting
    // change triggering _onSettingsChanged would incorrectly detect a mismatch).
    final currentFeedApiSource = _postsProvider.latestPostsApiSource;
    final shouldReload =
        currentFeedApiSource == null ||
        currentFeedApiSource != settingsApiSource;

    if (shouldReload) {
      if (isSwitchingSource) return;

      isSwitchingSource = true;
      selectedService = settingsApiSource.name;
      blockedTags = _tagFilterProvider.blacklist.toList();
      _postSearchProvider.clearSearch();
      notifyListeners();

      AppLogger.debug(
        '🔍 LatestPostsController: API source changed → ${settingsApiSource.name}',
      );
      HapticFeedback.lightImpact();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      await loadInitial();

      isSwitchingSource = false;
      gridAnimationEpoch++;
      _lastKnownKemonoDomain = _settingsProvider.cleanKemonoDomain;
      _lastKnownCoomerDomain = _settingsProvider.cleanCoomerDomain;
      notifyListeners();
    } else {
      // API source unchanged – check for domain URL change.
      final oldKemono = _lastKnownKemonoDomain;
      final oldCoomer = _lastKnownCoomerDomain;
      final domainChanged =
          _settingsProvider.cleanKemonoDomain != oldKemono ||
          _settingsProvider.cleanCoomerDomain != oldCoomer;

      _lastKnownKemonoDomain = _settingsProvider.cleanKemonoDomain;
      _lastKnownCoomerDomain = _settingsProvider.cleanCoomerDomain;
      blockedTags = _tagFilterProvider.blacklist.toList();

      if (domainChanged) {
        // Surface the transition event; UI will show the animation overlay.
        // In this branch currentFeedApiSource == settingsApiSource (no source
        // switch), so use currentFeedApiSource to convey the "before" state.
        final fromDomain = currentFeedApiSource == ApiSource.kemono
            ? oldKemono
            : oldCoomer;
        final toDomain = settingsApiSource == ApiSource.kemono
            ? _settingsProvider.cleanKemonoDomain
            : _settingsProvider.cleanCoomerDomain;
        pendingDomainTransition = (from: fromDomain, to: toDomain);

        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        gridAnimationEpoch++;
        notifyListeners();
        await loadInitial();
      } else {
        notifyListeners();
      }
    }
  }

  // ── Filtering ─────────────────────────────────────────────────────────────

  List<Post> _applyFilters(List<Post> posts) {
    final hideNsfw = _settingsProvider.hideNsfw;
    final hasTags = blockedTags.isNotEmpty;

    List<Post> filtered = posts;
    if (hideNsfw || hasTags) {
      filtered = posts.where((post) {
        if (hideNsfw && _isNsfwPost(post)) return false;
        if (!hasTags) return true;
        final lowerPostTags = post.tags.map((t) => t.toLowerCase()).toList();
        return !blockedTags.any(
          (blocked) => lowerPostTags.any((tag) => tag.contains(blocked)),
        );
      }).toList();
    }

    return _postSearchProvider.getFilteredPosts(
      filtered,
      blacklistedTags: blockedTags,
    );
  }

  bool _isNsfwPost(Post post) {
    if (post.tags.isEmpty) return false;
    return post.tags.any((tag) {
      final lower = tag.toLowerCase();
      return lower.contains('nsfw') ||
          lower.contains('r18') ||
          lower.contains('adult') ||
          lower.contains('explicit') ||
          lower.contains('18+');
    });
  }

  void _doSearch(String query) {
    _postSearchProvider.performServerSearch(
      query,
      refresh: true,
      apiSource: currentApiSource,
    );
    isSearchDebouncing = false;
    notifyListeners();
  }
}

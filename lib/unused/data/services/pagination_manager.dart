import 'package:flutter/foundation.dart' show debugPrint;
import '../models/post_model.dart';
import '../models/creator_model.dart';
import '../../domain/entities/api_source.dart';
import 'kemono_api.dart';

/// Prinsip 2: Client bertanggung jawab atas UX - Pagination Manager
///
/// API tidak memiliki state, client yang mengatur:
/// - Cache hasil
/// - Pagination logic
/// - Refresh manual
class PaginationManager<T> {
  final List<T> _items = [];
  int _currentPage = 0;
  final int _pageSize;
  bool _isLoading = false;
  bool _hasReachedEnd = false;
  String? _lastQuery;
  ApiSource _lastApiSource = ApiSource.kemono;

  PaginationManager({int pageSize = 50}) : _pageSize = pageSize;

  // Getters
  List<T> get items => List.unmodifiable(_items);
  int get currentPage => _currentPage;
  int get pageSize => _pageSize;
  bool get isLoading => _isLoading;
  bool get hasReachedEnd => _hasReachedEnd;
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;
  int get itemCount => _items.length;

  /// Reset pagination untuk query baru
  void reset({String? query, ApiSource? apiSource}) {
    debugPrint('PaginationManager: Resetting pagination');
    _items.clear();
    _currentPage = 0;
    _hasReachedEnd = false;
    _lastQuery = query;
    if (apiSource != null) {
      _lastApiSource = apiSource;
    }
  }

  /// Load next page dengan error handling
  Future<List<T>> loadNextPage(
    Future<List<T>> Function(int offset, int limit) fetchFunction, {
    String? query,
    ApiSource? apiSource,
  }) async {
    if (_isLoading || _hasReachedEnd) {
      debugPrint(
        'PaginationManager: Skipping load - loading:$_isLoading, reachedEnd:$_hasReachedEnd',
      );
      return [];
    }

    _isLoading = true;
    debugPrint('PaginationManager: Loading page $_currentPage');

    try {
      final newItems = await fetchFunction(_currentPage * _pageSize, _pageSize);

      if (newItems.isEmpty || newItems.length < _pageSize) {
        _hasReachedEnd = true;
        debugPrint('PaginationManager: Reached end of data');
      }

      _items.addAll(newItems);
      _currentPage++;

      debugPrint(
        'PaginationManager: Loaded ${newItems.length} items, total: ${_items.length}',
      );
      return newItems;
    } catch (e) {
      debugPrint('PaginationManager: Error loading page - $e');
      // Prinsip 5: Error handling - jangan crash UI
      rethrow;
    } finally {
      _isLoading = false;
    }
  }

  /// Refresh data (replace existing)
  Future<List<T>> refresh(
    Future<List<T>> Function(int offset, int limit) fetchFunction, {
    String? query,
    ApiSource? apiSource,
  }) async {
    debugPrint('PaginationManager: Refreshing data');
    reset(query: query, apiSource: apiSource);
    return await loadNextPage(
      fetchFunction,
      query: query,
      apiSource: apiSource,
    );
  }

  /// Add single item (untuk bookmark/save)
  void addItem(T item) {
    if (!_items.contains(item)) {
      _items.insert(0, item);
      debugPrint('PaginationManager: Added item to cache');
    }
  }

  /// Remove item
  bool removeItem(T item) {
    final removed = _items.remove(item);
    if (removed) {
      debugPrint('PaginationManager: Removed item from cache');
    }
    return removed;
  }

  /// Clear cache
  void clear() {
    debugPrint('PaginationManager: Clearing cache');
    _items.clear();
    _currentPage = 0;
    _hasReachedEnd = false;
  }

  /// Get item by index dengan bounds checking
  T? getItem(int index) {
    if (index >= 0 && index < _items.length) {
      return _items[index];
    }
    return null;
  }

  /// Check if need to load more (untuk infinite scroll)
  bool shouldLoadMore(int scrollIndex) {
    final threshold = _items.length - (_pageSize ~/ 2);
    return !_hasReachedEnd &&
        !_isLoading &&
        scrollIndex >= threshold &&
        _items.isNotEmpty;
  }
}

/// Specialized pagination untuk posts
class PostPaginationManager extends PaginationManager<PostModel> {
  PostPaginationManager({super.pageSize});

  /// Load posts untuk creator
  Future<List<PostModel>> loadCreatorPosts(
    String service,
    String userId, {
    ApiSource apiSource = ApiSource.kemono,
    bool refresh = false,
  }) async {
    debugPrint('PostPaginationManager: Loading posts for $service:$userId');

    if (refresh) {
      return await refresh(
        (offset, limit) =>
            _fetchCreatorPosts(service, userId, offset, limit, apiSource),
        apiSource: apiSource,
      );
    } else {
      return await loadNextPage(
        (offset, limit) =>
            _fetchCreatorPosts(service, userId, offset, limit, apiSource),
        apiSource: apiSource,
      );
    }
  }

  /// Load recent posts
  Future<List<PostModel>> loadRecentPosts({
    ApiSource apiSource = ApiSource.kemono,
    bool refresh = false,
  }) async {
    debugPrint('PostPaginationManager: Loading recent posts');

    if (refresh) {
      return await refresh(
        (offset, limit) => _fetchRecentPosts(offset, limit, apiSource),
        apiSource: apiSource,
      );
    } else {
      return await loadNextPage(
        (offset, limit) => _fetchRecentPosts(offset, limit, apiSource),
        apiSource: apiSource,
      );
    }
  }

  Future<List<PostModel>> _fetchCreatorPosts(
    String service,
    String userId,
    int offset,
    int limit,
    ApiSource apiSource,
  ) async {
    return await KemonoApi.getCreatorPosts(
      service,
      userId,
      offset: offset,
      limit: limit,
      apiSource: apiSource,
    );
  }

  Future<List<PostModel>> _fetchRecentPosts(
    int offset,
    int limit,
    ApiSource apiSource,
  ) async {
    return await KemonoApi.getRecentPosts(
      offset: offset,
      limit: limit,
      apiSource: apiSource,
    );
  }
}

/// Specialized pagination untuk creators
class CreatorPaginationManager extends PaginationManager<CreatorModel> {
  CreatorPaginationManager({super.pageSize});

  /// Search creators by name (secondary feature)
  Future<List<CreatorModel>> searchCreators(
    String query, {
    ApiSource apiSource = ApiSource.kemono,
    String? service,
    bool refresh = false,
  }) async {
    debugPrint('CreatorPaginationManager: Searching creators - $query');

    if (refresh) {
      return await refresh(
        (offset, limit) =>
            _searchCreators(query, offset, limit, apiSource, service),
        query: query,
        apiSource: apiSource,
      );
    } else {
      return await loadNextPage(
        (offset, limit) =>
            _searchCreators(query, offset, limit, apiSource, service),
        query: query,
        apiSource: apiSource,
      );
    }
  }

  Future<List<CreatorModel>> _searchCreators(
    String query,
    int offset,
    int limit,
    ApiSource apiSource,
    String? service,
  ) async {
    return await KemonoApi.searchCreatorsByName(
      query,
      apiSource: apiSource,
      service: service,
    );
  }
}

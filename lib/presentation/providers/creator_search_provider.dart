import 'package:flutter/material.dart';
import '../services/creator_index_manager.dart';
import '../../data/services/creator_search_service.dart';
import '../../data/models/creator_index_item.dart';
import '../../data/models/creator_search_result.dart';
import '../../domain/entities/api_source.dart';
import '../../domain/entities/creator.dart';
import '../../utils/logger.dart';

class CreatorSearchProvider extends ChangeNotifier {
  final CreatorIndexManager manager;

  bool _loading = false;
  bool _preparing = false;
  bool _isInitialized = false;
  List<CreatorIndexItem> _results = [];
  final List<CreatorIndexItem> _popularCreators = [];
  List<CreatorSearchResult> _nameSearchResults = [];
  String _currentQuery = '';
  String? _error;
  ApiSource _currentApiSource = ApiSource.kemono;

  CreatorSearchProvider(this.manager);

  // Getters
  bool get loading => _loading;
  bool get preparing => _preparing;
  bool get isInitialized => _isInitialized;
  List<CreatorIndexItem> get results => _results;
  List<CreatorIndexItem> get popularCreators => _popularCreators;
  List<CreatorSearchResult> get nameSearchResults => _nameSearchResults;
  String get currentQuery => _currentQuery;
  String? get error => _error;
  ApiSource get currentApiSource => _currentApiSource;
  bool get isReady => false; // Always false since we don't use index anymore
  int get indexSize => 0; // Always 0 since we don't use index anymore
  bool get hasNameSearchResults => _nameSearchResults.isNotEmpty;

  /// Prepare index for the specified API source - DISABLED
  Future<void> prepareIndex(ApiSource apiSource) async {
    // Index preparation is disabled since we use mbaharip API
    AppLogger.info(
      'Index preparation disabled - using mbaharip API instead',
      tag: 'CreatorSearch',
    );
    _preparing = false;
    notifyListeners();
  }

  /// Search creators by name - DISABLED (use searchCreatorsByName instead)
  void search(String query) {
    // Legacy search method is disabled - use searchCreatorsByName for mbaharip API
    AppLogger.warning(
      'Legacy search disabled - use searchCreatorsByName instead',
      tag: 'CreatorSearch',
    );
    _results = [];
    notifyListeners();
  }

  /// Clear search results
  void clearSearch() {
    _currentQuery = '';
    _results = [];
    _error = null;
    notifyListeners();
  }

  /// Switch API source and prepare new index - DISABLED
  Future<void> switchApiSource(ApiSource apiSource) async {
    // Index switching is disabled since we don't use index anymore
    AppLogger.info(
      'Index switching disabled - using mbaharip API instead',
      tag: 'CreatorSearch',
    );
    _currentApiSource = apiSource;
    notifyListeners();
  }

  /// Initialize provider - skip index download since we use mbaharip API
  Future<void> initialize() async {
    AppLogger.info(
      'Initializing CreatorSearchProvider (index download disabled)',
      tag: 'CreatorSearch',
    );

    // Skip index download since we now use mbaharip API for name search
    // Index is no longer needed for the new search system
    _isInitialized = true;
    notifyListeners();

    AppLogger.info(
      'CreatorSearchProvider initialized successfully (index disabled)',
      tag: 'CreatorSearch',
    );
  }

  /// Get creator by exact match - DISABLED
  CreatorIndexItem? findByServiceAndId(String service, String userId) {
    // Legacy method disabled since we don't use index anymore
    AppLogger.warning(
      'findByServiceAndId disabled - index not available',
      tag: 'CreatorSearch',
    );
    return null;
  }

  /// Retry preparation - DISABLED
  Future<void> retry() async {
    // Retry is disabled since we don't use index anymore
    AppLogger.info(
      'Retry disabled - using mbaharip API instead',
      tag: 'CreatorSearch',
    );
    _error = null;
    notifyListeners();
  }

  /// Search creators by name using mbaharip API (as resolver only)
  Future<void> searchCreatorsByName(String query, ApiSource apiSource) async {
    AppLogger.debug(
      '🔍 DEBUG: searchCreatorsByName called with query: "$query", apiSource: ${apiSource.name}',
    );

    if (query.trim().isEmpty) return;

    _loading = true;
    _error = null;
    _currentQuery = query;
    _currentApiSource = apiSource;
    _nameSearchResults.clear();
    notifyListeners();

    try {
      AppLogger.info(
        'Searching creators by name: "$query" for ${apiSource.name}',
        tag: 'CreatorSearch',
      );

      final serviceName = apiSource.name.toLowerCase();
      AppLogger.debug(
        '🔍 DEBUG: Calling CreatorSearchService.searchCreatorsByName with serviceName: $serviceName',
      );
      final results = await CreatorSearchService.searchCreatorsByName(
        query,
        serviceName,
      );
      AppLogger.debug('🔍 DEBUG: Got ${results.length} results from API');

      // Limit results to prevent overwhelming UI
      _nameSearchResults = results.take(5).toList();
      AppLogger.info(
        'Found ${results.length} creators by name (limited to ${_nameSearchResults.length})',
        tag: 'CreatorSearch',
      );
      AppLogger.debug('🔍 DEBUG: Final results count: ${_nameSearchResults.length}');
      AppLogger.debug(
        '🔍 DEBUG: _nameSearchResults list: ${_nameSearchResults.map((r) => r.name).toList()}',
      );
    } catch (e) {
      _error = e.toString();
      AppLogger.error(
        'Failed to search creators by name',
        tag: 'CreatorSearch',
        error: e,
      );
      AppLogger.debug('🔍 DEBUG: Error in search: $e');
    } finally {
      _loading = false;
      AppLogger.debug(
        '🔍 DEBUG: Before notifyListeners - _nameSearchResults.length: ${_nameSearchResults.length}',
      );
      notifyListeners();
      AppLogger.debug(
        '🔍 DEBUG: After notifyListeners - _nameSearchResults.length: ${_nameSearchResults.length}',
      );
      AppLogger.debug(
        '🔍 DEBUG: searchCreatorsByName completed, loading: $_loading, error: $_error',
      );
    }
  }

  /// Clear name search results
  void clearNameSearchResults() {
    _nameSearchResults.clear();
    _currentQuery = '';
    _error = null;
    notifyListeners();
  }

  /// Convert search result to Creator entity
  Creator? searchResultToCreator(CreatorSearchResult result) {
    return result.toCreator();
  }

  /// Get statistics
  Map<String, dynamic> getStats() {
    return {
      'isReady': false, // Always false since we don't use index
      'indexSize': 0, // Always 0 since we don't use index
      'currentApiSource': _currentApiSource.name,
      'currentQuery': _currentQuery,
      'resultsCount': _results.length, // Legacy results (always 0)
      'popularCount': _popularCreators.length, // Legacy popular (always 0)
      'nameSearchResultsCount':
          _nameSearchResults.length, // Active results from mbaharip
      'hasError': _error != null,
      'isInitialized': _isInitialized,
      'usingMbaharipApi': true, // New flag to indicate we use mbaharip API
    };
  }
}

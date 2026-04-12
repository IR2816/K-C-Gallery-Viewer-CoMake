import 'package:flutter/foundation.dart';
import '../../domain/repositories/kemono_repository.dart';
import '../../domain/entities/creator.dart';
import '../../domain/entities/api_source.dart';
import 'settings_provider.dart';
import '../services/creator_index_manager.dart';
import '../../data/services/creator_search_service.dart';
import '../../data/models/creator_index_item.dart';
import '../../data/models/creator_search_result.dart';
import '../../utils/logger.dart';

/// Unified provider that consolidates CreatorSearchProvider and CreatorsProvider
/// - Handles Kemono API operations for creator data (loadCreators, searchCreators, favorites)
/// - Handles mbaharip API operations for name search (searchCreatorsByName)
/// - Manages both legacy index state and modern search functionality
class CreatorsProvider with ChangeNotifier {
  final KemonoRepository repository;
  final SettingsProvider settingsProvider;
  final CreatorIndexManager?
  indexManager; // Optional, for backward compatibility

  CreatorsProvider({
    required this.repository,
    required this.settingsProvider,
    this.indexManager,
  });

  // ==================== Kemono API State ====================
  List<Creator> _creators = [];
  bool _isLoading = false;
  String? _error;
  String? _selectedService;
  Set<String> _favoriteCreators = {};

  // ==================== mbaharip API State ====================
  bool _preparing = false;
  bool _isInitialized = false;
  List<CreatorIndexItem> _results = [];
  final List<CreatorIndexItem> _popularCreators = [];
  List<CreatorSearchResult> _nameSearchResults = [];
  String _currentQuery = '';
  ApiSource _currentApiSource = ApiSource.kemono;

  // ==================== Kemono API Getters ====================
  List<Creator> get creators => _creators;
  bool get isLoading => _isLoading;
  bool get loading =>
      _isLoading; // Alias for backward compatibility with mbaharip API
  String? get error => _error;
  String? get selectedService => _selectedService;
  List<String> get favoriteCreators => _favoriteCreators.toList();

  // ==================== mbaharip API Getters ====================
  bool get preparing => _preparing;
  bool get isInitialized => _isInitialized;
  List<CreatorIndexItem> get results => _results;
  List<CreatorIndexItem> get popularCreators => _popularCreators;
  List<CreatorSearchResult> get nameSearchResults => _nameSearchResults;
  String get currentQuery => _currentQuery;
  ApiSource get currentApiSource => _currentApiSource;
  bool get isReady => false; // Always false since we don't use index
  int get indexSize => 0; // Always 0 since we don't use index
  bool get hasNameSearchResults => _nameSearchResults.isNotEmpty;

  // ==================== Kemono API Methods ====================

  Future<void> loadCreators({String? service}) async {
    _isLoading = true;
    _error = null;
    _selectedService = service;
    notifyListeners();

    try {
      _creators = await repository.getCreators(
        service: service,
        apiSource: settingsProvider.defaultApiSource,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
      _creators = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchCreators(
    String query, {
    ApiSource apiSource = ApiSource.kemono,
    String? service,
  }) async {
    final trimmedQuery = query.trim();
    final isNumericId = RegExp(r'^\d+$').hasMatch(trimmedQuery);
    final isAllService = service == null || service.isEmpty || service == 'all';
    if (isNumericId && isAllService) {
      _isLoading = false;
      _selectedService = service;
      _creators = [];
      _error =
          'Numeric ID search requires selecting a specific service (e.g. Patreon/OnlyFans). Please pick a service and retry.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    _selectedService = service;
    notifyListeners();

    try {
      _creators = await repository.searchCreators(
        trimmedQuery,
        apiSource: apiSource,
        service: service,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
      _creators = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadFavorites() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _creators = await repository.getFavoriteCreators();
      _favoriteCreators = _creators.map((c) => c.id).toSet();
      _error = null;
    } catch (e) {
      _error = e.toString();
      _creators = [];
      _favoriteCreators = {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(Creator creator) async {
    try {
      final isCurrentlyFavorited = _favoriteCreators.contains(creator.id);

      if (isCurrentlyFavorited) {
        // Remove from favorites
        await repository.removeFavoriteCreator(
          creator.id,
          service: creator.service,
        );
        _favoriteCreators.remove(creator.id);

        // Remove from creators list if it's currently loaded
        _creators.removeWhere((c) => c.id == creator.id);
      } else {
        // Add to favorites
        await repository.saveFavoriteCreator(creator);
        _favoriteCreators.add(creator.id);

        // Add to creators list if it's currently loaded and not already present
        final index = _creators.indexWhere((c) => c.id == creator.id);
        if (index == -1) {
          _creators.insert(0, creator.copyWith(favorited: true));
        } else {
          // Update existing creator in the list
          _creators[index] = _creators[index].copyWith(favorited: true);
        }
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearCreators() {
    _creators.clear();
    _error = null;
    notifyListeners();
  }

  /// Get specific creator details
  Future<Creator?> getCreatorDetails(
    String service,
    String creatorId, {
    ApiSource apiSource = ApiSource.kemono,
  }) async {
    try {
      return await repository.getCreator(
        service,
        creatorId,
        apiSource: apiSource,
      );
    } catch (e) {
      _error = e.toString();
      return null;
    }
  }

  // ==================== mbaharip API Methods ====================

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
      'Initializing CreatorsProvider (index download disabled)',
      tag: 'CreatorSearch',
    );

    // Skip index download since we now use mbaharip API for name search
    // Index is no longer needed for the new search system
    _isInitialized = true;
    notifyListeners();

    AppLogger.info(
      'CreatorsProvider initialized successfully (index disabled)',
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

  /// Search creators by name using mbaharip API
  Future<void> searchCreatorsByName(String query, ApiSource apiSource) async {
    AppLogger.debug(
      '🔍 DEBUG: searchCreatorsByName called with query: "$query", apiSource: ${apiSource.name}',
    );

    if (query.trim().isEmpty) return;

    _isLoading = true;
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
      AppLogger.debug(
        '🔍 DEBUG: Final results count: ${_nameSearchResults.length}',
      );
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
      _isLoading = false;
      AppLogger.debug(
        '🔍 DEBUG: Before notifyListeners - _nameSearchResults.length: ${_nameSearchResults.length}',
      );
      notifyListeners();
      AppLogger.debug(
        '🔍 DEBUG: After notifyListeners - _nameSearchResults.length: ${_nameSearchResults.length}',
      );
      AppLogger.debug(
        '🔍 DEBUG: searchCreatorsByName completed, loading: $_isLoading, error: $_error',
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

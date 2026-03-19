import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/entities/creator.dart';
import '../../domain/entities/api_source.dart';

/// Provider for managing popular creators state
class PopularCreatorsProvider extends ChangeNotifier {
  PopularCreatorsProvider();

  // State variables
  List<Creator> _popularCreators = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  ApiSource _currentService = ApiSource.kemono;
  int _currentPage = 1;
  bool _hasMorePages = true;
  int _totalItems = 0;

  // Getters
  List<Creator> get popularCreators => _popularCreators;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  ApiSource get currentService => _currentService;
  bool get hasMorePages => _hasMorePages;
  int get totalItems => _totalItems;

  /// Load popular creators for current service
  Future<void> loadPopularCreators({bool refresh = false}) async {
    if (refresh) {
      _popularCreators.clear();
      _currentPage = 1;
      _hasMorePages = true;
      _totalItems = 0;
    }

    if (_popularCreators.isNotEmpty && !refresh) {
      return; // Already loaded
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint(
        'PopularCreatorsProvider: Loading popular creators for service: $_currentService',
      );

      // Load first page from the kemono-api.mbaharip.com API
      final result = await _getPopularCreatorsFromApi(
        _currentService,
        _currentPage,
      );

      _popularCreators = result['creators'] as List<Creator>;
      _hasMorePages = result['hasMorePages'] as bool;
      _totalItems = result['totalItems'] as int;
      _error = null;

      debugPrint(
        'PopularCreatorsProvider: Loaded ${_popularCreators.length} popular creators (Page $_currentPage/${_hasMorePages ? 'more' : 'last'})',
      );
    } catch (e) {
      debugPrint(
        'PopularCreatorsProvider: Error loading popular creators - $e',
      );
      _error = e.toString();
      _popularCreators = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load more popular creators (infinite scroll)
  Future<void> loadMorePopularCreators() async {
    if (_isLoadingMore || !_hasMorePages || _isLoading) {
      return;
    }

    _isLoadingMore = true;
    notifyListeners();

    try {
      debugPrint(
        'PopularCreatorsProvider: Loading more popular creators (Page ${_currentPage + 1})',
      );

      _currentPage++;
      final result = await _getPopularCreatorsFromApi(
        _currentService,
        _currentPage,
      );

      final newCreators = result['creators'] as List<Creator>;
      _popularCreators.addAll(newCreators);
      _hasMorePages = result['hasMorePages'] as bool;

      debugPrint(
        'PopularCreatorsProvider: Loaded ${newCreators.length} more creators. Total: ${_popularCreators.length}',
      );
    } catch (e) {
      debugPrint(
        'PopularCreatorsProvider: Error loading more popular creators - $e',
      );
      _currentPage--; // Revert page number on error
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Get popular creators from kemono-api.mbaharip.com with pagination
  Future<Map<String, dynamic>> _getPopularCreatorsFromApi(
    ApiSource apiSource,
    int page,
  ) async {
    final String apiUrl = apiSource == ApiSource.kemono
        ? 'https://kemono-api.mbaharip.com/kemono?page=$page'
        : 'https://kemono-api.mbaharip.com/coomer?page=$page';

    debugPrint('PopularCreatorsProvider: Fetching from $apiUrl');

    final response = await http
        .get(
          Uri.parse(apiUrl),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load popular creators: ${response.statusCode}',
      );
    }

    final Map<String, dynamic> jsonResponse = json.decode(response.body);

    if (jsonResponse['message'] != 'OK') {
      throw Exception('API returned error: ${jsonResponse['message']}');
    }

    final List<dynamic> data = jsonResponse['data'] ?? [];
    final Map<String, dynamic> pagination = jsonResponse['pagination'] ?? {};

    final creators = data.map((item) {
      final Map<String, dynamic> creatorData = item as Map<String, dynamic>;

      return Creator(
        id: creatorData['id']?.toString() ?? '',
        service: creatorData['service']?.toString() ?? '',
        name: creatorData['name']?.toString() ?? 'Unknown',
        indexed: creatorData['indexed'] as int? ?? 0,
        updated: creatorData['updated'] as int? ?? 0,
        favorited: false, // We'll handle favorites separately
        avatar: '', // API doesn't provide avatar, will use fallback
        bio: 'Popular creator with ${creatorData['favorited'] ?? 0} favorites',
        fans: creatorData['favorited'] as int?,
        followed: false,
      );
    }).toList();

    return {
      'creators': creators,
      'hasMorePages': pagination['isNextPage'] ?? false,
      'totalItems': pagination['totalItems'] ?? 0,
      'currentPage': pagination['currentPage'] ?? page,
      'totalPages': pagination['totalPages'] ?? 1,
    };
  }

  /// Switch service and reload popular creators
  Future<void> switchService(ApiSource service) async {
    if (_currentService == service) return;

    debugPrint(
      'PopularCreatorsProvider: Switching service from $_currentService to $service',
    );
    _currentService = service;
    // Reset pagination state
    _currentPage = 1;
    _hasMorePages = true;
    _totalItems = 0;
    await loadPopularCreators(refresh: true);
  }

  /// Refresh popular creators
  Future<void> refresh() async {
    await loadPopularCreators(refresh: true);
  }

  /// Clear popular creators
  void clearPopularCreators() {
    _popularCreators.clear();
    _error = null;
    notifyListeners();
  }
}

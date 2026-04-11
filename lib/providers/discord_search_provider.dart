import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../domain/entities/discord_server.dart';
import '../presentation/providers/async_load_mixin.dart';
import '../presentation/providers/data_usage_dio_interceptor.dart';
import '../presentation/providers/data_usage_tracker.dart';

/// Discord Search Provider untuk mengelola pencarian Discord servers
/// Uses mbaharip API for search, Kemono API for data retrieval
class DiscordSearchProvider with ChangeNotifier, AsyncLoadMixin {
  late final Dio _dio;

  // State
  List<DiscordServer> _searchResults = [];
  List<DiscordServer> _popularServers = [];
  bool _isLoading = false;
  String? _error;
  String _currentQuery = '';

  // Getters
  List<DiscordServer> get searchResults => _searchResults;
  List<DiscordServer> get popularServers => _popularServers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get currentQuery => _currentQuery;
  bool get hasResults => _searchResults.isNotEmpty;
  bool get hasQuery => _currentQuery.isNotEmpty;

  DiscordSearchProvider({DataUsageTracker? dataUsageTracker}) {
    _dio = Dio();
    _dio.options.baseUrl = 'https://kemono-api.mbaharip.com';
    _dio.options.headers = {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    };
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);
    if (dataUsageTracker != null) {
      _dio.interceptors.add(DataUsageDioInterceptor(dataUsageTracker));
    }
  }


  /// Load popular Discord servers using mbaharip API
  /// GET /kemono/discord (no keyword)
  Future<void> loadPopularServers() async {
    await runAsync(
      () async {
        _error = null;

        final response = await _dio.get(
          '/kemono/discord',
          options: Options(
            validateStatus: (status) {
              return status != null && status < 600;
            },
          ),
        );

        if (response.statusCode == 503) {
          _error =
              'Search service temporarily unavailable. Please try again later.';
          _popularServers = [];
          return;
        }

        if (response.statusCode != null &&
            response.statusCode! >= 200 &&
            response.statusCode! < 300) {
          final dynamic data = response.data;
          List<dynamic> serversData = [];

          if (data is List) {
            serversData = data;
          } else if (data is Map<String, dynamic>) {
            if (data['results'] is List) {
              serversData = data['results'] as List;
            } else if (data['data'] is List) {
              serversData = data['data'] as List;
            }
          }

          _popularServers = serversData
              .whereType<Map<String, dynamic>>()
              .where(
                (json) => json['service']?.toString().toLowerCase() == 'discord',
              )
              .map(
                (json) => DiscordServer(
                  id: json['id']?.toString() ?? '',
                  name: json['name']?.toString() ?? '',
                  indexed: DateTime.fromMillisecondsSinceEpoch(
                    (json['indexed'] ?? 0) * 1000,
                  ),
                  updated: DateTime.fromMillisecondsSinceEpoch(
                    (json['updated'] ?? 0) * 1000,
                  ),
                ),
              )
              .toList();
        } else {
          _error = 'Search failed: ${response.statusCode}';
          _popularServers = [];
        }
      },
      setLoading: _setLoading,
      onError: (e, _) {
        if (e.toString().contains('503')) {
          _error =
              'Search service temporarily unavailable. Please try again later.';
        } else if (e.toString().contains('SocketException')) {
          _error = 'Network error. Please check your connection.';
        } else {
          _error = 'Search error: $e';
        }
        _popularServers = [];
      },
    );
  }

  /// Search Discord servers using mbaharip API
  /// GET /kemono/discord?keyword={query}
  Future<void> searchServers(String query) async {
    if (query.trim().isEmpty) {
      _clearResults();
      return;
    }

    _currentQuery = query.trim();

    await runAsync(
      () async {
        _error = null;

        final response = await _dio.get(
          '/kemono/discord',
          queryParameters: {'keyword': _currentQuery},
          options: Options(
            validateStatus: (status) {
              return status != null && status < 600;
            },
          ),
        );

        if (response.statusCode == 503) {
          _error =
              'Search service temporarily unavailable. Please try again later.';
          _searchResults = [];
          return;
        }

        if (response.statusCode != null &&
            response.statusCode! >= 200 &&
            response.statusCode! < 300) {
          final dynamic data = response.data;
          List<dynamic> serversData = [];

          if (data is List) {
            serversData = data;
          } else if (data is Map<String, dynamic>) {
            if (data['results'] is List) {
              serversData = data['results'] as List;
            } else if (data['data'] is List) {
              serversData = data['data'] as List;
            }
          }

          debugPrint(
            'DiscordSearchProvider: Found ${serversData.length} servers for query: $_currentQuery',
          );

          _searchResults = serversData
              .whereType<Map<String, dynamic>>()
              .where(
                (json) => json['service']?.toString().toLowerCase() == 'discord',
              )
              .map(
                (json) => DiscordServer(
                  id: json['id']?.toString() ?? '',
                  name: json['name']?.toString() ?? '',
                  indexed: DateTime.fromMillisecondsSinceEpoch(
                    (json['indexed'] ?? 0) * 1000,
                  ),
                  updated: DateTime.fromMillisecondsSinceEpoch(
                    (json['updated'] ?? 0) * 1000,
                  ),
                ),
              )
              .toList();

          debugPrint(
            'DiscordSearchProvider: Filtered to ${_searchResults.length} Discord servers',
          );
        } else {
          _error = 'Search failed: ${response.statusCode}';
          _searchResults = [];
        }
      },
      setLoading: _setLoading,
      onError: (e, _) {
        debugPrint('DiscordSearchProvider error: $e');
        if (e.toString().contains('503')) {
          _error =
              'Search service temporarily unavailable. Please try again later.';
        } else if (e.toString().contains('SocketException')) {
          _error = 'Network error. Please check your connection.';
        } else {
          _error = 'Search error: $e';
        }
        _searchResults = [];
      },
    );
  }

  /// Clear search results
  void _clearResults() {
    _searchResults.clear();
    _currentQuery = '';
    _error = null;
    notifyListeners();
  }

  /// Reset search
  void reset() {
    _clearResults();
    _setLoading(false);
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Retry search with current query
  Future<void> retry() async {
    if (_currentQuery.isNotEmpty) {
      await searchServers(_currentQuery);
    }
  }

  /// Get search suggestions (mock implementation)
  List<String> getSearchSuggestions() {
    const suggestions = [
      'vtuber',
      'fanbox',
      'patreon',
      'onlyfans',
      'discord',
      'art',
      'anime',
      'manga',
      'cosplay',
      'gaming',
    ];

    return suggestions
        .where(
          (suggestion) =>
              suggestion.toLowerCase().contains(_currentQuery.toLowerCase()),
        )
        .toList();
  }

  /// Dispose Dio instance
  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }
}

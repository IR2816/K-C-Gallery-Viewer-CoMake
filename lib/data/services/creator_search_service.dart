import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/entities/creator.dart';
import '../models/creator_search_result.dart';
import '../../utils/logger.dart';

/// Service for searching creators by name using mbaharip API
class CreatorSearchService {
  static const String _kemonoBaseUrl = 'https://kemono-api.mbaharip.com/kemono';
  static const String _coomerBaseUrl = 'https://kemono-api.mbaharip.com/coomer';

  /// Search creators by name using keyword parameter
  static Future<List<CreatorSearchResult>> searchCreatorsByName(
    String query,
    String service,
  ) async {
    AppLogger.debug('🔍 DEBUG: CreatorSearchService.searchCreatorsByName called');
    AppLogger.debug('🔍 DEBUG: query: "$query", service: "$service"');

    try {
      final baseUrl = service.toLowerCase() == 'coomer'
          ? _coomerBaseUrl
          : _kemonoBaseUrl;
      final url = '$baseUrl?keyword=${Uri.encodeComponent(query)}';

      AppLogger.debug('🔍 DEBUG: Final URL: $url');

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'User-Agent': 'KC-Gallery-Viewer/1.0',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      AppLogger.debug('🔍 DEBUG: Response status code: ${response.statusCode}');
      AppLogger.debug('🔍 DEBUG: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.debug('🔍 DEBUG: Parsed JSON data: $data');
        return _parseSearchResults(data);
      } else {
        throw Exception('Failed to search creators: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.debug('🔍 DEBUG: Exception in searchCreatorsByName: $e');
      throw Exception('Search service unavailable: $e');
    }
  }

  /// Parse search results from API response
  static List<CreatorSearchResult> _parseSearchResults(dynamic data) {
    AppLogger.debug(
      '🔍 DEBUG: _parseSearchResults called with data type: ${data.runtimeType}',
    );

    final List<CreatorSearchResult> results = [];

    // Handle the actual response format from mbaharip API
    if (data is Map<String, dynamic>) {
      AppLogger.debug('🔍 DEBUG: Data is Map, keys: ${data.keys}');

      // Check for 'data' field (the actual results array)
      if (data['data'] is List) {
        final dataList = data['data'] as List;
        AppLogger.debug('🔍 DEBUG: Found data array with ${dataList.length} items');

        // Limit results to prevent overwhelming the UI
        final limitedData = dataList.take(10).toList();
        AppLogger.debug('🔍 DEBUG: Limited to ${limitedData.length} items');

        for (int i = 0; i < limitedData.length; i++) {
          final item = limitedData[i];
          AppLogger.debug('🔍 DEBUG: Processing item $i: $item');

          if (item is Map<String, dynamic>) {
            try {
              final result = CreatorSearchResult.fromJson(item);
              results.add(result);
              AppLogger.debug('🔍 DEBUG: Successfully parsed item $i');
            } catch (e) {
              AppLogger.debug('🔍 DEBUG: Failed to parse item $i: $e');
              // Skip invalid items but continue processing others
              continue;
            }
          }
        }
      } else {
        AppLogger.debug('🔍 DEBUG: No data array found in response');
      }
    } else {
      AppLogger.debug('🔍 DEBUG: Data is not a Map, type: ${data.runtimeType}');
    }

    AppLogger.debug('🔍 DEBUG: Final parsed results count: ${results.length}');
    return results;
  }

  /// Get creator details by ID (for validation)
  static Future<Creator?> getCreatorDetails(
    String service,
    String creatorId,
  ) async {
    try {
      final baseUrl = service.toLowerCase() == 'coomer'
          ? _coomerBaseUrl
          : _kemonoBaseUrl;
      final url = '$baseUrl/creators/$creatorId';

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'User-Agent': 'KC-Gallery-Viewer/1.0',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseCreatorDetails(data);
      }
    } catch (e) {
      // Silently fail for validation
    }

    return null;
  }

  /// Parse creator details from API response
  static Creator? _parseCreatorDetails(dynamic data) {
    if (data is Map<String, dynamic>) {
      return Creator(
        id: data['id']?.toString() ?? '',
        name: data['name']?.toString() ?? '',
        service: data['service']?.toString() ?? '',
        indexed: data['indexed'] ?? 0,
        updated: data['updated'] ?? 0,
        favorited: data['favorited'] ?? false,
        avatar: data['avatar']?.toString() ?? '',
        bio: data['bio']?.toString() ?? '',
        fans: data['fans'],
        followed: data['followed'] ?? false,
      );
    }
    return null;
  }
}
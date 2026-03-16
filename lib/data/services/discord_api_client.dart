import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../domain/entities/discord_server.dart';
import '../../domain/entities/discord_channel.dart';
import '../../data/models/post_model.dart';

/// 🚀 Discord API Client - Isolated from Kemono API
///
/// Responisble for Discord-specific API calls only
/// Uses official Kemono API endpoints with proper headers
class DiscordApiClient {
  final Dio _dio;

  DiscordApiClient(this._dio);

  /// Lookup Discord channels by server ID
  /// GET /v1/discord/channel/lookup/{discord_server}
  Future<List<DiscordChannel>> lookupChannels(String serverId) async {
    try {
      final response = await _dio.get(
        'https://kemono.cr/api/v1/discord/channel/lookup/$serverId',
        options: Options(
          headers: {
            'Accept': 'text/css', // WAJIB untuk Discord API
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
          validateStatus: (status) {
            // Allow 503 to handle manually
            return status != null && status < 600;
          },
        ),
      );

      // Handle 503 Service Unavailable
      if (response.statusCode == 503) {
        throw Exception('Kemono Discord is temporarily unavailable (503)');
      }

      final data = response.data;
      List<dynamic> channelsData = [];

      // Handle different response formats
      if (data is Map<String, dynamic> && data['channels'] is List) {
        channelsData = data['channels'] as List;
      } else if (data is List) {
        channelsData = data;
      } else {
        return [];
      }

      // Log response for debugging
      debugPrint(
        'DiscordApiClient lookupChannels: statusCode=${response.statusCode}, channelCount=${channelsData.length}',
      );

      final channels = channelsData
          .whereType<Map<String, dynamic>>()
          .map(
            (e) => DiscordChannel(
              id: e['id']?.toString() ?? '',
              serverId: e['server_id']?.toString() ?? serverId,
              name: e['name']?.toString() ?? '',
              parentId: e['parent_channel_id']?.toString(),
              isNsfw: e['is_nsfw'] ?? false,
              type: e['type'] ?? 11,
              position: e['position'] ?? 0,
              postCount: e['post_count'] ?? 0,
              emoji: e['icon_emoji']?.toString(),
            ),
          )
          .toList();

      // Sort by position
      channels.sort((a, b) => a.position.compareTo(b.position));

      return channels;
    } catch (e) {
      debugPrint('DiscordApiClient lookupChannels error: $e');
      throw Exception('Failed to lookup channels for server $serverId: $e');
    }
  }

  /// Load posts from a Discord channel
  /// GET /v1/discord/channel/{channel_id}?offset=0
  Future<List<PostModel>> loadChannelPosts(
    String channelId, {
    int offset = 0,
  }) async {
    debugPrint(
      '🔍 DEBUG: DiscordApiClient.loadChannelPosts - ChannelId: $channelId, Offset: $offset',
    );

    try {
      final url = 'https://kemono.cr/api/v1/discord/channel/$channelId';
      debugPrint('🔍 DEBUG: MAKING REQUEST TO: $url?offset=$offset');

      final response = await _dio.get(
        url,
        queryParameters: {'offset': offset},
        options: Options(
          headers: {
            'Accept': 'text/css', // WAJIB untuk Discord API
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
          validateStatus: (status) {
            // Allow 503 to handle manually
            return status != null && status < 600;
          },
        ),
      );

      debugPrint('🔍 DEBUG: RESPONSE STATUS: ${response.statusCode}');
      debugPrint('🔍 DEBUG: RESPONSE TYPE: ${response.data.runtimeType}');

      // Handle 503 Service Unavailable
      if (response.statusCode == 503) {
        debugPrint('🔍 DEBUG: 503 ERROR - SERVICE UNAVAILABLE');
        throw Exception('Kemono Discord is temporarily unavailable (503)');
      }

      final data = response.data;
      List<dynamic> postsData = [];

      // Handle different response formats
      if (data is Map<String, dynamic>) {
        if (data['results'] is List) {
          postsData = data['results'] as List;
        } else if (data['data'] is List) {
          postsData = data['data'] as List;
        }
      } else if (data is List) {
        postsData = data;
      } else if (data is String) {
        // Try to parse string as JSON
        try {
          final parsed = jsonDecode(data);
          if (parsed is Map<String, dynamic>) {
            if (parsed['results'] is List) {
              postsData = parsed['results'] as List;
            } else if (parsed['data'] is List) {
              postsData = parsed['data'] as List;
            }
          } else if (parsed is List) {
            postsData = parsed;
          }
        } catch (e) {
          debugPrint('🔍 DEBUG: FAILED TO PARSE STRING RESPONSE: $e');
          throw Exception('Failed to parse response as JSON: $e');
        }
      }

      debugPrint('🔍 DEBUG: PARSED ${postsData.length} POSTS FROM RESPONSE');

      // Log response for debugging
      debugPrint(
        'DiscordApiClient loadChannelPosts: statusCode=${response.statusCode}, postCount=${postsData.length}',
      );

      final posts = postsData
          .whereType<Map<String, dynamic>>()
          .map((json) => PostModel.fromJson(json))
          .toList();

      debugPrint('🔍 DEBUG: CREATED ${posts.length} POSTMODEL OBJECTS');

      return posts;
    } catch (e) {
      debugPrint('🔍 DEBUG: DiscordApiClient loadChannelPosts ERROR: $e');
      throw Exception('Failed to load posts for channel $channelId: $e');
    }
  }

  /// Get Discord servers list
  /// GET /v1/discord/server
  Future<List<DiscordServer>> getServers() async {
    try {
      final response = await _dio.get(
        'https://kemono.cr/api/v1/discord/server',
        options: Options(
          headers: {
            'Accept': 'text/css', // WAJIB untuk Discord API
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
          validateStatus: (status) {
            // Allow 503 to handle manually, don't throw immediately
            return status != null && status < 600;
          },
        ),
      );

      // Handle 503 Service Unavailable
      if (response.statusCode == 503) {
        throw Exception('Kemono Discord is temporarily unavailable (503)');
      }

      final data = response.data;
      List<dynamic> serversData = [];

      // Handle different response formats
      if (data is Map<String, dynamic>) {
        if (data['servers'] is List) {
          serversData = data['servers'] as List;
        } else if (data['results'] is List) {
          serversData = data['results'] as List;
        }
      } else if (data is List) {
        serversData = data;
      }

      // Log response for debugging
      debugPrint(
        'DiscordApiClient getServers: statusCode=${response.statusCode}, dataCount=${serversData.length}',
      );

      final servers = serversData
          .whereType<Map<String, dynamic>>()
          .map(
            (e) => DiscordServer(
              id: e['id']?.toString() ?? '',
              name: e['name']?.toString() ?? '',
              indexed:
                  DateTime.tryParse(e['indexed']?.toString() ?? '') ??
                  DateTime.now(),
              updated:
                  DateTime.tryParse(e['updated']?.toString() ?? '') ??
                  DateTime.now(),
            ),
          )
          .toList();

      return servers;
    } catch (e) {
      debugPrint('DiscordApiClient getServers error: $e');
      throw Exception('Failed to load Discord servers: $e');
    }
  }

  /// Get Discord server with channel tree
  /// GET /v1/discord/server/{server_id}
  Future<Map<String, dynamic>> getServerWithChannels(String serverId) async {
    try {
      final response = await _dio.get(
        'https://kemono.cr/api/v1/discord/server/$serverId',
        options: Options(
          headers: {
            'Accept': 'text/css', // WAJIB untuk Discord API
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
          validateStatus: (status) {
            // Allow 503 to handle manually
            return status != null && status < 600;
          },
        ),
      );

      // Handle 503 Service Unavailable
      if (response.statusCode == 503) {
        throw Exception('Kemono Discord is temporarily unavailable (503)');
      }

      final data = response.data;

      // Log response for debugging
      debugPrint(
        'DiscordApiClient getServerWithChannels: statusCode=${response.statusCode}',
      );
      debugPrint(
        'DiscordApiClient getServerWithChannels: dataType=${data.runtimeType}',
      );
      debugPrint(
        'DiscordApiClient getServerWithChannels: dataPreview=${data.toString().substring(0, data.toString().length > 200 ? 200 : data.toString().length)}',
      );

      // Handle different response formats
      Map<String, dynamic> serverData = {};

      if (data is Map<String, dynamic>) {
        serverData = data;
      } else if (data is String) {
        // Try to parse string as JSON
        try {
          final parsed = jsonDecode(data);
          if (parsed is Map<String, dynamic>) {
            serverData = parsed;
          } else {
            throw Exception('Parsed JSON is not a Map: ${parsed.runtimeType}');
          }
        } catch (e) {
          throw Exception(
            'Failed to parse response as JSON: $e\nRaw response: ${data.substring(0, 200)}...',
          );
        }
      } else {
        throw Exception(
          'Invalid response format: expected Map or String, got ${data.runtimeType}',
        );
      }

      return serverData;
    } catch (e) {
      debugPrint('DiscordApiClient getServerWithChannels error: $e');
      throw Exception('Failed to load server $serverId: $e');
    }
  }
}

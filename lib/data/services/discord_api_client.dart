import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/discord_channel.dart';
import '../../domain/entities/discord_server.dart';
import '../../utils/api_logger.dart';
import '../../utils/logger.dart';
import '../exceptions/api_exceptions.dart';
import '../models/post_model.dart';
import 'api_header_service.dart';
import 'http_retry_strategy.dart';
import 'network_connectivity_service.dart';

/// Discord API Client - isolated for Discord endpoints only.
class DiscordApiClient {
  final Dio _dio;
  final HttpRetryStrategy _retryStrategy;
  final NetworkConnectivityService _connectivityService;

  /// Base API URL (e.g. `https://kemono.cr/api`).
  final String baseUrl;

  int _consecutiveFailures = 0;
  DateTime? _circuitOpenUntil;

  static const int _breakerThreshold = 3;
  static const Duration _breakerCooldown = Duration(seconds: 30);
  static const int _responseSnippetMaxLength = 200;

  DiscordApiClient(
    this._dio, {
    this.baseUrl = 'https://kemono.cr/api',
    HttpRetryStrategy? retryStrategy,
    NetworkConnectivityService? connectivityService,
  }) : _retryStrategy = retryStrategy ??
           HttpRetryStrategy(
             policy: const RetryPolicy(
               maxAttempts: 3,
               initialTimeout: Duration(seconds: 30),
               retryTimeout: Duration(seconds: 15),
               baseDelay: Duration(seconds: 1),
               maxDelay: Duration(seconds: 4),
             ),
           ),
       _connectivityService = connectivityService ??
           NetworkConnectivityService.instance {
    _connectivityService.initialize();
  }

  bool get _isCircuitOpen {
    final until = _circuitOpenUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  void _markSuccess() {
    _consecutiveFailures = 0;
    _circuitOpenUntil = null;
  }

  void _markFailure() {
    _consecutiveFailures += 1;
    if (_consecutiveFailures >= _breakerThreshold) {
      _circuitOpenUntil = DateTime.now().add(_breakerCooldown);
    }
  }

  ApiException _mapDioException(
    Object error, {
    required String endpoint,
    required String requestId,
    StackTrace? stackTrace,
  }) {
    if (error is ApiException) return error;
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return RequestTimeoutException(
            message: 'Discord API request timed out.',
            endpoint: endpoint,
            requestId: requestId,
            cause: error,
            stackTrace: stackTrace,
          );
        case DioExceptionType.connectionError:
        case DioExceptionType.unknown:
          return NetworkRequestException(
            message: 'Discord network error: ${error.message}',
            endpoint: endpoint,
            requestId: requestId,
            cause: error,
            stackTrace: stackTrace,
          );
        case DioExceptionType.badResponse:
          return HttpStatusException(
            message: 'Discord API returned status ${statusCode ?? 0}.',
            statusCode: statusCode ?? 0,
            endpoint: endpoint,
            requestId: requestId,
            cause: error,
            stackTrace: stackTrace,
          );
        default:
          return NetworkRequestException(
            message: 'Discord request failed: ${error.message}',
            endpoint: endpoint,
            requestId: requestId,
            cause: error,
            stackTrace: stackTrace,
          );
      }
    }
    return mapToApiException(
      error,
      endpoint: endpoint,
      requestId: requestId,
      stackTrace: stackTrace,
    );
  }

  Future<Response<dynamic>> _get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final requestId = ApiLogger.nextRequestId();
    final fullUrl = '$baseUrl$endpoint';

    if (_isCircuitOpen) {
      throw CircuitBreakerOpenException(
        retryAfter: _circuitOpenUntil!,
        endpoint: endpoint,
        requestId: requestId,
      );
    }

    final hasNetwork = await _connectivityService.hasNetworkConnection();
    if (!hasNetwork) {
      throw NetworkUnavailableException(endpoint: endpoint, requestId: requestId);
    }

    try {
      final response = await _retryStrategy.execute<Response<dynamic>>(
        operation: (attemptIndex, timeout) async {
          final startedAt = DateTime.now();
          ApiLogger.request(
            requestId: requestId,
            method: 'GET',
            url: fullUrl,
            headers: ApiHeaderService.kemonoHeaders,
            attempt: attemptIndex + 1,
          );

          final response = await _dio
              .get<dynamic>(
                fullUrl,
                queryParameters: queryParameters,
                options: Options(
                  headers: ApiHeaderService.kemonoHeaders,
                  validateStatus: (status) => status != null && status < 600,
                ),
              )
              .timeout(
                timeout,
                onTimeout: () => throw RequestTimeoutException(
                  message: 'Discord request timed out after ${timeout.inSeconds}s.',
                  endpoint: endpoint,
                  requestId: requestId,
                ),
              );

          final duration = DateTime.now().difference(startedAt);
          final responseSnippet = response.data == null
              ? null
              : response.data.toString().replaceAll('\n', ' ').substring(
                  0,
                  response.data.toString().length > _responseSnippetMaxLength
                      ? _responseSnippetMaxLength
                      : response.data.toString().length,
                );

          ApiLogger.response(
            requestId: requestId,
            method: 'GET',
            url: fullUrl,
            statusCode: response.statusCode ?? 0,
            duration: duration,
            bodySnippet: responseSnippet,
          );

          if ((response.statusCode ?? 0) == 503) {
            throw HttpStatusException(
              message: 'Kemono Discord is temporarily unavailable (503).',
              statusCode: 503,
              endpoint: endpoint,
              requestId: requestId,
            );
          }

          if ((response.statusCode ?? 0) >= 500) {
            throw HttpStatusException(
              message: 'Discord API server error ${response.statusCode}.',
              statusCode: response.statusCode ?? 0,
              endpoint: endpoint,
              requestId: requestId,
            );
          }

          if ((response.statusCode ?? 0) >= 400) {
            throw HttpStatusException(
              message: 'Discord API client error ${response.statusCode}.',
              statusCode: response.statusCode ?? 0,
              endpoint: endpoint,
              requestId: requestId,
            );
          }

          return response;
        },
        isRetryable: (error) {
          final mapped = _mapDioException(
            error,
            endpoint: endpoint,
            requestId: requestId,
          );
          return mapped.isRetryable;
        },
        onRetry: (attemptIndex, error) {
          AppLogger.warning(
            'Discord retry for $endpoint, next attempt ${attemptIndex + 2}',
            tag: 'DiscordApiClient',
            error: error,
          );
        },
      );

      _markSuccess();
      return response;
    } catch (error, stackTrace) {
      _markFailure();
      final mapped = _mapDioException(
        error,
        endpoint: endpoint,
        requestId: requestId,
        stackTrace: stackTrace,
      );
      ApiLogger.failure(
        requestId: requestId,
        method: 'GET',
        url: fullUrl,
        error: mapped,
        statusCode: mapped.statusCode,
      );
      throw mapped;
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  Future<List<DiscordChannel>> lookupChannels(String serverId) async {
    final response = await _get('/v1/discord/channel/lookup/$serverId');

    final data = response.data;
    List<dynamic> channelsData = [];

    if (data is Map<String, dynamic> && data['channels'] is List) {
      channelsData = data['channels'] as List;
    } else if (data is List) {
      channelsData = data;
    }

    _log(
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

    channels.sort((a, b) => a.position.compareTo(b.position));
    return channels;
  }

  Future<List<PostModel>> loadChannelPosts(
    String channelId, {
    int offset = 0,
  }) async {
    _log(
      '🔍 DEBUG: DiscordApiClient.loadChannelPosts - ChannelId: $channelId, Offset: $offset',
    );

    final response = await _get(
      '/v1/discord/channel/$channelId',
      queryParameters: {'offset': offset},
    );

    final data = response.data;
    List<dynamic> postsData = [];

    if (data is Map<String, dynamic>) {
      if (data['results'] is List) {
        postsData = data['results'] as List;
      } else if (data['data'] is List) {
        postsData = data['data'] as List;
      }
    } else if (data is List) {
      postsData = data;
    } else if (data is String) {
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
      } catch (e, stackTrace) {
        throw ApiParsingException(
          message: 'Failed to parse Discord channel posts JSON.',
          endpoint: '/v1/discord/channel/$channelId',
          cause: e,
          stackTrace: stackTrace,
        );
      }
    }

    _log(
      'DiscordApiClient loadChannelPosts: statusCode=${response.statusCode}, postCount=${postsData.length}',
    );

    return postsData
        .whereType<Map<String, dynamic>>()
        .map(PostModel.fromJson)
        .toList();
  }

  Future<List<DiscordServer>> getServers() async {
    final response = await _get('/v1/discord/server');

    final data = response.data;
    List<dynamic> serversData = [];

    if (data is Map<String, dynamic>) {
      if (data['servers'] is List) {
        serversData = data['servers'] as List;
      } else if (data['results'] is List) {
        serversData = data['results'] as List;
      }
    } else if (data is List) {
      serversData = data;
    }

    _log(
      'DiscordApiClient getServers: statusCode=${response.statusCode}, dataCount=${serversData.length}',
    );

    return serversData
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
  }

  Future<Map<String, dynamic>> getServerWithChannels(String serverId) async {
    final response = await _get('/v1/discord/server/$serverId');
    final data = response.data;

    _log(
      'DiscordApiClient getServerWithChannels: statusCode=${response.statusCode}',
    );

    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is String) {
      try {
        final parsed = jsonDecode(data);
        if (parsed is Map<String, dynamic>) {
          return parsed;
        }
      } catch (e, stackTrace) {
        throw ApiParsingException(
          message: 'Failed to parse Discord server JSON.',
          endpoint: '/v1/discord/server/$serverId',
          cause: e,
          stackTrace: stackTrace,
        );
      }
    }

    throw ApiParsingException(
      message:
          'Invalid Discord server response format: ${data.runtimeType}.',
      endpoint: '/v1/discord/server/$serverId',
    );
  }
}

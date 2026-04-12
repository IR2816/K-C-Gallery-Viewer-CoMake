import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'data_usage_tracker.dart';

/// Custom HTTP Client with Data Usage Tracking
class TrackedHttpClient extends http.BaseClient {
  final http.Client _inner;
  final DataUsageTracker _tracker;

  TrackedHttpClient(this._inner, this._tracker);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    try {
      final response = await _inner.send(request);

      final category = DataUsageTracker.categorizeRequest(
        request.url.toString(),
        contentType: response.headers['content-type'],
      );

      var streamedBytes = 0;
      final trackedStream = response.stream.transform<List<int>>(
        StreamTransformer.fromHandlers(
          handleData: (chunk, sink) {
            streamedBytes += chunk.length;
            sink.add(chunk);
          },
          handleDone: (sink) {
            final fallbackBytes = response.contentLength ?? 0;
            final bytesToTrack = streamedBytes > 0
                ? streamedBytes
                : fallbackBytes;
            if (bytesToTrack > 0) {
              _tracker.trackUsage(bytesToTrack, category: category);
            }
            sink.close();
          },
        ),
      );

      return http.StreamedResponse(
        trackedStream,
        response.statusCode,
        contentLength: response.contentLength,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('HTTP Error: ${request.method} ${request.url} -> $e');
      }
      rethrow;
    }
  }
}

/// HTTP Client with Automatic Retries
class RetryHttpClient extends http.BaseClient {
  final http.Client _inner;
  final int maxRetries;
  final Duration timeout;

  RetryHttpClient(
    this._inner, {
    this.maxRetries = 1,
    this.timeout = const Duration(seconds: 10),
  });

  Future<http.BaseRequest> _copyRequest(http.BaseRequest request) async {
    if (request is http.Request) {
      final copy = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..encoding = request.encoding
        ..followRedirects = request.followRedirects
        ..maxRedirects = request.maxRedirects
        ..bodyBytes = request.bodyBytes;
      return copy;
    } else if (request is http.MultipartRequest) {
      final copy = http.MultipartRequest(request.method, request.url)
        ..headers.addAll(request.headers)
        ..fields.addAll(request.fields)
        ..files.addAll(request.files);
      return copy;
    }
    return request;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    var attempts = 0;
    while (true) {
      attempts++;
      try {
        final requestCopy = await _copyRequest(request);
        final response = await _inner.send(requestCopy).timeout(timeout);

        if (response.statusCode >= 500 && attempts <= maxRetries) {
          if (kDebugMode) {
            debugPrint(
              'HTTP ${response.statusCode}: retry $attempts/$maxRetries for ${request.url}',
            );
          }
          await Future.delayed(Duration(seconds: 1 << attempts));
          continue;
        }
        return response;
      } catch (e) {
        if (attempts <= maxRetries) {
          if (kDebugMode) {
            debugPrint(
              'Network retry $attempts/$maxRetries for ${request.url} -> $e',
            );
          }
          await Future.delayed(Duration(seconds: 1 << attempts));
          continue;
        }
        rethrow;
      }
    }
  }
}

/// HTTP Client Factory for creating tracked clients
class TrackedHttpClientFactory {
  static DataUsageTracker? _tracker;
  static TrackedHttpClient? _cachedClient;

  /// Initialize with a tracker instance
  static void initialize(DataUsageTracker tracker) {
    // Skip re-initialization when the same tracker instance is already wired,
    // so we avoid unnecessary client recreation.
    if (identical(_tracker, tracker) && _cachedClient != null) return;
    _tracker = tracker;
    _cachedClient = null;
  }

  /// Get or create tracked HTTP client
  static http.Client getTrackedClient() {
    final tracker = _tracker;
    if (tracker == null) {
      if (kDebugMode) {
        debugPrint(
          'DataUsageTracker not initialized. Using regular HTTP client.',
        );
      }
      return RetryHttpClient(http.Client());
    }

    _cachedClient ??= TrackedHttpClient(
      RetryHttpClient(http.Client()),
      tracker,
    );
    return _cachedClient!;
  }

  /// Create a new tracked client instance
  static TrackedHttpClient createTrackedClient(DataUsageTracker tracker) {
    return TrackedHttpClient(RetryHttpClient(http.Client()), tracker);
  }
}

/// Extension methods for easy usage
extension TrackedHttpExtensions on http.Client {
  /// Get a tracked version of this client
  TrackedHttpClient asTracked(DataUsageTracker tracker) {
    return TrackedHttpClient(this, tracker);
  }
}

/// Utility class for manual tracking
class ManualUsageTracker {
  final DataUsageTracker _tracker;

  ManualUsageTracker(this._tracker);

  void trackImageLoad(String url, int bytes) {
    _tracker.trackUsage(
      bytes,
      category: DataUsageTracker.categorizeRequest(url, contentType: 'image/*'),
    );
  }

  void trackVideoStream(String url, int bytes) {
    _tracker.trackUsage(
      bytes,
      category: DataUsageTracker.categorizeRequest(url, contentType: 'video/*'),
    );
  }

  void trackThumbnailLoad(String url, int bytes) {
    _tracker.trackUsage(
      bytes,
      category: DataUsageTracker.categorizeRequest(url, contentType: 'image/*'),
    );
  }

  void trackApiResponse(String endpoint, int bytes) {
    _tracker.trackUsage(
      bytes,
      category: DataUsageTracker.categorizeRequest(
        endpoint,
        contentType: 'application/json',
      ),
    );
  }

  void trackGenericUsage(
    String description,
    int bytes, {
    UsageCategory? category,
  }) {
    _tracker.trackUsage(bytes, category: category ?? UsageCategory.other);
    if (kDebugMode) {
      debugPrint('Generic usage tracked: $description ($bytes bytes)');
    }
  }
}

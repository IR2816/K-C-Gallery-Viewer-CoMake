import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'data_usage_tracker.dart';

/// Custom HTTP Client with Data Usage Tracking
class TrackedHttpClient extends http.BaseClient {
  final http.Client _inner;
  final DataUsageTracker _tracker;

  TrackedHttpClient(this._inner, this._tracker);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _inner.send(request);

      // Track response size
      final contentLength = response.contentLength ?? 0;
      final category = _categorizeRequest(request.url.toString());

      _tracker.trackUsage(contentLength, category: category);

      debugPrint(
        '📊 HTTP: ${request.method} ${request.url} → ${response.statusCode} ($contentLength bytes, ${stopwatch.elapsedMilliseconds}ms)',
      );

      return response;
    } catch (e) {
      debugPrint('❌ HTTP Error: ${request.method} ${request.url} → $e');
      rethrow;
    } finally {
      stopwatch.stop();
    }
  }

  /// Categorize HTTP requests for usage tracking
  UsageCategory _categorizeRequest(String url) {
    // API calls
    if (url.contains('/api/') || url.contains('/v1/')) {
      return UsageCategory.apiCalls;
    }

    // Image files
    if (_isImageFile(url)) {
      return UsageCategory.images;
    }

    // Video files
    if (_isVideoFile(url)) {
      return UsageCategory.videos;
    }

    // Thumbnail files (usually smaller or contain 'thumb')
    if (url.contains('thumb') || url.contains('preview')) {
      return UsageCategory.thumbnails;
    }

    // Attachments
    if (url.contains('file') || url.contains('attachment')) {
      return UsageCategory.attachments;
    }

    return UsageCategory.other;
  }

  bool _isImageFile(String url) {
    final imageExtensions = [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.webp',
      '.bmp',
      '.svg',
    ];
    return imageExtensions.any((ext) => url.toLowerCase().endsWith(ext));
  }

  bool _isVideoFile(String url) {
    final videoExtensions = [
      '.mp4',
      '.avi',
      '.mov',
      '.wmv',
      '.flv',
      '.webm',
      '.mkv',
      '.m4v',
    ];
    return videoExtensions.any((ext) => url.toLowerCase().endsWith(ext));
  }
}

/// HTTP Client with Automatic Retries
class RetryHttpClient extends http.BaseClient {
  final http.Client _inner;
  final int maxRetries;
  final Duration timeout;

  RetryHttpClient(
    this._inner, {
    this.maxRetries = 3,
    this.timeout = const Duration(seconds: 15),
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
    int attempts = 0;
    while (true) {
      attempts++;
      try {
        final requestCopy = await _copyRequest(request);
        final response = await _inner.send(requestCopy).timeout(timeout);

        if (response.statusCode >= 500 && attempts <= maxRetries) {
          debugPrint(
              '⚠️ HTTP ${response.statusCode}: Retrying request (Attempt $attempts/$maxRetries) for ${request.url}');
          await Future.delayed(Duration(seconds: 1 << attempts));
          continue;
        }
        return response;
      } catch (e) {
        if (attempts <= maxRetries) {
          debugPrint(
              '⚠️ Network Error: Retrying request (Attempt $attempts/$maxRetries) for ${request.url} -> $e');
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
    _tracker = tracker;
    _cachedClient = null; // Reset cached client
  }

  /// Get or create tracked HTTP client
  static http.Client getTrackedClient() {
    if (_tracker == null) {
      debugPrint(
        '⚠️ DataUsageTracker not initialized. Using regular HTTP client.',
      );
      return RetryHttpClient(http.Client());
    }

    _cachedClient ??= TrackedHttpClient(RetryHttpClient(http.Client()), _tracker!);
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

  /// Track image loading manually
  void trackImageLoad(String url, int bytes) {
    _tracker.trackImageUsage(bytes);
    debugPrint('🖼️ Image: $url ($bytes bytes)');
  }

  /// Track video streaming manually
  void trackVideoStream(String url, int bytes) {
    _tracker.trackVideoUsage(bytes);
    debugPrint('🎥 Video: $url ($bytes bytes)');
  }

  /// Track thumbnail loading manually
  void trackThumbnailLoad(String url, int bytes) {
    _tracker.trackThumbnailUsage(bytes);
    debugPrint('👁️ Thumbnail: $url ($bytes bytes)');
  }

  /// Track API response manually
  void trackApiResponse(String endpoint, int bytes) {
    _tracker.trackApiUsage(bytes);
    debugPrint('📡 API: $endpoint ($bytes bytes)');
  }

  /// Track generic data usage
  void trackGenericUsage(
    String description,
    int bytes, {
    UsageCategory? category,
  }) {
    _tracker.trackUsage(bytes, category: category ?? UsageCategory.other);
    debugPrint('📊 Generic: $description ($bytes bytes)');
  }
}

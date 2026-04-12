import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../providers/data_usage_tracker.dart';

/// Custom HttpFileService that always injects headers for all requests
/// Critical for Kemono/Coomer CDN that requires specific headers
class HeaderHttpFileService extends HttpFileService {
  final Map<String, String> defaultHeaders;
  static DataUsageTracker? _tracker;

  HeaderHttpFileService(this.defaultHeaders);

  static void setTracker(DataUsageTracker tracker) {
    _tracker = tracker;
  }

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final merged = {...defaultHeaders, ...?headers};
    final response = await super.get(url, headers: merged);
    final tracker = _tracker;
    if (tracker == null) return response;
    return _TrackedFileServiceResponse(
      inner: response,
      url: url,
      tracker: tracker,
    );
  }
}

class _TrackedFileServiceResponse implements FileServiceResponse {
  final FileServiceResponse inner;
  final String url;
  final DataUsageTracker tracker;

  _TrackedFileServiceResponse({
    required this.inner,
    required this.url,
    required this.tracker,
  });

  @override
  Stream<List<int>> get content {
    var streamedBytes = 0;
    var hadError = false;
    return inner.content.transform<List<int>>(
      StreamTransformer.fromHandlers(
        handleData: (chunk, sink) {
          streamedBytes += chunk.length;
          sink.add(chunk);
        },
        handleError: (error, stackTrace, sink) {
          hadError = true;
          sink.addError(error, stackTrace);
        },
        handleDone: (sink) {
          final isSuccessful = statusCode >= 200 && statusCode < 400;
          final fallbackBytes =
              (!hadError && streamedBytes == 0 && isSuccessful)
              ? (contentLength ?? 0)
              : 0;
          final bytesToTrack = streamedBytes > 0
              ? streamedBytes
              : fallbackBytes;
          if (bytesToTrack > 0) {
            tracker.trackUsage(
              bytesToTrack,
              category: DataUsageTracker.categorizeRequest(
                url,
                contentType: inner.contentType,
              ),
            );
          }
          sink.close();
        },
      ),
    );
  }

  @override
  int? get contentLength => inner.contentLength;

  @override
  String? get contentType => inner.contentType;

  @override
  DateTime get validTill => inner.validTill;

  @override
  int get statusCode => inner.statusCode;

  @override
  String? get eTag => inner.eTag;

  @override
  String get fileExtension => inner.fileExtension;
}

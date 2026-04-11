import 'dart:convert';

import 'package:dio/dio.dart';

import 'data_usage_tracker.dart';

class DataUsageDioInterceptor extends Interceptor {
  final DataUsageTracker tracker;

  DataUsageDioInterceptor(this.tracker);

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _track(response);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;
    if (response != null) {
      _track(response);
    }
    handler.next(err);
  }

  void _track(Response response) {
    final extra = response.requestOptions.extra;
    if (extra['skipUsageTracking'] == true) return;

    final forceAttachment = extra['forceAttachment'] == true;
    final categoryOverrideName = extra['usageCategory']?.toString();
    UsageCategory? categoryOverride;
    if (categoryOverrideName != null) {
      for (final category in UsageCategory.values) {
        if (category.name == categoryOverrideName) {
          categoryOverride = category;
          break;
        }
      }
    }

    final bytes = _resolveResponseBytes(response);
    if (bytes <= 0) return;

    final contentType = response.headers.value(Headers.contentTypeHeader);
    final category = categoryOverride ??
        DataUsageTracker.categorizeRequest(
          response.requestOptions.uri.toString(),
          contentType: contentType,
          forceAttachment: forceAttachment,
        );

    tracker.trackUsage(bytes, category: category);
  }

  int _resolveResponseBytes(Response response) {
    final fromHeader = int.tryParse(
          response.headers.value(Headers.contentLengthHeader) ?? '',
        ) ??
        0;
    if (fromHeader > 0) return fromHeader;

    final data = response.data;
    if (data == null) return 0;
    if (data is List<int>) return data.length;
    if (data is String) return utf8.encode(data).length;

    try {
      return utf8.encode(jsonEncode(data)).length;
    } catch (_) {
      return 0;
    }
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../config/domain_config.dart';

enum ApiStatus { checking, online, rateLimited, offline }

class ApiHealthProvider extends ChangeNotifier {
  ApiStatus kemonoStatus = ApiStatus.checking;
  ApiStatus coomerStatus = ApiStatus.checking;

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    sendTimeout: const Duration(seconds: 8),
    validateStatus: (status) => true, // Parse all status codes
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    },
  ));

  ApiHealthProvider() {
    checkHealth();
  }

  Future<void> checkHealth() async {
    kemonoStatus = ApiStatus.checking;
    coomerStatus = ApiStatus.checking;
    notifyListeners();

    // Perform checks in parallel
    final results = await Future.wait([
      _pingDomain(DomainConfig.kemonoApiDomains.first),
      _pingDomain(DomainConfig.coomerApiDomains.first),
    ]);

    kemonoStatus = results[0];
    coomerStatus = results[1];
    notifyListeners();
  }

  Future<ApiStatus> _pingDomain(String apiUrl) async {
    try {
      // Rather than hitting a heavy JSON API endpoint, we hit the base website domain
      // using a HEAD request. This returns headers only and is far less likely
      // to count against your JSON API rate limit, yet proves the server is up.
      final uri = Uri.parse(apiUrl);
      final baseUrl = '${uri.scheme}://${uri.host}';

      final response = await _dio.head(baseUrl);

      if (response.statusCode == 429) {
        return ApiStatus.rateLimited;
      }

      if (response.statusCode != null && response.statusCode! >= 500) {
        return ApiStatus.offline;
      }

      // Codes like 200, 301, 302, 403 (Cloudflare Challenge) mean the backend is alive.
      return ApiStatus.online;
    } catch (_) {
      return ApiStatus.offline;
    }
  }
}

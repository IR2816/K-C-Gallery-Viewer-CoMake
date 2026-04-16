import 'package:flutter/foundation.dart' show debugPrint;

class ApiHeaderService {
  /// Base headers for Kemono/Coomer API requests.
  ///
  /// NOTE: `Accept: text/css` is intentionally non-standard. The Kemono/Coomer
  /// servers use it as a signal to return raw JSON instead of an HTML page shell.
  /// Do NOT change it to `application/json` — that will break JSON responses.
  static const Map<String, String> _kemonoCoomerHeaders = {
    'Accept': 'text/css',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept-Language': 'en-US,en;q=0.9',
    'Accept-Encoding': 'gzip, deflate',
    'DNT': '1',
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'none',
    'Cache-Control': 'max-age=0',
  };

  /// Public accessor for kemono headers (returns a mutable copy)
  static Map<String, String> get kemonoHeaders =>
      Map<String, String>.from(_kemonoCoomerHeaders);

  static const Map<String, String> _mediaHeaders = {
    'Accept': 'image/*, video/*, */*',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Referer': 'https://kemono.cr/',
  };

  /// Get headers for Kemono/Coomer API requests
  static Map<String, String> getApiHeaders({
    Map<String, String>? additionalHeaders,
  }) {
    final headers = kemonoHeaders;
    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }
    return headers;
  }

  /// Get headers for media requests (images/videos)
  static Map<String, String> getMediaHeaders({String? referer}) {
    final headers = Map<String, String>.from(_mediaHeaders);
    if (referer != null) {
      headers['Referer'] = referer;
    }
    return headers;
  }

  /// Get headers for specific domain
  static Map<String, String> getHeadersForDomain(
    String domain, {
    Map<String, String>? additionalHeaders,
  }) {
    final Map<String, String> baseHeaders =
        (domain.contains('kemono.cr') || domain.contains('coomer.st'))
        ? _kemonoCoomerHeaders
        : _mediaHeaders;

    final headers = Map<String, String>.from(baseHeaders);
    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }
    return headers;
  }

  /// Validate if headers contain required fields for Kemono/Coomer
  static bool validateKemonoCoomerHeaders(Map<String, String> headers) {
    final hasAccept =
        headers.containsKey('Accept') && headers['Accept'] == 'text/css';
    final hasUserAgent = headers.containsKey('User-Agent');
    return hasAccept && hasUserAgent;
  }

  /// Log headers for debugging
  static void logHeaders(String context, Map<String, String> headers) {
    debugPrint('=== $context Headers ===');
    headers.forEach((key, value) {
      debugPrint('$key: $value');
    });
    debugPrint('=== End Headers ===');
  }
}

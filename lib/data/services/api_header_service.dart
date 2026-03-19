import 'package:flutter/foundation.dart' show debugPrint;

class ApiHeaderService {
  static const Map<String, String> _kemonoCoomerHeaders = {
    'Accept': 'text/css',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
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

  static const Map<String, String> _mediaHeaders = {
    'Accept': 'image/*, video/*, */*',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Referer': 'https://kemono.cr/',
  };

  /// Get headers for Kemono/Coomer API requests
  static Map<String, String> getApiHeaders({
    Map<String, String>? additionalHeaders,
  }) {
    final headers = Map<String, String>.from(_kemonoCoomerHeaders);
    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }
    debugPrint('API Headers: ${headers.keys.join(', ')}');
    return headers;
  }

  /// Get headers for media requests (images/videos)
  static Map<String, String> getMediaHeaders({String? referer}) {
    final headers = Map<String, String>.from(_mediaHeaders);
    if (referer != null) {
      headers['Referer'] = referer;
    }
    debugPrint('Media Headers: ${headers.keys.join(', ')}');
    return headers;
  }

  /// Get headers for specific domain
  static Map<String, String> getHeadersForDomain(
    String domain, {
    Map<String, String>? additionalHeaders,
  }) {
    Map<String, String> baseHeaders;

    if (domain.contains('kemono.cr') || domain.contains('coomer.st')) {
      baseHeaders = _kemonoCoomerHeaders;
    } else {
      baseHeaders = _mediaHeaders;
    }

    final headers = Map<String, String>.from(baseHeaders);
    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }

    debugPrint('Headers for $domain: ${headers.keys.join(', ')}');
    return headers;
  }

  /// Validate if headers contain required fields for Kemono/Coomer
  static bool validateKemonoCoomerHeaders(Map<String, String> headers) {
    final hasAccept =
        headers.containsKey('Accept') && headers['Accept'] == 'text/css';
    final hasUserAgent = headers.containsKey('User-Agent');

    debugPrint(
      'Header validation - Accept: $hasAccept, User-Agent: $hasUserAgent',
    );
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

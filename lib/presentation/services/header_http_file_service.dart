import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Custom HttpFileService that always injects headers for all requests
/// Critical for Kemono/Coomer CDN that requires specific headers
class HeaderHttpFileService extends HttpFileService {
  final Map<String, String> defaultHeaders;

  HeaderHttpFileService(this.defaultHeaders);

  @override
  Future<FileServiceResponse> get(String url, {Map<String, String>? headers}) {
    final merged = {...defaultHeaders, ...?headers};
    return super.get(url, headers: merged);
  }
}

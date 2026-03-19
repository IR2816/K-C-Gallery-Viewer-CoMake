import 'dart:io';
import '../../data/datasources/creator_index_datasource_impl.dart';
import '../../data/models/creator_index_item.dart';
import '../../domain/entities/api_source.dart';
import '../../utils/logger.dart';

class CreatorIndexManager {
  final CreatorIndexDatasourceImpl datasource;
  final List<CreatorIndexItem> _index = [];
  bool _ready = false;
  String? _currentBaseUrl;

  CreatorIndexManager(this.datasource);

  bool get isReady => _ready;
  int get indexSize => _index.length;
  String? get currentBaseUrl => _currentBaseUrl;

  /// Prepare index for the specified API source
  Future<void> prepare(ApiSource apiSource) async {
    final baseUrl = apiSource == ApiSource.coomer
        ? 'https://coomer.st'
        : 'https://kemono.cr';

    // If already prepared for this source, skip
    if (_ready && _currentBaseUrl == baseUrl) {
      AppLogger.info(
        'Creator index already prepared for $baseUrl',
        tag: 'CreatorIndex',
      );
      return;
    }

    AppLogger.info('Preparing creator index for $baseUrl', tag: 'CreatorIndex');

    // Check if we have a valid cached index
    final hasValidCache = await datasource.hasValidIndex(baseUrl);

    try {
      File file;
      if (hasValidCache) {
        final dir = await getApplicationDocumentsDirectory();
        file = File('${dir.path}/creators_index.txt');
        AppLogger.info('Using cached creator index', tag: 'CreatorIndex');
      } else {
        file = await datasource.downloadIndex(baseUrl);
      }

      // Clear previous index
      _index.clear();
      int lineCount = 0;

      await for (final line in datasource.readLines(file)) {
        final parts = line.split(',');
        if (parts.length < 3) continue;

        _index.add(
          CreatorIndexItem(
            service: parts[0].trim(),
            userId: parts[1].trim(),
            name: parts.sublist(2).join(',').trim(),
          ),
        );

        lineCount++;
        if (lineCount % 10000 == 0) {
          AppLogger.info('Processed $lineCount lines...', tag: 'CreatorIndex');
        }
      }

      _ready = true;
      _currentBaseUrl = baseUrl;

      AppLogger.info(
        'Creator index prepared successfully: ${_index.length} creators',
        tag: 'CreatorIndex',
      );
    } catch (e) {
      AppLogger.error(
        'Failed to prepare creator index',
        tag: 'CreatorIndex',
        error: e,
      );
      _ready = false;
      rethrow;
    }
  }

  /// Search creators by name
  List<CreatorIndexItem> search(String query) {
    if (!_ready || query.length < 2) return [];

    final q = query.toLowerCase().trim();
    AppLogger.info('Searching creators for: "$q"', tag: 'CreatorIndex');

    final results = _index
        .where((item) => item.nameKey.contains(q))
        .take(50) // Limit results to prevent UI lag
        .toList();

    AppLogger.info(
      'Found ${results.length} creators for query: "$q"',
      tag: 'CreatorIndex',
    );
    return results;
  }

  /// Get creator by exact service and userId
  CreatorIndexItem? findByServiceAndId(String service, String userId) {
    try {
      return _index.firstWhere(
        (item) => item.service == service && item.userId == userId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get popular creators (first 100)
  List<CreatorIndexItem> getPopularCreators() {
    if (!_ready) return [];
    return _index.take(100).toList();
  }

  /// Clear current index
  void clear() {
    _index.clear();
    _ready = false;
    _currentBaseUrl = null;
    AppLogger.info('Creator index cleared', tag: 'CreatorIndex');
  }

  /// Get application documents directory
  Future<Directory> getApplicationDocumentsDirectory() async {
    return await getApplicationDocumentsDirectory();
  }
}

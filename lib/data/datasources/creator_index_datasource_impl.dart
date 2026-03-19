import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'creator_index_datasource.dart';
import '../../utils/logger.dart';

class CreatorIndexDatasourceImpl implements CreatorIndexDatasource {
  static const String _indexFileName = 'creators_index.txt';
  static const Duration _maxAge = Duration(hours: 24); // Cache for 24 hours

  @override
  Future<File> downloadIndex(String baseUrl) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_indexFileName');

    AppLogger.info(
      'Downloading creator index from $baseUrl/api/v1/creators.txt',
      tag: 'CreatorIndex',
    );

    final request = http.Request(
      'GET',
      Uri.parse('$baseUrl/api/v1/creators.txt'),
    );

    request.headers.addAll({
      'Accept': 'text/css',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Accept-Language': 'en-US,en;q=0.9',
      'Cache-Control': 'no-cache',
    });

    try {
      final response = await request.send();

      if (response.statusCode != 200) {
        throw HttpException('Failed to download index: ${response.statusCode}');
      }

      final sink = file.openWrite();
      await response.stream.pipe(sink);
      await sink.close();

      // Store metadata for cache validation
      final metadataFile = File('${dir.path}/$_indexFileName.meta');
      await metadataFile.writeAsString(DateTime.now().toIso8601String());

      AppLogger.info(
        'Creator index downloaded successfully: ${file.path}',
        tag: 'CreatorIndex',
      );
      return file;
    } catch (e) {
      AppLogger.error(
        'Failed to download creator index',
        tag: 'CreatorIndex',
        error: e,
      );
      rethrow;
    }
  }

  @override
  Stream<String> readLines(File file) {
    AppLogger.info(
      'Reading creator index lines from: ${file.path}',
      tag: 'CreatorIndex',
    );

    return file
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where((line) => line.trim().isNotEmpty) // Skip empty lines
        .where((line) => !line.startsWith('#')); // Skip comments
  }

  @override
  Future<bool> hasValidIndex(String baseUrl) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_indexFileName');
      final metadataFile = File('${dir.path}/$_indexFileName.meta');

      if (!await file.exists() || !await metadataFile.exists()) {
        return false;
      }

      final metadata = await metadataFile.readAsString();
      final lastUpdate = DateTime.parse(metadata);

      return DateTime.now().difference(lastUpdate) < _maxAge;
    } catch (e) {
      AppLogger.error(
        'Error checking index validity',
        tag: 'CreatorIndex',
        error: e,
      );
      return false;
    }
  }
}

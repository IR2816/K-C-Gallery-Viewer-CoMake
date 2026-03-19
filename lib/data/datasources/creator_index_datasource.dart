import 'dart:io';

abstract class CreatorIndexDatasource {
  /// Download creators.txt from the specified base URL
  Future<File> downloadIndex(String baseUrl);

  /// Read lines from the downloaded file as stream
  Stream<String> readLines(File file);

  /// Check if index file exists and is recent (optional)
  Future<bool> hasValidIndex(String baseUrl);
}

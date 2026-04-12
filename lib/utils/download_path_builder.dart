import 'dart:io';
import 'package:intl/intl.dart';

/// Utility class for building organized download paths.
///
/// This centralizes the logic for:
/// - Sanitizing path components (creator names, post titles)
/// - Formatting dates consistently (YYYY-MM-DD)
/// - Building organized directory structures
/// - Resolving final save directories
class DownloadPathBuilder {
  /// Sanitize a string for use as a filesystem path component.
  /// Removes/replaces characters not allowed in directory/file names:
  /// - Forward slash (/)
  /// - Backslash (\)
  /// - Colon (:)
  /// - Asterisk (*)
  /// - Question mark (?)
  /// - Double quote (")
  /// - Less than (<)
  /// - Greater than (>)
  /// - Pipe (|)
  /// - Control characters (ASCII 0-31)
  static String sanitizePathComponent(String name) {
    if (name.isEmpty) return 'unknown';

    var result = name
        // Replace invalid characters with underscores
        .replaceAll(RegExp(r'[/\\:*?"<>|\x00-\x1F]'), '_')
        // Trim leading/trailing whitespace
        .trim()
        // Collapse multiple spaces
        .replaceAll(RegExp(r'\s+'), ' ')
        // Remove trailing dots and spaces (invalid on some filesystems)
        .replaceAll(RegExp(r'[. ]+$'), '');

    return result.isEmpty ? 'unknown' : result;
  }

  /// Format a DateTime as YYYY-MM-DD.
  /// Returns 'unknown' if the date is null.
  static String formatPostDate(DateTime? date) {
    if (date == null) return 'unknown';
    try {
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (e) {
      return 'unknown';
    }
  }

  /// Build the organized directory path for a download.
  ///
  /// If [organizeByCreator] is true:
  ///   Returns: {baseDir}/{creator}/{YYYY-MM-DD}_{title}/
  /// Otherwise:
  ///   Returns: {baseDir}/
  ///
  /// Parameters:
  /// - [baseDir]: The base downloads directory
  /// - [creatorName]: Name of the creator (will be sanitized)
  /// - [postDate]: Publication date of the post (will be formatted as YYYY-MM-DD)
  /// - [postTitle]: Title of the post (will be sanitized)
  /// - [organizeByCreator]: Whether to organize by creator/date structure
  static Future<Directory> buildDownloadDirectory({
    required Directory baseDir,
    required String creatorName,
    required DateTime? postDate,
    required String postTitle,
    required bool organizeByCreator,
  }) async {
    if (!organizeByCreator) {
      // Return base directory as-is
      return baseDir;
    }

    try {
      final sanitizedCreator = sanitizePathComponent(creatorName);
      final formattedDate = formatPostDate(postDate);
      final sanitizedTitle = sanitizePathComponent(postTitle);

      final organizedPath =
          '${baseDir.path}/$sanitizedCreator/${formattedDate}_$sanitizedTitle';
      final directory = Directory(organizedPath);

      // Create the directory if it doesn't exist
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      return directory;
    } catch (e) {
      // Fallback to base directory on error
      return baseDir;
    }
  }

  /// Build the complete save path for a file.
  ///
  /// Combines the download directory with the file name,
  /// handling file conflicts by appending a numeric suffix.
  ///
  /// Returns the final path as a string.
  static Future<String> buildDownloadFilePath({
    required Directory saveDir,
    required String fileName,
  }) async {
    var finalPath = '${saveDir.path}/$fileName';
    var file = File(finalPath);

    // Handle file conflicts
    if (await file.exists()) {
      final nameWithoutExt = fileName.contains('.')
          ? fileName.substring(0, fileName.lastIndexOf('.'))
          : fileName;
      final ext = fileName.contains('.')
          ? fileName.substring(fileName.lastIndexOf('.'))
          : '';

      int counter = 1;
      while (await File(
        '${saveDir.path}/$nameWithoutExt($counter)$ext',
      ).exists()) {
        counter++;
      }

      finalPath = '${saveDir.path}/$nameWithoutExt($counter)$ext';
    }

    return finalPath;
  }

  /// Sanitize a file name (specifically for file names, not directory names).
  /// This is a wrapper around [sanitizePathComponent] with an additional
  /// check to provide a default if the result is empty.
  static String sanitizeFileName(String name) {
    final sanitized = sanitizePathComponent(name);
    return sanitized.isEmpty ? 'download_file' : sanitized;
  }

  /// Extract file extension from a URL or file name.
  static String getFileExtension(String fileNameOrUrl) {
    if (!fileNameOrUrl.contains('.')) return '';

    // Remove query parameters from URL
    final withoutQuery = fileNameOrUrl.split('?').first;
    if (!withoutQuery.contains('.')) return '';

    return '.${withoutQuery.split('.').last.toLowerCase()}';
  }

  /// Build a descriptive message for the organized path.
  ///
  /// Example output: "Saving to Creator Name/2025-03-20_Post Title/"
  static String buildPathDisplayMessage({
    required String creatorName,
    required DateTime? postDate,
    required String postTitle,
    required bool organizeByCreator,
  }) {
    if (!organizeByCreator) {
      return 'Saving to Downloads folder';
    }

    final sanitizedCreator = sanitizePathComponent(creatorName);
    final formattedDate = formatPostDate(postDate);
    final sanitizedTitle = sanitizePathComponent(postTitle);

    return 'Saving to $sanitizedCreator/${formattedDate}_$sanitizedTitle/';
  }
}

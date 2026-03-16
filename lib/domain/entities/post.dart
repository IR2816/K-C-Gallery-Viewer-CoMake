import 'post_file.dart';
import 'api_source.dart';
import '../../utils/logger.dart';

class Post {
  final String id;
  final String user;
  final String service;
  final String title;
  final String content;
  final String? embedUrl;
  final String sharedFile;
  final DateTime added;
  final DateTime published;
  final DateTime edited;
  final List<PostFile> attachments;
  final List<PostFile> file;
  final List<String> tags;
  final bool saved;

  Post({
    required this.id,
    required this.user,
    required this.service,
    required this.title,
    required this.content,
    this.embedUrl,
    required this.sharedFile,
    required this.added,
    required this.published,
    required this.edited,
    required this.attachments,
    required this.file,
    required this.tags,
    this.saved = false,
  });

  String? get thumbnailUrl {
    // DEPRECATED: Use getThumbnailUrl(apiSource) instead
    // This method is kept for compatibility but should not be used
    AppLogger.warning(
      'thumbnailUrl getter is deprecated, use getThumbnailUrl(apiSource) instead',
      tag: 'Post',
    );
    return getThumbnailUrl(ApiSource.kemono); // Fallback to kemono
  }

  String? getThumbnailUrl(
    ApiSource apiSource, {
    String? kemonoDomain,
    String? coomerDomain,
    bool forceThumbnail = false,
  }) {
    final domain = apiSource == ApiSource.kemono
        ? (kemonoDomain ?? 'kemono.cr')
        : (coomerDomain ?? 'coomer.st');
    final baseUrl = 'https://img.$domain/thumbnail/data';

    if (attachments.isNotEmpty || file.isNotEmpty) {
      final firstMedia = attachments.isNotEmpty ? attachments.first : file.first;
      final originalPath = firstMedia.path;
      
      if (originalPath.startsWith('http')) {
        // If it's an external URL and we force thumbnail, we might not have one
        // unless it's a known re-hosted pattern. For now, return original if not forced.
        return forceThumbnail ? null : originalPath;
      }
      if (originalPath.startsWith('//')) return 'https:$originalPath';

      // Normalize: API returns "/data/..." but thumbnails live at "/thumbnail/data/..."
      final clean = originalPath.startsWith('/')
          ? originalPath.substring(1)
          : originalPath;
      final stripped = clean.startsWith('data/') ? clean.substring(5) : clean;
      final fullUrl = '$baseUrl/$stripped';
      
      return fullUrl;
    }
    return null;
  }

  // Get appropriate thumbnail URL based on content type and quality
  String? getBestThumbnailUrl(
    ApiSource apiSource, {
    String? kemonoDomain,
    String? coomerDomain,
    String quality = 'medium',
  }) {
    // Quality levels:
    // 'low': Strict thumbnail only (img subdomain). If no thumbnail, return placeholder.
    // 'medium': Prefer thumbnail, fallback to original if thumbnail fails or doesn't exist.
    // 'high': Original image (n4 subdomain).

    final isLowQuality = quality == 'low';
    final isHighQuality = quality == 'high';

    if (isHighQuality) {
      // Return original URL
      if (file.isNotEmpty) return _buildFullUrl(file.first.path, service);
      if (attachments.isNotEmpty) return _buildFullUrl(attachments.first.path, service);
      return null;
    }

    // Try to get thumbnail first
    final thumb = getThumbnailUrl(
      apiSource,
      kemonoDomain: kemonoDomain,
      coomerDomain: coomerDomain,
      forceThumbnail: isLowQuality,
    );

    if (thumb != null) return thumb;

    // If low quality and no thumbnail, return null (caller shows placeholder)
    if (isLowQuality) return null;

    // Otherwise fallback to original for medium/unknown quality
    if (file.isNotEmpty) return _buildFullUrl(file.first.path, service);
    if (attachments.isNotEmpty) return _buildFullUrl(attachments.first.path, service);

    return null;
  }

  String _buildFullUrl(String path, String service) {
    if (path.startsWith('http')) return path;
    final domain = (service == 'onlyfans' || service == 'fansly' || service == 'candfans')
        ? 'n4.coomer.st'
        : 'n4.kemono.cr';
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return 'https://$domain$cleanPath';
  }

  // Get total media count
  int get mediaCount => attachments.length + file.length;

  // Get media count by type
  int get imageCount {
    final allFiles = [...attachments, ...file];
    return allFiles
        .where(
          (f) =>
              f.type?.contains('image') == true ||
              f.name.toLowerCase().endsWith('.jpg') ||
              f.name.toLowerCase().endsWith('.jpeg') ||
              f.name.toLowerCase().endsWith('.png') ||
              f.name.toLowerCase().endsWith('.gif') ||
              f.name.toLowerCase().endsWith('.webp'),
        )
        .length;
  }

  int get videoCount {
    final allFiles = [...attachments, ...file];
    return allFiles
        .where(
          (f) =>
              f.type?.contains('video') == true ||
              f.name.toLowerCase().endsWith('.mp4') ||
              f.name.toLowerCase().endsWith('.mov') ||
              f.name.toLowerCase().endsWith('.avi') ||
              f.name.toLowerCase().endsWith('.webm'),
        )
        .length;
  }

  bool get hasImage => imageCount > 0;
  bool get hasVideo => videoCount > 0;

  Post copyWith({bool? saved}) {
    return Post(
      id: id,
      user: user,
      service: service,
      title: title,
      content: content,
      embedUrl: embedUrl,
      sharedFile: sharedFile,
      added: added,
      published: published,
      edited: edited,
      attachments: attachments,
      file: file,
      tags: tags,
      saved: saved ?? this.saved,
    );
  }
}

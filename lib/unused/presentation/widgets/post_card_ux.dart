import 'package:flutter/material.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/api_source.dart';
import '../screens/post_detail_ux_screen.dart';

/// Prinsip 4: Post Card = Janji, bukan isi
///
/// UX Principles:
/// - Scan > Read (user lebih sering scroll daripada baca)
/// - Preview dulu, detail belakangan
/// - Media adalah fokus, bukan teks
/// - Navigasi dangkal (max 2 tap ke konten)
class PostCardUX extends StatelessWidget {
  final Post post;
  final ApiSource apiSource;
  final VoidCallback? onTap;
  final VoidCallback? onCreatorTap;

  const PostCardUX({
    super.key,
    required this.post,
    required this.apiSource,
    this.onTap,
    this.onCreatorTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Creator Header
              _buildCreatorHeader(),
              const SizedBox(height: 8),

              // Post Title (optional, max 2 lines)
              if (post.title.isNotEmpty) ...[
                _buildPostTitle(),
                const SizedBox(height: 8),
              ],

              // Media Preview (fokus utama)
              _buildMediaPreview(),
              const SizedBox(height: 8),

              // Post Meta
              _buildPostMeta(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreatorHeader() {
    return Row(
      children: [
        // Creator Avatar
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey[700],
          child: Text(
            post.user.isNotEmpty ? post.user[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Creator Name (clickable)
        Expanded(
          child: GestureDetector(
            onTap: onCreatorTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.user,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  post.service.toUpperCase(),
                  style: TextStyle(
                    color: _getServiceColor(post.service),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostTitle() {
    return Text(
      post.title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildMediaPreview() {
    final mediaCount = _getMediaCount();
    final hasVideo = _hasVideo();

    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[800],
      ),
      child: Stack(
        children: [
          // Thumbnail atau placeholder
          if (_hasThumbnail())
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildThumbnail(),
            )
          else
            _buildPlaceholder(),

          // Overlay untuk video/gallery
          if (hasVideo || mediaCount > 1)
            Positioned(
              top: 8,
              right: 8,
              child: _buildMediaBadge(hasVideo, mediaCount),
            ),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    final thumbnailUrl = _getThumbnailUrl();
    if (thumbnailUrl != null) {
      return Image.network(
        thumbnailUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholder();
        },
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey[800]!, Colors.grey[900]!],
        ),
      ),
      child: Icon(
        _hasVideo() ? Icons.play_circle_outline : Icons.image_outlined,
        size: 48,
        color: Colors.grey[600],
      ),
    );
  }

  Widget _buildMediaBadge(bool hasVideo, int mediaCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasVideo) ...[
            const Icon(Icons.play_arrow, color: Colors.white, size: 16),
            const SizedBox(width: 4),
          ],
          if (mediaCount > 1) ...[
            const Icon(Icons.collections, color: Colors.white, size: 16),
            const SizedBox(width: 4),
          ],
          Text(
            hasVideo
                ? 'Video'
                : mediaCount > 1
                ? 'Images $mediaCount'
                : 'Image',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostMeta() {
    return Row(
      children: [
        // Date
        Icon(Icons.schedule_outlined, size: 14, color: Colors.grey[400]),
        const SizedBox(width: 4),
        Text(
          _formatDate(post.published),
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
        const SizedBox(width: 12),

        // Attachments count
        Icon(Icons.attach_file_outlined, size: 14, color: Colors.grey[400]),
        const SizedBox(width: 4),
        Text(
          '${_getMediaCount()} items',
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
      ],
    );
  }

  // Helper methods

  bool _hasThumbnail() {
    // Check if post has thumbnail in content or files
    return post.content.isNotEmpty ||
        post.files.any((file) => _isImageFile(file.name));
  }

  String? _getThumbnailUrl() {
    // Try to get thumbnail from content first
    for (final content in post.content) {
      if (content.type == 'image') {
        return content.path;
      }
    }

    // Try to get first image from files
    for (final file in post.files) {
      if (_isImageFile(file.name)) {
        return file.path;
      }
    }

    return null;
  }

  bool _hasVideo() {
    return post.content.any((content) => content.type == 'video') ||
        post.files.any((file) => _isVideoFile(file.name));
  }

  int _getMediaCount() {
    return post.content.length + post.files.length;
  }

  bool _isImageFile(String filename) {
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    return imageExtensions.any((ext) => filename.toLowerCase().endsWith(ext));
  }

  bool _isVideoFile(String filename) {
    final videoExtensions = ['.mp4', '.webm', '.mov', '.avi', '.m4v'];
    return videoExtensions.any((ext) => filename.toLowerCase().endsWith(ext));
  }

  Color _getServiceColor(String service) {
    switch (service.toLowerCase()) {
      case 'fanbox':
        return Colors.blue[600]!;
      case 'patreon':
        return Colors.orange[600]!;
      case 'fantia':
        return Colors.purple[600]!;
      case 'afdian':
        return Colors.green[600]!;
      case 'boosty':
        return Colors.red[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }
}

/// Skeleton loader untuk post card
class PostCardSkeleton extends StatelessWidget {
  const PostCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Creator header skeleton
            Row(
              children: [
                _buildSkeleton(32, 32, BorderRadius.circular(16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSkeleton(120, 14, BorderRadius.circular(4)),
                      const SizedBox(height: 2),
                      _buildSkeleton(60, 10, BorderRadius.circular(4)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Title skeleton
            _buildSkeleton(double.infinity, 16, BorderRadius.circular(4)),
            const SizedBox(height: 8),

            // Media preview skeleton
            _buildSkeleton(double.infinity, 200, BorderRadius.circular(8)),
            const SizedBox(height: 8),

            // Meta skeleton
            Row(
              children: [
                _buildSkeleton(40, 12, BorderRadius.circular(4)),
                const SizedBox(width: 12),
                _buildSkeleton(60, 12, BorderRadius.circular(4)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton(
    double width,
    double height,
    BorderRadius borderRadius,
  ) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: borderRadius,
      ),
    );
  }
}

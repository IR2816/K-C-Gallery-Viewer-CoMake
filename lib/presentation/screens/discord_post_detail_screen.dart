import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/post_file.dart';
import '../../domain/entities/api_source.dart';
import '../../data/services/api_header_service.dart';
import '../providers/tracked_http_client.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../../utils/logger.dart';
import 'fullscreen_media_viewer.dart';
import 'video_player_screen.dart';
import '../widgets/app_video_player.dart';
import '../widgets/skeleton_loader.dart';

/// Screen untuk menampilkan detail post Discord
/// Discord posts sudah lengkap dari channel API, tidak perlu load additional data
class DiscordPostDetailScreen extends StatefulWidget {
  final Post post;

  const DiscordPostDetailScreen({super.key, required this.post});

  @override
  State<DiscordPostDetailScreen> createState() =>
      _DiscordPostDetailScreenState();
}

class _DiscordPostDetailScreenState extends State<DiscordPostDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showAllMedia = false;
  String? _mediaCacheKey;
  List<Map<String, dynamic>> _cachedMediaItems = [];
  String? _activeVideoUrl;
  final Map<String, Future<String?>> _contentTypeCache = {};
  static const double _singleMediaAspectRatio = 16 / 9;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _launchURL(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      AppLogger.warning('Failed to launch URL', tag: 'DiscordPost', error: e);
    }
  }

  String _formatDate(String dateString) {
    try {
      final dateTime = DateTime.parse(dateString);
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }


  bool _isImageFileName(String? filename) {
    if (filename == null) return false;
    final name = filename.toLowerCase();
    return name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.gif') ||
        name.endsWith('.webp');
  }

  bool _isGifFileName(String? filename) {
    if (filename == null) return false;
    return filename.toLowerCase().endsWith('.gif');
  }

  bool _isVideoFileName(String? filename) {
    if (filename == null) return false;
    final name = filename.toLowerCase();
    return name.endsWith('.mp4') ||
        name.endsWith('.webm') ||
        name.endsWith('.mov') ||
        name.endsWith('.avi') ||
        name.endsWith('.mkv') ||
        name.endsWith('.m4v');
  }

  bool _isImageAttachment(dynamic attachment) {
    final type = (attachment.type ?? '') as String;
    return type.startsWith('image/') || _isImageFileName(attachment.name);
  }

  bool _isGifAttachment(dynamic attachment) {
    final type = (attachment.type ?? '') as String;
    return type == 'image/gif' || _isGifFileName(attachment.name);
  }

  bool _isVideoAttachment(dynamic attachment) {
    final type = (attachment.type ?? '') as String;
    return type.startsWith('video/') || _isVideoFileName(attachment.name);
  }

  Future<String?> _getContentType(String url) {
    return _contentTypeCache.putIfAbsent(url, () async {
      try {
        final client = TrackedHttpClientFactory.getTrackedClient();
        final headers =
            ApiHeaderService.getMediaHeaders(referer: 'https://kemono.cr/');
        final response = await client
            .head(Uri.parse(url), headers: headers)
            .timeout(const Duration(seconds: 8));
        if (response.statusCode >= 200 && response.statusCode < 400) {
          return response.headers['content-type'];
        }
      } catch (e) {
        AppLogger.warning(
          'Failed to resolve content type for $url',
          tag: 'DiscordPost',
          error: e,
        );
      }
      return null;
    });
  }

  Future<bool> _isGifContent(String url) async {
    final contentType = await _getContentType(url);
    if (contentType == null) return true;
    return contentType.toLowerCase().contains('image/gif');
  }

  void _ensureMediaCache() {
    final key = '${widget.post.id}|${widget.post.attachments.length}';
    if (_mediaCacheKey == key) return;

    _cachedMediaItems = [];
    for (final attachment in widget.post.attachments) {
      if (attachment.path.isNotEmpty == true) {
        final path = attachment.path;
        final originalUrl = 'https://n2.kemono.cr/data$path';
        final thumbnailUrl = 'https://img.kemono.cr/thumbnail/data$path';
        final isImage = _isImageAttachment(attachment);
        final isVideo = _isVideoAttachment(attachment);
        final type = isImage ? 'image' : (isVideo ? 'video' : 'file');

        _cachedMediaItems.add({
          'url': originalUrl,
          'name': attachment.name,
          'type': type,
          'thumbnail_url': thumbnailUrl,
          'path': attachment.path,
          'attachment_type': attachment.type,
        });
      }
    }

    _mediaCacheKey = key;
    _activeVideoUrl = null;
  }

  void _openMediaFullscreen(Map<String, dynamic> mediaItem, int index) {
    final mediaType = mediaItem['type'] as String;

    if (mediaType == 'video') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(
            videoUrl: mediaItem['url'],
            videoName: mediaItem['name'] ?? 'Video',
            apiSource: ApiSource.kemono.name,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FullscreenMediaViewer(
            mediaItems: _cachedMediaItems,
            initialIndex: index,
            apiSource: ApiSource.kemono,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? const Color(0xFF1E1F22) : AppTheme.getBackgroundColor(context);
    final appBarColor =
        isDark ? const Color(0xFF2B2D31) : AppTheme.getSurfaceColor(context);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Discord Post',
          style: AppTheme.getTitleStyle(
            context,
          ).copyWith(color: AppTheme.getOnBackgroundColor(context)),
        ),
        backgroundColor: appBarColor,
        foregroundColor: AppTheme.getOnSurfaceColor(context),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.share), onPressed: _sharePost),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Discord posts don't need refresh, but we'll keep the gesture
          await Future.delayed(const Duration(milliseconds: 500));
        },
        color: AppTheme.primaryColor,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCreatorHeader(),
              _buildMediaSection(),
              _buildDownloadLinksSection(),
              _buildPostContent(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreatorHeader() {
    final accentColor = const Color(0xFF5865F2);
    final surfaceColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2B2D31)
        : AppTheme.getSurfaceColor(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppTheme.mdPadding,
        AppTheme.mdPadding,
        AppTheme.mdPadding,
        0,
      ),
      padding: const EdgeInsets.all(AppTheme.mdPadding),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Discord Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Text(
                    widget.post.user.isNotEmpty
                        ? widget.post.user[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.post.user,
                          style: AppTheme.getBodyStyle(context).copyWith(
                            color: AppTheme.getOnSurfaceColor(context),
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'DISCORD',
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(widget.post.published.toIso8601String()),
                      style: AppTheme.getCaptionStyle(
                        context,
                      ).copyWith(color: AppTheme.secondaryTextColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.tag, size: 16, color: AppTheme.secondaryTextColor),
              const SizedBox(width: 4),
              Text(
                'Service: ${widget.post.service}',
                style: AppTheme.getCaptionStyle(
                  context,
                ).copyWith(color: AppTheme.secondaryTextColor),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.chat_bubble_outline,
                size: 16,
                color: AppTheme.secondaryTextColor,
              ),
              const SizedBox(width: 4),
              Text(
                'Post ID: ${widget.post.id}',
                style: AppTheme.getCaptionStyle(
                  context,
                ).copyWith(color: AppTheme.secondaryTextColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMediaSection() {
    _ensureMediaCache();
    final settings = context.watch<SettingsProvider>();
    final imageFit = settings.imageFitMode;
    final autoplayVideo = settings.autoplayVideo;
    final useThumbnails = settings.loadThumbnails;
    final attachments = widget.post.attachments;
    if (attachments.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(AppTheme.mdPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Media (${attachments.length})',
                style: AppTheme.getBodyStyle(context).copyWith(
                  color: AppTheme.getOnSurfaceColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (attachments.length > 4)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showAllMedia = !_showAllMedia;
                    });
                  },
                  child: Text(
                    _showAllMedia ? 'Show Less' : 'Show All',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildMediaGrid(
            attachments,
            imageFit: imageFit,
            autoplayVideo: autoplayVideo,
            useThumbnails: useThumbnails,
          ),
        ],
      ),
    );
  }

  Widget _buildMediaGrid(
    List attachments, {
    required BoxFit imageFit,
    required bool autoplayVideo,
    required bool useThumbnails,
  }) {
    final displayCount = _showAllMedia
        ? attachments.length
        : (attachments.length > 4 ? 4 : attachments.length);
    final displayAttachments = attachments.take(displayCount).toList();
    final mediaItems = _cachedMediaItems.take(displayCount).toList();

    if (displayAttachments.length == 1) {
      return _buildSingleMedia(
        displayAttachments.first,
        mediaItems.first,
        imageFit: imageFit,
        autoplayVideo: autoplayVideo,
        useThumbnails: useThumbnails,
      );
    }

    return StaggeredGrid.count(
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: displayAttachments.asMap().entries.map((entry) {
        final index = entry.key;
        final attachment = entry.value;
        final mediaItem = mediaItems[index];
        final heroTag = 'discord_media_${widget.post.id}_$index';

        return StaggeredGridTile.fit(
          crossAxisCellCount: 1,
          child: _buildMediaItem(
            attachment,
            mediaItem,
            heroTag,
            imageFit: imageFit,
            autoplayVideo: autoplayVideo,
            useThumbnails: useThumbnails,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSingleMedia(
    PostFile attachment,
    Map<String, dynamic> mediaItem, {
    required BoxFit imageFit,
    required bool autoplayVideo,
    required bool useThumbnails,
  }) {
    final heroTag = 'discord_media_${widget.post.id}_single';
    final isImage = _isImageAttachment(attachment);
    final isVideo = _isVideoAttachment(attachment);
    final isGif = _isGifAttachment(attachment);
    final rawUrl = mediaItem['url'] as String;
    final thumbnailUrl = mediaItem['thumbnail_url'] as String?;
    final displayUrl =
        useThumbnails && thumbnailUrl != null && thumbnailUrl.isNotEmpty
            ? thumbnailUrl
            : rawUrl;

    if (isImage) {
      Widget imageWidget() {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GestureDetector(
            onTap: () => _openMediaFullscreen(mediaItem, 0),
            child: Hero(
              tag: heroTag,
              child: AspectRatio(
                aspectRatio: _singleMediaAspectRatio,
                child: _buildImageWithLayout(
                  displayUrl,
                  rawUrl,
                  fit: imageFit,
                ),
              ),
            ),
          ),
        );
      }

      if (isGif) {
        return FutureBuilder<bool>(
          future: _isGifContent(rawUrl),
          builder: (context, snapshot) {
            final confirmedGif = snapshot.data ?? true;
            if (!confirmedGif) {
              return imageWidget();
            }
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GestureDetector(
                onTap: () => _openMediaFullscreen(mediaItem, 0),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    color: Colors.black,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.gif, color: Colors.white70, size: 40),
                          SizedBox(height: 6),
                          Text(
                            'Tap to load GIF',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }
      return imageWidget();
    }

    if (isVideo) {
      return _buildVideoItem(
        mediaItem,
        height: 220,
        autoplayVideo: autoplayVideo,
      );
    }

    return _buildFileItem(attachment);
  }

  Widget _buildMediaItem(
    PostFile attachment,
    Map<String, dynamic> mediaItem,
    String heroTag, {
    required BoxFit imageFit,
    required bool autoplayVideo,
    required bool useThumbnails,
  }) {
    final isImage = _isImageAttachment(attachment);
    final isVideo = _isVideoAttachment(attachment);
    final isGif = _isGifAttachment(attachment);
    final rawUrl = mediaItem['url'] as String;
    final thumbnailUrl = mediaItem['thumbnail_url'] as String?;
    final displayUrl =
        useThumbnails && thumbnailUrl != null && thumbnailUrl.isNotEmpty
            ? thumbnailUrl
            : rawUrl;

    if (isImage) {
      Widget imageWidget() {
        return GestureDetector(
          onTap: () => _openMediaFullscreen(mediaItem, 0),
          child: Hero(
            tag: heroTag,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 1,
                child: _buildImageWithLayout(
                  displayUrl,
                  rawUrl,
                  fit: imageFit,
                ),
              ),
            ),
          ),
        );
      }

      if (isGif) {
        return FutureBuilder<bool>(
          future: _isGifContent(rawUrl),
          builder: (context, snapshot) {
            final confirmedGif = snapshot.data ?? true;
            if (!confirmedGif) {
              return imageWidget();
            }
            return GestureDetector(
              onTap: () => _openMediaFullscreen(mediaItem, 0),
              child: Hero(
                tag: heroTag,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      color: Colors.black,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.gif, color: Colors.white70, size: 32),
                            SizedBox(height: 6),
                            Text(
                              'Tap to load GIF',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }
      return imageWidget();
    }

    if (isVideo) {
      return _buildVideoItem(
        mediaItem,
        height: 180,
        autoplayVideo: autoplayVideo,
      );
    }

    return _buildFileItem(attachment);
  }


  Widget _buildVideoItem(
    Map<String, dynamic> mediaItem, {
    double height = 200,
    required bool autoplayVideo,
  }) {
    final videoUrl = mediaItem['url'] as String;
    final thumbnailUrl = mediaItem['thumbnail_url'] as String?;
    final shouldAutoPlay = autoplayVideo;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        child: (shouldAutoPlay || _activeVideoUrl == videoUrl)
            ? AppVideoPlayer(
                url: videoUrl,
                height: height,
                autoplay: shouldAutoPlay || _activeVideoUrl == videoUrl,
                apiSource: ApiSource.kemono.name,
              )
            : _buildVideoPlaceholder(videoUrl, thumbnailUrl, height),
      ),
    );
  }
                  ),
                ),
              )
            else
              void Container(
                color = Colors.black,
                child = const Center(
                  child: Icon(Icons.videocam, color: Colors.white70, size: 40),
                ),
              ),
            void Container(color = Colors.black.withValues(alpha: 0.35)),
            void Center(
              child = Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.play_circle_fill, color: Colors.white, size: 48),
                  SizedBox(height: 6),
                  Text(
                    'Tap to load video',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileItem(PostFile attachment) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getAttachmentIcon(attachment.type ?? ''),
            color: AppTheme.primaryColor,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            attachment.name,
            style: AppTheme.getBodyStyle(context).copyWith(
              color: AppTheme.getOnSurfaceColor(context),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildImageWithLayout(
    String displayUrl,
    String rawUrl, {
    required BoxFit fit,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.of(context).devicePixelRatio;
        final memCacheWidth = constraints.maxWidth.isFinite
            ? (constraints.maxWidth * dpr).round()
            : null;
        final memCacheHeight = constraints.maxHeight.isFinite
            ? (constraints.maxHeight * dpr).round()
            : null;
        return _buildImageWidget(
          displayUrl,
          rawUrl,
          fit: fit,
          memCacheWidth: memCacheWidth,
          memCacheHeight: memCacheHeight,
        );
      },
    );
  }

  Widget _buildImageWidget(
    String displayUrl,
    String rawUrl, {
    required BoxFit fit,
    int? memCacheWidth,
    int? memCacheHeight,
  }) {
    return CachedNetworkImage(
      imageUrl: displayUrl,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      placeholder: (context, url) => Container(
        color: Colors.grey[900],
        child: const AppSkeleton(shape: BoxShape.rectangle),
      ),
      errorWidget: (context, url, error) {
        if (displayUrl != rawUrl && rawUrl.isNotEmpty) {
          return CachedNetworkImage(
            imageUrl: rawUrl,
            fit: fit,
            memCacheWidth: memCacheWidth,
            memCacheHeight: memCacheHeight,
            placeholder: (context, url) => Container(
              color: Colors.grey[900],
              child: const AppSkeleton(shape: BoxShape.rectangle),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[900],
              child: const Center(
                child: Icon(
                  Icons.broken_image,
                  color: Colors.white54,
                  size: 32,
                ),
              ),
            ),
          );
        }
        return Container(
          color: Colors.grey[900],
          child: const Center(
            child: Icon(
              Icons.broken_image,
              color: Colors.white54,
              size: 32,
            ),
          ),
        );
      },
    );
  }

  Widget _buildDownloadLinksSection() {
    _ensureMediaCache();
    final attachments = widget.post.attachments;
    if (attachments.isEmpty) return const SizedBox.shrink();
    final accentColor = const Color(0xFF5865F2);
    final surfaceColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2B2D31)
        : AppTheme.getSurfaceColor(context);

    return Container(
      margin: const EdgeInsets.all(AppTheme.mdPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attachments',
            style: AppTheme.getBodyStyle(context).copyWith(
              color: AppTheme.getOnSurfaceColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...attachments.map(
            (attachment) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.getOnSurfaceColor(context).withValues(alpha: 0.1),
                  ),
                ),
                child: InkWell(
                  onTap: () async {
                    final attachmentUrl = attachment.path.isNotEmpty == true
                        ? 'https://n2.kemono.cr/data${attachment.path}'
                        : null;

                    if (attachmentUrl != null) {
                      await _launchURL(attachmentUrl);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      Icon(
                        _getAttachmentIcon(attachment.type ?? ''),
                        color: accentColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              attachment.name,
                              style: AppTheme.getBodyStyle(context).copyWith(
                                color: AppTheme.getOnSurfaceColor(context),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              (attachment.type ?? '').startsWith('image/')
                                  ? 'Image • Tap to view'
                                  : 'File • Tap to download',
                              style: AppTheme.getCaptionStyle(
                                context,
                              ).copyWith(color: AppTheme.secondaryTextColor),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.open_in_new,
                        color: accentColor,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostContent() {
    if (widget.post.content.isEmpty) return const SizedBox.shrink();
    final surfaceColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF313338)
        : AppTheme.getSurfaceColor(context);

    return Container(
      margin: const EdgeInsets.all(AppTheme.mdPadding),
      padding: const EdgeInsets.all(AppTheme.mdPadding),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Message',
            style: AppTheme.getBodyStyle(context).copyWith(
              color: AppTheme.getOnSurfaceColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SelectableLinkify(
            text: widget.post.content,
            style: AppTheme.getBodyStyle(
              context,
            ).copyWith(color: AppTheme.getOnSurfaceColor(context), height: 1.5),
            linkStyle: TextStyle(
              color: AppTheme.primaryColor,
              decoration: TextDecoration.underline,
            ),
            onOpen: (link) async {
              await _launchURL(link.url);
            },
          ),
        ],
      ),
    );
  }

  void _sharePost() {
    // Basic share functionality
    // You can implement share_plus package here if needed
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Share functionality coming soon!'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  IconData _getAttachmentIcon(String type) {
    if (type.startsWith('image/')) return Icons.image;
    if (type.startsWith('video/')) return Icons.videocam;
    if (type.startsWith('audio/')) return Icons.audiotrack;
    if (type.contains('pdf')) return Icons.picture_as_pdf;
    if (type.contains('zip') || type.contains('rar')) return Icons.archive;
    return Icons.insert_drive_file;
  }
}

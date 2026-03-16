import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/api_source.dart';
import '../../providers/discord_provider.dart';
import '../../data/services/api_header_service.dart';
import '../providers/tracked_http_client.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/app_state_widgets.dart';
import '../../utils/logger.dart';
import 'fullscreen_media_viewer.dart';
import 'video_player_screen.dart';

/// Screen untuk menampilkan posts dalam channel Discord
class DiscordChannelPostsScreen extends StatefulWidget {
  final String channelId;
  final String channelName;

  const DiscordChannelPostsScreen({
    super.key,
    required this.channelId,
    required this.channelName,
  });

  @override
  State<DiscordChannelPostsScreen> createState() =>
      _DiscordChannelPostsScreenState();
}

class _DiscordChannelPostsScreenState extends State<DiscordChannelPostsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  final Map<String, List<Map<String, dynamic>>> _mediaCache = {};
  final Map<String, Future<String?>> _contentTypeCache = {};
  static const double _singleMediaAspectRatio = 16 / 9;

  @override
  void initState() {
    super.initState();
    _loadInitialPosts();
    _setupScrollListener();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.userScrollDirection !=
          ScrollDirection.reverse) {
        return;
      }
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMorePosts();
      }
    });
  }

  void _loadInitialPosts() {
    context.read<DiscordProvider>().loadChannelPosts(widget.channelId);
  }

  void _loadMorePosts() {
    if (_isLoadingMore) return;

    final provider = context.read<DiscordProvider>();
    final currentPosts = provider.getPostsForChannel(widget.channelId);

    if (!provider.isLoadingPosts && currentPosts.isNotEmpty) {
      setState(() => _isLoadingMore = true);

      // Calculate next offset based on current posts count
      final nextOffset = currentPosts.length;

      provider
          .loadChannelPosts(widget.channelId, offset: nextOffset)
          .then((_) {
            if (!mounted) return;
            setState(() => _isLoadingMore = false);
          })
          .catchError((_) {
            if (!mounted) return;
            setState(() => _isLoadingMore = false);
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1F22) : AppTheme.getBackgroundColor(context);
    final appBarColor = isDark ? const Color(0xFF2B2D31) : AppTheme.getSurfaceColor(context);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.indigoAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.tag_rounded, size: 18, color: Colors.indigoAccent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.channelName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: -0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Consumer<DiscordProvider>(
        builder: (context, provider, child) {
          final currentPosts = provider.getPostsForChannel(widget.channelId);

          if (provider.isLoadingPosts && currentPosts.isEmpty) {
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: 6,
              itemBuilder: (context, index) => const DiscordMessageSkeleton(),
            );
          }

          if (provider.postsError != null && currentPosts.isEmpty) {
            return _buildErrorState(provider.postsError!, _loadInitialPosts);
          }

          if (currentPosts.isEmpty) {
            return _buildEmptyState();
          }

          return _buildPostsList(provider);
        },
      ),
    );
  }

  Widget _buildPostsList(DiscordProvider provider) {
    final currentPosts = provider.getPostsForChannel(widget.channelId);
    final settings = context.watch<SettingsProvider>();

    return RefreshIndicator(
      onRefresh: () async {
        await provider.loadChannelPosts(widget.channelId);
      },
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        cacheExtent: 800,
        addAutomaticKeepAlives: false,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: currentPosts.length + (_isLoadingMore ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (_isLoadingMore && index == currentPosts.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: const SizedBox(
                  width: 18,
                  height: 18,
                  child: AppSkeleton(shape: BoxShape.circle),
                ),
              ),
            );
          }

          final post = currentPosts[index];
          return _buildMessageItem(post, settings);
        },
      ),
    );
  }

  Widget _buildMessageItem(Post post, SettingsProvider settings) {
    final userColor = _getUserColor(post.user);
    final timeText = _formatDate(post.published.toIso8601String());
    final isEdited = post.edited.isAfter(post.published);
    final headerMeta = isEdited ? '$timeText - edited' : timeText;
    final hasText = post.title.isNotEmpty || post.content.isNotEmpty;
    final mediaItems = _getMediaItems(post);
    final visualMedia = mediaItems.where((item) => item['type'] != 'file').toList();
    final fileItems = mediaItems.where((item) => item['type'] == 'file').toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildUserAvatar(post.user, userColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        post.user,
                        style: AppTheme.getBodyStyle(context).copyWith(
                          color: userColor,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      headerMeta,
                      style: AppTheme.getCaptionStyle(context).copyWith(color: AppTheme.secondaryTextColor),
                    ),
                  ],
                ),
                if (hasText) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.getCardColor(context),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                      border: Border.all(color: AppTheme.getBorderColor(context).withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.05 : 0.4)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.1 : 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (post.title.isNotEmpty) ...[
                          Text(
                            post.title,
                            style: AppTheme.getBodyStyle(context).copyWith(
                              color: AppTheme.getOnSurfaceColor(context),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (post.content.isNotEmpty)
                            const SizedBox(height: 6),
                        ],
                        if (post.content.isNotEmpty)
                          Linkify(
                            text: post.content,
                            style: AppTheme.getBodyStyle(context).copyWith(
                              color: AppTheme.getOnSurfaceColor(context),
                            ),
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
                  ),
                ],
                if (visualMedia.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildMediaGrid(visualMedia, settings),
                ],
                if (fileItems.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Column(
                    children:
                        fileItems.map((item) => _buildFileRow(item)).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      AppLogger.warning('Failed to launch URL', tag: 'DiscordPosts', error: e);
    }
  }

  List<Map<String, dynamic>> _getMediaItems(Post post) {
    return _mediaCache.putIfAbsent(post.id, () {
      final items = <Map<String, dynamic>>[];
      final allFiles = [...post.attachments, ...post.file];

      for (final attachment in allFiles) {
        final path = attachment.path;
        if (path.isEmpty) continue;

        String rawUrl;
        if (path.startsWith('http')) {
          rawUrl = path;
        } else if (path.startsWith('//')) {
          rawUrl = 'https:$path';
        } else {
          rawUrl = 'https://n2.kemono.cr/data$path';
        }

        String thumbnailUrl;
        if (path.startsWith('http')) {
          thumbnailUrl = path;
        } else if (path.startsWith('//')) {
          thumbnailUrl = 'https:$path';
        } else {
          thumbnailUrl = 'https://img.kemono.cr/thumbnail/data$path';
        }

        final isImage = _isImageAttachment(attachment);
        final isVideo = _isVideoAttachment(attachment);
        final isGif = _isGifAttachment(attachment);
        final type = isImage ? 'image' : (isVideo ? 'video' : 'file');

        items.add({
          'url': rawUrl,
          'thumbnail_url': thumbnailUrl,
          'type': type,
          'is_gif': isGif,
          'name': attachment.name,
          'path': path,
          'attachment_type': attachment.type,
        });
      }

      return items;
    });
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
          tag: 'DiscordPosts',
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

  Widget _buildMediaGrid(
    List<Map<String, dynamic>> mediaItems,
    SettingsProvider settings,
  ) {
    if (mediaItems.length == 1) {
      return _buildMediaTile(
        mediaItems.first,
        0,
        mediaItems,
        settings,
        isSingle: true,
      );
    }

    return StaggeredGrid.count(
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: mediaItems.asMap().entries.map((entry) {
        return StaggeredGridTile.fit(
          crossAxisCellCount: 1,
          child: _buildMediaTile(
            entry.value,
            entry.key,
            mediaItems,
            settings,
            isSingle: false,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMediaTile(
    Map<String, dynamic> item,
    int index,
    List<Map<String, dynamic>> mediaItems,
    SettingsProvider settings, {
    required bool isSingle,
  }) {
    final type = item['type'] as String? ?? 'file';
    final rawUrl = item['url'] as String? ?? '';
    final thumbnailUrl = item['thumbnail_url'] as String?;
    final isGif = item['is_gif'] == true;
    final displayUrl = settings.loadThumbnails && (thumbnailUrl ?? '').isNotEmpty
        ? thumbnailUrl!
        : rawUrl;

    if (type == 'image') {
      if (isGif) {
        return FutureBuilder<bool>(
          future: _isGifContent(rawUrl),
          builder: (context, snapshot) {
            final confirmedGif = snapshot.data ?? true;
            if (!confirmedGif) {
              return GestureDetector(
                onTap: () => _openMedia(mediaItems, index),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio:
                        isSingle ? _singleMediaAspectRatio : 1,
                    child: _buildImageWithLayout(
                      displayUrl,
                      rawUrl,
                      fit: settings.imageFitMode,
                    ),
                  ),
                ),
              );
            }
            return GestureDetector(
              onTap: () => _openMedia(mediaItems, index),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: isSingle ? 16 / 9 : 1,
                  child: Container(
                    color: Colors.black,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.gif, color: Colors.white70, size: 36),
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
      return GestureDetector(
        onTap: () => _openMedia(mediaItems, index),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AspectRatio(
            aspectRatio: isSingle ? _singleMediaAspectRatio : 1,
            child: _buildImageWithLayout(
              displayUrl,
              rawUrl,
              fit: isSingle ? settings.imageFitMode : BoxFit.cover,
            ),
          ),
        ),
      );
    }

    if (type == 'video') {
      return GestureDetector(
        onTap: () => _openMedia(mediaItems, index),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AspectRatio(
            aspectRatio: isSingle ? 16 / 9 : 1,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final dpr = MediaQuery.of(context).devicePixelRatio;
                final memCacheWidth = constraints.maxWidth.isFinite
                    ? (constraints.maxWidth * dpr).round()
                    : null;
                final memCacheHeight = constraints.maxHeight.isFinite
                    ? (constraints.maxHeight * dpr).round()
                    : null;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (displayUrl.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: displayUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: memCacheWidth,
                        memCacheHeight: memCacheHeight,
                        placeholder: (context, url) => Container(
                          color: Colors.black,
                          child: const AppSkeleton(shape: BoxShape.rectangle),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.black,
                          child: const Center(
                            child: Icon(
                              Icons.videocam,
                              color: Colors.white70,
                              size: 36,
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        color: Colors.black,
                        child: const Center(
                          child: Icon(
                            Icons.videocam,
                            color: Colors.white70,
                            size: 36,
                          ),
                        ),
                      ),
                    Container(color: Colors.black.withValues(alpha: 0.35)),
                    const Center(
                      child: Icon(
                        Icons.play_circle_fill,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    }

    return _buildFileRow(item);
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
                child: Icon(Icons.broken_image, color: Colors.white54),
              ),
            ),
          );
        }
        return Container(
          color: Colors.grey[900],
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.white54),
          ),
        );
      },
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

  void _openMedia(List<Map<String, dynamic>> mediaItems, int index) {
    final item = mediaItems[index];
    final type = item['type'] as String? ?? 'file';

    if (type == 'video') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(
            videoUrl: item['url'] as String? ?? '',
            videoName: item['name'] as String? ?? 'Video',
            apiSource: ApiSource.kemono.name,
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullscreenMediaViewer(
          mediaItems: mediaItems,
          initialIndex: index,
          apiSource: ApiSource.kemono,
        ),
      ),
    );
  }

  Widget _buildFileRow(Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? 'File';
    final url = item['url']?.toString() ?? '';
    final type = item['attachment_type']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2B2D31)
            : AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: url.isNotEmpty ? () => _launchURL(url) : null,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  _getAttachmentIcon(type),
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: AppTheme.getBodyStyle(context).copyWith(
                      color: AppTheme.getOnSurfaceColor(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.open_in_new,
                  size: 16,
                  color: AppTheme.primaryColor.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
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

  Widget _buildErrorState(String error, VoidCallback onRetry) {
    return AppErrorState(
      title: 'Error loading posts',
      message: error,
      onRetry: onRetry,
    );
  }

  Widget _buildEmptyState() {
    return const AppEmptyState(
      icon: Icons.message_outlined,
      title: 'No messages found',
      message: 'This channel doesn\'t have any messages yet',
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
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
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildUserAvatar(String name, Color color) {
    final label = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Color _getUserColor(String name) {
    final palette = [
      Colors.indigo,
      Colors.teal,
      Colors.orange,
      Colors.purple,
      Colors.blueGrey,
      Colors.green,
      Colors.cyan,
    ];
    final hash = name.hashCode & 0x7fffffff;
    return palette[hash % palette.length];
  }
}

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:html/parser.dart' as html_parser;

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/services/api_header_service.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/api_source.dart';
import '../../domain/entities/comment.dart';
import '../../domain/entities/creator.dart';
import '../../utils/logger.dart';
import '../providers/posts_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/comments_provider.dart';
import '../providers/download_provider.dart';
import '../theme/app_theme.dart';
import 'fullscreen_media_viewer.dart';
import 'creator_detail_screen.dart';
import 'video_player_screen.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/comments_bottom_sheet.dart';
import '../widgets/app_video_player.dart';

/// Post link model for unified link handling
class PostLink {
  final String url;
  final String source; // content | file | attachment
  final String? label;

  PostLink({required this.url, required this.source, this.label});

  @override
  String toString() => 'PostLink(url: $url, source: $source, label: $label)';
}

class PostDetailScreen extends StatefulWidget {
  final Post post;
  final ApiSource apiSource;
  final bool isFromSavedPosts;

  const PostDetailScreen({
    super.key,
    required this.post,
    required this.apiSource,
    this.isFromSavedPosts = false,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;

  bool _isLoading = false;
  String? _error;
  bool _showAllMedia = false;
  String? _mediaCacheKey;
  List<Map<String, dynamic>> _cachedMediaItems = [];
  List<Map<String, dynamic>> _cachedVideoItems = [];
  List<Map<String, dynamic>> _cachedAudioItems = [];
  String? _activeVideoUrl;

  // Audio player state with enhanced controls
  AudioPlayer? _audioPlayer;
  String? _currentlyPlayingAudio;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLooping = false; // Loop control
  bool _isShuffling = false; // Shuffle control
  List<Map<String, dynamic>> _audioPlaylist = []; // Playlist management
  int _currentAudioIndex = 0;

  Post? _fullPost;
  bool _isRefreshingContent = false;
  late ApiSource _activeApiSource;
  bool _isSwitchingSource = false;

  @override
  void initState() {
    super.initState();
    _activeApiSource = widget.apiSource;
    _tabController = TabController(length: 2, vsync: this);

    // Initialize audio player
    _audioPlayer = AudioPlayer();

    // Set up audio player listeners with lifecycle guards and enhanced features
    _audioPlayer!.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() => _duration = duration);
    });

    _audioPlayer!.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
    });

    _audioPlayer!.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state == PlayerState.playing);
    });

    _audioPlayer!.onPlayerComplete.listen((_) {
      if (!mounted) return;
      if (_isLooping) {
        _audioPlayer!.seek(Duration.zero);
        _audioPlayer!.resume();
      } else if (_isShuffling ||
          _currentAudioIndex < _audioPlaylist.length - 1) {
        _playNextAudio();
      } else {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });

    // Preload comments for immediate preview
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadComments();
    });

    // Load full post data only if not from saved posts
    if (!widget.isFromSavedPosts) {
      _loadFullPost();
    } else {
      // For saved posts, use the post directly as it's already complete
      setState(() {
        _fullPost = widget.post;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  /// Preload comments for immediate preview
  void _preloadComments() {
    final commentsProvider = context.read<CommentsProvider>();
    commentsProvider.loadComments(
      widget.post.id,
      widget.post.service,
      widget.post.user,
    );
  }

  /// Load full post data from single post API
  Future<void> _loadFullPost() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final postsProvider = context.read<PostsProvider>();

      // Force fresh API call by clearing any existing cache
      await postsProvider.loadSinglePost(
        widget.post.service, // service FIRST
        widget.post.user, // creatorId SECOND
        widget.post.id, // postId THIRD
        apiSource: _activeApiSource,
      );

      // Get the updated post data from provider
      final updatedPost = postsProvider.posts
          .where((p) => p.id == widget.post.id)
          .firstOrNull;

      if (updatedPost != null) {
        if (mounted) {
          setState(() {
            _fullPost = updatedPost;
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Post not found after refresh');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _fullPost = widget.post; // Fallback to original post
        });
      }
    }
  }

  /// Get current post (full post if available, otherwise original post)
  Post get _currentPost => _fullPost ?? widget.post;

  Future<void> _switchApiSource(ApiSource targetSource) async {
    if (_isSwitchingSource || targetSource == _activeApiSource) {
      return;
    }

    HapticFeedback.lightImpact();
    _showDomainTransitionAnimation(_activeApiSource, targetSource);

    setState(() {
      _isSwitchingSource = true;
      _activeApiSource = targetSource;
      _cachedMediaItems = [];
      _cachedVideoItems = [];
      _cachedAudioItems = [];
      _mediaCacheKey = null;
      _cachedLinks = null;
      _cachedContentHash = null;
      _fullPost = null;
    });

    try {
      await _loadFullPost();
      if (mounted) {
        final commentsProvider = context.read<CommentsProvider>();
        commentsProvider.clearComments();
        await commentsProvider.loadComments(
          widget.post.id,
          widget.post.service,
          widget.post.user,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSwitchingSource = false;
        });
      }
    }
  }

  void _showDomainTransitionAnimation(ApiSource from, ApiSource to) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    final fromLabel = from == ApiSource.kemono ? 'Kemono' : 'Coomer';
    final toLabel = to == ApiSource.kemono ? 'Kemono' : 'Coomer';
    final accent = to == ApiSource.kemono
        ? AppTheme.primaryColor
        : AppTheme.accentColor;

    entry = OverlayEntry(
      builder: (context) => IgnorePointer(
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 460),
          tween: Tween(begin: 0, end: 1),
          curve: Curves.easeOutCubic,
          onEnd: () => entry.remove(),
          builder: (context, value, child) {
            return ColoredBox(
              color: Colors.black.withValues(alpha: 0.18 * (1 - value)),
              child: Center(
                child: Opacity(
                  opacity: (1 - (value - 0.65).clamp(0, 0.35) / 0.35).clamp(
                    0,
                    1,
                  ),
                  child: Transform.scale(
                    scale: 0.92 + (0.08 * value),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.darkCardColor.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.55),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.28),
                            blurRadius: 16,
                            spreadRadius: -8,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            fromLabel,
                            style: const TextStyle(
                              color: AppTheme.darkSecondaryTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: accent,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            toLabel,
                            style: TextStyle(
                              color: accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
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
        ),
      ),
    );
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        toolbarHeight: 84,
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.getOnSurfaceColor(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                (_activeApiSource == ApiSource.kemono
                        ? AppTheme.primaryColor
                        : AppTheme.accentColor)
                    .withValues(
                      alpha: Theme.of(context).brightness == Brightness.dark
                          ? 0.16
                          : 0.08,
                    ),
                Colors.transparent,
              ],
            ),
          ),
        ),
        titleSpacing: 16,
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (bounds) =>
                  AppTheme.primaryGradient.createShader(bounds),
              child: Text(
                'Post Detail',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                  color: AppTheme.getPrimaryTextColor(context),
                  letterSpacing: -0.9,
                  height: 1,
                ),
              ),
            ),
            Text(
              _activeApiSource == ApiSource.kemono
                  ? 'Viewing from Kemono'
                  : 'Viewing from Coomer',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.getSecondaryTextColor(context, opacity: 0.85),
              ),
            ),
          ],
        ),
        actions: [],
      ),
      // Removing Bottom Action Bar for social media inline layout
      body: _isLoading
          ? const SingleChildScrollView(child: DetailScreenSkeleton())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppTheme.errorColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading post',
                    style: AppTheme.titleStyle.copyWith(
                      color: AppTheme.errorColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: AppTheme.captionStyle.copyWith(
                      color: AppTheme.secondaryTextColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadFullPost,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.getBackgroundColor(context),
                          AppTheme.getBackgroundColor(
                            context,
                          ).withValues(alpha: 0.98),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -120,
                  left: -60,
                  child: Container(
                    width: 230,
                    height: 230,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.primaryColor.withValues(
                            alpha:
                                Theme.of(context).brightness == Brightness.dark
                                ? 0.08
                                : 0.04,
                          ),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 40,
                  right: -80,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.accentColor.withValues(
                            alpha:
                                Theme.of(context).brightness == Brightness.dark
                                ? 0.06
                                : 0.03,
                          ),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                RefreshIndicator(
                  onRefresh: _refreshContent,
                  color: AppTheme.primaryColor,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        _buildCreatorHeader(), // Updated: No margin/padding, clean row
                        _buildMediaSection(), // Updated: Edge-to-edge
                        _buildVideoSection(), // Updated: Edge-to-edge
                        _buildSocialActionBar(), // NEW: Inline action bar
                        _buildPostContent(),
                        if (_currentPost.tags.isNotEmpty) _buildTagsSection(),
                        _buildAudioSection(),
                        _buildDownloadLinksSection(),
                        _buildCommentsSection(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // New modern inline action bar mimicking Instagram/Twitter
  Widget _buildSocialActionBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          // Like / Save
          GestureDetector(
            onTap: _toggleSave,
            child: Icon(
              _currentPost.saved ? Icons.favorite : Icons.favorite_border,
              color: _currentPost.saved
                  ? Colors.red
                  : AppTheme.getPrimaryTextColor(context),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          // Share
          GestureDetector(
            onTap: _sharePost,
            child: Icon(
              Icons.send_rounded, // or Icons.share_rounded
              color: AppTheme.getPrimaryTextColor(context),
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          // Download All
          GestureDetector(
            onTap: _downloadAllFiles,
            child: Icon(
              Icons.download_rounded,
              color: AppTheme.getPrimaryTextColor(context),
              size: 28,
            ),
          ),
          const Spacer(),
          // Source link
          GestureDetector(
            onTap: _launchSourceUrl,
            child: Icon(
              Icons.open_in_browser_rounded,
              color: AppTheme.getPrimaryTextColor(context),
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildSourceControlCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.getBorderColor(context).withValues(alpha: 0.85),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.2
                  : 0.08,
            ),
            blurRadius: 16,
            spreadRadius: -8,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_sync_rounded,
            size: 18,
            color: AppTheme.getSecondaryTextColor(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Switch source and reload instantly',
              style: TextStyle(
                color: AppTheme.getSecondaryTextColor(context, opacity: 0.95),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppTheme.getElevatedSurfaceColorContext(
                context,
              ).withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.16)
                    : Colors.black.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildApiSourceChip(
                  source: ApiSource.kemono,
                  label: 'Kemono',
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 4),
                _buildApiSourceChip(
                  source: ApiSource.coomer,
                  label: 'Coomer',
                  color: AppTheme.accentColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiSourceChip({
    required ApiSource source,
    required String label,
    required Color color,
  }) {
    final isActive = source == _activeApiSource;
    return GestureDetector(
      onTap: _isSwitchingSource ? null : () => _switchApiSource(source),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.98),
                    color.withValues(alpha: 0.72),
                  ],
                )
              : null,
          color: isActive ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isActive
                ? color.withValues(alpha: 0.95)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive
                ? Colors.white
                : AppTheme.getSecondaryTextColor(context),
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCreatorHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Creator Avatar
          GestureDetector(
            onTap: _navigateToCreatorDetail,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.getBorderColor(
                    context,
                  ).withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: ClipOval(child: _buildCreatorAvatar()),
            ),
          ),
          const SizedBox(width: 12),
          // Creator Name & Info
          Expanded(
            child: GestureDetector(
              onTap: _navigateToCreatorDetail,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _currentPost.user,
                          style: TextStyle(
                            color: AppTheme.getPrimaryTextColor(context),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.verified,
                        size: 14,
                        color: AppTheme.primaryColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_getServiceDisplayName()} • ${_formatDate(_currentPost.published.toString())}',
                    style: TextStyle(
                      color: AppTheme.getSecondaryTextColor(context),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // More Options Placeholder
          IconButton(
            icon: Icon(
              Icons.more_vert,
              color: AppTheme.getPrimaryTextColor(context),
            ),
            onPressed: () {
              // Placeholder for more actions like report, unfollow, copy link natively
            },
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildInfoChip({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.getElevatedSurfaceColorContext(
          context,
        ).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.getBorderColor(context).withValues(alpha: 0.75),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.getSecondaryTextColor(context)),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: AppTheme.getSecondaryTextColor(context),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaSection() {
    _ensureMediaCache();
    final mediaItems = _cachedMediaItems;
    final settings = context.watch<SettingsProvider>();
    final imageFit = settings.imageFitMode;
    final useThumbnails = settings.loadThumbnails;

    if (mediaItems.isEmpty) {
      return const SizedBox.shrink();
    }

    const maxPreviewItems = 6;
    final hasManyItems = mediaItems.length > maxPreviewItems;
    final displayItems = _showAllMedia
        ? mediaItems
        : (hasManyItems
              ? mediaItems.take(maxPreviewItems).toList()
              : mediaItems);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMediaGrid(
          displayItems,
          imageFit: imageFit,
          useThumbnails: useThumbnails,
        ),
        if (hasManyItems) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _buildExpandCollapseButton(mediaItems.length),
          ),
        ],
      ],
    );
  }

  void _ensureMediaCache() {
    final key =
        '${_currentPost.id}|${_currentPost.file.length}|${_currentPost.attachments.length}';
    if (_mediaCacheKey == key) return;

    _cachedMediaItems = _collectAndSortMedia();
    _cachedVideoItems = _collectVideoFiles();
    _cachedAudioItems = _collectAudioFiles();
    _mediaCacheKey = key;
    _activeVideoUrl = null;
  }

  List<Map<String, dynamic>> _collectAndSortMedia() {
    final List<Map<String, dynamic>> mediaItems = [];

    for (final file in _currentPost.file) {
      if (_isMediaFile(file.name)) {
        final rawPath = file.path;
        final fullUrl = _buildFullUrl(rawPath);
        final thumbnailUrl = buildThumbnailFromRawPath(rawPath);

        // Skip audio files - they go to audio section
        if (_isAudioFile(file.name)) continue;

        // Skip video files - they go to video section
        if (_isVideoFile(file.name)) continue;

        mediaItems.add({
          'type': 'image',
          'url': fullUrl,
          'name': file.name,
          'thumbnail_url': thumbnailUrl,
        });
      }
    }

    for (final attachment in _currentPost.attachments) {
      if (_isMediaFile(attachment.name)) {
        final rawPath = attachment.path;
        final fullUrl = _buildFullUrl(rawPath);
        final thumbnailUrl = buildThumbnailFromRawPath(rawPath);

        // Skip audio files - they go to audio section
        if (_isAudioFile(attachment.name)) continue;

        // Skip video files - they go to video section
        if (_isVideoFile(attachment.name)) continue;

        mediaItems.add({
          'type': 'image',
          'url': fullUrl,
          'name': attachment.name,
          'thumbnail_url': thumbnailUrl,
        });
      }
    }

    mediaItems.sort(
      (a, b) => (a['name'] as String).compareTo(b['name'] as String),
    );
    return mediaItems;
  }

  /// Check if file is a video file
  bool _isVideoFile(String? filename) {
    if (filename == null) return false;
    final name = filename.toLowerCase();
    return name.endsWith('.mp4') ||
        name.endsWith('.webm') ||
        name.endsWith('.mov') ||
        name.endsWith('.avi') ||
        name.endsWith('.mkv') ||
        name.endsWith('.m4v');
  }

  /// Collect video files separately
  List<Map<String, dynamic>> _collectVideoFiles() {
    final List<Map<String, dynamic>> videoFiles = [];

    // Check files
    for (final file in _currentPost.file) {
      if (_isVideoFile(file.name)) {
        final rawPath = file.path;
        final fullUrl = _buildFullUrl(rawPath);

        final thumbnailUrl = buildThumbnailFromRawPath(rawPath);

        videoFiles.add({
          'type': 'video',
          'url': fullUrl,
          'name': file.name,
          'thumbnail_url': thumbnailUrl,
        });
      }
    }

    // Check attachments
    for (final attachment in _currentPost.attachments) {
      if (_isVideoFile(attachment.name)) {
        final rawPath = attachment.path;
        final fullUrl = _buildFullUrl(rawPath);

        final thumbnailUrl = buildThumbnailFromRawPath(rawPath);

        videoFiles.add({
          'type': 'video',
          'url': fullUrl,
          'name': attachment.name,
          'thumbnail_url': thumbnailUrl,
        });
      }
    }

    videoFiles.sort(
      (a, b) => (a['name'] as String).compareTo(b['name'] as String),
    );
    return videoFiles;
  }

  /// Check if file is an audio file
  bool _isAudioFile(String? filename) {
    if (filename == null) return false;
    final name = filename.toLowerCase();
    return name.endsWith('.mp3') ||
        name.endsWith('.wav') ||
        name.endsWith('.flac') ||
        name.endsWith('.aac') ||
        name.endsWith('.ogg') ||
        name.endsWith('.m4a');
  }

  /// Collect audio files separately
  List<Map<String, dynamic>> _collectAudioFiles() {
    final List<Map<String, dynamic>> audioFiles = [];

    // Check files
    for (final file in _currentPost.file) {
      if (_isAudioFile(file.name)) {
        final rawPath = file.path;
        final fullUrl = _buildFullUrl(rawPath);

        audioFiles.add({'type': 'audio', 'url': fullUrl, 'name': file.name});
      }
    }

    // Check attachments
    for (final attachment in _currentPost.attachments) {
      if (_isAudioFile(attachment.name)) {
        final rawPath = attachment.path;
        final fullUrl = _buildFullUrl(rawPath);

        audioFiles.add({
          'type': 'audio',
          'url': fullUrl,
          'name': attachment.name,
        });
      }
    }

    audioFiles.sort(
      (a, b) => (a['name'] as String).compareTo(b['name'] as String),
    );
    return audioFiles;
  }

  bool _isMediaFile(String? filename) {
    if (filename == null) return false;
    final name = filename.toLowerCase();
    return name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.gif') ||
        name.endsWith('.webp') ||
        name.endsWith('.mp4') ||
        name.endsWith('.webm') ||
        name.endsWith('.mov') ||
        name.endsWith('.avi') ||
        name.endsWith('.mkv');
  }

  String buildThumbnailFromRawPath(String rawPath) {
    if (rawPath.isEmpty) return '';
    final clean = rawPath.startsWith('/') ? rawPath : '/$rawPath';
    final thumbnailPath = 'thumbnail/data$clean';
    final base = _activeApiSource == ApiSource.coomer
        ? 'https://img.coomer.st'
        : 'https://img.kemono.cr';
    final thumbnailUrl = '$base/$thumbnailPath';
    return thumbnailUrl;
  }

  // ignore: unused_element
  Widget _buildMediaHeader(int totalItems) {
    return _buildSectionHeader(
      icon: Icons.photo_library_outlined,
      title: 'Media ($totalItems)',
      color: AppTheme.primaryColor,
      context: context,
    );
  }

  Widget _buildMediaGrid(
    List<Map<String, dynamic>> displayItems, {
    required BoxFit imageFit,
    required bool useThumbnails,
  }) {
    // Responsive grid count based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 2;

    // 🚀 FIX: if only 1 item, use full width so it's not asymmetrical
    if (displayItems.length == 1) {
      crossAxisCount = 1;
    } else {
      if (screenWidth > 600) crossAxisCount = 3;
      if (screenWidth > 900) crossAxisCount = 4;
    }

    return MasonryGridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      padding: EdgeInsets.zero,
      itemCount: displayItems.length,
      itemBuilder: (context, index) {
        final mediaItem = displayItems[index];
        final mediaType = mediaItem['type'] as String;

        final rawUrl = mediaItem['url'] as String;
        final thumbnailUrl = mediaItem['thumbnail_url'] as String?;
        final displayUrl =
            useThumbnails && thumbnailUrl != null && thumbnailUrl.isNotEmpty
            ? thumbnailUrl
            : rawUrl;

        return GestureDetector(
          onTap: () => _openMediaFullscreen(mediaItem, index),
          child: Container(
            color: Theme.of(context).colorScheme.surface,
            child: Stack(
              children: [
                if (mediaType == 'image')
                  CachedNetworkImage(
                    imageUrl: displayUrl,
                    httpHeaders: _getCoomerHeaders(displayUrl),
                    fit: BoxFit.contain,
                    memCacheWidth: MediaQuery.of(context).size.width ~/ 2,
                    placeholder: (context, url) => AspectRatio(
                      aspectRatio: 1.0,
                      child: _buildImagePlaceholder(),
                    ),
                    errorWidget: (context, url, error) {
                      if (displayUrl != rawUrl) {
                        return CachedNetworkImage(
                          imageUrl: rawUrl,
                          httpHeaders: _getCoomerHeaders(rawUrl),
                          fit: BoxFit.contain,
                          memCacheWidth: MediaQuery.of(context).size.width ~/ 2,
                          placeholder: (context, url) => AspectRatio(
                            aspectRatio: 1.0,
                            child: _buildImagePlaceholder(),
                          ),
                          errorWidget: (context, url, error) => AspectRatio(
                            aspectRatio: 1.0,
                            child: _buildImageError(),
                          ),
                        );
                      }
                      return AspectRatio(
                        aspectRatio: 1.0,
                        child: _buildImageError(),
                      );
                    },
                  )
                else
                  // For video, use fixed aspect ratio
                  AspectRatio(
                    aspectRatio: 16.0 / 9.0, // Standard video ratio
                    child: _buildVideoThumbnail(mediaItem),
                  ),

                // Hover effect and overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.black.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _openMediaFullscreen(mediaItem, index),
                        child: Stack(
                          children: [
                            // Center icon for interaction
                            Center(
                              child: Icon(
                                mediaType == 'video'
                                    ? Icons.play_circle
                                    : Icons.fullscreen,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white70
                                    : Colors.black54,
                                size: 32,
                              ),
                            ),
                            // Media type indicator
                            Positioned(
                              top: 8,
                              left: 8,
                              child: _buildMediaTypeIndicator(mediaType),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[800]
          : Colors.grey[300],
      child: const AppSkeleton(shape: BoxShape.rectangle),
    );
  }

  Widget _buildImageError() {
    return Container(
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[800]
          : Colors.grey[300],
      child: Icon(
        Icons.broken_image,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey
            : Colors.grey[600],
      ),
    );
  }

  Widget _buildVideoThumbnail(Map<String, dynamic> mediaItem) {
    final thumbnailUrl = mediaItem['thumbnail_url'] ?? mediaItem['url'];

    return CachedNetworkImage(
      imageUrl: thumbnailUrl,
      // 🚀 FIX: Add HTTP headers for Coomer CDN anti-hotlink protection
      httpHeaders: _getCoomerHeaders(thumbnailUrl),
      fit: BoxFit.cover,
      placeholder: (context, url) => _buildImagePlaceholder(),
      errorWidget: (context, url, error) => _buildImageError(),
    );
  }

  /// Build media type indicator
  Widget _buildMediaTypeIndicator(String mediaType) {
    Color indicatorColor;
    IconData indicatorIcon;

    switch (mediaType) {
      case 'video':
        indicatorColor = Colors.red;
        indicatorIcon = Icons.videocam;
        break;
      case 'image':
        indicatorColor = Colors.blue;
        indicatorIcon = Icons.image;
        break;
      default:
        indicatorColor = Colors.grey;
        indicatorIcon = Icons.insert_drive_file;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: indicatorColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(indicatorIcon, color: Colors.white, size: 12),
    );
  }

  /// Get file extension from filename
  String _getFileExtension(String filename) {
    final dotIndex = filename.lastIndexOf('.');
    return dotIndex != -1 ? filename.substring(dotIndex + 1) : 'unknown';
  }

  /// 🚀 FIX: Get HTTP headers for Coomer CDN anti-hotlink protection
  Map<String, String>? _getCoomerHeaders(String imageUrl) {
    final isCoomerDomain =
        imageUrl.contains('coomer.st') || imageUrl.contains('n2.coomer.st');

    if (isCoomerDomain) {
      return const {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept': 'image/avif,image/webp,image/*,*/*;q=0.8',
        'Referer': 'https://coomer.st/',
        'Origin': 'https://coomer.st',
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
      };
    }

    return null; // No headers needed for non-Coomer domains
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
            apiSource: _activeApiSource.name,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FullscreenMediaViewer(
            mediaItems: _collectAndSortMedia(),
            initialIndex: index,
            apiSource: _activeApiSource,
          ),
        ),
      );
    }
  }

  /// Build expand/collapse button with enhanced light mode support
  Widget _buildExpandCollapseButton(int totalItems) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showAllMedia = !_showAllMedia;
        });
      },
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.primaryColor.withValues(alpha: 0.1)
                  : AppTheme.primaryColor.withValues(alpha: 0.05), // Light mode
              Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.primaryColor.withValues(alpha: 0.05)
                  : AppTheme.primaryColor.withValues(alpha: 0.02), // Light mode
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.primaryColor.withValues(alpha: 0.2)
                : AppTheme.primaryColor.withValues(alpha: 0.1), // Light mode
            width: 1,
          ),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _showAllMedia ? Icons.expand_less : Icons.expand_more,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _showAllMedia ? 'Show Less' : 'Show All ($totalItems)',
                style: AppTheme.titleStyle.copyWith(
                  color: AppTheme.primaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build download links section with clean architecture
  /// Build Video Section with edge-to-edge layout
  Widget _buildVideoSection() {
    _ensureMediaCache();
    final videoFiles = _cachedVideoItems;
    final autoplayVideo = context.watch<SettingsProvider>().autoplayVideo;

    if (videoFiles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: videoFiles.asMap().entries.map((entry) {
        final index = entry.key;
        final videoFile = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: _buildVideoPlayer(
            videoFile,
            index,
            autoplayVideo: autoplayVideo,
          ),
        );
      }).toList(),
    );
  }

  /// Build individual video player widget
  Widget _buildVideoPlayer(
    Map<String, dynamic> videoFile,
    int index, {
    required bool autoplayVideo,
  }) {
    final videoUrl = videoFile['url'] as String;
    final shouldAutoPlay = autoplayVideo;

    return Container(
      color: Colors.black,
      height: 240,
      width: double.infinity,
      child: (shouldAutoPlay || _activeVideoUrl == videoUrl)
          ? AppVideoPlayer(
              url: videoUrl,
              height: 240,
              autoplay: shouldAutoPlay || _activeVideoUrl == videoUrl,
              apiSource: _activeApiSource.name,
            )
          : _buildVideoPlaceholder(videoFile),
    );
  }

  Widget _buildVideoPlaceholder(Map<String, dynamic> videoFile) {
    final videoUrl = videoFile['url'] as String;
    final thumbnailUrl = videoFile['thumbnail_url'] as String?;

    return Material(
      color: Colors.black,
      child: InkWell(
        onTap: () {
          if (!mounted) return;
          setState(() {
            _activeVideoUrl = videoUrl;
          });
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: thumbnailUrl,
                fit: BoxFit.cover,
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
                      size: 48,
                    ),
                  ),
                ),
              )
            else
              Container(
                color: Colors.black,
                child: const Center(
                  child: Icon(Icons.videocam, color: Colors.white70, size: 48),
                ),
              ),
            Container(color: Colors.black.withValues(alpha: 0.35)),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.play_circle_fill, color: Colors.white, size: 56),
                  SizedBox(height: 8),
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

  /// Open video in fullscreen
  // ignore: unused_element
  void _openVideoFullscreen(Map<String, dynamic> videoFile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          videoUrl: videoFile['url'],
          videoName: videoFile['name'] ?? 'Video',
          apiSource: _activeApiSource.name,
        ),
      ),
    );
  }

  /// Download single file to Downloads/KC Download
  Future<void> _downloadSingleFile(PostLink link) async {
    final url = link.url;
    // Extract a reasonable filename from the URL or label
    String fileName =
        link.label ??
        url
            .split('/')
            .lastWhere((e) => e.isNotEmpty, orElse: () => 'download_file');
    if (fileName.contains('?')) {
      fileName = fileName.split('?').first;
    }
    _showSnackBar('Starting download for $fileName...', Colors.blue);

    try {
      // Get the default Downloads directory
      Directory? downloadsDirectory;
      if (Platform.isAndroid) {
        downloadsDirectory = Directory(
          '/storage/emulated/0/Download/KC Download',
        );
      } else {
        final dir = await getDownloadsDirectory();
        if (dir != null) {
          downloadsDirectory = Directory('${dir.path}/KC Download');
        }
      }

      if (downloadsDirectory == null) {
        _showSnackBar('Could not access Downloads directory', Colors.red);
        return;
      }

      if (!await downloadsDirectory.exists()) {
        await downloadsDirectory.create(recursive: true);
      }

      final savePath = '${downloadsDirectory.path}/$fileName';

      // Route through DownloadProvider so progress shows in Download Manager
      if (!mounted) return;
      final downloadProvider = context.read<DownloadProvider>();
      downloadProvider.addDownload(
        name: fileName,
        url: url,
        savePath: savePath,
      );
      _showSnackBar(
        'Download started: $fileName — check Download Manager',
        Colors.blue,
      );
    } catch (e) {
      AppLogger.warning('Download failed', tag: 'Downloader', error: e);
      _showSnackBar('Download failed: $e', Colors.red);
    }
  }

  /// Build Audio Section with proper state management
  Widget _buildAudioSection() {
    _ensureMediaCache();
    final audioFiles = _cachedAudioItems;

    if (audioFiles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Audio section header
          _buildSectionHeader(
            icon: Icons.audiotrack,
            title: 'Audio (${audioFiles.length})',
            color: Colors.purple,
            context: context,
          ),
          const SizedBox(height: 16),

          // Audio list
          ...audioFiles.asMap().entries.map((entry) {
            final index = entry.key;
            final audioFile = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildAudioPlayer(audioFile, index),
            );
          }),
        ],
      ),
    );
  }

  /// Build individual audio player widget
  Widget _buildAudioPlayer(Map<String, dynamic> audioFile, int index) {
    final audioUrl = audioFile['url'] as String;
    final fileName = audioFile['name'] as String;
    final isCurrentlyPlaying = _currentlyPlayingAudio == audioUrl && _isPlaying;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main audio controls row
            Row(
              children: [
                // Audio icon with format indicator
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getAudioColor(fileName),
                        _getAudioColor(fileName).withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        isCurrentlyPlaying
                            ? Icons.graphic_eq
                            : Icons.audiotrack,
                        color: Colors.white,
                        size: 24,
                      ),
                      // Format badge
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getFileExtension(fileName).toUpperCase(),
                            style: TextStyle(
                              color: _getAudioColor(fileName),
                              fontSize: 6,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Audio info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.grey.shade800,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.purple.withValues(alpha: 0.2)
                              : Colors.purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getAudioQuality(fileName),
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.purple
                                : _getLightModeColor(Colors.purple),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Play/Pause button
                GestureDetector(
                  onTap: () => _toggleAudioPlayback(audioUrl),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isCurrentlyPlaying
                            ? [Colors.purple.shade400, Colors.purple.shade600]
                            : [Colors.grey.shade400, Colors.grey.shade600],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: isCurrentlyPlaying
                              ? Colors.purple.withValues(alpha: 0.3)
                              : Colors.grey.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      isCurrentlyPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),

            // Enhanced controls section (only show when playing)
            if (isCurrentlyPlaying) ...[
              const SizedBox(height: 16),

              // Progress bar with seek
              GestureDetector(
                onTap: () => _seekAudioPosition(audioUrl),
                child: LinearProgressIndicator(
                  value: _duration.inMilliseconds > 0
                      ? _position.inMilliseconds / _duration.inMilliseconds
                      : 0.0,
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.purple
                        : _getLightModeColor(Colors.purple),
                  ),
                ),
              ),

              const SizedBox(height: 4),

              // Time display
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(_position),
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black54,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    _formatDuration(_duration),
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black54,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Playback controls row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Previous button
                  IconButton(
                    onPressed: _audioPlaylist.length > 1
                        ? _playPreviousAudio
                        : null,
                    icon: Icon(Icons.skip_previous, color: Colors.purple),
                    iconSize: 20,
                  ),

                  // Rewind 10 seconds
                  IconButton(
                    onPressed: _rewind10Seconds,
                    icon: Icon(Icons.replay_10, color: Colors.purple),
                    iconSize: 20,
                    tooltip: 'Rewind 10s',
                  ),

                  // Shuffle button
                  IconButton(
                    onPressed: _toggleShuffle,
                    icon: Icon(
                      Icons.shuffle,
                      color: _isShuffling ? Colors.purple : Colors.grey,
                    ),
                    iconSize: 20,
                  ),

                  // Loop button
                  IconButton(
                    onPressed: _toggleLoop,
                    icon: Icon(
                      Icons.repeat,
                      color: _isLooping ? Colors.purple : Colors.grey,
                    ),
                    iconSize: 20,
                  ),

                  // Speed control
                  PopupMenuButton<double>(
                    icon: Icon(Icons.speed, color: Colors.purple),
                    onSelected: _setPlaybackSpeed,
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 0.5, child: Text('0.5x')),
                      PopupMenuItem(value: 0.75, child: Text('0.75x')),
                      PopupMenuItem(value: 1.0, child: Text('1.0x')),
                      PopupMenuItem(value: 1.25, child: Text('1.25x')),
                      PopupMenuItem(value: 1.5, child: Text('1.5x')),
                      PopupMenuItem(value: 2.0, child: Text('2.0x')),
                    ],
                  ),

                  // Fast forward 10 seconds
                  IconButton(
                    onPressed: _fastForward10Seconds,
                    icon: Icon(Icons.forward_10, color: Colors.purple),
                    iconSize: 20,
                    tooltip: 'Forward 10s',
                  ),

                  // Next button
                  IconButton(
                    onPressed: _audioPlaylist.length > 1
                        ? _playNextAudio
                        : null,
                    icon: Icon(Icons.skip_next, color: Colors.purple),
                    iconSize: 20,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Get actual image size from URL
  Future<Size> getImageSize(String imageUrl) async {
    final completer = Completer<Size>();
    final image = Image(
      image: CachedNetworkImageProvider(
        imageUrl,
        headers: _getCoomerHeaders(imageUrl),
      ),
    );

    image.image
        .resolve(const ImageConfiguration())
        .addListener(
          ImageStreamListener(
            (info, _) {
              if (!completer.isCompleted) {
                completer.complete(
                  Size(
                    info.image.width.toDouble(),
                    info.image.height.toDouble(),
                  ),
                );
              }
            },
            onError: (error, stackTrace) {
              if (!completer.isCompleted) {
                // Fallback to 16:9 ratio if error
                completer.complete(const Size(16.0, 9.0));
              }
            },
          ),
        );

    return completer.future;
  }

  /// Get audio color based on format
  Color _getAudioColor(String filename) {
    final extension = _getFileExtension(filename).toLowerCase();
    switch (extension) {
      case 'mp3':
        return Colors.orange;
      case 'wav':
        return Colors.blue;
      case 'flac':
        return Colors.green;
      case 'aac':
        return Colors.red;
      case 'ogg':
        return Colors.purple;
      case 'm4a':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  /// Get audio quality based on format
  String _getAudioQuality(String filename) {
    final extension = _getFileExtension(filename).toLowerCase();
    switch (extension) {
      case 'flac':
        return 'Lossless';
      case 'wav':
        return 'Lossless';
      case 'mp3':
        return 'Compressed';
      case 'aac':
        return 'High Quality';
      case 'm4a':
        return 'Apple Lossless';
      case 'ogg':
        return 'Open Source';
      default:
        return 'Audio';
    }
  }

  /// Enhanced audio toggle with playlist support
  Future<void> _toggleAudioPlayback(String audioUrl) async {
    try {
      if (_currentlyPlayingAudio == audioUrl && _isPlaying) {
        await _audioPlayer!.pause();
      } else {
        // Initialize playlist if not already done
        if (_audioPlaylist.isEmpty) {
          _audioPlaylist = _collectAudioFiles();
          _currentAudioIndex = _audioPlaylist.indexWhere(
            (audio) => audio['url'] == audioUrl,
          );
        }

        if (_currentlyPlayingAudio != audioUrl) {
          await _audioPlayer!.play(UrlSource(audioUrl));
          _currentlyPlayingAudio = audioUrl;
        } else {
          await _audioPlayer!.resume();
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to play audio: $e');
    }
  }

  /// Enhanced audio control methods
  Future<void> _playNextAudio() async {
    if (_audioPlaylist.isEmpty) return;

    int nextIndex;
    if (_isShuffling) {
      final random = Random();
      nextIndex = random.nextInt(_audioPlaylist.length);
      if (nextIndex == _currentAudioIndex && _audioPlaylist.length > 1) {
        nextIndex = (nextIndex + 1) % _audioPlaylist.length;
      }
    } else {
      nextIndex = (_currentAudioIndex + 1) % _audioPlaylist.length;
    }

    final nextAudio = _audioPlaylist[nextIndex];
    _currentAudioIndex = nextIndex;
    await _toggleAudioPlayback(nextAudio['url']);
  }

  Future<void> _playPreviousAudio() async {
    if (_audioPlaylist.isEmpty) return;

    int prevIndex =
        (_currentAudioIndex - 1 + _audioPlaylist.length) %
        _audioPlaylist.length;
    final prevAudio = _audioPlaylist[prevIndex];
    _currentAudioIndex = prevIndex;
    await _toggleAudioPlayback(prevAudio['url']);
  }

  Future<void> _setPlaybackSpeed(double speed) async {
    try {
      await _audioPlayer!.setPlaybackRate(speed);
    } catch (e) {
      AppLogger.warning(
        'Failed to set playback speed',
        tag: 'PostDetail',
        error: e,
      );
    }
  }

  /// 🚀 NEW: Fast forward 10 seconds
  Future<void> _fastForward10Seconds() async {
    try {
      if (_audioPlayer != null && _currentlyPlayingAudio != null) {
        final newPosition = _position + const Duration(seconds: 10);

        // Don't seek beyond the audio duration
        final seekPosition = newPosition > _duration ? _duration : newPosition;

        await _audioPlayer!.seek(seekPosition);

        // Show visual feedback
        _showSnackBar('Forwarded 10 seconds', Colors.purple);
      }
    } catch (e) {
      _showSnackBar('Failed to fast forward', Colors.red);
    }
  }

  /// 🚀 NEW: Rewind 10 seconds
  Future<void> _rewind10Seconds() async {
    try {
      if (_audioPlayer != null && _currentlyPlayingAudio != null) {
        final newPosition = _position - const Duration(seconds: 10);

        // Don't seek before 0
        final seekPosition = newPosition < Duration.zero
            ? Duration.zero
            : newPosition;

        await _audioPlayer!.seek(seekPosition);

        // Show visual feedback
        _showSnackBar('Rewinded 10 seconds', Colors.purple);
      }
    } catch (e) {
      _showSnackBar('Failed to rewind', Colors.red);
    }
  }

  Future<void> _toggleLoop() async {
    setState(() => _isLooping = !_isLooping);
  }

  Future<void> _toggleShuffle() async {
    setState(() => _isShuffling = !_isShuffling);
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// 🚀 NEW: Show custom SnackBar with color
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Seek audio position
  Future<void> _seekAudioPosition(String audioUrl) async {
    if (_currentlyPlayingAudio != audioUrl || _duration.inMilliseconds == 0) {
      return;
    }

    try {
      // Calculate seek position based on tap (simplified - seeks to middle for demo)
      final seekPosition = Duration(seconds: _duration.inSeconds ~/ 2);
      await _audioPlayer?.seek(seekPosition);
    } catch (e) {
      AppLogger.warning(
        'Failed to seek audio position',
        tag: 'PostDetail',
        error: e,
      );
    }
  }

  /// Format duration for display
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }

  /// Build section header with consistent styling
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
    required BuildContext context,
  }) {
    final accent = Theme.of(context).brightness == Brightness.dark
        ? color
        : _getLightModeColor(color);
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accent.withValues(alpha: 0.28),
                accent.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.28)),
          ),
          child: Icon(icon, color: accent, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.grey.shade800,
            ),
          ),
        ),
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.3),
                blurRadius: 10,
                spreadRadius: -4,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionShell({
    required Widget child,
    required Color accentColor,
  }) {
    final accent = Theme.of(context).brightness == Brightness.dark
        ? accentColor
        : _getLightModeColor(accentColor);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: Theme.of(context).brightness == Brightness.dark
              ? [
                  AppTheme.darkCardColor.withValues(alpha: 0.98),
                  AppTheme.darkSurfaceColor.withValues(alpha: 0.94),
                ]
              : [
                  Colors.white,
                  AppTheme.lightElevatedSurfaceColor.withValues(alpha: 0.95),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 18,
            spreadRadius: -10,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  /// Helper method to get light mode color variant
  Color _getLightModeColor(Color color) {
    if (color is MaterialColor) {
      return color.shade700;
    }
    return color;
  }

  /// Build download links section with unified link handling and refresh button
  Widget _buildDownloadLinksSection() {
    final allLinks = collectAllLinks();
    final contentStable = isContentStable(_currentPost.content);

    return _buildSectionShell(
      accentColor: contentStable ? Colors.green : Colors.orange,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Links section header with refresh button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader(
                icon: Icons.link,
                title: contentStable
                    ? 'Links & Downloads (${allLinks.length})'
                    : 'Links & Downloads (Content Loading...)',
                color: contentStable ? Colors.green : Colors.orange,
                context: context,
              ),
              if (!contentStable)
                Row(
                  children: [
                    if (_isRefreshingContent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Loading...',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      TextButton.icon(
                        onPressed: _refreshContent,
                        icon: Icon(
                          Icons.refresh,
                          color: Colors.orange,
                          size: 16,
                        ),
                        label: Text(
                          'Refresh',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          backgroundColor: Colors.orange.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.orange.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),

          if (!contentStable)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.orange.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.orange.withValues(alpha: 0.3)
                      : Colors.orange.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Content is still loading. Links will appear once the post content is fully loaded.',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.orange.shade200
                            : Colors.orange.shade800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (allLinks.isNotEmpty) ...[
            const SizedBox(height: 16),

            // Links list with source-specific styling
            ...allLinks.asMap().entries.map((entry) {
              final index = entry.key;
              final link = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildLinkItem(link, index),
              );
            }),

            // Download all button
            const SizedBox(height: AppTheme.mdSpacing),
            _buildDownloadAllButton(allLinks),
          ],
        ],
      ),
    );
  }

  /// Build individual link item with source-specific styling
  Widget _buildLinkItem(PostLink link, int index) {
    // Determine icon and color based on source
    IconData icon;
    Color color;
    String sourceLabel;

    switch (link.source) {
      case 'file':
        icon = Icons.file_download;
        color = Colors.blue;
        sourceLabel = 'File';
        break;
      case 'content':
        icon = Icons.link;
        color = Colors.green;
        sourceLabel = 'Content';
        break;
      default:
        icon = Icons.insert_link;
        color = Colors.grey;
        sourceLabel = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.getBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Link header with source indicator
          Row(
            children: [
              // Source icon
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, color: color, size: 16),
              ),

              const SizedBox(width: 12),

              // Link info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Source label
                    Text(
                      sourceLabel,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    // Link label (filename or URL)
                    Text(
                      link.label ?? link.url,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[300]
                            : Colors.grey[700],
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Link URL (selectable)
          SelectableText(
            link.url,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[400]
                  : Colors.grey[600],
              fontFamily: 'monospace',
            ),
          ),

          const SizedBox(height: 8),

          // Action buttons
          Row(
            children: [
              // Copy link button
              IconButton(
                onPressed: () => _copyLinkToClipboard(link.url),
                icon: Icon(
                  Icons.copy,
                  size: 16,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? color
                      : _getLightModeColor(color),
                ),
                tooltip: 'Copy Link',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),

              const SizedBox(width: 8),

              // Download button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _downloadSingleFile(link),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Save', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Open in browser button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openLinkInBrowser(link.url),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? color
                        : _getLightModeColor(color),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build download all button
  Widget _buildDownloadAllButton(List<PostLink> links) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).brightness == Brightness.dark
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.green.withValues(alpha: 0.05),
            Theme.of(context).brightness == Brightness.dark
                ? Colors.green.withValues(alpha: 0.05)
                : Colors.green.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.green.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _downloadAllFiles,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.download_for_offline,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.green
                      : _getLightModeColor(Colors.green),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Download All Files',
                  style: AppTheme.titleStyle.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.green
                        : _getLightModeColor(Colors.green),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Check if content is stable enough for parsing
  bool isContentStable(String content) {
    if (content.trim().isEmpty) return false;
    if (content.length < 80) return false;
    if (content.contains('<a') && !content.contains('</a>')) return false;
    return true;
  }

  /// Manual refresh content method
  Future<void> _refreshContent() async {
    if (_isRefreshingContent) return;

    setState(() {
      _isRefreshingContent = true;
    });

    try {
      // Clear all caches to force fresh extraction
      _cachedLinks = null;
      _cachedContentHash = null;

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Refreshing post...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // Reload full post data with fresh API call
      if (!widget.isFromSavedPosts) {
        await _loadFullPost();
      }

      // Trigger UI update
      setState(() {});

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Post refreshed successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refresh failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingContent = false;
        });
      }
    }
  }

  /// Collect all links from different sources with caching and stability check
  List<PostLink>? _cachedLinks;
  String? _cachedContentHash;

  List<PostLink> collectAllLinks() {
    final content = _currentPost.content;
    final hash = content.hashCode.toString();

    // Return cached result if content hasn't changed
    if (_cachedLinks != null && _cachedContentHash == hash) {
      return _cachedLinks!;
    }

    // Skip parsing if content is not stable
    if (!isContentStable(content)) {
      return [];
    }

    final links = <PostLink>[];

    // Collect from content
    links.addAll(extractLinksFromContent());

    // Collect from files
    links.addAll(extractFileLinks());

    // Cache the result
    _cachedLinks = links;
    _cachedContentHash = hash;
    for (int i = 0; i < links.length; i++) {}

    return links;
  }

  /// Extract links from content with clean, defensive parsing
  List<PostLink> extractLinksFromContent() {
    final content = _currentPost.content;
    final links = <PostLink>[];

    if (content.trim().isEmpty) {
      return links;
    }

    // Extract from HTML href attributes using HTML parser
    try {
      final document = html_parser.parse(content);
      final anchorElements = document.getElementsByTagName('a');

      for (final element in anchorElements) {
        final href = element.attributes['href'];
        if (href != null && href.isNotEmpty) {
          // Skip relative URLs and anchors
          if (href.startsWith('#') ||
              href.startsWith('/') ||
              href.startsWith('mailto:') ||
              href.startsWith('javascript:')) {
            continue;
          }

          // Normalize URL
          final url = normalizeUrl(href);

          // Only add if valid and not already in the list
          if (_isValidUrl(url) && !links.any((link) => link.url == url)) {
            links.add(PostLink(url: url, source: 'content', label: url));
          }
        }
      }
    } catch (e) {
      AppLogger.warning(
        'Failed to parse HTML content links',
        tag: 'PostDetail',
        error: e,
      );
    }

    // Simple regex fallback for plain text URLs only
    final urlRegex = RegExp(r'https?:\/\/[^\s<>"\)]+', caseSensitive: false);

    final matches = urlRegex.allMatches(content);

    for (final match in matches) {
      String url = match.group(0)!;

      // Clean trailing punctuation
      url = url.replaceAll(RegExp(r'[.,;:!?)\]\}]+$'), '');

      // Normalize URL
      url = normalizeUrl(url);

      // Only add if valid and not already in the list
      if (_isValidUrl(url) && !links.any((link) => link.url == url)) {
        links.add(PostLink(url: url, source: 'content', label: url));
      }
    }
    for (int i = 0; i < links.length; i++) {}

    return links;
  }

  /// Extract file links from post files
  List<PostLink> extractFileLinks() {
    final links = <PostLink>[];

    for (final file in _currentPost.file) {
      try {
        // Build full URL from file path
        final url = _buildFullUrl(file.path);

        // Only add if valid and not already in the list
        if (_isValidUrl(url) && !links.any((link) => link.url == url)) {
          links.add(
            PostLink(
              url: url,
              source: 'file',
              label: file.name, // Use filename as label
            ),
          );
        }
      } catch (e) {
        AppLogger.warning(
          'Failed to build file link',
          tag: 'PostDetail',
          error: e,
        );
      }
    }
    return links;
  }

  /// Normalize URL (add https if missing)
  String normalizeUrl(String url) {
    if (url.startsWith('www.')) {
      return 'https://$url';
    }
    return url;
  }

  /// Validate URL
  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Build full URL from file path - FIXED with proper CDN domains
  String _buildFullUrl(String? path) {
    if (path == null || path.isEmpty) {
      throw Exception('File path is empty');
    }

    // If path is already a full URL, return as is
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    // Build URL using active source to prevent cross-domain content mixing.
    final baseUrl = _activeApiSource == ApiSource.coomer
        ? 'https://n2.coomer.st/data'
        : 'https://n1.kemono.cr/data';

    // Remove leading slash if present to avoid double slashes
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;

    return '$baseUrl/$cleanPath';
  }

  /// Copy link to clipboard
  void _copyLinkToClipboard(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Link copied to clipboard')));
    }
  }

  /// Open link in browser
  Future<void> _openLinkInBrowser(String link) async {
    final uri = Uri.parse(link);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Could not open $link')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening link: $e')));
      }
    }
  }

  Future<void> _launchSourceUrl() async {
    final baseUrl = _activeApiSource == ApiSource.coomer
        ? 'https://coomer.st'
        : 'https://kemono.cr';
    final url =
        '$baseUrl/${widget.post.service}/user/${widget.post.user}/post/${widget.post.id}';

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Could not open link')));
        }
      }
    } catch (e) {
      AppLogger.warning(
        'Failed to launch full post URL',
        tag: 'PostDetail',
        error: e,
      );
    }
  }

  Widget _buildPostContent() {
    final cleanContent = _cleanHtmlContent(_currentPost.content);

    if (cleanContent.isEmpty && _currentPost.title.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_currentPost.title.isNotEmpty) ...[
            Text(
              _currentPost.title,
              style: TextStyle(
                color: AppTheme.getPrimaryTextColor(context),
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            if (cleanContent.isNotEmpty) const SizedBox(height: 6),
          ],
          if (cleanContent.isNotEmpty) _buildLinkifiedContent(),
        ],
      ),
    );
  }

  /// Clean HTML content and extract text
  String _cleanHtmlContent(String htmlContent) {
    // DEBUG: Print original content

    // Early return for completely empty content
    if (htmlContent.trim().isEmpty) {
      return '';
    }

    // Parse HTML and extract text
    final document = html_parser.parse(htmlContent);

    // Remove script and style tags
    final scripts = document.getElementsByTagName('script');
    for (final script in scripts) {
      script.remove();
    }

    final styles = document.getElementsByTagName('style');
    for (final style in styles) {
      style.remove();
    }

    // Get clean text content
    String cleanText = document.body?.text ?? document.text ?? '';

    // Clean up extra whitespace and HTML artifacts
    cleanText = cleanText
        .replaceAll(RegExp(r'\s+'), ' ') // Multiple whitespace to single space
        .replaceAll(RegExp(r'&nbsp;'), ' ') // HTML non-breaking space
        .replaceAll(RegExp(r'&amp;'), '&') // HTML ampersand
        .replaceAll(RegExp(r'&lt;'), '<') // HTML less than
        .replaceAll(RegExp(r'&gt;'), '>') // HTML greater than
        .trim();

    // Check if content is meaningful (not just empty HTML tags)
    if (cleanText.isEmpty ||
        cleanText.length < 3 || // Very short content is likely just artifacts
        RegExp(r'^[\s\W]*$').hasMatch(cleanText)) {
      // Only whitespace/special chars
      return '';
    }

    // DEBUG: Print cleaned content

    return cleanText;
  }

  /// Build linkified content - always show full content
  Widget _buildLinkifiedContent() {
    // Clean HTML content first
    final cleanContent = _cleanHtmlContent(_currentPost.content);

    return Linkify(
      onOpen: (link) async {
        final uri = Uri.parse(link.url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Could not open $link')));
          }
        }
      },
      text: cleanContent,
      style: TextStyle(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.grey.shade800, // Light mode
        fontSize: 14,
        height: 1.4,
      ),
      linkStyle: TextStyle(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.lightBlue
            : _getLightModeColor(Colors.blue), // Light mode
        decoration: TextDecoration.underline,
      ),
      options: const LinkifyOptions(
        looseUrl: true,
        removeWww: false,
        defaultToHttps: true,
        humanize: false,
      ),
    );
  }

  Widget _buildTagsSection() {
    return _buildSectionShell(
      accentColor: Colors.orange,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.tag,
            title: 'Tags (${_currentPost.tags.length})',
            color: Colors.orange,
            context: context,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _currentPost.tags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.orange.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.05), // Light mode
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.orange.withValues(alpha: 0.3)
                        : Colors.orange.withValues(alpha: 0.2), // Light mode
                  ),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.orange
                        : _getLightModeColor(Colors.orange), // Light mode
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    return _buildSectionShell(
      accentColor: Colors.blue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.chat_bubble_outline,
            title: 'Comments',
            color: Colors.blue,
            context: context,
          ),
          const SizedBox(height: 16),
          Consumer<CommentsProvider>(
            builder: (context, commentsProvider, _) {
              final comments = commentsProvider.comments;

              // DEBUG: Print comments state

              if (commentsProvider.isLoading) {
                return Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.blue.withValues(alpha: 0.1)
                        : Colors.blue.withValues(alpha: 0.05), // Light mode
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.blue.withValues(alpha: 0.3)
                          : Colors.blue.withValues(alpha: 0.2), // Light mode
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: AppSkeleton.circle(size: 24),
                        ),
                        const SizedBox(height: 8),
                        AppSkeleton.rounded(height: 12, width: 120),
                      ],
                    ),
                  ),
                );
              }

              if (comments.isEmpty) {
                return Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.blue.withValues(alpha: 0.1)
                        : Colors.blue.withValues(alpha: 0.05), // Light mode
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.blue.withValues(alpha: 0.3)
                          : Colors.blue.withValues(alpha: 0.2), // Light mode
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.blue
                              : _getLightModeColor(Colors.blue), // Light mode
                          size: 20,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No comments yet',
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.blue
                                : _getLightModeColor(Colors.blue), // Light mode
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Be the first to comment!',
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[400]
                                : Colors.grey[600], // Light mode
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  // Comments preview with error handling
                  ...comments.take(3).map((comment) {
                    try {
                      return _buildCommentItem(comment);
                    } catch (e) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.red.withValues(alpha: 0.1)
                              : Colors.red.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.red.withValues(alpha: 0.3)
                                : Colors.red.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          'Error loading comment',
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.red
                                : Colors.red.shade700,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }
                  }),

                  // View all button
                  if (comments.length > 3)
                    TextButton(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => CommentsBottomSheet(
                            postId: _currentPost.id,
                            service: _currentPost.service,
                            creatorId: _currentPost.user,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).brightness == Brightness.dark
                                  ? Colors.blue.withValues(alpha: 0.1)
                                  : Colors.blue.withValues(
                                      alpha: 0.05,
                                    ), // Light mode
                              Theme.of(context).brightness == Brightness.dark
                                  ? Colors.blue.withValues(alpha: 0.05)
                                  : Colors.blue.withValues(
                                      alpha: 0.02,
                                    ), // Light mode
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.blue.withValues(alpha: 0.3)
                                : Colors.blue.withValues(
                                    alpha: 0.2,
                                  ), // Light mode
                          ),
                        ),
                        child: Text(
                          'View All Comments (${comments.length})',
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.blue
                                : _getLightModeColor(Colors.blue), // Light mode
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Comment comment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: Theme.of(context).brightness == Brightness.dark
              ? [
                  Colors.blue.withValues(alpha: 0.08),
                  AppTheme.darkElevatedSurfaceColor.withValues(alpha: 0.72),
                ]
              : [Colors.blue.withValues(alpha: 0.03), Colors.white],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.blue.withValues(alpha: 0.2)
              : Colors.blue.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Author avatar placeholder
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.blue.withValues(alpha: 0.2)
                      : Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.blue.withValues(alpha: 0.4)
                        : Colors.blue.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  Icons.person,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.blue
                      : _getLightModeColor(Colors.blue),
                  size: 16,
                ),
              ),

              const SizedBox(width: 8),

              // Author name and date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.username,
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.blue
                            : _getLightModeColor(Colors.blue),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _formatCommentDate(comment.timestamp.toIso8601String()),
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[400]
                            : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Comment body with better text handling
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.getElevatedSurfaceColor(context),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
                topLeft: Radius.circular(4),
              ),
              border: Border.all(
                color: AppTheme.getBorderColor(context).withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              comment.content,
              style: TextStyle(
                color: AppTheme.getPrimaryTextColor(context),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Format comment date with better handling
  String _formatCommentDate(String dateString) {
    try {
      if (dateString.isEmpty) return 'Unknown date';

      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 365) {
        return '${(difference.inDays / 365).floor()}y ago';
      } else if (difference.inDays > 30) {
        return '${(difference.inDays / 30).floor()}mo ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'just now';
      }
    } catch (e) {
      return dateString.length > 10 ? dateString.substring(0, 10) : dateString;
    }
  }

  // ignore: unused_element
  Color _getServiceColor() {
    switch (_currentPost.service) {
      case 'onlyfans':
        return Colors.blue;
      case 'fansly':
        return Colors.purple;
      case 'candfans':
        return Colors.pink;
      default:
        return Colors.orange;
    }
  }

  String _getServiceDisplayName() {
    switch (_currentPost.service) {
      case 'onlyfans':
        return 'OnlyFans';
      case 'fansly':
        return 'Fansly';
      case 'candfans':
        return 'CandFans';
      default:
        return _currentPost.service.toUpperCase();
    }
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

  Future<void> _toggleSave() async {
    final postsProvider = context.read<PostsProvider>();
    try {
      await postsProvider.toggleSavePost(_currentPost);
      setState(() {
        _fullPost = _currentPost.copyWith(saved: !_currentPost.saved);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _currentPost.saved ? 'Post saved' : 'Post removed from saved',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: _currentPost.saved
                ? AppTheme.primaryColor
                : AppTheme.getSecondaryTextColor(context),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update saved status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadAllFiles() async {
    final links = collectAllLinks();
    if (links.isEmpty) {
      _showSnackBar('No files found to download.', Colors.orange);
      return;
    }

    _showSnackBar(
      'Starting batch download for ${links.length} files...',
      Colors.blue,
    );

    int successCount = 0;
    int failCount = 0;

    try {
      Directory? downloadsDirectory;
      if (Platform.isAndroid) {
        downloadsDirectory = Directory(
          '/storage/emulated/0/Download/KC Download',
        );
      } else {
        final dir = await getDownloadsDirectory();
        if (dir != null) {
          downloadsDirectory = Directory('${dir.path}/KC Download');
        }
      }

      if (downloadsDirectory == null) {
        _showSnackBar('Could not access Downloads directory', Colors.red);
        return;
      }

      if (!await downloadsDirectory.exists()) {
        await downloadsDirectory.create(recursive: true);
      }

      final dio = Dio();
      final referer = _activeApiSource == ApiSource.coomer
          ? 'https://coomer.st/'
          : 'https://kemono.cr/';
      final headers = ApiHeaderService.getMediaHeaders(referer: referer);

      for (final link in links) {
        try {
          final url = link.url;
          String fileName =
              link.label ??
              url
                  .split('/')
                  .lastWhere(
                    (e) => e.isNotEmpty,
                    orElse: () => 'download_file',
                  );
          if (fileName.contains('?')) {
            fileName = fileName.split('?').first;
          }
          final savePath = '${downloadsDirectory.path}/$fileName';

          await dio.download(url, savePath, options: Options(headers: headers));
          successCount++;
        } catch (e) {
          failCount++;
          AppLogger.warning(
            'Failed batch download for ${link.url}',
            tag: 'Downloader',
            error: e,
          );
        }
      }

      if (failCount > 0) {
        _showSnackBar(
          'Downloaded $successCount files ($failCount failed)',
          Colors.orange,
        );
      } else {
        _showSnackBar(
          'Successfully downloaded all $successCount files to KC Download!',
          Colors.green,
        );
      }
    } catch (e) {
      _showSnackBar('Batch download failed: $e', Colors.red);
    }
  }

  Future<void> _sharePost() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality not implemented yet')),
    );
  }

  /// 🚀 NEW: Navigate to creator detail screen
  void _navigateToCreatorDetail() {
    // Create a Creator object from the post data
    final creator = Creator(
      id: _currentPost.user,
      name: _currentPost.user,
      service: _currentPost.service,
      indexed:
          DateTime.now().millisecondsSinceEpoch ~/ 1000, // Current timestamp
      updated:
          DateTime.now().millisecondsSinceEpoch ~/ 1000, // Current timestamp
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CreatorDetailScreen(creator: creator, apiSource: _activeApiSource),
      ),
    );
  }

  /// 🚀 NEW: Build creator avatar widget
  Widget _buildCreatorAvatar() {
    final iconUrl = _buildCreatorIconUrl(
      apiSource: _activeApiSource,
      service: _currentPost.service,
      creatorId: _currentPost.user,
    );

    return CircleAvatar(
      radius: 16,
      backgroundColor: AppTheme.getSurfaceColor(context),
      backgroundImage: CachedNetworkImageProvider(
        iconUrl,
        // 🚀 FIX: Add HTTP headers for Coomer CDN anti-hotlink protection
        headers: _getCoomerHeaders(iconUrl),
      ),
      onBackgroundImageError: (error, stackTrace) {
        // Error handled by fallback child
      },
      child: Icon(Icons.person, color: AppTheme.secondaryTextColor, size: 16),
    );
  }

  /// 🚀 NEW: Build creator icon URL
  String _buildCreatorIconUrl({
    required ApiSource apiSource,
    required String service,
    required String creatorId,
  }) {
    final base = apiSource == ApiSource.coomer
        ? 'https://img.coomer.st'
        : 'https://img.kemono.cr';

    return '$base/icons/$service/$creatorId';
  }
}

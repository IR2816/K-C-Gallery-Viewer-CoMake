import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Prinsip 4: Kontrol di tangan user (sense of control)
/// 
/// 4.1 Jangan autoplay video
/// Walau kelihatan modern, autoplay:
/// - Boros
/// - Ganggu  
/// - Bikin panas
/// 
/// Lebih baik:
/// - Thumbnail + tombol play
/// - User memutuskan
/// 
/// 4.2 Beri pilihan kualitas (opsional)
/// Kalau memungkinkan:
/// - Low / Original
/// - Ingat pilihan user
/// 
/// Ini UX matang, bukan fitur pamer.
class SmartMediaController extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final MediaQuality defaultQuality;
  final bool showQualitySelector;
  final VoidCallback? onPlay;
  final VoidCallback? onPause;
  final VoidCallback? onEnded;
  final Function(MediaQuality)? onQualityChanged;

  const SmartMediaController({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
    this.defaultQuality = MediaQuality.auto,
    this.showQualitySelector = true,
    this.onPlay,
    this.onPause,
    this.onEnded,
    this.onQualityChanged,
  });

  @override
  State<SmartMediaController> createState() => _SmartMediaControllerState();
}

class _SmartMediaControllerState extends State<SmartMediaController> {
  MediaQuality _currentQuality = MediaQuality.auto;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _showControls = true;
  bool _isFullscreen = false;
  Duration _position = Duration.zero;
  final Duration _duration = Duration.zero;
  Timer? _hideControlsTimer;
  Timer? _positionTimer;

  @override
  void initState() {
    super.initState();
    _currentQuality = widget.defaultQuality;
    _loadUserPreference();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _positionTimer?.cancel();
    super.dispose();
  }

  void _loadUserPreference() async {
    // TODO: Load user's preferred quality from cache
    // final savedQuality = await CacheHelper.getUserPreference<MediaQuality>('video_quality');
    // if (savedQuality != null) {
    //   setState(() {
    //     _currentQuality = savedQuality;
    //   });
    // }
  }

  void _saveUserPreference() async {
    // TODO: Save user's preferred quality to cache
    // await CacheHelper.setUserPreference('video_quality', _currentQuality);
  }

  void _togglePlayPause() {
    HapticFeedback.lightImpact();
    
    if (_isPlaying) {
      _pause();
    } else {
      _play();
    }
  }

  void _play() {
    setState(() {
      _isLoading = true;
    });
    
    // Simulate loading
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _isPlaying = true;
        _isLoading = false;
      });
      widget.onPlay?.call();
      _startPositionTimer();
      _scheduleHideControls();
    });
  }

  void _pause() {
    setState(() {
      _isPlaying = false;
    });
    widget.onPause?.call();
    _positionTimer?.cancel();
    _showControls = true;
  }

  void _toggleControls() {
    HapticFeedback.selectionClick();
    
    if (_showControls) {
      _hideControls();
    } else {
      setState(() {
        _showControls = true;
      });
      _scheduleHideControls();
    }
  }

  void _hideControls() {
    if (_isPlaying) {
      setState(() {
        _showControls = false;
      });
    }
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      _hideControls();
    });
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      // Simulate position update
      if (_position < _duration) {
        setState(() {
          _position = _position + const Duration(milliseconds: 500);
        });
      } else {
        _onVideoEnded();
      }
    });
  }

  void _onVideoEnded() {
    _positionTimer?.cancel();
    setState(() {
      _isPlaying = false;
      _position = Duration.zero;
      _showControls = true;
    });
    widget.onEnded?.call();
  }

  void _changeQuality(MediaQuality quality) {
    HapticFeedback.selectionClick();
    
    setState(() {
      _currentQuality = quality;
      _isLoading = true;
    });
    
    // Simulate quality change
    Future.delayed(const Duration(milliseconds: 1000), () {
      setState(() {
        _isLoading = false;
      });
      widget.onQualityChanged?.call(quality);
      _saveUserPreference();
    });
  }

  void _toggleFullscreen() {
    HapticFeedback.mediumImpact();
    
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
    
    // TODO: Implement actual fullscreen
  }

  void _onTap() {
    if (_isPlaying) {
      _toggleControls();
    } else {
      _togglePlayPause();
    }
  }

  void _onDoubleTap() {
    HapticFeedback.mediumImpact();
    // TODO: Implement zoom or seek
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      onDoubleTap: _onDoubleTap,
      child: Container(
        width: double.infinity,
        height: _isFullscreen ? MediaQuery.of(context).size.height : 300,
        color: Colors.black,
        child: Stack(
          children: [
            // Video/Thumbnail background
            _buildVideoBackground(),
            
            // Loading overlay
            if (_isLoading)
              _buildLoadingOverlay(),
            
            // Play button overlay (when not playing)
            if (!_isPlaying && !_isLoading)
              _buildPlayButtonOverlay(),
            
            // Controls overlay
            if (_showControls)
              _buildControlsOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoBackground() {
    if (_isPlaying && !_isLoading) {
      // TODO: Replace with actual video player
      return Container(
        color: Colors.black,
        child: const Center(
          child: Icon(
            Icons.play_circle_outline,
            size: 64,
            color: Colors.white24,
          ),
        ),
      );
    }
    
    // Show thumbnail
    return widget.thumbnailUrl != null
        ? Image.network(
            widget.thumbnailUrl!,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
          )
        : _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.surfaceColor,
            AppTheme.cardColor,
          ],
        ),
      ),
      child: const Icon(
        Icons.movie_outlined,
        size: 64,
        color: AppTheme.secondaryTextColor,
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black.withOpacity(0.5),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: AppTheme.smSpacing),
            Text(
              'Loading...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayButtonOverlay() {
    return Center(
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.play_arrow,
          size: 48,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.7),
          ],
        ),
      ),
      child: Column(
        children: [
          // Top controls
          _buildTopControls(),
          
          const Spacer(),
          
          // Bottom controls
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildTopControls() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.mdPadding),
        child: Row(
          children: [
            // Back button
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop();
              },
            ),
            
            const Spacer(),
            
            // Quality selector
            if (widget.showQualitySelector)
              _buildQualitySelector(),
            
            // Fullscreen button
            IconButton(
              icon: Icon(
                _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                color: Colors.white,
              ),
              onPressed: _toggleFullscreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.mdPadding),
      child: Column(
        children: [
          // Progress bar
          _buildProgressBar(),
          
          const SizedBox(height: AppTheme.smSpacing),
          
          // Control buttons
          Row(
            children: [
              // Play/Pause button
              IconButton(
                icon: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
                onPressed: _togglePlayPause,
              ),
              
              const SizedBox(width: AppTheme.smSpacing),
              
              // Time display
              Text(
                '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              
              const Spacer(),
              
              // Volume control (placeholder)
              IconButton(
                icon: const Icon(Icons.volume_up, color: Colors.white),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  // TODO: Implement volume control
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: _duration.inMilliseconds > 0 
            ? _position.inMilliseconds / _duration.inMilliseconds 
            : 0.0,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildQualitySelector() {
    return PopupMenuButton<MediaQuality>(
      icon: const Icon(Icons.settings, color: Colors.white),
      onSelected: _changeQuality,
      itemBuilder: (context) => MediaQuality.values.map((quality) {
        return PopupMenuItem(
          value: quality,
          child: Row(
            children: [
              Text(_getQualityLabel(quality)),
              const Spacer(),
              if (_currentQuality == quality)
                const Icon(Icons.check, color: AppTheme.primaryColor),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _getQualityLabel(MediaQuality quality) {
    switch (quality) {
      case MediaQuality.auto:
        return 'Auto';
      case MediaQuality.low:
        return '360p';
      case MediaQuality.medium:
        return '720p';
      case MediaQuality.high:
        return '1080p';
      case MediaQuality.original:
        return 'Original';
    }
  }
}

/// Video quality options
enum MediaQuality {
  auto,
  low,
  medium,
  high,
  original,
}

/// Smart image viewer with user controls
class SmartImageViewer extends StatefulWidget {
  final String imageUrl;
  final String? thumbnailUrl;
  final bool allowZoom;
  final bool allowDownload;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;

  const SmartImageViewer({
    super.key,
    required this.imageUrl,
    this.thumbnailUrl,
    this.allowZoom = true,
    this.allowDownload = true,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
  });

  @override
  State<SmartImageViewer> createState() => _SmartImageViewerState();
}

class _SmartImageViewerState extends State<void SmartImageViewer {
  bool isLoading = true;
  bool hasError = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap?.call();
      },
      onDoubleTap: () {
        if (widget.allowZoom) {
          HapticFeedback.mediumImpact();
          widget.onDoubleTap?.call();
        }
      },
      onLongPress: () {
        HapticFeedback.heavyImpact();
        widget.onLongPress?.call();
        showImageOptions();
      },
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: buildImageContent(),
      ),
    );
  }

  Widget buildImageContent() {
    if (hasError) {
      return buildErrorWidget();
    }
    
    if (isLoading) {
      return buildLoadingWidget();
    }
    
    if (widget.allowZoom) {
      return InteractiveViewer(
        child: Image.network(
          widget.imageUrl,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.contain,
        ),
      );
    }
    
    return Image.network(
      widget.imageUrl,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.contain,
    );
  }

  Widget buildLoadingWidget() {
    return widget.thumbnailUrl != null
        ? Image.network(
            widget.thumbnailUrl!,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          )
        : const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          );
  }

  Widget buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.broken_image,
            size: 64,
            color: AppTheme.secondaryTextColor,
          ),
          const SizedBox(height: AppTheme.smSpacing),
          Text(
            'Failed to load image',
            style: TextStyle(
              color: AppTheme.secondaryTextColor,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: AppTheme.smSpacing),
          ElevatedButton(
            onPressed: retryLoad,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void retryLoad() {
    setState(() {
      isLoading = true;
      hasError = false;
    });
    
    // Simulate reload
    Future.delayed(const Duration(milliseconds: 1000), () {
      setState(() {
        isLoading = false;
        hasError = true; // Simulate error for demo
      });
    });
  }

  void showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppTheme.mdPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Image Options',
              style: AppTheme.titleStyle,
            ),
            const SizedBox(height: AppTheme.mdSpacing),
            ListTile(
              leading: const Icon(Icons.download, color: AppTheme.primaryColor),
              title: const Text('Download Image'),
              onTap: () {
                Navigator.of(context).pop();
                // TODO: Implement download
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: AppTheme.primaryColor),
              title: const Text('Copy Link'),
              onTap: () {
                Navigator.of(context).pop();
                // TODO: Implement copy link
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: AppTheme.primaryColor),
              title: const Text('Share'),
              onTap: () {
                Navigator.of(context).pop();
                // TODO: Implement share
              },
            ),
          ],
        ),
      ),
    );
  }
}

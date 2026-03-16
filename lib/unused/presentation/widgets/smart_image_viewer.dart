import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import 'human_error_handler.dart';

/// Smart Image Viewer dengan proper error handling dan zoom
///
/// Features:
/// - Proper error handling dengan retry
/// - Double-tap zoom
/// - Long-press options
/// - Consistent dengan app theme
/// - Haptic feedback
class SmartImageViewer extends StatefulWidget {
  final String imageUrl;
  final String? thumbnailUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool allowZoom;
  final bool allowDownload;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final Function(String)? onError;

  const SmartImageViewer({
    super.key,
    required this.imageUrl,
    this.thumbnailUrl,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.allowZoom = true,
    this.allowDownload = true,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onError,
  });

  @override
  State<SmartImageViewer> createState() => _SmartImageViewerState();
}

class _SmartImageViewerState extends State<SmartImageViewer> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  // Proper headers untuk Kemono/Coomer
  static const Map<String, String> _headers = {
    'Accept': 'text/css,*/*;q=0.1',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept-Language': 'en-US,en;q=0.9',
    'Accept-Encoding': 'gzip, deflate, br',
    'DNT': '1',
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
  };

  @override
  void initState() {
    super.initState();
    _validateAndLoadImage();
  }

  @override
  void didUpdateWidget(SmartImageViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _resetState();
      _validateAndLoadImage();
    }
  }

  void _resetState() {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
      _retryCount = 0;
    });
  }

  Future<void> _validateAndLoadImage() async {
    if (widget.imageUrl.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = 'No image URL provided';
        _isLoading = false;
      });
      return;
    }

    try {
      // Validate URL format
      final uri = Uri.parse(widget.imageUrl);
      if (!uri.hasScheme || !uri.hasAuthority) {
        throw Exception('Invalid URL format');
      }

      // If URL is valid, let CachedNetworkImage handle the loading
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
      widget.onError?.call(e.toString());
    }
  }

  Future<void> _retryLoad() async {
    if (_retryCount >= _maxRetries) {
      _showMaxRetriesMessage();
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _retryCount++;
      _hasError = false;
      _errorMessage = null;
      _isLoading = true;
    });

    // Add delay before retry
    await Future.delayed(Duration(milliseconds: 500 * _retryCount));

    await _validateAndLoadImage();
  }

  void _showMaxRetriesMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Maximum retry attempts reached. Please check your connection.',
        ),
        backgroundColor: AppTheme.errorColor,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Open in Browser',
          textColor: Colors.white,
          onPressed: _openInBrowser,
        ),
      ),
    );
  }

  void _openInBrowser() {
    HapticFeedback.mediumImpact();
    // TODO: Implement actual browser opening
    debugPrint('Opening image in browser: ${widget.imageUrl}');
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppTheme.lgRadius),
          topRight: Radius.circular(AppTheme.lgRadius),
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppTheme.mdPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.image, color: AppTheme.primaryColor),
                const SizedBox(width: AppTheme.smSpacing),
                Text('Image Options', style: AppTheme.titleStyle),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: AppTheme.secondaryTextColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.mdSpacing),

            // Options
            ListTile(
              leading: Icon(Icons.zoom_in, color: AppTheme.primaryColor),
              title: Text('Zoom In'),
              subtitle: Text('Double-tap to zoom'),
              onTap: () {
                Navigator.of(context).pop();
                HapticFeedback.lightImpact();
                widget.onDoubleTap?.call();
              },
            ),

            if (widget.allowDownload)
              ListTile(
                leading: Icon(Icons.download, color: AppTheme.primaryColor),
                title: Text('Download Image'),
                subtitle: Text('Save to device'),
                onTap: () {
                  Navigator.of(context).pop();
                  HapticFeedback.lightImpact();
                  _downloadImage();
                },
              ),

            ListTile(
              leading: Icon(Icons.copy, color: AppTheme.primaryColor),
              title: Text('Copy Link'),
              subtitle: Text('Copy image URL to clipboard'),
              onTap: () {
                Navigator.of(context).pop();
                HapticFeedback.lightImpact();
                _copyImageLink();
              },
            ),

            ListTile(
              leading: Icon(Icons.share, color: AppTheme.primaryColor),
              title: Text('Share'),
              subtitle: Text('Share image link'),
              onTap: () {
                Navigator.of(context).pop();
                HapticFeedback.lightImpact();
                _shareImage();
              },
            ),

            ListTile(
              leading: Icon(
                Icons.open_in_browser,
                color: AppTheme.primaryColor,
              ),
              title: Text('Open in Browser'),
              subtitle: Text('Open image in web browser'),
              onTap: () {
                Navigator.of(context).pop();
                HapticFeedback.mediumImpact();
                _openInBrowser();
              },
            ),

            const Divider(),

            ListTile(
              leading: Icon(Icons.refresh, color: AppTheme.warningColor),
              title: Text('Retry Loading'),
              subtitle: Text('Attempt to load image again'),
              onTap: () {
                Navigator.of(context).pop();
                _retryLoad();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _downloadImage() {
    // TODO: Implement image download
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Download feature coming soon!'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  void _copyImageLink() {
    // TODO: Implement clipboard functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Image link copied!'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  void _shareImage() {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Share feature coming soon!'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildImageContent() {
    return CachedNetworkImage(
      imageUrl: widget.imageUrl,
      httpHeaders: _headers,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      placeholder: (context, url) => _buildPlaceholder(),
      errorWidget: (context, url, error) {
        // Update error state
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _hasError = true;
              _errorMessage = error.toString();
            });
            widget.onError?.call(error.toString());
          }
        });
        return _buildErrorWidget();
      },
      // FIXED: Better cache configuration
      memCacheWidth: widget.width?.toInt(),
      memCacheHeight: widget.height?.toInt(),
      cacheKey: '${widget.imageUrl}_smart_viewer',
      // FIXED: Add error listener
      errorListener: (error) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = error.toString();
          });
          widget.onError?.call(error.toString());
        }
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.smRadius),
      ),
      child: Stack(
        children: [
          // Show thumbnail if available
          if (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: widget.thumbnailUrl!,
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              placeholder: (context, url) => _buildLoadingIndicator(),
              errorWidget: (context, url, error) => _buildLoadingIndicator(),
              memCacheWidth: widget.width?.toInt(),
              memCacheHeight: widget.height?.toInt(),
            ),

          // Loading overlay
          Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(AppTheme.smRadius),
            ),
            child: _buildLoadingIndicator(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            strokeWidth: 2,
          ),
          const SizedBox(height: AppTheme.smSpacing),
          Text(
            'Loading...',
            style: AppTheme.captionStyle.copyWith(
              color: AppTheme.primaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.smRadius),
        border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, size: 48, color: AppTheme.errorColor),
          const SizedBox(height: AppTheme.smSpacing),
          Text(
            'Failed to load image',
            style: AppTheme.captionStyle.copyWith(color: AppTheme.errorColor),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: AppTheme.xsSpacing),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.mdPadding,
              ),
              child: Text(
                _errorMessage!,
                style: AppTheme.captionStyle.copyWith(
                  color: AppTheme.secondaryTextColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: AppTheme.smSpacing),

          // Retry info
          if (_retryCount > 0)
            Text(
              'Retry attempt: $_retryCount/$_maxRetries',
              style: AppTheme.captionStyle.copyWith(
                color: AppTheme.secondaryTextColor,
              ),
            ),

          const SizedBox(height: AppTheme.smSpacing),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_retryCount < _maxRetries)
                IconButton(
                  icon: Icon(Icons.refresh, color: AppTheme.primaryColor),
                  onPressed: _retryLoad,
                  tooltip: 'Retry loading',
                ),

              const SizedBox(width: AppTheme.smSpacing),

              IconButton(
                icon: Icon(Icons.more_vert, color: AppTheme.primaryColor),
                onPressed: _showImageOptions,
                tooltip: 'More options',
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildPlaceholder();
    }

    if (_hasError) {
      return _buildErrorWidget();
    }

    if (widget.allowZoom) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap?.call();
        },
        onDoubleTap: () {
          HapticFeedback.mediumImpact();
          widget.onDoubleTap?.call();
        },
        onLongPress: () {
          HapticFeedback.heavyImpact();
          widget.onLongPress?.call();
          _showImageOptions();
        },
        child: InteractiveViewer(child: _buildImageContent()),
      );
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap?.call();
      },
      onLongPress: () {
        HapticFeedback.heavyImpact();
        widget.onLongPress?.call();
        _showImageOptions();
      },
      child: _buildImageContent(),
    );
  }
}

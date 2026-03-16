import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/post.dart';
import '../../domain/entities/api_source.dart';
import '../providers/posts_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tag_filter_provider.dart';
import '../theme/app_theme.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;
  final ApiSource apiSource;

  const PostDetailScreen({
    super.key, 
    required this.post, 
    required this.apiSource
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> 
    with TickerProviderStateMixin {
  
  // Core Controllers
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;
  
  // State Management
  final bool _showFullText = false;
  final int _currentMediaIndex = 0;
  bool _isLoading = false;
  String? _error;
  
  // Full post data from single post API
  Post? _fullPost;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Load full post data
    _loadFullPost();
    
    // DEBUG: Print post information
    print('=== DEBUG: POST INFORMATION ===');
    print('Post ID: ${widget.post.id}');
    print('Post title: ${widget.post.title}');
    print('Post content length: ${widget.post.content.length}');
    print('Post content preview: ${widget.post.content.length > 100 ? widget.post.content.substring(0, 100) : widget.post.content}');
    print('Post tags count: ${widget.post.tags.length}');
    print('Post tags: ${widget.post.tags}');
    print('=== END POST DEBUG ===');
  }

  /// Load full post data from single post API
  Future<void> _loadFullPost() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final postsProvider = context.read<PostsProvider>();
      await postsProvider.loadSinglePost(
        widget.post.service,
        widget.post.user,
        widget.post.id,
      );
      
      // Get the full post from provider
      final fullPost = postsProvider.posts.firstWhere(
        (p) => p.id == widget.post.id,
        orElse: () => widget.post,
      );
      
      setState(() {
        _fullPost = fullPost;
        _isLoading = false;
      });
      
      // DEBUG: Print full post information
      print('=== DEBUG: FULL POST INFORMATION ===');
      print('Full post content length: ${_fullPost?.content.length}');
      print('Full post content preview: ${_fullPost?.content.length != null && _fullPost!.content.length > 100 ? _fullPost!.content.substring(0, 100) : _fullPost?.content}');
      print('Full post tags count: ${_fullPost?.tags.length}');
      print('Full post tags: ${_fullPost?.tags}');
      print('=== END FULL POST DEBUG ===');
      
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _fullPost = widget.post; // Fallback to original post
      });
      
      print('=== DEBUG: LOAD FULL POST ERROR ===');
      print('Error: $e');
      print('=== END ERROR DEBUG ===');
    }
  }

  /// Get current post (full post if available, otherwise original post)
  Post get _currentPost => _fullPost ?? widget.post;

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // BUILD METHOD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.apiSource == ApiSource.kemono ? 'Kemono' : 'Coomer',
          style: AppTheme.titleStyle.copyWith(
            color: AppTheme.primaryTextColor,
          ),
        ),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.primaryTextColor,
        elevation: 0,
        actions: [
          // Download Button
          IconButton(
            icon: Icon(
              Icons.download,
              color: AppTheme.primaryTextColor,
            ),
            onPressed: _downloadPost,
            tooltip: 'Download in Browser',
          ),
          
          // Share Button
          IconButton(
            icon: Icon(
              Icons.share,
              color: AppTheme.primaryTextColor,
            ),
            onPressed: _sharePost,
          ),
          
          // Bookmark Button
          IconButton(
            icon: Icon(
              _currentPost.saved ? Icons.bookmark : Icons.bookmark_border,
              color: _currentPost.saved 
                  ? AppTheme.primaryColor 
                  : AppTheme.primaryTextColor,
            ),
            onPressed: _toggleBookmark,
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            )
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
              : SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Post Header
                      _buildPostHeader(),
                      
                      // Post Body
                      _buildPostBody(),
                      
                      // Tags Section
                      if (_currentPost.tags.isNotEmpty) _buildTagsSection(),
                      
                      // Raw Links Section
                      _buildRawLinksSection(),
                      
                      // Bottom padding
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  // 🎯 WIDGET BUILDERS

  /// Post Header with Creator Info
  Widget _buildPostHeader() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.mdPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Creator Info
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.cardColor,
                child: Text(
                  _currentPost.user.isNotEmpty 
                      ? _currentPost.user[0].toUpperCase()
                      : '?',
                  style: AppTheme.bodyStyle.copyWith(
                    color: AppTheme.primaryTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.mdSpacing),
              
              // Creator Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Creator Name
                    Text(
                      _currentPost.user.isNotEmpty 
                          ? _currentPost.user
                          : 'Unknown Creator',
                      style: AppTheme.titleStyle.copyWith(
                        color: AppTheme.primaryTextColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Service Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: widget.apiSource == ApiSource.kemono 
                            ? AppTheme.primaryColor.withOpacity(0.1)
                            : AppTheme.secondaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _currentPost.service.toUpperCase(),
                        style: AppTheme.captionStyle.copyWith(
                          color: widget.apiSource == ApiSource.kemono 
                              ? AppTheme.primaryColor
                              : AppTheme.secondaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppTheme.mdSpacing),
          
          // Post Title
          Text(
            _currentPost.title.isNotEmpty 
                ? _currentPost.title
                : 'Untitled Post',
            style: AppTheme.titleStyle.copyWith(
              color: AppTheme.primaryTextColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          
          const SizedBox(height: AppTheme.smSpacing),
          
          // Post Metadata
          Row(
            children: [
              // Published Date
              Icon(
                Icons.schedule,
                size: 16,
                color: AppTheme.secondaryTextColor,
              ),
              const SizedBox(width: 4),
              Text(
                _formatDate(_currentPost.published),
                style: AppTheme.captionStyle.copyWith(
                  color: AppTheme.secondaryTextColor,
                ),
              ),
              
              const SizedBox(width: AppTheme.mdSpacing),
              
              // Post ID
              Icon(
                Icons.tag,
                size: 16,
                color: AppTheme.secondaryTextColor,
              ),
              const SizedBox(width: 4),
              Text(
                'ID: ${_currentPost.id}',
                style: AppTheme.captionStyle.copyWith(
                  color: AppTheme.secondaryTextColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostBody() {
    final contentText = _currentPost.content;
    if (contentText.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppTheme.mdPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Text(
            'Content',
            style: AppTheme.titleStyle.copyWith(
              color: AppTheme.primaryTextColor,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: AppTheme.mdSpacing),
          
          // Simple text display without PostBodyText
          Text(
            contentText,
            style: AppTheme.bodyStyle.copyWith(
              color: AppTheme.primaryTextColor,
              fontSize: 16,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// Build Tags Section
  Widget _buildTagsSection() {
    return Consumer<TagFilterProvider>(
      builder: (context, tagFilter, child) {
        return Container(
          padding: const EdgeInsets.all(AppTheme.mdPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Title
              Text(
                'Tags',
                style: AppTheme.titleStyle.copyWith(
                  color: AppTheme.primaryTextColor,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: AppTheme.mdSpacing),
              
              // Tags Wrap
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _currentPost.tags.map((tag) {
                  final isBlocked = tagFilter.isTagBlocked(tag);
                  return ActionChip(
                    label: Text(
                      '#$tag',
                      style: AppTheme.captionStyle.copyWith(
                        color: isBlocked ? Colors.white : AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    backgroundColor: isBlocked ? AppTheme.errorColor : AppTheme.surfaceColor,
                    onPressed: () {
                      _handleTagTap(tag);
                    },
                    pressElevation: 2,
                    tooltip: isBlocked ? 'Blocked tag - Tap to search' : 'Tap to search for #$tag',
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build Raw Links Section
  Widget _buildRawLinksSection() {
    final rawLinks = _extractRawLinks();
    
    if (rawLinks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.mdPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.link,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Raw Links',
                style: AppTheme.titleStyle.copyWith(
                  color: AppTheme.primaryTextColor,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.mdSpacing),
          
          // List of raw links with download buttons
          ...rawLinks.asMap().entries.map((entry) {
            final index = entry.key;
            final link = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey[300]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Link URL
                    SelectableText(
                      link,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Action buttons
                    Row(
                      children: [
                        // Copy link button
                        IconButton(
                          onPressed: () => _copyToClipboard(link),
                          icon: Icon(
                            Icons.copy,
                            size: 16,
                            color: AppTheme.primaryColor,
                          ),
                          tooltip: 'Copy Link',
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                        
                        const SizedBox(width: 8),
                        
                        // Download in browser button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _downloadLinkInBrowser(link),
                            icon: Icon(
                              Icons.download,
                              size: 16,
                            ),
                            label: Text(
                              'Download',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              minimumSize: Size(0, 32),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Extract raw links from post content
  List<String> _extractRawLinks() {
    final content = _currentPost.content;
    final links = <String>[];
    
    print('=== DEBUG: Extracting links from content ===');
    print('Content length: ${content.length}');
    print('Full content:');
    print(content);
    print('=== END CONTENT ===');
    
    // Use a single, more precise pattern for URLs
    final urlPattern = RegExp(
      r'https?://[^\s<>"\'\]+',
      caseSensitive: false,
    );
    
    final matches = urlPattern.allMatches(content);
    
    print('=== URL PATTERN MATCHES ===');
    for (final match in matches) {
      String url = match.group(0)!;
      print('Raw match: $url');
      
      // Clean the URL
      url = _cleanUrl(url);
      
      // Only add if it's a valid URL and not already in the list
      if (_isValidUrl(url) && !links.contains(url)) {
        links.add(url);
        print('Added cleaned URL: $url');
      } else {
        print('Skipped invalid or duplicate URL: $url');
      }
    }
    print('=== END URL MATCHES ===');
    
    print('=== FINAL RESULTS ===');
    print('Final links count: ${links.length}');
    for (int i = 0; i < links.length; i++) {
      print('Final Link $i: ${links[i]}');
    }
    print('=== END DEBUG ===');
    
    return links;
  }

  /// Clean URL by removing trailing punctuation and HTML artifacts
  String _cleanUrl(String url) {
    // Remove trailing punctuation
    url = url.replaceAll(RegExp(r'[.,;:!?)\]}]+$'), '');
    
    // Remove HTML entities and artifacts
    url = url.replaceAll(RegExp(r'''["'\'>]'''), '');
    
    // Remove HTML closing tags
    url = url.replaceAll(RegExp(r'</[^>]*>$'), '');
    
    return url.trim();
  }

  /// Check if URL is valid and complete
  bool _isValidUrl(String url) {
    if (url.isEmpty) return false;
    
    // Check if it's a proper URL
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAbsolutePath) return false;
    
    // Check if it has a proper domain
    if (!url.contains('://') || url.length < 10) return false;
    
    // Check if it's not just a partial URL
    if (url.endsWith('.com') || url.endsWith('.org') || url.endsWith('.net')) {
      return false; // Incomplete URL
    }
    
    return true;
  }

  // 🎯 HELPER METHODS

  /// Format date for display
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else {
      return '${(difference.inDays / 365).floor()} years ago';
    }
  }

  /// Copy link to clipboard
  void _copyToClipboard(String link) async {
    try {
      await Clipboard.setData(ClipboardData(text: link));
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Link copied to clipboard!'),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to copy link: $e'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  /// Download link in browser
  void _downloadLinkInBrowser(String link) async {
    try {
      if (await canLaunchUrl(Uri.parse(link))) {
        await launchUrl(
          Uri.parse(link),
          mode: LaunchMode.externalApplication,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening link in browser...'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      } else {
        throw Exception('Cannot launch browser');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open browser: $e'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  /// Handle tag tap - navigate to tag search
  void _handleTagTap(String tag) {
    // TODO: Navigate to tag search screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Search for #$tag (coming soon)'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Download post
  void _downloadPost() async {
    try {
      // Build the post URL for browser
      final postUrl = _getPostUrl();
      
      if (await canLaunchUrl(Uri.parse(postUrl))) {
        await launchUrl(
          Uri.parse(postUrl),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open post: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  /// Get post URL for browser
  String _getPostUrl() {
    final domain = widget.apiSource == ApiSource.kemono 
        ? 'https://kemono.cr' 
        : 'https://coomer.st';
    
    return '$domain/${widget.post.service}/user/${widget.post.user}/post/${widget.post.id}';
  }

  /// Share post
  void _sharePost() async {
    try {
      final postUrl = _getPostUrl();
      await Clipboard.setData(ClipboardData(text: postUrl));
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Post link copied to clipboard!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share post: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  /// Toggle bookmark
  void _toggleBookmark() async {
    try {
      final postsProvider = context.read<PostsProvider>();
      await postsProvider.toggleSavePost(_currentPost);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to toggle bookmark: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
}

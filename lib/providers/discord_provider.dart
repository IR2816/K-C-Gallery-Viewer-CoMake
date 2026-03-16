import 'package:flutter/material.dart';
import '../../domain/entities/discord_server.dart';
import '../../domain/entities/discord_channel.dart';
import '../../domain/entities/post.dart';
import '../../data/models/post_model.dart';
import '../../data/services/discord_api_client.dart';

/// Discord Provider - Isolated from PostsProvider
///
/// Manages Discord-specific state and API calls
/// Discord = filesystem + log viewer, NOT creator/post feed
class DiscordProvider with ChangeNotifier {
  final DiscordApiClient _api;

  DiscordProvider(this._api);

  // State management
  bool _isLoading = false;
  bool _isLoadingChannels = false;
  bool _isLoadingPosts = false;
  String? _error;
  String? _channelsError;
  String? _postsError;

  List<DiscordServer> _servers = [];
  List<DiscordChannel> _channels = [];
  final Map<String, List<PostModel>> _channelPosts = {};

  // Getters
  bool get isLoading => _isLoading;
  bool get isLoadingChannels => _isLoadingChannels;
  bool get isLoadingPosts => _isLoadingPosts;
  String? get error => _error;
  String? get channelsError => _channelsError;
  String? get postsError => _postsError;
  List<DiscordServer> get servers => _servers;
  List<DiscordChannel> get channels => _channels;
  Map<String, List<PostModel>> get channelPosts => _channelPosts;
  List<Post> getPostsForChannel(String channelId) {
    final postModels = _channelPosts[channelId] ?? [];
    return postModels
        .map(
          (model) => Post(
            id: model.id,
            user: model.user,
            service: model.service,
            title: model.title,
            content: model.content,
            embedUrl: model.embedUrl,
            sharedFile: model.sharedFile,
            added: model.added,
            published: model.published,
            edited: model.edited,
            attachments: model.attachments,
            file: model.file,
            tags: model.tags,
            saved: model.saved,
          ),
        )
        .toList();
  }

  /// Load Discord servers
  Future<void> loadServers() async {
    _setLoading(true);
    _error = null;

    try {
      _servers = await _api.getServers();
      notifyListeners();
    } catch (e) {
      // Check if this is a 503 error
      if (e.toString().contains('503')) {
        _error =
            'Kemono Discord is temporarily unavailable. Please try again later.';
      } else {
        _error = e.toString();
      }
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// Load channels for a server
  Future<void> loadChannels(String serverId) async {
    _setLoadingChannels(true);
    _channelsError = null;

    try {
      // Try to get server with channels first (more efficient)
      final serverData = await _api.getServerWithChannels(serverId);

      // Extract channels from server response
      List<dynamic> channelsData = [];
      if (serverData['channels'] is List) {
        channelsData = serverData['channels'] as List;
      }

      _channels = channelsData
          .whereType<Map<String, dynamic>>()
          .map(
            (e) => DiscordChannel(
              id: e['id']?.toString() ?? '',
              serverId: e['server_id']?.toString() ?? serverId,
              name: e['name']?.toString() ?? '',
              parentId: e['parent_channel_id']?.toString(),
              isNsfw: e['is_nsfw'] ?? false,
              type: e['type'] ?? 11,
              position: e['position'] ?? 0,
              postCount: e['post_count'] ?? 0,
              emoji: e['icon_emoji']?.toString(),
            ),
          )
          .toList();

      // Sort by position
      _channels.sort((a, b) => a.position.compareTo(b.position));

      notifyListeners();
    } catch (e) {
      // Fallback to lookup channels if server endpoint fails
      try {
        _channels = await _api.lookupChannels(serverId);
        notifyListeners();
      } catch (fallbackError) {
        // Check if this is a 503 error
        if (e.toString().contains('503') ||
            fallbackError.toString().contains('503')) {
          _channelsError =
              'Kemono Discord is temporarily unavailable. Please try again later.';
        } else {
          _channelsError = e.toString();
        }
        notifyListeners();
      }
    } finally {
      _setLoadingChannels(false);
    }
  }

  /// Load posts for a channel
  Future<void> loadChannelPosts(String channelId, {int offset = 0}) async {
    debugPrint(
      '🔍 DEBUG: DiscordProvider.loadChannelPosts - ChannelId: $channelId, Offset: $offset',
    );

    _setLoadingPosts(true);
    _postsError = null;

    try {
      debugPrint(
        '🔍 DEBUG: CALLING API.loadChannelPosts - ChannelId: $channelId, Offset: $offset',
      );
      final posts = await _api.loadChannelPosts(channelId, offset: offset);
      debugPrint('🔍 DEBUG: API RETURNED ${posts.length} POSTS');

      if (offset == 0) {
        _channelPosts[channelId] = posts;
        debugPrint(
          '🔍 DEBUG: SET INITIAL POSTS - ChannelId: $channelId, Count: ${posts.length}',
        );
      } else {
        final existingPosts = _channelPosts[channelId] ?? [];
        final existingIds = existingPosts.map((p) => p.id).toSet();
        final uniquePosts =
            posts.where((p) => !existingIds.contains(p.id)).toList();
        _channelPosts[channelId] = [
          ...existingPosts,
          ...uniquePosts,
        ];
        debugPrint(
          '🔍 DEBUG: APPENDED POSTS - ChannelId: $channelId, Added: ${uniquePosts.length}, Total: ${_channelPosts[channelId]?.length}',
        );
      }

      notifyListeners();
    } catch (e) {
      debugPrint('🔍 DEBUG: API ERROR - ChannelId: $channelId, Error: $e');

      // Check if this is a 503 error
      if (e.toString().contains('503')) {
        _postsError =
            'Kemono Discord is temporarily unavailable. Please try again later.';
      } else {
        _postsError = e.toString();
      }
      notifyListeners();
    } finally {
      _setLoadingPosts(false);
    }
  }

  /// Get channels grouped by hierarchy (file explorer style)
  Map<String, List<DiscordChannel>> getChannelsByHierarchy() {
    final Map<String, List<DiscordChannel>> hierarchy = {};

    // Root level channels (no parent)
    hierarchy['root'] = _channels.where((c) => c.parentId == null).toList();

    // Group by parent
    for (final channel in _channels) {
      if (channel.parentId != null) {
        hierarchy.putIfAbsent(channel.parentId!, () => []).add(channel);
      }
    }

    // Sort each group by position
    for (final group in hierarchy.values) {
      group.sort((a, b) => a.position.compareTo(b.position));
    }

    return hierarchy;
  }

  /// Get post channels only (categories filtered out)
  List<DiscordChannel> get postChannels =>
      _channels.where((c) => c.isPostChannel).toList();

  /// Clear all data
  void clearAll() {
    _servers.clear();
    _channels.clear();
    _channelPosts.clear();
    _error = null;
    _channelsError = null;
    _postsError = null;
    notifyListeners();
  }

  /// Clear posts for specific channel
  void clearChannelPosts(String channelId) {
    _channelPosts.remove(channelId);
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setLoadingChannels(bool loading) {
    _isLoadingChannels = loading;
    notifyListeners();
  }

  void _setLoadingPosts(bool loading) {
    _isLoadingPosts = loading;
    notifyListeners();
  }
}

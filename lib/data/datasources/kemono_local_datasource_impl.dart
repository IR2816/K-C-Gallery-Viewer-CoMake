import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/creator_model.dart';
import '../models/post_model.dart';
import '../models/folder_model.dart';
import 'kemono_local_datasource.dart';

class KemonoLocalDataSourceImpl implements KemonoLocalDataSource {
  final SharedPreferences prefs;

  KemonoLocalDataSourceImpl({required this.prefs});

  static const String _favoriteCreatorsKey = 'favorite_creators';
  static const String _savedPostsKey = 'saved_posts';
  static const String _settingsKey = 'app_settings';
  static const String _foldersKey = 'saved_folders';

  @override
  Future<List<CreatorModel>> getFavoriteCreators() async {
    final jsonString = prefs.getString(_favoriteCreatorsKey);
    if (jsonString == null) return [];

    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((e) => CreatorModel.fromJson(e)).toList();
  }

  @override
  Future<void> saveFavoriteCreator(CreatorModel creator) async {
    final creators = await getFavoriteCreators();
    // Check if creator already exists
    final existingIndex = creators.indexWhere(
      (c) => c.id == creator.id && c.service == creator.service,
    );

    // Create creator with favorited: true
    final favoritedCreator = CreatorModel(
      id: creator.id,
      service: creator.service,
      name: creator.name,
      indexed: creator.indexed,
      updated: creator.updated,
      favorited: true, // CRITICAL: Set favorited to true!
    );

    if (existingIndex != -1) {
      // Creator already exists, update it
      creators[existingIndex] = favoritedCreator;
    } else {
      // Add new creator
      creators.add(favoritedCreator);
    }

    final jsonString = json.encode(creators.map((e) => e.toJson()).toList());
    await prefs.setString(_favoriteCreatorsKey, jsonString);
  }

  @override
  Future<void> removeFavoriteCreator(String id, {String? service}) async {
    final creators = await getFavoriteCreators();
    final initialLength = creators.length;
    // Remove creator by ID AND service to avoid cross-domain conflicts
    if (service != null) {
      creators.removeWhere((c) => c.id == id && c.service == service);
    } else {
      // Fallback: remove by ID only (backward compatibility)
      creators.removeWhere((c) => c.id == id);
    }

    // Only save if something was actually removed
    if (creators.length < initialLength) {
      final jsonString = json.encode(creators.map((e) => e.toJson()).toList());
      await prefs.setString(_favoriteCreatorsKey, jsonString);
    }
  }

  @override
  Future<List<PostModel>> getSavedPosts() async {
    final jsonString = prefs.getString(_savedPostsKey);
    if (jsonString == null) return [];

    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((e) => PostModel.fromJson(e)).toList();
  }

  @override
  Future<void> savePost(PostModel post) async {
    final posts = await getSavedPosts();
    posts.removeWhere((p) => p.id == post.id);
    posts.insert(0, post);

    final jsonString = json.encode(posts.map((e) => e.toJson()).toList());
    await prefs.setString(_savedPostsKey, jsonString);
  }

  @override
  Future<void> removeSavedPost(String id) async {
    final posts = await getSavedPosts();
    posts.removeWhere((p) => p.id == id);

    final jsonString = json.encode(posts.map((e) => e.toJson()).toList());
    await prefs.setString(_savedPostsKey, jsonString);
  }

  @override
  Future<Map<String, dynamic>> getSettings() async {
    final jsonString = prefs.getString(_settingsKey);
    if (jsonString == null) {
      return {
        'theme_mode': 'system',
        'grid_columns': 2,
        'auto_play_video': false,
        'default_service': 'all',
        'nsfw_filter': false,
        'load_thumbnails': true,
        'default_api_source': 'kemono',
      };
    }
    return json.decode(jsonString);
  }

  @override
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    final jsonString = json.encode(settings);
    await prefs.setString(_settingsKey, jsonString);
  }

  // Folder management methods
  @override
  Future<List<FolderModel>> getFolders() async {
    final jsonString = prefs.getString(_foldersKey);
    if (jsonString == null) return [];

    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((e) => FolderModel.fromJson(e)).toList();
  }

  @override
  Future<void> saveFolder(FolderModel folder) async {
    final folders = await getFolders();
    final existingIndex = folders.indexWhere((f) => f.id == folder.id);

    if (existingIndex != -1) {
      folders[existingIndex] = folder;
    } else {
      folders.add(folder);
    }

    final jsonString = json.encode(folders.map((e) => e.toJson()).toList());
    await prefs.setString(_foldersKey, jsonString);
  }

  @override
  Future<void> removeFolder(String folderId) async {
    final folders = await getFolders();
    folders.removeWhere((f) => f.id == folderId);

    final jsonString = json.encode(folders.map((e) => e.toJson()).toList());
    await prefs.setString(_foldersKey, jsonString);
  }

  @override
  Future<void> addPostToFolder(String folderId, String postId) async {
    final folders = await getFolders();
    final folderIndex = folders.indexWhere((f) => f.id == folderId);

    if (folderIndex != -1) {
      final folder = folders[folderIndex];
      if (!folder.postIds.contains(postId)) {
        final updatedFolder = folder.copyWith(
          postIds: [...folder.postIds, postId],
          updatedAt: DateTime.now(),
        );
        folders[folderIndex] = updatedFolder;

        final jsonString = json.encode(folders.map((e) => e.toJson()).toList());
        await prefs.setString(_foldersKey, jsonString);
      }
    }
  }

  @override
  Future<void> removePostFromFolder(String folderId, String postId) async {
    final folders = await getFolders();
    final folderIndex = folders.indexWhere((f) => f.id == folderId);

    if (folderIndex != -1) {
      final folder = folders[folderIndex];
      final updatedPostIds = folder.postIds
          .where((id) => id != postId)
          .toList();
      final updatedFolder = folder.copyWith(
        postIds: updatedPostIds,
        updatedAt: DateTime.now(),
      );
      folders[folderIndex] = updatedFolder;

      final jsonString = json.encode(folders.map((e) => e.toJson()).toList());
      await prefs.setString(_foldersKey, jsonString);
    }
  }
}

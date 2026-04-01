import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/creator_model.dart';
import '../models/post_model.dart';
import '../models/folder_model.dart';
import '../services/prefs_store.dart';
import 'kemono_local_datasource.dart';

class KemonoLocalDataSourceImpl implements KemonoLocalDataSource {
  final SharedPreferences prefs;
  final PrefsStore prefsStore;

  KemonoLocalDataSourceImpl({required this.prefs})
      : prefsStore = PrefsStore(prefs: prefs);

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
    final favoritedCreator = CreatorModel(
      id: creator.id,
      service: creator.service,
      name: creator.name,
      indexed: creator.indexed,
      updated: creator.updated,
      favorited: true,
    );

    await prefsStore.upsert<CreatorModel>(
      _favoriteCreatorsKey,
      favoritedCreator,
      (c) => c.id == creator.id && c.service == creator.service,
      (c) => c.toJson(),
      (json) => CreatorModel.fromJson(json),
    );
  }

  @override
  Future<void> removeFavoriteCreator(String id, {String? service}) async {
    await prefsStore.removeWhere<CreatorModel>(
      _favoriteCreatorsKey,
      (c) => c.id == id && (service == null || c.service == service),
      (c) => c.toJson(),
      (json) => CreatorModel.fromJson(json),
    );
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
    await prefsStore.upsert<PostModel>(
      _savedPostsKey,
      post,
      (p) => p.id == post.id,
      (p) => p.toJson(),
      (json) => PostModel.fromJson(json),
      prepend: true,
    );
  }

  @override
  Future<void> removeSavedPost(String id) async {
    await prefsStore.removeWhere<PostModel>(
      _savedPostsKey,
      (p) => p.id == id,
      (p) => p.toJson(),
      (json) => PostModel.fromJson(json),
    );
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
    final initialLength = folders.length;
    folders.removeWhere((f) => f.id == folderId);

    // Only persist if something was actually removed
    if (folders.length < initialLength) {
      final jsonString = json.encode(folders.map((e) => e.toJson()).toList());
      await prefs.setString(_foldersKey, jsonString);
    }
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

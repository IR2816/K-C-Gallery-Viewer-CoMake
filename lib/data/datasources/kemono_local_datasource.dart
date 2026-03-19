import '../models/creator_model.dart';
import '../models/post_model.dart';
import '../models/folder_model.dart';

abstract class KemonoLocalDataSource {
  Future<List<CreatorModel>> getFavoriteCreators();
  Future<void> saveFavoriteCreator(CreatorModel creator);
  Future<void> removeFavoriteCreator(String id, {String? service});
  Future<List<PostModel>> getSavedPosts();
  Future<void> savePost(PostModel post);
  Future<void> removeSavedPost(String id);
  Future<Map<String, dynamic>> getSettings();
  Future<void> saveSettings(Map<String, dynamic> settings);

  // Folder management
  Future<List<FolderModel>> getFolders();
  Future<void> saveFolder(FolderModel folder);
  Future<void> removeFolder(String folderId);
  Future<void> addPostToFolder(String folderId, String postId);
  Future<void> removePostFromFolder(String folderId, String postId);
}

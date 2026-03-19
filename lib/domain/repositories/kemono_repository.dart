import '../entities/post.dart';
import '../entities/creator.dart';
import '../entities/comment.dart';
import '../entities/api_source.dart';

abstract class KemonoRepository {
  Future<List<Post>> getCreatorPosts(
    String service,
    String creatorId, {
    int offset = 0,
    ApiSource apiSource = ApiSource.kemono,
  });
  Future<Post> getPost(
    String service,
    String creatorId,
    String postId, {
    ApiSource apiSource = ApiSource.kemono,
  });
  Future<List<Post>> searchPosts(
    String query, {
    int offset = 0,
    int limit = 50,
    ApiSource apiSource = ApiSource.kemono,
  });
  Future<List<Post>> getPostsByTags(
    List<String> tags, {
    int offset = 0,
    ApiSource apiSource = ApiSource.kemono,
  });
  Future<List<Creator>> getCreators({
    String? service,
    ApiSource apiSource = ApiSource.kemono,
  });
  Future<Creator> getCreator(
    String service,
    String creatorId, {
    ApiSource apiSource = ApiSource.kemono,
  });
  Future<List<dynamic>> getCreatorLinks(
    String service,
    String creatorId, {
    ApiSource apiSource = ApiSource.kemono,
  });
  Future<List<Creator>> searchCreators(
    String query, {
    ApiSource apiSource = ApiSource.kemono,
    String? service,
  });
  Future<void> saveFavoriteCreator(Creator creator);
  Future<void> removeFavoriteCreator(String id, {String? service});
  Future<List<Creator>> getFavoriteCreators();
  Future<void> savePost(Post post);
  Future<void> removeSavedPost(String id);
  Future<List<Post>> getSavedPosts({int offset = 0, int limit = 50});
  Future<Map<String, dynamic>> getSettings();
  Future<void> saveSettings(Map<String, dynamic> settings);
  Future<List<Comment>> getComments(
    String postId,
    String service,
    String creatorId,
  );
  String? getLastSuccessfulDomain();
}

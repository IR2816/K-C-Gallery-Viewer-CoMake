import '../models/creator_model.dart';
import '../models/post_model.dart';
import '../../domain/entities/api_source.dart';

abstract class KemonoRemoteDataSource {
  Future<List<CreatorModel>> getCreators({
    String? service,
    ApiSource apiSource = ApiSource.kemono,
  });
  Future<CreatorModel> getCreator(
    String service,
    String creatorId, {
    ApiSource apiSource = ApiSource.kemono,
  });
  Future<List<PostModel>> getCreatorPosts(
    String service,
    String creatorId, {
    int offset = 0,
    ApiSource apiSource = ApiSource.kemono,
  });
  Future<List<dynamic>> getCreatorLinks(
    String service,
    String creatorId, {
    ApiSource apiSource = ApiSource.kemono,
  });
  Future<PostModel> getPost(
    String service,
    String creatorId,
    String postId, {
    ApiSource apiSource = ApiSource.kemono,
  });
  Future<List<PostModel>> searchPosts(
    String query, {
    int offset = 0,
    int limit = 50,
    ApiSource apiSource = ApiSource.kemono,
  });
  Future<List<dynamic>> getComments(
    String postId,
    String service,
    String creatorId,
  );
}

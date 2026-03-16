import '../repositories/kemono_repository.dart';
import '../entities/post.dart';
import '../../data/datasources/kemono_remote_datasource.dart';

class GetCreatorPosts {
  final KemonoRepository repository;

  GetCreatorPosts(this.repository);

  Future<List<Post>> call(
    String service,
    String creatorId, {
    int offset = 0,
    ApiSource apiSource = ApiSource.kemono,
  }) {
    return repository.getCreatorPosts(
      service,
      creatorId,
      offset: offset,
      apiSource: apiSource,
    );
  }
}

import '../repositories/kemono_repository.dart';
import '../entities/post.dart';
import '../../data/datasources/kemono_remote_datasource.dart';

class SearchPosts {
  final KemonoRepository repository;

  SearchPosts(this.repository);

  Future<List<Post>> call(
    String query, {
    int offset = 0,
    int limit = 50,
    ApiSource apiSource = ApiSource.kemono,
  }) {
    return repository.searchPosts(
      query,
      offset: offset,
      limit: limit,
      apiSource: apiSource,
    );
  }
}

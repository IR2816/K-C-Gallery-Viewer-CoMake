import '../repositories/kemono_repository.dart';
import '../entities/post.dart';
import '../../data/datasources/kemono_remote_datasource.dart';

class SearchByTags {
  final KemonoRepository repository;

  SearchByTags(this.repository);

  Future<List<Post>> call(
    List<String> tags, {
    int offset = 0,
    ApiSource apiSource = ApiSource.kemono,
  }) {
    return repository.getPostsByTags(
      tags,
      offset: offset,
      apiSource: apiSource,
    );
  }
}

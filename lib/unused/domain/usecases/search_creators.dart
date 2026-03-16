import '../repositories/kemono_repository.dart';
import '../entities/creator.dart';
import '../../data/datasources/kemono_remote_datasource.dart';

class SearchCreators {
  final KemonoRepository repository;

  SearchCreators(this.repository);

  Future<List<Creator>> call(
    String query, {
    ApiSource apiSource = ApiSource.kemono,
    String? service,
  }) {
    return repository.searchCreators(
      query,
      apiSource: apiSource,
      service: service,
    );
  }
}

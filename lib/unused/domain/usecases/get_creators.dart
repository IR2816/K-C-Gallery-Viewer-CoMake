import '../repositories/kemono_repository.dart';
import '../entities/creator.dart';
import '../../data/datasources/kemono_remote_datasource.dart';

class GetCreators {
  final KemonoRepository repository;

  GetCreators(this.repository);

  Future<List<Creator>> call({
    String? service,
    ApiSource apiSource = ApiSource.kemono,
  }) {
    return repository.getCreators(service: service, apiSource: apiSource);
  }
}

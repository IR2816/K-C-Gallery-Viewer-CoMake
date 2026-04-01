import '../../domain/entities/post_file.dart';
import '../utils/json_field_utils.dart';

class PostFileModel extends PostFile {
  PostFileModel({
    required super.id,
    required super.name,
    required super.path,
    super.type,
    super.size,
  });

  factory PostFileModel.fromJson(Map<String, dynamic> json) {
    final typeCandidate = JsonFieldUtils.string(
      json,
      'type',
      defaultValue: JsonFieldUtils.string(json, 'mime'),
    );

    return PostFileModel(
      id: JsonFieldUtils.string(json, 'id'),
      name: JsonFieldUtils.string(json, 'name'),
      path: JsonFieldUtils.string(json, 'path'),
      type: typeCandidate.isNotEmpty ? typeCandidate : null,
      size: JsonFieldUtils.intValue(json, 'size', defaultValue: 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'path': path, 'type': type, 'size': size};
  }
}

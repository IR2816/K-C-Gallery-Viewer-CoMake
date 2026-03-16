import '../../domain/entities/post_file.dart';

class PostFileModel extends PostFile {
  PostFileModel({
    required super.id,
    required super.name,
    required super.path,
    super.type,
    super.size,
  });

  factory PostFileModel.fromJson(Map<String, dynamic> json) {
    return PostFileModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      path: json['path'] ?? '',
      type: (json['type'] ?? json['mime'])?.toString(),
      size: json['size'] is int
          ? json['size'] as int
          : int.tryParse(json['size']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'path': path, 'type': type, 'size': size};
  }
}

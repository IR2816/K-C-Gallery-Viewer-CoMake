class PostFile {
  final String id;
  final String name;
  final String path;
  final String? type;
  final int? size;

  PostFile({
    required this.id,
    required this.name,
    required this.path,
    this.type,
    this.size,
  });
}

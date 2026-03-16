/// Folder model for organizing saved posts
class FolderModel {
  final String id;
  final String name;
  final List<String> postIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  FolderModel({
    required this.id,
    required this.name,
    required this.postIds,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create empty folder
  factory FolderModel.create(String name) {
    final now = DateTime.now();
    return FolderModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      postIds: [],
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'postIds': postIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create from JSON
  factory FolderModel.fromJson(Map<String, dynamic> json) {
    return FolderModel(
      id: json['id'] as String,
      name: json['name'] as String,
      postIds: List<String>.from(json['postIds'] as List),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Copy with new values
  FolderModel copyWith({
    String? id,
    String? name,
    List<String>? postIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FolderModel(
      id: id ?? this.id,
      name: name ?? this.name,
      postIds: postIds ?? this.postIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get post count
  int get postCount => postIds.length;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FolderModel &&
        other.id == id &&
        other.name == name &&
        other.postIds.length == postIds.length;
  }

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ postIds.length.hashCode;

  @override
  String toString() =>
      'FolderModel(id: $id, name: $name, postCount: $postCount)';
}

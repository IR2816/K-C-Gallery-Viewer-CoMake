/// Smart Bookmark Model untuk advanced bookmarking
///
/// Support:
/// - Bookmark per creator
/// - Bookmark per tag
/// - Bookmark media spesifik
/// - Bookmark collections
/// - Domain & API source tracking
class BookmarkModel {
  final String id;
  final BookmarkType type;
  final String? creatorId;
  final String? creatorName;
  final String? tag;
  final String? postId;
  final String? mediaUrl;
  final String? title;
  final DateTime createdAt;
  final String? collectionId;
  final String? collectionName;

  // Additional data for creator bookmarks
  final String? creatorService;
  final String? creatorAvatar;

  // NEW: Domain & API source tracking
  final String? apiSource; // 'kemono' or 'coomer'
  final String? domain; // 'kemono.cr' or 'coomer.st'

  const BookmarkModel({
    required this.id,
    required this.type,
    this.creatorId,
    this.creatorName,
    this.tag,
    this.postId,
    this.mediaUrl,
    this.title,
    required this.createdAt,
    this.collectionId,
    this.collectionName,
    this.creatorService,
    this.creatorAvatar,
    this.apiSource,
    this.domain,
  });

  /// Creator bookmark
  factory BookmarkModel.creator({
    required String id,
    required String creatorId,
    required String creatorName,
    String? creatorService,
    String? creatorAvatar,
    String? collectionId,
    String? collectionName,
    String? apiSource,
    String? domain,
  }) {
    return BookmarkModel(
      id: id,
      type: BookmarkType.creator,
      creatorId: creatorId,
      creatorName: creatorName,
      creatorService: creatorService,
      creatorAvatar: creatorAvatar,
      createdAt: DateTime.now(),
      collectionId: collectionId,
      collectionName: collectionName,
      apiSource: apiSource,
      domain: domain,
    );
  }

  /// Tag bookmark
  factory BookmarkModel.tag({
    required String id,
    required String tag,
    String? creatorId,
    String? creatorName,
    String? collectionId,
    String? collectionName,
  }) {
    return BookmarkModel(
      id: id,
      type: BookmarkType.tag,
      tag: tag,
      creatorId: creatorId,
      creatorName: creatorName,
      createdAt: DateTime.now(),
      collectionId: collectionId,
      collectionName: collectionName,
    );
  }

  /// Post bookmark
  factory BookmarkModel.post({
    required String id,
    required String postId,
    required String title,
    String? creatorId,
    String? creatorName,
    String? collectionId,
    String? collectionName,
  }) {
    return BookmarkModel(
      id: id,
      type: BookmarkType.post,
      postId: postId,
      title: title,
      creatorId: creatorId,
      creatorName: creatorName,
      createdAt: DateTime.now(),
      collectionId: collectionId,
      collectionName: collectionName,
    );
  }

  /// Media bookmark
  factory BookmarkModel.media({
    required String id,
    required String mediaUrl,
    required String title,
    String? postId,
    String? creatorId,
    String? creatorName,
    String? collectionId,
    String? collectionName,
  }) {
    return BookmarkModel(
      id: id,
      type: BookmarkType.media,
      mediaUrl: mediaUrl,
      title: title,
      postId: postId,
      creatorId: creatorId,
      creatorName: creatorName,
      createdAt: DateTime.now(),
      collectionId: collectionId,
      collectionName: collectionName,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.index,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'tag': tag,
      'postId': postId,
      'mediaUrl': mediaUrl,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'collectionId': collectionId,
      'collectionName': collectionName,
      'creatorService': creatorService,
      'creatorAvatar': creatorAvatar,
    };
  }

  /// Create from JSON
  factory BookmarkModel.fromJson(Map<String, dynamic> json) {
    return BookmarkModel(
      id: json['id'],
      type: BookmarkType.values[json['type']],
      creatorId: json['creatorId'],
      creatorName: json['creatorName'],
      tag: json['tag'],
      postId: json['postId'],
      mediaUrl: json['mediaUrl'],
      title: json['title'],
      createdAt: DateTime.parse(json['createdAt']),
      collectionId: json['collectionId'],
      collectionName: json['collectionName'],
      creatorService: json['creatorService'],
      creatorAvatar: json['creatorAvatar'],
    );
  }

  /// Copy with new values
  BookmarkModel copyWith({
    String? id,
    BookmarkType? type,
    String? creatorId,
    String? creatorName,
    String? tag,
    String? postId,
    String? mediaUrl,
    String? title,
    DateTime? createdAt,
    String? collectionId,
    String? collectionName,
    String? creatorService,
    String? creatorAvatar,
  }) {
    return BookmarkModel(
      id: id ?? this.id,
      type: type ?? this.type,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      tag: tag ?? this.tag,
      postId: postId ?? this.postId,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      collectionId: collectionId ?? this.collectionId,
      collectionName: collectionName ?? this.collectionName,
      creatorService: creatorService ?? this.creatorService,
      creatorAvatar: creatorAvatar ?? this.creatorAvatar,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BookmarkModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'BookmarkModel(id: $id, type: $type, title: $title)';
  }
}

/// Bookmark types
enum BookmarkType { creator, tag, post, media }

/// Bookmark collection untuk grouping
class BookmarkCollection {
  final String id;
  final String name;
  final String description;
  final DateTime createdAt;
  final int itemCount;

  const BookmarkCollection({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.itemCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'itemCount': itemCount,
    };
  }

  factory BookmarkCollection.fromJson(Map<String, dynamic> json) {
    return BookmarkCollection(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      createdAt: DateTime.parse(json['createdAt']),
      itemCount: json['itemCount'],
    );
  }
}

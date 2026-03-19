import 'dart:convert';

/// A locally-stored bookmark of a post, enriched with user annotations.
class PostBookmark {
  final String id; // unique local identifier
  final String postId;
  final String creatorName; // post.user
  final String service; // post.service (kemono, coomer, …)
  final String title;
  final String content;
  final DateTime published;
  final String personalNotes;
  final int? rating; // 1-5 stars, nullable
  final List<String> tags; // user-assigned tags, max 5
  final DateTime bookmarkedDate;
  final int mediaCount; // total images + videos + audio
  final String? thumbnailUrl; // used for offline display

  const PostBookmark({
    required this.id,
    required this.postId,
    required this.creatorName,
    required this.service,
    required this.title,
    required this.content,
    required this.published,
    this.personalNotes = '',
    this.rating,
    this.tags = const [],
    required this.bookmarkedDate,
    this.mediaCount = 0,
    this.thumbnailUrl,
  });

  PostBookmark copyWith({
    String? personalNotes,
    int? rating,
    bool clearRating = false,
    List<String>? tags,
  }) {
    return PostBookmark(
      id: id,
      postId: postId,
      creatorName: creatorName,
      service: service,
      title: title,
      content: content,
      published: published,
      personalNotes: personalNotes ?? this.personalNotes,
      rating: clearRating ? null : (rating ?? this.rating),
      tags: tags ?? this.tags,
      bookmarkedDate: bookmarkedDate,
      mediaCount: mediaCount,
      thumbnailUrl: thumbnailUrl,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'postId': postId,
    'creatorName': creatorName,
    'service': service,
    'title': title,
    'content': content,
    'published': published.millisecondsSinceEpoch,
    'personalNotes': personalNotes,
    'rating': rating,
    'tags': tags,
    'bookmarkedDate': bookmarkedDate.millisecondsSinceEpoch,
    'mediaCount': mediaCount,
    'thumbnailUrl': thumbnailUrl,
  };

  factory PostBookmark.fromJson(Map<String, dynamic> json) => PostBookmark(
    id: json['id'] as String,
    postId: json['postId'] as String,
    creatorName: json['creatorName'] as String? ?? '',
    service: json['service'] as String? ?? '',
    title: json['title'] as String? ?? '',
    content: json['content'] as String? ?? '',
    published: DateTime.fromMillisecondsSinceEpoch(
      json['published'] as int? ?? 0,
    ),
    personalNotes: json['personalNotes'] as String? ?? '',
    rating: json['rating'] as int?,
    tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
    bookmarkedDate: DateTime.fromMillisecondsSinceEpoch(
      json['bookmarkedDate'] as int? ?? 0,
    ),
    mediaCount: json['mediaCount'] as int? ?? 0,
    thumbnailUrl: json['thumbnailUrl'] as String?,
  );

  /// Serialize to a JSON string for SharedPreferences storage.
  String toJsonString() => jsonEncode(toJson());

  /// Deserialize from a JSON string.
  static PostBookmark fromJsonString(String source) =>
      PostBookmark.fromJson(jsonDecode(source) as Map<String, dynamic>);
}

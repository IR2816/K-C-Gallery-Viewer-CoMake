class Comment {
  final String id;
  final String username;
  final String? avatar;
  final String content;
  final DateTime timestamp;
  final String postId;
  final String service;

  const Comment({
    required this.id,
    required this.username,
    this.avatar,
    required this.content,
    required this.timestamp,
    required this.postId,
    required this.service,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {

    // Handle the actual Kemono API response structure
    return Comment(
      id: json['id']?.toString() ?? '',
      username: json['commenter_name']?.toString() ?? 'Anonymous',
      avatar: null, // comments API doesn't provide avatar
      content: json['content']?.toString() ?? '',
      timestamp: DateTime.tryParse(json['published'] ?? '') ?? DateTime.now(),
      postId: '', // optional - not provided in comments API
      service: '', // optional - not provided in comments API
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'avatar': avatar,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'postId': postId,
      'service': service,
    };
  }

  Comment copyWith({
    String? id,
    String? username,
    String? avatar,
    String? content,
    DateTime? timestamp,
    String? postId,
    String? service,
  }) {
    return Comment(
      id: id ?? this.id,
      username: username ?? this.username,
      avatar: avatar ?? this.avatar,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      postId: postId ?? this.postId,
      service: service ?? this.service,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Comment && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Comment(id: $id, username: $username, content: ${content.length > 50 ? '${content.substring(0, 50)}...' : content})';
  }
}

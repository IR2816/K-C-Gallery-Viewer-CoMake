/// Discord Channel entity untuk Kemono Discord API
class DiscordChannel {
  final String id;
  final String serverId;
  final String name;
  final String? parentId;
  final bool isNsfw;
  final int type; // 0 = category, 11 = channel
  final int position;
  final int postCount;
  final String? emoji;

  DiscordChannel({
    required this.id,
    required this.serverId,
    required this.name,
    this.parentId,
    required this.isNsfw,
    required this.type,
    required this.position,
    required this.postCount,
    this.emoji,
  });

  factory DiscordChannel.fromJson(Map<String, dynamic> json) {
    return DiscordChannel(
      id: json['id']?.toString() ?? '',
      serverId: json['server_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      parentId: json['parent_channel_id']?.toString(),
      isNsfw: json['is_nsfw'] ?? false,
      type: json['type'] ?? 11,
      position: json['position'] ?? 0,
      postCount: json['post_count'] ?? 0,
      emoji: json['icon_emoji']?.toString(),
    );
  }

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'server_id': serverId,
      'name': name,
      'parent_channel_id': parentId,
      'is_nsfw': isNsfw,
      'type': type,
      'position': position,
      'post_count': postCount,
      'icon_emoji': emoji,
    };
  }

  /// Getters untuk type checking
  bool get isCategory => type == 4; // Category channels are type 4
  bool get isPostChannel =>
      type == 0 || type == 11; // Type 0 = text channel, Type 11 = forum/thread
  bool get isThread => type == 12; // Discord thread

  /// Get display emoji
  String get displayEmoji {
    if (emoji != null && emoji!.isNotEmpty) return emoji!;
    if (isCategory) return '📁';
    if (isThread) return '💬';
    return '📄';
  }

  /// Check if channel can be opened (has posts)
  bool get canOpen => !isCategory && postCount > 0;

  DiscordChannel copyWith({
    String? id,
    String? serverId,
    String? name,
    String? parentId,
    bool? isNsfw,
    int? type,
    int? position,
    int? postCount,
    String? emoji,
  }) {
    return DiscordChannel(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      isNsfw: isNsfw ?? this.isNsfw,
      type: type ?? this.type,
      position: position ?? this.position,
      postCount: postCount ?? this.postCount,
      emoji: emoji ?? this.emoji,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscordChannel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'DiscordChannel(id: $id, name: $name, type: $type)';
}

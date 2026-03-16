class Creator {
  final String id;
  final String service;
  final String name;
  final int indexed;
  final int updated;
  final bool favorited;

  // Additional properties for enhanced features
  final String avatar;
  final String bio;
  final int? fans;
  final bool followed;

  Creator({
    required this.id,
    required this.service,
    required this.name,
    required this.indexed,
    required this.updated,
    this.favorited = false,
    this.avatar = '',
    this.bio = '',
    this.fans,
    this.followed = false,
  });

  Creator copyWith({
    bool? favorited,
    String? avatar,
    String? bio,
    int? fans,
    bool? followed,
  }) {
    return Creator(
      id: id,
      service: service,
      name: name,
      indexed: indexed,
      updated: updated,
      favorited: favorited ?? this.favorited,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
      fans: fans ?? this.fans,
      followed: followed ?? this.followed,
    );
  }
}

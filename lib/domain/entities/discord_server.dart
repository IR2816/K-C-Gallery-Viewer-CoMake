/// Discord Server entity untuk Kemono Discord API
class DiscordServer {
  final String id;
  final String name;
  final DateTime indexed;
  final DateTime updated;

  DiscordServer({
    required this.id,
    required this.name,
    required this.indexed,
    required this.updated,
  });

  factory DiscordServer.fromJson(Map<String, dynamic> json) {
    return DiscordServer(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      indexed:
          DateTime.tryParse(json['indexed']?.toString() ?? '') ??
          DateTime.now(),
      updated:
          DateTime.tryParse(json['updated']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'indexed': indexed.toIso8601String(),
      'updated': updated.toIso8601String(),
    };
  }

  DiscordServer copyWith({
    String? id,
    String? name,
    DateTime? indexed,
    DateTime? updated,
  }) {
    return DiscordServer(
      id: id ?? this.id,
      name: name ?? this.name,
      indexed: indexed ?? this.indexed,
      updated: updated ?? this.updated,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DiscordServer && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'DiscordServer(id: $id, name: $name)';
  }
}

import '../../domain/entities/creator.dart';

/// Creator search result from mbaharip API
class CreatorSearchResult {
  final String id;
  final String name;
  final String service;
  final String? avatar;
  final int? fans;
  final int? favorited; // Changed from bool? to int? - API returns int
  final String? indexed;

  const CreatorSearchResult({
    required this.id,
    required this.name,
    required this.service,
    this.avatar,
    this.fans,
    this.favorited,
    this.indexed,
  });

  /// Create from JSON
  factory CreatorSearchResult.fromJson(Map<String, dynamic> json) {
    return CreatorSearchResult(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      service: json['service']?.toString() ?? '',
      avatar: json['avatar']?.toString(),
      fans: json['fans'] as int?,
      favorited: json['favorited'] as int?, // Changed from bool? to int?
      indexed: json['indexed']?.toString(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'service': service,
      'avatar': avatar,
      'fans': fans,
      'favorited': favorited,
      'indexed': indexed,
    };
  }

  /// Convert to Creator entity
  Creator toCreator() {
    return Creator(
      id: id,
      name: name,
      service: service,
      indexed: 0, // Default value
      updated: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      favorited: (favorited ?? 0) > 0, // Convert int to bool
      avatar: avatar ?? '',
      bio: '',
      fans: fans,
      followed: false,
    );
  }

  @override
  String toString() {
    return 'CreatorSearchResult(id: $id, name: $name, service: $service)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreatorSearchResult && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

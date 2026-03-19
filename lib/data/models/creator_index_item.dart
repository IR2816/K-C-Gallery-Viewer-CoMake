/// Creator Index Item for Local Search
/// Lightweight model for creator indexing, not to be confused with Creator entity
class CreatorIndexItem {
  final String service;
  final String userId;
  final String name;
  final String nameKey;

  CreatorIndexItem({
    required this.service,
    required this.userId,
    required this.name,
  }) : nameKey = name.toLowerCase().trim();

  @override
  String toString() =>
      'CreatorIndexItem(service: $service, userId: $userId, name: $name)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreatorIndexItem &&
        other.service == service &&
        other.userId == userId &&
        other.name == name;
  }

  @override
  int get hashCode => Object.hash(service, userId, name);
}

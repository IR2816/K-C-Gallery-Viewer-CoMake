import '../../domain/entities/creator.dart';

class CreatorModel extends Creator {
  CreatorModel({
    required super.id,
    required super.service,
    required super.name,
    required super.indexed,
    required super.updated,
    super.favorited,
  });

  factory CreatorModel.fromJson(Map<String, dynamic> json) {
    // Handle timestamps that might be strings or integers
    int parseTimestamp(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) {
        // Try to parse ISO string to timestamp
        try {
          final dateTime = DateTime.parse(value);
          return dateTime.millisecondsSinceEpoch ~/ 1000;
        } catch (e) {
          // If not ISO format, try to parse as int
          return int.tryParse(value) ?? 0;
        }
      }
      return 0;
    }

    return CreatorModel(
      id: json['id']?.toString() ?? '',
      service: json['service'] ?? '',
      name: json['name'] ?? 'Unknown',
      indexed: parseTimestamp(json['indexed']),
      updated: parseTimestamp(json['updated']),
      favorited: json['favorited'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'service': service,
      'name': name,
      'indexed': indexed,
      'updated': updated,
      'favorited': favorited,
    };
  }

  factory CreatorModel.fromEntity(Creator creator) {
    return CreatorModel(
      id: creator.id,
      service: creator.service,
      name: creator.name,
      indexed: creator.indexed,
      updated: creator.updated,
      favorited: creator.favorited,
    );
  }
}

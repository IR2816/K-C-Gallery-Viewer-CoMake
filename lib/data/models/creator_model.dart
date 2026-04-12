import '../../domain/entities/creator.dart';
import '../utils/json_field_utils.dart';

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
    return CreatorModel(
      id: JsonFieldUtils.string(json, 'id'),
      service: JsonFieldUtils.string(json, 'service'),
      name: JsonFieldUtils.string(json, 'name', defaultValue: 'Unknown'),
      indexed:
          JsonFieldUtils.dateTime(json, 'indexed').millisecondsSinceEpoch ~/
          1000,
      updated:
          JsonFieldUtils.dateTime(json, 'updated').millisecondsSinceEpoch ~/
          1000,
      favorited: JsonFieldUtils.boolValue(json, 'favorited'),
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

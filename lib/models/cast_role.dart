import 'package:json_annotation/json_annotation.dart';

part 'cast_role.g.dart';

@JsonSerializable()
class CastRole {
  final int? id;
  final String? filter;
  final String tag;
  final String? tagKey;
  final String? role;
  final String? thumb;
  final int? count;

  CastRole({this.id, this.filter, required this.tag, this.tagKey, this.role, this.thumb, this.count});

  factory CastRole.fromJson(Map<String, dynamic> json) => _$CastRoleFromJson(json);

  Map<String, dynamic> toJson() => _$CastRoleToJson(this);
}

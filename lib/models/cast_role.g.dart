// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cast_role.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CastRole _$CastRoleFromJson(Map<String, dynamic> json) => CastRole(
  id: (json['id'] as num?)?.toInt(),
  filter: json['filter'] as String?,
  tag: json['tag'] as String,
  tagKey: json['tagKey'] as String?,
  role: json['role'] as String?,
  thumb: json['thumb'] as String?,
  count: (json['count'] as num?)?.toInt(),
);

Map<String, dynamic> _$CastRoleToJson(CastRole instance) => <String, dynamic>{
  'id': instance.id,
  'filter': instance.filter,
  'tag': instance.tag,
  'tagKey': instance.tagKey,
  'role': instance.role,
  'thumb': instance.thumb,
  'count': instance.count,
};

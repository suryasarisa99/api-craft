import 'dart:ui';
import 'package:objectbox/objectbox.dart';
import 'package:api_craft/core/models/models.dart';

@Entity()
class EnvironmentEntity {
  @Id()
  int id = 0;

  @Index()
  @Unique()
  String uid;

  @Index()
  String collectionId;

  String name;
  int? colorValue; // Store Color as int
  bool isShared;
  bool isGlobal;

  // Flex Prop
  List<Map<String, dynamic>>? variables;

  EnvironmentEntity({
    this.id = 0,
    required this.uid,
    required this.collectionId,
    required this.name,
    this.colorValue,
    this.isShared = false,
    this.isGlobal = false,
    this.variables,
  });

  factory EnvironmentEntity.fromModel(Environment model) {
    return EnvironmentEntity(
      uid: model.id,
      collectionId: model.collectionId,
      name: model.name,
      colorValue: model.color?.value,
      isShared: model.isShared,
      isGlobal: model.isGlobal,
      variables: model.variables.map((e) => e.toMap()).toList(),
    );
  }

  Environment toModel() {
    return Environment(
      id: uid,
      collectionId: collectionId,
      name: name,
      color: colorValue != null ? Color(colorValue!) : null,
      isShared: isShared,
      isGlobal: isGlobal,
      variables: variables?.map((e) => KeyValueItem.fromMap(e)).toList() ?? [],
    );
  }
}

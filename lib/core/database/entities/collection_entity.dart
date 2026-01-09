import 'package:objectbox/objectbox.dart';
import 'package:api_craft/features/collection/collection_model.dart';
import 'package:api_craft/core/models/models.dart';

@Entity()
class CollectionEntity {
  @Id()
  int id = 0;

  @Index()
  @Unique()
  String uid;

  String name;
  String type; // 'database' or 'filesystem'
  String? path;
  String? selectedEnvId;
  String? selectedJarId;
  String description;

  // Flex Props
  List<Map<String, dynamic>>? headers;
  Map<String, dynamic>? auth;

  CollectionEntity({
    this.id = 0,
    required this.uid,
    required this.name,
    required this.type,
    this.path,
    this.selectedEnvId,
    this.selectedJarId,
    this.description = '',
    this.headers,
    this.auth,
  });

  factory CollectionEntity.fromModel(CollectionModel model) {
    return CollectionEntity(
      uid: model.id,
      name: model.name,
      type: model.type.name, // enum to string
      path: model.path,
      selectedEnvId: model.selectedEnvId,
      selectedJarId: model.selectedJarId,
      description: model.description,
      headers: model.headers.map((e) => e.toMap()).toList(),
      auth: model.auth.toMap(),
    );
  }

  CollectionModel toModel() {
    return CollectionModel(
      id: uid,
      name: name,
      type: type == CollectionType.database.name
          ? CollectionType.database
          : CollectionType.filesystem,
      path: path,
      selectedEnvId: selectedEnvId,
      selectedJarId: selectedJarId,
      description: description,
      headers: headers?.map((e) => KeyValueItem.fromMap(e)).toList() ?? [],
      auth: auth != null ? AuthData.fromMap(auth!) : const AuthData(),
    );
  }
}

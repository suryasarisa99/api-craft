import 'package:objectbox/objectbox.dart';
import 'package:api_craft/core/models/models.dart';

@Entity()
class WorkspaceEntity {
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

  WorkspaceEntity({
    this.id = 0,
    required this.uid,
    required this.name,
    required this.type,
    this.path,
    this.selectedEnvId,
    this.selectedJarId,
  });

  factory WorkspaceEntity.fromModel(WorkspaceModel model) {
    return WorkspaceEntity(
      uid: model.id,
      name: model.name,
      type: model.type.name, // enum to string
      path: model.path,
      selectedEnvId: model.selectedEnvId,
      selectedJarId: model.selectedJarId,
    );
  }

  WorkspaceModel toModel() {
    return WorkspaceModel(
      id: uid,
      name: name,
      type: WorkspaceType.values.byName(type),
      path: path,
      selectedEnvId: selectedEnvId,
      selectedJarId: selectedJarId,
    );
  }
}

enum WorkspaceType { database, filesystem }

class WorkspaceModel {
  final String id;
  final String name;
  final WorkspaceType type;
  final String? path;
  final String? selectedEnvId;
  final String? selectedJarId;

  const WorkspaceModel({
    required this.id,
    required this.name,
    required this.type,
    this.path,
    this.selectedEnvId,
    this.selectedJarId,
  });

  factory WorkspaceModel.fromMap(Map<String, dynamic> map) {
    return WorkspaceModel(
      id: map['id'],
      name: map['name'],
      type: WorkspaceType.values.byName(map['type'] ?? 'local'),
      path: map['path'],
      selectedEnvId: map['selected_env_id'],
      selectedJarId: map['selected_jar_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'path': path,
      'selected_env_id': selectedEnvId,
      'selected_jar_id': selectedJarId,
    };
  }

  WorkspaceModel copyWith({
    String? id,
    String? name,
    WorkspaceType? type,
    String? path,
    String? selectedEnvId,
    String? selectedJarId,
  }) {
    return WorkspaceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      path: path ?? this.path,
      selectedEnvId: selectedEnvId ?? this.selectedEnvId,
      selectedJarId: selectedJarId ?? this.selectedJarId,
    );
  }
}

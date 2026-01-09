enum CollectionType { database, filesystem }

class CollectionModel {
  final String id;
  final String name;
  final CollectionType type;
  final String? path; // Only used if type == filesystem
  final String? selectedEnvId;
  final String? selectedJarId;

  const CollectionModel({
    required this.id,
    required this.name,
    required this.type,
    this.path,
    this.selectedEnvId,
    this.selectedJarId,
  });

  factory CollectionModel.fromMap(Map<String, dynamic> map) {
    return CollectionModel(
      id: map['id'],
      name: map['name'],
      type: map['type'] == 'database'
          ? CollectionType.database
          : CollectionType.filesystem,
      path: map['path'],
      selectedEnvId: map['selected_env_id'],
      selectedJarId: map['selected_jar_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type == CollectionType.database ? 'database' : 'filesystem',
      'path': path,
      'selected_env_id': selectedEnvId,
      'selected_jar_id': selectedJarId,
    };
  }

  CollectionModel copyWith({
    String? id,
    String? name,
    CollectionType? type,
    String? path,
    String? selectedEnvId,
    String? selectedJarId,
  }) {
    return CollectionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      path: path ?? this.path,
      selectedEnvId: selectedEnvId ?? this.selectedEnvId,
      selectedJarId: selectedJarId ?? this.selectedJarId,
    );
  }
}

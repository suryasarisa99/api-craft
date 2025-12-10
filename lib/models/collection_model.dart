// models/collection_model.dart
enum CollectionType { database, filesystem }

class CollectionModel {
  final String id;
  final String name;
  final CollectionType type;
  final String? path; // Only used if type == filesystem

  CollectionModel({
    required this.id,
    required this.name,
    required this.type,
    this.path,
  });

  factory CollectionModel.fromMap(Map<String, dynamic> map) {
    return CollectionModel(
      id: map['id'],
      name: map['name'],
      type: map['type'] == 'database'
          ? CollectionType.database
          : CollectionType.filesystem,
      path: map['path'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type == CollectionType.database ? 'database' : 'filesystem',
      'path': path,
    };
  }
}

// models/collection_model.dart
import 'dart:convert';
import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/features/request/models/node_model.dart';
import 'package:flutter/material.dart';

enum CollectionType { database, filesystem }

class CollectionModel {
  final String id;
  final String name;
  final CollectionType type;
  final String? path; // Only used if type == filesystem
  final String? selectedEnvId;
  final String? selectedJarId;
  final String description;
  final List<KeyValueItem> headers;
  final AuthData auth;

  const CollectionModel({
    required this.id,
    required this.name,
    required this.type,
    this.path,
    this.selectedEnvId,
    this.selectedJarId,
    this.description = '',
    this.headers = const [],
    this.auth = const AuthData(),
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
      description: map['description'] ?? '',
      headers: Node.parseKeyValueItems(map['headers']),
      auth: (map['auth'] != null)
          ? AuthData.fromMap(map['auth'])
          : const AuthData(),
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
      'description': description,
      'headers': headers,
      'auth': auth.toMap(),
    };
  }

  CollectionModel copyWith({
    String? id,
    String? name,
    CollectionType? type,
    String? path,
    String? selectedEnvId,
    String? selectedJarId,
    String? description,
    List<KeyValueItem>? headers,
    AuthData? auth,
  }) {
    return CollectionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      path: path ?? this.path,
      selectedEnvId: selectedEnvId ?? this.selectedEnvId,
      selectedJarId: selectedJarId ?? this.selectedJarId,
      description: description ?? this.description,
      headers: headers ?? this.headers,
      auth: auth ?? this.auth,
    );
  }
}

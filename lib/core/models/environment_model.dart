import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:api_craft/features/request/models/node_model.dart';
import 'package:api_craft/features/request/models/node_config_model.dart';

class Environment {
  final String id;
  final String collectionId;
  final String name;
  final Color? color;
  final List<KeyValueItem> variables;
  final bool isShared;
  final bool isGlobal;

  const Environment({
    required this.id,
    required this.collectionId,
    required this.name,
    this.color,
    this.variables = const [],
    this.isShared = false,
    this.isGlobal = false,
  });

  Environment copyWith({
    String? id,
    String? collectionId,
    String? name,
    Color? color,
    List<KeyValueItem>? variables,
    bool? isShared,
    bool? isGlobal,
  }) {
    return Environment(
      id: id ?? this.id,
      collectionId: collectionId ?? this.collectionId,
      name: name ?? this.name,
      color: color ?? this.color,
      variables: variables ?? this.variables,
      isShared: isShared ?? this.isShared,
      isGlobal: isGlobal ?? this.isGlobal,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'collection_id': collectionId,
      'name': name,
      'color': color?.value,
      'variables': variables.map((e) => e.toMap()).toList(),
      'is_shared': isShared ? 1 : 0,
      'is_global': isGlobal ? 1 : 0,
    };
  }

  factory Environment.fromMap(Map<String, dynamic> map) {
    return Environment(
      id: map['id'],
      collectionId: map['collection_id'],
      name: map['name'],
      color: map['color'] != null ? Color(map['color']) : null,
      variables: Node.parseKeyValueItems(map['variables']),
      isShared: (map['is_shared'] as int? ?? 0) == 1,
      isGlobal: (map['is_global'] as int? ?? 0) == 1,
    );
  }
}

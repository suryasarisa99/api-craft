import 'package:api_craft/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// This is a provider to store the the last updated folder
/// so for request we can track tis , if this folder is ancestor of it, we retrigger

final nodeUpdateTriggerProvider =
    NotifierProvider<NodeUpdateTriggerProvider, NodeUpdateEvent?>(
      NodeUpdateTriggerProvider.new,
    );

class NodeUpdateTriggerProvider extends Notifier<NodeUpdateEvent?> {
  @override
  NodeUpdateEvent? build() {
    return null;
  }

  void setLastUpdatedFolder(String id) {
    state = NodeUpdateEvent(id);
  }
}

class NodeUpdateEvent {
  final String id;
  final int timestamp; // Optional debug helper

  NodeUpdateEvent(this.id) : timestamp = DateTime.now().millisecondsSinceEpoch;
}

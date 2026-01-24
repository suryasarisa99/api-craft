import 'package:api_craft/flows/filter/models/m.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FilterManagerData {
  final FilterGroup rootFilter;
  FilterManagerData({required this.rootFilter});

  // copy with
  FilterManagerData copyWith({FilterGroup? rootFilter}) {
    return FilterManagerData(rootFilter: rootFilter ?? this.rootFilter);
  }

  FilterManagerData.empty()
    : rootFilter = FilterGroup(children: [FilterCondition()]);
}

typedef FilterManagerProvider =
    NotifierProvider<ConditionManagerNotifier, FilterManagerData>;

final _filterManagerProvider =
    NotifierProvider.family<
      ConditionManagerNotifier,
      FilterManagerData,
      String
    >((s) => ConditionManagerNotifier(s));

final filterManagerProvider = _filterManagerProvider("filter");
final interceptManagerProvider = _filterManagerProvider("intercept");

class ConditionManagerNotifier extends Notifier<FilterManagerData> {
  final String? type;
  ConditionManagerNotifier(this.type);

  @override
  FilterManagerData build() {
    return FilterManagerData.empty();
  }

  void reset() {
    state = FilterManagerData.empty();
  }

  /// Forces a state update to notify listeners.
  /// Call this after mutating the filter tree in place.
  void notify() {
    state = state.copyWith();
  }

  void addSubgroupTo(FilterGroup group) {
    if (group.children.isNotEmpty) {
      group.operators.add(LogicalOperator.and);
    }
    group.children.add(FilterGroup(children: [FilterCondition()]));
    notify();
  }

  void addConditionTo(FilterGroup group) {
    if (group.children.isNotEmpty) {
      group.operators.add(LogicalOperator.and);
    }
    group.children.add(FilterCondition());
    notify();
  }

  void moveNodeBetweenGroups(
    FilterGroup sourceGroup,
    int sourceIndex,
    FilterGroup targetGroup,
    int targetIndex,
  ) {
    if (sourceIndex < 0 || sourceIndex >= sourceGroup.children.length) return;

    // Remove from source
    final item = sourceGroup.children.removeAt(sourceIndex);

    // Operator cleanup in source
    // If source had >1 children, we need to remove an operator.
    // If we removed index i, we remove operator i-1 (if i>0) or operator 0 (if i=0 and list not empty).
    if (sourceGroup.operators.isNotEmpty) {
      if (sourceIndex > 0) {
        sourceGroup.operators.removeAt(sourceIndex - 1);
      } else {
        sourceGroup.operators.removeAt(0);
      }
    }

    // Insert into target
    // If target index is out of bounds (e.g. dropped at end), clamp it or append.
    if (targetIndex >= targetGroup.children.length) {
      targetGroup.children.add(item);
      // Add operator if not first child
      if (targetGroup.children.length > 1) {
        targetGroup.operators.add(LogicalOperator.and);
      }
    } else {
      targetGroup.children.insert(targetIndex, item);
      // Insert operator
      if (targetGroup.children.length > 1) {
        // If inserted at 0, add operator at 0.
        // If inserted at i > 0, insert operator at i-1?
        // Let's standardise: always ensure N-1 operators.
        // If we insert at `targetIndex`, we likely need an operator at `targetIndex` (if targetIndex < length-1) or before it.
        // Simplest: just add AND at targetIndex if possible.
        if (targetIndex > 0) {
          targetGroup.operators.insert(targetIndex - 1, LogicalOperator.and);
        } else {
          // Inserted at 0
          targetGroup.operators.insert(0, LogicalOperator.and);
        }
      }
    }

    notify();
  }

  void moveNode(FilterGroup group, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = group.children.removeAt(oldIndex);
    group.children.insert(newIndex, item);
    notify();
  }
}

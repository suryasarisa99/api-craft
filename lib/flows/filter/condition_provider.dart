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
}

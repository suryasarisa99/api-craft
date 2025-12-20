class VariableValue {
  final String? sourceId;
  final dynamic value;

  VariableValue(this.sourceId, this.value);
}

class ResolvedVariableValue {
  final String? sourceId;
  final dynamic value;
  final bool isFunction;
  final bool isResolved;

  ResolvedVariableValue({
    this.sourceId,
    this.value,
    this.isFunction = false,
    this.isResolved = false,
  });
}

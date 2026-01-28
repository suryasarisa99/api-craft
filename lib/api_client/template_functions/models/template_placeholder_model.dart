abstract class TemplatePlaceholder {
  String name;
  final int start;
  final int end;
  TemplatePlaceholder({
    required this.name,
    required this.start,
    required this.end,
  });
}

class TemplateVariablePlaceholder extends TemplatePlaceholder {
  TemplateVariablePlaceholder({
    required super.name,
    required super.start,
    required super.end,
  });
}

class TemplateFnPlaceholder extends TemplatePlaceholder {
  final Map<String, dynamic>? args;

  TemplateFnPlaceholder({
    required super.name,
    required this.args,
    required super.start,
    required super.end,
  });

  bool get isFunction => args != null;

  TemplateFnPlaceholder copyWithArgs(Map<String, dynamic> newArgs) {
    return TemplateFnPlaceholder(
      name: name,
      args: newArgs,
      start: start,
      end: end,
    );
  }
}

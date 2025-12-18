import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A unified context interface that wraps either [Ref] (from a Provider)
/// or [WidgetRef] (from a ConsumerWidget/HookConsumerWidget).
///
/// This allows template functions to be used in both background execution
/// (where only [Ref] is available) and UI previews (where [WidgetRef] is available).
abstract class TemplateContext {
  T read<T>(dynamic provider);
}

/// Adapter for [Ref]
class RefTemplateContext implements TemplateContext {
  final Ref _ref;
  RefTemplateContext(this._ref);

  @override
  T read<T>(dynamic provider) => _ref.read(provider);
}

/// Adapter for [WidgetRef]
class WidgetRefTemplateContext implements TemplateContext {
  final WidgetRef _ref;
  WidgetRefTemplateContext(this._ref);

  @override
  T read<T>(dynamic provider) => _ref.read(provider);
}

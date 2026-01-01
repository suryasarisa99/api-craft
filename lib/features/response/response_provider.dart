import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/features/request/providers/request_details_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final responseProvider = NotifierProvider.autoDispose
    .family<ResponseNotifier, RawHttpResponse?, String>(ResponseNotifier.new);

class ResponseNotifier extends Notifier<RawHttpResponse?> {
  final String id;
  ResponseNotifier(this.id);

  @override
  RawHttpResponse? build() {
    final historyId = ref.watch(
      fileTreeProvider.select(
        (state) => (state.nodeMap[id] as RequestNode?)?.config.historyId,
      ),
    );
    final history = ref.watch(
      requestDetailsProvider(id).select((s) => s.history),
    );
    if (history?.isEmpty ?? true) return null;
    if (historyId == null) return history!.first;
    return history!.firstWhere((e) => e.id == historyId);
  }
}

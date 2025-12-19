import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/features/response/response_headers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ResponseTAb extends ConsumerStatefulWidget {
  const ResponseTAb({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ResponseTAbState();
}

class _ResponseTAbState extends ConsumerState<ResponseTAb> {
  @override
  Widget build(BuildContext context) {
    final id = ref.watch(activeReqIdProvider);
    if (id == null) {
      return const Center(child: Text("No Active Request"));
    }
    final node = ref.watch(activeReqProvider);
    if (node == null) {
      return const Center(child: Text("No Active Request"));
    }
    final response = ref.watch(
      reqComposeProvider(id).select((d) => d.history?.firstOrNull),
    );
    if (response == null) {
      return const Center(child: Text("No Response Available"));
    }
    return ResponseHeaders(id: id);
  }
}

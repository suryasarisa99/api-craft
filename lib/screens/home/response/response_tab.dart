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
    return Center(child: Text("Response Tab"));
  }
}

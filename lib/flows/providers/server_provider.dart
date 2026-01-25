import 'dart:async';
import 'dart:io';

import 'package:api_craft/flows/providers/flows_provider.dart';
import 'package:api_craft/flows/models/flow.dart';
import 'package:api_craft/flows/providers/paused_providers.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockhttp/mockttp.dart';

final serverProvider = NotifierProvider<ServerNotifier, RawMockttpServer>(
  () => ServerNotifier(),
);

class ServerNotifier extends Notifier<RawMockttpServer> {
  final String caCertPath = '${Directory.current.path}/mockttp-ca-cert.pem';
  final String caKeyPath = '${Directory.current.path}/mockttp-ca-key.pem';
  late final FlowsNotifier flowNotifier;
  @override
  RawMockttpServer build() {
    flowNotifier = ref.read(flowsProvider.notifier);
    debugPrint("Server build");
    //temporarily start after 5secs
    Future.delayed(const Duration(seconds: 2), () {
      startServer(null);
    });
    return _createServer();
  }

  Future<void> startServer(int? port) async {
    debugPrint("Server started");
    runZonedGuarded(
      () async {
        state.start(port: port);
        debugPrint("Certificate: ${state.certificateAuthority}");
        if (state.certificateAuthority != null) {
          if (!await File(caCertPath).exists() ||
              !await File(caKeyPath).exists()) {
            await state.certificateAuthority!.saveCaCertToFile(caCertPath);
            await state.certificateAuthority!.saveCaKeyToFile(caKeyPath);
            debugPrint('Certificate: Generated and saved OK.');
          } else {
            debugPrint('Certificate: Loaded from disk OK.');
          }
        }
        // rule:
        // state.matching(.domain('example.com')).thenEditReq((req) {
        //   req.url = "https://www.google.com";
        //   return req;
        // });
        state.matching(.domain(.eq('sample.com'))).thenPauseReqRes();
        state.matching(.port(.eq(3000))).thenEditRes((res) {
          res.statusCode = 111;
          return res;
        });
        state.forAnyRequest().thenPassThrough();

        // listeners:
        state.on.req((req) {
          debugPrint("@req: ${req.id}");
          flowNotifier.updateReq(FlowRequest.fromOngoingReq(req));
        });
        state.on.res((res) {
          debugPrint("@res: ${res.id}");
          flowNotifier.updateRes(FlowResponse.fromCompletedRes(res));
        });
        state.on.pause((info) {
          final flowId = (info.pausedRequest?.id ?? info.pausedResponse?.id)!;
          final flowType = info.pausedRequest != null ? "req" : "res";
          debugPrint("@pause: $flowId $flowType");
          ref.read(pausedFlowsProvider.notifier).add(flowId, flowType);
        });
        state.on.resume((info) {});
      },
      (error, stackTrace) {
        debugPrint("Server error: $error");
      },
    );
  }

  void resume(String id, String type) async {
    final pausedFlow = ref.read(pausedFlowsProvider.notifier);
    final flow = ref.read(flowsProvider)[id]!;
    pausedFlow.remove(id);
    if (type == "req") {
      final mutableReq = await flow.request!.toMutableReq();
      state.resumePausedRequest(id, editedRequest: mutableReq);
    } else {
      final mutableRes = await flow.response?.toMutableRes();
      state.resumePausedResponse(id, editedResponse: mutableRes);
    }
  }
}

RawMockttpServer _createServer() {
  debugPrint("Server created");
  debugPrint("expected path: ${Directory.current.path}");
  final caCertPath = '${Directory.current.path}/mockttp-ca-cert.pem';
  final caKeyPath = '${Directory.current.path}/mockttp-ca-key.pem';

  MockttpHttpsOptions httpsOptions;

  if (File(caCertPath).existsSync() && File(caKeyPath).existsSync()) {
    httpsOptions = MockttpHttpsOptions(
      keyPath: caKeyPath,
      certPath: caCertPath,
    );
  } else {
    httpsOptions = MockttpHttpsOptions();
  }

  final options = MockttpOptions(
    https: httpsOptions,
    debug: false, // Enable debug
    http2: false, // Disable HTTP/2, use HTTP/1.1 only )
  );
  return RawMockttpServer(options);
}

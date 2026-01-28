import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:api_craft/core/constants/globals.dart';
import 'package:api_craft/traffic/interception_rules/interception_provider.dart';
import 'package:api_craft/traffic/interception_rules/interception_script_service.dart';
import 'package:api_craft/traffic/flows/models/flow.dart';
import 'package:api_craft/traffic/flows/providers/flows_provider.dart';
import 'package:api_craft/traffic/flows/providers/paused_providers.dart';
import 'package:api_craft/traffic/interceptors/utils/get_certificate.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockhttp/mockttp.dart';
import 'package:mockhttp/types.dart';
import 'package:path/path.dart' as p;

// Import types for explicit casting if needed
// import 'package:mockhttp/types.dart';

final serverProvider = AsyncNotifierProvider<ServerNotifier, void>(
  () => ServerNotifier(),
);

class ServerNotifier extends AsyncNotifier<void> {
  Isolate? _isolate;
  SendPort? _sendPort;
  late final FlowsNotifier flowNotifier;

  @override
  Future<void> build() async {
    flowNotifier = ref.read(flowsProvider.notifier);

    // Start server logic
    await _startServer();

    // Listen for rule changes
    ref.listen(interceptionProvider, (previous, next) {
      if (previous != next) {
        _sendToIsolate({'type': 'applyRules', 'rules': next});
      }
    });

    // Cleanup on dispose
    ref.onDispose(() {
      _stopServer();
    });
  }

  Future<void> _startServer() async {
    if (_isolate != null) return;

    final receivePort = ReceivePort();
    final rootIsolateToken = RootIsolateToken.instance;

    if (rootIsolateToken == null) {
      debugPrint("Server: Cannot get RootIsolateToken");
      return;
    }

    try {
      _isolate = await Isolate.spawn(
        _isolateEntry,
        _IsolateArgs(
          sendPort: receivePort.sendPort,
          rootToken: rootIsolateToken,
          initialRules: ref.read(interceptionProvider),
          projectPath: Directory.current.path,
        ),
      );

      receivePort.listen((message) {
        _handleMessage(message);
      });
    } catch (e, st) {
      debugPrint("Server Isolate Spawn Error: $e\n$st");
    }
  }

  void _stopServer() {
    _sendToIsolate({'type': 'stop'});
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
  }

  void resume(String id, String type) {
    // We send a resume command to the isolate.
    // Ideally we need to send the EDITED request/response back if it was modified.
    // The UI modifies the Flow in FlowsProvider.
    // So we need to fetch the current flow data and send it.

    final flow = ref.read(flowsProvider)[id];
    if (flow == null) return;

    // Remove from paused provider in UI immediately for responsiveness
    ref.read(pausedFlowsProvider.notifier).remove(id);

    // Prepare data to send
    if (type == 'req') {
      // We need to send the MutableRequest data.
      _resumeRequest(id, flow.request!);
    } else {
      _resumeResponse(id, flow.response!);
    }
  }

  Future<void> _resumeRequest(String id, FlowRequest req) async {
    // Convert FlowRequest back to MutableRequest-like struct or just map
    // Since we can't send MutableRequest easily if it has complex methods,
    // but MutableRequest is mostly data.
    // Let's rely on MutableRequest being serializable or send a Map.
    // Mockttp's resumePausedRequest expects `editedRequest`.
    final mutableReq = await req.toMutableReq();
    _sendToIsolate({'type': 'resumeReq', 'id': id, 'data': mutableReq});
  }

  Future<void> _resumeResponse(String id, FlowResponse res) async {
    final mutableRes = await res.toMutableRes();
    _sendToIsolate({'type': 'resumeRes', 'id': id, 'data': mutableRes});
  }

  void _sendToIsolate(dynamic message) {
    _sendPort?.send(message);
  }

  void _handleMessage(dynamic message) async {
    if (message is SendPort) {
      _sendPort = message;
      // Initial Apply Rules
      _sendToIsolate({
        'type': 'applyRules',
        'rules': ref.read(interceptionProvider),
      });
      return;
    }

    if (message is Map) {
      switch (message['type']) {
        case 'log':
          debugPrint("ServerIsolate: ${message['msg']}");
          break;
        case 'req':
          // Received new request
          // message['data'] should be MutableRequest or compatible
          if (message['data'] is MutableRequest) {
            final req = FlowRequest.fromMutableReq(
              message['data'] as MutableRequest,
            );
            flowNotifier.updateReq(req);
          }
          break;
        case 'res':
          if (message['data'] is MutableResponse) {
            final res = FlowResponse.fromMutableRes(
              message['data'] as MutableResponse,
            );
            flowNotifier.updateRes(res);
          }
          break;
        case 'paused':
          final id = message['id'] as String;
          final flowType = message['flowType'] as String; // "req" or "res"
          debugPrint("@pause: $id $flowType");
          ref.read(pausedFlowsProvider.notifier).add(id, flowType);
          break;
        default:
          debugPrint("Unknown message from isolate: $message");
      }
    }
  }
}

class _IsolateArgs {
  final SendPort sendPort;
  final RootIsolateToken rootToken;
  final List<ProxyRule> initialRules;
  final String projectPath;

  _IsolateArgs({
    required this.sendPort,
    required this.rootToken,
    required this.initialRules,
    required this.projectPath,
  });
}

// --- Isolate Entry Point ---

Future<void> _isolateEntry(_IsolateArgs args) async {
  // 1. Initialize Background Isolate
  BackgroundIsolateBinaryMessenger.ensureInitialized(args.rootToken);

  final sendPort = args.sendPort;
  final receivePort = ReceivePort();

  // Handshake
  sendPort.send(receivePort.sendPort);

  // 2. Create Server
  // final caCertPath = '${args.projectPath}/mockttp-ca-cert.pem';
  // final caKeyPath = '${args.projectPath}/mockttp-ca-key.pem';
  final certificationsDirPath = getCertificationsDirPath();
  debugPrint("Certifications dir path: $certificationsDirPath");
  final caCertPath = p.join(certificationsDirPath, '$kAppName-ca-cert.pem');
  final caKeyPath = p.join(certificationsDirPath, '$kAppName-ca-key.pem');

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
    debug: false,
    http2: false,
  );

  final server = RawMockttpServer(options);

  // 3. Setup Listeners
  server.on.req((req) async {
    // Convert to MutableRequest to read body and make it serializable
    try {
      final mutableReq = await MutableRequest.fromOngoingRequest(req);
      sendPort.send({'type': 'req', 'data': mutableReq});
    } catch (e) {
      sendPort.send({'type': 'log', 'msg': 'Error processing req: $e'});
    }
  });

  server.on.res((res) async {
    try {
      final mutableRes = await MutableResponse.fromCompletedResponse(res);
      sendPort.send({'type': 'res', 'data': mutableRes});
    } catch (e) {
      sendPort.send({'type': 'log', 'msg': 'Error processing res: $e'});
    }
  });

  server.on.pause((info) {
    final pausedRequest = info.pausedRequest;
    final pausedResponse = info.pausedResponse;
    final flowId = (pausedRequest?.id ?? pausedResponse?.id);
    if (flowId == null) return;

    final flowType = pausedRequest != null ? "req" : "res";

    // Check if we need to send the paused request/response specifically?
    // Usually on.req/on.res handled the initial data.
    // Pause event mainly signals UI to show pause state.
    sendPort.send({'type': 'paused', 'id': flowId, 'flowType': flowType});
  });

  // 4. Start Server
  await server.start();

  // Cert generation if needed
  if (server.certificateAuthority != null) {
    if (!File(caCertPath).existsSync() || !File(caKeyPath).existsSync()) {
      Directory(certificationsDirPath).createSync(recursive: true);
      await server.certificateAuthority!.saveCaCertToFile(caCertPath);
      await server.certificateAuthority!.saveCaKeyToFile(caKeyPath);
      sendPort.send({'type': 'log', 'msg': 'Certificate generated'});
    }
  }

  sendPort.send({
    'type': 'log',
    'msg': 'Server started on port ${server.port}',
  });

  // Helper to apply rules
  void applyRules(List<ProxyRule> rules) {
    final manager = ProxyRuleManager(server);

    final hydratedRules = rules.map((rule) {
      // Hydrate Edit Request
      if (rule.action.type == 'editReq' &&
          rule.action.script != null &&
          rule.action.script!.isNotEmpty) {
        final script = rule.action.script!;
        final newRule = rule.copy();
        newRule.action = RuleActionConfig.editReq((req) {
          return InterceptionScriptService.instance.editRequest(script, req);
        });
        newRule.action.script = script;
        return newRule;
      }
      // Hydrate Edit Response
      else if (rule.action.type == 'editRes' &&
          rule.action.script != null &&
          rule.action.script!.isNotEmpty) {
        final script = rule.action.script!;
        final newRule = rule.copy();
        newRule.action = RuleActionConfig.editRes(
          (res) {
            return InterceptionScriptService.instance.editResponse(script, res);
          },
          ignoreHostCertificateErrors: rule.action.ignoreHostCertificateErrors,
        );
        newRule.action.script = script;
        return newRule;
      }
      return rule;
    }).toList();

    manager.reapplyRules(hydratedRules);
    server.forAnyRequest().thenPassThrough();
    sendPort.send({'type': 'log', 'msg': 'Rules applied: ${rules.length}'});
  }

  // 5. Listen for Commands
  receivePort.listen((message) {
    if (message is Map) {
      switch (message['type']) {
        case 'stop':
          server.stop();
          Isolate.current.kill();
          break;
        case 'applyRules':
          if (message['rules'] is List) {
            applyRules((message['rules'] as List).cast<ProxyRule>());
          }
          break;
        case 'resumeReq':
          final id = message['id'] as String;
          final data = message['data'] as MutableRequest?;
          server.resumePausedRequest(id, editedRequest: data);
          break;
        case 'resumeRes':
          final id = message['id'] as String;
          final data = message['data'] as MutableResponse?;
          server.resumePausedResponse(id, editedResponse: data);
          break;
      }
    }
  });
}

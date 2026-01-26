import 'dart:async';
import 'dart:io';

import 'package:api_craft/flows/providers/flows_provider.dart';
import 'package:api_craft/flows/models/flow.dart';
import 'package:api_craft/flows/providers/paused_providers.dart';
import 'package:api_craft/features/interception/providers/interception_provider.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockhttp/mockttp.dart';

import 'package:api_craft/features/interception/services/interception_script_service.dart';

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

    // Listen for rule changes and apply them dynamically
    ref.listen(interceptionProvider, (previous, next) {
      if (previous != next) {
        _applyRules(next);
      }
    });

    return _createServer();
  }

  Future<void> startServer(int? port) async {
    debugPrint("Server started");
    runZonedGuarded(
      () async {
        await state.start(port: port);
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

        // Setup initial listeners
        _setupListeners();

        // Apply rules
        _applyRules(ref.read(interceptionProvider));
      },
      (error, stackTrace) {
        debugPrint("Server error: $error");
      },
    );
  }

  void _setupListeners() {
    // Clear any existing listeners if possible?
    // Mockttp API doesn't seem to have 'off' easily exposed here,
    // but we assume startServer is called once per instance lifecycle or after stop.
    // Actually if we don't restart server, we run this once.
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
  }

  void _applyRules(List<ProxyRule> rules) {
    debugPrint("Applying ${rules.length} interception rules");
    final manager = ProxyRuleManager(state);

    // reset() is called inside reapplyRules (via manager.clearAllRules)
    // This clears existing rules.
    // Hydrate script actions
    final hydratedRules = rules.map((rule) {
      if (rule.action.type == 'editReq' &&
          rule.action.script != null &&
          rule.action.script!.isNotEmpty) {
        final script = rule.action.script!;
        final newRule = rule.copy();
        newRule.action = RuleActionConfig.editReq((req) {
          return InterceptionScriptService.instance.editRequest(script, req);
        });
        // Preserve script field for UI
        newRule.action.script = script;
        return newRule;
      } else if (rule.action.type == 'editRes' &&
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
        // Preserve script field for UI
        newRule.action.script = script;
        return newRule;
      }
      return rule;
    }).toList();

    manager.reapplyRules(hydratedRules);

    // Default rule: Pass through everything else
    state.forAnyRequest().thenPassThrough();
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

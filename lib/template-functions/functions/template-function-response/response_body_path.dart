import 'dart:convert';

import 'package:api_craft/models/models.dart';
import 'package:api_craft/providers/utils/req_executor.dart';
import 'package:api_craft/services/app_service.dart';
import 'package:api_craft/template-functions/functions/temple_common_args.dart';
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:json_path/json_path.dart';
import 'package:xml/xml.dart';
import 'package:xml/xpath.dart';

final responseBodyPath = TemplateFunction(
  name: "response.body.path",
  description: 'Access a field of the response body using JsonPath or XPath',
  args: [
    requestArgs,
    behaviorArgs,
    returnFormatHstak,
    FormInputText(
      name: 'path',
      label: 'JSONPath or XPath',
      placeholder: '\$.books[0].id or /books[0]/id',
      optional: true,
      dynamicFn: (ctx, args) {
        // get response
        // check xml or json
        // return obj indicating xml or json
        // to just display the placeholder thats it
        return {
          'label': "JSONPath",
          'placeholder': '\$.books[0].id',
          'description':
              'Use JSONPath to access fields in JSON response bodies',
        };
      },
    ),
  ],
  onRender: (ctx, args) async {
    debugPrint("Rendering response.body.path with args: ${args.values}");
    if (args.values['request'] == null || args.values['path'] == null) {
      debugPrint("request or path is null, cannot proceed");
      return null;
    }

    final response = await getResponse(
      ctx,
      purpose: args.purpose.name,
      requestId: args.values['request'],
      behavior: args.values['behavior'],
      ttl: args.values['ttl'],
    );
    debugPrint("Got response: $response");
    if (response == null) return null;
    try {
      return filterJsonPath(response.body, args.values['path'], 'first');
    } catch (e) {
      // try xpath
    }

    try {
      return filterXmlPath(response.body, args.values['path'], 'first');
    } catch (e) {
      debugPrint("Failed to parse XML: $e");
      // may not xml
    }

    return null;
  },
);

final responseHeader = TemplateFunction(
  name: 'response.header',
  description: 'Read the value of a response header, by name',
  args: [
    requestArgs,
    behaviorArgs,
    FormInputText(
      name: 'header',
      label: 'Header Name',
      dynamicFn: (ctx, args) async {},
    ),
  ],
  onRender: (ctx, args) async {
    if (args.values['request'] == null || args.values['header'] == null) {
      return null;
    }
    final h = (args.values['header'] as String).toLowerCase();
    final response = await getResponse(
      ctx,
      purpose: args.purpose.name,
      requestId: args.values['request'],
      behavior: args.values['behavior'],
      ttl: args.values['ttl'],
    );
    if (response == null) return null;

    final header = response.headers.firstWhereOrNull(
      (header) => header[0].toLowerCase() == h,
    );
    return header != null ? header[1] : null;
  },
);

final responseBodyRaw = TemplateFunction(
  name: 'response.body.raw',
  description: 'Access the entire response body, as text',
  args: [requestArgs, behaviorArgs],

  onRender: (ctx, args) async {
    if (args.values['request'] == null) {
      return null;
    }

    final response = await getResponse(
      ctx,
      purpose: args.purpose.name,
      requestId: args.values['request'],
      behavior: args.values['behavior'],
      ttl: args.values['ttl'],
    );
    if (response == null) return null;

    return response.body;
  },
);

/// Helpers
Future<RawHttpResponse?> getResponse(
  Ref ctx, {
  required String purpose,
  String? behavior,
  required String requestId,
  String? ttl,
}) async {
  // var response = await ctx.read(httpRequestProvider).getResById(ctx, requestId);
  var response = await AppService.http.getRes(ctx, requestId);

  if (behavior == Behavior.never.name && response == null) {
    return null;
  }
  final finalBehavior =
      behavior == Behavior.always.name && purpose == Purpose.preview.name
      ? Behavior.smart.name
      : behavior;
  debugPrint(
    "Final behavior: $finalBehavior, response is null: ${response == null}",
  );
  if ((finalBehavior == Behavior.smart.name && response == null) ||
      finalBehavior == Behavior.always.name ||
      (finalBehavior == Behavior.ttl.name &&
          shouldSendExpired(response, ttl))) {
    // response = await ctx.read(httpRequestProvider).runById(ctx, requestId);
    response = await AppService.http.run(ctx, requestId);
  }
  return response;
}

bool shouldSendExpired(RawHttpResponse? response, String? ttl) {
  if (response == null) return true;
  if (ttl == null) return false;
  final expiryDuration = Duration(seconds: int.tryParse(ttl) ?? 0);
  if (expiryDuration.inSeconds == 0) return false;
  final requestDate = response.executeAt.add(
    Duration(milliseconds: response.durationMs),
  );
  final expiryDate = requestDate.add(expiryDuration);
  debugPrint("expiryDate: $expiryDate, now: ${DateTime.now()}");
  return DateTime.now().isAfter(expiryDate);
}

String? filterJsonPath(
  String body,
  String path,
  String returnFormat, {
  String join = ', ',
}) {
  final parsed = jsonDecode(body);
  debugPrint("Parsed body: $parsed");
  var items = JsonPath(path).read(parsed);
  if (returnFormat == Return.first.name) {
    if (items.isNotEmpty) {
      return objToString(items.first.value);
    }
    return null;
  } else if (returnFormat == Return.last.name) {
    if (items.isNotEmpty) {
      return objToString(items.last.value);
    }
    return null;
  } else {
    final values = items.map((e) => objToString(e.value)).toList();
    return values.join(join);
  }
}

String objToString(dynamic obj) {
  if (obj == null) return 'null';
  if (obj is String) return obj;
  if (obj is num || obj is bool) return obj.toString();
  try {
    return jsonEncode(obj);
  } catch (e) {
    return obj.toString();
  }
}

String? filterXmlPath(
  String body,
  String path,
  String returnFormat, {
  String join = ', ',
}) {
  final document = XmlDocument.parse(body);

  final nodes = document.xpath(path);

  if (nodes.isEmpty) return null;

  if (returnFormat == Return.first.name) {
    return _nodeToString(nodes.first);
  } else if (returnFormat == Return.last.name) {
    return _nodeToString(nodes.last);
  } else {
    return nodes.map(_nodeToString).join(join);
  }
}

String? _nodeToString(XmlNode node) {
  if (node is XmlAttribute) return node.value;
  return node.value;
}

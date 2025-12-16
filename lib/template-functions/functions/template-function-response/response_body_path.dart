import 'dart:convert';

import 'package:api_craft/models/models.dart';
import 'package:api_craft/providers/utils/req_executor.dart';
import 'package:api_craft/template-functions/functions/temple_common_args.dart';
import 'package:flutter/widgets.dart';
import 'package:json_path/json_path.dart';

final responseBody = TemplateFunction(
  name: "response.body.path",
  description: 'Access a field of the response body using JsonPath or XPath',
  args: [
    requestArgs,
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
    if (args.values['request'] != null || args.values['path'] != null) {
      return null;
    }
    final response = await getResponse(
      ctx,
      purpose: args.purpose,
      requestId: args.values['request'],
      behavior: args.values['behavior'],
      ttl: args.values['ttl'],
    );
    if (response == null) return null;
    try {
      return filterJsonPath(response.body, args.values['path'], 'first');
    } catch (e) {
      debugPrint("Error in parsing response body: $e");
      return null;
    }
  },
);

Future<RawHttpResponse?> getResponse(
  WContext ctx, {
  required Purpose purpose,
  Behavior? behavior,
  required String requestId,
  String? ttl,
}) async {
  var response = await ctx.read(httpRequestProvider).getResById(requestId);

  if (behavior == Behavior.never && response == null) {
    return null;
  }
  final finalBehavior =
      behavior == Behavior.always && purpose == Purpose.preview
      ? Behavior.smart
      : behavior;
  if ((finalBehavior == Behavior.smart && response != null) ||
      finalBehavior == Behavior.always ||
      (finalBehavior == Behavior.ttl && shouldSendExpired(response, ttl))) {
    response = await ctx.read(httpRequestProvider).runById(requestId);
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
  return DateTime.now().isAfter(expiryDate);
}

String? filterJsonPath(
  String body,
  String path,
  String returnFormat, {
  String join = ', ',
}) {
  final parsed = jsonDecode(body);
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

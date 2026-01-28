import 'package:api_craft/shared/ui/custom_dialog.dart';
import 'package:api_craft/traffic/interceptors/intercept_widgets/interceptor_builder.dart';
import 'package:api_craft/traffic/interceptors/models/interceptor_model.dart';
import 'package:api_craft/traffic/interceptors/sources/android/frida/frida_android_intercept.dart';
import 'package:api_craft/traffic/interceptors/sources/chromium_interceptor.dart';
import 'package:api_craft/traffic/interceptors/sources/firefox_interceptor.dart';
import 'package:api_craft/traffic/interceptors/sources/terminal_interceptor.dart';
import 'package:flutter/material.dart';

class InterceptorsDialog extends StatefulWidget {
  const InterceptorsDialog({super.key});

  @override
  State<InterceptorsDialog> createState() => _InterceptorsDialogState();
}

final List<Interceptor> interceptors = [
  ChromiumInterceptor(),
  FirefoxInterceptor(),
  FridaAndroidInterceptor(),
  TerminalProxyInterceptor(),
];

class _InterceptorsDialogState extends State<InterceptorsDialog> {
  @override
  Widget build(BuildContext context) {
    // final theme = Theme.of(context);
    return CustomDialog(
      showCloseButton: false,
      width: 580,
      // backgroundColor: theme.colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...interceptors.map((interceptor) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: InterceptorBuilder(interceptor: interceptor),
            );
          }),
        ],
      ),
    );
  }
}

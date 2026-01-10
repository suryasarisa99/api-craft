import 'package:flutter/material.dart';
import 'package:api_craft/core/widgets/sonner/sonner.dart';

enum _ToastType { info, success, error, warning }

class ToastService {
  static void show(
    String message, {
    bool isError = false,
    Duration? duration = const Duration(seconds: 4),
    String? description,
  }) {
    Sonner.toast(
      duration: duration,
      builder: (context, onDismiss) => _StandardToast(
        message: message,
        description: description,
        type: isError ? _ToastType.error : _ToastType.success,
        onDismiss: onDismiss,
      ),
    );
  }

  static void success(
    String message, {
    String? description,
    Duration? duration = const Duration(seconds: 4),
  }) {
    Sonner.toast(
      duration: duration,
      builder: (context, onDismiss) => _StandardToast(
        message: message,
        description: description,
        type: _ToastType.success,
        onDismiss: onDismiss,
      ),
    );
  }

  static void error(
    String message, {
    String? description,
    Duration? duration = const Duration(seconds: 4),
  }) {
    Sonner.toast(
      duration: duration,
      builder: (context, onDismiss) => _StandardToast(
        message: message,
        description: description,
        type: _ToastType.error,
        onDismiss: onDismiss,
      ),
    );
  }

  static void warning(
    String message, {
    String? description,
    Duration? duration = const Duration(seconds: 4),
  }) {
    Sonner.toast(
      duration: duration,
      builder: (context, onDismiss) => _StandardToast(
        message: message,
        description: description,
        type: _ToastType.warning,
        onDismiss: onDismiss,
      ),
    );
  }

  static void info(String message) {
    Sonner.toast(
      builder: (context, onDismiss) => _StandardToast(
        message: message,
        type: _ToastType.info,
        onDismiss: onDismiss,
      ),
    );
  }
}

class _StandardToast extends StatelessWidget {
  final String message;
  final String? description;
  final _ToastType type;
  final VoidCallback onDismiss;

  const _StandardToast({
    required this.message,
    this.description,
    required this.type,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.white;
    Color fg = Colors.black;
    IconData icon = Icons.info_outline;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      bg = const Color(0xFF1E1E1E);
      fg = Colors.white;
    }

    switch (type) {
      case _ToastType.success:
        icon = Icons.check_circle_outline;
        break;
      case _ToastType.error:
        icon = Icons.error_outline;
        break;
      case _ToastType.warning:
        icon = Icons.warning_amber_rounded;
        break;
      default:
        break;
    }

    return Container(
      width: 356,
      margin: const EdgeInsets.symmetric(horizontal: 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: fg.withValues(alpha: 0.8)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (description != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      description!,
                      style: TextStyle(
                        color: fg.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(
              Icons.close,
              size: 16,
              color: fg.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

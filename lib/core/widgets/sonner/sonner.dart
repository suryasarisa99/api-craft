import 'dart:async';
import 'package:flutter/material.dart';

/// Configuration for the Sonner overlay behavior
class SonnerConfig {
  final double expandedSpacing;
  final double stackSpacing;
  final double toastWidth;
  final int maxVisibleToasts;
  final Alignment alignment;

  const SonnerConfig({
    this.expandedSpacing = 60.0,
    this.stackSpacing = 10.0,
    this.toastWidth = 356.0,
    this.maxVisibleToasts = 10,
    this.alignment = Alignment.bottomRight,
  });
}

class ToastItem {
  final String id;
  final Widget Function(BuildContext context, VoidCallback onDismiss) builder;
  final Duration? duration;
  final VoidCallback? onDismiss;

  ToastItem({
    required this.id,
    required this.builder,
    this.duration,
    this.onDismiss,
  });
}

class Sonner {
  static final GlobalKey<SonnerOverlayState> overlayKey =
      GlobalKey<SonnerOverlayState>();

  /// Shows a toast using a custom builder.
  /// If [duration] is null, the toast will persist until manually dismissed.
  static void toast({
    required Widget Function(BuildContext context, VoidCallback onDismiss)
    builder,
    Duration? duration,
  }) {
    overlayKey.currentState?.addToast(
      ToastItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        builder: builder,
        duration: duration,
      ),
    );
  }
}

class SonnerOverlay extends StatefulWidget {
  final Widget child;
  final SonnerConfig config;

  const SonnerOverlay({
    super.key,
    required this.child,
    this.config = const SonnerConfig(),
  });

  @override
  State<SonnerOverlay> createState() => SonnerOverlayState();
}

class SonnerOverlayState extends State<SonnerOverlay> {
  final List<ToastItem> _toasts = [];
  bool _isHovering = false;

  void addToast(ToastItem toast) {
    setState(() {
      _toasts.insert(0, toast); // Add new to front
    });

    // Auto dismiss if duration is provided
    if (toast.duration != null) {
      Future.delayed(toast.duration!, () {
        removeToast(toast.id);
      });
    }
  }

  void removeToast(String id) {
    if (!mounted) return;
    setState(() {
      _toasts.removeWhere((t) => t.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Determine positioning based on alignment
    // For simplicity, we hardcode bottom right logic but use alignment for the container
    // Ideally we'd support top/bottom logic.
    // Given the previous code was Positioned bottom: 24, right: 24, we keep that for now
    // but allow config to influence inner stack behavior.

    return Stack(
      children: [
        widget.child,
        Positioned(
          bottom: 24,
          right: 24,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovering = true),
            onExit: (_) => setState(() => _isHovering = false),
            child: SizedBox(
              width: widget.config.toastWidth,
              height: _toasts.isEmpty
                  ? 0
                  : 400, // Constrain height to avoid blocking too much
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: _buildToastStack(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildToastStack() {
    final visibleToasts = _toasts.take(widget.config.maxVisibleToasts).toList();
    final widgets = <Widget>[];

    for (int i = 0; i < visibleToasts.length; i++) {
      final toast = visibleToasts[i];
      final index = i;

      // Stacking Logic
      // Front (index 0): scale 1.0, y 0
      // Back (index > 0): scale drops, y moves up (negative)

      double scale = 1.0 - (index * 0.05);
      double yOffset = -(index * widget.config.stackSpacing);

      // On Hover (Spread)
      if (_isHovering) {
        scale = 1.0;
        yOffset = -(index * widget.config.expandedSpacing);
      }

      double opacity = 1.0;
      if (index >= widget.config.maxVisibleToasts - 1) {
        // Fade out the last item as it creates space for others or exceeds limit
        // Actually we take `maxVisibleToasts`, so the last one is visible.
        // If we want to hide "behind" items, we can handle logic here.
        // But `take` limits the list already.
      }

      widgets.add(
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          bottom: _isHovering
              ? (index * widget.config.expandedSpacing)
              : (index * widget.config.stackSpacing),
          left: 0,
          right: 0,
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment.bottomCenter,
            child: AnimatedOpacity(
              opacity: opacity,
              duration: const Duration(milliseconds: 200),
              child: _ToastBuilderWrapper(
                key: ValueKey(toast.id),
                toast: toast,
                onDismiss: () => removeToast(toast.id),
              ),
            ),
          ),
        ),
      );
    }

    return widgets.reversed.toList();
  }
}

class _ToastBuilderWrapper extends StatelessWidget {
  final ToastItem toast;
  final VoidCallback onDismiss;

  const _ToastBuilderWrapper({
    super.key,
    required this.toast,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(toast.id),
      onDismissed: (_) => onDismiss(),
      direction: DismissDirection.horizontal,
      child: Material(
        type: MaterialType.transparency,
        child: toast.builder(context, onDismiss),
      ),
    );
  }
}

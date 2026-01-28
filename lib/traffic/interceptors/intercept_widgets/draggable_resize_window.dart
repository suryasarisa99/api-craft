import 'package:flutter/material.dart';

OverlayEntry showDraggableWindowOverlay({
  required BuildContext context,
  // required Widget Function(double width) childBuilder,
  required Widget child,
}) {
  final overlay = OverlayEntry(
    builder: (context) => DraggableResizableWindow(child: child),
    // builder: (context) => DraggableResizableWindow(childBuilder: childBuilder),
  );

  Overlay.of(context).insert(overlay);
  return overlay;
}

class DraggableResizableWindow extends StatefulWidget {
  final Widget child;
  final double initialTop;
  final double initialLeft;
  final double initialWidth;
  final double initialHeight;

  const DraggableResizableWindow({
    super.key,
    required this.child,
    this.initialTop = 100,
    this.initialLeft = 50,
    this.initialWidth = 350,
    this.initialHeight = 600,
  });

  @override
  State<DraggableResizableWindow> createState() =>
      _DraggableResizableWindowState();
}

class _DraggableResizableWindowState extends State<DraggableResizableWindow> {
  late double top, left, width, height;
  static const double edgeSize = 4.0; // Size of the resize edge area
  static const double cornerSize = 16.0; // Larger corner area
  static const double minSize = 150.0;
  static const double maxSize = 2000.0;

  @override
  void initState() {
    super.initState();
    top = widget.initialTop;
    left = widget.initialLeft;
    width = widget.initialWidth;
    height = widget.initialHeight;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Main content with drag functionality
            GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  top += details.delta.dy;
                  left += details.delta.dx;
                });
              },
              child: SizedBox(
                width: width,
                height: height,
                child: widget.child,
              ),
            ),

            // Edges (placed first, will be underneath corners)
            // Top edge (avoiding corners)
            _buildResizeEdge(
              top: 0,
              left: cornerSize,
              width: width - cornerSize * 2,
              height: edgeSize,
              cursor: SystemMouseCursors.resizeUp,
              onPanUpdate: (delta) {
                setState(() {
                  final newHeight = height - delta.dy;
                  if (newHeight >= minSize && newHeight <= maxSize) {
                    top += delta.dy;
                    height = newHeight;
                  }
                });
              },
            ),

            // Bottom edge (avoiding corners)
            _buildResizeEdge(
              bottom: 0,
              left: cornerSize,
              width: width - cornerSize * 2,
              height: edgeSize,
              cursor: SystemMouseCursors.resizeDown,
              onPanUpdate: (delta) {
                setState(() {
                  height = (height + delta.dy).clamp(minSize, maxSize);
                });
              },
            ),

            // Left edge (avoiding corners)
            _buildResizeEdge(
              top: cornerSize,
              left: 0,
              width: edgeSize,
              height: height - cornerSize * 2,
              cursor: SystemMouseCursors.resizeLeft,
              onPanUpdate: (delta) {
                setState(() {
                  final newWidth = width - delta.dx;
                  if (newWidth >= minSize && newWidth <= maxSize) {
                    left += delta.dx;
                    width = newWidth;
                  }
                });
              },
            ),

            // Right edge (avoiding corners)
            _buildResizeEdge(
              top: cornerSize,
              right: 0,
              width: edgeSize,
              height: height - cornerSize * 2,
              cursor: SystemMouseCursors.resizeRight,
              onPanUpdate: (delta) {
                setState(() {
                  width = (width + delta.dx).clamp(minSize, maxSize);
                });
              },
            ),

            // Corners (placed AFTER edges so they're on top)
            // Top-left corner
            _buildResizeEdge(
              top: 0,
              left: 0,
              width: cornerSize,
              height: cornerSize,
              cursor: SystemMouseCursors.resizeUpLeftDownRight,
              onPanUpdate: (delta) {
                setState(() {
                  final newWidth = width - delta.dx;
                  final newHeight = height - delta.dy;
                  if (newWidth >= minSize && newWidth <= maxSize) {
                    left += delta.dx;
                    width = newWidth;
                  }
                  if (newHeight >= minSize && newHeight <= maxSize) {
                    top += delta.dy;
                    height = newHeight;
                  }
                });
              },
            ),

            // Top-right corner
            _buildResizeEdge(
              top: 0,
              right: 0,
              width: cornerSize,
              height: cornerSize,
              cursor: SystemMouseCursors.resizeUpRightDownLeft,
              onPanUpdate: (delta) {
                setState(() {
                  width = (width + delta.dx).clamp(minSize, maxSize);
                  final newHeight = height - delta.dy;
                  if (newHeight >= minSize && newHeight <= maxSize) {
                    top += delta.dy;
                    height = newHeight;
                  }
                });
              },
            ),

            // Bottom-left corner
            _buildResizeEdge(
              bottom: 0,
              left: 0,
              width: cornerSize,
              height: cornerSize,
              cursor: SystemMouseCursors.resizeUpRightDownLeft,
              onPanUpdate: (delta) {
                setState(() {
                  final newWidth = width - delta.dx;
                  if (newWidth >= minSize && newWidth <= maxSize) {
                    left += delta.dx;
                    width = newWidth;
                  }
                  height = (height + delta.dy).clamp(minSize, maxSize);
                });
              },
            ),

            // Bottom-right corner
            _buildResizeEdge(
              bottom: 0,
              right: 0,
              width: cornerSize,
              height: cornerSize,
              // cursor: SystemMouseCursors.resizeUpLeftDownRight,
              cursor: SystemMouseCursors.resizeDownRight,
              onPanUpdate: (delta) {
                setState(() {
                  width = (width + delta.dx).clamp(minSize, maxSize);
                  height = (height + delta.dy).clamp(minSize, maxSize);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResizeEdge({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double width,
    required double height,
    required MouseCursor cursor,
    required Function(Offset delta) onPanUpdate,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          onPanUpdate: (details) => onPanUpdate(details.delta),
          child: Container(
            width: width,
            height: height,
            color: Colors.transparent, // Invisible but interactive
            // Debug: Uncomment to see resize areas
            // color: Colors.red.withOpacity(0.2),
          ),
        ),
      ),
    );
  }
}

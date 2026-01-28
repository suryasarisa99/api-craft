import 'package:flutter/material.dart';

/// A controller to programmatically manage a [ResizableContainer].
///
/// Use this controller to hide, show, or resize the children of the container.
class ResizableController extends ChangeNotifier {
  double _ratio;
  bool _isChild1Hidden;
  bool _isChild2Hidden;

  ResizableController({
    double initialRatio = 0.5,
    bool isChild1Hidden = false,
    bool isChild2Hidden = false,
  }) : _ratio = initialRatio,
       _isChild1Hidden = isChild1Hidden,
       _isChild2Hidden = isChild2Hidden;

  /// The current split ratio between the two children.
  double get currentRatio => _ratio;

  /// Whether the first child (top/left) is currently hidden.
  bool get isChild1Hidden => _isChild1Hidden;

  /// Whether the second child (bottom/right) is currently hidden.
  bool get isChild2Hidden => _isChild2Hidden;

  /// Sets the split ratio of the container.
  ///
  /// [ratio] must be between 0.0 and 1.0.
  void setRatio(double ratio) {
    _ratio = ratio.clamp(0.0, 1.0);
    notifyListeners();
  }

  /// Hides the first child (top/left) and expands the second child.
  void hideFirstChild() {
    if (!_isChild1Hidden) {
      _isChild1Hidden = true;
      notifyListeners();
    }
  }

  /// Shows the first child (top/left).
  void showFirstChild() {
    if (_isChild1Hidden) {
      _isChild1Hidden = false;
      notifyListeners();
    }
  }

  /// Hides the second child (bottom/right) and expands the first child.
  void hideSecondChild() {
    if (!_isChild2Hidden) {
      _isChild2Hidden = true;
      notifyListeners();
    }
  }

  /// Shows the second child (bottom/right).
  void showSecondChild() {
    if (_isChild2Hidden) {
      _isChild2Hidden = false;
      notifyListeners();
    }
  }
}

/// A widget that arranges two children in a resizable container, separated
/// by a draggable divider.
class ResizableContainer extends StatefulWidget {
  final Widget child1;
  final Widget child2;
  final Axis axis;
  final double dividerWidth;
  final double dividerHandleWidth;
  final Color dividerColor;
  final ResizableController? controller;

  /// The color of the divider when the user is dragging it.
  final Color? onDragDividerColor;

  /// The width of the divider when the user is dragging it.
  final double? onDragDividerWidth;

  final double minRatio;
  final double maxRatio;

  const ResizableContainer({
    super.key,
    required this.child1,
    required this.child2,
    this.axis = Axis.horizontal,
    this.dividerWidth = 1.0,
    this.dividerHandleWidth = 12.0,
    this.dividerColor = Colors.grey,
    this.onDragDividerColor,
    this.onDragDividerWidth,
    this.controller,
    this.minRatio = 0.1,
    this.maxRatio = 0.9,
  }) : assert(dividerHandleWidth >= dividerWidth);

  @override
  State<ResizableContainer> createState() => _ResizableContainerState();
}

class _ResizableContainerState extends State<ResizableContainer> {
  late ResizableController _controller;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ResizableController();
    _controller.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(ResizableContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_rebuild);
      _controller = widget.controller ?? ResizableController();
      _controller.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_rebuild);
    // If we created the controller internally, we should dispose of it.
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _rebuild() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSize = widget.axis == Axis.horizontal
            ? constraints.maxWidth
            : constraints.maxHeight;

        if (totalSize <= 0 || !totalSize.isFinite) {
          return const SizedBox.shrink();
        }

        // If both are hidden, show nothing.
        if (_controller.isChild1Hidden && _controller.isChild2Hidden) {
          return const SizedBox.shrink();
        }

        final child1Size = _controller.isChild1Hidden
            ? 0.0
            : (_controller.isChild2Hidden
                  ? totalSize
                  : totalSize * _controller.currentRatio);

        final currentDividerWidth =
            (_isDragging ? widget.onDragDividerWidth : widget.dividerWidth) ??
            widget.dividerWidth;

        final showDivider =
            !_controller.isChild1Hidden && !_controller.isChild2Hidden;

        return Stack(
          children: [
            // --- First Child (Top or Left) ---
            if (!_controller.isChild1Hidden)
              Positioned(
                top: 0,
                left: 0,
                width: widget.axis == Axis.horizontal
                    ? child1Size
                    : constraints.maxWidth,
                height: widget.axis == Axis.vertical
                    ? child1Size
                    : constraints.maxHeight,
                child: widget.child1,
              ),

            // --- Second Child (Bottom or Right) ---
            if (!_controller.isChild2Hidden)
              Positioned(
                top: widget.axis == Axis.vertical
                    ? (_controller.isChild1Hidden
                          ? 0.0
                          : child1Size + currentDividerWidth)
                    : 0,
                left: widget.axis == Axis.horizontal
                    ? (_controller.isChild1Hidden
                          ? 0.0
                          : child1Size + currentDividerWidth)
                    : 0,
                width: widget.axis == Axis.horizontal
                    ? (_controller.isChild1Hidden
                          ? constraints.maxWidth
                          : constraints.maxWidth -
                                child1Size -
                                currentDividerWidth)
                    : constraints.maxWidth,
                height: widget.axis == Axis.vertical
                    ? (_controller.isChild1Hidden
                          ? constraints.maxHeight
                          : constraints.maxHeight -
                                child1Size -
                                currentDividerWidth)
                    : constraints.maxHeight,
                child: widget.child2,
              ),

            // --- Draggable Divider ---
            if (showDivider)
              Positioned(
                top: widget.axis == Axis.vertical
                    ? child1Size - (widget.dividerHandleWidth / 2)
                    : 0,
                left: widget.axis == Axis.horizontal
                    ? child1Size - (widget.dividerHandleWidth / 2)
                    : 0,
                width: widget.axis == Axis.horizontal
                    ? widget.dividerHandleWidth
                    : constraints.maxWidth,
                height: widget.axis == Axis.vertical
                    ? widget.dividerHandleWidth
                    : constraints.maxHeight,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: (_) => setState(() => _isDragging = true),
                  onPanEnd: (_) => setState(() => _isDragging = false),
                  onPanUpdate: (details) {
                    final delta = widget.axis == Axis.horizontal
                        ? details.delta.dx
                        : details.delta.dy;
                    final newRatio =
                        _controller.currentRatio + (delta / totalSize);
                    _controller.setRatio(
                      newRatio.clamp(widget.minRatio, widget.maxRatio),
                    );
                  },
                  child: MouseRegion(
                    cursor: widget.axis == Axis.horizontal
                        ? SystemMouseCursors.resizeLeftRight
                        : SystemMouseCursors.resizeUpDown,
                    child: Center(
                      child: Container(
                        width: widget.axis == Axis.horizontal
                            ? currentDividerWidth
                            : double.infinity,
                        height: widget.axis == Axis.vertical
                            ? currentDividerWidth
                            : double.infinity,
                        color:
                            (_isDragging
                                ? widget.onDragDividerColor
                                : widget.dividerColor) ??
                            widget.dividerColor,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

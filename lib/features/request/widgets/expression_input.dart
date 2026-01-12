import 'dart:convert';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/core/services/assertion_service.dart';
import 'package:api_craft/core/widgets/ui/custom_input.dart';
import 'package:api_craft/features/request/models/node_model.dart';
import 'package:api_craft/features/response/response_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExpressionInput extends ConsumerStatefulWidget {
  final String value;
  final ValueChanged<String> onUpdate;
  final String id;
  final bool autoFocus;
  final bool isEnabled;

  const ExpressionInput({
    super.key,
    required this.value,
    required this.onUpdate,
    required this.id,
    this.autoFocus = false,
    this.isEnabled = true,
  });

  @override
  ConsumerState<ExpressionInput> createState() => _ExpressionInputState();
}

class _ExpressionInputState extends ConsumerState<ExpressionInput> {
  late TextEditingController _ctrl;
  final FocusNode _fn = FocusNode();
  final LayerLink _layerLink = LayerLink();
  final Object _groupId = Object();
  OverlayEntry? _overlayEntry;
  List<String> _suggestions = [];
  int _selectedIndex = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
    _fn.addListener(_handleFocusChange);
    _fn.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          if (_suggestions.isNotEmpty) {
            setState(() {
              _selectedIndex = (_selectedIndex + 1) % _suggestions.length;
            });
            _updateOverlay();
            _scrollToSelected();
            return KeyEventResult.handled;
          }
        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          if (_suggestions.isNotEmpty) {
            setState(() {
              _selectedIndex =
                  (_selectedIndex - 1 + _suggestions.length) %
                  _suggestions.length;
            });
            _updateOverlay();
            _scrollToSelected();
            return KeyEventResult.handled;
          }
        } else if (event.logicalKey == LogicalKeyboardKey.enter) {
          if (_suggestions.isNotEmpty &&
              _selectedIndex >= 0 &&
              _selectedIndex < _suggestions.length) {
            _applySuggestion(_suggestions[_selectedIndex]);
            return KeyEventResult.handled;
          }
        }
      }
      return KeyEventResult.ignored;
    };
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _fn.requestFocus();
          _ctrl.selection = TextSelection.fromPosition(
            TextPosition(offset: _ctrl.text.length),
          );
        }
      });
    }
  }

  @override
  void didUpdateWidget(ExpressionInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && widget.value != _ctrl.text) {
      _ctrl.text = widget.value;
      _ctrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _ctrl.text.length),
      );
    }
  }

  @override
  void dispose() {
    _hideOverlay();
    _fn.removeListener(_handleFocusChange);
    _fn.dispose();
    _scrollController.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_fn.hasFocus) {
      _showOverlay();
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => _ExpressionOverlay(
        layerLink: _layerLink,
        expression: _ctrl.text,
        requestId: widget.id,
        groupId: _groupId,
        onHide: _hideOverlay,
        // We recalculate suggestions here only if needed, but optimally we should pass them
        // To minimize refactor, let's keep logic but now we need to sync state.
        // Better: Compute suggestions in _onChanged and pass them.
        suggestions: _suggestions,
        selectedIndex: _selectedIndex,
        scrollController: _scrollController,
        onSuggestionSelected: (suggestion) {
          _applySuggestion(suggestion);
        },
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _updateOverlay() {
    // Rebuild the overlay with new expression
    _overlayEntry?.markNeedsBuild();
  }

  void _applySuggestion(String suggestion) {
    // We need to fetch the inspection to know where to append
    final res = ref.read(responseProvider(widget.id));
    if (res == null) return;

    Map<String, dynamic>? jsonBody;
    try {
      jsonBody = jsonDecode(res.body);
    } catch (_) {}

    final inspection = AssertionService.inspectPath(
      _ctrl.text,
      res,
      jsonBody: jsonBody,
    );

    String newText;
    if (inspection.validExpression.isEmpty) {
      // Should not happen if suggestions are shown, but safe fallback
      newText = suggestion;
    } else {
      newText = "${inspection.validExpression}.$suggestion";
    }

    // Keep focus first to avoid platform overwriting selection
    _fn.requestFocus();

    _ctrl.text = newText;
    _ctrl.selection = TextSelection.collapsed(offset: newText.length);

    widget.onUpdate(newText);
    _updateSuggestions();
    _updateOverlay();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TapRegion(
        groupId: _groupId,
        onTapOutside: (_) => _hideOverlay(),
        child: TextField(
          controller: _ctrl,
          focusNode: _fn,
          onChanged: (val) {
            widget.onUpdate(val);
            _updateSuggestions(); // Update suggestions on text change
            if (_overlayEntry != null) {
              _updateOverlay();
            } else {
              _showOverlay();
            }
          },
        ),
      ),
    );
  }

  void _updateSuggestions() {
    final res = ref.read(responseProvider(widget.id));
    if (res == null) {
      _suggestions = [];
      return;
    }

    Map<String, dynamic>? jsonBody;
    try {
      jsonBody = jsonDecode(res.body);
    } catch (_) {}

    final inspection = AssertionService.inspectPath(
      _ctrl.text,
      res,
      jsonBody: jsonBody,
    );
    _suggestions = inspection.suggestions;
    _selectedIndex = 0; // Reset selection
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;
    // itemHeight ~32? + padding. Let's estimate or better use ensureVisible if we had keys.
    // Simple estimation:
    const itemHeight = 32.0; // Approximation
    final offset = _selectedIndex * itemHeight;
    // We want to keep it in view.
    if (offset < _scrollController.offset) {
      _scrollController.jumpTo(offset);
    } else if (offset + itemHeight >
        _scrollController.offset +
            _scrollController.position.viewportDimension) {
      _scrollController.jumpTo(
        offset + itemHeight - _scrollController.position.viewportDimension,
      );
    }
  }
}

class _ExpressionOverlay extends ConsumerWidget {
  final LayerLink layerLink;
  final String expression;
  final String requestId;
  final Object groupId;
  final VoidCallback onHide;
  final ValueChanged<String> onSuggestionSelected;
  final List<String> suggestions;
  final int selectedIndex;
  final ScrollController scrollController;

  const _ExpressionOverlay({
    required this.layerLink,
    required this.expression,
    required this.requestId,
    required this.groupId,
    required this.onHide,
    required this.onSuggestionSelected,
    required this.suggestions,
    required this.selectedIndex,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final res = ref.watch(responseProvider(requestId));

    if (res == null || expression.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    Map<String, dynamic>? jsonBody;
    try {
      jsonBody = jsonDecode(res.body);
    } catch (_) {}

    final inspection = AssertionService.inspectPath(
      expression,
      res,
      jsonBody: jsonBody,
    );

    return Positioned(
      width: 400, // Fixed width for now, or could match layerLink size
      child: CompositedTransformFollower(
        link: layerLink,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, 4),
        child: TapRegion(
          groupId: groupId,
          onTapOutside: (_) => onHide(),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFF1E1E1E), // Dark bg
            child: Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top: Preview
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.white12)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Query breakdown
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 12),
                            children: [
                              TextSpan(
                                text: inspection.validExpression,
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                ),
                              ),
                              if (inspection.pendingExpression.isNotEmpty)
                                TextSpan(
                                  text: inspection.pendingExpression,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Value Preview
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxHeight: 100,
                            minWidth: double.infinity,
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              inspection.value != null
                                  ? _formatValue(inspection.value)
                                  : "null",
                              style: const TextStyle(
                                fontFamily: 'RobotoMono',
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                              // maxLines: 5,
                              // overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom: Suggestions
                  if (suggestions.isNotEmpty)
                    Flexible(
                      child: ListView.builder(
                        controller: scrollController,
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: suggestions.length,
                        itemBuilder: (context, index) {
                          final suggestion = suggestions[index];
                          final isSelected = index == selectedIndex;
                          return InkWell(
                            onTap: () => onSuggestionSelected(suggestion),
                            // hoverColor: Colors.white10,
                            child: Container(
                              color: isSelected
                                  ? Colors.blue.withOpacity(0.3)
                                  : null,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Text(
                                suggestion,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  else if (inspection.value is! Map && inspection.value != null)
                    // No suggestions for leaf nodes usually
                    const SizedBox.shrink()
                  else if (inspection.suggestions.isEmpty &&
                      inspection.value == null)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        "No suggestions",
                        style: TextStyle(color: Colors.white30, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatValue(dynamic value) {
    if (value is Map || value is List) {
      return const JsonEncoder.withIndent('  ').convert(value);
    }
    return value.toString();
  }
}

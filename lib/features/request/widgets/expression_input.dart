import 'dart:convert';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/core/services/assertion_service.dart';
import 'package:api_craft/core/widgets/ui/custom_input.dart';
import 'package:api_craft/features/request/models/node_model.dart';
import 'package:api_craft/features/response/models/http_response_model.dart';
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
  final String? hint;

  const ExpressionInput({
    super.key,
    required this.value,
    required this.onUpdate,
    required this.id,
    this.autoFocus = false,
    this.isEnabled = true,
    this.hint,
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

  AssertionInspection? _lastInspection;

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
      // Update suggestions when gaining focus to ensure freshness
      _updateSuggestions();
      _showOverlay();
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => _ExpressionOverlay(
        layerLink: _layerLink,
        inspection: _lastInspection,
        groupId: _groupId,
        onHide: _hideOverlay,
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
    _overlayEntry?.markNeedsBuild();
  }

  void _applySuggestion(String suggestion) {
    // If we have a cached inspection, use it to get the prefix
    final inspection = _lastInspection;
    debugPrint("inspection is null: ${inspection == null}");

    // Fallback if inspection is null (shouldn't happen if suggestions exist)
    if (inspection == null) {
      // Try to update info just in case
      final res = getRes();
      if (res != null) {
        Map<String, dynamic>? jsonBody;
        try {
          jsonBody = jsonDecode(res.body);
        } catch (_) {}
        final insp = AssertionService.inspectPath(
          _ctrl.text,
          res,
          jsonBody: jsonBody,
        );
        _applySuggestionLogic(suggestion, insp);
        return;
      }
      return;
    } else {}

    _applySuggestionLogic(suggestion, inspection);
  }

  void _applySuggestionLogic(
    String suggestion,
    AssertionInspection inspection,
  ) {
    String newText;
    if (inspection.validExpression.isEmpty) {
      newText = suggestion;
    } else {
      newText = "${inspection.validExpression}.$suggestion";
    }

    _fn.requestFocus();

    _ctrl.text = newText;
    _ctrl.selection = TextSelection.collapsed(offset: newText.length);

    widget.onUpdate(newText);
    _updateSuggestions(); // Recalculate based on new text
    if (_overlayEntry != null) {
      _updateOverlay();
    }
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
          decoration: InputDecoration(hintText: widget.hint),
          onChanged: (val) {
            widget.onUpdate(val);
            _updateSuggestions(); // Update suggestions & inspection
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

  RawHttpResponse? getRes() {
    final tree = ref.read(fileTreeProvider);
    final map = tree.nodeMap;
    final node = map[widget.id];

    if (node is FolderNode) {
      for (final childId in node.children) {
        final child = map[childId];
        if (child is RequestNode) {
          return ref.read(responseProvider(child.id));
        }
      }
      return RawHttpResponse.dummyRes();
    } else {
      // If node is not found or is RequestNode
      return ref.read(responseProvider(widget.id));
    }
  }

  void _updateSuggestions() {
    final res = getRes();
    if (res == null) {
      _suggestions = [];
      _lastInspection = null;
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

    _lastInspection = inspection;
    _suggestions = inspection.suggestions;
    _selectedIndex = 0;
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;
    const itemHeight = 32.0;
    final offset = _selectedIndex * itemHeight;
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
  final AssertionInspection? inspection;
  final Object groupId;
  final VoidCallback onHide;
  final ValueChanged<String> onSuggestionSelected;
  final List<String> suggestions;
  final int selectedIndex;
  final ScrollController scrollController;

  const _ExpressionOverlay({
    required this.layerLink,
    required this.inspection,
    required this.groupId,
    required this.onHide,
    required this.onSuggestionSelected,
    required this.suggestions,
    required this.selectedIndex,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Used cached inspection result
    final insp = inspection;

    if (insp == null && suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    // If inspection is null for some reason but we have suggestions? Should be synced.
    // But if insp is null, we can't show preview.

    return Positioned(
      width: 400,
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
                  // Top: Preview (Only if we have inspection)
                  if (insp != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.white12),
                        ),
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
                                  text: insp.validExpression,
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
                                  ),
                                ),
                                if (insp.pendingExpression.isNotEmpty)
                                  TextSpan(
                                    text: insp.pendingExpression,
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
                                insp.value != null
                                    ? _formatValue(insp.value)
                                    : "null",
                                style: const TextStyle(
                                  fontFamily: 'RobotoMono',
                                  fontSize: 11,
                                  color: Colors.white70,
                                ),
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
                  else if (insp != null &&
                      insp.value is! Map &&
                      insp.value != null)
                    // No suggestions for leaf nodes usually
                    const SizedBox.shrink()
                  else if (suggestions.isEmpty && (insp?.value == null))
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

import 'package:api_craft/core/widgets/ui/custom_dialog.dart';
import 'package:api_craft/core/widgets/ui/surya_theme_icon.dart';
import 'package:api_craft/features/interception/widgets/action_editor.dart';
import 'package:api_craft/flows/filter/condition_provider.dart';
import 'package:api_craft/flows/filter/models/m.dart';
import 'package:api_craft/flows/filter/widgets/filter_group.dart';
import 'package:api_craft/flows/filter/filter_converter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockhttp/ui/rule_config.dart';
import 'package:suryaicons/bulk_rounded.dart';

class InterceptionDialog extends StatefulWidget {
  final List<ProxyRule> initialRules;
  final ValueChanged<List<ProxyRule>> onSave;

  const InterceptionDialog({
    super.key,
    required this.initialRules,
    required this.onSave,
  });

  @override
  State<InterceptionDialog> createState() => _InterceptionDialogState();
}

class _InterceptionDialogState extends State<InterceptionDialog> {
  late List<ProxyRule> _rules;
  static const _autoSave = true;

  @override
  void initState() {
    super.initState();
    // Deep copy using copy() method and manually handling metadata/uiFilter deep copy
    _rules = widget.initialRules.map((r) {
      final newRule = r.copy();
      // Manually deep copy uiFilter in metadata if it exists
      if (newRule.metadata != null &&
          newRule.metadata!.containsKey('uiFilter')) {
        // The copy() already did Map.from(metadata), so we have a shallow copy of the map.
        // But 'uiFilter' value is likely a Map (JSON) if it came from JSON, or we might need to verify.
        // If it's a Map, Map.from above only copied the reference to the inner Map.
        // We need to deep copy the inner Map.
        final uiFilterJson = newRule.metadata!['uiFilter'];
        if (uiFilterJson is Map) {
          newRule.metadata!['uiFilter'] = Map<String, dynamic>.from(
            uiFilterJson as Map<String, dynamic>,
          );
          // Note: If FilterNode.toJson() produces nested maps/lists, we ideally need full deep copy.
          // But jsonDecode/Encode cycle is safest deep copy for JSON data.
          // Or assume 1-level deep? No, filters are recursive.
          // Let's rely on JSON copy helper or logic.
          // Re-parsing to FilterNode and back to JSON is a valid way to deep copy too!
          try {
            final tempNode = (uiFilterJson['type'] == 'group')
                ? FilterGroup.fromJson(uiFilterJson)
                : FilterCondition.fromJson(
                    uiFilterJson,
                  );
            newRule.metadata!['uiFilter'] = tempNode.copy().toJson();
          } catch (e) {
            // Fallback: re-encode decode? or just accept shallow for now to avoid complexity?
            // The user wants valid code.
            // Let's do simple map copy for now or rely on re-parsing if possible.
            // Actually we have FilterGroup available here.
          }
        }
      }
      return newRule;
    }).toList();
  }

  void _addRule() {
    setState(() {
      final uiFilter = FilterGroup(children: [FilterCondition()]);
      _rules.add(
        ProxyRule(
          name: 'New Rule ${_rules.length + 1}',
          action: RuleActionConfig.passthrough(),
          metadata: {'uiFilter': uiFilter.toJson()},
        ),
      );
    });
  }

  void _removeRule(int index) {
    setState(() {
      _rules.removeAt(index);
    });
  }

  void _save() {
    // Before saving, ensure matchers are updated from UI filters logic?
    // Conversion happens when 'uiFilter' changes via ref.listen in item.
    // However, if we save to JSON, we rely on metadata['uiFilter'] being correct.
    // The server/mockhttp might look at 'matcher'.
    // We should ensure 'matcher' is set in ProxyRule before saving?
    // We do this in _InterceptionRuleItem's ref.listen logic.
    widget.onSave(_rules);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (result, _) {
        if (_autoSave) {
          widget.onSave(_rules);
        }
      },
      child: CustomDialog(
        width: 900,
        height: 800,
        showCloseButton: false,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Interception Rules',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addRule,
                  tooltip: 'Add Rule',
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _rules.length,
                itemBuilder: (context, index) {
                  final rule = _rules[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: _InterceptionRuleItem(
                      key: ValueKey(
                        rule.id,
                      ), // Important for state preservation
                      rule: rule,
                      onDelete: () => _removeRule(index),
                      onUpdate: (updatedRule) {
                        // _rules[index] refers to the object, simpler to just access object ref
                        // But if we replaced the object:
                        _rules[index] = updatedRule;
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            if (!_autoSave)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _save, child: const Text('Save')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _InterceptionRuleItem extends ConsumerStatefulWidget {
  final ProxyRule rule;
  final VoidCallback onDelete;
  final ValueChanged<ProxyRule> onUpdate;

  const _InterceptionRuleItem({
    super.key,
    required this.rule,
    required this.onDelete,
    required this.onUpdate,
  });

  @override
  ConsumerState<_InterceptionRuleItem> createState() =>
      _InterceptionRuleItemState();
}

class _InterceptionRuleItemState extends ConsumerState<_InterceptionRuleItem> {
  bool _isExpanded = false;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.rule.name ?? '');

    // Initialize provider with current filter
    // We defer this to the first time we need it or lazily?
    // If we defer, the provider might be empty.
    // We should initialize it now.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FilterNode? initialFilter;
      if (widget.rule.metadata != null &&
          widget.rule.metadata!.containsKey('uiFilter')) {
        final json = widget.rule.metadata!['uiFilter'];
        try {
          if (json['type'] == 'group') {
            initialFilter = FilterGroup.fromJson(json);
          } else {
            initialFilter = FilterCondition.fromJson(json); // or wrap in group
          }
        } catch (e) {
          // Error parsing uiFilter
        }
      }

      if (initialFilter != null) {
        if (initialFilter is FilterCondition) {
          // Ensure root is Group for widget compatibility
          ref
              .read(filterManagerFamilyProvider(widget.rule.id).notifier)
              .setRoot(FilterGroup(children: [initialFilter]));
        } else {
          ref
              .read(filterManagerFamilyProvider(widget.rule.id).notifier)
              .setRoot(initialFilter as FilterGroup);
        }
        // Also update the server matcher immediately in case it wasn't set?
        // No, don't override existing matcher unless user edits.
      } else {
        ref.read(filterManagerFamilyProvider(widget.rule.id).notifier).reset();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch filter changes to update local rule object
    ref.listen(filterManagerFamilyProvider(widget.rule.id), (previous, next) {
      // Update ui state in metadata
      if (widget.rule.metadata == null) widget.rule.metadata = {};
      widget.rule.metadata!['uiFilter'] = next.rootFilter.toJson();

      // Update derived matcher
      widget.rule.matcher = FilterConvert.toRequestMatcher(next.rootFilter);

      widget.onUpdate(widget.rule);
    });

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 6,
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: widget.rule.enabled,
                    onChanged: (val) {
                      setState(() {
                        widget.rule.enabled = val ?? true;
                      });
                      widget.onUpdate(widget.rule);
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.rule.name ?? 'Unnamed Rule',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: const SuryaThemeIcon(BulkRounded.delete01),
                    onPressed: widget.onDelete,
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                  ),
                ],
              ),
            ),
          ),
          // Body (Accordion)
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  // Name Field
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Rule Name'),
                    onChanged: (val) {
                      widget.rule.name = val;
                      widget.onUpdate(widget.rule);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Filter Section
                  const Text(
                    'Matching Conditions',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Consumer(
                    builder: (context, ref, _) {
                      final filterState = ref.watch(
                        filterManagerFamilyProvider(widget.rule.id),
                      );
                      return FilterGroupWidget(
                        index: 0,
                        group: filterState.rootFilter,
                        managerProvider: filterManagerFamilyProvider(
                          widget.rule.id,
                        ),
                        isRoot: true,
                        // Ensure layout constraints or scrolling if needed
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Action Section
                  const SizedBox(height: 8),
                  ActionEditor(
                    config: widget.rule.action,
                    onChanged: (newConfig) {
                      widget.rule.action = newConfig;
                      widget.onUpdate(widget.rule);
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

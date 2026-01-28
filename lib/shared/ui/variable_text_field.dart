// import 'dart:math';

// import 'package:api_craft/core/providers/filter_provider.dart';
// import 'package:api_craft/core/widgets/ui/filter.dart';
// import 'package:api_craft/core/widgets/ui/key_valu_text_builder.dart';
// import 'package:api_craft/core/widgets/ui/variable_text_builder.dart';
// import 'package:api_craft/features/environment/environment_editor_dialog.dart';
// import 'package:api_craft/features/environment/environment_provider.dart';
// import 'package:api_craft/features/request/providers/req_compose_provider.dart';
// import 'package:api_craft/features/sidebar/context_menu.dart';
// import 'package:api_craft/features/template-functions/models/template_placeholder_model.dart';
// import 'package:api_craft/features/template-functions/parsers/parse.dart';
// import 'package:api_craft/features/template-functions/parsers/utils.dart';
// import 'package:api_craft/features/template-functions/widget/form_popup_widget.dart';
// import 'package:extended_text_field/extended_text_field.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// class VariableTextFieldX extends ConsumerStatefulWidget {
//   final String? initialValue;
//   // null id for global variables.
//   final String? id;
//   final TextEditingController? controller;
//   final ValueChanged<String>? onChanged;
//   final ValueChanged<String>? onSubmitted;
//   final FocusNode? focusNode;
//   final InputDecoration? decoration;
//   final String? placeHolder;
//   final KeyEventResult Function(FocusNode, KeyEvent)? onKeyEvent;
//   final bool enableUrlSuggestions;
//   final bool enableSuggestions;
//   final int? maxLines;
//   final int? minLines;
//   final bool isKeyVal;
//   const VariableTextFieldX({
//     super.key,
//     this.initialValue,
//     this.controller,
//     this.onChanged,
//     this.focusNode,
//     required this.id,
//     this.decoration,
//     this.placeHolder,
//     this.onKeyEvent,
//     this.onSubmitted,
//     this.enableSuggestions = true,
//     this.enableUrlSuggestions = false,
//     this.maxLines = 1,
//     this.minLines,
//     this.isKeyVal = false,
//   });

//   @override
//   ConsumerState<VariableTextFieldX> createState() => _VariableTextFieldXState();
// }

// class _VariableTextFieldXState extends ConsumerState<VariableTextFieldX> {
//   late final TextEditingController _controller =
//       widget.controller ?? TextEditingController(text: widget.initialValue);
//   final FocusNode _focusNode = FocusNode();
//   late SpecialTextSpanBuilder _variableBuilder;
//   int latestCursorPos = 0;
//   final fontSize = 16.0;

//   @override
//   void initState() {
//     super.initState();

//     if (widget.isKeyVal) {
//       _variableBuilder = KeyValueTextBuilder(
//         builderOnTap: handleVariableTap,
//         builderTextStyle: TextStyle(
//           fontWeight: FontWeight.bold,
//           fontSize: fontSize,
//           color: const Color.fromARGB(255, 254, 145, 223),
//           backgroundColor: const Color.fromARGB(68, 63, 21, 63),
//         ),
//       );
//     } else {
//       _variableBuilder = VariableTextBuilder(
//         builderOnTap: handleVariableTap,
//         builderTextStyle: TextStyle(
//           fontWeight: FontWeight.bold,
//           fontSize: fontSize,
//           color: const Color.fromARGB(255, 254, 145, 223),
//           backgroundColor: const Color.fromARGB(68, 63, 21, 63),
//         ),
//       );
//     }
//   }

//   void handleVariableTap({
//     required bool isVariable,
//     required String name,
//     required String rawContent,
//     required int from,
//     required int to,
//   }) {
//     debugPrint("Variable clicked in UI: $name");

//     if (isVariable) {
//       final (variable, source) = getVariable(name);
//       final isGlobalEnv = widget.id == null;
//       /*
//       source null means the variable is global variable
//       widget.id null means the text field is from keyvalue editor of global environment
//       */

//       if (variable != null) {
//         debugPrint("Variable source ID: $source, value: $variable");
//         if (source == null) {
//           if (isGlobalEnv) {
//             return;
//           }
//           showDialog(
//             context: context,
//             builder: (_) => const EnvironmentEditorDialog(),
//           );
//         }
//         if (source == "global-env") {
//           showDialog(
//             context: context,
//             builder: (_) => const EnvironmentEditorDialog(globalActive: true),
//           );
//         } else if (source == "sub-env") {
//           showDialog(
//             context: context,
//             builder: (_) => const EnvironmentEditorDialog(),
//           );
//         } else {
//           showFolderConfigDialog(
//             context: context,
//             ref: ref,
//             id: source!,
//             tabIndex: 3,
//           );
//         }
//       } else {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text('variable: $name not found')));
//       }
//     } else {
//       // function
//       debugPrint("Function clicked in UI: $name,from: $from, to: $to");
//       final templateFn = getTemplateFunctionByName(name);
//       if (templateFn == null) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text('function: $name not found')));
//         return;
//       }
//       final fnPlaceholder =
//           TemplateParser.parseContent(rawContent, start: from, end: to)
//               as TemplateFnPlaceholder;
//       showDialog(
//         context: context,
//         builder: (context) => FormPopupWidget(
//           fnPlaceholder: fnPlaceholder,
//           templateFn: templateFn,
//           id: widget.id,
//           updateField: updateField,
//         ),
//       );
//     }
//   }

//   (String? variable, String? source) getVariable(String name) {
//     if (widget.id != null) {
//       final x = ref.read(reqComposeProvider(widget.id!)).allVariables[name];
//       return (x?.value, x?.sourceId);
//     }
//     final x = ref
//         .read(environmentProvider)
//         .selectedEnvironment
//         ?.variables
//         .firstWhere((e) => e.key == name);
//     return (x?.value, null);
//   }

//   String displayStringForOption(FillOptions option) {
//     final (text, cursorPos) = FilterService.onOptionPick(
//       _controller.text,
//       option,
//     );
//     latestCursorPos = cursorPos;
//     return text;
//   }

//   void moveToCursorPosition() {
//     _controller.selection = TextSelection.fromPosition(
//       TextPosition(offset: latestCursorPos),
//     );
//   }

//   FilterService get _filterService {
//     return ref.read(filterServiceProvider(widget.id));
//   }

//   void updateField(String Function(String val) fn) {
//     final val = fn(widget.controller?.text ?? '');
//     debugPrint("updated-field value: $val");
//     _controller.text = val;
//     widget.onChanged?.call(val);
//   }

//   Widget optionsViewBuilder(
//     BuildContext context,
//     AutocompleteOnSelected<FillOptions> onSelected,
//     Iterable<FillOptions> options,
//   ) {
//     final int count = options.length;

//     final double height = min(
//       (count * 40) + // item height
//           ((count - 1).clamp(0, count) * 4) + // separators
//           8 + // ListView padding (4 top + 4 bottom)
//           2, // ✅ Container border (1 + 1)
//       200.0,
//     );
//     return Align(
//       alignment: Alignment.topLeft,
//       child: Material(
//         elevation: 8.0,
//         borderRadius: BorderRadius.circular(8),
//         child: Container(
//           width: 320,
//           height: height,
//           constraints: const BoxConstraints(maxWidth: 400),
//           decoration: BoxDecoration(
//             border: Border.all(color: const Color.fromARGB(255, 49, 49, 49)),
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: ListView.separated(
//             padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
//             itemCount: options.length,
//             separatorBuilder: (context, index) => const SizedBox(height: 4),
//             itemBuilder: (BuildContext context, int index) {
//               final FillOptions option = options.elementAt(index);

//               // 1. Get the currently highlighted index from Autocomplete's internal state
//               final int highlightedIndex = AutocompleteHighlightedOption.of(
//                 context,
//               );

//               // 2. Check if this specific tile is the one selected by keyboard or default
//               // Highlighting index 0 by default if highlightedIndex is 0 (standard behavior)
//               final bool isHighlighted = highlightedIndex == index;

//               return _buildOptionTile(option, onSelected, isHighlighted);
//             },
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildOptionTile(
//     FillOptions option,
//     AutocompleteOnSelected<FillOptions> onSelected,
//     bool isHighlighted,
//   ) {
//     return Container(
//       height: 40,
//       decoration: BoxDecoration(
//         color: isHighlighted ? const Color(0xFF242424) : null,
//         borderRadius: BorderRadius.circular(4),
//       ),
//       child: InkWell(
//         canRequestFocus: false,
//         // onTap: () => onSelected(option),
//         onTap: () {
//           onSelected(option);
//           Future.delayed(Duration(milliseconds: 800), () {
//             _focusNode.requestFocus();
//           });
//         },
//         borderRadius: BorderRadius.circular(4),
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//           child: Row(
//             children: [
//               // Icon based on type
//               // Container(
//               //   width: 26,
//               //   height: 26,
//               //   decoration: BoxDecoration(
//               //     color: _getTypeColor(
//               //       option.type,
//               //     ).withValues(alpha: isHighlighted ? 0.2 : 0.1),
//               //     borderRadius: BorderRadius.circular(6),
//               //   ),
//               //   child:
//               // ),
//               Icon(
//                 _getTypeIcon(option.type),
//                 size: 18,
//                 color: _getTypeColor(option.type),
//               ),
//               const SizedBox(width: 12),
//               Expanded(child: _buildHighlightedText(option, isHighlighted)),
//               // Badge
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//                 decoration: BoxDecoration(
//                   color: _getTypeColor(option.type).withValues(alpha: 0.1),
//                   borderRadius: BorderRadius.circular(4),
//                 ),
//                 child: Text(
//                   option.type,
//                   style: TextStyle(
//                     fontSize: 10,
//                     fontWeight: FontWeight.w600,
//                     color: _getTypeColor(option.type),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildHighlightedText(FillOptions option, bool isHighlighted) {
//     final baseColor = isHighlighted ? Colors.white : null;

//     if (option.fuzzyMatch == null) {
//       return Text(
//         option.label,
//         style: TextStyle(fontSize: 14, color: baseColor),
//       );
//     }

//     final match = option.fuzzyMatch!;
//     final spans = <TextSpan>[];

//     for (int i = 0; i < match.text.length; i++) {
//       final isMatched = match.matchedIndices.contains(i);
//       spans.add(
//         TextSpan(
//           text: match.text[i],
//           style: TextStyle(
//             fontSize: 14,
//             fontWeight: isMatched ? FontWeight.bold : FontWeight.normal,
//             // If the row is highlighted, make the non-matched text white, keep matched text blue
//             color: isMatched ? const Color(0xFF57ABFF) : baseColor,
//           ),
//         ),
//       );
//     }

//     return RichText(text: TextSpan(children: spans));
//   }

//   IconData _getTypeIcon(String type) {
//     switch (type) {
//       case 'url':
//         return Icons.link;
//       case 'variable':
//         return Icons.data_object;
//       case 'function':
//         return Icons.functions;
//       default:
//         return Icons.text_fields;
//     }
//   }

//   Color _getTypeColor(String type) {
//     switch (type) {
//       case 'url':
//         return Colors.blue;
//       case 'variable':
//         return Colors.green;
//       case 'function':
//         return Colors.purple;
//       default:
//         return Colors.grey;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Autocomplete<FillOptions>(
//       focusNode: _focusNode,
//       textEditingController: _controller,
//       optionsBuilder: _filterService.getOptions,
//       displayStringForOption: displayStringForOption,
//       optionsViewBuilder: optionsViewBuilder,
//       fieldViewBuilder:
//           (context, textEditingController, focusNode, onFieldSubmitted) {
//             return ExtendedTextField(
//               controller: textEditingController,
//               focusNode: focusNode,
//               specialTextSpanBuilder: _variableBuilder,
//               style: TextStyle(fontSize: fontSize, height: 1.4),
//               autofillHints: const [AutofillHints.url],
//               // Ensure onSubmitted calls the autocomplete logic if needed,
//               // though Autocomplete handles Enter key internally when an option is highlighted.
//               onSubmitted: (value) {
//                 onFieldSubmitted();
//                 moveToCursorPosition();
//                 focusNode.requestFocus();
//               },
//               onChanged: (v) {
//                 widget.onChanged?.call(v);
//               },
//               canRequestFocus: true,
//               autofocus: true,
//               maxLines: widget.isKeyVal ? null : widget.maxLines,
//               minLines: widget.isKeyVal ? null : widget.minLines,
//               textAlignVertical: TextAlignVertical.top,

//               expands: widget.isKeyVal,
//               decoration: const InputDecoration(
//                 border: OutlineInputBorder(),
//                 isDense: true,
//                 contentPadding: EdgeInsets.symmetric(
//                   horizontal: 8.0,
//                   vertical: 10.0,
//                 ),
//                 hintText: 'Try typing {{baseUrl}}/users or just "base"...',
//               ),
//             );
//           },
//     );
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     _focusNode.dispose();
//     super.dispose();
//   }
// }

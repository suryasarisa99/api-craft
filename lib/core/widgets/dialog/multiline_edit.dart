import 'package:flutter/material.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';

class MultilineEditDialog extends StatefulWidget {
  final String initialValue;
  const MultilineEditDialog({super.key, this.initialValue = ""});

  @override
  State<MultilineEditDialog> createState() => _MultilineEditDialogState();
}

class _MultilineEditDialogState extends State<MultilineEditDialog> {
  late final TextEditingController _controller;
  late LinkedScrollControllerGroup _controllers;
  late ScrollController _numbersScroll;
  late ScrollController _textScroll;

  // Define a consistent text style for both Input and Line Numbers logic
  // to ensure measurements match exactly.
  final TextStyle _textStyle = const TextStyle(
    fontSize: 16,
    height: 1.5, // Important for consistent line height
  );

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _controllers = LinkedScrollControllerGroup();
    _numbersScroll = _controllers.addAndGet();
    _textScroll = _controllers.addAndGet();
  }

  @override
  void dispose() {
    _controller.dispose();
    _numbersScroll.dispose();
    _textScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: SizedBox(
        width: 650,
        height: 400,
        child: Padding(
          padding: const EdgeInsets.only(
            left: 8,
            top: 8,
            bottom: 10,
            right: 10,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: .zero,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const .only(left: 18.0, top: 6),
                      child: Text(
                        "Edit",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: Icon(Icons.close, size: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 1. FIX: Expanded ensures this Row takes remaining space, preventing overflow
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    // border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // We need to know the width of the text input area
                      // to calculate where lines wrap.
                      // 40 is the width reserved for line numbers below.
                      final textInputMaxWidth = constraints.maxWidth - 85;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Line Numbers Column
                          SizedBox(
                            width: 40,
                            child: TextLinesColumn(
                              controller: _controller,
                              scrollController: _numbersScroll,
                              textStyle: _textStyle,
                              maxWidth: textInputMaxWidth,
                            ),
                          ),

                          // Text Input
                          Expanded(
                            child: TextFormField(
                              controller: _controller,
                              scrollController: _textScroll,
                              style: _textStyle,
                              expands: true,
                              maxLines: null,
                              textAlignVertical: TextAlignVertical.top,
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.all(4),
                                border: InputBorder.none,
                                isDense: true,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 15, bottom: 15),
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(context, _controller.text);
                      },
                      child: const Text("Done"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TextLinesColumn extends StatefulWidget {
  final TextEditingController controller;
  final ScrollController? scrollController;
  final TextStyle textStyle;
  final double maxWidth;

  const TextLinesColumn({
    super.key,
    required this.controller,
    required this.textStyle,
    required this.maxWidth,
    this.scrollController,
  });

  @override
  State<TextLinesColumn> createState() => _TextLinesColumnState();
}

class _TextLinesColumnState extends State<TextLinesColumn> {
  // We store the split lines to iterate over them
  List<String> _lines = [];
  late int _currLine = 0;

  @override
  void initState() {
    super.initState();
    _lines = widget.controller.text.split('\n');
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TextLinesColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.maxWidth != widget.maxWidth) {
      // If window resized, re-calculate
      setState(() {});
    }
  }

  void _onTextChanged() {
    // Only rebuild if the content structure actually changed
    final newLines = widget.controller.text.split('\n');
    final currLine = getCurrentLine();
    if (newLines.length != _lines.length ||
        widget.controller.text != newLines.join('\n') ||
        _currLine != currLine) {
      setState(() {
        _lines = newLines;
        _currLine = currLine;
      });
    }
  }

  /// Calculates the visual height of a specific line of text
  /// based on the available width in the text field.
  double _calculateLineHeight(String lineText) {
    final span = TextSpan(
      text: lineText.isEmpty ? ' ' : lineText,
      style: widget.textStyle,
    );
    final tp = TextPainter(text: span, textDirection: TextDirection.ltr);

    // We adjust maxWidth slightly to account for the input's padding
    tp.layout(maxWidth: widget.maxWidth - 8); // -8 for input decoration padding

    // Return the height, ensuring at least one line height exists
    return tp.height == 0 ? tp.preferredLineHeight : tp.height;
  }

  int getCurrentLine() {
    final lines = widget.controller.text.split('\n');
    final pos = widget.controller.selection.baseOffset;
    int count = 0;
    int currLine = 0;

    for (final line in lines) {
      final lineLength = line.length + 1; // +1 for the newline character
      if (pos <= count + lineLength - 1) {
        return currLine;
      }
      count += lineLength;
      currLine++;
    }
    return currLine;
  }

  // @override
  // Widget build(BuildContext context) {
  //   return ScrollConfiguration(
  //     behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
  //     child: SingleChildScrollView(
  //       controller: widget.scrollController,
  //       physics: const ClampingScrollPhysics(),
  //       child: Padding(
  //         padding: const EdgeInsets.symmetric(vertical: 0.0),
  //         child: Column(
  //           children: [
  //             for (int i = 0; i < _lines.length; i++)
  //               Container(
  //                 alignment: Alignment.center,
  //                 height: _calculateLineHeight(_lines[i]),
  //                 width: double.infinity,
  //                 child: Text(
  //                   "${i + 1}",
  //                   style: TextStyle(
  //                     color: _currLine == i ? Colors.blue : Colors.grey,
  //                     fontSize: 12,
  //                   ),
  //                 ),
  //               ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView.builder(
        controller: widget.scrollController,
        itemBuilder: (context, index) {
          if (index >= _lines.length) return null;
          return Container(
            alignment: Alignment.center,
            height: _calculateLineHeight(_lines[index]),
            width: double.infinity,
            child: Text(
              "${index + 1}",
              style: TextStyle(
                color: _currLine == index ? Colors.blue : Colors.grey,
                fontSize: 12,
              ),
            ),
          );
        },
      ),
    );
  }
}

// class TextLinesColumn extends StatefulWidget {
//   final TextEditingController controller;
//   final ScrollController? scrollController;
//   final TextStyle textStyle;
//   final double maxWidth;

//   const TextLinesColumn({
//     super.key,
//     required this.controller,
//     required this.textStyle,
//     required this.maxWidth,
//     this.scrollController,
//   });

//   @override
//   State<TextLinesColumn> createState() => _TextLinesColumnState();
// }

// class _TextLinesColumnState extends State<TextLinesColumn> {
//   @override
//   void initState() {
//     super.initState();
//     // Listen to changes to trigger a repaint
//     widget.controller.addListener(_handleTextChange);
//   }

//   @override
//   void dispose() {
//     widget.controller.removeListener(_handleTextChange);
//     super.dispose();
//   }

//   void _handleTextChange() {
//     setState(() {});
//   }

//   @override
//   Widget build(BuildContext context) {
//     // 1. Setup the TextPainter with the full text.
//     // We do this in build to calculate the total height needed for scrolling.
//     final span = TextSpan(
//       text: widget.controller.text,
//       style: widget.textStyle,
//     );

//     final textPainter = TextPainter(
//       text: span,
//       textDirection: TextDirection.ltr,
//     );

//     // 2. Layout exactly as the TextField does.
//     // -8 accounts for the EdgeInsets.all(4) padding you have in InputDecoration
//     textPainter.layout(maxWidth: widget.maxWidth - 8);

//     // 3. Calculate total height (plus vertical padding matching the Input)
//     final double totalHeight =
//         textPainter.height + 8; // +8 for top/bottom padding

//     return ScrollConfiguration(
//       behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
//       child: SingleChildScrollView(
//         controller: widget.scrollController,
//         child: CustomPaint(
//           size: Size(double.infinity, totalHeight),
//           painter: LineNumberPainter(
//             text: widget.controller.text,
//             textPainter: textPainter,
//             style: widget.textStyle,
//             // Pass the current selection to highlight the active line
//             selection: widget.controller.selection,
//           ),
//         ),
//       ),
//     );
//   }
// }

// class LineNumberPainter extends CustomPainter {
//   final String text;
//   final TextPainter textPainter;
//   final TextStyle style;
//   final TextSelection selection;

//   LineNumberPainter({
//     required this.text,
//     required this.textPainter,
//     required this.style,
//     required this.selection,
//   });

//   @override
//   void paint(Canvas canvas, Size size) {
//     // The Input has EdgeInsets.all(4), so we start drawing at y=4
//     const double verticalPadding = 4.0;

//     // We manually calculate where the newlines are to draw numbers
//     int lineNumber = 1;
//     int currentIndex = 0;

//     // Helper to draw a number at a specific Y offset
//     void drawLineNumber(int index, int number) {
//       // Ask the text engine: "Where is the character at this index visually?"
//       final offset = textPainter.getOffsetForCaret(
//         TextPosition(offset: index),
//         Rect.zero,
//       );

//       final yPosition = offset.dy + verticalPadding;

//       // (Optional) simple active line highlight logic
//       // Check if this line range includes the selection
//       // This is a basic check; for wrapped lines, it highlights the start of the logical line.

//       final numberText = TextSpan(
//         text: "$number",
//         style: style.copyWith(
//           color: Colors.grey,
//           fontSize: 12,
//           // Ensure line height doesn't mess up centering relative to text
//           height: style.height,
//         ),
//       );

//       final numberPainter = TextPainter(
//         text: numberText,
//         textAlign: TextAlign.center,
//         textDirection: TextDirection.ltr,
//       );

//       numberPainter.layout(maxWidth: size.width);

//       // Center the number horizontally in the gutter
//       numberPainter.paint(
//         canvas,
//         Offset((size.width - numberPainter.width) / 2, yPosition),
//       );
//     }

//     // 1. Draw line 1 always
//     drawLineNumber(0, 1);

//     // 2. Find all newlines and draw the next number after them
//     while (true) {
//       final nextNewline = text.indexOf('\n', currentIndex);
//       if (nextNewline == -1) break;

//       lineNumber++;
//       currentIndex = nextNewline + 1;

//       // If the text ends with a newline, we must draw the number for the new empty line
//       if (currentIndex <= text.length) {
//         drawLineNumber(currentIndex, lineNumber);
//       }
//     }
//   }

//   @override
//   bool shouldRepaint(covariant LineNumberPainter oldDelegate) {
//     return oldDelegate.text != text || oldDelegate.selection != selection;
//   }
// }

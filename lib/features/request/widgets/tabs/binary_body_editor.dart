import 'package:api_craft/core/providers/providers.dart';

import 'package:api_craft/core/models/models.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:dotted_decoration/dotted_decoration.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';

class BinaryBodyEditor extends ConsumerStatefulWidget {
  final String id;
  const BinaryBodyEditor({super.key, required this.id});

  @override
  ConsumerState<BinaryBodyEditor> createState() => _BinaryBodyEditorState();
}

class _BinaryBodyEditorState extends ConsumerState<BinaryBodyEditor> {
  String? _ignoredMimeType;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final (bodyData, currHeaders, inheritedHeaders) = ref.watch(
      reqComposeProvider(widget.id).select(
        (s) => (
          s.bodyData,
          (s.node as RequestNode).config.headers,
          s.inheritedHeaders,
        ),
      ),
    );
    final filePath = bodyData['file'] as String?;
    List<KeyValueItem> headers = [...currHeaders, ...inheritedHeaders];

    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = _isDragging
        ? colorScheme.primary
        : colorScheme.outlineVariant;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: DottedDecoration(
                  borderRadius: BorderRadius.circular(8),
                  shape: Shape.box,
                  color: borderColor,
                ),
                child: DropTarget(
                  onDragEntered: (_) => setState(() => _isDragging = true),
                  onDragExited: (_) => setState(() => _isDragging = false),
                  onDragDone: (details) {
                    setState(() => _isDragging = false);
                    if (details.files.isNotEmpty) {
                      ref
                          .read(reqComposeProvider(widget.id).notifier)
                          .updateBodyFile(details.files.first.path);
                      setState(() {
                        _ignoredMimeType = null;
                      });
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        style: BorderStyle.none,
                      ),
                      color: _isDragging
                          ? colorScheme.primaryContainer.withOpacity(0.1)
                          : colorScheme.surfaceContainerHighest.withOpacity(
                              0.3,
                            ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (filePath != null && filePath.isNotEmpty) ...[
                              _buildSelectedFile(context, ref, filePath),
                              const SizedBox(height: 16),
                              _buildRecommendation(
                                context,
                                ref,
                                filePath,
                                headers,
                              ),
                              const SizedBox(height: 24),
                            ],
                            ElevatedButton.icon(
                              onPressed: () async {
                                final result = await FilePicker.platform
                                    .pickFiles();
                                if (result != null &&
                                    result.files.single.path != null) {
                                  ref
                                      .read(
                                        reqComposeProvider(widget.id).notifier,
                                      )
                                      .updateBodyFile(
                                        result.files.single.path!,
                                      );
                                  setState(() {
                                    _ignoredMimeType = null; // Reset ignore
                                  });
                                }
                              },
                              icon: Icon(
                                Icons.upload_file,
                                size: 22,
                                color: colorScheme.secondary,
                              ),
                              label: Text(
                                filePath != null && filePath.isNotEmpty
                                    ? "Change file"
                                    : "Select a file",
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "or drag and drop here",
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedFile(BuildContext context, WidgetRef ref, String path) {
    // Extract filename from path
    final fileName = path.split(RegExp(r'[/\\]')).last;

    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.description, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              fileName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () {
              ref
                  .read(reqComposeProvider(widget.id).notifier)
                  .updateBodyFile('');
              setState(() {
                _ignoredMimeType = null;
              });
            },
            tooltip: "Remove file",
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendation(
    BuildContext context,
    WidgetRef ref,
    String path,
    List<KeyValueItem> headers,
  ) {
    final mimeType = lookupMimeType(path);
    if (mimeType == null) return const SizedBox.shrink();

    if (_ignoredMimeType == mimeType) return const SizedBox.shrink();

    // Check if Content-Type is already set to this mime type
    final hasHeader = headers.any(
      (h) =>
          h.key.toLowerCase() == 'content-type' &&
          h.value.toLowerCase().contains(mimeType.toLowerCase()) &&
          h.isEnabled,
    );

    if (hasHeader) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Recommended Header",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Set Content-Type header to '$mimeType'.",
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: .min,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _ignoredMimeType = mimeType;
                      });
                    },
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 0,
                      ),
                    ),
                    child: const Text("Ignore"),
                  ),
                  const SizedBox(width: 8),

                  FilledButton.tonal(
                    onPressed: () {
                      // Start logic to set header
                      // We need to add or update Content-Type
                      final currentHeaders = ref
                          .read(reqComposeProvider(widget.id))
                          .node
                          .config
                          .headers;
                      // Copy existing
                      final newHeaders = List<KeyValueItem>.from(
                        currentHeaders,
                      );

                      final index = newHeaders.indexWhere(
                        (h) => h.key.toLowerCase() == 'content-type',
                      );
                      if (index >= 0) {
                        newHeaders[index] = newHeaders[index].copyWith(
                          value: mimeType,
                          isEnabled: true,
                        );
                      } else {
                        newHeaders.add(
                          KeyValueItem(
                            key: 'Content-Type',
                            value: mimeType,
                            isEnabled: true,
                          ),
                        );
                      }

                      ref
                          .read(reqComposeProvider(widget.id).notifier)
                          .updateHeaders(newHeaders);
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 0,
                      ),
                    ),
                    child: const Text("Set Header"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

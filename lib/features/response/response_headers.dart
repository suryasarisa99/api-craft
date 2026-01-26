import 'package:api_craft/core/widgets/ui/key_value_view.dart';
import 'package:api_craft/features/request/providers/req_compose_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ResponseHeaders extends ConsumerWidget {
  final String id;
  const ResponseHeaders({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final response = ref.watch(
      reqComposeProvider(id).select((d) => d.history?.firstOrNull),
    );

    if (response == null) {
      return const Center(child: Text("No response data"));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Request Headers (Collapsed by default)
          if (response.reqHeaders != null && response.reqHeaders!.isNotEmpty)
            _SimpleAccordion(
              title: "Request Headers",
              count: response.reqHeaders!.length,
              initiallyExpanded: false,
              child: KeyValueView(
                items: response.reqHeaders!,
                pairSeparator: ': ',
                itemSeparator: '\n',
                padding: EdgeInsets.zero,
                keyStyle: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.primary,
                ),
                valueStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),

          const SizedBox(height: 8),

          // Response Headers
          _SimpleAccordion(
            title: "Response Headers",
            count: response.headers.length,
            initiallyExpanded: true,
            child: KeyValueView(
              items: response.headers,
              pairSeparator: ': ',
              itemSeparator: '\n',
              padding: EdgeInsets.zero,
              keyStyle: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.primary,
              ),
              valueStyle: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleAccordion extends StatefulWidget {
  final String title;
  final int count;
  final bool initiallyExpanded;
  final Widget child;

  const _SimpleAccordion({
    required this.title,
    required this.count,
    required this.initiallyExpanded,
    required this.child,
  });

  @override
  State<_SimpleAccordion> createState() => _SimpleAccordionState();
}

class _SimpleAccordionState extends State<_SimpleAccordion> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.arrow_drop_down : Icons.arrow_right,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  ": ${widget.count}",
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF848484),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: widget.child,
          ),
      ],
    );
  }
}

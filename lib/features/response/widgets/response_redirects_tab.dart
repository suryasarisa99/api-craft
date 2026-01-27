import 'package:api_craft/core/widgets/ui/key_value_view.dart';
import 'package:api_craft/features/response/models/response_history.dart';
import 'package:flutter/material.dart';
import 'package:api_craft/core/utils/formatters.dart';

class ResponseRedirectsTab extends StatelessWidget {
  final ResponseHistory response;

  const ResponseRedirectsTab({super.key, required this.response});

  @override
  Widget build(BuildContext context) {
    if (response.redirects.isEmpty) {
      return const Center(child: Text("No Redirects"));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: response.redirects.length,
      separatorBuilder: (c, i) => const Divider(),
      itemBuilder: (context, index) {
        final step = response.redirects[index];
        return _RedirectItem(step: step, index: index + 1);
      },
    );
  }
}

class _RedirectItem extends StatefulWidget {
  final RedirectStep step;
  final int index;

  const _RedirectItem({required this.step, required this.index});

  @override
  State<_RedirectItem> createState() => _RedirectItemState();
}

class _RedirectItemState extends State<_RedirectItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: Row(
              children: [
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_right_rounded,
                  size: 20,
                  color: Colors.grey,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "#${widget.index}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "${widget.step.method} ${widget.step.statusCode}",
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Text(
                  formatDuration(widget.step.durationMs),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 36, right: 16, bottom: 8),
          child: SelectableText(
            widget.step.url,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        ),

        if (_isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                _buildHeaderSection(
                  "Request Headers",
                  widget.step.reqHeaders,
                  theme,
                ),
                const SizedBox(height: 16),
                _buildHeaderSection(
                  "Response Headers",
                  widget.step.resHeaders,
                  theme,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHeaderSection(
    String title,
    List<List<String>> headers,
    ThemeData theme,
  ) {
    if (headers.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        KeyValueView(
          items: headers,
          pairSeparator: ': ',
          itemSeparator: '\n',
          keyStyle: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.primary,
            fontFamily: 'monospace',
          ),
          valueStyle: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
        ),
      ],
    );
  }
}

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withOpacity(0.1),
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
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(widget.step.statusCode),
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
                _buildHeaderSection("Request Headers", widget.step.reqHeaders),
                const SizedBox(height: 16),
                _buildHeaderSection("Response Headers", widget.step.resHeaders),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHeaderSection(String title, List<List<String>> headers) {
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
        ...headers.map(
          (h) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: SelectableText(
                    "${h[0]}:",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blueGrey,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                Expanded(
                  child: SelectableText(
                    h.length > 1 ? h[1] : '',
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(int status) {
    if (status >= 200 && status < 300) return Colors.green;
    if (status >= 300 && status < 400) return Colors.orange;
    if (status >= 400 && status < 500) return Colors.red;
    if (status >= 500) return Colors.red[800]!;
    return Colors.grey;
  }
}

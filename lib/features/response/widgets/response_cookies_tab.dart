import 'dart:io';
import 'package:api_craft/core/models/cookie_jar_model.dart';
import 'package:api_craft/core/widgets/ui/key_value_view.dart';
import 'package:api_craft/features/request/providers/req_compose_provider.dart';
import 'package:extended_text/extended_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ResponseCookiesTab extends ConsumerWidget {
  final String id;
  const ResponseCookiesTab({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final response = ref.watch(
      reqComposeProvider(id).select((d) => d.history?.firstOrNull),
    );

    if (response == null) {
      return const Center(child: Text("No response data"));
    }

    // Prepare data
    final reqCookies = response.reqCookies;
    final resCookies = response.resCookies;

    // Helper to format Date
    String fmtDate(DateTime? dt) {
      if (dt == null) return "Session";
      return dt.toLocal().toString();
    }

    Widget buildReqCookiesList() {
      if (reqCookies.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(title: "Cookies Sent", count: reqCookies.length),
          KeyValueView(
            items: reqCookies,
            pairSeparator: '=',
            itemSeparator: '; ',
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
        ],
      );
    }

    Widget buildResCookiesList() {
      if (resCookies.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(title: "Cookies Received", count: resCookies.length),
          SetCookiesView(cookies: resCookies),
        ],
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          if (reqCookies.isEmpty && resCookies.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("No cookies found"),
            ),

          buildReqCookiesList(),
          const SizedBox(height: 16),
          buildResCookiesList(),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "$count",
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class SetCookiesView extends StatelessWidget {
  final List<CookieDef> cookies;
  const SetCookiesView({super.key, required this.cookies});

  @override
  Widget build(BuildContext context) {
    if (cookies.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SelectionArea(
        child: ExtendedText.rich(
          TextSpan(
            children: cookies.map((c) {
              // Reconstruct raw cookie string for copy
              final sb = StringBuffer();
              sb.write("${c.key}=${c.value}");
              if (c.domain.isNotEmpty) sb.write("; Domain=${c.domain}");
              if (c.path.isNotEmpty) sb.write("; Path=${c.path}");
              if (c.expires != null)
                sb.write("; Expires=${HttpDate.format(c.expires!)}");
              if (c.isHttpOnly) sb.write("; HttpOnly");
              if (c.isSecure) sb.write("; Secure");
              // if (c.isHostOnly)
              //   sb.write("; HostOnly"); // Internal flag, maybe skip?
              sb.write("\n"); // Newline separator

              return ExtendedWidgetSpan(
                actualText: sb.toString(),
                child: SelectionContainer.disabled(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).dividerColor.withOpacity(0.5),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name=Value
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${c.key}:",
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                c.value,
                                style: const TextStyle(fontFamily: 'monospace'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Attributes in a Wrap
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (c.domain.isNotEmpty)
                              _CookieAttr("Domain", c.domain),
                            if (c.path.isNotEmpty) _CookieAttr("Path", c.path),
                            if (c.expires != null)
                              _CookieAttr(
                                "Expires",
                                c.expires!.toLocal().toString(),
                              ),
                            if (c.isHttpOnly) const _CookieBadge("HttpOnly"),
                            if (c.isSecure) const _CookieBadge("Secure"),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _CookieAttr extends StatelessWidget {
  final String label;
  final String value;
  const _CookieAttr(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
          children: [
            TextSpan(
              text: "$label: ",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CookieBadge extends StatelessWidget {
  final String label;
  const _CookieBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 11,
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

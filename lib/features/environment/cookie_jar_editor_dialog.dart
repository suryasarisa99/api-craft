import 'package:api_craft/core/models/cookie_jar_model.dart';
import 'package:api_craft/core/widgets/ui/surya_theme_icon.dart';
import 'package:api_craft/features/environment/environment_provider.dart';
import 'package:api_craft/core/widgets/ui/custom_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suryaicons/bulk_rounded.dart';

class CookieJarEditorDialog extends ConsumerWidget {
  const CookieJarEditorDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(environmentProvider);
    final jar = state.selectedCookieJar;

    if (jar == null) {
      return const SizedBox.shrink();
    }
    const smallLabel = TextStyle(fontSize: 11);

    return CustomDialog(
      width: 1400,
      height: 800,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Manage Cookies - ${jar.name}",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (jar.cookies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 8),
              child: Row(
                children: [
                  Expanded(flex: 1, child: Text("Key")),
                  const SizedBox(width: 8),
                  Expanded(flex: 3, child: Text("Value")),
                  const SizedBox(width: 8),
                  Expanded(flex: 1, child: Text("Domain")),
                  const SizedBox(width: 8),
                  Expanded(flex: 1, child: Text("Path")),
                  const SizedBox(width: 4),
                  SizedBox(width: 40, child: Text("Secure", style: smallLabel)),
                  const SizedBox(width: 4),
                  SizedBox(width: 40, child: Text("Http", style: smallLabel)),
                  const SizedBox(width: 30),
                ],
              ),
            ),
          Expanded(
            child: jar.cookies.isEmpty
                ? const Center(child: Text("No cookies in this jar"))
                : ListView.builder(
                    itemCount: jar.cookies.length,
                    itemBuilder: (context, index) {
                      final cookie = jar.cookies[index];
                      return Padding(
                        key: ValueKey(cookie.id),
                        padding: const EdgeInsets.only(left: 8, bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                initialValue: cookie.key,
                                onChanged: (val) {
                                  _updateCookie(
                                    ref,
                                    jar,
                                    index,
                                    cookie.copyWith(key: val),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                initialValue: cookie.value,
                                onChanged: (val) {
                                  _updateCookie(
                                    ref,
                                    jar,
                                    index,
                                    cookie.copyWith(value: val),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                initialValue: cookie.domain,
                                onChanged: (val) {
                                  _updateCookie(
                                    ref,
                                    jar,
                                    index,
                                    cookie.copyWith(domain: val),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                initialValue: cookie.path,
                                onChanged: (val) {
                                  _updateCookie(
                                    ref,
                                    jar,
                                    index,
                                    cookie.copyWith(path: val),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 4),

                            SizedBox(
                              width: 40,
                              child: Checkbox(
                                value: cookie.isSecure,
                                onChanged: (val) {
                                  _updateCookie(
                                    ref,
                                    jar,
                                    index,
                                    cookie.copyWith(isSecure: val),
                                  );
                                },
                              ),
                            ),

                            const SizedBox(width: 4),

                            SizedBox(
                              width: 40,
                              child: Checkbox(
                                value: cookie.isHttpOnly,
                                onChanged: (val) {
                                  _updateCookie(
                                    ref,
                                    jar,
                                    index,
                                    cookie.copyWith(isHttpOnly: val),
                                  );
                                },
                              ),
                            ),
                            IconButton(
                              icon: const SuryaThemeIcon(
                                BulkRounded.removeCircle,
                              ),
                              onPressed: () {
                                _removeCookie(ref, jar, index);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: .end,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  _addCookie(ref, jar);
                },
                icon: const Icon(Icons.add),
                label: const Text("Add Cookie"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _updateCookie(
    WidgetRef ref,
    CookieJarModel jar,
    int index,
    CookieDef newCookie,
  ) {
    var newCookies = List<CookieDef>.from(jar.cookies);
    newCookies[index] = newCookie;
    ref
        .read(environmentProvider.notifier)
        .updateCookieJar(jar.copyWith(cookies: newCookies));
  }

  void _removeCookie(WidgetRef ref, CookieJarModel jar, int index) {
    var newCookies = List<CookieDef>.from(jar.cookies);
    newCookies.removeAt(index);
    ref
        .read(environmentProvider.notifier)
        .updateCookieJar(jar.copyWith(cookies: newCookies));
  }

  void _addCookie(WidgetRef ref, CookieJarModel jar) {
    var newCookies = List<CookieDef>.from(jar.cookies);
    newCookies.add(CookieDef(key: "", value: ""));
    ref
        .read(environmentProvider.notifier)
        .updateCookieJar(jar.copyWith(cookies: newCookies));
  }
}

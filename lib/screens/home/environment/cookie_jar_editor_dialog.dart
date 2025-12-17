import 'package:api_craft/models/cookie_jar_model.dart';
import 'package:api_craft/providers/environment_provider.dart';
import 'package:api_craft/widgets/ui/custom_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CookieJarEditorDialog extends ConsumerWidget {
  const CookieJarEditorDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(environmentProvider);
    final jar = state.selectedCookieJar;

    if (jar == null) {
      return const SizedBox.shrink();
    }

    return CustomDialog(
      width: 800,
      height: 600,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Manage Cookies - ${jar.name}",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: jar.cookies.isEmpty
                ? const Center(child: Text("No cookies in this jar"))
                : ListView.builder(
                    itemCount: jar.cookies.length,
                    itemBuilder: (context, index) {
                      final cookie = jar.cookies[index];
                      return Card(
                        color: Colors.white10,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: cookie.key,
                                      decoration: const InputDecoration(
                                        labelText: "Key",
                                        isDense: true,
                                      ),
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
                                      decoration: const InputDecoration(
                                        labelText: "Value",
                                        isDense: true,
                                      ),
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
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.redAccent,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      _removeCookie(ref, jar, index);
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: cookie.domain,
                                      decoration: const InputDecoration(
                                        labelText: "Domain",
                                        isDense: true,
                                      ),
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
                                    child: TextFormField(
                                      initialValue: cookie.path,
                                      decoration: const InputDecoration(
                                        labelText: "Path",
                                        isDense: true,
                                      ),
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
                                  const SizedBox(width: 8),
                                  FilterChip(
                                    label: const Text("Secure"),
                                    selected: cookie.isSecure,
                                    onSelected: (val) {
                                      _updateCookie(
                                        ref,
                                        jar,
                                        index,
                                        cookie.copyWith(isSecure: val),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  FilterChip(
                                    label: const Text("HttpOnly"),
                                    selected: cookie.isHttpOnly,
                                    onSelected: (val) {
                                      _updateCookie(
                                        ref,
                                        jar,
                                        index,
                                        cookie.copyWith(isHttpOnly: val),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              _addCookie(ref, jar);
            },
            icon: const Icon(Icons.add),
            label: const Text("Add Cookie"),
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
    ref.read(environmentProvider.notifier).saveCookiesToJar(jar.id, newCookies);
  }

  void _removeCookie(WidgetRef ref, CookieJarModel jar, int index) {
    var newCookies = List<CookieDef>.from(jar.cookies);
    newCookies.removeAt(index);
    ref.read(environmentProvider.notifier).saveCookiesToJar(jar.id, newCookies);
  }

  void _addCookie(WidgetRef ref, CookieJarModel jar) {
    var newCookies = List<CookieDef>.from(jar.cookies);
    newCookies.add(CookieDef(key: "", value: ""));
    ref.read(environmentProvider.notifier).saveCookiesToJar(jar.id, newCookies);
  }
}

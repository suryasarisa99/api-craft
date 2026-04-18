import 'package:api_craft/core/constants/globals.dart';
import 'package:api_craft/traffic/interceptors/intercept_widgets/android_widget.dart';
import 'package:api_craft/traffic/interceptors/intercept_widgets/draggable_resize_window.dart';
import 'package:api_craft/traffic/interceptors/models/interceptor_model.dart';
import 'package:api_craft/traffic/interceptors/sources/android/frida/frida_android_intercept.dart';
import 'package:flutter/material.dart';

class InterceptorBuilder extends StatefulWidget {
  final Interceptor interceptor;
  const InterceptorBuilder({super.key, required this.interceptor});

  @override
  State<InterceptorBuilder> createState() => _InterceptorBuilderState();
}

class _InterceptorBuilderState extends State<InterceptorBuilder> {
  late final options = widget.interceptor.getOptions();
  String? selectedOption;
  // late String? selectedOption = (options != null && options.isNotEmpty)
  //     ? options[0]
  //     : null;
  late final PreOptionsType preOptions = widget.interceptor.getPreOptions();

  @override
  void initState() {
    super.initState();
    options?.then((value) {
      if (mounted) {
        setState(() {
          if (value.isNotEmpty) {
            selectedOption = getValue(value[0]);
          }
        });
      }
    }).catchError((e) {
      debugPrint("Error initializing options for ${widget.interceptor.name}: $e");
    });
  }

  @override
  Widget build(BuildContext context) {
    return buildAsMenu();
  }

  String getValue(dynamic option) {
    if (option is String) {
      return option;
    }

    // else if (option is OptionType) {
    //   return option.value.toString();
    // }
    return option.toString();
  }

  Widget buildAsMenu() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color.fromARGB(160, 98, 98, 98)),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.only(left: 8.0, right: 10, top: 12, bottom: 8),

      child: Row(
        crossAxisAlignment: .start,
        children: [
          SizedBox(width: 50, child: Icon(Icons.settings)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.interceptor.name,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.interceptor.description,
                  // overflow: TextOverflow.ellipsis,
                  // maxLines: 3,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    if (options != null)
                      FutureBuilder(
                        future: options,
                        builder: (context, snapshot) {
                          final optionsList = snapshot.data ?? [];
                          if (optionsList.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                                vertical: 8,
                              ),
                              child: Text(
                                "No items available",
                                style: TextStyle(
                                  color: Colors.orange.withAlpha(200),
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            );
                          }
                          return DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color.fromARGB(160, 98, 98, 98),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButton<String>(
                              isDense: true,
                              underline: SizedBox(),
                              value: selectedOption,
                              enableFeedback: false,
                              borderRadius: .circular(8),
                              dropdownColor: const Color.fromARGB(
                                255,
                                49,
                                49,
                                49,
                              ),
                              padding: .symmetric(horizontal: 12, vertical: 3),
                              items: optionsList.map<DropdownMenuItem<String>>((
                                option,
                              ) {
                                return DropdownMenuItem<String>(
                                  value: option.toString(),
                                  child: Text(option.toString()),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedOption = value;
                                });
                              },
                            ),
                          );
                        },
                      ),
                    Spacer(),
                    if (preOptions.isEmpty) buildLaunchBtn(),
                  ],
                ),
                SizedBox(height: 12),
                if (preOptions.isNotEmpty)
                  Row(
                    mainAxisAlignment: .end,
                    spacing: 8,
                    children: [
                      ...preOptions.map((preOption) {
                        return buildBtn(
                          preOption.label,
                          onPressed: () {
                            final config = LaunchConfig(
                              option: selectedOption,
                              preOption: preOption.value,
                            );
                            widget.interceptor.launch(config);
                          },
                        );
                      }),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildLaunchBtn() {
    return OutlinedButton.icon(
      style: ButtonStyle(
        shape: .all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        minimumSize: .all(const Size(80, 38)),
        foregroundColor: .all(const Color.fromARGB(255, 212, 212, 212)),
        padding: .all(.symmetric(horizontal: 16, vertical: 6)),
      ),
      onPressed:
          selectedOption == null
              ? null
              : () async {
                if (widget.interceptor is FridaAndroidInterceptor) {
                  androidOverlayEntry = showDraggableWindowOverlay(
                    context: context,
                    child: AndroidPhone(
                      width: 350,
                      id: selectedOption ?? '',
                      interceptor: widget.interceptor as FridaAndroidInterceptor,
                    ),
                  );
                } else {
                  final config = LaunchConfig(option: selectedOption);
                  widget.interceptor.launch(config);
                }
                Navigator.of(context).pop();
              },
      label: Text("Launch", style: TextStyle(fontSize: 12)),
      icon: Icon(Icons.launch, size: 16),
    );
  }

  Widget buildBtn(String label, {required VoidCallback onPressed}) {
    return OutlinedButton(
      style: ButtonStyle(
        shape: .all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        minimumSize: .all(const Size(80, 38)),
        foregroundColor: .all(const Color.fromARGB(255, 212, 212, 212)),
        padding: .all(.symmetric(horizontal: 24, vertical: 6)),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

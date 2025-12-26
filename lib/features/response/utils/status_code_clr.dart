import 'package:flutter/material.dart';

Color statusCodeColor(int code) {
  if (code == 0) return Colors.red;
  if (code >= 200 && code < 300) {
    return Colors.green;
  } else if (code >= 400 && code < 500) {
    return Colors.orange;
  } else if (code >= 500) {
    return const Color.fromARGB(255, 249, 122, 71);
  }
  return Colors.grey;
}

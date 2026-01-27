import 'package:flutter/material.dart';
import 'package:suryaicons/suryaicons.dart';

class SuryaThemeIcon extends StatelessWidget {
  final List<List<dynamic>> icon;
  final double size;
  final Color? clr;
  const SuryaThemeIcon(this.icon, {super.key, this.size = 16, this.clr});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SuryaIcon(
      icon: icon,
      color: clr ?? cs.primary,
      color2: cs.onSurfaceVariant,
      strokeWidth: 1.2,
      size: size,
    );
  }
}

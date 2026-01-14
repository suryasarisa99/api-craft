import 'package:flutter_riverpod/flutter_riverpod.dart';

final refProvider = Provider<Ref>((ref) => ref);
Ref getRef(WidgetRef ref) => ref.read(refProvider);

import 'package:api_craft/core/screens/api_client_screen.dart';
import 'package:api_craft/flows/widgets/flows_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lazy_load_indexed_stack/lazy_load_indexed_stack.dart';

final screenProvider = NotifierProvider<ScreenNotifier, int>(
  ScreenNotifier.new,
);

class ScreenNotifier extends Notifier<int> {
  @override
  int build() {
    return 0;
  }

  void set(int index) {
    state = index;
  }

  void toggle() {
    state = state == 0 ? 1 : 0;
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final screens = [ApiClientScreen(), FlowsScreen()];
  @override
  Widget build(BuildContext context) {
    return LazyLoadIndexedStack(
      index: ref.watch(screenProvider),
      children: screens,
    );
  }
}

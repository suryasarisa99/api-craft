import 'package:api_craft/app/screens/api_client_screen.dart';
import 'package:api_craft/app/screens/screen_provider.dart';
import 'package:api_craft/traffic/flows/widgets/flows_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lazy_load_indexed_stack/lazy_load_indexed_stack.dart';

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

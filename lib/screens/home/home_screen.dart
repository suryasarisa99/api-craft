import 'package:api_craft/providers/providers.dart';
import 'package:api_craft/screens/home/request/request.dart';
import 'package:api_craft/screens/home/sidebar/sidebar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const HomeTopBar(),
          Expanded(
            child: Row(
              children: [
                SizedBox(width: 280, child: FileExplorerView()),
                const VerticalDivider(width: 1),
                Expanded(child: ReqTabWrapper()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HomeTopBar extends ConsumerStatefulWidget {
  const HomeTopBar({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _HomeTopBarState();
}

class _HomeTopBarState extends ConsumerState<HomeTopBar> {
  @override
  Widget build(BuildContext context) {
    final selectedCollection = ref.watch(selectedCollectionProvider);
    return Row(
      children: [
        Text(
          selectedCollection != null
              ? 'Selected Collection: ${selectedCollection.name}'
              : 'No Collection Selected',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}

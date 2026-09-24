import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:{{app_name.snakeCase()}}/features/home/providers/home_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncModules = ref.watch(connectedModulesProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Demo Home Screen')),
      body: SafeArea(
        child: Center(
          child: asyncModules.when(
            loading: () => const CircularProgressIndicator(),
            error: (error, stack) => Text('Error: $error'),
            data: (modules) => Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Text('The list of connected SMF modules'),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 20,
                      runSpacing: 10,
                      children: List.generate(
                        modules.length,
                        (index) => Text(modules[index]),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

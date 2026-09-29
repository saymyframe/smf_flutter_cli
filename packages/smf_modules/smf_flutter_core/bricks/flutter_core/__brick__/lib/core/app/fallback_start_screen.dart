import 'package:flutter/material.dart';

/// The screen the app starts on when no route of the app can start it.
class FallbackStartScreen extends StatelessWidget {
  /// Creates the screen.
  const FallbackStartScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('{{app_name.titleCase()}}')),
      );
}

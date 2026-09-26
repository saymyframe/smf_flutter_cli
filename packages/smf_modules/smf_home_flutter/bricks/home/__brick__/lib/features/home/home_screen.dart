import 'package:flutter/material.dart';

/// The screen the app starts on, with the name of the app.
{{{smf_router__screen_annotations__home__home_screen}}}
class HomeScreen extends StatelessWidget {
  /// Creates the screen.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('{{app_name.titleCase()}}')),
  );
}

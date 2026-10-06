import 'package:flutter/material.dart';

/// The settings of the app: an entry for each setting that a module of the
/// app has, and what the app is, with its licenses.
{{{smf_router__screen_annotations__settings__settings_screen}}}
class SettingsScreen extends StatelessWidget {
  /// Creates the screen.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: {{^has_localization}}const {{/has_localization}}Text({{{text_title}}})),
    body: ListView(
      children: const [
{{{entries}}}
        AboutListTile(
          icon: Icon(Icons.info_outline),
          applicationName: '{{app_name.titleCase()}}',
        ),
      ],
    ),
  );
}

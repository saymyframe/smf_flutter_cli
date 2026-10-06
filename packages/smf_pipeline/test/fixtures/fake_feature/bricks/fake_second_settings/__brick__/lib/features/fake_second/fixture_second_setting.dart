import 'package:flutter/material.dart';

/// The setting of the second fixture feature: a row of the settings screen
/// of the app, with a text of the feature in the language of the app.
///
/// The setting of the fixture screen log has the same class name in a file
/// of its own, so a settings screen shows both only through an import of
/// each file with a prefix of its own.
class FixtureSetting extends StatelessWidget {
  /// Creates the row.
  const FixtureSetting({super.key});

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.looks_two),
    title: Text({{{text_setting}}}),
  );
}

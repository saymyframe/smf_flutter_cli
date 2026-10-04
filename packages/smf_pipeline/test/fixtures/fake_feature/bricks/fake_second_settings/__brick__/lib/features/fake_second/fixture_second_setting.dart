import 'package:flutter/material.dart';

/// The setting of the second fixture feature: a row of the settings screen
/// of the app.
class FixtureSecondSetting extends StatelessWidget {
  /// Creates the row.
  const FixtureSecondSetting({super.key});

  @override
  Widget build(BuildContext context) => const ListTile(
    leading: Icon(Icons.looks_two),
    title: Text('Second'),
  );
}

import 'package:flutter/material.dart';

/// The setting of the fixture screen log: a row of the settings screen of
/// the app.
class FixtureScreenLogSetting extends StatelessWidget {
  /// Creates the row.
  const FixtureScreenLogSetting({super.key});

  @override
  Widget build(BuildContext context) => const ListTile(
    leading: Icon(Icons.list),
    title: Text('Screen log'),
  );
}

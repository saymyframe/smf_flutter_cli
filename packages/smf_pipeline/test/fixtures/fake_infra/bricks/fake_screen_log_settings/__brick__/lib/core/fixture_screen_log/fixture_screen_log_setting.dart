import 'package:flutter/material.dart';

/// The settings of the fixture screen log: two rows of the settings screen
/// of the app that belong together, so the entry is taller than one row.
///
/// The setting of the second fixture feature has the same class name in a
/// file of its own, so a settings screen shows both only through an import
/// of each file with a prefix of its own.
class FixtureSetting extends StatelessWidget {
  /// Creates the rows.
  const FixtureSetting({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ListTile(leading: Icon(Icons.list), title: Text('Screen log')),
      ListTile(leading: Icon(Icons.timer), title: Text('Keep for a day')),
    ],
  );
}
